## Derives each level's pattern cards from its target picture, and how many
## drops its cards show.
##
## Run from the project folder:
##   godot_console --headless --path . --script res://tools/make_cards.gd
## For every level with a "card_rule", picks card colors so that the rule's
## machine weaves the target, and rewrites the level's "cards". Choices are
## pseudo-random but fixed by the level id, so reruns give the same cards.
##
## What a card shows decodes the level (DESIGN.md 5.1): every wrong machine
## within the level's two-star budget must fail within the drops a card shows
## at the start. For each count from 4 (or the level's card_shows_min) to 10,
## the first stitches are rerolled among the rule's options, greedily, to make
## every cheap wrong machine fail there; the shortest count that works is the
## level's "card_shows". A level with fixed cards (no rule: the Mix and Sieve
## tables) only gets its count. A level no count up to 10 decodes is reported
## and the run fails.
##
## Rules (t = target stitch):
##   copy         one card: t itself (the card tubed straight to the loom weaves t)
##   remove_yellow one card: t without its yellow (a Mix with the yellow pot weaves t)
##   fork         one card whose paint mixed with its own Shift is t (red for
##                orange, yellow for green, blue for purple; black stays black)
##   unshift      one card: t turned back one step (a Shift weaves t)
##   any_red      one card: Red where t is Black, White elsewhere
##   invert       one card: the opposite of t
##   third_paint  two cards whose mix is the opposite of t (the Third Paint weaves t)
##   filter       two cards that share exactly t
##   bleach       two cards: the first minus the second's paint is t
##   smudges      one card: t with yellow sand on about a third of the stitches
##                (Sandy Crab, sieved down to its red)
##   missing      two cards that share exactly the opposite of t
##   mix          two cards whose mix is t
##   contrast     two cards: the first random, the second holding the primaries
##                in exactly one of t and the first
##   same         two cards: the first random, the second holding the primaries
##                where the first and t disagree (Same Paint weaves t)
##   two_of_three three cards: a primary is in t exactly when two or more cards have it
extends SceneTree

const Paint = preload("res://core/paint.gd")
const Level = preload("res://core/level.gd")
const Solver = preload("res://tools/level_solver.gd")
const Invention = preload("res://core/invention.gd")
const Functions = preload("res://tools/functions.gd")

const CARD_COUNT := {
	"copy": 1, "remove_yellow": 1, "fork": 1, "unshift": 1, "any_red": 1,
	"invert": 1, "smudges": 1, "third_paint": 2, "filter": 2, "bleach": 2,
	"missing": 2, "mix": 2, "contrast": 2, "same": 2, "two_of_three": 3,
}
const NAMES := ["A", "B", "C"]
const OPTION_TRIES := 24  # rerolls of the rule per shown stitch


func _init() -> void:
	var ids := Level.index_ids()
	var levels := Level.load_all()
	var by_level := Invention.reference_inventions_by_level(levels)
	var ops_of := {}  # level id -> the pieces it offers, as search operations
	for level in levels:
		ops_of[level.id] = Solver.level_ops(level, by_level[level.number - 1])
	var failures := 0
	for level_id in ids:
		var path := "res://levels/%s.json" % level_id
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var rule: String = d.get("card_rule", "")
		if d.get("cards", []).is_empty() and rule == "":
			continue
		var width := str(d["target"][0]).length()
		var target := Level.parse_rows(d["target"])
		var salt := hash(str(level_id)) & 0xffff
		var cols := []
		if rule == "":  # fixed cards
			for card in d["cards"]:
				cols.append(Array(Level.parse_rows(card["colors"])))
		else:
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
		var res := decode(rule, d, ops_of[level_id], target, salt, cols)
		if res["shows"] < 0:
			printerr("%s: no card shows enough to decode it within %d drops (%s)" % [level_id, Level.CARD_SHOWS_MAX, res["note"]])
			failures += 1
			continue
		var cards := []
		for k in cols.size():
			cards.append({"name": NAMES[k], "colors": Level.letters(PackedByteArray(res["cols"][k]), width)})
		d["cards"] = cards
		d["card_shows"] = res["shows"]
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_ints(d), "\t", false) + "\n")
		print("%s: %d card(s) written, showing %d drops (%s)" % [level_id, cards.size(), res["shows"], res["note"]])
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------
# Decoding: every cheap wrong machine fails within the drops a card shows
# ---------------------------------------------------------------------------

## Finds the fewest drops a card can show so that every wrong machine within
## the two-star budget fails within them, rerolling the shown stitches among
## the rule's options (fixed cards keep theirs). Returns {"shows": int (-1 if
## none up to 10 works), "cols": the cards, "note": a report}.
func decode(rule: String, d: Dictionary, ops: Array, target: PackedByteArray, salt: int, base: Array) -> Dictionary:
	var n: int = base.size()
	var fn = Functions.new()
	var funcs: Array = fn.cheap_functions(ops, n, int(d["stars"]["budget"]))
	var lo := maxi(Level.CARD_SHOWS_MIN, int(d.get("card_shows_min", 0)))
	var survivors := 0
	for shows in range(lo, Level.CARD_SHOWS_MAX + 1):
		var cols: Array = base.map(func(c): return c.duplicate())
		var span := mini(shows, target.size())
		# The paints each shown stitch may take (the derived one first).
		var options := []
		for p in span:
			var seen := {}
			var opts := []
			for s in (OPTION_TRIES if rule != "" else 1):
				var pick: Array = derive(rule, target[p], p, salt + s * 7919) if s > 0 else range(n).map(func(k): return cols[k][p])
				if pick.is_empty():
					continue
				var x := Functions.combo_index(pick)
				if not seen.has(x):
					seen[x] = true
					opts.append(x)
			# Then every other set of card paints the rule's machine weaves the
			# stitch from, where the rule takes several cards.
			if n > 1 and rule != "":
				for x in int(pow(8, n)):
					if not seen.has(x) and rule_weaves(rule, range(n).map(func(k): return (x >> (3 * k)) & 7)) == target[p]:
						seen[x] = true
						opts.append(x)
			options.append(opts)
		# Wrong machines: the ones that weave a stitch past the span wrong.
		var below := []
		for i in range(span, target.size()):
			below.append(Functions.combo_index(range(n).map(func(k): return cols[k][i])))
		var alive := []
		for f in funcs:
			for j in below.size():
				if Functions.at(f, below[j]) != target[span + j]:
					alive.append(f)
					break
		var total := alive.size()
		var assigned := {}
		while not alive.is_empty():
			# A machine few choices can fail weighs more, so the stitch that
			# alone can fail it is spent on it (and on as many others as can be).
			var chances := []
			for f in alive:
				var c := 0
				for p in span:
					if not assigned.has(p):
						for x in options[p]:
							if Functions.at(f, x) != target[p]:
								c += 1
				chances.append(c)
			var best_kill := 0.0
			var best_p := -1
			var best_x := -1
			for p in span:
				if assigned.has(p):
					continue
				for x in options[p]:
					var kill := 0.0
					for i in alive.size():
						if Functions.at(alive[i], x) != target[p]:
							kill += 1.0 / chances[i]
					if kill > best_kill:
						best_kill = kill
						best_p = p
						best_x = x
			if best_kill == 0.0:
				break
			assigned[best_p] = best_x
			alive = alive.filter(func(f): return Functions.at(f, best_x) == target[best_p])
		survivors = alive.size()
		if not alive.is_empty() and shows == Level.CARD_SHOWS_MAX:
			var tab := ""
			for x in int(pow(8, n)):
				tab += Level.LETTERS[Functions.at(alive[0], x)]
			print("  a survivor, by card paints (card A fastest): ", tab, " first 10 target: ", Level.letters(target.slice(0, 10), 10))
		if alive.is_empty():
			for p in assigned:
				for k in n:
					cols[k][p] = (assigned[p] >> (3 * k)) & 7
			# The rerolls may decode it sooner than asked: show only what's needed.
			var combos := Functions.stitch_combos(cols, target.size())
			var needed := lo
			for f in funcs:
				needed = maxi(needed, Functions.first_wrong(f, combos, target) + 1)
			return {"shows": needed, "cols": cols, "note": "%d cheap wrong machines, all fail in the first %d drops" % [total, needed]}
	return {"shows": -1, "cols": base, "note": "%d cheap wrong machines still pass the first %d drops" % [survivors, Level.CARD_SHOWS_MAX]}


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

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


## What a several-card rule's machine weaves from these card paints (-1 for
## a one-card rule, whose cards come only from derive()).
static func rule_weaves(rule: String, ins: Array) -> int:
	match rule:
		"third_paint":
			return Paint.invert(Paint.mix(ins[0], ins[1]))
		"filter":
			return Paint.filter(ins[0], ins[1])
		"bleach":
			return Paint.bleach(ins[0], ins[1])
		"missing":
			return Paint.invert(Paint.filter(ins[0], ins[1]))
		"mix":
			return Paint.mix(ins[0], ins[1])
		"contrast":
			return Paint.contrast(ins[0], ins[1])
		"same":
			return Paint.invert(Paint.contrast(ins[0], ins[1]))
		"two_of_three":
			var out := 0
			for p in Paint.PRIMARIES:
				if [0, 1, 2].filter(func(k): return ins[k] & p).size() >= 2:
					out |= p
			return out
	return -1


static func derive(rule: String, t: int, i: int, salt: int) -> Array:
	match rule:
		"copy":
			return [t]
		"remove_yellow":
			return [t & ~Paint.YELLOW] if t & Paint.YELLOW else []
		"fork":
			if t == Paint.BLACK:
				return [Paint.BLACK]
			for p in Paint.ALL:
				if Paint.mix(p, Paint.shift(p)) == t:
					return [p]
			return []
		"unshift":
			return [Paint.shift(Paint.shift(t))]
		"any_red":
			if t == Paint.BLACK:
				return [Paint.RED]
			return [Paint.WHITE] if t == Paint.WHITE else []
		"invert":
			return [Paint.invert(t)]
		"third_paint":
			return derive("mix", Paint.invert(t), i, salt)
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
		"same":
			var any := rnd(i, salt, 1) % 8
			return [any, Paint.contrast(any, Paint.invert(t))]
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
