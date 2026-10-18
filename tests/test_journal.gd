## The journal: its Words data matches the lexicon, words unlock with their
## levels, piece pages fill from what the player's machines do (and survive a
## save), tabs and pages turn by tap and key, peek opens a piece's page from
## the workbench, a first solve brings "New in your journal", and a full
## quilt opens its chapter's historical note.
## Run: godot_console --headless --path . --script res://tests/test_journal.gd
extends SceneTree

const Level = preload("res://core/level.gd")
const Progress = preload("res://core/progress.gd")
const Pieces = preload("res://core/pieces.gd")
const Simulator = preload("res://core/simulator.gd")
const Invention = preload("res://core/invention.gd")
const Words = preload("res://core/words.gd")
const Paint = preload("res://core/paint.gd")
const Lexicon = preload("res://tools/lexicon.gd")
const Journal = preload("res://ui/journal.gd")
const K = preload("res://ui/draw_kit.gd")
const JournalNews = preload("res://ui/journal_news.gd")
const Workbench = preload("res://ui/workbench.gd")
const Options = preload("res://ui/options.gd")
const Keys = preload("res://ui/keys.gd")
const SETTINGS := "user://chromaton_settings_test_journal.json"

var failures := 0
var checks := 0
var levels: Array = []
var by_id := {}


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func _initialize() -> void:
	Keys.settings_path = SETTINGS  # a workbench saves the speed on _ready
	Keys.reset()
	levels = Level.load_all()
	for level in levels:
		by_id[level.id] = level
	test_words_match_lexicon()
	test_words_unlock()
	test_learning()
	test_save()
	test_journal_tabs()
	test_word_pages()
	test_invention_pages()
	test_peek()
	test_articles()
	test_news()
	test_news_entries()
	test_history_notes()
	test_options_fit()
	if failures == 0:
		print("test_journal: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


func _finalize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


# --- helpers ----------------------------------------------------------------

func press(node, p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	node._gui_input(e)


func tap(node, p: Vector2) -> void:
	press(node, p, true)
	press(node, p, false)


func key(node, code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	node._unhandled_input(e)


## Solves the first n levels with their reference machines.
func solved(n: int):
	var p = Progress.new()
	for k in n:
		p.record_solve(levels[k].id, levels[k].best, 10, 3)
	return p


func journal(progress, tab := "", focus := ""):
	var j = Journal.new()
	j.setup(levels, progress, tab, focus)
	j._ready()  # not in the tree: no deferred _ready, so build it now
	return j


# --- tests ------------------------------------------------------------------

## data/words.json is exactly what the lexicon makes (rerun .\make words), and
## what the player reads says paint, never bits or colors.
func test_words_match_lexicon() -> void:
	var built := Lexicon.build(levels)
	check(built["errors"].is_empty(), "every gameplay term reads: %s" % str(built["errors"]))
	var f := FileAccess.open(Lexicon.OUT, FileAccess.READ)
	var text := f.get_as_text() if f != null else ""
	check(text == Lexicon.to_json(built["words"]), "data/words.json matches docs/lexicon/ (run .\\make words)")
	var words := Words.load_all()
	check(words.size() == built["words"].size() and words.size() >= 20, "the game reads every word (%d)" % words.size())
	var banned := RegEx.new()
	banned.compile("(?i)\\b(bits?|binary|bytes?|colou?rs?)\\b")
	for w in words:
		check(by_id.has(w["level"]), "%s unlocks in a real level" % w["id"])
		check(w["tab"] in Lexicon.TABS or w["tab"] == "", "%s points at a real tab" % w["id"])
		var said: String = w["text"] + " " + w["word"]
		for c in w.get("cases", []):
			said += " " + str(c["why"])
		check(banned.search(said) == null, "%s speaks of paint, not bits or colors (its case rows too)" % w["id"])
		check(not "](" in w["text"] and not "**" in w["text"], "%s has no markdown left" % w["id"])
	var shift := Words.find("shift")
	check(shift.get("level") == "yellow" and shift.get("tab") == "pieces", "Shift unlocks in Yellow, its page on Pieces")
	check(Words.find("paint-card").get("level") == "one_pot", "the paint card's word unlocks in One Pot of Red")
	check(Words.find("quilt").get("tab") == "cloths", "the quilt's page is on Cloths")
	check(Words.find("implementation").is_empty(), "only gameplay terms are words")


func test_words_unlock() -> void:
	var p = Progress.new()
	var shift := Words.find("shift")
	check(not Words.is_unlocked(shift, p), "a word starts locked")
	p.record_solve("yellow", 2, 10, 3)
	check(Words.is_unlocked(shift, p), "and unlocks once its level is solved")
	var names: Array = Words.unlocked_by("yellow").map(func(w): return w["id"])
	check("shift" in names and "critter" in names and "invention" in names, "Yellow brings Shift, critter and invention: %s" % str(names))


## The simulator reports each piece at work; Progress keeps each first.
func test_learning() -> void:
	var level = by_id["opposites"]
	var p = Progress.new()
	var sim = Simulator.new(level.reference_machine(), level.cards, level.target, {})
	var firsts := 0
	while sim.status == Simulator.Status.RUNNING:
		sim.step()
		for f in sim.fired:
			firsts += int(p.learn(f[0], f[1]))
	check(firsts == 8 and p.seen.get("invert", {}).size() == 8, "Opposites fills Invert's page at once")
	for c in 8:
		check(p.knows("invert", [c]), "Invert on paint %d is known" % c)
	check(not p.knows("shift", [1]), "Shift's page is still empty")
	check(Progress.seen_key([1, 4]) == Progress.seen_key([4, 1]), "Mix and Filter don't care about order")
	check(p.learn("mix", [1, 4]) and not p.learn("mix", [4, 1]) and p.knows("mix", [4, 1]), "a pair, once seen, is known both ways")
	check(not p.learn("copy", [1]) and not p.learn("red", []), "Split and the pot have no frames to fill")


## The frames survive a save; a save from before them is stale.
func test_save() -> void:
	var p = Progress.new()
	p.learn("shift", [3])
	p.learn("filter", [5, 2])
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	check(Progress.problems(d, levels).is_empty(), "a fresh save fits")
	var back = Progress.from_dict(d, levels)
	check(back.knows("shift", [3]) and back.knows("filter", [2, 5]) and not back.knows("shift", [1]), "what the player saw survives a save")
	var old := d.duplicate()
	old["version"] = 1
	old.erase("seen")
	check(not Progress.problems(old, levels).is_empty(), "a save from before the journal is stale")
	check(Progress.VERSION == 4, "the save version moved on")


func test_journal_tabs() -> void:
	var j = journal(solved(12), "paint")
	check(j.tab == "paint" and j.paint_card.visible, "the Paint tab holds the paint card")
	key(j, KEY_3)
	check(j.tab == "pieces" and not j.paint_card.visible, "3 opens Pieces")
	key(j, KEY_TAB)
	check(j.tab == "cloths", "Tab goes to the next tab (Pieces holds the inventions too)")
	check(j.TABS.size() == 6 and not j.TABS.any(func(tb): return tb[0] == "inventions"), "six tabs, no Inventions tab")
	j.show_tab("paint")
	tap(j, j._tab_rect(3).get_center())
	check(j.tab == "cloths", "a tap on a tab opens it")
	var chapter: int = j.chapter
	check(chapter == by_id[levels[12].id].chapter, "Cloths opens on the first chapter not finished")
	key(j, KEY_RIGHT)
	check(j.chapter == chapter + 1 and j.prev_button.visible, "→ turns the page")
	j.prev_button.pressed.emit()
	check(j.chapter == chapter, "and the arrow turns it back")
	key(j, KEY_2)
	key(j, KEY_6)
	key(j, KEY_RIGHT)
	check(j.tab == "words" and j.word == 1, "→ on Words picks the next word")
	var closed := []
	j.back.connect(func(): closed.append(true))
	key(j, KEY_B)
	key(j, KEY_ESCAPE)
	check(closed.size() == 2, "B and Back close the journal")
	j.free()
	# Pieces: met once a level that offers them is open.
	j = journal(Progress.new())
	check(j.is_met("red_pot") and not j.is_met("shift"), "at the start only the red pot is met")
	j.free()
	j = journal(solved(1))
	check(j.is_met("shift") and not j.is_met("filter"), "solving level 1 opens Yellow, and Shift is met")
	j.here = by_id["smudges"]
	check(j.is_met("filter"), "the level the journal is opened from counts as met")
	j.free()


func test_word_pages() -> void:
	var p = solved(2)
	var j = journal(p, "words")
	var i: int = j.words.find(Words.find("shift"))
	tap(j, j._word_rect(i).get_center())
	check(j.word == i, "a tap picks a word")
	check(j._target_at(j._open_rect().get_center()) == "open", "an unlocked word with a page offers it")
	key(j, KEY_ENTER)
	check(j.tab == "pieces" and j.pieces[j.piece] == "shift", "Enter opens Shift's page")
	j.show_tab("words")
	j.word = j.words.find(Words.find("filter"))
	check(j._target_at(j._open_rect().get_center()) == "", "a locked word has no page to open")
	j.open_word_page()
	check(j.tab == "words", "and opening it does nothing")
	j.free()


## Pieces and inventions share one tab: the known ones by name, then the
## rest; the list scrolls; an invention's page opens once it's made; and
## every case row is what the piece or invention really makes.
func test_invention_pages() -> void:
	var rules := {"mix": "mix", "filter": "filter", "contrast": "contrast", "third-paint": "third_paint", "missing-from-either": "missing_from_either", "same-paint": "same_paint"}
	for id in rules:
		var cases: Array = Words.find(id).get("cases", [])
		var fewest := 3 if id in ["mix", "filter"] else 4
		check(cases.size() >= fewest and cases.size() <= 6, "%s has %d to 6 case rows (%d)" % [id, fewest, cases.size()])
		for c in cases:
			var ins := [Paint.NAMES.find(c["in"][0]), Paint.NAMES.find(c["in"][1])]
			check(Invention.expected(rules[id], ins) == Paint.NAMES.find(c["out"]), "%s: %s + %s makes %s" % [id, c["in"][0], c["in"][1], c["out"]])
	var p = Progress.new()
	for l in levels.slice(0, by_id["either_not_both"].number):  # through The Queen
		p.record_solve(l.id, l.best, 10, 3)
		if not l.invention.is_empty():
			p.add_invention(Invention.package(l, l.reference_machine(), p.inventions))
	var j = journal(p, "pieces")
	var known: Array = j.pieces.filter(func(e): return j.knows(e))
	var names: Array = known.map(func(e): return j.entry_name(e))
	var sorted := names.duplicate()
	sorted.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	check(names == sorted and j.pieces.slice(0, known.size()) == known, "the known entries come first, by name: %s" % str(names))
	check("inv:third_paint" in known and "inv:contrast" in known and "mix" in known, "pieces and the inventions made share the list")
	check(j.pieces.has("inv:same_paint") and not j.knows("inv:same_paint"), "an invention not made yet waits, locked, after them")
	check(j.pieces.has("red_pot") and not j.pieces.any(func(e): return e.begins_with("inv:pot_")), "the pots are on the red pot's page, not entries")
	check(j._article_max() > 0 and j._more_rect().size.x > 0, "the list runs past its page, with a \"more below\" chip")
	key(j, KEY_DOWN)
	check(j.article_scroll > 0.0, "the down key scrolls the list")
	j.article_scroll = 0.0
	j.piece = 0
	for k in j.pieces.size():
		key(j, KEY_RIGHT)
	check(j.piece == j.pieces.size() - 1 and is_equal_approx(j.article_scroll, j._article_max()), "→ steps down the list, which follows")
	var last: int = j.pieces.size() - 2
	tap(j, j._article_rect().position + j._piece_rect(last).get_center() - Vector2(0, j.article_scroll))
	check(j.piece == last, "a tap on a scrolled entry opens it")
	j.free()
	j = journal(p, "", "inv:contrast")
	check(j.tab == "pieces" and j.pieces[j.piece] == "inv:contrast", "a peek on Extreme Mix opens its page")
	j.free()
	j = journal(p, "", "inv:pot_orange")
	check(j.tab == "pieces" and j.pieces[j.piece] == "red_pot", "a peek on a pot opens the red pot's page, with the paint shelf")
	j.free()
	j = journal(p, "words")
	j.word = j.words.find(Words.find("contrast"))
	j.open_word_page()
	check(j.tab == "pieces" and j.pieces[j.piece] == "inv:contrast", "Extreme Mix's word opens its page")
	j.free()


func open_bench(level, progress):
	var wb = Workbench.new()
	wb.setup(level, progress, true, levels)
	root.add_child(wb)
	return wb


func slot_of(wb, kind: String) -> int:
	for i in wb.tray.size():
		if wb.tray[i]["kind"] == kind:
			return i
	return -1


## Peek: select, then tap the journal by the trash.
func test_peek() -> void:
	var level = by_id["green"]
	var wb = open_bench(level, Progress.new())
	var peek: Vector2 = Workbench.PEEK.get_center()
	tap(wb, peek)
	check(wb.journal != null and wb.journal.tab == "pieces", "with nothing selected the journal opens at Pieces")
	wb.journal.back.emit()
	check(wb.journal == null, "Back closes it over the bench")
	# A piece picked up from the tray
	tap(wb, wb.tray[slot_of(wb, "invert")]["rect"].get_center())
	check(wb.carrying == slot_of(wb, "invert"), "a tap picks up Invert")
	tap(wb, peek)
	check(wb.journal != null and wb.journal.pieces[wb.journal.piece] == "invert" and wb.carrying == -1, "peek opens Invert's page and the hand empties")
	wb.journal.back.emit()
	# A placed piece, selected by a tap
	tap(wb, wb.tray[slot_of(wb, "shift")]["rect"].get_center())
	tap(wb, wb.cell_center(5, 3))
	var id: int = wb.piece_in_cell(5, 3)
	check(id >= 0, "Shift is placed")
	tap(wb, wb.cell_center(5, 3))
	check(wb.selected_piece == id, "a tap selects it")
	tap(wb, peek)
	check(wb.journal != null and wb.journal.pieces[wb.journal.piece] == "shift" and wb.selected_piece == id, "peek opens Shift's page and keeps the selection")
	var keys_ignored: bool = wb.journal != null
	key(wb, KEY_DELETE)
	check(keys_ignored and wb.machine.nodes.has(id), "the bench takes no keys while the journal is open")
	wb.journal.back.emit()
	# Dropping a piece on the journal leaves it where it was.
	press(wb, wb.cell_center(5, 3), true)
	var m := InputEventMouseMotion.new()
	m.position = peek
	wb._gui_input(m)
	press(wb, peek, false)
	check(wb.machine.nodes.has(id) and wb.journal == null, "the journal is no bin: a piece dropped on it stays")
	key(wb, KEY_J)
	check(wb.journal != null and wb.journal.tab == "pieces", "J does what a tap does")
	wb.journal.back.emit()
	wb.queue_free()


## A first solve: the success panel, then "New in your journal", then on.
func test_news() -> void:
	var level = by_id["yellow"]
	var p = Progress.new()
	var wb = open_bench(level, p)
	var went := []
	wb.next_requested.connect(func(): went.append(true))
	wb.load_machine(level.reference_machine())
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	check(wb.panel != null, "the solve shows the success panel")
	var ids: Array = wb.new_words.map(func(w): return w["id"])
	check("shift" in ids and "critter" in ids, "the first solve brings Yellow's words")
	check(wb.fresh.size() >= 1 and wb.fresh[0][0] == "shift" and p.knows("shift", [1]), "Shift turning red is a new frame")
	wb.panel.next.emit()
	check(wb.panel == null and wb.news != null and went.is_empty(), "Next shows the news first")
	var presses := 0
	while wb.news != null and presses < 5:
		var below: int = wb.news.rows_below()
		key(wb.news, KEY_ENTER)
		presses += 1
		if wb.news != null:
			check(below > 0, "Enter scrolls only while there's more below")
	check(wb.news == null and went.size() == 1, "Enter goes on to the next level at the bottom")
	# Solving it again brings nothing new: straight on.
	wb._rebuild()
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	check(wb.new_words.is_empty() and wb.fresh.is_empty(), "a second solve brings nothing new")
	wb.panel.next.emit()
	check(wb.news == null and went.size() == 2, "so Next goes straight on")
	wb.queue_free()


## Historical notes (DESIGN.md 5.7): every chapter has one, short and in
## paint; it opens once the chapter's quilt is full, from its tag on Cloths
## (a tap or Enter; a tap, Back or Enter puts it away), and the solve that
## fills the quilt announces it in "New in your journal".
func test_history_notes() -> void:
	var banned := RegEx.new()
	banned.compile("(?i)\\b(bits?|binary|bytes?|colou?rs?)\\b")
	var stop := RegEx.new()
	stop.compile("[.!?](\\s|$)")
	var chapters := Level.chapters()
	for c in chapters.size():
		var note: Dictionary = chapters[c].get("note", {})
		var name: String = chapters[c]["name"]
		check(str(note.get("title", "")) != "" and str(note.get("text", "")) != "", "%s has a historical note" % name)
		if note.is_empty():
			continue
		check(Journal.year_text({"year": -150}) == "150 BC" and Journal.year_text({"year": 1725}) == "1725", "a year before the common era reads BC")
		check(int(note.get("year", 0)) != 0 and int(note.get("year", 0)) >= -3000 and int(note.get("year", 0)) <= 2000, "%s's note has a year (%s)" % [name, note.get("year")])
		check(str(note.get("picture", "")) in K.HISTORY_PICTURES, "%s's note names a picture the draw kit draws" % name)
		var text := str(note["text"])
		var sentences := stop.search_all(text).size()
		check(sentences >= 3 and sentences <= 4, "%s's note is 3 or 4 sentences (%d)" % [name, sentences])
		check(banned.search(text + " " + str(note["title"])) == null, "%s's note speaks of paint and thread, not bits or colors" % name)
		check(levels.filter(func(l): return l.chapter == c).all(func(l): return l.chapter_note == note), "%s's levels carry its note" % name)
	# Opens with a full quilt, not before.
	check(not Journal.note_open(levels, solved(7), 0), "the paint box's note waits for its last cloth")
	var p = solved(8)
	check(Journal.note_open(levels, p, 0) and not Journal.note_open(levels, p, 1), "a full quilt opens its own note only")
	var j = journal(solved(7), "cloths")
	j.chapter = 0
	var tag: Vector2 = j._note_tag_rect().get_center()
	tap(j, tag)
	check(not j.reading, "a dashed tag doesn't open")
	j.free()
	j = journal(p, "cloths")
	j.chapter = 0
	var closed := []
	j.back.connect(func(): closed.append(true))
	tap(j, tag)
	check(j.reading and not j.prev_button.visible and not j.next_button.visible, "a tap on the tag opens the note over the page")
	key(j, KEY_ESCAPE)
	check(not j.reading and closed.is_empty(), "Back puts the note away first, the journal stays")
	key(j, KEY_ENTER)
	check(j.reading, "Enter opens it too")
	tap(j, Vector2(640, 420))
	check(not j.reading, "any tap puts it away")
	key(j, KEY_ENTER)
	j.show_tab("scores")
	check(not j.reading, "another tab puts it away")
	j.free()
	j = journal(p, "", "note:0")
	check(j.tab == "cloths" and j.chapter == 0 and j.reading, "\"note:0\" opens the journal at the paint box's note")
	j.free()
	# The solve that fills the quilt says so, once.
	var q = solved(7)
	q.know_levels(levels)
	for l in levels.slice(0, 7):  # the pots its machine is built of
		if not l.invention.is_empty():
			q.add_invention(Invention.package(l, l.reference_machine(), q.inventions))
	var wb = open_bench(by_id["white"], q)
	wb.levels = levels
	wb.load_machine(by_id["white"].reference_machine())
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	var n: Dictionary = wb.news_extra.get("note", {})
	check(n.get("chapter", -1) == 0 and n.get("note", {}).get("title", "") == "The Paper Strip", "the last cloth of the paint box brings its note")
	var news = JournalNews.new()
	news.setup([], [], func(ci, id, c, s): pass, wb.news_extra)
	check(news.rows[0]["kind"] == "note" and news.rows[0]["title"] == "A note from history: The Paper Strip", "in those words (%s)" % news.rows[0]["title"])
	check(news.first_entry() == ["cloths", "note:0"], "the book opens it")
	news.free()
	wb.panel.next.emit()
	if wb.news != null:
		wb.news.done.emit()
	wb._rebuild()
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	check(not wb.news_extra.has("note"), "weaving it again brings no note")
	wb.queue_free()


## Options' key slots all fit the screen and none overlap, Journal's included.
func test_options_fit() -> void:
	var o = Options.new()
	o._ready()
	var tabs := 0
	for s in o.slots:
		tabs += int(str(s["action"]).begins_with("tab_"))
		check(Rect2(Vector2.ZERO, Options.DESIGN).encloses(s["rect"]), "%s's slot fits on screen" % s["action"])
	check(tabs == 6, "Options lists the journal's tabs")
	for a in o.slots.size():
		for b in range(a + 1, o.slots.size()):
			if o.slots[a]["rect"].intersects(o.slots[b]["rect"]):
				check(false, "slots %s and %s overlap" % [o.slots[a]["action"], o.slots[b]["action"]])
	o.free()


## An article fits each word's text and scrolls when it runs past its page:
## the scroll keys, the "more below" chip, and a peek on a tube or a card
## opening Loom at that word.
func test_articles() -> void:
	var p = Progress.new()
	p.unlock_all = true
	var j = Journal.new()
	j.setup(levels, p, "loom")
	j._ready()
	check(j._article_max() > 0 and j._rows_below() > 0 and j._more_rect().size.x > 0, "Loom runs past its page, with a \"more below\" chip")
	var rows: Array = j._article_rows()
	var heights := {}
	for r in rows:
		heights[r["w"]["id"]] = r["h"]
	check(rows.all(func(r): return r["h"] >= 80) and heights["tick"] > heights["thread"], "rows are as tall as their text (Tick is longer than Thread)")
	check(heights.has("shuttle"), "the shuttle has its article on the Loom page")
	key(j, KEY_DOWN)
	check(is_equal_approx(j.article_scroll, minf(j.ARTICLE_STEP, j._article_max())), "the down key scrolls down")
	key(j, KEY_W)
	check(j.article_scroll == 0.0, "W scrolls back up")
	j._gui_input(_click(j._more_rect().get_center(), true))
	j._gui_input(_click(j._more_rect().get_center(), false))
	check(j.article_scroll > 0.0, "the chip scrolls on")
	j.scroll_article(9999)
	check(is_equal_approx(j.article_scroll, j._article_max()) and j._rows_below() == 0 and j._more_rect().size.x == 0, "at the bottom the chip goes")
	j.free()
	for focus in ["tube", "card"]:
		var k = Journal.new()
		k.setup(levels, p, "", focus)
		k._ready()
		var want := "tube" if focus == "tube" else "pattern-card"
		var row: Dictionary = k._article_rows().filter(func(r): return r["w"]["id"] == want)[0]
		check(k.tab == "loom" and is_equal_approx(k.article_scroll, minf(row["y"], k._article_max())), "a peek on a %s opens Loom at its word" % focus)
		k.free()


func _click(pos: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	return e


func _key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


## What else "New in your journal" says, most important first: a new
## chapter, the levels an invention opens, an invention made cheaper.
func test_news_entries() -> void:
	var p = Progress.new()
	p.know_levels(levels)
	for l in levels.slice(0, 22):  # up to The Rock Pool
		p.record_solve(l.id, l.best, 10, 3)
		if not l.invention.is_empty():
			p.add_invention(Invention.package(l, l.reference_machine(), p.inventions))
	# Solving The Fish opens The Pawn, chapter 3's first level.
	var wb = open_bench(by_id["wash_out"], p)
	wb.levels = levels
	wb.load_machine(by_id["wash_out"].reference_machine())
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	check(wb.news_extra.has("chapter") and wb.news_extra["chapter"]["name"] == "Invent What You Know", "a solve that opens a chapter says so")
	wb.queue_free()
	# The Pawn earns the Third Paint, which opens The Chess Clock and The Rook.
	p.record_solve("black_cat", 4, 10, 3)
	wb = open_bench(by_id["third_color"], p)
	wb.levels = levels
	wb.load_machine(by_id["third_color"].reference_machine())
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	var opens: Array = wb.news_extra.get("opens", {}).get("levels", []).map(func(l): return l.id)
	check(opens == ["two_pawns", "neither_twice"], "the Third Paint opens The Chess Clock and The Rook (%s)" % str(opens))
	var news = JournalNews.new()
	news.setup([], [], func(ci, id, c, s): pass, wb.news_extra)
	check(news.rows[0]["title"] == "The Third Paint opens {level:two_pawns} and {level:neither_twice}.", "in those words (%s)" % news.rows[0]["title"])
	check(Level.plain(news.rows[0]["title"]) == "The Third Paint opens %s and %s." % [by_id["two_pawns"].ref_name(), by_id["neither_twice"].ref_name()], "the markers read as level references (%s)" % Level.plain(news.rows[0]["title"]))
	news.free()
	wb.queue_free()
	# A cheaper pot: both prices, only when the price drops.
	var q = Progress.new()
	var refs := Invention.reference_inventions_by_level(levels)
	q.add_invention(Invention.package(by_id["yellow"], by_id["yellow"].reference_machine(), {}))
	q.add_invention(Invention.package(by_id["orange"], by_id["orange"].reference_machine(), refs[by_id["orange"].number - 1]))
	q.add_invention(Invention.package(by_id["blue"], by_id["blue"].reference_machine(), refs[by_id["blue"].number - 1]))
	wb = open_bench(by_id["orange_opposite"], q)
	wb.levels = levels
	wb.load_machine(by_id["orange_opposite"].reference_machine())
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	var cheaper: Array = wb.news_extra.get("cheaper", [])
	check(cheaper.size() == 1 and cheaper[0]["old"] == 2 and cheaper[0]["new"] == 1, "Orange pot: cheaper, 2 → 1")
	news = JournalNews.new()
	news.setup([], [[ "invert", [4]]], func(ci, id, c, s): pass, {"chapter": {"name": "X", "level": levels[24]}, "cheaper": cheaper})
	check(news.rows.map(func(r): return r["kind"]) == ["level", "invention", "frames"] and news.rows[1]["title"] == "Orange pot: cheaper, 2 → 1", "rows in order of importance, one kind")
	check(news.first_entry() == ["cloths", ""], "the book opens at the first entry")
	news.free()
	wb.queue_free()
