## A campaign level, loaded from levels/<id>.json.
##
## Pictures and pattern cards are rows of color letters:
##   W R Y O B P G K = White, Red, Yellow, Orange, Blue, Purple, Green, Black.
## Cards are read and the loom is woven row by row, left to right.
##
## JSON fields: id, name (the level's primary title: what tags, Cloths and
## Scores show, and what text refers to it by, "2. The Yellow Pot"), cloth
## and machine (the two title phrases the top bar shows, "The Queen · Extreme
## Mix": what the cloth is, then what the machine does; machine "" for the
## cloth alone; name is the cloth phrase, or in the paint box the machine
## phrase), goal (what to weave) and hint (the rule in paint, then how),
## both shown in the hint panel (ui/level_note.gd) as the ★ objective,
## optional star_hint (a nudge toward the ★★★ machine, where the hint describes
## a dearer one; shown under the ★★★ objective once the player has ★★),
## optional steps (a guided
## level's guide: [{line, do: [actions]}], see ui/guide.gd), pieces (the kinds it
## offers; the tray also shows earlier levels' pieces, locked), inventions
## (invention ids allowed in the tray), optional hold_pots (earned pots this
## level holds back; see _lay_trays), optional waits_for (invention ids the
## level can't be built without: it stays locked until the player owns them,
## proven by tools/level_solver.gd), optional star_needs ({invention id:
## price}: the dearest price of each pot or invention at which ★★★ is still
## reachable, where that is below what earning it at ★★ gives; written by
## tools/level_solver.gd), target (rows), cards ([{name, colors:
## rows}]), card_shows (how many stitches a wrong machine may weave before it
## fails visibly, 4 to 10; the player sees the whole card; written by
## tools/make_cards.gd, checked by
## the solver), optional card_shows_min (a level asking for more, for looks),
## stars {budget, best}, optional invention {id, name, check, in_text} on
## invention levels (in_text: the name inside a sentence, "the Third Paint"),
## reference (a solution: {pieces: [{id, kind, x, y}], tubes: [[from, to]]},
## endpoints written "name" or "name.port", with "card0", "card1", ... and
## "loom" predefined), and card_rule (used by tools/make_cards.gd to derive
## cards from the target).
##
## levels/index.json lists the campaign's chapters in order; an entry marked
## "lost": true is Lost Levels, levels that left the campaign, kept apart and
## shown nowhere yet (lost_ids()).
extends RefCounted

const Machine = preload("res://core/machine.gd")
const Pieces = preload("res://core/pieces.gd")
const Paint = preload("res://core/paint.gd")
const Invention = preload("res://core/invention.gd")

const LETTERS := "WRYOBPGK"
const INDEX_PATH := "res://levels/index.json"
## How many stitches a wrong machine may take to fail (a level's card_shows,
## its decode depth): between these.
const CARD_SHOWS_MIN := 4
const CARD_SHOWS_MAX := 10
## A pattern card's picture is 8 columns by 6 rows by default (4:3, like the
## loom cloth) and may run from 1 row by 4 columns up to 9 rows by 12
## columns (designer, 2026-10-06). The Lost Levels' 16 by 12 pictures are
## beyond it, and shown nowhere.
const CARD_COLS_MIN := 4
const CARD_COLS_MAX := 12
const CARD_ROWS_MIN := 1
const CARD_ROWS_MAX := 9

var id := ""
var number := 0  # position in the campaign, from 1 (0 when loaded on its own)
var chapter := 0  # index into Level.chapters()
var chapter_name := ""
var quilt_across := 0  # the chapter's patches across in its quilt (index.json; 0: as fits)
var name := ""  # the primary title
var cloth_phrase := ""
var machine_phrase := ""
var goal := ""
var hint := ""
var star_hint := ""  # the ★★★ objective's nudge, shown once the player has ★★
var steps: Array = []  # a guided level's steps (ui/guide.gd): [{"line", "do"}]
var cols := 0
var rows := 0
var target := PackedByteArray()
var cards: Array = []
var card_names: Array = []
var card_shows := 0  # stitches a wrong machine may weave before it fails visibly: the decode depth (0 without cards)
var pieces: Array = []  # the kinds this level offers
var tray: Array = []  # the tray's piece kinds in order, offered or locked (see _lay_trays)
var inventions: Array = []
var pots: Array = []  # the earned pots open in the pot slot's fan (see _lay_trays)
var held_pots: Array = []  # earned pots this level holds back: in the fan, locked
var earned_inventions: Array = []  # inventions (not pots) earlier levels earn, in that order: the Inventions slot's fan (see _lay_trays)
var inventions_at := -1  # the Inventions slot's place on the shelf, or -1 before any invention is earned
var hold_pots: Array = []  # the level file's hold_pots
var waits_for: Array = []  # invention ids the level can't be built without
var star_needs := {}  # invention id -> the dearest price ★★★ still allows (written by the solver)
var invention := {}
var budget := 0
var best := 0
var reference := {}
var raw := {}
var error := ""


## The campaign's chapters from levels/index.json, in order:
## [{"name": String, "levels": [level ids], optional "quilt_across": int}]
## (how many patches across the chapter's quilt is; every chapter but the
## paint box, whose threads stack, has a multiple of it so the quilt fills).
static func chapters() -> Array:
	return _index().filter(func(c): return not c.get("lost", false))


## Lost Levels' ids: levels that left the campaign, kept apart in the index
## and shown nowhere yet (DESIGN.md 5.1).
static func lost_ids() -> Array:
	var out := []
	for chapter in _index():
		if chapter.get("lost", false):
			out.append_array(chapter["levels"])
	return out


static func _index() -> Array:
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
			level.quilt_across = int(index[c].get("quilt_across", 0))
			out.append(level)
	_lay_trays(out)
	return out


## Every level's tray shows what it offers plus, locked, every piece an
## earlier level offered: the tray as it was when the campaign got there,
## however far the player has gone since. Pieces sit in the order the
## campaign first offers them, so a new piece joins at the right end and no
## piece's slot (or number key) ever moves.
##
## Pots are pieces too: a level that offers the red pot also offers every
## pot an earlier level earns (in the pot slot's fan, in paint order), from
## Blue on, except the ones its hold_pots holds back and the pot it earns
## itself (a cheaper pot is made, not placed), which show locked. A level
## that offers only named pieces (no red pot) offers no pots. Worked out from
## the campaign, like the tray, so the solver and tests see what a player
## who got here has; the workbench shows only the pots the player owns.
##
## Inventions other than pots share one slot too, the Inventions slot: it
## joins the shelf where the campaign earns its first one (after the six
## critters, key 7) and keeps that place, its fan listing every invention
## earlier levels earn, in the order they are earned. The workbench shows the
## ones the player owns, locked where the level doesn't list them.
static func _lay_trays(levels: Array) -> void:
	var order := []
	for level in levels:
		for kind in level.pieces:
			if not kind in order:
				order.append(kind)
	var seen := {}
	var earned := []  # pot ids, in paint order
	var earned_inventions := []  # other inventions, in the order earned
	var inventions_at := -1
	for level in levels:
		for kind in level.pieces:
			seen[kind] = true
		level.tray = order.filter(func(kind): return seen.has(kind))
		level.earned_inventions = earned_inventions.duplicate()
		level.inventions_at = inventions_at if not earned_inventions.is_empty() else -1
		level.pots = []
		level.held_pots = []
		if "red_pot" in level.pieces:
			for pot in earned:
				var held: bool = pot in level.hold_pots or pot == level.invention.get("id", "")
				(level.held_pots if held else level.pots).append(pot)
		var paint := Invention.paint_of(level.invention)
		if paint < 0 and not level.invention.is_empty() and not level.invention["id"] in earned_inventions:
			if earned_inventions.is_empty():
				inventions_at = level.tray.size()
			earned_inventions.append(level.invention["id"])
		if paint >= 0 and not level.invention["id"] in earned:
			earned.append(level.invention["id"])
			earned.sort_custom(func(a, b): return _pot_paint(a) < _pot_paint(b))


## The paint of a pot invention id (pot_yellow -> Yellow), from its name.
static func _pot_paint(pot_id: String) -> int:
	return Paint.NAMES.map(func(n): return "pot_" + n.to_lower()).find(pot_id)


## The whole title, both phrases: "The Queen · Extreme Mix", or the cloth
## alone.
func title() -> String:
	return cloth_phrase if machine_phrase == "" else "%s · %s" % [cloth_phrase, machine_phrase]


## How text refers to a level: its number and primary title, "2. The Yellow
## Pot" (DESIGN.md 5.1).
func ref_name() -> String:
	return "%d. %s" % [number, name]


## The first campaign level that earns this invention, or null.
static func earning_level(levels: Array, inv_id: String):
	for level in levels:
		if level.invention.get("id", "") == inv_id:
			return level
	return null


## The locked tag's line for a level waiting for inventions: where to earn
## the first one it waits for ("Earn the Third Paint in 25. The Pawn.").
static func waiting_line(levels: Array, inv_ids: Array) -> String:
	if inv_ids.is_empty():
		return ""
	var earner = earning_level(levels, inv_ids[0])
	if earner == null:
		return ""
	var what: String = earner.invention.get("in_text", earner.invention.get("name", ""))
	return "Earn %s in %s." % [what, earner.ref_name()]


## The pots and inventions that cost this player too much for ★★★ here
## (star_needs, proven by the solver), so ★★★ is out of reach before the run:
## [{"id", "name", "yours", "lowest", "from"}], "lowest" the cheapest price so
## far and "from" the level whose ★★★ brings it there ("25. The Pawn").
func dear_inventions(owned: Dictionary, levels: Array) -> Array:
	var out := []
	if star_needs.is_empty() or number < 1:
		return out
	var lowest: Dictionary = Invention.reference_inventions_by_level(levels)[number - 1]
	for inv_id in star_needs:
		if not owned.has(inv_id) or not lowest.has(inv_id):
			continue
		var yours := int(owned[inv_id]["cost"])
		if yours <= int(star_needs[inv_id]):
			continue
		var from := ""
		for l in levels:
			if l.id == lowest[inv_id].get("from_level", ""):
				from = l.ref_name()
		out.append({"id": inv_id, "name": owned[inv_id]["name"], "pot": Invention.paint_of(owned[inv_id]) >= 0,
			"yours": yours, "lowest": int(lowest[inv_id]["cost"]), "from": from})
	return out


## What the hint panel and the success panel say about dear_inventions(), a
## line each: "Your Third Paint costs 2. Three stars on 25. The Pawn bring it
## down to 1." (DESIGN.md 9.1). A no-break space keeps the new price on the
## line with "to".
static func dear_line(dear: Array) -> String:
	var said := PackedStringArray()
	for d in dear:
		if d["from"] == "":
			continue
		var what: String = str(d["name"]).to_lower() if d["pot"] else str(d["name"])
		said.append("Your %s costs %d. Three stars on %s bring it down to %d." % [what, d["yours"], d["from"], d["lowest"]])
	return "\n".join(said)


## The level's objectives, as the hint panel and the success panel show them
## (DESIGN.md 5.1, "Level objectives"): [{"stars", "text", "note", "reached"}].
## ★ is the goal, with the hint as its note; ★★ and ★★★ are prices (one row
## when the two counts are equal). The ★★★ note is the hint ladder's next
## rung: `dear` (Level.dear_line) when a dear invention blocks it, otherwise
## star_hint once the player has ★★ (not on the success panel: `nudge`
## false). `have` is the player's best stars here.
func objectives(have: int, dear := "", nudge := true) -> Array:
	var rows := [{"stars": 1, "text": goal, "note": hint}]
	if budget > best:
		rows.append({"stars": 2, "text": price_text(budget), "note": ""})
	var note := dear
	if note == "" and have >= 2 and nudge:
		note = star_hint
	rows.append({"stars": 3, "text": price_text(best), "note": note})
	for r in rows:
		r["reached"] = have >= int(r["stars"])
	return rows


static func price_text(price: int) -> String:
	return "A price of %d or less." % price if price > 0 else "A price of 0: no pieces at all."


## The critter this level rebuilds from other pieces ("" if none): its card
## rule is the critter's, and its tray holds that critter back.
func rebuilds() -> String:
	var rule := str(raw.get("card_rule", ""))
	return rule if rule in tray and not rule in pieces else ""


## Whether this level lets the player place this invention: one it lists, or
## an earned pot (_lay_trays).
func offers_invention(inv_id: String) -> bool:
	return inv_id in inventions or inv_id in pots


## A piece the tray shows that this level doesn't offer.
func is_locked(kind: String) -> bool:
	return kind in tray and not kind in pieces


## Lost Levels, loaded on their own (unnumbered, no chapter's tray).
static func load_lost() -> Array:
	return lost_ids().map(func(level_id): return load_file("res://levels/%s.json" % level_id))


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
	level.cloth_phrase = str(d.get("cloth", level.name))
	level.machine_phrase = str(d.get("machine", ""))
	level.goal = str(d.get("goal", ""))
	level.hint = str(d.get("hint", ""))
	level.star_hint = str(d.get("star_hint", ""))
	level.steps = d.get("steps", []).duplicate(true)
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
	if not level.cards.is_empty():
		level.card_shows = clampi(int(d.get("card_shows", 6)), CARD_SHOWS_MIN, CARD_SHOWS_MAX)
	level.pieces = d.get("pieces", []).duplicate()
	level.tray = level.pieces.duplicate()  # on its own; load_all adds the locked ones
	level.inventions = d.get("inventions", []).duplicate()
	level.hold_pots = d.get("hold_pots", []).duplicate()
	level.waits_for = d.get("waits_for", []).duplicate()
	for inv_id in d.get("star_needs", {}):
		level.star_needs[str(inv_id)] = int(d["star_needs"][inv_id])
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


## Builds a machine from a compact spec (the "reference" format above),
## its pieces on whole cells (or on spots when the spec says "grid": 2).
func machine_from_spec(spec: Dictionary):
	var m = new_machine()
	var scale: int = Machine.GRID / maxi(1, int(spec.get("grid", 1)))
	var names := {"loom": m.find_kind(Pieces.LOOM)}
	for i in cards.size():
		names["card%d" % i] = m.find_kind(Pieces.CARD, i)
	for p in spec.get("pieces", []):
		var extra := {}
		if p.has("invention"):
			extra["invention"] = p["invention"]
		names[p["id"]] = m.add_node(p["kind"], int(p["x"]) * scale, int(p["y"]) * scale, extra)
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
