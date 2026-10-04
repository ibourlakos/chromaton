## A campaign level, loaded from levels/<id>.json.
##
## Pictures and pattern cards are rows of color letters:
##   W R Y O B P G K = White, Red, Yellow, Orange, Blue, Purple, Green, Black.
## Cards are read and the loom is woven row by row, left to right.
##
## JSON fields: id, name, goal, optional hint (guidance shown with the goal
## as the level opens and under the title after), pieces (the kinds it
## offers; the tray also shows earlier levels' pieces, locked), inventions
## (invention ids allowed in the tray), optional hold_pots (earned pots this
## level holds back; see _lay_trays), target (rows), cards
## ([{name, colors: rows, optional smudges: [stitch indices that carry stray
## paint]}]),
## stars {budget, best}, optional invention {id, name, check} on invention
## levels, reference (a solution: {pieces: [{id, kind, x, y}], tubes:
## [[from, to]]}, endpoints written "name" or "name.port", with "card0",
## "card1", ... and "loom" predefined), and card_rule (used by
## tools/make_cards.gd to derive cards from the target).
extends RefCounted

const Machine = preload("res://core/machine.gd")
const Pieces = preload("res://core/pieces.gd")
const Paint = preload("res://core/paint.gd")
const Invention = preload("res://core/invention.gd")

const LETTERS := "WRYOBPGK"
const INDEX_PATH := "res://levels/index.json"
const CARD_SHOWS := 6  # how many coming drops a pattern card shows

var id := ""
var number := 0  # position in the campaign, from 1 (0 when loaded on its own)
var chapter := 0  # index into Level.chapters()
var chapter_name := ""
var name := ""
var goal := ""
var hint := ""
var cols := 0
var rows := 0
var target := PackedByteArray()
var cards: Array = []
var card_names: Array = []
var smudges: Array = []  # per card, the stitch indices marked as stray paint
var pieces: Array = []  # the kinds this level offers
var tray: Array = []  # the tray's piece kinds in order, offered or locked (see _lay_trays)
var inventions: Array = []
var pots: Array = []  # the earned pots open in the pot slot's fan (see _lay_trays)
var held_pots: Array = []  # earned pots this level holds back: in the fan, locked
var hold_pots: Array = []  # the level file's hold_pots
var invention := {}
var budget := 0
var best := 0
var reference := {}
var raw := {}
var error := ""


## The campaign's chapters from levels/index.json, in order:
## [{"name": String, "levels": [level ids]}].
static func chapters() -> Array:
	var index = _read_json(INDEX_PATH)
	if not index is Array:
		push_error("cannot read " + INDEX_PATH)
		return []
	return index


## Every level id in campaign order.
static func index_ids() -> Array:
	var out := []
	for chapter in chapters():
		out.append_array(chapter["levels"])
	return out


static func load_all() -> Array:
	var out := []
	var index := chapters()
	for c in index.size():
		for level_id in index[c]["levels"]:
			var level = load_file("res://levels/%s.json" % level_id)
			if level.error != "":
				push_error(level.error)
			level.number = out.size() + 1
			level.chapter = c
			level.chapter_name = str(index[c]["name"])
			out.append(level)
	_lay_trays(out)
	return out


## Every level's tray shows what it offers plus, locked, every piece an
## earlier level offered: the tray as it was when the campaign got there,
## however far the player has gone since. Pieces sit in the order the
## campaign first offers them, so a new piece joins at the right end and no
## piece's slot (or number key) ever moves.
##
## Pots are pieces too: from chapter 2 on, a level that offers the red pot
## also offers every pot an earlier level earns (in the pot slot's fan, in
## paint order), except the ones its hold_pots holds back, which show
## locked. A level that offers only named pieces (no red pot) offers no pots.
## Worked out from the campaign, like the tray, so the solver and tests see
## what a player who got here has; the workbench shows only the pots the
## player owns.
static func _lay_trays(levels: Array) -> void:
	var order := []
	for level in levels:
		for kind in level.pieces:
			if not kind in order:
				order.append(kind)
	var seen := {}
	var earned := []  # pot ids, in paint order
	for level in levels:
		for kind in level.pieces:
			seen[kind] = true
		level.tray = order.filter(func(kind): return seen.has(kind))
		level.pots = []
		level.held_pots = []
		if level.chapter > 0 and "red_pot" in level.pieces:
			for pot in earned:
				(level.held_pots if pot in level.hold_pots else level.pots).append(pot)
		var paint := Invention.paint_of(level.invention)
		if paint >= 0 and not level.invention["id"] in earned:
			earned.append(level.invention["id"])
			earned.sort_custom(func(a, b): return _pot_paint(a) < _pot_paint(b))


## The paint of a pot invention id (pot_yellow -> Yellow), from its name.
static func _pot_paint(pot_id: String) -> int:
	return Paint.NAMES.map(func(n): return "pot_" + n.to_lower()).find(pot_id)


## Whether this level lets the player place this invention: one it lists, or
## an earned pot (_lay_trays).
func offers_invention(inv_id: String) -> bool:
	return inv_id in inventions or inv_id in pots


## A piece the tray shows that this level doesn't offer.
func is_locked(kind: String) -> bool:
	return kind in tray and not kind in pieces


static func load_file(path: String):
	var d = _read_json(path)
	if not d is Dictionary:
		var bad = load("res://core/level.gd").new()
		bad.error = "cannot read level " + path
		return bad
	return from_dict(d)


static func from_dict(d: Dictionary):
	var level = load("res://core/level.gd").new()
	level.raw = d
	level.id = str(d.get("id", ""))
	level.name = str(d.get("name", ""))
	level.goal = str(d.get("goal", ""))
	level.hint = str(d.get("hint", ""))
	var rows_in: Array = d.get("target", [])
	level.rows = rows_in.size()
	level.cols = str(rows_in[0]).length() if rows_in.size() > 0 else 0
	for r in rows_in:
		if str(r).length() != level.cols:
			level.error = "%s: target rows differ in length" % level.id
	level.target = parse_rows(rows_in)
	for card in d.get("cards", []):
		level.card_names.append(str(card.get("name", "")))
		var seq := parse_rows(card.get("colors", []))
		if seq.size() != level.target.size():
			level.error = "%s: card %s has %d colors, loom has %d stitches" % [level.id, card.get("name", ""), seq.size(), level.target.size()]
		level.cards.append(seq)
		level.smudges.append(card.get("smudges", []).map(func(i): return int(i)))
	level.pieces = d.get("pieces", []).duplicate()
	level.tray = level.pieces.duplicate()  # on its own; load_all adds the locked ones
	level.inventions = d.get("inventions", []).duplicate()
	level.hold_pots = d.get("hold_pots", []).duplicate()
	level.invention = d.get("invention", {}).duplicate()
	var stars: Dictionary = d.get("stars", {})
	level.budget = int(stars.get("budget", 0))
	level.best = int(stars.get("best", 0))
	level.reference = d.get("reference", {})
	if level.target.size() == 0:
		level.error = "%s: empty target" % level.id
	return level


## Color letters to colors. Unknown letters become -1.
static func parse_rows(rows_in: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for r in rows_in:
		for ch in str(r):
			var c := LETTERS.find(ch)
			if c < 0:
				push_error("unknown color letter: " + ch)
			out.append(maxi(c, 0))
	return out


static func letters(seq: PackedByteArray, width: int) -> Array:
	var out := []
	var line := ""
	for i in seq.size():
		line += LETTERS[seq[i]]
		if line.length() == width:
			out.append(line)
			line = ""
	if line != "":
		out.append(line)
	return out


func size() -> int:
	return target.size()


## The bench with only the level's fixed parts: its cards and the loom.
func new_machine():
	var m = Machine.new()
	for i in cards.size():
		m.add_node(Pieces.CARD, 0, 0, {"card": i})
	m.add_node(Pieces.LOOM)
	return m


## Builds a machine from a compact spec (the "reference" format above).
func machine_from_spec(spec: Dictionary):
	var m = new_machine()
	var names := {"loom": m.find_kind(Pieces.LOOM)}
	for i in cards.size():
		names["card%d" % i] = m.find_kind(Pieces.CARD, i)
	for p in spec.get("pieces", []):
		var extra := {}
		if p.has("invention"):
			extra["invention"] = p["invention"]
		names[p["id"]] = m.add_node(p["kind"], int(p["x"]), int(p["y"]), extra)
	for t in spec.get("tubes", []):
		var a := _endpoint(t[0])
		var b := _endpoint(t[1])
		if not names.has(a[0]) or not names.has(b[0]):
			push_error("%s: unknown tube endpoint in %s" % [id, str(t)])
			continue
		m.connect_ports(names[a[0]], a[1], names[b[0]], b[1])
	return m


func reference_machine():
	return machine_from_spec(reference)


## Stars for a solve: 1 solved, 2 within budget, 3 at or under the best known.
func stars_for(piece_count: int) -> int:
	if piece_count <= best:
		return 3
	if piece_count <= budget:
		return 2
	return 1


static func _endpoint(s: String) -> Array:
	var dot := s.find(".")
	if dot < 0:
		return [s, 0]
	return [s.substr(0, dot), int(s.substr(dot + 1))]


static func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("%s:%d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return null
	return j.data
