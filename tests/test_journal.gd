## The journal: its Words data matches the lexicon, words unlock with their
## levels, piece pages fill from what the player's machines do (and survive a
## save), tabs and pages turn by tap and key, peek opens a piece's page from
## the workbench, and a first solve brings "New in your journal".
## Run: godot_console --headless --path . --script res://tests/test_journal.gd
extends SceneTree

const Level = preload("res://core/level.gd")
const Progress = preload("res://core/progress.gd")
const Pieces = preload("res://core/pieces.gd")
const Simulator = preload("res://core/simulator.gd")
const Words = preload("res://core/words.gd")
const Lexicon = preload("res://tools/lexicon.gd")
const Journal = preload("res://ui/journal.gd")
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
	test_peek()
	test_news()
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
		check(banned.search(w["text"] + " " + w["word"]) == null, "%s speaks of paint, not bits or colors" % w["id"])
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
	check(Progress.VERSION == 3, "the save version moved on")


func test_journal_tabs() -> void:
	var j = journal(solved(12), "paint")
	check(j.tab == "paint" and j.paint_card.visible, "the Paint tab holds the paint card")
	key(j, KEY_3)
	check(j.tab == "pieces" and not j.paint_card.visible, "3 opens Pieces")
	key(j, KEY_TAB)
	check(j.tab == "inventions", "Tab goes to the next tab")
	tap(j, j._tab_rect(4).get_center())
	check(j.tab == "cloths", "a tap on a tab opens it")
	var chapter: int = j.chapter
	check(chapter == by_id[levels[12].id].chapter, "Cloths opens on the first chapter not finished")
	key(j, KEY_RIGHT)
	check(j.chapter == chapter + 1 and j.prev_button.visible, "→ turns the page")
	j.prev_button.pressed.emit()
	check(j.chapter == chapter, "and the arrow turns it back")
	key(j, KEY_2)
	key(j, KEY_7)
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
	var id: int = wb.machine.piece_at(5, 3)
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
	key(wb.news, KEY_ENTER)
	check(wb.news == null and went.size() == 1, "Enter goes on to the next level")
	# Solving it again brings nothing new: straight on.
	wb._rebuild()
	wb.fast_forward(100000, 1.0)
	wb._on_tick_shown()
	check(wb.new_words.is_empty() and wb.fresh.is_empty(), "a second solve brings nothing new")
	wb.panel.next.emit()
	check(wb.news == null and went.size() == 2, "so Next goes straight on")
	wb.queue_free()


## Options' key slots all fit the screen and none overlap, Journal's included.
func test_options_fit() -> void:
	var o = Options.new()
	o._ready()
	var tabs := 0
	for s in o.slots:
		tabs += int(str(s["action"]).begins_with("tab_"))
		check(Rect2(Vector2.ZERO, Options.DESIGN).encloses(s["rect"]), "%s's slot fits on screen" % s["action"])
	check(tabs == 7, "Options lists the journal's tabs")
	for a in o.slots.size():
		for b in range(a + 1, o.slots.size()):
			if o.slots[a]["rect"].intersects(o.slots[b]["rect"]):
				check(false, "slots %s and %s overlap" % [o.slots[a]["action"], o.slots[b]["action"]])
	o.free()
