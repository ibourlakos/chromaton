## "New in your journal": shown over the workbench after the success panel,
## when the solve brought something new: the words its level unlocks, and
## frames the player's machines filled on piece pages (DESIGN.md 5.7). A
## stepping stone into the rest of the campaign.
##
## Continue (Enter or →, as after weaving, or Back) goes on to wherever the
## success panel was sending the player; the book opens the journal on the
## new words.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const Pieces = preload("res://core/pieces.gd")

signal done
signal open_journal

const DESIGN := Vector2(1280, 800)
const FULL_TEXT := 3  # up to this many words show their text; more show as tiles

var words: Array = []
var frames: Array = []  # [piece kind, input colors] the player's machines showed
var picture: Callable  # draws a word's picture: func(ci, id, centre, scale)
var t := 0.0
var card := Rect2()


func setup(p_words: Array, p_frames: Array, p_picture: Callable) -> void:
	words = p_words
	frames = p_frames
	picture = p_picture


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := 150.0 + _words_height() + _frames_height()
	card = Rect2(DESIGN.x / 2 - 380, maxf(30, DESIGN.y / 2 - h / 2), 760, minf(h, DESIGN.y - 60))
	var go = ToyButton.make("next", Vector2(60, 60))
	go.position = Vector2(card.get_center().x + 8, card.end.y - 80)
	go.key = Keys.label("next")
	go.toggled_on = true
	go.pressed.connect(func(): done.emit())
	add_child(go)
	var book = ToyButton.make("book", Vector2(60, 60))
	book.position = Vector2(card.get_center().x - 68, card.end.y - 80)
	book.pressed.connect(func(): open_journal.emit())
	add_child(book)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or event.echo:
		return
	if Keys.action(event, "Woven") in ["next", "back"]:
		Keys.handled(self)
		done.emit()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _words_height() -> float:
	if words.is_empty():
		return 0.0
	if words.size() <= FULL_TEXT:
		return words.size() * 104.0
	return ceilf(words.size() / 4.0) * 76.0 + 30


## Frames by piece: kind -> [input colors], in the order they were found.
func _by_piece() -> Dictionary:
	var out := {}
	for f in frames:
		var list: Array = out.get(f[0], [])
		list.append(f[1])
		out[f[0]] = list
	return out


func _frames_height() -> float:
	return _by_piece().size() * 64.0 + (20.0 if not frames.is_empty() else 0.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, DESIGN), P.VEIL)
	K.fill(self, K.round_rect(Rect2(card.position + Vector2(5, 8), card.size), 22), P.SHADOW)
	K.shape(self, K.round_rect(card, 22), P.TAG, P.INK, 3)
	var cx := card.get_center().x
	K.icon(self, "book", Vector2(cx - 150, card.position.y + 42), 1.4, P.INK)
	K.text(self, P.display(600), Vector2(cx + 16, card.position.y + 42), "New in your journal", 30, P.INK)
	var y := card.position.y + 86
	if words.size() <= FULL_TEXT:
		for w in words:
			picture.call(self, str(w["id"]), Vector2(card.position.x + 70, y + 38), 0.8)
			K.text(self, P.display(600), Vector2(card.position.x + 130, y + 12), w["word"], 22, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			_para(Vector2(card.position.x + 130, y + 28), card.size.x - 160, w["text"], 15)
			y += 104
	else:
		for k in words.size():
			var w: Dictionary = words[k]
			var r := Rect2(card.position + Vector2(30 + (k % 4) * 177, y - card.position.y + (k / 4) * 76), Vector2(167, 66))
			K.shape(self, K.round_rect(r, 10), Color(P.PAPER, 0.6), Color(P.INK, 0.35), 1.5)
			picture.call(self, str(w["id"]), r.position + Vector2(34, 36), 0.45)
			K.text(self, P.display(600), Vector2(r.position.x + 70, r.get_center().y), w["word"], 16, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		y += ceilf(words.size() / 4.0) * 76
		K.text(self, P.ui(700), Vector2(cx, y + 8), "Read them on the Words tab.", 15, P.INK_SOFT)
		y += 30
	if not frames.is_empty():
		y += 20
		var by_piece := _by_piece()
		for kind in by_piece:
			var x := card.position.x + 40
			K.text(self, P.display(600), Vector2(x, y + 20), Pieces.display_name(kind), 20, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			x += 110
			for ins in by_piece[kind].slice(0, 6):
				for c in ins:
					K.drop(self, Vector2(x, y + 22), 10, c)
					x += 24
				K.icon(self, "next", Vector2(x, y + 22), 0.55, P.INK_SOFT)
				x += 22
				K.drop(self, Vector2(x, y + 22), 10, Pieces.apply(kind, ins)[0])
				x += 36
			if by_piece[kind].size() > 6:
				K.text(self, P.ui(700), Vector2(x, y + 22), "+%d" % (by_piece[kind].size() - 6), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
			y += 64


func _para(pos: Vector2, width: float, s: String, size: int) -> void:
	var font := P.ui(700)
	draw_multiline_string(font, Vector2(pos.x, pos.y + font.get_ascent(size)), s.replace("\n\n", " "), HORIZONTAL_ALIGNMENT_LEFT, width, size, 3, P.INK)
