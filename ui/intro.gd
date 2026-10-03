## The short note shown at launch: this is an early build, and an update may
## reset saved progress. One tap anywhere (or Enter, the level select's
## Continue key) goes on.
##
## When the save no longer fits this build (core/progress.gd, problems()) the
## note says so instead and asks: start fresh, or keep the levels and
## inventions that still fit. Either way the old file is moved to a .bak.
## Enter starts fresh.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")

signal done
signal fresh
signal keep

const DESIGN := Vector2(1280, 800)
const BUTTON := Vector2(220, 60)

var stale := false
var card := Rect2()
var t := 0.0


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	card = Rect2(DESIGN.x / 2 - 360, 205, 720, 370)
	var y := card.end.y - BUTTON.y - 34
	var buttons := [["next", "Let's paint", done, Keys.label("continue")]]
	if stale:
		buttons = [["reset", "Start fresh", fresh, Keys.label("continue")], ["check", "Keep what fits", keep, ""]]
	var total := buttons.size() * (BUTTON.x + 24) - 24
	for i in buttons.size():
		var b = ToyButton.make(buttons[i][0], BUTTON)
		b.position = Vector2(DESIGN.x / 2 - total / 2 + i * (BUTTON.x + 24), y)
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


## Without a question to answer, a tap anywhere goes on.
func _gui_input(event: InputEvent) -> void:
	if not stale and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		done.emit()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and Keys.action(event, "Levels") == "continue":
		(fresh if stale else done).emit()
		Keys.handled(self)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	K.fill(self, K.round_rect(Rect2(card.position + Vector2(5, 8), card.size), 22), P.SHADOW)
	K.shape(self, K.round_rect(card, 22), P.TAG, P.INK, 3)
	# An empty mix tub peeks over the card's corner, stirring now and then.
	K.tub(self, card.position + Vector2(72, -10), 0.7, -1, fmod(t, 2.4), "mix", t, 0.4)
	var cx := card.get_center().x
	var title := "Welcome to an early build!"
	var lines := [
		"Chromaton is still being made, so things will change.",
		"An update may reset your saved progress.",
		"Thanks for playing, and for telling us what you think.",
	]
	if stale:
		lines = [
			"This update no longer fits your saved game.",
			"Start fresh, or keep the levels that still fit?",
			"Your old save is tucked away in a backup either way.",
		]
	K.text(self, P.display(600), Vector2(cx, card.position.y + 72), title, 34, P.INK)
	var font := P.ui(700)
	for i in lines.size():
		K.text(self, font, Vector2(cx, card.position.y + 140 + i * 36), lines[i], 21, P.INK_SOFT if i == 2 else P.INK)
