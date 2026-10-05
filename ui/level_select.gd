## Level select: one page per chapter, one tag per level with its picture
## and stars. Arrows turn the pages.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const Invention = preload("res://core/invention.gd")
const Level = preload("res://core/level.gd")

signal level_chosen(index: int)
signal book_requested
signal options_requested
signal page_changed(chapter: int)

const DESIGN := Vector2(1280, 800)
const TAG := Vector2(280, 142)
const GAP := Vector2(20, 16)
const COLUMNS := 4  # three rows fit a page: twelve levels per chapter at most
const TAGS_Y := 196.0
const DOTS_Y := 772.0
const HINTS_CHIP := Vector2(196, 34)

var levels: Array = []
var progress
var page := 0  # the chapter on show
var chapter_count := 1
var tags: Array = []  # the ToyButtons on this page
var prev_button
var next_button
var t := 0.0


func setup(p_levels: Array, p_progress, p_page := 0) -> void:
	levels = p_levels
	progress = p_progress
	for level in levels:
		chapter_count = maxi(chapter_count, level.chapter + 1)
	page = clampi(p_page, 0, chapter_count - 1)
	_build()


## Indices into levels of the levels on a chapter's page.
func page_levels(chapter: int) -> Array:
	var out := []
	for i in levels.size():
		if levels[i].chapter == chapter:
			out.append(i)
	return out


## Builds the screen's buttons; done in setup so the page works before it
## enters the tree.
func _build() -> void:
	size = DESIGN
	var book = ToyButton.make("book", Vector2(64, 64))
	book.position = Vector2(DESIGN.x - 96, 40)
	book.key = Keys.label("book")
	book.pressed.connect(func(): book_requested.emit())
	add_child(book)
	# Options on every build (the bench grid); its keys only where a keyboard is likely.
	var options = ToyButton.make("options", Vector2(64, 64))
	options.position = Vector2(32, 40)
	options.key = Keys.label("options")
	options.pressed.connect(func(): options_requested.emit())
	add_child(options)
	if Keys.rebindable():
		# Tells players the key labels can come and go: tap it, or press its key.
		var hints = ToyButton.new()
		hints.custom_minimum_size = HINTS_CHIP
		hints.size = HINTS_CHIP
		hints.position = Vector2(DESIGN.x / 2 - HINTS_CHIP.x / 2, DOTS_Y - 58)
		hints.painter = _paint_hints_chip
		hints.pressed.connect(func(): Keys.set_hints(not Keys.shown, get_tree()))
		add_child(hints)
	var left := DESIGN.x / 2 - (COLUMNS * TAG.x + (COLUMNS - 1) * GAP.x) / 2
	prev_button = ToyButton.make("back")
	prev_button.position = Vector2(left, DOTS_Y - 30)
	prev_button.key = Keys.label("prev_page")
	prev_button.key_above = true
	prev_button.pressed.connect(func(): turn(-1))
	add_child(prev_button)
	next_button = ToyButton.make("next")
	next_button.key = Keys.label("next_page")
	next_button.key_above = true
	next_button.position = Vector2(DESIGN.x - left - 52, DOTS_Y - 30)
	next_button.pressed.connect(func(): turn(1))
	add_child(next_button)
	_build_page()


## Turns by pages (negative for back); stops at the first and last chapter.
func turn(by: int) -> void:
	var to := clampi(page + by, 0, chapter_count - 1)
	if to == page:
		return
	page = to
	_build_page()
	page_changed.emit(page)


func _build_page() -> void:
	for b in tags:
		b.queue_free()
	tags.clear()
	var ids := levels.map(func(l): return l.id)
	var origin := Vector2(DESIGN.x / 2 - (COLUMNS * TAG.x + (COLUMNS - 1) * GAP.x) / 2, TAGS_Y)
	var on_page := page_levels(page)
	for k in on_page.size():
		var i: int = on_page[k]
		var b = ToyButton.new()
		b.custom_minimum_size = TAG
		b.size = TAG
		b.position = origin + Vector2(k % COLUMNS, k / COLUMNS) * (TAG + GAP)
		b.painter = _paint_tag.bind(i, progress.is_unlocked(ids, i))
		b.disabled = not progress.is_unlocked(ids, i)
		b.key = Keys.label("continue") if i == continue_level() else ""
		b.pressed.connect(func(): level_chosen.emit(i))
		add_child(b)
		tags.append(b)
	prev_button.visible = page > 0
	next_button.visible = page < chapter_count - 1
	queue_redraw()


## Keys (keys.gd): turn the pages, open the Pattern Book or Options, and play the first
## open level not yet solved (the tag wearing that key's cap).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match Keys.action(event, "Levels"):
		"prev_page":
			turn(-1)
		"next_page":
			turn(1)
		"book":
			book_requested.emit()
		"options":
			options_requested.emit()
		"continue":
			var i := continue_level()
			if i >= 0:
				level_chosen.emit(i)
		_:
			return
	Keys.handled(self)


## The first open level not yet solved, or -1 when every open level is solved.
func continue_level() -> int:
	var ids := levels.map(func(l): return l.id)
	for i in levels.size():
		if progress.is_unlocked(ids, i) and not progress.is_solved(ids[i]):
			return i
	return -1


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	K.text(self, P.display(600), Vector2(DESIGN.x / 2, 74), "Chromaton", 56, P.INK)
	K.text(self, P.ui(700), Vector2(DESIGN.x / 2, 124), "Invent machines out of paint", 18, P.INK_SOFT)
	K.text(self, P.display(600), Vector2(DESIGN.x / 2, 168), _chapter_name(page), 24, P.INK)
	# One dot per chapter, the one on show filled
	for ch in chapter_count:
		var at := Vector2(DESIGN.x / 2 + (ch - (chapter_count - 1) / 2.0) * 28, DOTS_Y)
		K.shape(self, K.ellipse(at, 7, 7, 0, 16), P.INK if ch == page else P.TAG, P.INK, 2)
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
	_stamp(b, body.position + Vector2(30, 29), level.number, open)
	# The primary title, smaller where it would run into the invention's icon.
	var room := body.size.x - 57 - (56.0 if not level.invention.is_empty() else 14.0)
	var name_size := 19
	while name_size > 13 and P.display(600).get_string_size(level.name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > room:
		name_size -= 1
	K.text(b, P.display(600), body.position + Vector2(57, 27), level.name, name_size, ink, HORIZONTAL_ALIGNMENT_LEFT)
	if not level.invention.is_empty():
		var paint := Invention.paint_of(level.invention)
		if paint >= 0:
			K.pot(b, body.position + Vector2(body.size.x - 30, 30), 0.3, 1.0, t, 0.2, paint)
		else:
			K.sticker(b, body.position + Vector2(body.size.x - 40, body.size.y - 24), 0.45, level.invention["name"], 99, t, 0.2)
	if open:
		# The picture this level weaves
		var pic := Rect2(body.position + Vector2(16, 50), Vector2(136, 80))
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
			K.star(b, body.position + Vector2(186 + s * 28, 70), 11, s < stars)
		var rec: Dictionary = progress.level_record(level.id)
		if rec.get("solved", false):
			K.icon(b, "pieces", body.position + Vector2(176, 100), 0.8, P.INK_SOFT)
			K.text(b, P.ui(700), body.position + Vector2(190, 100), str(rec.get("best_pieces", 0)), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
			K.icon(b, "ticks", body.position + Vector2(220, 100), 0.8, P.INK_SOFT)
			K.text(b, P.ui(700), body.position + Vector2(234, 100), str(rec.get("best_ticks", 0)), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	else:
		# A level waiting for an invention says where to earn it.
		var line := Level.waiting_line(levels, progress.waiting_for(level.id))
		K.icon(b, "lock", body.get_center() + Vector2(0, 4 if line != "" else 16), 1.6, Color(P.INK, 0.4))
		if line != "":
			var font := P.ui(700)
			b.draw_multiline_string(font, body.position + Vector2(16, 104 + font.get_ascent(14)), line, HORIZONTAL_ALIGNMENT_CENTER, body.size.x - 32, 14, 2, Color(P.INK, 0.6))


## The level's number as a rubber stamp in wood-brown ink: a scalloped ring
## pressed on a little askew (each number at its own tilt), so it doesn't read
## as a key or a button.
func _stamp(b: Control, c: Vector2, number: int, open: bool) -> void:
	var ink := Color(P.WOOD_DK, 0.95) if open else Color(P.INK, 0.25)
	K.set_xf(b, c, Vector2.ONE, -0.22 + 0.14 * sin(number * 2.3))
	var edge := PackedVector2Array()
	for i in 72:
		var a := i * TAU / 72
		edge.append(Vector2(cos(a), sin(a)) * (19.5 + 1.5 * cos(a * 12)))
	K.shape(b, edge, Color(P.WOOD_LT, 0.3) if open else Color(P.PAPER, 0.4), ink, 2)
	K.ring(b, Vector2.ZERO, 15, Color(ink, ink.a * 0.6), 1.2)
	var digits := Color(P.INK, 0.85) if open else ink
	for dx in [-0.4, 0.4]:  # pressed in thick, like a well-inked stamp
		K.text(b, P.display(700), Vector2(dx, 1), str(number), 19, digits)
	K.reset_xf(b)


## "[?] Hide key labels" (or Show): the key always shows here, labels on or off.
func _paint_hints_chip(b: Control, r: Rect2, down: bool) -> void:
	var press := Vector2(0, 2) if down else Vector2.ZERO
	var body := Rect2(r.position + press, r.size)
	if not down:
		K.fill(b, K.round_rect(Rect2(r.position + Vector2(0, 3), r.size), r.size.y / 2), P.SHADOW)
	K.shape(b, K.round_rect(body, r.size.y / 2), P.TAG, Color(P.INK, 0.5), 1.5)
	var key := Keys.label("hints")
	var w := maxf(20.0, Keys.text_width(key, 12) + 10)
	var cap := Rect2(body.position + Vector2(10, body.size.y / 2 - 10), Vector2(w, 20))
	K.shape(b, K.round_rect(cap, 5), P.PAPER, Color(P.INK, 0.7), 1.5)
	Keys.key_text(b, cap.get_center(), key, 12, P.INK)
	var text := "Hide key labels" if Keys.shown else "Show key labels"
	K.text(b, P.ui(700), Vector2(cap.end.x + 10, body.get_center().y), text, 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


func _chapter_name(chapter: int) -> String:
	for level in levels:
		if level.chapter == chapter:
			return level.chapter_name
	return ""
