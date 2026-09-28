## Plays the whole campaign through the workbench with simulated taps and
## drags only (the same events a mouse or a finger sends): every level's
## reference machine is built from the tray, run to the end, and scored.
## Also checks moving, trashing, tube re-routing, tube deletion and undo.
## Run: godot_console --headless --path . --script res://tests/test_workbench.gd
extends SceneTree

const Level = preload("res://core/level.gd")
const Progress = preload("res://core/progress.gd")
const Pieces = preload("res://core/pieces.gd")
const Workbench = preload("res://ui/workbench.gd")

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func _initialize() -> void:
	var levels := Level.load_all()
	var progress = Progress.new()
	test_editing(levels[5], Progress.new())
	for i in levels.size():
		play_level(levels[i], progress, i)
	if failures == 0:
		print("test_workbench: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


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
	var names := {}
	for p in level.reference["pieces"]:
		var kind: String = p["kind"]
		if kind == Pieces.INVENTION:
			kind = "inv:" + p["invention"]
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
		check(not inv.is_empty() and inv["cost"] == 4, "%s: the player's machine joins the Pattern Book" % level.id)
	wb.queue_free()


func test_editing(level, progress) -> void:
	var wb = open(level, progress)
	var m = wb.machine
	# Place a mix and an invert.
	drag(wb, tray_point(wb, "mix"), wb.cell_center(6, 1))
	drag(wb, tray_point(wb, "invert"), wb.cell_center(6, 3))
	var mix: int = m.piece_at(6, 1)
	var inv: int = m.piece_at(6, 3)
	check(mix >= 0 and inv >= 0, "drag from tray places pieces")
	drag(wb, tray_point(wb, "shift"), wb.cell_center(6, 1))
	check(wb.machine.nodes.size() == 5, "a piece can't be dropped on an occupied cell")
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
	drag(wb, wb.cell_center(6, 3), wb.cell_center(8, 3))
	check(wb.machine.piece_at(8, 3) == inv and wb.machine.piece_at(6, 3) == -1, "drag moves a piece")
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
	drag(wb, wb.in_port(inv, 0), Vector2(1000, 300))
	check(wb.machine.tube_into(inv, 0) < 0, "dragging a tube end away removes it")
	wb._undo()
	# Re-route a tube end to another input.
	drag(wb, tray_point(wb, "shift"), wb.cell_center(10, 3))
	var shift: int = wb.machine.piece_at(10, 3)
	drag(wb, wb.in_port(inv, 0), wb.in_port(shift, 0))
	check(wb.machine.tube_into(shift, 0) >= 0 and wb.machine.tube_into(inv, 0) < 0, "a tube end can be moved to another input")
	# Trash: drag a piece onto the tray.
	drag(wb, wb.cell_center(10, 3), wb.TRASH.get_center())
	check(wb.machine.piece_at(10, 3) == -1, "dragging a piece to the trash removes it")
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
	drag(wb, wb.in_port(inv, 0), Vector2(1000, 300))
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
	wb.queue_free()
