## A chunky tag-paper button drawn in code. Works by tap or click; nothing
## depends on hover. Shows an icon (see DrawKit.icon) or a custom drawing.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")

signal pressed

var icon := ""
var toggled_on := false
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
## Optional custom drawing: func(button: Control, rect: Rect2, down: bool).
var painter: Callable
var rounded := true

var _down := false


static func make(icon_kind: String, size_px := Vector2(52, 52)):
	var b = load("res://ui/toy_button.gd").new()
	b.icon = icon_kind
	b.custom_minimum_size = size_px
	b.size = size_px
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
		elif _down:
			_down = false
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _down and not Rect2(Vector2.ZERO, size).has_point(event.position):
		_down = false
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var press := Vector2(0, 2) if _down else Vector2.ZERO
	if painter.is_valid():
		painter.call(self, r, _down)
		return
	var rad := minf(size.x, size.y) / 2 if rounded else 12.0
	if not _down:
		K.fill(self, K.round_rect(Rect2(r.position + Vector2(0, 3), r.size), rad), P.SHADOW)
	var face := P.INK if toggled_on else P.TAG
	var body := K.round_rect(Rect2(r.position + press, r.size - Vector2(0, 1)), rad)
	K.shape(self, body, face, P.INK, 2.5)
	var col := P.TAG if toggled_on else P.INK
	if disabled:
		col = Color(col, 0.3)
	K.icon(self, icon, r.get_center() + press, minf(size.x, size.y) / 52.0, col)
