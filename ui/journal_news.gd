## "New in your journal": shown over the workbench after the success panel,
## when the solve brought something new (DESIGN.md 5.7). A stepping stone
## into the rest of the campaign.
##
## One row kind for every entry: an icon as the thing looks in the game, a
## title and one line. Most important first: the level's new words (with
## their text when there are up to three), what opened (a new chapter, the
## levels an invention opens), inventions made cheaper (both prices), then
## the frames the player's runs filled on piece pages.
##
## The card is 760 px wide and grows to fit, up to about 600 px tall; past
## that the rows scroll (drag, the wheel), with a "more below" chip that
## scrolls on when tapped. Continue (Enter, then Space) scrolls a page while
## there's more below and goes on at the bottom; Back goes on at once. The
## book opens the journal at the first new entry.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const Pieces = preload("res://core/pieces.gd")
const Invention = preload("res://core/invention.gd")

signal done
signal open_journal(tab: String, focus: String)

const DESIGN := Vector2(1280, 800)
const WIDTH := 760.0
const MAX_H := 600.0
const HEAD := 82.0  # the title above the rows
const FOOT := 92.0  # the buttons below them
const FULL_TEXT := 3  # up to this many words show their text
const STEP := 60.0

var rows: Array = []  # [{"kind", "title", "line", "h", and what the icon needs}]
var picture: Callable  # draws a word's picture: func(ci, id, centre, scale)
var t := 0.0
var card := Rect2()
var view: Control  # the rows, clipped so they scroll
var scroll := 0.0
var _press_at := Vector2(-1, -1)
var _dragged := false


## words: the level's new words; frames: [piece kind, input colors] the
## player's runs showed; extra: {"chapter": {"name", "level"}, "opens":
## {"what", "levels"}, "cheaper": [{"inv", "old", "new"}]} (levels are
## Level objects; what is the invention's name in a sentence).
func setup(words: Array, frames: Array, p_picture: Callable, extra := {}) -> void:
	picture = p_picture
	rows = []
	for w in words:
		var text: String = str(w["text"]).replace("\n\n", " ") if words.size() <= FULL_TEXT else ""
		rows.append({"kind": "word", "id": w["id"], "title": w["word"], "line": text})
	if extra.has("chapter"):
		var c: Dictionary = extra["chapter"]
		rows.append({"kind": "level", "level": c["level"], "title": "A new chapter: %s" % c["name"], "line": c["level"].ref_name()})
	if extra.has("opens"):
		var o: Dictionary = extra["opens"]
		var refs: Array = o["levels"].map(func(l): return l.ref_name())
		var listed: String = refs[0] if refs.size() == 1 else ", ".join(refs.slice(0, refs.size() - 1)) + " and " + refs[refs.size() - 1]
		var what: String = o["what"]
		rows.append({"kind": "level", "level": o["levels"][0], "title": "%s opens %s." % [what.substr(0, 1).to_upper() + what.substr(1), listed], "line": ""})
	for c in extra.get("cheaper", []):
		var inv: Dictionary = c["inv"]
		rows.append({"kind": "invention", "inv": inv, "title": "%s: cheaper, %d → %d" % [inv["name"], c["old"], c["new"]], "line": ""})
	var by_piece := {}
	for f in frames:
		var list: Array = by_piece.get(f[0], [])
		list.append(f[1])
		by_piece[f[0]] = list
	for kind in by_piece:
		rows.append({"kind": "frames", "piece": kind, "title": Pieces.display_name(kind), "line": "", "frames": by_piece[kind]})
	var font := P.ui(700)
	for row in rows:
		var h := 70.0
		if row["line"] != "" and row["kind"] == "word":
			h = maxf(84.0, 44.0 + font.get_multiline_string_size(row["line"], HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 170, 15).y)
		elif font.get_string_size(row["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x > WIDTH - 170:
			h = 84.0  # a long title wraps
		row["h"] = h
	var card_h := minf(HEAD + _rows_height() + FOOT, MAX_H)
	card = Rect2(DESIGN.x / 2 - WIDTH / 2, DESIGN.y / 2 - card_h / 2, WIDTH, card_h)


## Where the open journal should start: the first new entry's tab and focus.
func first_entry() -> Array:
	if rows.is_empty():
		return ["", ""]
	var row: Dictionary = rows[0]
	match row["kind"]:
		"word":
			return ["words", "word:" + str(row["id"])]
		"frames":
			return ["pieces", row["piece"]]
		"invention":
			return ["inventions", "inv:" + str(row["inv"]["id"])]
	return ["cloths", ""]


func _rows_height() -> float:
	var h := 0.0
	for row in rows:
		h += row["h"] + 10
	return h


func max_scroll() -> float:
	return maxf(0.0, _rows_height() - view_rect().size.y)


func view_rect() -> Rect2:
	return Rect2(card.position.x + 20, card.position.y + HEAD, card.size.x - 40, card.size.y - HEAD - FOOT)


## Rows that end below the view.
func rows_below() -> int:
	var bottom := scroll + view_rect().size.y
	var y := 0.0
	var n := 0
	for row in rows:
		if y + row["h"] > bottom + 1:
			n += 1
		y += row["h"] + 10
	return n


func more_rect() -> Rect2:
	if rows_below() == 0:
		return Rect2()
	var v := view_rect()
	return Rect2(v.get_center().x - 80, v.end.y - 34, 160, 30)


func scroll_by(dy: float) -> void:
	scroll = clampf(scroll + dy, 0.0, max_scroll())


## Continue: a page further while there's more below, else on.
func go_on() -> void:
	if rows_below() > 0:
		scroll_by(view_rect().size.y - 60)
	else:
		done.emit()


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	view = Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.position = view_rect().position
	view.size = view_rect().size
	view.draw.connect(_draw_rows)
	add_child(view)
	var go = ToyButton.make("next", Vector2(60, 60))
	go.position = Vector2(card.get_center().x + 8, card.end.y - 80)
	go.key = Keys.label("next")
	go.toggled_on = true
	go.pressed.connect(go_on)
	add_child(go)
	var book = ToyButton.make("book", Vector2(60, 60))
	book.position = Vector2(card.get_center().x - 68, card.end.y - 80)
	book.pressed.connect(func():
		var at := first_entry()
		open_journal.emit(at[0], at[1]))
	add_child(book)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or event.echo:
		return
	match Keys.action(event, "Woven"):
		"next":
			go_on()
		"back":
			done.emit()
		_:
			return
	Keys.handled(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed:
			scroll_by(-STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else STEP)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_dragged = false
		else:
			if not _dragged and more_rect().has_point(event.position):
				scroll_by(view_rect().size.y - 60)
			_press_at = Vector2(-1, -1)
		accept_event()
	elif event is InputEventMouseMotion and _press_at.x >= 0:
		if _dragged or event.position.distance_to(_press_at) > 8:
			_dragged = true
			scroll_by(-event.relative.y)
		accept_event()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if view != null:
		view.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), P.VEIL)
	K.fill(self, K.round_rect(Rect2(card.position + Vector2(5, 8), card.size), 22), P.SHADOW)
	K.shape(self, K.round_rect(card, 22), P.TAG, P.INK, 3)
	var cx := card.get_center().x
	K.icon(self, "book", Vector2(cx - 150, card.position.y + 42), 1.4, P.INK)
	K.text(self, P.display(600), Vector2(cx + 16, card.position.y + 42), "New in your journal", 30, P.INK)


## The rows, on the clipped view, then the "more below" chip over them.
func _draw_rows() -> void:
	var y := -scroll
	var w := view.size.x
	for row in rows:
		var h: float = row["h"]
		if y + h >= 0 and y <= view.size.y:
			_draw_row(row, Rect2(0, y, w, h))
		y += h + 10
	var m := more_rect()
	if m.size.x > 0:
		m.position -= view.position
		K.fill(view, K.round_rect(Rect2(m.position + Vector2(0, 3), m.size), 15), P.SHADOW)
		K.shape(view, K.round_rect(m, 15), P.TAG, Color(P.INK, 0.5), 1.5)
		K.text(view, P.ui(700), m.get_center(), "%d more below ↓" % rows_below(), 14, P.INK_SOFT)


func _draw_row(row: Dictionary, r: Rect2) -> void:
	K.shape(view, K.round_rect(r, 12), Color(P.PAPER, 0.55), Color(P.INK, 0.25), 1.5)
	var icon := Vector2(r.position.x + 52, r.position.y + minf(r.size.y / 2, 40))
	match row["kind"]:
		"word":
			picture.call(view, str(row["id"]), icon, 0.62)
		"level":
			_tag(icon, row["level"])
		"invention":
			var inv: Dictionary = row["inv"]
			var paint := Invention.paint_of(inv)
			if paint >= 0:
				K.pot(view, icon + Vector2(0, -2), 0.5, 99, t, 0.2, paint)
			else:
				K.sticker(view, icon, 0.55, str(inv["name"]), 99, t, 0.2)
		"frames":
			picture.call(view, str(row["piece"]).replace("_", "-"), icon, 0.62)
	var x := r.position.x + 110
	var font := P.display(600)
	if row["kind"] == "frames":
		K.text(view, font, Vector2(x, r.get_center().y), row["title"], 20, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_frames(row, Vector2(x + font.get_string_size(row["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24, r.get_center().y))
		return
	var title_y := r.position.y + 22
	if row["line"] == "" and r.size.y <= 70:
		title_y = r.get_center().y
	view.draw_multiline_string(font, Vector2(x, title_y - 12 + font.get_ascent(19)), row["title"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 19, 2, P.INK)
	if row["line"] != "":
		var ui := P.ui(700)
		view.draw_multiline_string(ui, Vector2(x, r.position.y + 38 + ui.get_ascent(15)), row["line"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 15, 4, P.INK_SOFT)


## A frame row's drops: what went in, what came out, the first few.
func _draw_frames(row: Dictionary, at: Vector2) -> void:
	var x := at.x
	var list: Array = row["frames"]
	for ins in list.slice(0, 6):
		for c in ins:
			K.drop(view, Vector2(x, at.y), 10, c)
			x += 24
		K.icon(view, "next", Vector2(x, at.y), 0.55, P.INK_SOFT)
		x += 22
		K.drop(view, Vector2(x, at.y), 10, Pieces.apply(row["piece"], ins)[0])
		x += 36
	if list.size() > 6:
		K.text(view, P.ui(700), Vector2(x, at.y), "+%d" % (list.size() - 6), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


## A level's tag, small: its number stamped on tag paper.
func _tag(c: Vector2, level) -> void:
	var r := Rect2(c - Vector2(34, 24), Vector2(68, 48))
	K.fill(view, K.round_rect(Rect2(r.position + Vector2(2, 3), r.size), 10), P.SHADOW)
	K.shape(view, K.round_rect(r, 10), P.TAG, P.INK, 2)
	K.ring(view, c, 17, Color(P.WOOD_DK, 0.9), 2)
	K.text(view, P.display(700), c + Vector2(0, 1), str(level.number), 18, P.INK)
