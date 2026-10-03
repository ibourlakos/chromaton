## Shown over the workbench after a solve: stars, Pieces and Ticks, and the
## new invention on invention levels.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const Invention = preload("res://core/invention.gd")

signal replay
signal levels
signal next

const DESIGN := Vector2(1280, 800)
## Where the splashes land, in order: left and right of the card by turns.
const SPLASHES := [
	Vector2(130, 150), Vector2(1150, 140), Vector2(235, 300), Vector2(1045, 290),
	Vector2(115, 440), Vector2(1165, 430), Vector2(240, 580), Vector2(1040, 570),
	Vector2(140, 710), Vector2(1150, 705),
]

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
	var h := 440.0 if invention.is_empty() else 540.0
	card = Rect2(DESIGN.x / 2 - 310, DESIGN.y / 2 - h / 2 - 10, 620, h)
	var buttons := [["reset", replay, Keys.label("replay")], ["levels", levels, Keys.label("back")]]
	if has_next:
		buttons.append(["next", next, Keys.label("next")])
	var total := buttons.size() * 76 - 16
	for i in buttons.size():
		var b = ToyButton.make(buttons[i][0], Vector2(60, 60))
		b.position = Vector2(DESIGN.x / 2 - total / 2.0 + i * 76, card.end.y - 84)
		b.key = buttons[i][2]
		b.toggled_on = buttons[i][0] == "next"
		var sig: Signal = buttons[i][1]
		b.pressed.connect(func(): sig.emit())
		add_child(b)


## Enter (or →) for the next level, R to replay, Esc for the levels. Not
## Space: it may still be held from running the machine.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match Keys.action(event, "Woven"):
		"next":
			if has_next:
				next.emit()
		"replay":
			replay.emit()
		"back":
			levels.emit()
		_:
			return
	Keys.handled(self)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), P.VEIL)
	_splashes()
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
	# The finished tapestry
	var box := Rect2(card.position + Vector2(36, 168), Vector2(214, 158))
	_tapestry(box)
	# Metrics
	var font := P.ui(800)
	var bx := card.position.x + 282
	var y := card.position.y + 196
	for row in [["pieces", "Pieces", pieces, better.get("pieces", false)], ["ticks", "Ticks", ticks, better.get("ticks", false)]]:
		K.icon(self, row[0], Vector2(bx, y), 1.2, P.INK)
		K.text(self, font, Vector2(bx + 22, y), row[1], 22, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		K.text(self, P.display(600), Vector2(bx + 210, y), str(row[2]), 28, P.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		if row[3]:
			var badge := Rect2(bx + 222, y - 13, 70, 26)
			K.shape(self, K.round_rect(badge, 13), P.WOOD_LT, P.INK, 2)
			K.text(self, P.ui(800), badge.get_center(), "best!", 14, P.INK)
		y += 44
	# How to earn more stars
	if stars < 3:
		var want := stars + 1
		for s in want:
			K.star(self, Vector2(bx + 4 + s * 20, y + 4), 8, true)
		K.text(self, P.ui(700), Vector2(bx + 4 + want * 20, y + 4), "with %d pieces or fewer" % (level.best if want == 3 else level.budget), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	if not invention.is_empty():
		var sy := card.position.y + 380
		var paint := Invention.paint_of(invention)
		if paint >= 0:
			K.pot(self, Vector2(cx - 60, sy + 4), 0.55, clampf(t - 1.2, 0, 99), t, 0.3, paint)
		else:
			K.sticker(self, Vector2(cx - 60, sy), 1.1, invention["name"], clampf(t - 1.2, 0, 99), t, 0.3)
		K.icon(self, "next", Vector2(cx + 20, sy), 1.0, P.INK)
		K.icon(self, "book", Vector2(cx + 64, sy), 1.6, P.INK)
		var note: String = "%s for your Pattern Book" % invention["name"] if paint >= 0 else "New piece for your Pattern Book"
		K.text(self, P.ui(700), Vector2(cx, sy + 46), note, 16, P.INK_SOFT)


## The woven picture in a little frame; stitches appear row by row.
func _tapestry(box: Rect2) -> void:
	var cols: int = level.cols
	var rows: int = level.rows
	var cs := floorf(minf((box.size.x - 24) / cols, (box.size.y - 24) / rows))
	var cloth_size := Vector2(cols, rows) * cs
	var o := box.get_center() - cloth_size / 2
	K.shape(self, K.round_rect(Rect2(o - Vector2(10, 10), cloth_size + Vector2(20, 20)), 6), P.WOOD, P.INK, 2.5)
	draw_rect(Rect2(o, cloth_size), P.CLOTH)
	var shown := int(clampf(t / 0.9, 0, 1) * level.size())
	for i in shown:
		var c: int = level.target[i]
		var cell := Rect2(o + Vector2(i % cols, i / cols) * cs, Vector2(cs, cs)).grow(-0.5)
		K.fill(self, K.round_rect(cell, cs * 0.25, 2), P.WHITE_STITCH if c == 0 else P.SIG[c])


## Splashes of wood and paper tones (never paint colors: those are reserved)
## land one after another on both sides of the card, each with a few
## flecks, then soak away.
func _splashes() -> void:
	var colors := [P.WOOD, P.WOOD_LT, P.HOOP, P.TAG, P.WOOD_DK]
	for i in SPLASHES.size():
		var h1 := float((i * 7919) % 997) / 997.0
		var h2 := float((i * 104729) % 991) / 991.0
		var age := t - (0.1 + i * 0.22)
		if age < 0:
			continue
		var fade := clampf(1.0 - (age - 2.6) / 1.0, 0, 1)
		if fade <= 0:
			continue
		var u := clampf(age / 0.22, 0, 1)
		var pop := 1.0 + 0.25 * sin(u * PI) if u < 1 else 1.0  # lands, bulges, settles
		var c: Vector2 = SPLASHES[i] + Vector2(h1 - 0.5, h2 - 0.5) * 40
		var r := (26.0 + h2 * 16) * u * pop
		var col: Color = Color(colors[i % colors.size()], fade)
		var ink := Color(P.INK, fade)
		var blob := PackedVector2Array()
		for k in 48:
			var a := k * TAU / 48
			blob.append(c + Vector2(cos(a), sin(a)) * r * (1 + 0.09 * sin(6 * a + i) + 0.05 * sin(11 * a + 2 * i)))
		K.shape(self, blob, col, ink, 2)
		for k in 5:
			var a := i * 1.7 + k * TAU / 5 + h1
			var d := r * (1.45 + 0.3 * sin(k * 2.1 + i))
			K.shape(self, K.ellipse(c + Vector2(cos(a), sin(a)) * d, r * 0.12 + 1, r * 0.12 + 1, 0, 12), col, ink, 1.5)
