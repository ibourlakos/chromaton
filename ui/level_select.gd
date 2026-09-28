## Level select: one tag per level with its picture and stars.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")

signal level_chosen(index: int)
signal book_requested

const DESIGN := Vector2(1280, 800)
const TAG := Vector2(300, 176)
const GAP := Vector2(28, 22)

var levels: Array = []
var progress
var t := 0.0


func setup(p_levels: Array, p_progress) -> void:
	levels = p_levels
	progress = p_progress


func _ready() -> void:
	size = DESIGN
	var ids := levels.map(func(l): return l.id)
	var origin := Vector2(DESIGN.x / 2 - (3 * TAG.x + 2 * GAP.x) / 2, 176)
	for i in levels.size():
		var b = ToyButton.new()
		b.custom_minimum_size = TAG
		b.size = TAG
		b.position = origin + Vector2(i % 3, i / 3) * (TAG + GAP)
		b.painter = _paint_tag.bind(i, progress.is_unlocked(ids, i))
		b.disabled = not progress.is_unlocked(ids, i)
		b.pressed.connect(func(): level_chosen.emit(i))
		add_child(b)
	var book = ToyButton.make("book", Vector2(64, 64))
	book.position = Vector2(DESIGN.x - 96, 40)
	book.pressed.connect(func(): book_requested.emit())
	add_child(book)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	K.text(self, P.display(600), Vector2(DESIGN.x / 2, 74), "Chromaton", 56, P.INK)
	K.text(self, P.ui(700), Vector2(DESIGN.x / 2, 124), "Invent machines out of paint", 18, P.INK_SOFT)
	# A few drops dancing under the title
	for i in 8:
		var c: int = [1, 2, 4, 3, 6, 5, 7, 0][i]
		var bob := sin(t * 2.2 + i * 0.8) * 3
		if i < 4:
			K.drop(self, Vector2(DESIGN.x / 2 - 390 + i * 34, 80 + bob), 11, c)
		else:
			K.drop(self, Vector2(DESIGN.x / 2 + 288 + (i - 4) * 34, 80 + bob), 11, c)


func _paint_tag(b: Control, r: Rect2, down: bool, i: int, open: bool) -> void:
	var level = levels[i]
	var press := Vector2(0, 2) if down else Vector2.ZERO
	if not down:
		K.fill(b, K.round_rect(Rect2(r.position + Vector2(3, 5), r.size), 14), P.SHADOW)
	var body := Rect2(r.position + press, r.size)
	K.shape(b, K.round_rect(body, 14), P.TAG if open else P.PAPER_DK, P.INK if open else Color(P.INK, 0.35), 2.5)
	var ink := P.INK if open else Color(P.INK, 0.4)
	var num := body.position + Vector2(26, 26)
	K.shape(b, K.ellipse(num, 16, 16, 0, 24), P.WOOD_LT if open else P.PAPER, ink, 2)
	K.text(b, P.display(600), num + Vector2(0, 1), str(i + 1), 18, ink)
	K.text(b, P.display(600), body.position + Vector2(50, 26), level.name, 19, ink, HORIZONTAL_ALIGNMENT_LEFT)
	if not level.invention.is_empty():
		K.sticker(b, body.position + Vector2(body.size.x - 44, 142), 0.5, level.invention["name"], 99, t, 0.2)
	if open:
		# The picture this level weaves
		var pic := Rect2(body.position + Vector2(18, 52), Vector2(150, 110))
		var cs := minf(pic.size.x / level.cols, pic.size.y / level.rows)
		var size_px := Vector2(level.cols, level.rows) * cs
		var o := pic.position + (pic.size - size_px) / 2
		b.draw_rect(Rect2(o - Vector2(4, 4), size_px + Vector2(8, 8)), P.CLOTH)
		for k in level.size():
			var c: int = level.target[k]
			b.draw_rect(Rect2(o + Vector2(k % level.cols, k / level.cols) * cs, Vector2(cs, cs)), P.WHITE_STITCH if c == 0 else P.SIG[c])
		b.draw_rect(Rect2(o - Vector2(4, 4), size_px + Vector2(8, 8)), Color(P.INK, 0.4), false, 1.5)
		var stars: int = progress.stars(level.id)
		for s in 3:
			K.star(b, body.position + Vector2(200 + s * 30, 78), 12, s < stars)
		var rec: Dictionary = progress.level_record(level.id)
		if rec.get("solved", false):
			K.icon(b, "pieces", body.position + Vector2(196, 110), 0.8, P.INK_SOFT)
			K.text(b, P.ui(700), body.position + Vector2(210, 110), str(rec.get("best_pieces", 0)), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
			K.icon(b, "ticks", body.position + Vector2(240, 110), 0.8, P.INK_SOFT)
			K.text(b, P.ui(700), body.position + Vector2(254, 110), str(rec.get("best_ticks", 0)), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		K.icon(b, "lock", body.get_center() + Vector2(0, 16), 1.6, Color(P.INK, 0.4))
