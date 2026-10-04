## The level's note: pops up over the workbench as a level opens, with its
## title, goal and hint, and lands under the title when tapped (or on any
## key). Tapping the title brings it back. DESIGN.md "Level text teaches".
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const Keys = preload("res://ui/keys.gd")

signal landed

const DESIGN := Vector2(1280, 800)
const POP := 0.25  # seconds to pop up
const LAND := 0.45  # seconds to fly home under the title
const HINT_WIDTH := 520.0
## How wide the line under the title may run before the run controls; a
## longer one wraps onto a second, smaller line (line_size).
const LINE_WIDTH := 640.0

var level
var home := Rect2()  # the line under the title it lands on
var t := 0.0
var leaving := -1.0  # seconds since it was sent home (-1: still up)
var card := Rect2()


## `home` is the left middle of the line under the title, where the hint
## (or the goal, on a level without one) sits once the note has landed.
func setup(p_level, p_home: Vector2) -> void:
	level = p_level
	var w := P.ui(700).get_string_size(line(level), HORIZONTAL_ALIGNMENT_LEFT, -1, line_size(level)).x
	home = Rect2(p_home - Vector2(0, 11), Vector2(minf(w, LINE_WIDTH), 22 if line_size(level) == 15 else 30))


## The text under the title: the hint, or the goal when there is none.
static func line(p_level) -> String:
	return p_level.hint if p_level.hint != "" else p_level.goal


## The font size of the line under the title: 15, or 12 on two lines when it
## doesn't fit on one (a hint of two sentences).
static func line_size(p_level) -> int:
	return 15 if P.ui(700).get_string_size(line(p_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x <= LINE_WIDTH else 12


## How many lines the hint takes on the note.
static func hint_lines(p_level) -> int:
	if p_level.hint == "":
		return 0
	var size := P.ui(700).get_multiline_string_size(p_level.hint, HORIZONTAL_ALIGNMENT_CENTER, HINT_WIDTH, 22)
	return maxi(1, roundi(size.y / P.ui(700).get_height(22)))


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := 212.0 + P.ui(700).get_height(22) * maxi(2, hint_lines(level)) if level.hint != "" else 168.0
	card = Rect2(DESIGN.x / 2 - 310, DESIGN.y / 2 - h / 2 - 20, 620, h)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismiss()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		dismiss()
		Keys.handled(self)


## Sends the note home under the title.
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
	# Pops up from a little smaller; flies home shrinking onto the line under
	# the title, its words fading first.
	var p := clampf(t / POP, 0, 1)
	var grow := 0.92 + 0.08 * (1 - pow(1 - p, 3))
	var r := Rect2(card.get_center() - card.size * grow / 2, card.size * grow)
	r = Rect2(r.position.lerp(home.position, e), r.size.lerp(home.size, e))
	var words := clampf(1 - u * 2.5, 0, 1)
	var a := 1 - e * e
	K.fill(self, K.round_rect(Rect2(r.position + Vector2(5, 8), r.size), 22 * (1 - e) + 4), Color(P.SHADOW, P.SHADOW.a * a))
	K.shape(self, K.round_rect(r, 22 * (1 - e) + 4), Color(P.TAG, a), Color(P.INK, a), 3)
	if words <= 0:
		return
	var cx := r.get_center().x
	var y := r.position.y
	K.text(self, P.display(600), Vector2(cx, y + 46), "%d · %s" % [level.number, level.name], 32, Color(P.INK, words))
	K.text(self, P.ui(700), Vector2(cx, y + 92), level.goal, 20, Color(P.INK_SOFT, words))
	if level.hint != "":
		var font := P.ui(700)
		for i in 9:  # a dotted rule between the goal and the hint
			K.disc(self, Vector2(cx - 64 + i * 16, y + 126), 2, Color(P.HOOP, words))
		draw_multiline_string(font, Vector2(r.position.x + 50, y + 168), level.hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 100, 22, -1, Color(P.INK, words))
	K.text(self, P.ui(700), Vector2(cx, r.end.y - 26), "Tap anywhere to start", 14, Color(P.INK_SOFT, words))
