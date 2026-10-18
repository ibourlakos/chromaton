## The hint panel (the level's note): pops up over the workshop as an
## unsolved level opens, with the whole title and the level's objectives
## (Level.objectives, DESIGN.md 5.1 "Level objectives"), and flies home into
## the title's "?" when tapped (or on any key). Tapping the title brings it
## back. Each objective is a row: its stars (filled once the player has
## them), what to do, and a note under it: under ★ (weave the cloth) the hint,
## the rule in paint then how; under ★★★ the hint ladder's next rung (a dear
## invention's line, or the level's star_hint once ★★ is earned).
##
## It grows to fit its text up to MAX_H; past that the rows scroll (drag,
## the wheel, or the up and down keys), and a tap that doesn't drag sends it
## home.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const Keys = preload("res://ui/keys.gd")

signal landed

const DESIGN := Vector2(1280, 800)
const POP := 0.25  # seconds to pop up
const LAND := 0.45  # seconds to fly home into the "?"
const WIDTH := 720.0
const PAD := 40.0  # the rows' margin inside the card
const STARS_W := 64.0  # the stars' column
const TEXT_W := WIDTH - 2 * PAD - STARS_W
const ROW_SIZE := 20  # what to do
const HINT_SIZE := 20  # the hint, under ★
const NOTE_SIZE := 16  # the ★★★ note
const MAX_H := 620.0
const TITLE_SIZE := 32
const DRAG := 8.0  # how far a press moves before it scrolls instead of tapping

var level
var have := 0  # the player's best stars on this level
var dear := ""  # Level.dear_line: why ★★★ is out of reach before the run ("" if it isn't)
var rows: Array = []  # Level.objectives
var home := Rect2()  # the title's "?", where the note lands
var t := 0.0
var leaving := -1.0  # seconds since it was sent home (-1: still up)
var card := Rect2()
var scroll := 0.0
var max_scroll := 0.0
var _items: Array = []  # what the rows draw, laid out from the top of the view
var _press := Vector2(-1, -1)
var _dragged := false


## `p_home` is the title's "?" badge, where the note flies home to; `p_have`
## the player's best stars here; `p_dear` the line on a pot or invention too
## dear for ★★★ (Level.dear_line).
func setup(p_level, p_home: Rect2, p_have := 0, p_dear := "") -> void:
	level = p_level
	home = p_home
	have = p_have
	dear = p_dear
	rows = level.objectives(have, dear)


static func title_size(p_level) -> int:
	var font := P.title()
	var s := TITLE_SIZE
	while s > 20 and font.get_string_size(_title(p_level), HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > WIDTH - 60:
		s -= 1
	return s


static func _title(p_level) -> String:
	return "%d · %s" % [p_level.number, p_level.title()]


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var laid := lay_out(rows, TEXT_W, ROW_SIZE, HINT_SIZE, NOTE_SIZE)
	_items = laid["items"]
	var want: float = 140.0 + laid["h"]
	var h := minf(want, MAX_H)
	max_scroll = want - h
	card = Rect2(DESIGN.x / 2 - WIDTH / 2, DESIGN.y / 2 - h / 2 - 10, WIDTH, h)


## Lays objective rows (Level.objectives) out from y 0, one item per stars,
## rule or line of text, so a scrolled line is drawn whole or not at all: the
## stars in a column STARS_W wide, the text right of it, `text_w` wide. The ★
## row's note (the hint) is set at `hint_size` in ink, other notes at
## `note_size` in soft ink; a row already reached is soft. The success panel
## draws the same rows. Returns {"items", "h"}.
static func lay_out(p_rows: Array, text_w: float, row_size: int, hint_size: int, note_size: int) -> Dictionary:
	var items := []
	var y := 0.0
	for k in p_rows.size():
		var row: Dictionary = p_rows[k]
		if k == 1:  # a dotted rule between weaving the cloth and its prices
			items.append({"kind": "rule", "y": y + 2})
			y += 22
		var ink: Color = P.INK if not row["reached"] else P.INK_SOFT
		items.append({"kind": "stars", "y": y + P.ui(800).get_height(row_size) / 2, "n": row["stars"], "filled": row["reached"]})
		y = _paragraph(items, row["text"], P.ui(800), row_size, ink, y, text_w)
		if row["note"] != "":
			var hint: bool = row["stars"] == 1
			y = _paragraph(items, row["note"], P.ui(700), hint_size if hint else note_size, P.INK if hint else P.INK_SOFT, y + 6, text_w)
		y += 14
	return {"items": items, "h": y - 14}


static func _paragraph(items: Array, text: String, font: Font, size_px: int, col: Color, y: float, text_w: float) -> float:
	var para := TextParagraph.new()
	K.add_spans(para, text, font, size_px)
	para.width = text_w
	var line_h := font.get_height(size_px)
	for i in para.get_line_count():
		items.append({"kind": "line", "para": para, "i": i, "y": y, "h": line_h, "col": col})
		y += line_h
	return y


## Draws lay_out's items with their top left at `origin` (the stars' column
## starts there), each only where it fits inside `view`; `words` fades them.
static func draw_rows(ci: CanvasItem, items: Array, origin: Vector2, view: Rect2, words: float, rule_x: float) -> void:
	for it in items:
		var y: float = origin.y + it["y"]
		match it["kind"]:
			"rule":
				if y > view.position.y - 4 and y < view.end.y:
					for i in 9:
						K.disc(ci, Vector2(rule_x - 64 + i * 16, y), 2, Color(P.HOOP, words))
			"stars":  # K.star has no fade: shown while the words are
				if words > 0.6 and y - 10 >= view.position.y and y + 10 <= view.end.y:
					for s in it["n"]:
						K.star(ci, Vector2(origin.x + STARS_W - 14 - s * 18, y), 8, it["filled"])
			"line":
				if y >= view.position.y - 2 and y + it["h"] <= view.end.y + 2:
					K.draw_paragraph(ci, it["para"], Vector2(origin.x + STARS_W, y), Color(it["col"], words), it["i"])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed and max_scroll > 0:
				scroll_by(-40.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 40.0)
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press = event.position
			_dragged = false
		elif _press.x >= 0:
			if not _dragged:
				dismiss()
			_press = Vector2(-1, -1)
		accept_event()
	elif event is InputEventMouseMotion and _press.x >= 0 and max_scroll > 0:
		if _dragged or event.position.distance_to(_press) > DRAG:
			_dragged = true
			scroll_by(-event.relative.y)
		accept_event()


func scroll_by(dy: float) -> void:
	scroll = clampf(scroll + dy, 0, max_scroll)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := Keys.normalize(event.keycode)
		if max_scroll > 0 and k in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			scroll_by(-60.0 if k in [KEY_UP, KEY_W] else 60.0)
		elif not event.echo:
			dismiss()
		Keys.handled(self)


## Sends the note home into the title's "?".
func dismiss() -> void:
	if leaving < 0:
		leaving = 0.0


func _process(delta: float) -> void:
	t += delta
	if leaving >= 0:
		leaving += delta
		if leaving >= LAND:
			landed.emit()
			queue_free()
	queue_redraw()


func _draw() -> void:
	var u := clampf(leaving / LAND, 0, 1) if leaving >= 0 else 0.0
	var e := u * u * (3 - 2 * u)
	draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(P.VEIL, P.VEIL.a * (1 - e)))
	# Pops up from a little smaller; flies home shrinking into the "?", its
	# words fading first.
	var p := clampf(t / POP, 0, 1)
	var grow := 0.92 + 0.08 * (1 - pow(1 - p, 3))
	var r := Rect2(card.get_center() - card.size * grow / 2, card.size * grow)
	r = Rect2(r.position.lerp(home.position, e), r.size.lerp(home.size, e))
	var words := clampf(1 - u * 2.5, 0, 1)
	var a := 1 - e * e
	var corner := 22 * (1 - e) + home.size.y / 2 * e
	K.fill(self, K.round_rect(Rect2(r.position + Vector2(5, 8), r.size), corner), Color(P.SHADOW, P.SHADOW.a * a))
	K.shape(self, K.round_rect(r, corner), Color(P.TAG, a), Color(P.INK, a), 3)
	if words <= 0:
		return
	var cx := r.get_center().x
	var top := r.position.y
	K.text(self, P.title(), Vector2(cx, top + 46), _title(level), title_size(level), Color(P.INK, words))
	# The rows scroll under the title, clipped above the foot.
	var view := Rect2(r.position.x + 10, top + 80, r.size.x - 20, r.size.y - 124)
	draw_rows(self, _items, Vector2(cx - WIDTH / 2 + PAD, view.position.y + 4 - scroll), view, words, cx)
	if max_scroll > 0 and scroll < max_scroll - 1:
		K.text(self, P.ui(700), Vector2(cx, r.end.y - 46), "more below ↓", 13, Color(P.INK_SOFT, words))
	K.text(self, P.ui(700), Vector2(cx, r.end.y - 24), "Tap anywhere to start", 14, Color(P.INK_SOFT, words))
