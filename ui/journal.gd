## The journal (DESIGN.md 5.7): the player's own book of what they've learned,
## made and woven. Paper tabs along the top: Paint · Loom · Pieces ·
## Inventions · Cloths · Scores · Words.
##
## - Paint and Loom are short articles: the Gameplay text of the lexicon's
##   words for that tab (data/words.json), each with a small picture; Paint
##   also holds the paint card's triangle.
## - Pieces has a page per piece: its critter, its words, and a frame for
##   every paint it can be given, filled the first time the player's own
##   machine shows it doing that (Progress.seen). Mix and Filter take two
##   paints, so theirs is a table that fills both ways at once.
## - Inventions is the old Pattern Book: the paint shelf, then the invention
##   slots.
## - Cloths hangs every level's cloth, one chapter per page, empty until
##   woven, with the chapter's quilt beside them.
## - Scores is the scoreboard: best stars, Pieces and Ticks per level.
## - Words is the player's lexicon. A word unlocks when the level that brings
##   it in is solved; a locked word is an empty frame naming that level.
##
## Opened from the level select (book button, B) or over the workbench by
## peek (a piece's page). Everything is a tap; keys (keys.gd, group Journal)
## only do what a tap does: 1–7 a tab, Tab the next one, ← → turn pages (or
## step through pieces and words), Enter opens a word's page, Back, B or J
## closes.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const PaintCard = preload("res://ui/paint_card.gd")
const Level = preload("res://core/level.gd")
const Pieces = preload("res://core/pieces.gd")
const Paint = preload("res://core/paint.gd")
const Invention = preload("res://core/invention.gd")
const Progress = preload("res://core/progress.gd")
const Words = preload("res://core/words.gd")

signal back

const DESIGN := Vector2(1280, 800)
const TABS := [["paint", "Paint"], ["loom", "Loom"], ["pieces", "Pieces"], ["inventions", "Inventions"], ["cloths", "Cloths"], ["scores", "Scores"], ["words", "Words"]]
const PAGE := Rect2(40, 112, 1200, 674)
const TAB_TOP := 66.0
const SLOT := Vector2(306, 252)  # an invention's slot
const WORD_COLS := 4

static var last_tab := "paint"  # where the journal opens next time

var levels: Array = []
var progress
var words: Array = []
var tab := "paint"
var chapter := 0  # the Cloths and Scores page
var piece := 0  # the Pieces page
var word := 0  # the word picked on the Words tab
var overlay := false  # over the workbench: draws its own paper
var article_view: Control  # the open article (Paint, Loom), clipped so it scrolls
var article_scroll := 0.0
var article_focus := ""  # a word to scroll the article to (a peek on a tube or card)
var _press_at := Vector2(-1, -1)
var _dragged := false
var here = null  # the level it was opened from (peek): its pieces count as met
var t := 0.0
var pieces: Array = []  # piece kinds in the order the campaign brings them
var paint_card: Control
var prev_button
var next_button
var _pressed := ""


## focus: a piece kind ("mix", "inv:<id>"), "tube" or "card", for a peek, or
## "word:<id>" for a word; tab_id ""
## for the tab last open.
func setup(p_levels: Array, p_progress, tab_id := "", focus := "") -> void:
	levels = p_levels if not p_levels.is_empty() else Level.load_all()
	progress = p_progress
	words = Words.load_all()
	pieces = []
	if not levels.is_empty():
		pieces = levels[-1].tray.filter(func(k): return Pieces.TABLE.has(k))
	tab = last_tab
	if focus.begins_with("inv:"):
		tab = "inventions"
	elif focus.begins_with("word:"):  # "New in your journal": its first new word
		tab = "words"
		for i in words.size():
			if str(words[i]["id"]) == focus.substr(5):
				word = i
	elif focus in ["tube", "card"]:  # a tube or a pattern card: the Loom article at its word
		tab = "loom"
		article_focus = "tube" if focus == "tube" else "pattern-card"
	elif focus in pieces:
		tab = "pieces"
		piece = pieces.find(focus)
	if tab_id != "":
		tab = tab_id
	chapter = _first_unfinished_chapter()


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var b = ToyButton.make("back")
	b.position = Vector2(14, 6)
	b.key = Keys.label("back")
	b.pressed.connect(func(): back.emit())
	add_child(b)
	paint_card = PaintCard.new()
	paint_card.scale = Vector2(1.55, 1.55)
	paint_card.position = PAGE.position + Vector2(44, 70)
	add_child(paint_card)
	paint_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prev_button = ToyButton.make("back")
	prev_button.position = Vector2(PAGE.position.x + 24, PAGE.end.y - 66)
	prev_button.key = Keys.label("page_back")
	prev_button.key_above = true
	prev_button.pressed.connect(func(): turn(-1))
	add_child(prev_button)
	next_button = ToyButton.make("next")
	next_button.position = Vector2(PAGE.end.x - 76, PAGE.end.y - 66)
	next_button.key = Keys.label("page_forward")
	next_button.key_above = true
	next_button.pressed.connect(func(): turn(1))
	add_child(next_button)
	article_view = Control.new()
	article_view.clip_contents = true
	article_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	article_view.draw.connect(_draw_article_view)
	add_child(article_view)
	show_tab(tab)


func show_tab(id: String) -> void:
	if id != tab:
		article_scroll = 0.0
	tab = id
	last_tab = id
	if article_view != null:
		var r := _article_rect()
		article_view.position = r.position
		article_view.size = r.size
		article_view.visible = r.size.y > 0
	if article_focus != "":  # a peek: the article starts at that word
		for row in _article_rows():
			if row["w"]["id"] == article_focus:
				article_scroll = minf(row["y"], _article_max())
		article_focus = ""
	paint_card.visible = tab == "paint"
	_sync_arrows()
	queue_redraw()


func _sync_arrows() -> void:
	var paged := tab in ["cloths", "scores"]
	prev_button.visible = paged and chapter > 0
	next_button.visible = paged and chapter < _chapter_count() - 1


## ← and →: turn the chapter page, or step to the next piece or word.
func turn(by: int) -> void:
	match tab:
		"cloths", "scores":
			chapter = clampi(chapter + by, 0, _chapter_count() - 1)
		"pieces":
			piece = clampi(piece + by, 0, pieces.size() - 1)
		"words":
			word = clampi(word + by, 0, words.size() - 1)
	_sync_arrows()
	queue_redraw()


## A word's fuller page: its tab, and on Pieces its piece.
func open_word_page() -> void:
	if word >= words.size() or not Words.is_unlocked(words[word], progress):
		return
	var w: Dictionary = words[word]
	var kind: String = str(w["id"]).replace("-", "_")
	if kind in pieces:
		piece = pieces.find(kind)
	if w["tab"] != "" and w["tab"] != "words":
		show_tab(w["tab"])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var act := Keys.action(event, "Journal")
	if event.echo and not act in ["scroll_up", "scroll_down"]:
		return
	match act:
		"back", "close_journal":
			back.emit()
		"next_tab":
			show_tab(TABS[(_tab_index() + 1) % TABS.size()][0])
		"page_back":
			turn(-1)
		"page_forward":
			turn(1)
		"scroll_up":
			scroll_article(-ARTICLE_STEP)
		"scroll_down":
			scroll_article(ARTICLE_STEP)
		"open_page":
			if tab == "words":
				open_word_page()
		_:
			if act.begins_with("tab_"):
				show_tab(TABS[int(act.substr(4)) - 1][0])
			else:
				return
	Keys.handled(self)


func _gui_input(event: InputEvent) -> void:
	# An article scrolls with the wheel or a drag (a drag taps nothing).
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed and _article_rect().size.y > 0:
			scroll_article(-ARTICLE_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else ARTICLE_STEP)
		accept_event()
		return
	if event is InputEventMouseMotion and _press_at.x >= 0 and _article_rect().size.y > 0:
		if _dragged or event.position.distance_to(_press_at) > 8:
			_dragged = true
			scroll_article(-event.relative.y)
		accept_event()
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var hit := _target_at(event.position)
	if event.pressed:
		_pressed = hit
		_press_at = event.position
		_dragged = false
		return
	_press_at = Vector2(-1, -1)
	if _dragged or hit == "" or hit != _pressed:
		return
	_pressed = ""
	var parts := hit.split(":")
	match parts[0]:
		"tab":
			show_tab(parts[1])
		"piece":
			piece = int(parts[1])
		"word":
			word = int(parts[1])
		"open":
			open_word_page()
		"more":  # the chip scrolls on by most of a page
			scroll_article(_article_rect().size.y - 80)
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if article_view != null and article_view.visible:
		article_view.queue_redraw()


# ---------------------------------------------------------------------------
# What's where
# ---------------------------------------------------------------------------

func _tab_index() -> int:
	for i in TABS.size():
		if TABS[i][0] == tab:
			return i
	return 0


func _tab_rect(i: int) -> Rect2:
	var w := (PAGE.size.x - 40) / TABS.size()
	return Rect2(PAGE.position.x + 20 + i * w, TAB_TOP, w - 8, PAGE.position.y - TAB_TOP + 2)


func _piece_rect(i: int) -> Rect2:
	return Rect2(PAGE.position + Vector2(24, 24 + i * 100), Vector2(170, 90))


func _word_rect(i: int) -> Rect2:
	var rows := ceili(float(words.size()) / WORD_COLS)
	var h := minf(88.0, (PAGE.size.y - 48 - (rows - 1) * 10) / maxf(1, rows))
	return Rect2(PAGE.position + Vector2(24 + (i % WORD_COLS) * 180, 24 + (i / WORD_COLS) * (h + 10)), Vector2(170, h))


func _word_panel() -> Rect2:
	return Rect2(PAGE.position.x + 760, PAGE.position.y + 24, PAGE.size.x - 784, PAGE.size.y - 48)


func _open_rect() -> Rect2:
	var panel := _word_panel()
	return Rect2(panel.get_center().x - 110, panel.end.y - 76, 220, 52)


## What a tap at pos lands on: "tab:<id>", "piece:<i>", "word:<i>", "open" or "".
func _target_at(pos: Vector2) -> String:
	for i in TABS.size():
		if _tab_rect(i).has_point(pos):
			return "tab:" + TABS[i][0]
	if _more_rect().has_point(pos):
		return "more"
	match tab:
		"pieces":
			for i in pieces.size():
				if _piece_rect(i).has_point(pos):
					return "piece:%d" % i
		"words":
			for i in words.size():
				if _word_rect(i).has_point(pos):
					return "word:%d" % i
			if _has_page(word) and _open_rect().has_point(pos):
				return "open"
	return ""


func _has_page(i: int) -> bool:
	return i < words.size() and Words.is_unlocked(words[i], progress) and not str(words[i]["tab"]) in ["", "words"]


func _chapter_count() -> int:
	var n := 0
	for level in levels:
		n = maxi(n, level.chapter + 1)
	return n


func _chapter_levels(c: int) -> Array:
	return levels.filter(func(l): return l.chapter == c)


func _first_unfinished_chapter() -> int:
	for level in levels:
		if not progress.is_solved(level.id):
			return level.chapter
	return 0


## A level's number in the campaign, or fallback if it isn't one.
func _number_of(id: String, fallback: int) -> int:
	var level = _level_by_id(id)
	return level.number if level != null else fallback


func _level_by_id(id: String):
	for level in levels:
		if level.id == id:
			return level
	return null


func _ids() -> Array:
	return levels.map(func(l): return l.id)


## A piece is met once a level the player can open offers it, or the level
## the journal was opened from does.
func is_met(kind: String) -> bool:
	if here != null and kind in here.pieces:
		return true
	var ids := _ids()
	for i in levels.size():
		if kind in levels[i].pieces and progress.is_unlocked(ids, i):
			return true
	return false


func _tab_words(id: String) -> Array:
	return words.filter(func(w): return w["tab"] == id)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if overlay:
		draw_texture_rect(P.paper_texture(), Rect2(Vector2.ZERO, DESIGN), true)
	K.icon(self, "book", Vector2(DESIGN.x / 2 - 92, 32), 1.6, P.INK)
	K.text(self, P.display(600), Vector2(DESIGN.x / 2 + 14, 32), "Journal", 36, P.INK)
	# The tabs behind the page, the page, then the open tab joined to it.
	for i in TABS.size():
		if TABS[i][0] != tab:
			_draw_tab(i, false)
	K.fill(self, K.round_rect(Rect2(PAGE.position + Vector2(4, 6), PAGE.size), 18), P.SHADOW)
	K.shape(self, K.round_rect(PAGE, 18), P.TAG, P.INK, 2.5)
	_draw_tab(_tab_index(), true)
	match tab:
		"paint", "loom":
			pass  # drawn by article_view, over the page
		"pieces":
			_draw_pieces()
		"inventions":
			_draw_inventions()
		"cloths":
			_draw_cloths()
		"scores":
			_draw_scores()
		"words":
			_draw_words()


func _draw_tab(i: int, open: bool) -> void:
	var r := _tab_rect(i)
	var body := Rect2(r.position + (Vector2.ZERO if open else Vector2(0, 6)), r.size + (Vector2(0, 4) if open else Vector2.ZERO))
	var pts := K.round_rect(body, 12)
	K.shape(self, pts, P.TAG if open else P.PAPER_DK, P.INK if open else Color(P.INK, 0.45), 2.5 if open else 1.8)
	if open:  # no page edge under the open tab
		draw_rect(Rect2(body.position.x + 2, PAGE.position.y - 2, body.size.x - 4, 6), P.TAG)
	K.text(self, P.display(600), Vector2(r.get_center().x, r.position.y + 24 + (0 if open else 3)), TABS[i][1], 21, P.INK if open else P.INK_SOFT)
	Keys.cap(self, Vector2(r.end.x - 14, r.position.y + 4), Keys.label("tab_%d" % (i + 1)))


## Paragraphs that wrap at width, from pos (top left), on `ci` (the journal
## itself by default); returns their height.
func _para(pos: Vector2, width: float, s: String, size := 18, col := P.INK, ci: CanvasItem = null) -> float:
	var on: CanvasItem = ci if ci != null else self
	var font := P.ui(700)
	var y := pos.y
	for p in s.split("\n\n"):
		on.draw_multiline_string(font, Vector2(pos.x, y + font.get_ascent(size)), p, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, col)
		y += font.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, width, size).y + size * 0.6
	return y - pos.y


## How tall _para's paragraphs are, without drawing them.
static func _para_height(width: float, s: String, size := 18) -> float:
	var font := P.ui(700)
	var h := 0.0
	for p in s.split("\n\n"):
		h += font.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, width, size).y + size * 0.6
	return h


## A locked entry: an empty frame naming the level that unlocks it.
func _locked(r: Rect2, w: Dictionary, ci: CanvasItem = null) -> void:
	var on: CanvasItem = ci if ci != null else self
	K.dashed(on, K.closed(K.round_rect(r, 12)), Color(P.INK, 0.3), 2, 8, 6)
	var level = _level_by_id(str(w["level"]))
	K.text(on, P.display(600), Vector2(r.position.x + 40, r.get_center().y), "?", 34, Color(P.INK, 0.3))
	if level != null:
		K.text(on, P.ui(700), Vector2(r.position.x + 74, r.get_center().y), "Weave %s to read this." % level.ref_name(), 16, Color(P.INK, 0.45), HORIZONTAL_ALIGNMENT_LEFT)


# --- Articles (Paint, Loom) ----------------------------------------------------
#
# Words one under another: picture, word, Gameplay text. Each row is as tall
# as its picture or its text, whichever is taller, plus a gap; an article
# longer than its page scrolls (drag, the wheel, or the scroll keys), with a
# "more below" chip that scrolls on when tapped.

const ARTICLE_GAP := 18.0
const ARTICLE_STEP := 60.0  # a scroll key's or wheel notch's distance


## Where the open tab's article sits, or an empty rect on other tabs.
func _article_rect() -> Rect2:
	match tab:
		"paint":
			return Rect2(PAGE.position.x + 540, PAGE.position.y + 40, 620, PAGE.size.y - 60)
		"loom":
			return Rect2(PAGE.position + Vector2(40, 30), PAGE.size - Vector2(80, 50))
	return Rect2()


## Each word's row on the open tab's article: [{"w", "y", "h"}].
func _article_rows() -> Array:
	var width := _article_rect().size.x
	var rows := []
	var y := 0.0
	for w in _tab_words(tab):
		var h := 70.0
		if Words.is_unlocked(w, progress):
			h = maxf(80.0, 34.0 + _para_height(width - 116, w["text"], 17))
		rows.append({"w": w, "y": y, "h": h})
		y += h + ARTICLE_GAP
	return rows


## How far the article can scroll.
func _article_max() -> float:
	var rows := _article_rows()
	if rows.is_empty():
		return 0.0
	var last: Dictionary = rows[rows.size() - 1]
	return maxf(0.0, last["y"] + last["h"] - _article_rect().size.y)


func scroll_article(by: float) -> void:
	article_scroll = clampf(article_scroll + by, 0.0, _article_max())
	article_view.queue_redraw()


## Rows that end below the article's window.
func _rows_below() -> int:
	var bottom := article_scroll + _article_rect().size.y
	return _article_rows().filter(func(row): return row["y"] + row["h"] > bottom + 1).size()


## The "more below" chip at the article's foot, while there's more below.
func _more_rect() -> Rect2:
	var r := _article_rect()
	if r.size.y <= 0 or _rows_below() == 0:
		return Rect2()
	return Rect2(r.get_center().x - 80, r.end.y - 32, 160, 30)


## The article view's drawing (a clipped child, so rows scroll under the
## page's edge).
func _draw_article_view() -> void:
	var ci := article_view
	var r := _article_rect()
	if r.size.y <= 0:
		return
	article_scroll = clampf(article_scroll, 0.0, _article_max())
	for row in _article_rows():
		var y: float = row["y"] - article_scroll
		if y + row["h"] < 0 or y > r.size.y:
			continue
		var w: Dictionary = row["w"]
		if not Words.is_unlocked(w, progress):
			_locked(Rect2(0, y, r.size.x, 70), w, ci)
			continue
		picture(ci, str(w["id"]), Vector2(50, y + 40), 1.0, t, levels)
		K.text(ci, P.display(600), Vector2(116, y + 14), w["word"], 26, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		_para(Vector2(116, y + 34), r.size.x - 116, w["text"], 17, P.INK, ci)
	_draw_more_chip(ci, -r.position)


func _draw_more_chip(ci: CanvasItem, offset: Vector2) -> void:
	var m := _more_rect()
	if m.size.x <= 0:
		return
	m.position += offset
	var n := _rows_below()
	K.fill(ci, K.round_rect(Rect2(m.position + Vector2(0, 3), m.size), 15), P.SHADOW)
	K.shape(ci, K.round_rect(m, 15), P.TAG, Color(P.INK, 0.5), 1.5)
	K.text(ci, P.ui(700), m.get_center(), "%d more below ↓" % n, 14, P.INK_SOFT)

# --- Pieces ------------------------------------------------------------------

func _draw_pieces() -> void:
	for i in pieces.size():
		var r := _piece_rect(i)
		var met := is_met(pieces[i])
		var lit := i == piece
		K.shape(self, K.round_rect(r, 12), Color(P.HOOP, 0.25) if lit else (P.TAG if met else P.PAPER_DK), Color(P.INK, 0.8 if lit else 0.35), 2.5 if lit else 1.5)
		if met:
			critter(self, pieces[i], r.position + Vector2(48, r.size.y / 2), 0.62, t)
			# A long name (Shift Wheel, Mixing Tub) takes two lines.
			var name := Pieces.display_name(pieces[i])
			var lines := [name]
			if P.display(600).get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x > r.size.x - 96 and name.contains(" "):
				lines = name.split(" ", false, 1)
			for k in lines.size():
				K.text(self, P.display(600), Vector2(r.position.x + 92, r.get_center().y + (k - (lines.size() - 1) / 2.0) * 22), lines[k], 19, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			K.icon(self, "lock", r.get_center(), 1.4, Color(P.INK, 0.35))
	var kind: String = pieces[piece] if piece < pieces.size() else ""
	var area := Rect2(PAGE.position.x + 220, PAGE.position.y + 24, PAGE.size.x - 244, PAGE.size.y - 48)
	K.line(self, Vector2(area.position.x - 12, area.position.y), Vector2(area.position.x - 12, area.end.y), Color(P.INK, 0.12), 2)
	if kind == "" or not is_met(kind):
		K.text(self, P.display(600), area.get_center() + Vector2(0, -20), "?", 64, Color(P.INK, 0.25))
		K.text(self, P.ui(700), area.get_center() + Vector2(0, 40), "You haven't met this piece yet.", 18, Color(P.INK, 0.45))
		return
	critter(self, kind, area.position + Vector2(70, 70), 1.15, t)
	K.text(self, P.display(600), Vector2(area.position.x + 150, area.position.y + 26), Pieces.display_name(kind), 34, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var w := Words.find(kind.replace("_", "-"))
	if not w.is_empty() and Words.is_unlocked(w, progress):
		_para(Vector2(area.position.x + 150, area.position.y + 50), area.size.x - 160, w["text"], 17)
	elif not w.is_empty():
		var level = _level_by_id(str(w["level"]))
		K.text(self, P.ui(700), Vector2(area.position.x + 150, area.position.y + 66), "Weave %s to read about it. Till then, watch it work." % level.ref_name(), 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	var top := area.position.y + 170
	match kind:
		"shift", "invert":
			_draw_one_input(kind, Rect2(area.position.x, top, area.size.x, 200))
		"mix", "filter":
			_draw_two_inputs(kind, Vector2(area.position.x + 40, top))
		"red_pot":
			_fact(Vector2(area.position.x + 60, top + 60), [], [Paint.RED], "Every drop it makes is red.")
		"split":
			_fact(Vector2(area.position.x + 60, top + 60), [Paint.ORANGE], [Paint.ORANGE, Paint.ORANGE], "Whatever goes in comes out twice.")
	# Using the paint card for this piece, once its page is read.
	if CARD_LINES.has(kind) and not w.is_empty() and Words.is_unlocked(w, progress):
		if kind in ["shift", "invert"]:
			_card_line(Rect2(area.position.x, top + 214, area.size.x, 60), CARD_LINES[kind])
		else:
			var x := area.position.x + 40 + 9 * 44.0 + 30
			_card_line(Rect2(x, top + 170, area.end.x - x, 120), CARD_LINES[kind])
	# What it's made of: the levels that rebuild it.
	if kind in ["shift", "invert"]:
		_draw_made_of(kind, Rect2(area.position.x, top + 290, area.size.x, area.end.y - top - 290))
	elif kind in ["mix", "filter"]:
		var x2 := area.position.x + 40 + 9 * 44.0 + 30
		_draw_made_of(kind, Rect2(x2, top + 250, area.end.x - x2, area.end.y - top - 250))


## What a critter is made of: a row for each level that rebuilds it from
## other pieces, showing what the player's machine there used (its pieces,
## each with how many), or an empty frame naming the level until it's woven.
func _draw_made_of(kind: String, r: Rect2) -> void:
	var rebuilt := levels.filter(func(l): return l.rebuilds() == kind)
	if rebuilt.is_empty():
		return
	K.text(self, P.display(600), Vector2(r.position.x, r.position.y + 12), "Made of", 22, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var y := r.position.y + 34
	for level in rebuilt:
		var row := Rect2(r.position.x, y, minf(r.size.x, 520), 56)
		y += 64
		if not progress.is_solved(level.id):
			_locked(row, {"level": level.id})
			continue
		K.shape(self, K.round_rect(row, 12), P.TAG, Color(P.INK, 0.35), 1.5)
		K.text(self, P.ui(700), Vector2(row.position.x + 14, row.get_center().y), level.ref_name(), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		var x := row.position.x + 30 + P.ui(700).get_string_size(level.ref_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var counts := _machine_parts(progress.stored_machine(level.id))
		for part in counts:
			var c := Vector2(x + 26, row.get_center().y)
			if part.begins_with("inv:"):
				var inv: Dictionary = progress.inventions.get(part.substr(4), {})
				K.sticker(self, c + Vector2(8, 0), 0.42, str(inv.get("name", "?")), 99, t, 0.2)
				x += 70
			else:
				critter(self, part, c, 0.42, t)
				x += 44
			K.text(self, P.ui(800), Vector2(x + 6, row.get_center().y), "× %d" % counts[part], 15, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			x += 46


## The pieces a saved machine is built from, by tray kind ("inv:<id>" for an
## invention), with how many of each; cards and the loom aren't pieces.
static func _machine_parts(m: Dictionary) -> Dictionary:
	var out := {}
	for n in m.get("nodes", []):
		var kind: String = n["kind"]
		if kind in [Pieces.CARD, Pieces.LOOM]:
			continue
		var key := "inv:" + str(n.get("invention", "")) if kind == Pieces.INVENTION else kind
		out[key] = out.get(key, 0) + 1
	return out


## The line on using the paint card for a piece (levels/level-text.md),
## beside a little paint card. The red pot and Split have none.
const CARD_LINES := {
	"mix": "On the paint card, a mix sits between its two paints: red and yellow meet at orange.",
	"filter": "On the paint card, the Sieve keeps the corners two paints share: orange and purple share red.",
	"invert": "On the paint card, a paint's opposite sits straight across black.",
	"shift": "On the paint card, follow one arrow: every paint moves one corner on.",
}


func _card_line(r: Rect2, s: String) -> void:
	picture(self, "paint-card", r.position + Vector2(30, 26), 0.9, t, levels)
	_para(r.position + Vector2(70, 4), r.size.x - 70, s, 16, P.INK_SOFT)


## Shift and Invert: a frame per paint, the paint over what it becomes.
func _draw_one_input(kind: String, r: Rect2) -> void:
	var found := 0
	var step := minf(112.0, r.size.x / 8)
	for c in 8:
		var known: bool = progress.knows(kind, [c])
		found += int(known)
		var f := Rect2(r.position.x + c * step, r.position.y + 30, step - 12, 150)
		K.shape(self, K.round_rect(f, 12), P.TAG if known else Color(P.PAPER_DK, 0.6), Color(P.INK, 0.5 if known else 0.25), 1.8)
		var cx := f.get_center().x
		K.drop(self, Vector2(cx, f.position.y + 38), 16, c)
		K.icon(self, "next", Vector2(cx, f.position.y + 78), 0.7, Color(P.INK, 0.6 if known else 0.25))
		var out: int = Pieces.apply(kind, [c])[0]
		if known:
			K.drop(self, Vector2(cx, f.position.y + 118), 16, out)
		else:
			_unknown_drop(Vector2(cx, f.position.y + 118), 16)
	K.text(self, P.ui(700), Vector2(r.position.x, r.position.y + 6), "Found %d of 8" % found, 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


## Mix and Filter: a table of every pair, filled both ways once seen.
func _draw_two_inputs(kind: String, o: Vector2) -> void:
	var cs := 44.0
	var found := 0
	var origin := o + Vector2(cs, cs + 26)
	for c in 8:
		K.drop(self, origin + Vector2((c + 0.5) * cs, -cs * 0.45), 11, c)
		K.drop(self, origin + Vector2(-cs * 0.5, (c + 0.6) * cs), 11, c)
	for a in 8:
		for b in 8:
			var cell := Rect2(origin + Vector2(b, a) * cs, Vector2(cs, cs)).grow(-2)
			var known: bool = progress.knows(kind, [a, b])
			if known:
				if a <= b:
					found += 1
				K.fill(self, K.round_rect(cell, 6), P.TAG)
				K.drop(self, cell.get_center() + Vector2(0, 2), 11, Pieces.apply(kind, [a, b])[0])
			else:
				K.fill(self, K.round_rect(cell, 6), Color(P.PAPER_DK, 0.7))
	draw_rect(Rect2(origin, Vector2(8, 8) * cs), Color(P.INK, 0.3), false, 1.5)
	K.text(self, P.ui(700), Vector2(o.x, o.y + 6), "Found %d of 36" % found, 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	K.text(self, P.ui(700), Vector2(origin.x + 8 * cs + 30, origin.y + 30), "Each square is what the two", 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	K.text(self, P.ui(700), Vector2(origin.x + 8 * cs + 30, origin.y + 52), "paints beside it make.", 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


func _fact(o: Vector2, ins: Array, outs: Array, line: String) -> void:
	var x := o.x
	for c in ins:
		K.drop(self, Vector2(x, o.y), 18, c)
		x += 48
	K.icon(self, "next", Vector2(x, o.y), 1.0, P.INK)
	x += 48
	for c in outs:
		K.drop(self, Vector2(x, o.y), 18, c)
		x += 48
	K.text(self, P.ui(700), Vector2(x + 20, o.y), line, 18, P.INK, HORIZONTAL_ALIGNMENT_LEFT)


func _unknown_drop(c: Vector2, r: float) -> void:
	K.dashed(self, K.closed(K.teardrop(c, r)), Color(P.INK, 0.3), 1.5, 5, 4)
	K.text(self, P.display(600), c + Vector2(0, 2), "?", 16, Color(P.INK, 0.35))


static func critter(ci: CanvasItem, kind: String, c: Vector2, s: float, t: float) -> void:
	var look: String = Pieces.TABLE[kind]["look"] if Pieces.TABLE.has(kind) else "tub"
	var more := {"ins": [c + Vector2(-30, 0) * s], "outs": [c + Vector2(30, -16) * s, c + Vector2(30, 16) * s]}
	K.piece(ci, look, c, 0.6 * s, -1, 99, t, 0.4, more)


# --- Inventions (the old Pattern Book) ----------------------------------------

func _draw_inventions() -> void:
	var page := PAGE
	K.text(self, P.ui(700), Vector2(page.get_center().x, page.position.y + 30), "Machines you invented become pieces you can use again.", 17, P.INK_SOFT)
	_draw_shelf(page)
	var slots := _invention_slots()
	var origin := page.position + Vector2(64, 236)
	# Three slots to a row, or all in one row of narrower slots when there
	# are more (one row is all the page has room for).
	var across := maxi(3, slots.size())
	var gap := 46.0 if across == 3 else 16.0
	var span := 3 * SLOT.x + 2 * 46.0
	var size := Vector2((span - (across - 1) * gap) / across, SLOT.y)
	var s := size.x / SLOT.x  # how much smaller than a slot of three
	for k in across:
		var r := Rect2(origin + Vector2(k * (size.x + gap), 0), size)
		if k >= slots.size():
			K.dashed(self, K.closed(K.round_rect(r.grow(-20), 16)), Color(P.INK, 0.18), 2, 8, 6)
			continue
		var slot: Array = slots[k]
		var inv: Dictionary = progress.inventions.get(slot[1], {})
		if inv.is_empty():
			K.dashed(self, K.closed(K.round_rect(r.grow(-20), 16)), Color(P.INK, 0.4), 2, 8, 6)
			K.text(self, P.display(600), r.get_center() + Vector2(0, -10), "?", 48, Color(P.INK, 0.35))
			K.text(self, P.ui(700), r.get_center() + Vector2(0, 40), "Level %d" % (slot[0] + 1), 16, Color(P.INK, 0.45))
			continue
		K.sticker(self, r.position + Vector2(r.size.x / 2, 66), 1.5 * s, inv["name"], 99, t, k * 0.7)
		var y := r.position.y + 142
		K.icon(self, "pieces", Vector2(r.position.x + 40, y), 1.2, P.INK)
		K.text(self, P.ui(800), Vector2(r.position.x + 58, y), ("%d piece" if int(inv["cost"]) == 1 else "%d pieces") % int(inv["cost"]), 20, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var x := r.position.x + 40
		var counts: Dictionary = inv.get("counts", {})
		for kind in counts:
			critter(self, kind, Vector2(x + 18, y + 56), 0.6 * s, t)
			K.text(self, P.ui(800), Vector2(x + 40 * s, y + 60), "× %d" % int(counts[kind]), 17, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			x += 96 * s
		K.text(self, P.ui(700), Vector2(r.position.x + r.size.x / 2, r.end.y - 6), "%d inputs · from level %d" % [int(inv["inputs"]), _number_of(str(inv.get("from_level", "")), slot[0] + 1)], 14, P.INK_SOFT)


## Invention slots in campaign order, pots aside: [level index, invention id,
## name]. An invention two levels earn (Same Paint) has one slot, at the
## first; the slot tells which level made the one kept.
func _invention_slots() -> Array:
	var out := []
	var ids := {}
	for i in levels.size():
		var inv: Dictionary = levels[i].invention
		if not inv.is_empty() and Invention.paint_of(inv) < 0 and not ids.has(inv["id"]):
			ids[inv["id"]] = true
			out.append([i, inv["id"], inv["name"]])
	return out


## The paint shelf, one place per paint: [paint, level index (-1 for the red
## pot, which is always there), invention id].
func _pots() -> Array:
	var out := []
	for paint in 8:
		out.append([paint, -1, ""])
	for i in levels.size():
		var paint := Invention.paint_of(levels[i].invention)
		if paint >= 0 and out[paint][1] < 0:  # the first level that earns it
			out[paint] = [paint, i, levels[i].invention["id"]]
	return out


func _draw_shelf(page: Rect2) -> void:
	var y := page.position.y + 108
	var plank := Rect2(page.position.x + 30, y + 30, page.size.x - 60, 14)
	K.fill(self, K.round_rect(Rect2(plank.position + Vector2(2, 4), plank.size), 6), P.SHADOW)
	K.shape(self, K.round_rect(plank, 6), P.WOOD_LT, P.INK, 2)
	var step := (page.size.x - 80) / 8.0
	for spot in _pots():
		var paint: int = spot[0]
		var x := page.position.x + 40 + step * (paint + 0.5)
		var price := 1  # the red pot
		if spot[1] >= 0:
			var inv: Dictionary = progress.inventions.get(spot[2], {})
			if inv.is_empty():
				K.pot_outline(self, Vector2(x, y), 0.85, Color(P.INK, 0.3))
				K.text(self, P.ui(700), Vector2(x, y + 64), "Level %d" % levels[spot[1]].number, 14, Color(P.INK, 0.45))
				continue
			price = int(inv["cost"])
		K.pot(self, Vector2(x, y), 0.85, 99, t, paint * 0.37, paint)
		K.icon(self, "pieces", Vector2(x - 12, y + 64), 0.8, P.INK_SOFT)
		K.text(self, P.ui(800), Vector2(x + 2, y + 64), str(price), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


# --- Cloths and quilts ---------------------------------------------------------

func _draw_chapter_header() -> void:
	var list := _chapter_levels(chapter)
	if list.is_empty():
		return
	K.text(self, P.display(600), Vector2(PAGE.get_center().x, PAGE.position.y + 32), list[0].chapter_name, 26, P.INK)
	var n := _chapter_count()
	for ch in n:
		var at := Vector2(PAGE.get_center().x + (ch - (n - 1) / 2.0) * 28, PAGE.end.y - 40)
		K.shape(self, K.ellipse(at, 7, 7, 0, 16), P.INK if ch == chapter else P.TAG, P.INK, 2)


func _draw_cloths() -> void:
	_draw_chapter_header()
	var list := _chapter_levels(chapter)
	var gallery := Rect2(PAGE.position.x + 30, PAGE.position.y + 66, 790, 524)
	var cols: int = list[0].quilt_across if list[0].quilt_across > 0 else (4 if list.size() <= 8 else 5)
	var rows := ceili(float(list.size()) / cols)
	var gap := 16.0
	var w := (gallery.size.x - (cols - 1) * gap) / cols
	var h := minf(250.0, (gallery.size.y - (rows - 1) * gap) / rows)
	var patches := []
	var threads := true
	var ids := _ids()
	for k in list.size():
		var level = list[k]
		var r := Rect2(gallery.position + Vector2(k % cols * (w + gap), k / cols * (h + gap)), Vector2(w, h))
		var woven: bool = progress.is_solved(level.id)
		threads = threads and level.rows == 1 and level.cols == list[0].cols
		patches.append([level.cols, level.target] if woven else [])
		var pic := Rect2(r.position + Vector2(14, 14), r.size - Vector2(28, 64))
		if woven:
			K.shape(self, K.round_rect(r, 12), P.TAG, Color(P.INK, 0.5), 1.8)
			K.cloth(self, pic, level.cols, level.target)
		else:
			K.shape(self, K.round_rect(r, 12), Color(P.PAPER_DK, 0.7), Color(P.INK, 0.2), 1.5)
			# An empty frame the cloth's shape, so the gallery shows what's to come.
			var cs := minf(pic.size.x / level.cols, (pic.size.y - 10) / level.rows)
			var size := Vector2(level.cols, level.rows) * cs
			K.dashed(self, K.closed(K.round_rect(Rect2(pic.get_center() + Vector2(0, 5) - size / 2, size), 4)), Color(P.INK, 0.25), 1.5, 6, 5)
		var open: bool = progress.is_unlocked(ids, level.number - 1)
		var ink := P.INK if woven else Color(P.INK, 0.5 if open else 0.3)
		_fit_text(Vector2(r.get_center().x, r.end.y - 34), "%d" % level.number, w - 16, 15, ink, P.display(600))
		_fit_text(Vector2(r.get_center().x, r.end.y - 16), level.name, w - 16, 15, ink, P.ui(700))
	# The chapter's quilt
	var side := Rect2(PAGE.position.x + 846, PAGE.position.y + 66, PAGE.size.x - 876, 524)
	K.text(self, P.display(600), Vector2(side.get_center().x, side.position.y + 10), "Quilt", 24, P.INK)
	# Patches share the cloths' shape when every cloth in the chapter has it.
	var aspect: float = float(list[0].cols) / list[0].rows
	if not list.all(func(l): return is_equal_approx(float(l.cols) / l.rows, aspect)):
		aspect = 1.0
	K.quilt(self, Rect2(side.position + Vector2(0, 36), Vector2(side.size.x, side.size.y - 96)), patches, list[0].cols if threads else 0, list[0].quilt_across, aspect)
	var done := patches.filter(func(p): return not p.is_empty()).size()
	var line := "Every cloth sewn in!" if done == list.size() else "%d of %d cloths woven" % [done, list.size()]
	K.text(self, P.ui(700), Vector2(side.get_center().x, side.end.y - 30), line, 16, P.INK_SOFT)


## Centred text, smaller until it fits in width.
func _fit_text(c: Vector2, s: String, width: float, size: int, col: Color, font: Font) -> void:
	while size > 10 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	K.text(self, font, c, s, size, col)


# --- Scores ------------------------------------------------------------------

func _draw_scores() -> void:
	_draw_chapter_header()
	# Totals over the whole campaign
	var stars := 0
	var solved := 0
	for level in levels:
		stars += progress.stars(level.id)
		solved += int(progress.is_solved(level.id))
	var tx := PAGE.position.x + 60
	K.star(self, Vector2(tx, PAGE.position.y + 32), 13, true)
	K.text(self, P.ui(800), Vector2(tx + 22, PAGE.position.y + 32), "%d of %d" % [stars, levels.size() * 3], 18, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	K.text(self, P.ui(700), Vector2(PAGE.end.x - 60, PAGE.position.y + 32), "%d of %d cloths woven" % [solved, levels.size()], 17, P.INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	# The table
	var x0 := PAGE.position.x + 150
	var cols := [x0, x0 + 520, x0 + 700, x0 + 840]
	var y := PAGE.position.y + 84
	K.text(self, P.ui(800), Vector2(cols[0], y), "Level", 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	K.text(self, P.ui(800), Vector2(cols[1] + 40, y), "Stars", 16, P.INK_SOFT)
	K.icon(self, "pieces", Vector2(cols[2] - 30, y), 1.0, P.INK_SOFT)
	K.text(self, P.ui(800), Vector2(cols[2] - 14, y), "Pieces", 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	K.icon(self, "ticks", Vector2(cols[3] - 22, y), 1.0, P.INK_SOFT)
	K.text(self, P.ui(800), Vector2(cols[3] - 6, y), "Ticks", 16, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	y += 22
	K.line(self, Vector2(x0 - 40, y), Vector2(cols[3] + 110, y), Color(P.INK, 0.2), 2)
	var ids := _ids()
	for level in _chapter_levels(chapter):
		y += 44
		var rec: Dictionary = progress.level_record(level.id)
		var done: bool = rec.get("solved", false)
		var open: bool = progress.is_unlocked(ids, level.number - 1)
		var ink := P.INK if done else Color(P.INK, 0.5 if open else 0.3)
		K.text(self, P.display(600), Vector2(cols[0] - 14, y - 22), str(level.number), 18, ink, HORIZONTAL_ALIGNMENT_RIGHT)
		K.text(self, P.display(600), Vector2(cols[0], y - 22), level.name, 20, ink, HORIZONTAL_ALIGNMENT_LEFT)
		for s in 3:
			K.star(self, Vector2(cols[1] + 12 + s * 28, y - 22), 11, s < int(rec.get("stars", 0)))
		K.text(self, P.ui(800), Vector2(cols[2] + 30, y - 22), str(rec["best_pieces"]) if done else "–", 18, ink)
		K.text(self, P.ui(800), Vector2(cols[3] + 20, y - 22), str(rec["best_ticks"]) if done else "–", 18, ink)
		K.line(self, Vector2(x0 - 40, y), Vector2(cols[3] + 110, y), Color(P.INK, 0.08), 1.5)


# --- Words -------------------------------------------------------------------

func _draw_words() -> void:
	for i in words.size():
		var r := _word_rect(i)
		var w: Dictionary = words[i]
		var lit := i == word
		if Words.is_unlocked(w, progress):
			K.shape(self, K.round_rect(r, 12), Color(P.HOOP, 0.25) if lit else P.TAG, Color(P.INK, 0.8 if lit else 0.4), 2.5 if lit else 1.5)
			picture(self, str(w["id"]), r.position + Vector2(40, r.size.y / 2 + 4), minf(0.62, r.size.y / 130), t, levels)
			_fit_text(Vector2(r.position.x + 120, r.get_center().y), w["word"], 96, 17, P.INK, P.display(600))
		else:
			K.fill(self, K.round_rect(r, 12), Color(P.PAPER_DK, 0.6))
			K.dashed(self, K.closed(K.round_rect(r, 12)), Color(P.INK, 0.5 if lit else 0.25), 2 if lit else 1.5, 6, 5)
			K.text(self, P.display(600), Vector2(r.position.x + 36, r.get_center().y), "?", 26, Color(P.INK, 0.3))
			var level = _level_by_id(str(w["level"]))
			K.text(self, P.ui(700), Vector2(r.position.x + 110, r.get_center().y), "Level %d" % level.number, 14, Color(P.INK, 0.4))
	var panel := _word_panel()
	K.shape(self, K.round_rect(panel, 14), Color(P.PAPER, 0.5), Color(P.INK, 0.3), 1.5)
	if word >= words.size():
		return
	var w: Dictionary = words[word]
	if not Words.is_unlocked(w, progress):
		var level = _level_by_id(str(w["level"]))
		K.text(self, P.display(600), panel.get_center() + Vector2(0, -40), "?", 64, Color(P.INK, 0.25))
		K.text(self, P.ui(700), panel.get_center() + Vector2(0, 30), "Weave %s" % level.ref_name(), 18, P.INK_SOFT)
		K.text(self, P.ui(700), panel.get_center() + Vector2(0, 56), "to find this word.", 18, P.INK_SOFT)
		return
	picture(self, str(w["id"]), Vector2(panel.get_center().x, panel.position.y + 86), 1.4, t, levels)
	K.text(self, P.display(600), Vector2(panel.get_center().x, panel.position.y + 182), w["word"], 32, P.INK)
	_para(panel.position + Vector2(26, 214), panel.size.x - 52, w["text"], 18)
	if _has_page(word):
		var b := _open_rect()
		var down := _pressed == "open"
		if not down:
			K.fill(self, K.round_rect(Rect2(b.position + Vector2(0, 3), b.size), 14), P.SHADOW)
		K.shape(self, K.round_rect(Rect2(b.position + Vector2(0, 2 if down else 0), b.size), 14), P.TAG, P.INK, 2.5)
		var label := "Its page: %s" % _tab_name(w["tab"])
		K.text(self, P.display(600), b.get_center() + Vector2(-12, 2 if down else 0), label, 18, P.INK)
		K.icon(self, "next", Vector2(b.end.x - 24, b.get_center().y + (2 if down else 0)), 0.8, P.INK)
		Keys.cap(self, Vector2(b.get_center().x, b.end.y), Keys.label("open_page"))


func _tab_name(id: String) -> String:
	for tb in TABS:
		if tb[0] == id:
			return tb[1]
	return id


## A word's small picture, centred on c (about 90 across at s = 1).
static func picture(ci: CanvasItem, id: String, c: Vector2, s: float, t: float, levels: Array) -> void:
	match id:
		"pattern-card":
			# a small picture card, three drops read
			var drops := PackedByteArray([Paint.RED, Paint.RED, Paint.ORANGE, Paint.WHITE, Paint.BLUE, Paint.BLUE, Paint.GREEN, Paint.WHITE, Paint.YELLOW, Paint.RED, Paint.RED, Paint.BLUE])
			K.set_xf(ci, c, Vector2(0.6, 0.6) * s, -0.06)
			K.card_body(ci, Vector2.ZERO, "A", 4, 3, drops)
			K.card_paints(ci, Vector2.ZERO, 4, 3, 3)
			K.reset_xf(ci)
		"paint":
			for k in 3:
				var a := -PI / 2 + k * TAU / 3
				K.drop(ci, c + Vector2(cos(a), sin(a)) * 20 * s + Vector2(0, 4) * s, 13 * s, [Paint.RED, Paint.YELLOW, Paint.BLUE][k])
		"paint-card":
			var at := PaintCard.spots()
			var mid: Vector2 = at[7]
			for color in at:
				if color != 0:
					K.drop(ci, c + (at[color] - mid) * 0.3 * s + Vector2(0, 6) * s, 7.5 * s, color)
		"critter":
			K.piece(ci, "mix", c, 0.6 * s, -1, 99, t, 0.4)  # a critter: the jolly Mixing Tub
		"mix", "invert", "filter", "shift", "red-pot", "split":
			critter(ci, id.replace("-", "_"), c, s, t)
		"piece":
			K.icon(ci, "pieces", c, 2.6 * s, P.INK)
		"tray":
			var r := Rect2(c - Vector2(40, 18) * s, Vector2(80, 36) * s)
			K.shape(ci, K.round_rect(r, 6 * s), P.PAPER_DK, P.INK, 2)
			for k in 3:
				K.shape(ci, K.round_rect(Rect2(r.position + Vector2(5 + k * 25, 5) * s, Vector2(20, 26) * s), 4 * s), P.TAG, Color(P.INK, 0.5), 1.2)
		"workbench":
			var r := Rect2(c - Vector2(40, 26) * s, Vector2(80, 52) * s)
			K.shape(ci, K.round_rect(r, 8 * s), Color(P.TAG, 0.6), Color(P.INK, 0.5), 2)
			for gx in 5:
				for gy in 4:
					K.disc(ci, r.position + Vector2(8 + gx * 16, 8 + gy * 12) * s, 1.8 * s, Color(P.INK, 0.35))
		"tube":
			var pts := K.tube_path(c + Vector2(-40, 12) * s, c + Vector2(40, -12) * s)
			K.tube(ci, pts)
			K.drop(ci, K.along(pts, 0.5), 9 * s, Paint.GREEN)
		"tick":
			K.icon(ci, "ticks", c, 2.6 * s, P.INK)
		"loom":
			# A little loom: two posts, two rails, a cloth half woven.
			var cloth := Rect2(c - Vector2(24, 12) * s, Vector2(48, 24) * s)
			for px in [cloth.position.x - 9 * s, cloth.end.x + 2 * s]:
				K.shape(ci, K.round_rect(Rect2(px, cloth.position.y - 9 * s, 7 * s, cloth.size.y + 18 * s), 3 * s), P.WOOD, P.INK, 1.8)
			for py in [cloth.end.y + 4 * s]:  # the cloth hangs from its own rod
				K.shape(ci, K.round_rect(Rect2(cloth.position.x - 13 * s, py, cloth.size.x + 26 * s, 6 * s), 3 * s), P.WOOD_DK, P.INK, 1.8)
			K.cloth(ci, Rect2(cloth.position - Vector2(0, 10), cloth.size + Vector2(0, 10)), 8, PackedByteArray([1, 3, 2, 6, 4, 5, 7, 0, 0, 1, 1, 3, 2, 2, 6, 4]))
		"stitch":
			var r := Rect2(c - Vector2(16, 16) * s, Vector2(32, 32) * s)
			K.shape(ci, K.round_rect(r, 8 * s), P.SIG[Paint.ORANGE], P.STITCH_EDGE_DARK, 1.5)
		"thread":
			var cs := 10.0 * s
			var row := PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7])
			K.cloth(ci, Rect2(c - Vector2(4 * cs, cs * 0.5 + 10), Vector2(8 * cs, cs + 10)), 8, row)
		"cloth":
			var found := levels.filter(func(l): return l.id == "pattern_card")
			var level = found[0] if not found.is_empty() else null
			if level != null:
				K.cloth(ci, Rect2(c - Vector2(36, 32) * s, Vector2(72, 64) * s), level.cols, level.target)
		"quilt":
			var patches := []
			for level in levels.filter(func(l): return l.chapter == 0):
				patches.append([level.cols, level.target])
			K.quilt(ci, Rect2(c - Vector2(34, 34) * s, Vector2(68, 68) * s), patches, 8)
		"stars":
			for k in 3:
				K.star(ci, c + Vector2((k - 1) * 26, -6 if k == 1 else 2) * s, 12 * s, true)
		"invention":
			K.sticker(ci, c, 0.62 * s, "Extreme Mix", 99, t, 0.4)
		_:
			K.icon(ci, "book", c, 2.4 * s, P.INK)
