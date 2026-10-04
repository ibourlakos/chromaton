## Chromaton color-algebra checker.
##
## Documents the pieces in the game (from core/pieces.gd: every-paint tables
## and the laws they obey, each checked), answers "which starting kits of
## pieces can build every possible color machine?", prices the inventions
## DESIGN.md specs and the candidates for future pieces in the game's kit, and
## lists what today's rules can't build.
##
## Run from the project folder:
##   .\make algebra
## Writes docs/algebra-report.md and exits with code 1 if any check fails.
##
## How a price is reached: every recipe has a hand-built machine (an upper
## bound). A search then tries every machine of the kit's pieces, cheapest
## first, within a node budget. If it finds one, that count is proven
## cheapest; otherwise the report gives a range: every count up to the low end
## was ruled out, the high end is the hand-built machine.
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
const GamePieces = preload("res://core/pieces.gd")

## What each piece in core/pieces.gd does, by kind. A piece missing here fails
## the check, so the notes can't fall behind the game.
const PIECE_NOTES := {
	"red_pot": "Red paint, one drop whenever its tube is free. The only basic pot; the other seven are inventions.",
	"mix": "Everything in either paint.",
	"filter": "Only the primaries both paints share.",
	"invert": "The complement: the primaries the paint lacks.",
	"shift": "Turns the wheel one step: red to yellow, yellow to blue, blue to red.",
	"split": "A copy of the drop in each tube. Free.",
	"catch_pot": "Swallows every drop and remembers the last few. Free; out of the trays for now (DESIGN.md 2.5).",
}

## How many cheapest-first machines the search may try per recipe and kit.
const SEARCH_NODES := 20000

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

	## Black if x has every primary, otherwise White.
	func all_paint(x):
		var s1 = shift(x)
		return filter(filter(x, s1), shift(s1))

	## How much paint, not which: White, Red, Orange or Black.
	func settle(x):
		var s1 = shift(x)
		var s2 = shift(s1)
		var any = mix(mix(x, s1), s2)
		var all = filter(filter(x, s1), s2)
		var two = mix(filter(x, s1), filter(s2, mix(x, s1)))
		var r = pot(0)
		return mix(mix(filter(any, r), filter(two, mix(r, pot(1)))), all)


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
	if p.has_filter:
		# Is It Black? of Same Paint (section 7.1).
		return [p.all_paint(p.mix(p.filter(i[0], i[1]), p.inv(p.mix(i[0], i[1]))))]
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
	return {"ok": ok, "cost": cost(outs), "outs": outs}


## A machine as a formula, inputs named A, B, C, D.
func formula(e: Expr) -> String:
	if e.op == "in":
		return "ABCD"[e.value]
	if ARITY[e.op] == 0:
		return PIECE_NAMES[e.op].trim_suffix(" pot")
	var parts := []
	for a in e.args:
		parts.append(formula(a))
	return "%s(%s)" % [PIECE_NAMES[e.op], ", ".join(parts)]


# ---------------------------------------------------------------------------
# Cheapest-machine search
# ---------------------------------------------------------------------------

## Tries every machine of a kit's pieces, cheapest first, until one gives
## every output of a recipe (splits free, so any result can feed any number of
## pieces). A signal is what one tube carries for every input combination: one
## row of flags per primary, bit k of row ch set if combination k gives paint
## with that primary. Each distinct signal gets an id, so a search state (the
## set of signals made so far) is a sorted list of ids.
##
## Each set of pieces is visited in one order only: a new piece must take the
## last piece's paint or have a larger id. Every machine has such an order
## (keep adding the smallest-id piece whose inputs are ready), so nothing
## cheaper is missed.
class Search:
	var n := 0
	var size := 1
	var words := 1
	var ops: Array = []
	var full := PackedInt64Array()  # per word: the bits in use
	var targets: Array = []  # per output: [values, care mask per word]
	var ids := {}  # signal value -> id
	var values: Array = []  # id -> signal value
	var cache := {}  # Vector3i(op index, input id, input id) -> id
	var visited := {}
	var nodes := 0
	var gave_up := false
	var found: Array = []

	func _init(p_n: int, p_ops: Array) -> void:
		n = p_n
		ops = p_ops
		for i in n:
			size *= 8
		words = maxi(1, (size + 63) / 64)
		full.resize(words)
		for wd in words:
			var bits := mini(64, size - wd * 64)
			full[wd] = -1 if bits == 64 else (1 << bits) - 1

	func _blank() -> PackedInt64Array:
		var v := PackedInt64Array()
		v.resize(3 * words)
		v.fill(0)
		return v

	## A signal from one color per input combination.
	func from_colors(colors: Array) -> PackedInt64Array:
		var v := _blank()
		for k in size:
			for ch in 3:
				if colors[k] & (1 << ch):
					v[ch * words + k / 64] |= 1 << (k % 64)
		return v

	## Adds an output to find: its color per combination and where it matters.
	func want(colors: Array, cares: Array) -> void:
		var care := PackedInt64Array()
		care.resize(words)
		care.fill(0)
		for k in size:
			if cares[k]:
				care[k / 64] |= 1 << (k % 64)
		targets.append([from_colors(colors), care])

	func _intern(v: PackedInt64Array) -> int:
		if not ids.has(v):
			ids[v] = values.size()
			values.append(v)
		return ids[v]

	func _meets(id: int, t: Array) -> bool:
		var v: PackedInt64Array = values[id]
		var tv: PackedInt64Array = t[0]
		var care: PackedInt64Array = t[1]
		for ch in 3:
			for wd in words:
				if ((v[ch * words + wd] ^ tv[ch * words + wd]) & care[wd]) != 0:
					return false
		return true

	## The outputs no signal gives yet.
	func _unmet(signals: Array) -> Array:
		var out := []
		for t in targets:
			var hit := false
			for s in signals:
				if _meets(s[0], t):
					hit = true
					break
			if not hit:
				out.append(t)
		return out

	## Signals are [id, op, first input index, second input index]; inputs
	## have op "in" and their letter's index.
	func _desc(signals: Array, k: int) -> String:
		var s: Array = signals[k]
		match s[1]:
			"in":
				return "ABCD"[s[2]]
			"red":
				return "Red"
			"invert", "shift":
				return "%s(%s)" % [s[1].capitalize(), _desc(signals, s[2])]
		return "%s(%s, %s)" % [s[1].capitalize(), _desc(signals, s[2]), _desc(signals, s[3])]

	func _record(signals: Array) -> void:
		found = []
		for t in targets:
			for k in signals.size():
				if _meets(signals[k][0], t):
					found.append(_desc(signals, k))
					break

	## Every piece the kit can add: [id, op, first input index, second input index].
	func _gates(signals: Array) -> Array:
		var out := []
		var m := signals.size()
		for oi in ops.size():
			var op: String = ops[oi]
			match op:
				"red":
					var key := Vector3i(oi, -1, -1)
					if not cache.has(key):
						var v := _blank()
						for wd in words:
							v[wd] = full[wd]
						cache[key] = _intern(v)
					out.append([cache[key], op, -1, -1])
				"invert", "shift":
					for k in m:
						var key := Vector3i(oi, signals[k][0], -1)
						if not cache.has(key):
							var a: PackedInt64Array = values[signals[k][0]]
							var v := _blank()
							for ch in 3:
								for wd in words:
									if op == "invert":
										v[ch * words + wd] = a[ch * words + wd] ^ full[wd]
									else:
										v[((ch + 1) % 3) * words + wd] = a[ch * words + wd]
							cache[key] = _intern(v)
						out.append([cache[key], op, k, -1])
				"mix", "filter":
					for i in m:
						for j in range(i + 1, m):
							var lo: int = mini(signals[i][0], signals[j][0])
							var hi: int = maxi(signals[i][0], signals[j][0])
							var key := Vector3i(oi, lo, hi)
							if not cache.has(key):
								var a: PackedInt64Array = values[lo]
								var b: PackedInt64Array = values[hi]
								var v := _blank()
								for x in v.size():
									v[x] = (a[x] | b[x]) if op == "mix" else (a[x] & b[x])
								cache[key] = _intern(v)
							out.append([cache[key], op, i, j])
		return out

	## Adds pieces after the given signals (none of which gives every output)
	## until every output is given or the limit is reached.
	func _dfs(signals: Array, used: int, limit: int, last: int) -> bool:
		nodes += 1
		if nodes > SEARCH_NODES:
			gave_up = true
			return false
		var state := PackedInt32Array()
		for s in signals:
			state.append(s[0])
		state.sort()
		state.append(last)
		if visited.has(state):
			return false
		visited[state] = true
		var unmet := _unmet(signals)
		var have := {}
		for s in signals:
			have[s[0]] = true
		var last_index := signals.size() - 1 if last >= 0 else -1
		for g in _gates(signals):
			if have.has(g[0]):
				continue
			var takes_last: bool = last_index >= 0 and (g[2] == last_index or g[3] == last_index)
			if not takes_last and g[0] < last:
				continue
			signals.append(g)
			var done := true
			for t in unmet:
				if not _meets(g[0], t):
					done = false
					break
			if done:
				_record(signals)
				return true
			if used + 1 < limit:
				if _dfs(signals, used + 1, limit, g[0]):
					return true
				if gave_up:
					return false
			signals.pop_back()
		return false

	## {"cost": the cheapest count, or -1 if none was found, "machine": one
	## formula per output, "ruled_out": every count up to this has no machine}.
	func cheapest(max_cost: int) -> Dictionary:
		var start := []
		for i in n:
			var colors := []
			for k in size:
				colors.append((k / int(pow(8, i))) % 8)
			start.append([_intern(from_colors(colors)), "in", i, -1])
		if _unmet(start).is_empty():
			_record(start)
			return {"cost": 0, "machine": found, "ruled_out": -1}
		for limit in range(1, max_cost + 1):
			visited = {}
			if _dfs(start.duplicate(), 0, limit, -1):
				return {"cost": limit, "machine": found, "ruled_out": limit - 1}
			if gave_up:
				return {"cost": -1, "machine": [], "ruled_out": limit - 1}
		return {"cost": -1, "machine": [], "ruled_out": max_cost}


## Prices a recipe in a kit: a hand-built machine, then the search for anything
## cheaper. {"ok", "low", "high", "machine", "counts"}: low == high means
## proven cheapest.
func price(recipe: Dictionary, has_filter: bool, ops: Array) -> Dictionary:
	var pieces := []
	for op in ops:
		pieces.append(op)
	var hand := check_recipe(recipe, has_filter, false, pieces)
	var high: int = hand["cost"]["total"]
	var n: int = recipe["inputs"]
	var s := Search.new(n, ops)
	var columns := []
	for o in recipe["spec"].call(digits(0, n)).size():
		columns.append([])
	var cares := []
	for k in s.size:
		var v := digits(k, n)
		var ok: bool = recipe["domain"].call(v)
		cares.append(ok)
		var want: Array = recipe["spec"].call(v)
		for o in columns.size():
			columns[o].append(want[o] if ok else 0)
	for col in columns:
		s.want(col, cares)
	var r := s.cheapest(high)
	if r["cost"] >= 0:
		return {"ok": hand["ok"], "low": r["cost"], "high": r["cost"], "machine": "; ".join(r["machine"]), "counts": hand["cost"]}
	var low: int = r["ruled_out"] + 1
	var machine := ""
	if low == high:
		# Everything cheaper was ruled out, so the hand-built machine is cheapest.
		var parts := []
		for e in hand["outs"]:
			parts.append(formula(e))
		machine = "; ".join(parts)
	return {"ok": hand["ok"], "low": low, "high": high, "machine": machine, "counts": hand["cost"]}


func price_text(p: Dictionary) -> String:
	if p["low"] == p["high"]:
		return "**%d**" % p["high"]
	return "%d–%d" % [p["low"], p["high"]]


## The cheapest machine if proven, else what the hand-built one uses.
func machine_text(p: Dictionary) -> String:
	if p["machine"] != "":
		return "`%s`" % p["machine"]
	return "hand-built: " + cost_text(p["counts"]).replace("**", "")


# ---------------------------------------------------------------------------
# The pieces in the game: every-paint tables and laws
# ---------------------------------------------------------------------------

static func game(op: String, ins: Array) -> int:
	return GamePieces.apply(op, ins)[0]


static func g_mix(a: int, b: int) -> int:
	return game("mix", [a, b])


static func g_filter(a: int, b: int) -> int:
	return game("filter", [a, b])


static func g_inv(a: int) -> int:
	return game("invert", [a])


static func g_shift(a: int) -> int:
	return game("shift", [a])


## Laws the pieces obey, each checked on every paint (v holds three paints).
func laws() -> Array:
	return [
		{"law": "Order doesn't matter: Mix(a, b) = Mix(b, a), and the same for Filter.",
			"f": func(v): return g_mix(v[0], v[1]) == g_mix(v[1], v[0]) and g_filter(v[0], v[1]) == g_filter(v[1], v[0])},
		{"law": "Grouping doesn't matter: Mix(Mix(a, b), c) = Mix(a, Mix(b, c)), and the same for Filter. So a Mix or Filter of any number of paints is well defined.",
			"f": func(v): return g_mix(g_mix(v[0], v[1]), v[2]) == g_mix(v[0], g_mix(v[1], v[2])) and g_filter(g_filter(v[0], v[1]), v[2]) == g_filter(v[0], g_filter(v[1], v[2]))},
		{"law": "Doubling changes nothing: Mix(a, a) = Filter(a, a) = a.",
			"f": func(v): return g_mix(v[0], v[0]) == v[0] and g_filter(v[0], v[0]) == v[0]},
		{"law": "White changes nothing in a Mix and wipes out a Filter; Black changes nothing in a Filter and fills a Mix.",
			"f": func(v): return g_mix(v[0], Paint.WHITE) == v[0] and g_filter(v[0], Paint.WHITE) == Paint.WHITE and g_filter(v[0], Paint.BLACK) == v[0] and g_mix(v[0], Paint.BLACK) == Paint.BLACK},
		{"law": "Absorption: Mix(a, Filter(a, b)) = a and Filter(a, Mix(a, b)) = a.",
			"f": func(v): return g_mix(v[0], g_filter(v[0], v[1])) == v[0] and g_filter(v[0], g_mix(v[0], v[1])) == v[0]},
		{"law": "Each spreads over the other: Filter(a, Mix(b, c)) = Mix(Filter(a, b), Filter(a, c)), and with Mix and Filter swapped.",
			"f": func(v): return g_filter(v[0], g_mix(v[1], v[2])) == g_mix(g_filter(v[0], v[1]), g_filter(v[0], v[2])) and g_mix(v[0], g_filter(v[1], v[2])) == g_filter(g_mix(v[0], v[1]), g_mix(v[0], v[2]))},
		{"law": "Opposites: Invert(Invert(a)) = a; Mix(a, Invert(a)) = Black; Filter(a, Invert(a)) = White.",
			"f": func(v): return g_inv(g_inv(v[0])) == v[0] and g_mix(v[0], g_inv(v[0])) == Paint.BLACK and g_filter(v[0], g_inv(v[0])) == Paint.WHITE},
		{"law": "De Morgan: Invert(Mix(a, b)) = Filter(Invert(a), Invert(b)) and Invert(Filter(a, b)) = Mix(Invert(a), Invert(b)). (Keep What They Share and Mix Without Mix.)",
			"f": func(v): return g_inv(g_mix(v[0], v[1])) == g_filter(g_inv(v[0]), g_inv(v[1])) and g_inv(g_filter(v[0], v[1])) == g_mix(g_inv(v[0]), g_inv(v[1]))},
		{"law": "Three Shifts make a full turn: Shift(Shift(Shift(a))) = a. Two Shifts turn the wheel back one step.",
			"f": func(v): return g_shift(g_shift(g_shift(v[0]))) == v[0]},
		{"law": "Shift leaves only White and Black as they are.",
			"f": func(v): return (g_shift(v[0]) == v[0]) == (v[0] == Paint.WHITE or v[0] == Paint.BLACK)},
		{"law": "Shift respects the other pieces: Shift(Mix(a, b)) = Mix(Shift(a), Shift(b)), the same for Filter, and Shift(Invert(a)) = Invert(Shift(a)). (So without a pot nothing can tell the primaries apart.)",
			"f": func(v): return g_shift(g_mix(v[0], v[1])) == g_mix(g_shift(v[0]), g_shift(v[1])) and g_shift(g_filter(v[0], v[1])) == g_filter(g_shift(v[0]), g_shift(v[1])) and g_shift(g_inv(v[0])) == g_inv(g_shift(v[0]))},
		{"law": "Mix can't be undone: Mix(a, b) = Mix(a, c) doesn't mean b = c (Mix(Red, Orange) = Mix(Red, Yellow)). Neither can Filter (Filter(Red, Orange) = Filter(Red, Purple)). Invert and Shift can: different paints in, different paints out.",
			"f": func(v): return g_mix(Paint.RED, Paint.ORANGE) == g_mix(Paint.RED, Paint.YELLOW) and g_filter(Paint.RED, Paint.ORANGE) == g_filter(Paint.RED, Paint.PURPLE) and (v[0] == v[1] or (g_inv(v[0]) != g_inv(v[1]) and g_shift(v[0]) != g_shift(v[1])))},
	]


# ---------------------------------------------------------------------------
# Future work: candidate pieces buildable today
# ---------------------------------------------------------------------------

func _pop(c: int) -> int:
	return (c & 1) + ((c >> 1) & 1) + ((c >> 2) & 1)


func _yes(b: bool) -> int:
	return Paint.BLACK if b else Paint.WHITE


func _r_any_paint(p: Pieces, i: Array) -> Array:
	return [p.any_paint(i[0])]

func _r_is_white(p: Pieces, i: Array) -> Array:
	return [p.inv(p.any_paint(i[0]))]

func _r_is_black(p: Pieces, i: Array) -> Array:
	return [p.all_paint(i[0])]

func _r_odd(p: Pieces, i: Array) -> Array:
	var s1 = p.shift(i[0])
	return [p.contrast(p.contrast(i[0], s1), p.shift(s1))]

func _r_contains(p: Pieces, i: Array) -> Array:
	return [p.all_paint(p.mix(i[0], p.inv(i[1])))]

func _r_settle(p: Pieces, i: Array) -> Array:
	return [p.settle(i[0])]

func _r_darker(p: Pieces, i: Array) -> Array:
	return [p.any_paint(p.bleach(p.settle(i[0]), p.settle(i[1])))]

func _r_turn_back(p: Pieces, i: Array) -> Array:
	return [p.shift(p.shift(i[0]))]

func _r_mirror(p: Pieces, i: Array) -> Array:
	var reds = p.filter(i[0], p.pot(0))
	var blues = p.filter(i[0], p.pot(2))
	return [p.mix(p.mix(p.filter(i[0], p.pot(1)), p.shift(p.shift(reds))), p.shift(blues))]

func _r_same_paint(p: Pieces, i: Array) -> Array:
	return [p.mix(p.filter(i[0], i[1]), p.inv(p.mix(i[0], i[1])))]

func _r_stencil(p: Pieces, i: Array) -> Array:
	return [p.mix(p.filter(i[0], i[2]), p.filter(i[1], p.inv(i[2])))]

func _r_gate(p: Pieces, i: Array) -> Array:
	return [p.filter(i[1], p.any_paint(i[0]))]

func _r_choose(p: Pieces, i: Array) -> Array:
	var any = p.any_paint(i[0])
	return [p.mix(p.filter(i[1], p.inv(any)), p.filter(i[2], any))]

func _r_sort(p: Pieces, i: Array) -> Array:
	return [p.filter(i[0], i[1]), p.mix(i[0], i[1])]

func _r_half(p: Pieces, i: Array) -> Array:
	var both = p.filter(i[0], i[1])
	return [both, p.filter(p.mix(i[0], i[1]), p.inv(both))]


func _s_any_paint(v: Array) -> Array:
	return [_yes(v[0] != Paint.WHITE)]

func _s_is_white(v: Array) -> Array:
	return [_yes(v[0] == Paint.WHITE)]

func _s_is_black(v: Array) -> Array:
	return [_yes(v[0] == Paint.BLACK)]

func _s_odd(v: Array) -> Array:
	return [_yes(_pop(v[0]) % 2 == 1)]

func _s_contains(v: Array) -> Array:
	return [_yes((v[1] & ~v[0] & 7) == 0)]

func _s_settle(v: Array) -> Array:
	return [[Paint.WHITE, Paint.RED, Paint.ORANGE, Paint.BLACK][_pop(v[0])]]

func _s_darker(v: Array) -> Array:
	return [_yes(_pop(v[0]) > _pop(v[1]))]

func _s_turn_back(v: Array) -> Array:
	return [Paint.shift(Paint.shift(v[0]))]

func _s_mirror(v: Array) -> Array:
	return [(v[0] & Paint.YELLOW) | ((v[0] & Paint.RED) << 2) | ((v[0] & Paint.BLUE) >> 2)]

func _s_same_paint(v: Array) -> Array:
	return [Paint.invert(Paint.contrast(v[0], v[1]))]

func _s_stencil(v: Array) -> Array:
	return [(v[0] & v[2]) | (v[1] & ~v[2] & 7)]

func _s_gate(v: Array) -> Array:
	return [v[1] if v[0] != Paint.WHITE else Paint.WHITE]

func _s_choose(v: Array) -> Array:
	return [v[1] if v[0] == Paint.WHITE else v[2]]

func _s_sort(v: Array) -> Array:
	return [v[0] & v[1], v[0] | v[1]]

func _s_half(v: Array) -> Array:
	return [v[0] & v[1], v[0] ^ v[1]]


## Candidate pieces for later chapters. Each is a plain function of its
## inputs, so today's rules can build it; "family" groups them as DESIGN.md
## 2.3 does.
func candidates() -> Array:
	return [
		{"family": "Questions", "name": "Any Paint?", "shape": "1 -> 1", "what": "Black if the paint isn't white, otherwise White.", "inputs": 1, "build": _r_any_paint, "spec": _s_any_paint, "domain": _d_all},
		{"family": "Questions", "name": "Is It White?", "shape": "1 -> 1", "what": "Black if the paint is white, otherwise White. The condition an If White brancher reads.", "inputs": 1, "build": _r_is_white, "spec": _s_is_white, "domain": _d_all},
		{"family": "Questions", "name": "Is It Black?", "shape": "1 -> 1", "what": "Black only if the paint is black.", "inputs": 1, "build": _r_is_black, "spec": _s_is_black, "domain": _d_all},
		{"family": "Questions", "name": "Odd Paint?", "shape": "1 -> 1", "what": "Black if the paint has one or three primaries (a primary or black).", "inputs": 1, "build": _r_odd, "spec": _s_odd, "domain": _d_all},
		{"family": "Questions", "name": "Contains?", "shape": "2 -> 1", "what": "Black if the first paint has every primary of the second.", "inputs": 2, "build": _r_contains, "spec": _s_contains, "domain": _d_all},
		{"family": "Counting", "name": "Settle", "shape": "1 -> 1", "what": "Keeps how much paint, drops which: none White, one primary Red, two Orange, three Black.", "inputs": 1, "build": _r_settle, "spec": _s_settle, "domain": _d_all},
		{"family": "Counting", "name": "Darker?", "shape": "2 -> 1", "what": "Black if the first paint has more primaries than the second.", "inputs": 2, "build": _r_darker, "spec": _s_darker, "domain": _d_all},
		{"family": "Wheel", "name": "Turn Back", "shape": "1 -> 1", "what": "Turns the wheel one step the other way.", "inputs": 1, "build": _r_turn_back, "spec": _s_turn_back, "domain": _d_all},
		{"family": "Wheel", "name": "Mirror", "shape": "1 -> 1", "what": "Swaps red and blue, keeps yellow. With Shift it makes every reordering of the primaries.", "inputs": 1, "build": _r_mirror, "spec": _s_mirror, "domain": _d_all},
		{"family": "Paint-like", "name": "Same Paint", "shape": "2 -> 1", "what": "The primaries both paints have or both lack.", "inputs": 2, "build": _r_same_paint, "spec": _s_same_paint, "domain": _d_all},
		{"family": "Paint-like", "name": "Stencil", "shape": "3 -> 1", "what": "Each primary from A where the stencil C has it, from B where it doesn't.", "inputs": 3, "build": _r_stencil, "spec": _s_stencil, "domain": _d_all},
		{"family": "Choosing", "name": "Gate", "shape": "2 -> 1", "what": "The paint B if the control A has any paint, otherwise White.", "inputs": 2, "build": _r_gate, "spec": _s_gate, "domain": _d_all},
		{"family": "Choosing", "name": "Choose", "shape": "3 -> 1", "what": "B if the control A is white, otherwise C.", "inputs": 3, "build": _r_choose, "spec": _s_choose, "domain": _d_all},
		{"family": "Several outputs", "name": "Sort", "shape": "2 -> 2", "what": "What both share out of the top, everything in either out of the bottom. Three Sorts give the lightest, middle and darkest of three paints, primary by primary (the middle is Consensus).", "inputs": 2, "build": _r_sort, "spec": _s_sort, "domain": _d_all},
		{"family": "Several outputs", "name": "Share and Differ", "shape": "2 -> 2", "what": "What both share, and what only one has.", "inputs": 2, "build": _r_half, "spec": _s_half, "domain": _d_all},
	]


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
	var game_ops := ["red", "mix", "filter", "invert", "shift"]
	var no_filter_ops := ["red", "mix", "invert", "shift"]

	w("# Chromaton color algebra notes")
	w()
	w("Generated by `tools/algebra_check.gd` on %s. Rerun it after changing pieces or recipes: `.\\make algebra`." % Time.get_date_string_from_system())
	w()
	w("Internal design document: it talks about primaries as separate lanes and borrows logic-design names, which the player never needs to see. Every table and law here is checked by the script on every paint; a piece added to `core/pieces.gd` without an entry here fails the check. Design decisions live in DESIGN.md; this file is the evidence.")
	w()
	w("1. [The paints](#1-the-paints)")
	w("2. [The pieces in the game today](#2-the-pieces-in-the-game-today)")
	w("3. [The base kit: NOR, Shift and one Red pot](#3-the-base-kit-nor-shift-and-one-red-pot)")
	w("4. [Candidate starting kits](#4-candidate-starting-kits)")
	w("5. [End-to-end: random machines built from each complete kit](#5-end-to-end-random-machines-built-from-each-complete-kit)")
	w("6. [Recipe catalog: the inventions DESIGN.md specs](#6-recipe-catalog-the-inventions-designmd-specs)")
	w("7. [Future work](#7-future-work)")
	w()

	# --- 1. paints ---
	w("## 1. The paints")
	w()
	w("A paint is the set of primaries in it, so there are exactly eight. With Mix, Filter and Invert they form a Boolean algebra (the subsets of {red, yellow, blue}); Shift is one of its symmetries.")
	w()
	w("| Paint | Primaries | Opposite (Invert) | Shifted |")
	w("|---|---|---|---|")
	for c in Paint.ALL:
		var prims := []
		for p in Paint.PRIMARIES:
			if c & p:
				prims.append(Paint.name_of(p).to_lower())
		w("| %s | %s | %s | %s |" % [Paint.name_of(c), ", ".join(prims) if not prims.is_empty() else "none", Paint.name_of(g_inv(c)), Paint.name_of(g_shift(c))])
	w()

	# --- 2. pieces ---
	w("## 2. The pieces in the game today")
	w()
	w("From `core/pieces.gd`. Splits and catch pots are free; every other piece costs 1.")
	w()
	w("| Piece | In -> out | Cost | What it does |")
	w("|---|---|---|---|")
	for kind in GamePieces.TABLE:
		var e: Dictionary = GamePieces.TABLE[kind]
		if not PIECE_NOTES.has(kind):
			fail("piece %s has no entry in PIECE_NOTES" % kind)
		w("| %s | %d -> %d | %d | %s |" % [e["name"], e["inputs"], e["outputs"], e["cost"], PIECE_NOTES.get(kind, "**missing**")])
	w("| Pattern card | 0 -> 1 | 0 | Part of the level: releases its next color whenever its tube is free. Every card must be used. |")
	w("| Loom | 1 -> 0 | 0 | Part of the level: weaves one drop per tick; the first wrong stitch stops the run. |")
	w("| Invention | n -> 1 | its inside | A solved machine as one piece: its cards become inputs, its loom the one output. Takes one tick and looks its answer up, which the every-paint check makes exact. |")
	w()
	w("What the one-input pieces do to every paint:")
	w()
	var head := "| Piece |"
	var rule := "|---|"
	for c in Paint.ALL:
		head += " %s |" % Paint.name_of(c)
		rule += "---|"
	w(head)
	w(rule)
	for kind in GamePieces.TABLE:
		var e: Dictionary = GamePieces.TABLE[kind]
		if e["inputs"] != 1 or e["outputs"] != 1 or e["cost"] == 0:
			continue
		var row := "| %s |" % e["name"]
		for c in Paint.ALL:
			row += " %s |" % Paint.name_of(game(e["op"], [c]))
		w(row)
	w()
	for kind in GamePieces.TABLE:
		var e: Dictionary = GamePieces.TABLE[kind]
		if e["inputs"] != 2:
			continue
		w("%s (first paint down the side, second across the top):" % e["name"])
		w()
		w(head.replace("Piece", e["name"]))
		w(rule)
		for a in Paint.ALL:
			var row := "| **%s** |" % Paint.name_of(a)
			for b in Paint.ALL:
				row += " %s |" % Paint.name_of(game(e["op"], [a, b]))
			w(row)
		w()
	w("Laws the pieces obey, each checked on every combination of paints. Puzzles can lean on them; several levels are one law in disguise.")
	w()
	for law in laws():
		var holds := true
		for k in 512:
			if not law["f"].call(digits(k, 3)):
				holds = false
				break
		if not holds:
			fail("law broken: " + law["law"])
		w("- %s %s" % ["✓" if holds else "**BROKEN:**", law["law"]])
	w()

	# --- 3. base kit ---
	w("## 3. The base kit: NOR, Shift and one Red pot")
	w()
	w("NOR is Invert after Mix, as a single vat. The argument that these three build any machine, whatever its number of inputs:")
	w()
	w("1. **Pots:** White = NOR(Red, NOR(Red, Red)). Yellow = Shift(Red), Blue = Shift(Yellow). Any color is a Mix of those.")
	w("2. **Paint logic within each primary:** NOR alone builds Invert, Mix and Filter, applied to each primary separately.")
	w("3. **Moving paint between primaries:** \"Any Red?\" = Filter(x, Red), then Mix it with its Shift and its double Shift. The result is Black if x has red, White if not. Same for yellow and blue.")
	w("4. **Any machine:** for every input combination that should give paint, test \"is input 1 exactly this color, input 2 exactly that color, ...\" with the step-3 answers and Filter, keep the wanted color with Filter, and Mix all those terms together.")
	w()
	w("The checker builds every step from real pieces and runs them on every possible input, then does the same for whole random machines (section 5).")
	w()

	# --- 4. kits ---
	w("## 4. Candidate starting kits")
	w()
	w("The game's kit (DESIGN.md 2.5) is Red pot, Mix, Filter, Invert and Shift: complete, since it holds the second kit below.")
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

	# --- 5. end to end ---
	w("## 5. End-to-end: random machines built from each complete kit")
	w()
	w("Each random machine is a random table of outputs, built with the generic construction from section 3 using only the kit's own pieces, then run on every input and compared with the table. Piece counts are for the generic construction, which is far from optimal: they show that building is possible, not what a clever player would need.")
	w()
	w("| Kit | Machines matching their table | Avg pieces, 1 input | Avg pieces, 2 inputs | Pieces, 3 inputs |")
	w("|---|---|---|---|---|")
	for kit in complete_kits:
		var r := end_to_end(kit, rng)
		if r["passed"] != r["total"]:
			fail("end-to-end mismatch for " + kit["name"])
		w("| %s | %d / %d | %d | %d | %d |" % [kit["name"], r["passed"], r["total"], average(r["sizes"][1]), average(r["sizes"][2]), average(r["sizes"][3])])
	w()

	# --- 6. catalog ---
	w("## 6. Recipe catalog: the inventions DESIGN.md specs")
	w()
	w("Priced in two trays: **the game's kit** (Red pot, Mix, Filter, Invert, Shift, free Split) and **without Filter** (chapter 3's Invent What You Know trays, and the old lean kit). Each recipe has a hand-built machine, checked on every input it is meant for. A search then tries every machine of the tray's pieces, cheapest first, and stops after %d steps per price. **A bold count is proven cheapest**, with a cheapest machine shown. A range means the search ruled out every machine below its low end before it stopped, and the high end is the hand-built machine. The full kit with three basic pots was dropped (DESIGN.md 2.5); a pot invention costs what its machine does, so it changes no price." % SEARCH_NODES)
	w()
	w("| Recipe | In -> out | What it does | Game kit | Cheapest in the game kit | Without Filter |")
	w("|---|---|---|---|---|---|")
	for recipe in recipes():
		var t0 := Time.get_ticks_msec()
		var g := price(recipe, true, game_ops)
		var l := price(recipe, false, no_filter_ops)
		if not g["ok"]:
			fail("recipe %s is wrong in the game kit" % recipe["name"])
		if not l["ok"]:
			fail("recipe %s is wrong without Filter" % recipe["name"])
		w("| %s | %s | %s | %s | %s | %s |" % [recipe["name"], recipe["shape"], recipe["what"], price_text(g), machine_text(g), price_text(l)])
		print("%-22s game %s  no filter %s  (%.1f s)" % [recipe["name"], price_text(g).replace("*", ""), price_text(l).replace("*", ""), (Time.get_ticks_msec() - t0) / 1000.0])
	w()

	# --- 7. future work ---
	w("## 7. Future work")
	w()
	w("Not decided: candidates for the designer, grouped by the families of DESIGN.md 2.3 and by what logic design calls them.")
	w()
	w("### 7.1 Candidate pieces today's rules can build")
	w()
	w("Each is a plain function of its inputs, so it could be an invention level today; pieces with two or more outputs need an invention level with more than one loom first (7.2). Priced in the game's kit, the same way as section 6. Questions answer Black for yes and White for no, the form an If White brancher (7.2) would read.")
	w()
	w("| Family | Candidate | In -> out | What it does | Game kit | Cheapest machine |")
	w("|---|---|---|---|---|---|")
	for cand in candidates():
		var t0 := Time.get_ticks_msec()
		var g := price(cand, true, game_ops)
		if not g["ok"]:
			fail("candidate %s is wrong in the game kit" % cand["name"])
		w("| %s | %s | %s | %s | %s | %s |" % [cand["family"], cand["name"], cand["shape"], cand["what"], price_text(g), machine_text(g)])
		print("%-22s game %s  (%.1f s)" % [cand["name"], price_text(g).replace("*", ""), (Time.get_ticks_msec() - t0) / 1000.0])
	w()
	w("Logic-design names, for reference: Any Paint? is an OR of the primaries, Is It Black? an AND, Odd Paint? parity, Contains? subset (implication), Same Paint XNOR, Stencil a per-primary multiplexer, Choose a whole-paint multiplexer (if-then-else), Gate an enable, Sort a compare-exchange (the step of a sorting network), Share and Differ a half adder (carry and sum), Settle a thermometer code (popcount), Darker? a magnitude comparator.")
	w()
	w("### 7.2 What today's rules can't build")
	w()
	w("With one-drop tubes every piece takes one drop per input and gives one per output, and a loop waits on itself, so every machine weaves stitch i from the cards' i-th drops: a pure function. That is what lets the solver prove star counts and an invention run as a one-tick lookup. Four families need more:")
	w()
	w("| Family | Logic ancestor | Smallest new piece | Rule change | What it opens up |")
	w("|---|---|---|---|---|")
	w("| **Memory** | D flip-flop, register | **Delay** (1 -> 1): gives the drop it got last time; starts holding a preset paint (White, or one the player taps in) | None to the firing rule: it fires like any one-input piece and starts with a drop in its output tube (an initial token, as in synchronous dataflow). A loop becomes legal when it passes through a Delay. An invention with Delays becomes a state table (state and inputs to new state and output); the every-paint check covers every state. | Toggle (Invert in a loop: alternates), ring counter (Shift in a loop: red, yellow, blue), running Mix (everything so far), change detector (Contrast of a drop and the one before), Keeper (a register: Stencil fed back through a Delay, written where the enable has paint), rows that grow from the row before (cellular automata, DESIGN.md 5.5). Combinational pieces plus Delays build every finite-state machine. |")
	w("| **Branching** | Demultiplexer, conditional jump | **If White** (2 -> 2): a control drop and a paint drop; the paint leaves by the top exit if the control is white, by the bottom otherwise, and the other exit gets nothing. Wired with the same drop on both inputs, a drop routes itself. | A piece fires when the exit it will use is free. Stitch i no longer comes from the cards' drop i, so the solver needs a stream model and an invention must record which exit fires. Needs **Merge** (2 -> 1, oldest drop first, top on ties) and the Catch pot back as a bin. | Removing smudges instead of recoloring them, sorting streams, dedupe, counting, buffer puzzles (DESIGN.md 5.4). The Questions in 7.1 become its conditions. |")
	w("| **Register-like cards** | Register file, FIFO, delay-line memory | **Slate** (1 -> 1): a card with an input port; the machine writes drops in on its left and reads them out in order on its right. It can start blank or with paint. | A card that can be written, and a loom or level that waits for it. | Two-pass machines, reversing a row, the Jacquard card chain as a loop of cards (a long delay), output cards a later level reads back. |")
	w("| **Several outputs** | Multi-output blocks (decoders, adders) | An invention level with two or three looms; each loom becomes an output port, in loom order | Today an invention has exactly one output (`core/pieces.gd` ports). | Prism, Sort, Share and Differ, the Three-way Switch. |")
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
