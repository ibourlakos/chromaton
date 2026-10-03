## The note shown at launch when the saved game no longer fits this build
## (core/progress.gd, problems()): start fresh, or keep the levels and
## inventions that still fit. Either way the old file is moved to a .bak.
## Enter (the level select's Continue key) starts fresh.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")

signal fresh
signal keep

const DESIGN := Vector2(1280, 800)
const BUTTON := Vector2(220, 60)

var card := Rect2()


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = Rect2(DESIGN.x / 2 - 330, 200, 660, 360)
	var y := card.end.y - BUTTON.y - 36
	var buttons := [["reset", "Start fresh", fresh, Keys.label("continue")], ["check", "Keep what fits", keep, ""]]
	for i in buttons.size():
		var b = ToyButton.make(buttons[i][0], BUTTON)
		b.position = Vector2(DESIGN.x / 2 - BUTTON.x - 12 + i * (BUTTON.x + 24), y)
		b.painter = _label_painter(buttons[i][0], buttons[i][1], i == 0)
		b.key = buttons[i][3]
		var sig: Signal = buttons[i][2]
		b.pressed.connect(func(): sig.emit())
		add_child(b)


## A wide toy button with an icon and a word on it (the first one inked).
func _label_painter(icon: String, label: String, inked: bool) -> Callable:
	return func(b: Control, r: Rect2, down: bool) -> void:
		var press := Vector2(0, 2) if down else Vector2.ZERO
		if not down:
			K.fill(b, K.round_rect(Rect2(r.position + Vector2(0, 3), r.size), 18), P.SHADOW)
		var face := P.INK if inked else P.TAG
		var col := P.TAG if inked else P.INK
		K.shape(b, K.round_rect(Rect2(r.position + press, r.size - Vector2(0, 1)), 18), face, P.INK, 2.5)
		var font := P.display(600)
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var x := r.get_center().x - (w + 34) / 2
		K.icon(b, icon, Vector2(x + 12, r.get_center().y) + press, 1.0, col)
		K.text(b, font, Vector2(x + 34, r.get_center().y) + press, label, 22, col, HORIZONTAL_ALIGNMENT_LEFT)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and Keys.action(event, "Levels") == "continue":
		fresh.emit()
		Keys.handled(self)


func _draw() -> void:
	K.fill(self, K.round_rect(Rect2(card.position + Vector2(5, 8), card.size), 22), P.SHADOW)
	K.shape(self, K.round_rect(card, 22), P.TAG, P.INK, 3)
	var cx := card.get_center().x
	K.text(self, P.display(600), Vector2(cx, card.position.y + 58), "Your saved game is from an older build", 32, P.INK)
	var font := P.ui(700)
	var lines := [
		"Some of it no longer fits the levels in this one.",
		"Start fresh, or keep the levels that still fit?",
		"Your old save is tucked away in a backup either way.",
	]
	for i in lines.size():
		K.text(self, font, Vector2(cx, card.position.y + 124 + i * 34), lines[i], 20, P.INK_SOFT if i == 2 else P.INK)
