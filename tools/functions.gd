## The functions of a level's cards that its pieces build cheaply, as packed
## tables over every combination of card paints. Shared by the card maker
## (tools/make_cards.gd), which picks cards so that every cheap wrong machine
## fails within the first few stitches (card_shows), and the solver (tools/level_solver.gd),
## which checks it.
##
## A table holds one paint per combination of card paints; combination x
## gives card k the paint (x >> 3k) & 7 (combo_index()).
extends RefCounted

const Paint = preload("res://core/paint.gd")

const LANES := 20  # paints packed per int (3 flags each)

var chunks := 0
var full_mask := PackedInt64Array()
var low_mask := PackedInt64Array()
var high_mask := PackedInt64Array()


## Combination index of one paint per card: card k's paint counts 8^k.
static func combo_index(paints: Array) -> int:
	var x := 0
	for k in range(paints.size() - 1, -1, -1):
		x = x * 8 + int(paints[k])
	return x


## A function's paint for combination x.
static func at(f: PackedInt64Array, x: int) -> int:
	return (f[x / LANES] >> (3 * (x % LANES))) & 7


## The combination each stitch of these cards gives.
static func stitch_combos(cards: Array, size: int) -> Array:
	var out := []
	for i in size:
		out.append(combo_index(cards.map(func(c): return c[i])))
	return out


## The first stitch where a function weaves something other than the target
## on these cards (combos from stitch_combos), or -1 if it weaves it all.
static func first_wrong(f: PackedInt64Array, combos: Array, target: PackedByteArray, from := 0) -> int:
	for i in range(from, combos.size()):
		if at(f, combos[i]) != target[i]:
			return i
	return -1


## Every function of n cards the pieces build for at most `budget` pieces.
## Formula trees with cards and pots free to reuse: close to what Split
## allows, and a superset without it. The pieces are the level's search
## operations (level_solver.gd's level_ops: basic pieces, earned pots,
## inventions, each at its price).
func cheap_functions(ops: Array, n: int, budget: int) -> Array:
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
		for o in ops:
			var k: int = o["cost"]
			if k > cost:
				continue
			match o["op"]:
				"red_pot":
					if k == cost:
						add.call(_const_vec(size, Paint.RED))
				"paint":
					if k == cost:
						add.call(_const_vec(size, o["paint"]))
				"invert", "shift":
					for f in by_cost[cost - k]:
						add.call(_unary(o["op"], f))
				_:
					for a in cost - k + 1:
						var b := cost - k - a
						if b < a:
							break
						for i in by_cost[a].size():
							for j in range(i if a == b else 0, by_cost[b].size()):
								add.call(_binary(o["op"], by_cost[a][i], by_cost[b][j]))
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
		match op:
			"mix":
				out[c] = a[c] | b[c]
			"filter":
				out[c] = a[c] & b[c]
			"contrast":
				out[c] = a[c] ^ b[c]
			"third_paint":
				out[c] = (a[c] | b[c]) ^ full_mask[c]
			"missing_from_either":
				out[c] = (a[c] & b[c]) ^ full_mask[c]
			"same_paint":
				out[c] = (a[c] ^ b[c]) ^ full_mask[c]
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
