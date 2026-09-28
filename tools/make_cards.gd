## Derives each level's pattern cards from its target picture.
##
## Run from the project folder:
##   godot_console --headless --path . --script res://tools/make_cards.gd
## For every level with a "card_rule", picks card colors so that the rule's
## machine weaves the target, and rewrites the level's "cards". Choices are
## pseudo-random but fixed by the level id, so reruns give the same cards.
## The first row is then chosen, among the rule's options, so that every
## cheap wrong machine (within the level's two-star budget) fails in it if it
## can; each level's line in the output says how many get further.
##
## Rules (t = target stitch):
##   copy         one card: t itself (the card tubed straight to the loom weaves t)
##   remove_red  one card: t without its red (a Mix with the red pot weaves t)
##   unshift      one card: t turned back one step (a Shift weaves t)
##   any_red      one card: Red where t is Black, White elsewhere
##   invert       one card: the opposite of t
##   third_color  two cards: the two primaries t is not, in random order
##   filter       two cards that share exactly t
##   bleach       two cards: the first minus the second's paint is t
##   smudges      one card: t with stray yellow on about a third of the stitches
##                (at least one in the first row); also writes the card's
##                "smudges", the stitches that carry stray paint
##   missing      two cards that share exactly the opposite of t
##   mix          two cards whose mix is t
##   contrast     two cards: the first random, the second holding the primaries
##                in exactly one of t and the first
##   two_of_three three cards: a primary is in t exactly when two or more cards have it
extends SceneTree

const Paint = preload("res://core/paint.gd")
const Level = preload("res://core/level.gd")

const CARD_COUNT := {
	"copy": 1, "remove_red": 1, "unshift": 1, "any_red": 1, "invert": 1,
	"smudges": 1, "third_color": 2, "filter": 2, "bleach": 2, "missing": 2,
	"mix": 2, "contrast": 2, "two_of_three": 3,
}
const NAMES := ["A", "B", "C"]


func _init() -> void:
	var ids := Level.index_ids()
	var failures := 0
	for level_id in ids:
		var path := "res://levels/%s.json" % level_id
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var rule: String = d.get("card_rule", "")
		if rule == "":
			continue
		var width := str(d["target"][0]).length()
		var target := Level.parse_rows(d["target"])
		var salt := hash(str(level_id)) & 0xffff
		var cols := []
		for k in CARD_COUNT[rule]:
			cols.append([])
		for i in target.size():
			var picked := derive(rule, target[i], i, salt)
			if picked.is_empty():
				printerr("%s: rule %s cannot make %s at stitch %d" % [level_id, rule, Paint.name_of(target[i]), i])
				failures += 1
				picked = []
				for k in CARD_COUNT[rule]:
					picked.append(0)
			for k in picked.size():
				cols[k].append(picked[k])
		var note := order_first_row(rule, d, target, width, salt, cols)
		if rule == "smudges":
			# The first row always shows a smudge, so the lesson starts at once.
			var first := range(width).filter(func(i): return cols[0][i] != target[i])
			if first.is_empty():
				var j := rnd(0, salt, 8) % width
				cols[0][j] = target[j] | Paint.YELLOW
		var cards := []
		for k in cols.size():
			cards.append({"name": NAMES[k], "colors": Level.letters(PackedByteArray(cols[k]), width)})
		if rule == "smudges":
			cards[0]["smudges"] = range(target.size()).filter(func(i): return cols[0][i] != target[i])
		d["cards"] = cards
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_ints(d), "\t", false) + "\n")
		print("%s: %d card(s) written%s" % [level_id, cards.size(), note])
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------
# First-row ordering: cheap wrong machines should fail within the first row
# ---------------------------------------------------------------------------

const LANES := 20  # paints packed per int (3 flags each)
const OPTION_TRIES := 24  # rerolls of the rule per first-row stitch

var chunks := 0
var full_mask := PackedInt64Array()
var low_mask := PackedInt64Array()
var high_mask := PackedInt64Array()


## Rerolls the rule for each stitch of the first row and keeps, stitch by
## stitch, the card paints that make the most cheap wrong machines fail
## there (greedy). Rows below stay as derived. A cheap machine is any the
## level's pieces build within its two-star budget. Returns a report note.
func order_first_row(rule: String, d: Dictionary, target: PackedByteArray, width: int, salt: int, cols: Array) -> String:
	var n: int = cols.size()
	# The paints each first-row stitch may take (the derived one first).
	var options := []
	var choices := 0
	for p in width:
		var seen := {}
		var opts := []
		for s in OPTION_TRIES:
			var pick: Array = derive(rule, target[p], p, salt + s * 7919) if s > 0 else range(n).map(func(k): return cols[k][p])
			var x := combo_index(pick)
			if not pick.is_empty() and not seen.has(x):
				seen[x] = true
				opts.append(x)
		options.append(opts)
		choices += opts.size() - 1
	if choices == 0:
		return ""
	var funcs := cheap_functions(d.get("pieces", []), n, int(d["stars"]["budget"]))
	# Wrong machines: wrong on some stitch below the first row, or on some option.
	var below := []
	for i in range(width, target.size()):
		below.append(combo_index(range(n).map(func(k): return cols[k][i])))
	var alive := []
	for f in funcs:
		var wrong := false
		for j in below.size():
			if at(f, below[j]) != target[width + j]:
				wrong = true
				break
		for p in width:
			for x in options[p]:
				wrong = wrong or at(f, x) != target[p]
		if wrong:
			alive.append(f)
	var total := alive.size()
	var assigned := {}
	while assigned.size() < width and not alive.is_empty():
		var best_kill := 0
		var best_p := -1
		var best_x := -1
		for p in width:
			if assigned.has(p):
				continue
			for x in options[p]:
				var kill := 0
				for f in alive:
					if at(f, x) != target[p]:
						kill += 1
				if kill > best_kill:
					best_kill = kill
					best_p = p
					best_x = x
		if best_kill == 0:
			break
		assigned[best_p] = best_x
		alive = alive.filter(func(f): return at(f, best_x) == target[best_p])
	for p in assigned:
		var x: int = assigned[p]
		for k in n:
			cols[k][p] = (x >> (3 * k)) & 7
	if alive.is_empty():
		return " (%d cheap wrong machines, all fail in the first row)" % total
	# Where the rest fail (some may fit these cards after all: other answers).
	var last := 0
	var fitting := 0
	for f in alive:
		var fails := -1
		for j in below.size():
			if at(f, below[j]) != target[width + j]:
				fails = width + j
				break
		if fails < 0:
			fitting += 1
		last = maxi(last, fails)
	return " (%d cheap wrong machines; %d get past the first row, the last fails at stitch %d; %d fit these cards)" % [total, alive.size(), last + 1, fitting]


## Combination index of one paint per card: card k's paint counts 8^k.
static func combo_index(paints: Array) -> int:
	var x := 0
	for k in range(paints.size() - 1, -1, -1):
		x = x * 8 + int(paints[k])
	return x


## A function's paint for combination x.
static func at(f: PackedInt64Array, x: int) -> int:
	return (f[x / LANES] >> (3 * (x % LANES))) & 7


## Every function of n cards the pieces build for at most `budget` pieces,
## as packed tables over all combinations of card paints. Formula trees with
## cards and the red pot free to reuse: close to what Split allows.
func cheap_functions(pieces: Array, n: int, budget: int) -> Array:
	var size := int(pow(8, n))
	chunks = int(ceil(size / float(LANES)))
	full_mask = _const_vec(size, Paint.BLACK)
	low_mask = _const_vec(size, Paint.RED | Paint.YELLOW)
	high_mask = _const_vec(size, Paint.BLUE)
	var seen := {}
	var by_cost := [[]]
	for k in n:
		var col := []
		for x in size:
			col.append((x >> (3 * k)) & 7)
		var v := _pack(col)
		seen[v] = true
		by_cost[0].append(v)
	for cost in range(1, budget + 1):
		var made := []
		var add := func(v: PackedInt64Array):
			if not seen.has(v):
				seen[v] = true
				made.append(v)
		if cost == 1 and "red_pot" in pieces:
			add.call(_const_vec(size, Paint.RED))
		for f in by_cost[cost - 1]:
			if "invert" in pieces:
				add.call(_unary("invert", f))
			if "shift" in pieces:
				add.call(_unary("shift", f))
		for a in cost:
			var b := cost - 1 - a
			if b < a:
				break
			for i in by_cost[a].size():
				for j in range(i if a == b else 0, by_cost[b].size()):
					if "mix" in pieces:
						add.call(_binary("mix", by_cost[a][i], by_cost[b][j]))
					if "filter" in pieces:
						add.call(_binary("filter", by_cost[a][i], by_cost[b][j]))
		by_cost.append(made)
	var out := []
	for fs in by_cost:
		out.append_array(fs)
	return out


func _unary(op: String, a: PackedInt64Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(chunks)
	for c in chunks:
		if op == "invert":
			out[c] = a[c] ^ full_mask[c]
		else:
			out[c] = ((a[c] & low_mask[c]) << 1) | ((a[c] & high_mask[c]) >> 2)
	return out


func _binary(op: String, a: PackedInt64Array, b: PackedInt64Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(chunks)
	for c in chunks:
		out[c] = (a[c] | b[c]) if op == "mix" else (a[c] & b[c])
	return out


func _pack(colors: Array) -> PackedInt64Array:
	var out := PackedInt64Array()
	out.resize(chunks)
	out.fill(0)
	for i in colors.size():
		out[i / LANES] = out[i / LANES] | (int(colors[i]) << (3 * (i % LANES)))
	return out


func _const_vec(count: int, color: int) -> PackedInt64Array:
	var col := []
	for i in count:
		col.append(color)
	return _pack(col)


static func rnd(i: int, salt: int, k: int) -> int:
	var x := (i * 7919 + salt * 104729 + k * 15485863 + 1) & 0x7fffffff
	for n in 3:
		x = (x * 1103515245 + 12345) & 0x7fffffff
		x ^= x >> 13
	return x


## A random sub-paint of p (some of its primaries).
static func sub(p: int, r: int) -> int:
	var subs := []
	for s in Paint.ALL:
		if s & p == s:
			subs.append(s)
	return subs[r % subs.size()]


## Two paints that share exactly `shared`, preferring ones that add something.
static func share(shared: int, i: int, salt: int, k: int) -> Array:
	var free := Paint.BLACK & ~shared
	for attempt in 8:
		var x := sub(free, rnd(i, salt, k + attempt * 2))
		var y := sub(free & ~x, rnd(i, salt, k + attempt * 2 + 1))
		if (x | y) != 0 or free == 0 or attempt == 7:
			if rnd(i, salt, k + 40) & 1:
				return [shared | x, shared | y]
			return [shared | y, shared | x]
	return []


static func derive(rule: String, t: int, i: int, salt: int) -> Array:
	match rule:
		"copy":
			return [t]
		"remove_red":
			return [t & ~Paint.RED] if t & Paint.RED else []
		"unshift":
			return [Paint.shift(Paint.shift(t))]
		"any_red":
			if t == Paint.BLACK:
				return [Paint.RED]
			return [Paint.WHITE] if t == Paint.WHITE else []
		"invert":
			return [Paint.invert(t)]
		"third_color":
			if not t in Paint.PRIMARIES:
				return []
			var others := Paint.PRIMARIES.filter(func(p): return p != t)
			if rnd(i, salt, 0) & 1:
				others.reverse()
			return others
		"filter":
			return share(t, i, salt, 0)
		"bleach":
			var b := sub(Paint.BLACK & ~t, rnd(i, salt, 1))
			if b == 0:
				b = sub(Paint.BLACK & ~t, rnd(i, salt, 2))
			return [t | sub(b, rnd(i, salt, 3)), b]
		"smudges":
			return [t | Paint.YELLOW] if rnd(i, salt, 7) % 3 == 0 else [t]
		"missing":
			return share(Paint.invert(t), i, salt, 0)
		"mix":
			var part := sub(t, rnd(i, salt, 1))
			return [part, (t & ~part) | sub(part, rnd(i, salt, 2))]
		"contrast":
			var any := rnd(i, salt, 1) % 8
			return [any, Paint.contrast(any, t)]
		"two_of_three":
			var out := [0, 0, 0]
			for p in Paint.PRIMARIES:
				var r := rnd(i, salt, 10 + p)
				var holders := []
				if t & p:
					# two cards, now and then all three
					holders = [0, 1, 2] if r % 4 == 0 else [0, 1, 2].filter(func(k): return k != (r >> 3) % 3)
				elif r % 5 >= 2:
					holders = [(r >> 3) % 3]  # one card, now and then none
				for k in holders:
					out[k] |= p
			return out
	return []


## JSON numbers come back as floats; write whole numbers as ints.
static func _ints(v):
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		return v.map(func(e): return _ints(e))
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _ints(v[k])
		return out
	return v
