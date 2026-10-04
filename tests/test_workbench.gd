## Plays the whole campaign through the workbench with simulated taps and
## drags only (the same events a mouse or a finger sends): every level's
## reference machine is built from the tray, run to the end, and scored.
## Also checks moving, trashing, tube re-routing, tube deletion and undo.
## Run: godot_console --headless --path . --script res://tests/test_workbench.gd
extends SceneTree

const Level = preload("res://core/level.gd")
const Invention = preload("res://core/invention.gd")
const Progress = preload("res://core/progress.gd")
const Pieces = preload("res://core/pieces.gd")
const Workbench = preload("res://ui/workbench.gd")
const LevelSelect = preload("res://ui/level_select.gd")
const K = preload("res://ui/draw_kit.gd")
const Keys = preload("res://ui/keys.gd")
const Options = preload("res://ui/options.gd")
const Intro = preload("res://ui/intro.gd")
const PaintCard = preload("res://ui/paint_card.gd")
const SETTINGS := "user://chromaton_settings_test.json"

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func _initialize() -> void:
	Keys.settings_path = SETTINGS  # the speed and Options save on every change
	var levels := Level.load_all()
	var by_id := {}
	for level in levels:
		by_id[level.id] = level
	var progress = Progress.new()
	test_editing(by_id["third_color"], Progress.new())
	test_keys(by_id["third_color"])
	test_paint_card(by_id["third_color"])
	test_bindings()
	test_card_hint(by_id["pattern_card"])
	test_left_edge(by_id["orange"])
	for i in levels.size():
		play_level(levels[i], progress, i)
	test_tray_lists_only_the_level(by_id["green"], progress)
	test_locked_tray(levels, by_id)
	test_pot_fan(levels, by_id)
	test_not_general(by_id["either_not_both"])
	test_unused_card(by_id["third_color"])
	test_note(by_id["green"])
	test_round_rect()
	test_level_select(levels)
	test_intro()
	if failures == 0:
		print("test_workbench: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


## Nodes added while _initialize runs only get _ready after it returns, and a
## workbench's _ready saves the speed: the settings stay pointed at the test's
## file until the very end, so the real settings are never written.
func _finalize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


# --- gestures ---------------------------------------------------------------

func press(wb, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	wb._gui_input(e)


func move(wb, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	wb._gui_input(e)


func release(wb, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = p
	wb._gui_input(e)


func drag(wb, a: Vector2, b: Vector2) -> void:
	press(wb, a)
	move(wb, a.lerp(b, 0.5))
	move(wb, b)
	release(wb, b)


func tap(wb, p: Vector2) -> void:
	press(wb, p)
	release(wb, p)


func tray_point(wb, kind: String) -> Vector2:
	for item in wb.tray:
		if item["kind"] == kind:
			return item["rect"].get_center()
	return Vector2(-1, -1)


func open(level, progress):
	var wb = Workbench.new()
	wb.setup(level, progress, true)
	root.add_child(wb)
	return wb


func node_named(wb, level, names: Dictionary, name: String) -> int:
	if name == "loom":
		return wb.machine.find_kind(Pieces.LOOM)
	if name.begins_with("card"):
		return wb.machine.find_kind(Pieces.CARD, int(name.substr(4)))
	return names.get(name, -1)


# --- tests ------------------------------------------------------------------

## Builds the level's reference machine by hand, runs it, and checks the score.
func play_level(level, progress, index: int) -> void:
	var wb = open(level, progress)
	var shown: Array = level.tray.duplicate()
	for inv_id in level.inventions:
		if progress.inventions.has(inv_id):
			shown.append("inv:" + inv_id)
	var shelf: Array = wb.tray.slice(0, wb.shelf_size)
	check(shelf.map(func(item): return item["kind"]) == shown, "%s: the tray holds the level's pieces and earlier levels' pieces" % level.id)
	var open_kinds: Array = shelf.filter(func(item): return not item["locked"]).map(func(item): return item["kind"])
	check(open_kinds.filter(func(k): return not k.begins_with("inv:")).size() == level.pieces.size() and level.pieces.all(func(k): return k in open_kinds), "%s: exactly the level's own pieces are open" % level.id)
	var names := {}
	for p in level.reference["pieces"]:
		var kind: String = p["kind"]
		if kind == Pieces.INVENTION:
			kind = "inv:" + p["invention"]
		if kind.begins_with("inv:pot_"):  # earned pots wait in the pot slot's fan
			tap(wb, tray_point(wb, "red_pot"))
			check(wb.fan_open, "%s: tapping the pot slot fans out the pots" % level.id)
		var from := tray_point(wb, kind)
		check(from.x >= 0, "%s: tray offers %s" % [level.id, kind])
		drag(wb, from, wb.cell_center(int(p["x"]), int(p["y"])))
		names[p["id"]] = wb.machine.piece_at(int(p["x"]), int(p["y"]))
		check(names[p["id"]] >= 0, "%s: placed %s by dragging" % [level.id, p["id"]])
	for t in level.reference["tubes"]:
		var a: Array = Level._endpoint(t[0])
		var b: Array = Level._endpoint(t[1])
		var from_id := node_named(wb, level, names, a[0])
		var to_id := node_named(wb, level, names, b[0])
		drag(wb, wb.out_port(from_id, a[1]), wb.in_port(to_id, b[1]))
		check(wb.machine.tube_into(to_id, b[1]) >= 0, "%s: tube %s laid by dragging" % [level.id, str(t)])
	check(wb.machine.tubes.size() == level.reference["tubes"].size(), "%s: every tube is on the bench" % level.id)
	check(wb.machine.cost(progress.inventions) == level.best, "%s: built machine costs %d" % [level.id, level.best])
	# Run at full speed until the loom is done.
	wb._set_speed(2)
	wb._toggle_run()
	var frames := 0
	while wb.outcome == "" and frames < 20000:
		wb._process(0.05)
		frames += 1
	check(wb.outcome == "solved", "%s: solved by playing (outcome '%s', tick %d)" % [level.id, wb.outcome, wb.sim.tick])
	check(wb.panel != null, "%s: success panel shows" % level.id)
	check(progress.is_solved(level.id) and progress.stars(level.id) == 3, "%s: three stars recorded" % level.id)
	var rec: Dictionary = progress.level_record(level.id)
	check(rec.get("best_pieces", -1) == level.best and rec.get("best_ticks", 0) == wb.sim.tick, "%s: pieces and ticks recorded" % level.id)
	if not level.invention.is_empty():
		var inv: Dictionary = progress.inventions.get(level.invention["id"], {})
		check(not inv.is_empty() and inv["cost"] == level.best, "%s: the player's machine joins the journal's inventions" % level.id)
	wb.queue_free()


## An invention the player owns stays out of a level that doesn't list it.
func test_tray_lists_only_the_level(level, progress) -> void:
	check(progress.inventions.has("contrast") and not "contrast" in level.inventions, "%s: set up with an owned, unlisted Contrast" % level.id)
	var wb = open(level, progress)
	check(tray_point(wb, "inv:contrast").x < 0, "%s: an unlisted invention is not in the tray" % level.id)
	wb.queue_free()


func locked_kinds(level) -> Array:
	return level.tray.filter(func(k): return level.is_locked(k))


## A tray shows earlier levels' pieces locked, in the order the campaign
## first offers them, so a piece keeps its slot (and number key) everywhere.
func test_locked_tray(levels: Array, by_id: Dictionary) -> void:
	var order := ["red_pot", "shift", "mix", "split", "invert", "filter"]
	check(by_id["smudges"].tray == order, "the full tray is in the order pieces arrive: %s" % str(by_id["smudges"].tray))
	var slot := {}
	var seen := {}
	for level in levels:
		for kind in level.pieces:
			seen[kind] = true
		check(level.tray == order.filter(func(k): return seen.has(k)), "%s: the tray shows every piece offered so far" % level.id)
		for i in level.tray.size():
			var kind: String = level.tray[i]
			check(slot.get(kind, i) == i, "%s: %s keeps slot %d" % [level.id, kind, slot.get(kind, i) + 1])
			slot[kind] = i
	check(locked_kinds(by_id["pattern_card"]) == ["red_pot", "shift", "mix", "split", "invert"], "The Pattern Card shows every known piece locked")
	check(locked_kinds(by_id["orange_sun"]) == ["split", "invert"], "Orange Sun locks Split and Invert")
	for id in ["opposites", "flip_side", "turn_the_wheel", "smudges", "either_not_both", "missing_from_either", "same_paint"]:
		check(locked_kinds(by_id[id]).is_empty(), "%s has no locks" % id)
	check(locked_kinds(by_id["keep_what_they_share"]) == ["filter"], "Keep What They Share locks Filter, which it rebuilds")
	check(locked_kinds(by_id["mix_without_mix"]) == ["mix"], "Mix Without Mix locks Mix")
	for id in ["neither_twice", "back_to_mix", "only_third_paint", "missing_twice", "back_to_filter", "only_missing"]:
		check(locked_kinds(by_id[id]) == ["red_pot", "shift", "mix", "invert", "filter"], "%s offers only Split of the critters" % id)
	check(Level.load_file("res://levels/orange_sun.json").tray == ["red_pot", "shift", "mix"], "a level loaded on its own has no locks")
	# A locked piece places nothing, by tap, drag or key; its lock wiggles.
	var level = by_id["orange_sun"]
	var wb = Workbench.new()
	wb.setup(level, Progress.new(), true)
	root.add_child(wb)
	wb._ready()
	var split := tray_point(wb, "split")
	check(wb.tray[3]["locked"] and not wb.tray[0]["locked"], "Orange Sun's Split slot is locked, the pot's isn't")
	var start: int = wb.machine.nodes.size()
	tap(wb, split)
	check(wb.carrying == -1 and wb.wiggle_slot == 3, "tapping a locked piece picks nothing up; its lock wiggles")
	drag(wb, split, wb.cell_center(5, 3))
	check(wb.machine.nodes.size() == start, "dragging a locked piece places nothing")
	key(wb, KEY_1)
	check(wb.carrying == 0, "1 still picks up the pot")
	key(wb, KEY_4)
	check(wb.carrying == -1 and wb.wiggle_slot == 3, "a locked piece's key wiggles its lock and empties the hand")
	tap(wb, wb.cell_center(5, 3))
	check(wb.machine.nodes.size() == start, "and nothing lands on the bench")
	wb.free()
	var card_wb = Workbench.new()
	card_wb.setup(by_id["pattern_card"], Progress.new(), true)
	root.add_child(card_wb)
	card_wb._ready()
	check(card_wb._first_open_slot() == -1, "The Pattern Card has nothing to place")
	card_wb.free()


## Without cards, the whole bench takes pieces, right up to its left edge.
func test_left_edge(level) -> void:
	var wb = open(level, Progress.new())
	for row in [0, 3, 6]:
		drag(wb, tray_point(wb, "red_pot"), wb.cell_center(0, row))
		check(wb.machine.piece_at(0, row) >= 0, "%s: a pot fits in the first column, row %d" % [level.id, row])
	wb.queue_free()


## With nothing in the tray, the hand shows the tube from the card to the loom.
func test_card_hint(level) -> void:
	var wb = open(level, Progress.new())
	var card: int = wb.machine.find_kind(Pieces.CARD, 0)
	check(wb._hint_path() == [wb.out_port(card, 0), wb.loom_port], "%s: the hint lays the card's tube" % level.id)
	drag(wb, wb.out_port(card, 0), wb.loom_port)
	check(wb._hint_path().is_empty(), "%s: the hint stops once the loom is fed" % level.id)
	wb.queue_free()


func test_editing(level, progress) -> void:
	var wb = open(level, progress)
	var m = wb.machine
	# Place a mix and an invert.
	drag(wb, tray_point(wb, "mix"), wb.cell_center(5, 3))
	drag(wb, tray_point(wb, "invert"), wb.cell_center(7, 3))
	var mix: int = m.piece_at(5, 3)
	var inv: int = m.piece_at(7, 3)
	check(mix >= 0 and inv >= 0, "drag from tray places pieces")
	drag(wb, tray_point(wb, "shift"), wb.cell_center(5, 3))
	check(wb.machine.nodes.size() == 5, "a piece can't be dropped on an occupied cell")
	# Cards cover the first two cells of their rows; the rest of the left edge is free.
	drag(wb, tray_point(wb, "shift"), wb.cell_center(1, 1))
	check(wb.machine.nodes.size() == 5, "a piece can't be dropped on a pattern card")
	drag(wb, tray_point(wb, "shift"), wb.cell_center(0, 3))
	check(wb.machine.piece_at(0, 3) >= 0, "the left edge between cards takes pieces")
	wb._undo()
	m = wb.machine
	# Tubes: card A -> mix, card B -> mix (dragged backwards), mix -> invert -> loom.
	var card_a: int = m.find_kind(Pieces.CARD, 0)
	var card_b: int = m.find_kind(Pieces.CARD, 1)
	var loom: int = m.find_kind(Pieces.LOOM)
	drag(wb, wb.out_port(card_a, 0), wb.in_port(mix, 0))
	drag(wb, wb.in_port(mix, 1), wb.out_port(card_b, 0))
	drag(wb, wb.out_port(mix, 0), wb.in_port(inv, 0))
	drag(wb, wb.out_port(inv, 0), wb.loom_cloth.get_center())
	check(wb.machine.tubes.size() == 4, "four tubes laid (got %d)" % wb.machine.tubes.size())
	check(wb.machine.tube_into(mix, 1) >= 0, "a tube can be dragged from an input to an output")
	check(wb.machine.tube_into(loom, 0) >= 0, "dropping a tube on the loom connects it")
	# Move the invert; its tubes follow.
	drag(wb, wb.cell_center(7, 3), wb.cell_center(7, 5))
	check(wb.machine.piece_at(7, 5) == inv and wb.machine.piece_at(7, 3) == -1, "drag moves a piece")
	check(wb.machine.tubes.size() == 4, "moving keeps tubes")
	# Tap a tube, then its delete button.
	var ti: int = wb.machine.tube_into(inv, 0)
	tap(wb, wb.tube_points(ti)[12])
	check(wb.selected_tube == ti, "tapping a tube selects it")
	tap(wb, wb._delete_button_pos())
	check(wb.machine.tubes.size() == 3 and wb.machine.tube_into(inv, 0) < 0, "delete button removes the tube")
	# Undo brings it back.
	wb._undo()
	check(wb.machine.tubes.size() == 4, "undo restores the tube")
	m = wb.machine
	# Drag a tube's end off its input to empty space: removed.
	drag(wb, wb.in_port(inv, 0), wb.cell_center(8, 0))
	check(wb.machine.tube_into(inv, 0) < 0, "dragging a tube end away removes it")
	wb._undo()
	# Re-route a tube end to another input.
	drag(wb, tray_point(wb, "shift"), wb.cell_center(9, 5))
	var shift: int = wb.machine.piece_at(9, 5)
	drag(wb, wb.in_port(inv, 0), wb.in_port(shift, 0))
	check(wb.machine.tube_into(shift, 0) >= 0 and wb.machine.tube_into(inv, 0) < 0, "a tube end can be moved to another input")
	# Trash: drag a piece onto the tray.
	drag(wb, wb.cell_center(9, 5), wb.TRASH.get_center())
	check(wb.machine.piece_at(9, 5) == -1, "dragging a piece to the trash removes it")
	check(wb.machine.tube_into(shift, 0) < 0, "its tubes go with it")
	# An edit while running rewinds the run.
	wb._undo()
	wb._undo()
	wb._toggle_run()
	for n in 10:
		wb._process(0.25)
	check(wb.sim.tick > 0, "the machine runs")
	drag(wb, tray_point(wb, "red_pot"), wb.cell_center(0, 0))
	check(wb.sim.tick == 0 and not wb.running, "editing stops and rewinds the run")
	# A wrong machine shows the wrong stitch.
	drag(wb, wb.in_port(inv, 0), wb.cell_center(8, 0))
	drag(wb, wb.out_port(mix, 0), wb.loom_cloth.get_center())
	wb._toggle_run()
	var frames := 0
	while wb.outcome == "" and frames < 5000:
		wb._process(0.25)
		frames += 1
	check(wb.outcome == "wrong" and wb.sim.wrong_index == 0, "a wrong machine stops at the wrong stitch (%s)" % wb.outcome)
	# Stepping one tick at a time.
	wb._reset_pressed()
	wb._step_pressed()
	check(wb.sim.tick == 1 and not wb.running, "step advances one tick")
	var at_one: String = wb.sim.signature()
	wb._step_pressed()
	wb._step_pressed()
	wb._step_back_pressed()
	wb._step_back_pressed()
	check(wb.sim.tick == 1 and wb.sim.signature() == at_one, "step back returns to the same state")
	wb._step_back_pressed()
	wb._step_back_pressed()
	check(wb.sim.tick == 0, "step back stops at the start")
	wb._toggle_run()
	for n in 8:
		wb._process(0.25)
	wb._step_back_pressed()
	check(not wb.running and wb.sim.tick > 0, "step back pauses a running machine")
	wb.queue_free()


## An invention must work for every pair of paints, not only the level's cards.
func test_not_general(inv_level) -> void:
	var raw: Dictionary = inv_level.raw.duplicate(true)
	raw["invention"]["check"] = "bleach"  # the Contrast picture, judged as a Bleach
	var level = Level.from_dict(raw)
	var progress = Progress.new()
	var wb = open(level, progress)
	wb.load_machine(level.reference_machine())
	wb._set_speed(2)
	wb._toggle_run()
	var frames := 0
	while wb.outcome == "" and frames < 5000:
		wb._process(0.05)
		frames += 1
	check(wb.outcome == "not_general", "a machine that only fits the cards is not accepted (%s)" % wb.outcome)
	check(not progress.is_solved(level.id) and progress.inventions.is_empty(), "nothing is recorded")
	wb.queue_free()


## The level's note pops up, any key (or a tap) lands it under the title
## without doing what the key means, and tapping the title brings it back.
func test_note(level) -> void:
	var wb = open(level, Progress.new())
	wb.show_note()
	var note = wb.note
	check(note != null and wb._still_look()[0], "the level's note pops up")
	key(wb, KEY_SPACE)
	check(not wb.running, "a key doesn't reach the bench while the note is up")
	key(note, KEY_SPACE)
	for n in 10:
		note._process(0.1)
	check(wb.note == null and not wb.running, "a key lands the note without running the machine")
	tap(wb, wb.TITLE_HIT.get_center())
	check(wb.note != null, "tapping the title brings the note back")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	wb.note._gui_input(e)
	wb.note._process(1.0)
	check(wb.note == null, "a tap lands it")
	wb.queue_free()


## A card with no tube out of it fails the run as soon as it starts.
func test_unused_card(level) -> void:
	var wb = open(level, Progress.new())
	wb.load_machine(level.reference_machine())
	var card: int = wb.machine.find_kind(Pieces.CARD, 1)
	wb.machine.remove_tube(wb.machine.tube_from(card, 0))
	wb._edited()
	wb._toggle_run()
	for n in 10:
		wb._process(0.25)
	check(wb.outcome == "unused" and wb.sim.unused_card == 1 and wb.sim.tick == 0, "a card with no tube fails the run at once (%s)" % wb.outcome)
	wb.queue_free()


## A rounded rectangle whose radius is half its width (the hint hand's finger)
## has no repeated points and triangulates wherever it is drawn.
func test_round_rect() -> void:
	var ok := true
	for k in 60:
		var pts := K.round_rect(Rect2(Vector2(100.13 + k * 0.37, 80.71 + k * 0.29), Vector2(10, 28)), 5)
		for i in pts.size():
			if pts[i].is_equal_approx(pts[(i + 1) % pts.size()]):
				ok = false
		if Geometry2D.triangulate_polygon(pts).is_empty():
			ok = false
	check(ok, "narrow rounded rectangles have no repeated points and triangulate")


## The intro goes on with one tap anywhere or Enter; for a stale save it
## waits for an answer, and Enter starts fresh.
func test_intro() -> void:
	var said := []
	for stale in [false, true]:
		var s = Intro.new()
		s.stale = stale
		root.add_child(s)
		s._ready()
		for sig in ["done", "fresh", "keep"]:
			s.connect(sig, func(): said.append(sig))
		tap(s, Vector2(100, 700))
		key(s, KEY_ENTER)
		s.queue_free()
	check(said == ["done", "done", "fresh"], "the intro goes on by tap or Enter, a stale one only by an answer (got %s)" % str(said))


## One page per chapter; the arrows stop at the first and last chapter.
func test_level_select(levels: Array) -> void:
	var chapters := Level.chapters()
	var s = LevelSelect.new()
	s.setup(levels, Progress.new(), 1)
	root.add_child(s)
	check(s.page == 1, "the level select opens on the page it is given")
	var turned := []
	s.page_changed.connect(func(c): turned.append(c))
	for c in chapters.size():
		var ids: Array = s.page_levels(c).map(func(i): return levels[i].id)
		check(ids == chapters[c]["levels"], "page %d holds chapter %d's levels" % [c, c])
	s.turn(-1)
	check(s.page == 0 and s.tags.size() == chapters[0]["levels"].size(), "turning back shows the first chapter's tags")
	check(not s.prev_button.visible and s.next_button.visible, "no back arrow on the first page")
	s.turn(-1)
	check(s.page == 0, "turning stops at the first page")
	s.turn(chapters.size() + 3)
	check(s.page == chapters.size() - 1 and not s.next_button.visible and s.prev_button.visible, "turning stops at the last page")
	check(turned == [0, chapters.size() - 1], "each page turn is announced once")
	s.queue_free()


# --- keys -------------------------------------------------------------------

func key(node, code: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	node._unhandled_input(e)


## Keys only do what taps do: a tray piece's key (or a tap on it) picks the
## piece up and a click puts it down; Delete removes only a selection; Back
## drops a carried piece, then clears a selection, then leaves.
func test_keys(level) -> void:
	Keys.reset()
	var wb = open(level, Progress.new())
	var left := []
	wb.exit_requested.connect(func(): left.append(true))
	var start: int = wb.machine.nodes.size()
	move(wb, wb.cell_center(5, 3))
	key(wb, KEY_1)
	check(wb.carrying == 0 and wb.machine.nodes.size() == start, "1 picks up the first tray piece without placing it")
	check(wb._carried_ghost(), "the carried piece follows the pointer over the bench")
	tap(wb, wb.cell_center(5, 3))
	var id: int = wb.machine.piece_at(5, 3)
	check(id >= 0 and wb.machine.nodes[id]["kind"] == wb.tray[0]["kind"] and wb.carrying == -1, "a click puts the carried piece down")
	key(wb, KEY_2)
	tap(wb, wb.cell_center(5, 3))
	check(wb.machine.nodes.size() == start + 1 and wb.carrying == -1, "a click on a taken cell drops the carried piece back")
	key(wb, KEY_2)
	key(wb, KEY_2)
	check(wb.carrying == -1, "picking the same piece again puts it back")
	key(wb, KEY_9)
	check(wb.carrying == -1, "a key past the tray picks nothing")
	key(wb, KEY_KP_2)
	key(wb, KEY_ESCAPE)
	check(wb.carrying == -1 and left.is_empty(), "Esc drops a carried piece and stays")
	key(wb, KEY_2)
	var nodes: int = wb.machine.nodes.size()
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	rc.position = wb.cell_center(11, 3)
	wb._gui_input(rc)
	check(wb.carrying == -1 and wb.machine.nodes.size() == nodes, "a right-click drops a carried piece without placing it")
	tap(wb, tray_point(wb, wb.tray[1]["kind"]))
	check(wb.carrying == 1, "tapping a tray piece picks it up")
	tap(wb, wb.cell_center(7, 3))
	check(wb.machine.piece_at(7, 3) >= 0, "and a tap on a free cell puts it down")
	drag(wb, tray_point(wb, wb.tray[0]["kind"]), wb.cell_center(9, 3))
	check(wb.machine.piece_at(9, 3) >= 0 and wb.carrying == -1, "dragging from the tray still places")
	# Delete only acts on what is selected, never on what's under the pointer.
	move(wb, wb.cell_center(7, 3))
	key(wb, KEY_DELETE)
	check(wb.machine.piece_at(7, 3) >= 0, "Delete with nothing selected does nothing")
	tap(wb, wb.cell_center(5, 3))
	check(wb.selected_piece == id, "tapping a piece selects it")
	key(wb, KEY_ESCAPE)
	check(wb.selected_piece == -1 and left.is_empty(), "Esc clears the selection and stays")
	tap(wb, wb.cell_center(5, 3))
	tap(wb, wb._delete_button_pos())
	check(wb.machine.piece_at(5, 3) < 0, "a selected piece's delete button removes it")
	key(wb, KEY_Z)
	check(wb.machine.piece_at(5, 3) >= 0, "Z undoes")
	tap(wb, wb.cell_center(5, 3))
	key(wb, KEY_BACKSPACE)
	check(wb.machine.piece_at(5, 3) < 0, "Backspace removes the selected piece")
	key(wb, KEY_MINUS)
	key(wb, KEY_MINUS)
	check(wb.speed == 0, "- slows down to slow")
	key(wb, KEY_EQUAL)
	key(wb, KEY_PLUS)
	key(wb, KEY_KP_ADD)
	check(wb.speed == 2, "+ speeds up to fast")
	key(wb, KEY_TAB)
	check(wb.speed == 0, "Tab after fast goes round to slow")
	key(wb, KEY_TAB)
	check(wb.speed == 1, "Tab steps on to normal")
	key(wb, KEY_EQUAL)
	var next = open(level, Progress.new())
	check(next.speed == 2, "the speed carries to the next level")
	next.queue_free()
	Keys.speed = 1
	Keys.load_settings()
	check(Keys.speed == 2, "the speed is kept in the settings file")
	key(wb, KEY_MINUS)
	# A changed key works at once and the old one stops.
	Keys.bind("run", 0, KEY_G)
	key(wb, KEY_SPACE)
	check(not wb.running, "an unbound key does nothing")
	key(wb, KEY_G)
	check(wb.running, "a newly bound key runs")
	key(wb, KEY_G)
	Keys.reset()
	key(wb, KEY_ESCAPE)
	check(left.size() == 1, "Esc with nothing selected leaves the level")
	wb.queue_free()
	var s = LevelSelect.new()
	s.setup(Level.load_all(), Progress.new(), 0)
	root.add_child(s)
	check(s.continue_level() == 0, "Enter on a fresh save plays the first level")
	var chosen := []
	s.level_chosen.connect(func(i): chosen.append(i))
	key(s, KEY_ENTER)
	key(s, KEY_RIGHT)
	check(chosen == [0] and s.page == 1, "the level select takes Enter and arrows")
	s.queue_free()


## The paint card: the Paints button or P puts it up and away, a tap on the
## card puts it away, it stays up from level to level, the bench works around
## it, and Back puts it away only after a carried piece and a selection.
func test_paint_card(level) -> void:
	Keys.reset()
	Keys.paints = false
	# The triangle tells the rules: primaries where their glyph dots sit, each
	# mix halfway between its two paints, black in the middle, opposites
	# straight across it.
	var at: Dictionary = PaintCard.spots()
	var mid: Vector2 = at[7]
	var dots := {1: -PI / 2, 2: PI / 6, 4: 5 * PI / 6}
	for c in dots:
		check(absf(angle_difference((at[c] - mid).angle(), dots[c])) < 0.01, "paint %d sits where its glyph dot sits" % c)
	for c in [3, 5, 6]:
		var parents := [1, 2, 4].filter(func(p): return (c & p) != 0)
		check(at[c].distance_to((at[parents[0]] + at[parents[1]]) / 2) < 0.01, "mix %d sits halfway between its paints" % c)
	for c in range(1, 7):
		check(absf(angle_difference((at[c] - mid).angle(), (at[7 - c] - mid).angle() + PI)) < 0.01, "paint %d faces its opposite across black" % c)
	var wb = open(level, Progress.new())
	wb._ready()  # its buttons (headless tests never run _ready on their own)
	check(wb.paint_card == null and not wb.btn_paints.toggled_on, "the paint card starts away")
	key(wb, KEY_P)
	check(wb.paint_card != null and wb.btn_paints.toggled_on, "P puts the paint card up")
	var card: Rect2 = wb.paint_card.get_rect()
	check(wb.BENCH.encloses(card), "the card hangs over the bench")
	check(card.end.y <= wb.cell_center(0, 3).y - wb.CELL.y / 2, "and clears the middle row, where a single card's machine sits")
	Keys.paints = false
	Keys.load_settings()
	check(Keys.paints, "the card being up is kept in the settings file")
	var next = open(level, Progress.new())
	next._ready()
	check(next.paint_card != null, "the card stays up in the next level")
	next.show_note()
	check(next.note.get_index() > next.paint_card.get_index(), "the level's note covers the card")
	next.free()  # now, before a frame would run its _ready again
	tap(wb, tray_point(wb, wb.tray[0]["kind"]))
	tap(wb, wb.cell_center(5, 5))
	check(wb.machine.piece_at(5, 5) >= 0 and wb.paint_card != null, "the bench works around the card")
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	wb.paint_card._gui_input(e)
	check(wb.paint_card == null and not Keys.paints, "a tap on the card puts it away")
	wb.btn_paints.pressed.emit()
	check(wb.paint_card != null, "the Paints button puts it up")
	var left := []
	wb.exit_requested.connect(func(): left.append(true))
	tap(wb, wb.cell_center(5, 5))
	key(wb, KEY_ESCAPE)
	check(wb.selected_piece == -1 and wb.paint_card != null, "Esc clears a selection before the card")
	key(wb, KEY_ESCAPE)
	check(wb.paint_card == null and left.is_empty(), "then puts the card away and stays")
	key(wb, KEY_ESCAPE)
	check(left.size() == 1, "then leaves")
	wb.free()
	Keys.paints = false


## Binding: a key moves off actions it clashes with (same screen, or
## Everywhere), not off other screens' actions; settings save and load.
func test_bindings() -> void:
	Keys.reset()
	var moved: Array = Keys.bind("undo", 1, KEY_R)
	check(moved == ["reset"] and Keys.bindings["reset"][0] == 0, "a key moves off a clashing action on the same screen")
	check(Keys.bindings["replay"][0] == KEY_R, "but stays on another screen's action")
	moved = Keys.bind("book", 0, KEY_ESCAPE)
	check(moved == ["back"], "Everywhere keys clash with every screen")
	moved = Keys.bind("step", 1, KEY_S)
	check(moved.is_empty() and Keys.bindings["step"] == [0, KEY_S], "moving a key between an action's own slots")
	Keys.bind("faster", 0, KEY_KP_ADD)
	check(Keys.bindings["faster"][0] == KEY_EQUAL, "number pad keys count as their main keys")
	check(Keys.key_name(KEY_ESCAPE) == "Esc" and Keys.key_name(KEY_LEFT) == "←" and Keys.key_name(KEY_F5) == "F5", "key names")
	var path := SETTINGS
	Keys.save_settings(path)
	var saved: Dictionary = Keys.bindings.duplicate(true)
	Keys.reset()
	Keys.load_settings(path)
	check(Keys.bindings == saved, "keys survive a save and load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Keys.reset()
	var o = Options.new()
	root.add_child(o)
	o._ready()
	var undo_slot := -1
	for i in o.slots.size():
		if o.slots[i]["action"] == "undo" and o.slots[i]["slot"] == 1:
			undo_slot = i
	check(undo_slot >= 0, "Options has a second slot for Undo")
	o.tap_slot(undo_slot)
	check(o.capturing == {"action": "undo", "slot": 1}, "tapping a slot waits for a key")
	o.tap_slot(undo_slot)
	check(o.capturing.is_empty() and Keys.bindings["undo"][1] == 0, "tapping it again clears it")
	# The bench grid: off at first, switched in Options and kept in the settings.
	check(not Keys.grid, "the bench grid starts off")
	o._toggle_grid()
	Keys.grid = false
	Keys.load_settings()
	check(Keys.grid, "the grid switch is saved")
	o.queue_free()
	# Without a keyboard Options still has the grid, but no keys.
	Keys.keyboard = false
	o = Options.new()
	root.add_child(o)
	o._ready()
	check(o.slots.is_empty() and o.hints_button == null and o.grid_button != null and o.grid_button.toggled_on, "keyboardless Options offers only the grid")
	o._toggle_grid()
	check(not Keys.grid, "and switches it off again")
	var s = LevelSelect.new()
	s.setup(Level.load_all(), Progress.new(), 0)
	var gears := s.get_children().filter(func(c): return c.get("icon") == "options")
	check(gears.size() == 1, "the level select offers Options on every build")
	s.free()
	Keys.keyboard = true
	o.queue_free()
	Keys.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## From chapter 2 on the red pot's slot is the pot slot: a tap fans out the
## owned pots above the shelf (touch-first, no hover), a tap or drag takes one
## out, keys pick from the fan while it's open, Back folds it, and a pot the
## level holds back sits in the fan locked.
func test_pot_fan(levels: Array, by_id: Dictionary) -> void:
	var p = Progress.new()
	for id in ["yellow", "blue", "black_short_way"]:
		var l = by_id[id]
		p.add_invention(Invention.package(l, l.reference_machine(), p.inventions))
	var plain = open(by_id["black_short_way"], p)
	check(not plain.tray[0].get("pots", false) and plain.shelf_size == plain.tray.size(), "the paint box keeps a plain red pot")
	plain.queue_free()
	var wb = open(by_id["orange_sun"], p)
	wb._ready()
	var slot := tray_point(wb, "red_pot")
	check(wb.tray[0].get("pots", false) and not wb.fan_open, "Orange Sun's first slot is the pot slot, folded")
	var fan: Array = wb.tray.slice(wb.shelf_size).map(func(e): return e["kind"])
	check(fan == ["red_pot", "inv:pot_yellow", "inv:pot_blue", "inv:pot_black"], "the fan holds the red pot and the owned pots in paint order: %s" % str(fan))
	var yellow: Vector2 = wb.tray[wb.shelf_size + 1]["rect"].get_center()
	tap(wb, yellow)
	check(wb.carrying == -1, "a folded fan takes no taps")
	tap(wb, slot)
	check(wb.fan_open and wb.carrying == -1, "tapping the pot slot fans the pots out")
	check(wb.tray.slice(wb.shelf_size).all(func(e): return e["rect"].end.y < wb.TRAY.position.y and wb.BENCH.encloses(e["rect"])), "the fan sits above the shelf, on the bench")
	tap(wb, yellow)
	check(wb.carrying == wb.shelf_size + 1 and not wb.fan_open, "tapping a fanned-out pot picks it up and folds the fan")
	tap(wb, wb.cell_center(5, 5))
	var placed: int = wb.machine.piece_at(5, 5)
	check(placed >= 0 and wb.machine.nodes[placed].get("invention", "") == "pot_yellow", "a click puts the yellow pot down")
	tap(wb, slot)
	drag(wb, wb.tray[wb.shelf_size + 2]["rect"].get_center(), wb.cell_center(6, 5))
	check(wb.machine.piece_at(6, 5) >= 0 and wb.machine.nodes[wb.machine.piece_at(6, 5)].get("invention", "") == "pot_blue" and not wb.fan_open, "a pot drags straight out of the fan")
	drag(wb, slot, wb.cell_center(7, 5))
	check(wb.machine.piece_at(7, 5) >= 0 and wb.machine.nodes[wb.machine.piece_at(7, 5)]["kind"] == "red_pot", "dragging the pot slot itself places the red pot")
	key(wb, KEY_1)
	check(wb.fan_open, "the pot slot's key fans the pots out")
	key(wb, KEY_4)
	check(wb.carrying == wb.shelf_size + 3 and not wb.fan_open, "with the fan open, a number key picks that pot")
	key(wb, KEY_ESCAPE)
	key(wb, KEY_1)
	key(wb, KEY_ESCAPE)
	check(not wb.fan_open and wb.carrying == -1, "Back folds the fan")
	tap(wb, slot)
	tap(wb, wb.cell_center(8, 0))
	check(not wb.fan_open, "a tap anywhere else folds it")
	wb.free()
	# A held-back pot shows in the fan, locked.
	var raw: Dictionary = by_id["orange_sun"].raw.duplicate(true)
	raw["hold_pots"] = ["pot_blue"]
	var held = Level.from_dict(raw)
	held.chapter = 1
	var copy := levels.duplicate()
	copy[copy.find(by_id["orange_sun"])] = held
	Level._lay_trays(copy)
	wb = open(held, p)
	wb._ready()
	tap(wb, tray_point(wb, "red_pot"))
	var blue: Dictionary = wb.tray[wb.shelf_size + 2]
	check(blue["kind"] == "inv:pot_blue" and blue["locked"], "a held-back pot is locked in the fan")
	tap(wb, blue["rect"].get_center())
	check(wb.carrying == -1 and wb.wiggle_slot == wb.shelf_size + 2, "tapping it only wiggles its lock")
	wb.free()
	Level._lay_trays(levels)
	var lone = open(by_id["neither_twice"], p)
	check(not lone.tray.any(func(e): return e.get("pots", false) or e.get("fan", false)), "a level of named pieces offers no pots")
	lone.queue_free()
