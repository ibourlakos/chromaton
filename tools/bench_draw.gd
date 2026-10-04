## Times the workbench's drawing, level by level: its reference machine runs
## at fast speed, then the run stops and a piece is dragged from the tray over
## the bench. Prints the time each frame spends drawing the bench (every layer
## that redrew) for both, and what each layer costs a running frame.
## Run: .\make bench (headless, with a fixed 60 frames a second, so the layers
## redraw as often as they would on screen)
extends SceneTree

const Level = preload("res://core/level.gd")
const Progress = preload("res://core/progress.gd")
const Invention = preload("res://core/invention.gd")
const Keys = preload("res://ui/keys.gd")
const SETTINGS := "user://chromaton_settings_bench.json"  # never the real settings

const FRAMES := 180  # per phase: three seconds at 60 frames a second
const LAYERS := ["still", "shelf", "tray", "aim", "cards", "paints", "wiring", "loom", "critters", "ports", "top"]


class TimedBench extends "res://ui/workbench.gd":
	var frame_us := 0  # this frame's drawing so far
	var parts := {}

	func _done(part: String, t: int) -> void:
		var us := Time.get_ticks_usec() - t
		frame_us += us
		parts[part] = parts.get(part, 0) + us

	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("top", t)

	func _draw_still() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("still", t)

	func _draw_shelf() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("shelf", t)

	func _draw_tray() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("tray", t)

	func _draw_wiring() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("wiring", t)

	func _draw_loom() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("loom", t)

	func _draw_critters() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("critters", t)

	func _draw_ports() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("ports", t)

	func _draw_aim() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("aim", t)

	func _draw_cards() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("cards", t)

	func _draw_card_paints() -> void:
		var t := Time.get_ticks_usec()
		super()
		_done("paints", t)


var levels := []
var progress
var index := -1
var frame := 0
var bench: TimedBench
var dragging := false  # the second phase: the run stopped, a piece dragged
var run_us := []
var drag_us := []
var run_parts := {}
var totals := [[], []]


func _initialize() -> void:
	Keys.settings_path = SETTINGS  # setting the speed saves the settings
	levels = Level.load_all()
	progress = Progress.new()
	for level in levels:
		if not level.invention.is_empty():
			progress.inventions[level.invention["id"]] = Invention.package(level, level.reference_machine(), progress.inventions)
	print("per frame, in microseconds: running at fast speed | dragging a piece from the tray over the bench")
	_next()


func _next() -> void:
	if bench != null:
		_report()
		bench.queue_free()
		bench = null
	index += 1
	if index >= levels.size():
		print("all levels: running %.0f us, dragging %.0f us average per frame" % [_mean(totals[0]), _mean(totals[1])])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
		quit(0)
		return
	var level = levels[index]
	bench = TimedBench.new()
	bench.setup(level, progress, false)
	root.add_child(bench)
	bench.load_machine(level.reference_machine())
	bench._set_speed(2)
	bench.running = true
	frame = 0
	dragging = false
	run_us = []
	drag_us = []


func _process(_delta: float) -> bool:
	if bench == null:
		return false
	# What the last frame drew (the first frames draw every layer once).
	if frame > 2:
		(drag_us if dragging else run_us).append(bench.frame_us)
	if frame == 2:
		bench.parts = {}
	bench.frame_us = 0
	frame += 1
	if frame == FRAMES:
		run_parts = bench.parts
		dragging = true
		bench._rebuild()  # stops the run
		var slot: int = bench._first_open_slot()
		if slot >= 0:
			bench._press(bench.tray[slot]["rect"].get_center())
	if dragging:
		if bench.drag == "new":
			bench.drag_pos = Vector2(100 + (frame % 100) * 8, 300 + sin(frame * 0.1) * 100)
			bench.drag_moved = true
	else:
		# Keep it running: start again when the run ends.
		if bench.sim.status != bench.Simulator.Status.RUNNING and bench.phase >= 1.0:
			bench._rebuild()
		bench.running = true
	if frame >= FRAMES * 2:
		_next()
	return false


func _mean(values: Array) -> float:
	var sum := 0.0
	for v in values:
		sum += v
	return sum / maxf(1, values.size())


func _report() -> void:
	var run := _mean(run_us)
	var drag := _mean(drag_us)
	totals[0].append(run)
	totals[1].append(drag)
	var line := "%-22s %2d nodes %2d tubes  run %5.0f (worst %5d) | drag %5.0f (worst %5d) | running:" % [
		levels[index].id, bench.machine.nodes.size(), bench.machine.tubes.size(), run, run_us.max(), drag, drag_us.max()]
	for part in LAYERS:
		var us := float(run_parts.get(part, 0)) / maxf(1, run_us.size())
		if us >= 1:
			line += " %s %.0f" % [part, us]
	print(line)
