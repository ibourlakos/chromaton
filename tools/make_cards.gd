## Derives each level's pattern cards from its target picture.
##
## Run from the project folder:
##   godot_console --headless --path . --script res://tools/make_cards.gd
## For every level with a "card_rule", picks card colors so that the rule's
## machine weaves the target, and rewrites the level's "cards". Choices are
## pseudo-random but fixed by the level id, so reruns give the same cards.
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
##   filter_mix   three cards: what the first two share, mixed with the third, is t
extends SceneTree

const Paint = preload("res://core/paint.gd")
const Level = preload("res://core/level.gd")

const CARD_COUNT := {
	"copy": 1, "remove_red": 1, "unshift": 1, "any_red": 1, "invert": 1,
	"third_color": 2, "filter": 2, "bleach": 2, "filter_mix": 3,
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
		var cards := []
		for k in cols.size():
			cards.append({"name": NAMES[k], "colors": Level.letters(PackedByteArray(cols[k]), width)})
		d["cards"] = cards
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_ints(d), "\t", false) + "\n")
		print("%s: %d card(s) written" % [level_id, cards.size()])
	quit(1 if failures > 0 else 0)


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
		"filter_mix":
			var c := sub(t, rnd(i, salt, 4))
			var s := (t & ~c) | sub(t & c, rnd(i, salt, 5))
			var ab := share(s, i, salt, 6)
			return [ab[0], ab[1], c]
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
