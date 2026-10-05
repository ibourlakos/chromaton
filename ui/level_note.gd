## The hint panel (the level's note): pops up over the workshop as an
## unsolved level opens, with the whole title, the goal (what to weave) and
## the hint (the rule in paint, then how), and flies home into the title's
## "?" when tapped (or on any key). Tapping the title brings it back.
## DESIGN.md 5.1, "The title says what you do, the hint says how".
##
## It grows to fit its text up to MAX_H; past that the hint scrolls (drag,
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
const WIDTH := 640.0
const TEXT_W := 540.0
const HINT_SIZE := 22
const MAX_H := 600.0
const TITLE_SIZE := 32
const DRAG := 8.0  # how far a press moves before it scrolls instead of tapping

var level
var home := Rect2()  # the title's "?", where the note lands
var t := 0.0
var leaving := -1.0  # seconds since it was sent home (-1: still up)
var card := Rect2()
var scroll := 0.0
var max_scroll := 0.0
var _press := Vector2(-1, -1)
var _dragged := false


## `p_home` is the title's "?" badge, where the note flies home to.
func setup(p_level, p_home: Rect2) -> void:
	level = p_level
	home = p_home


static func title_size(p_level) -> int:
	var font := P.display(600)
	var s := TITLE_SIZE
	while s > 20 and font.get_string_size(_title(p_level), HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > WIDTH - 60:
		s -= 1
	return s


static func _title(p_level) -> String:
	return "%d · %s" % [p_level.number, p_level.title()]


## The hint's height on the note, at its width.
static func hint_height(p_level) -> float:
	if p_level.hint == "":
		return 0.0
	return P.ui(700).get_multiline_string_size(p_level.hint, HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, HINT_SIZE).y


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var goal_h := P.ui(700).get_multiline_string_size(level.goal, HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, 20).y
	var want := 150.0 + goal_h + (hint_height(level) + 34.0 if level.hint != "" else 0.0)
	var h := minf(want, MAX_H)
	max_scroll = want - h
	card = Rect2(DESIGN.x / 2 - WIDTH / 2, DESIGN.y / 2 - h / 2 - 10, WIDTH, h)


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
	var font := P.ui(700)
	var cx := r.get_center().x
	var top := r.position.y
	var x0 := cx - TEXT_W / 2
	K.text(self, P.display(600), Vector2(cx, top + 46), _title(level), title_size(level), Color(P.INK, words))
	# The goal and the hint scroll under the title, clipped above the foot.
	var view := Rect2(r.position.x + 10, top + 80, r.size.x - 20, r.size.y - 124)
	var y := view.position.y + 4 - scroll
	var goal_h := font.get_multiline_string_size(level.goal, HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, 20).y
	if y >= view.position.y - 2 and y + goal_h <= view.end.y + 2:
		draw_multiline_string(font, Vector2(x0, y + font.get_ascent(20)), level.goal, HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, 20, -1, Color(P.INK_SOFT, words))
	y += goal_h + 16
	if level.hint != "":
		if y > view.position.y - 4 and y < view.end.y:
			for i in 9:  # a dotted rule between the goal and the hint
				K.disc(self, Vector2(cx - 64 + i * 16, y), 2, Color(P.HOOP, words))
		y += 18
		_hint_lines(font, x0, y, view, Color(P.INK, words))
	if max_scroll > 0 and scroll < max_scroll - 1:
		K.text(self, P.ui(700), Vector2(cx, r.end.y - 46), "more below ↓", 13, Color(P.INK_SOFT, words))
	K.text(self, P.ui(700), Vector2(cx, r.end.y - 24), "Tap anywhere to start", 14, Color(P.INK_SOFT, words))


## The hint, wrapped, each line drawn only where it is inside the view (so
## a scrolled hint never spills over the title or the foot).
func _hint_lines(font: Font, x0: float, y: float, view: Rect2, col: Color) -> void:
	var para := TextParagraph.new()
	para.add_string(level.hint, font, HINT_SIZE)
	para.width = TEXT_W
	para.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line_h := font.get_height(HINT_SIZE)
	for i in para.get_line_count():
		var ly := y + i * line_h
		if ly >= view.position.y - 2 and ly + line_h <= view.end.y + 2:
			para.draw_line(get_canvas_item(), Vector2(x0, ly), i, col)
