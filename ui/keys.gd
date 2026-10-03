## Keyboard hints: small key caps drawn next to the controls they press.
##
## Every key only speeds up something a tap already does, so nothing needs a
## keyboard. The caps show by default unless the device has a touch screen;
## touching the screen hides them, pressing a key brings them back, and H (or
## ?) turns them on and off.
extends RefCounted

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")

const GROUP := "key_hints"  # nodes that draw caps and must redraw on a toggle

static var shown := not DisplayServer.is_touchscreen_available()
static var _turned_off := false  # by H: a key press doesn't bring them back


## Watches every input event (called from the root screen before anything
## handles it). Returns true when the event was the show/hide key.
static func watch(event: InputEvent, tree: SceneTree) -> bool:
	if event is InputEventScreenTouch and event.pressed and shown:
		_show(false, tree)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H or event.keycode == KEY_SLASH or event.keycode == KEY_QUESTION:
			_turned_off = shown
			_show(not shown, tree)
			return true
		if not shown and not _turned_off:
			_show(true, tree)
	return false


static func _show(on: bool, tree: SceneTree) -> void:
	shown = on
	tree.call_group(GROUP, "queue_redraw")


## Draws a key cap centred on c (when hints are shown).
static func cap(ci: CanvasItem, c: Vector2, label: String) -> void:
	if not shown or label == "":
		return
	var font := P.ui(800)
	var w := maxf(20.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10)
	var r := Rect2(c - Vector2(w / 2, 10), Vector2(w, 20))
	K.fill(ci, K.round_rect(Rect2(r.position + Vector2(0, 2), r.size), 5), P.SHADOW)
	K.shape(ci, K.round_rect(r, 5), P.PAPER, Color(P.INK, 0.7), 1.5)
	if label == "←" or label == "→":
		# The fonts have no arrows: draw one.
		var d := -1.0 if label == "←" else 1.0
		ci.draw_line(c - Vector2(5 * d, 0), c + Vector2(4 * d, 0), P.INK, 2)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(6 * d, 0), c + Vector2(1 * d, -4), c + Vector2(1 * d, 4)]), P.INK)
	else:
		K.text(ci, font, c, label, 12, P.INK)


## Marks a key as used so no other screen acts on it.
static func handled(node: Node) -> void:
	if node.is_inside_tree():
		node.get_viewport().set_input_as_handled()
