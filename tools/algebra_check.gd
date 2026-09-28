## Chromaton color-algebra checker.
##
## Answers "which starting kits of pieces can build every possible color machine?"
## and prices a catalog of useful recipes in the candidate kits.
##
## Run from the project folder:
##   godot_console --headless --path . --script res://tools/algebra_check.gd
## Writes docs/algebra-report.md and exits with code 1 if any check fails.
##
## How a verdict is reached:
## - COMPLETE: the kit can rebuild NOR, Shift and a Red pot (verified on every
##   input), and those three can build any machine (see "The base kit" in the
##   report). As an end-to-end check, random machines of 1-3 inputs are then
##   actually built from the kit's own pieces and compared against their tables.
## - INCOMPLETE: every piece in the kit respects some rule (a relation) that
##   not every machine respects. Anything built from the kit respects it too,
##   so the machines that break the rule can never be built. That is a proof.
extends SceneTree

const Paint = preload("res://core/paint.gd")

const ARITY := {
	"mix": 2, "filter": 2, "invert": 1, "shift": 1, "nor": 2, "contrast": 2,
	"swap_ry": 1, "red": 0, "yellow": 0, "blue": 0,
}
const PIECE_NAMES := {
	"mix": "Mix", "filter": "Filter", "invert": "Invert", "shift": "Shift",
	"nor": "NOR", "contrast": "Contrast", "swap_ry": "Swap red/yellow",
	"red": "Red pot", "yellow": "Yellow pot", "blue": "Blue pot",
}
const COMMUTATIVE := {"mix": true, "filter": true, "nor": true, "contrast": true}

var problems := 0
var report := PackedStringArray()
var _preserve_cache := {}


# ---------------------------------------------------------------------------
# Piece semantics
# ---------------------------------------------------------------------------

static func apply0(op: String) -> int:
	match op:
		"red":
			return Paint.RED
		"yellow":
			return Paint.YELLOW
		"blue":
			return Paint.BLUE
	push_error("unknown source: " + op)
	return 0


static func apply1(op: String, a: int) -> int:
	match op:
		"invert":
			return Paint.invert(a)
		"shift":
			return Paint.shift(a)
		"swap_ry":
			return (a & Paint.BLUE) | ((a & Paint.RED) << 1) | ((a & Paint.YELLOW) >> 1)
	push_error("unknown unary piece: " + op)
	return 0


static func apply2(op: String, a: int, b: int) -> int:
	match op:
		"mix":
			return Paint.mix(a, b)
		"filter":
			return Paint.filter(a, b)
		"nor":
			return Paint.invert(Paint.mix(a, b))
		"contrast":
			return Paint.contrast(a, b)
	push_error("unknown binary piece: " + op)
	return 0


# ---------------------------------------------------------------------------
# Machines as shared expression graphs
# ---------------------------------------------------------------------------

class Expr:
	var op: String
	var args: Array
	var value: int

	func _init(p_op: String, p_args: Array, p_value: int) -> void:
		op = p_op
		args = p_args
		value = p_value


## Creates pieces, reusing an identical piece instead of making a second one
## (a machine can split one tube to feed several vats).
class Builder:
	var cache := {}

	func node(op: String, args: Array = [], value: int = 0) -> Expr:
		var ordered := args.duplicate()
		if COMMUTATIVE.has(op):
			ordered.sort_custom(func(p, q): return p.get_instance_id() < q.get_instance_id())
		var key := op + "|" + str(value)
		for a in ordered:
			key += "|" + str(a.get_instance_id())
		if not cache.has(key):
			cache[key] = Expr.new(op, ordered, value)
		return cache[key]

	func input(i: int) -> Expr:
		return node("in", [], i)


func topo(roots: Array) -> Array:
	var order := []
	var seen := {}
	var stack := []
	for r in roots:
		stack.append([r, false])
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var e: Expr = top[0]
		if top[1]:
			order.append(e)
			continue
		var id := e.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		stack.append([e, true])
		for a in e.args:
			if not seen.has(a.get_instance_id()):
				stack.append([a, false])
	return order


## Output tables of the given machine outputs over all 8^n inputs.
## Entry k holds the output for inputs (k % 8, k / 8 % 8, ...).
func evaluate(roots: Array, n: int) -> Array:
	var size := 1
	for i in n:
		size *= 8
	var tables := {}
	for e in topo(roots):
		var t := PackedByteArray()
		t.resize(size)
		if e.op == "in":
			var d := 1
			for i in e.value:
				d *= 8
			for k in size:
				t[k] = (k / d) % 8
		else:
			var arity: int = ARITY[e.op]
			if arity == 0:
				t.fill(apply0(e.op))
			elif arity == 1:
				var a: PackedByteArray = tables[e.args[0].get_instance_id()]
				for k in size:
					t[k] = apply1(e.op, a[k])
			else:
				var a: PackedByteArray = tables[e.args[0].get_instance_id()]
				var b: PackedByteArray = tables[e.args[1].get_instance_id()]
				for k in size:
					t[k] = apply2(e.op, a[k], b[k])
		tables[e.get_instance_id()] = t
	var result := []
	for r in roots:
		result.append(tables[r.get_instance_id()])
	return result


func cost(roots: Array) -> Dictionary:
	var counts := {}
	var total := 0
	for e in topo(roots):
		if e.op == "in":
			continue
		counts[e.op] = counts.get(e.op, 0) + 1
		total += 1
	return {"total": total, "counts": counts}


func cost_text(c: Dictionary) -> String:
	var parts := []
	var ops: Array = c["counts"].keys()
	ops.sort_custom(func(p, q): return c["counts"][p] > c["counts"][q] or (c["counts"][p] == c["counts"][q] and p < q))
	for op in ops:
		parts.append("%d %s" % [c["counts"][op], PIECE_NAMES[op]])
	return "**%d** (%s)" % [c["total"], ", ".join(parts)]


static func same_table(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k] != b[k]:
			return false
	return true


static func digits(k: int, n: int) -> Array:
	var v := []
	for i in n:
		v.append(k % 8)
		k /= 8
	return v


# ---------------------------------------------------------------------------
# Generic construction: any machine from NOR, Shift and a Red pot
# ---------------------------------------------------------------------------

## Builds any machine out of a kit's own pieces, given the kit's recipes for
## NOR, Shift and a Red pot.
class Toolkit:
	var b: Builder
	var kit: Dictionary

	func _init(p_b: Builder, p_kit: Dictionary) -> void:
		b = p_b
		kit = p_kit

	func nor(x, y):
		return kit["nor"].call(b, x, y)

	func shift(x):
		return kit["shift"].call(b, x)

	func red():
		return kit["red"].call(b)

	func inv(x):
		return nor(x, x)

	func orr(x, y):
		return inv(nor(x, y))

	func andd(x, y):
		return nor(inv(x), inv(y))

	func white():
		var r = red()
		return nor(r, inv(r))

	func primary(ch: int):
		var p = red()
		for i in ch:
			p = shift(p)
		return p

	func constant(c: int):
		var parts := []
		for ch in 3:
			if c & (1 << ch):
				parts.append(primary(ch))
		return balanced(parts, true)

	## Black if x contains primary ch, otherwise White.
	func any_of(ch: int, x):
		var m = andd(x, primary(ch))
		var s1 = shift(m)
		var s2 = shift(s1)
		return orr(orr(m, s1), s2)

	## Black if x is exactly color c, otherwise White.
	func is_color(x, c: int):
		var lits := []
		for ch in 3:
			var lit = any_of(ch, x)
			if not (c & (1 << ch)):
				lit = inv(lit)
			lits.append(lit)
		return balanced(lits, false)

	func balanced(items: Array, use_or: bool):
		if items.is_empty():
			return white() if use_or else inv(white())
		while items.size() > 1:
			var nxt := []
			for i in range(0, items.size(), 2):
				if i + 1 < items.size():
					nxt.append(orr(items[i], items[i + 1]) if use_or else andd(items[i], items[i + 1]))
				else:
					nxt.append(items[i])
			items = nxt
		return items[0]

	## One term per input combination that should give paint:
	## "inputs are exactly these colors" filtered down to the wanted output.
	func from_table(tbl: PackedByteArray, inputs: Array):
		var terms := []
		for k in tbl.size():
			var wanted: int = tbl[k]
			if wanted == 0:
				continue
			var lits := []
			var rest := k
			for i in inputs.size():
				lits.append(is_color(inputs[i], rest % 8))
				rest /= 8
			lits.append(constant(wanted))
			terms.append(balanced(lits, false))
		return balanced(terms, true)


# ---------------------------------------------------------------------------
# Kits
# ---------------------------------------------------------------------------

func _nor_direct(b: Builder, x, y):
	return b.node("nor", [x, y])


func _nor_via_mix(b: Builder, x, y):
	return b.node("invert", [b.node("mix", [x, y])])


func _nor_via_contrast(b: Builder, x, y):
	var r := b.node("red")
	var yl := b.node("shift", [r])
	var bl := b.node("shift", [yl])
	var black := b.node("mix", [b.node("mix", [r, yl]), bl])
	return b.node("contrast", [b.node("mix", [x, y]), black])


func _shift_direct(b: Builder, x):
	return b.node("shift", [x])


func _red_direct(b: Builder):
	return b.node("red")


func kits() -> Array:
	return [
		{"name": "NOR + Shift + Red pot", "pieces": ["nor", "shift", "red"],
			"nor": _nor_direct, "shift": _shift_direct, "red": _red_direct,
			"how": "The base kit itself."},
		{"name": "Mix + Invert + Shift + Red pot", "pieces": ["mix", "invert", "shift", "red"],
			"nor": _nor_via_mix, "shift": _shift_direct, "red": _red_direct,
			"how": "NOR = Invert after Mix."},
		{"name": "Mix + Filter + Invert + Shift + Red, Yellow, Blue pots",
			"pieces": ["mix", "filter", "invert", "shift", "red", "yellow", "blue"],
			"nor": _nor_via_mix, "shift": _shift_direct, "red": _red_direct,
			"how": "NOR = Invert after Mix."},
		{"name": "Mix + Filter + Contrast + Shift + Red pot", "pieces": ["mix", "filter", "contrast", "shift", "red"],
			"nor": _nor_via_contrast, "shift": _shift_direct, "red": _red_direct,
			"how": "Black = Red + Shift(Red) + Shift(Shift(Red)); NOR = Contrast of the Mix with Black."},
		{"name": "NOR + Shift, no pot", "pieces": ["nor", "shift"]},
		{"name": "NOR + Red pot, no Shift", "pieces": ["nor", "red"]},
		{"name": "Mix + Filter + Invert + Shift, no pots", "pieces": ["mix", "filter", "invert", "shift"]},
		{"name": "Mix + Filter + Shift + 3 pots, no Invert", "pieces": ["mix", "filter", "shift", "red", "yellow", "blue"]},
		{"name": "Mix + Filter + Invert + 3 pots, no Shift", "pieces": ["mix", "filter", "invert", "red", "yellow", "blue"]},
		{"name": "Mix + Filter + Invert + Swap red/yellow + 3 pots", "pieces": ["mix", "filter", "invert", "swap_ry", "red", "yellow", "blue"]},
		{"name": "Contrast + Shift + Red pot, no Mix or Filter", "pieces": ["contrast", "shift", "red"]},
	]


# ---------------------------------------------------------------------------
# Rules (relations) that prove a kit incomplete
# ---------------------------------------------------------------------------

func relations() -> Array:
	var order := []
	var rotation := []
	var swap := []
	var lanes := [[], [], []]
	var affine := []
	for a in 8:
		rotation.append([a, Paint.shift(a)])
		swap.append([a, apply1("swap_ry", a)])
		for b in 8:
			if (a & ~b & 7) == 0:
				order.append([a, b])
			for ch in 3:
				if (((a ^ b) >> ch) & 1) == 0:
					lanes[ch].append([a, b])
			for c in 8:
				affine.append([a, b, c, a ^ b ^ c])
	return [
		{"name": "Only adds paint", "tuples": order,
			"why": "Every piece gives the same or more paint when its inputs get more paint. Nothing built from them can take paint away, so Invert can't be built."},
		{"name": "Blind to the wheel's turn", "tuples": rotation,
			"why": "Every piece behaves the same if red, yellow and blue are all turned one step around the wheel. Nothing built from them can single out one primary, so a Red pot can't be built."},
		{"name": "Red and yellow look alike", "tuples": swap,
			"why": "Every piece behaves the same if red and yellow are swapped everywhere. Red and yellow can never be told apart."},
		{"name": "Red stays in its lane", "tuples": lanes[0],
			"why": "Whether an output has red depends only on whether the inputs have red. Paint never moves between primaries, so Shift can't be built."},
		{"name": "Yellow stays in its lane", "tuples": lanes[1],
			"why": "Whether an output has yellow depends only on whether the inputs have yellow. Paint never moves between primaries."},
		{"name": "Blue stays in its lane", "tuples": lanes[2],
			"why": "Whether an output has blue depends only on whether the inputs have blue. Blue can never move into another primary, so Shift can't be built."},
		{"name": "Only toggles", "tuples": affine,
			"why": "Every piece works like Contrast: it only ever toggles primaries on and off. Toggles only combine into more toggles, so Filter and Mix can't be built."},
		{"name": "No paint from nothing", "tuples": [[0]],
			"why": "With only white coming in, only white comes out. There is no paint source."},
		{"name": "No hue from white and black", "tuples": [[0], [7]],
			"why": "With only white and black coming in, only white and black come out. No hue can ever appear, so a Red pot can't be built."},
	]


static func encode(t: Array) -> int:
	var code := 0
	var mul := 1
	for v in t:
		code += v * mul
		mul *= 8
	return code


func preserves(op: String, rel: Dictionary) -> bool:
	var cache_key: String = op + "@" + rel["name"]
	if _preserve_cache.has(cache_key):
		return _preserve_cache[cache_key]
	var tuples: Array = rel["tuples"]
	var m: int = tuples[0].size()
	var keys := {}
	for t in tuples:
		keys[encode(t)] = true
	var ok := true
	var arity: int = ARITY[op]
	if arity == 0:
		var t := []
		for i in m:
			t.append(apply0(op))
		ok = keys.has(encode(t))
	elif arity == 1:
		for t in tuples:
			var r := []
			for i in m:
				r.append(apply1(op, t[i]))
			if not keys.has(encode(r)):
				ok = false
				break
	else:
		for t1 in tuples:
			for t2 in tuples:
				var code := 0
				var mul := 1
				for i in m:
					code += apply2(op, t1[i], t2[i]) * mul
					mul *= 8
				if not keys.has(code):
					ok = false
					break
			if not ok:
				break
	_preserve_cache[cache_key] = ok
	return ok


# ---------------------------------------------------------------------------
# Kit analysis
# ---------------------------------------------------------------------------

func uses_only(roots: Array, pieces: Array) -> bool:
	for e in topo(roots):
		if e.op != "in" and not pieces.has(e.op):
			return false
	return true


func verify_translation(kit: Dictionary) -> bool:
	var b := Builder.new()
	var x := b.input(0)
	var y := b.input(1)
	var n = kit["nor"].call(b, x, y)
	var s = kit["shift"].call(b, x)
	var r = kit["red"].call(b)
	if not uses_only([n, s, r], kit["pieces"]):
		return false
	var nt: PackedByteArray = evaluate([n], 2)[0]
	for k in 64:
		var v := digits(k, 2)
		if nt[k] != apply2("nor", v[0], v[1]):
			return false
	var st: PackedByteArray = evaluate([s], 1)[0]
	for k in 8:
		if st[k] != Paint.shift(k):
			return false
	return evaluate([r], 0)[0][0] == Paint.RED


func end_to_end(kit: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var trials := {1: 30, 2: 8, 3: 1}
	var passed := 0
	var total := 0
	var sizes := {1: [], 2: [], 3: []}
	for n in [1, 2, 3]:
		for trial in trials[n]:
			var size := 1
			for i in n:
				size *= 8
			var tbl := PackedByteArray()
			tbl.resize(size)
			for k in size:
				tbl[k] = rng.randi_range(0, 7)
			var b := Builder.new()
			var tk := Toolkit.new(b, kit)
			var inputs := []
			for i in n:
				inputs.append(b.input(i))
			var root = tk.from_table(tbl, inputs)
			total += 1
			if uses_only([root], kit["pieces"]) and same_table(evaluate([root], n)[0], tbl):
				passed += 1
			sizes[n].append(cost([root])["total"])
	return {"passed": passed, "total": total, "sizes": sizes}


static func average(values: Array) -> int:
	if values.is_empty():
		return 0
	var s := 0
	for v in values:
		s += v
	return int(round(float(s) / values.size()))


# ---------------------------------------------------------------------------
# Recipe catalog
# ---------------------------------------------------------------------------

## Recipes written with the pieces a player would place.
class Pieces:
	var b: Builder
	var has_filter: bool
	var has_all_pots: bool

	func _init(p_b: Builder, p_has_filter: bool, p_has_all_pots: bool) -> void:
		b = p_b
		has_filter = p_has_filter
		has_all_pots = p_has_all_pots

	func mix(x, y):
		return b.node("mix", [x, y])

	func inv(x):
		return b.node("invert", [x])

	func shift(x):
		return b.node("shift", [x])

	func pot(ch: int):
		if has_all_pots:
			return b.node(["red", "yellow", "blue"][ch])
		var p = b.node("red")
		for i in ch:
			p = shift(p)
		return p

	func filter(x, y):
		if has_filter:
			return b.node("filter", [x, y])
		return inv(mix(inv(x), inv(y)))

	func bleach(x, y):
		if has_filter:
			return filter(x, inv(y))
		return inv(mix(inv(x), y))

	func contrast(x, y):
		if has_filter:
			return filter(mix(x, y), inv(filter(x, y)))
		return mix(bleach(x, y), bleach(y, x))

	## Black if x has any paint, otherwise White.
	func any_paint(x):
		var s1 = shift(x)
		return mix(mix(x, s1), shift(s1))

	## Black if x contains primary ch, otherwise White.
	func any_of(ch: int, x):
		return any_paint(filter(x, pot(ch)))


func _r_yellow(p: Pieces, _i: Array) -> Array:
	return [p.pot(1)]

func _r_black(p: Pieces, _i: Array) -> Array:
	return [p.mix(p.mix(p.pot(0), p.pot(1)), p.pot(2))]

func _r_filter(p: Pieces, i: Array) -> Array:
	return [p.filter(i[0], i[1])]

func _r_third(p: Pieces, i: Array) -> Array:
	return [p.inv(p.mix(i[0], i[1]))]

func _r_bleach(p: Pieces, i: Array) -> Array:
	return [p.bleach(i[0], i[1])]

func _r_contrast(p: Pieces, i: Array) -> Array:
	return [p.contrast(i[0], i[1])]

func _r_consensus(p: Pieces, i: Array) -> Array:
	return [p.mix(p.mix(p.filter(i[0], i[1]), p.filter(i[1], i[2])), p.filter(i[0], i[2]))]

func _r_prism(p: Pieces, i: Array) -> Array:
	return [p.filter(i[0], p.pot(0)), p.filter(i[0], p.pot(1)), p.filter(i[0], p.pot(2))]

func _r_any_red(p: Pieces, i: Array) -> Array:
	return [p.any_of(0, i[0])]

func _r_same(p: Pieces, i: Array) -> Array:
	return [p.inv(p.any_paint(p.contrast(i[0], i[1])))]

func _r_switch(p: Pieces, i: Array) -> Array:
	return [p.filter(i[1], p.any_of(0, i[0])), p.filter(i[1], p.any_of(1, i[0])), p.filter(i[1], p.any_of(2, i[0]))]

func _r_selector(p: Pieces, i: Array) -> Array:
	return [p.mix(p.mix(p.filter(i[1], p.any_of(0, i[0])), p.filter(i[2], p.any_of(1, i[0]))), p.filter(i[3], p.any_of(2, i[0])))]


func _s_yellow(_v: Array) -> Array:
	return [Paint.YELLOW]

func _s_black(_v: Array) -> Array:
	return [Paint.BLACK]

func _s_filter(v: Array) -> Array:
	return [Paint.filter(v[0], v[1])]

func _s_third(v: Array) -> Array:
	return [Paint.invert(Paint.mix(v[0], v[1]))]

func _s_bleach(v: Array) -> Array:
	return [Paint.bleach(v[0], v[1])]

func _s_contrast(v: Array) -> Array:
	return [Paint.contrast(v[0], v[1])]

func _s_consensus(v: Array) -> Array:
	return [(v[0] & v[1]) | (v[1] & v[2]) | (v[0] & v[2])]

func _s_prism(v: Array) -> Array:
	return [v[0] & Paint.RED, v[0] & Paint.YELLOW, v[0] & Paint.BLUE]

func _s_any_red(v: Array) -> Array:
	return [Paint.BLACK if v[0] & Paint.RED else Paint.WHITE]

func _s_same(v: Array) -> Array:
	return [Paint.BLACK if v[0] == v[1] else Paint.WHITE]

func _s_switch(v: Array) -> Array:
	return [v[1] if v[0] == Paint.RED else Paint.WHITE, v[1] if v[0] == Paint.YELLOW else Paint.WHITE, v[1] if v[0] == Paint.BLUE else Paint.WHITE]

func _s_selector(v: Array) -> Array:
	if v[0] == Paint.RED:
		return [v[1]]
	if v[0] == Paint.YELLOW:
		return [v[2]]
	return [v[3]]


func _d_all(_v: Array) -> bool:
	return true

func _d_two_primaries(v: Array) -> bool:
	return Paint.PRIMARIES.has(v[0]) and Paint.PRIMARIES.has(v[1]) and v[0] != v[1]

func _d_primary_control(v: Array) -> bool:
	return Paint.PRIMARIES.has(v[0])


func recipes() -> Array:
	return [
		{"name": "Yellow pot", "shape": "none -> 1", "what": "Makes yellow from the red pot.", "inputs": 0, "build": _r_yellow, "spec": _s_yellow, "domain": _d_all},
		{"name": "Black pot", "shape": "none -> 1", "what": "Makes black.", "inputs": 0, "build": _r_black, "spec": _s_black, "domain": _d_all},
		{"name": "Filter", "shape": "2 -> 1", "what": "Only the primaries both inputs share.", "inputs": 2, "build": _r_filter, "spec": _s_filter, "domain": _d_all},
		{"name": "Third Color", "shape": "2 -> 1", "what": "Two different primaries in, the missing one out.", "inputs": 2, "build": _r_third, "spec": _s_third, "domain": _d_two_primaries},
		{"name": "Bleach", "shape": "2 -> 1", "what": "First input with the second one's primaries washed out.", "inputs": 2, "build": _r_bleach, "spec": _s_bleach, "domain": _d_all},
		{"name": "Contrast", "shape": "2 -> 1", "what": "Primaries in exactly one of the inputs.", "inputs": 2, "build": _r_contrast, "spec": _s_contrast, "domain": _d_all},
		{"name": "Consensus", "shape": "3 -> 1", "what": "Primaries in at least two of the three inputs.", "inputs": 3, "build": _r_consensus, "spec": _s_consensus, "domain": _d_all},
		{"name": "Prism", "shape": "1 -> 3", "what": "Splits a paint into its red, yellow and blue parts.", "inputs": 1, "build": _r_prism, "spec": _s_prism, "domain": _d_all},
		{"name": "Any Red?", "shape": "1 -> 1", "what": "Black if the input has red in it, otherwise white.", "inputs": 1, "build": _r_any_red, "spec": _s_any_red, "domain": _d_all},
		{"name": "Same Color?", "shape": "2 -> 1", "what": "Black if both inputs are the same color, otherwise white.", "inputs": 2, "build": _r_same, "spec": _s_same, "domain": _d_all},
		{"name": "Three-way Switch", "shape": "2 -> 3", "what": "A primary control sends the paint out of the red, yellow or blue exit.", "inputs": 2, "build": _r_switch, "spec": _s_switch, "domain": _d_primary_control},
		{"name": "Three-way Selector", "shape": "4 -> 1", "what": "A primary control picks which of three inputs passes.", "inputs": 4, "build": _r_selector, "spec": _s_selector, "domain": _d_primary_control},
	]


func check_recipe(recipe: Dictionary, has_filter: bool, has_all_pots: bool, pieces: Array) -> Dictionary:
	var b := Builder.new()
	var p := Pieces.new(b, has_filter, has_all_pots)
	var n: int = recipe["inputs"]
	var inputs := []
	for i in n:
		inputs.append(b.input(i))
	var outs: Array = recipe["build"].call(p, inputs)
	var tables := evaluate(outs, n)
	var ok := uses_only(outs, pieces)
	for k in tables[0].size():
		var v := digits(k, n)
		if not recipe["domain"].call(v):
			continue
		var want: Array = recipe["spec"].call(v)
		for o in outs.size():
			if tables[o][k] != want[o]:
				ok = false
	return {"ok": ok, "cost": cost(outs)}


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

func w(line: String = "") -> void:
	report.append(line)


func fail(what: String) -> void:
	problems += 1
	printerr("PROBLEM: " + what)


func _init() -> void:
	var started := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	var rels := relations()

	w("# Chromaton color algebra report")
	w()
	w("Generated by `tools/algebra_check.gd` on %s. Rerun it after changing pieces or recipes:" % Time.get_date_string_from_system())
	w()
	w("```")
	w("godot_console --headless --path . --script res://tools/algebra_check.gd")
	w("```")
	w()
	w("Internal design document: it talks about primaries as separate lanes, which the player never needs to see.")
	w()

	# --- 1. base kit ---
	w("## 1. The base kit: NOR, Shift and one Red pot")
	w()
	w("NOR is Invert after Mix, as a single vat. The argument that these three build any machine, whatever its number of inputs:")
	w()
	w("1. **Pots:** White = NOR(Red, NOR(Red, Red)). Yellow = Shift(Red), Blue = Shift(Yellow). Any color is a Mix of those.")
	w("2. **Paint logic within each primary:** NOR alone builds Invert, Mix and Filter, applied to each primary separately.")
	w("3. **Moving paint between primaries:** \"Any Red?\" = Filter(x, Red), then Mix it with its Shift and its double Shift. The result is Black if x has red, White if not. Same for yellow and blue.")
	w("4. **Any machine:** for every input combination that should give paint, test \"is input 1 exactly this color, input 2 exactly that color, ...\" with the step-3 answers and Filter, keep the wanted color with Filter, and Mix all those terms together.")
	w()
	w("The checker builds every step from real pieces and runs them on every possible input, then does the same for whole random machines (section 3).")
	w()

	# --- 2. kits ---
	w("## 2. Candidate starting kits")
	w()
	w("| Kit | Verdict | Why |")
	w("|---|---|---|")
	var complete_kits := []
	for kit in kits():
		var preserved := []
		for rel in rels:
			var all_keep := true
			for op in kit["pieces"]:
				if not preserves(op, rel):
					all_keep = false
					break
			if all_keep:
				preserved.append(rel)
		var complete := false
		if kit.has("nor"):
			complete = verify_translation(kit)
			if not complete:
				fail("translation to the base kit failed for " + kit["name"])
		var verdict := ""
		var why := ""
		if complete and not preserved.is_empty():
			fail("contradiction for " + kit["name"])
			verdict = "CHECKER BUG"
		elif complete:
			verdict = "**Complete**"
			why = kit["how"]
			complete_kits.append(kit)
		elif not preserved.is_empty():
			verdict = "Incomplete"
			why = "*%s.* %s" % [preserved[0]["name"], preserved[0]["why"]]
		else:
			verdict = "Unknown"
			why = "No recipe for the base kit and no blocking rule found."
			fail("undetermined kit " + kit["name"])
		w("| %s | %s | %s |" % [kit["name"], verdict, why])
		print("%-60s %s" % [kit["name"], verdict.replace("*", "")])
	w()

	# --- 3. end to end ---
	w("## 3. End-to-end: random machines built from each complete kit")
	w()
	w("Each random machine is a random table of outputs, built with the generic construction from section 1 using only the kit's own pieces, then run on every input and compared with the table. Piece counts are for the generic construction, which is far from optimal: they show that building is possible, not what a clever player would need.")
	w()
	w("| Kit | Machines matching their table | Avg pieces, 1 input | Avg pieces, 2 inputs | Pieces, 3 inputs |")
	w("|---|---|---|---|---|")
	for kit in complete_kits:
		var r := end_to_end(kit, rng)
		if r["passed"] != r["total"]:
			fail("end-to-end mismatch for " + kit["name"])
		w("| %s | %d / %d | %d | %d | %d |" % [kit["name"], r["passed"], r["total"], average(r["sizes"][1]), average(r["sizes"][2]), average(r["sizes"][3])])
	w()

	# --- 4. catalog ---
	w("## 4. Recipe catalog: how many pieces each invention takes")
	w()
	w("Two candidate kits. **Lean:** Mix, Invert, Shift and one Red pot, with Filter as an early invention. **Full:** Mix, Filter, Invert, Shift and all three pots. Every recipe is checked on every input it is meant for. Pieces are counted the way the optimizer would count them: every vat and pot, with one tube allowed to feed several vats.")
	w()
	w("| Recipe | In -> out | What it does | Lean kit | Full kit |")
	w("|---|---|---|---|---|")
	var lean := ["mix", "invert", "shift", "red"]
	var full := ["mix", "filter", "invert", "shift", "red", "yellow", "blue"]
	for recipe in recipes():
		var l := check_recipe(recipe, false, false, lean)
		var f := check_recipe(recipe, true, true, full)
		if not l["ok"]:
			fail("recipe %s is wrong in the lean kit" % recipe["name"])
		if not f["ok"]:
			fail("recipe %s is wrong in the full kit" % recipe["name"])
		w("| %s | %s | %s | %s | %s |" % [recipe["name"], recipe["shape"], recipe["what"], cost_text(l["cost"]), cost_text(f["cost"])])
	w()
	w("---")
	w()
	w("Checks: %s. Run time %.1f s." % ["all passed" if problems == 0 else "**%d problem(s), see console**" % problems, (Time.get_ticks_msec() - started) / 1000.0])

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs"))
	var file := FileAccess.open("res://docs/algebra-report.md", FileAccess.WRITE)
	file.store_string("\n".join(report) + "\n")
	file.close()
	print("Wrote docs/algebra-report.md; problems: %d" % problems)
	quit(1 if problems > 0 else 0)
