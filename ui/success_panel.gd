## Shown over the workbench after a solve: stars, Pieces and Ticks, and the
## new invention on invention levels.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")

signal replay
signal levels
signal next

const DESIGN := Vector2(1280, 800)

var level
var pieces := 0
var ticks := 0
var stars := 0
var better := {}
var invention := {}
var has_next := false
var t := 0.0
var card := Rect2()


func setup(p_level, p_pieces: int, p_ticks: int, p_stars: int, p_better: Dictionary, p_invention: Dictionary, p_has_next: bool) -> void:
	level = p_level
	pieces = p_pieces
	ticks = p_ticks
	stars = p_stars
	better = p_better
	invention = p_invention
	has_next = p_has_next


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := 430.0 if invention.is_empty() else 540.0
	card = Rect2(DESIGN.x / 2 - 270, DESIGN.y / 2 - h / 2 - 10, 540, h)
	var buttons := [["reset", replay], ["levels", levels]]
	if has_next:
		buttons.append(["next", next])
	var total := buttons.size() * 76 - 16
	for i in buttons.size():
		var b = ToyButton.make(buttons[i][0], Vector2(60, 60))
		b.position = Vector2(DESIGN.x / 2 - total / 2.0 + i * 76, card.end.y - 84)
		b.toggled_on = buttons[i][0] == "next"
		var sig: Signal = buttons[i][1]
		b.pressed.connect(func(): sig.emit())
		add_child(b)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), P.VEIL)
	K.fill(self, K.round_rect(Rect2(card.position + Vector2(5, 8), card.size), 22), P.SHADOW)
	K.shape(self, K.round_rect(card, 22), P.TAG, P.INK, 3)
	var cx := card.get_center().x
	K.text(self, P.display(600), Vector2(cx, card.position.y + 44), "Woven!", 38, P.INK)
	# Stars pop in one by one.
	for i in 3:
		var start := 0.3 + i * 0.28
		var u := clampf((t - start) / 0.35, 0, 1)
		var pop := 1.0 + sin(u * PI) * 0.35 if u < 1 else 1.0
		var filled := i < stars and t > start
		var r := 34.0 * (pop if filled else 1.0)
		K.star(self, Vector2(cx + (i - 1) * 86, card.position.y + 118 - (8 if i == 1 else 0)), r, filled)
	# Metrics
	var font := P.ui(800)
	var y := card.position.y + 196
	for row in [["pieces", "Pieces", pieces, better.get("pieces", false)], ["ticks", "Ticks", ticks, better.get("ticks", false)]]:
		K.icon(self, row[0], Vector2(cx - 120, y), 1.2, P.INK)
		K.text(self, font, Vector2(cx - 96, y), row[1], 22, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		K.text(self, P.display(600), Vector2(cx + 60, y), str(row[2]), 28, P.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		if row[3]:
			var badge := Rect2(cx + 76, y - 13, 70, 26)
			K.shape(self, K.round_rect(badge, 13), P.WOOD_LT, P.INK, 2)
			K.text(self, P.ui(800), badge.get_center(), "best!", 14, P.INK)
		y += 42
	# How to earn more stars
	var hint := ""
	if stars < 3:
		hint = "%s with %d pieces or fewer" % ["★★★" if stars == 2 else "★★", level.best if stars == 2 else level.budget]
		K.text(self, P.ui(700), Vector2(cx, y + 4), hint, 16, P.INK_SOFT)
	if not invention.is_empty():
		var sy := y + 64
		K.sticker(self, Vector2(cx - 60, sy), 1.1, invention["name"], clampf(t - 1.2, 0, 99), t, 0.3)
		K.icon(self, "next", Vector2(cx + 20, sy), 1.0, P.INK)
		K.icon(self, "book", Vector2(cx + 64, sy), 1.6, P.INK)
		K.text(self, P.ui(700), Vector2(cx, sy + 46), "New piece for your Pattern Book", 16, P.INK_SOFT)
