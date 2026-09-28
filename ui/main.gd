## Entry point: loads levels and progress, switches between screens.
##
## Command-line options (after "--"):
##   --level=<id>                open a level straight away
##   --unlock-all                open every level
##   --screenshot=<id>:<path>    load a level's reference solution, run it,
##                               save a PNG and quit. <id> may also be
##                               "levels" or "book".
##   --ticks=<n>                 ticks to run before the screenshot
##                               (default: one per stitch)
##   --phase=<0..1>              how far drops are along their tubes
extends Control

const P = preload("res://ui/palette.gd")
const Level = preload("res://core/level.gd")
const Progress = preload("res://core/progress.gd")
const Invention = preload("res://core/invention.gd")
const Workbench = preload("res://ui/workbench.gd")
const LevelSelect = preload("res://ui/level_select.gd")
const PatternBook = preload("res://ui/pattern_book.gd")

const DESIGN := Vector2(1280, 800)

var levels: Array = []
var progress
var stage: Control
var screen: Control


func _ready() -> void:
	levels = Level.load_all()
	progress = Progress.load_from()
	var args := _args()
	if args.has("unlock-all"):
		progress.unlock_all = true
	stage = Control.new()
	stage.size = DESIGN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_center)
	_center()
	if args.has("screenshot"):
		_screenshot(args)
		return
	var start := _level_index(str(args.get("level", "")))
	if start >= 0:
		open_level(start)
	else:
		show_level_select()


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := str(a).trim_prefix("--")
		var eq := s.find("=")
		if eq >= 0:
			out[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			out[s] = true
	return out


func _level_index(id: String) -> int:
	for i in levels.size():
		if levels[i].id == id:
			return i
	return -1


func _center() -> void:
	stage.position = ((size - DESIGN) / 2).floor()
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(P.paper_texture(), Rect2(Vector2.ZERO, size), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and progress != null:
		progress.save()


func _set_screen(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	stage.add_child(c)


func show_level_select() -> void:
	var s = LevelSelect.new()
	s.setup(levels, progress)
	s.level_chosen.connect(open_level)
	s.book_requested.connect(show_book)
	_set_screen(s)


func show_book() -> void:
	var b = PatternBook.new()
	b.setup(levels, progress)
	b.back.connect(show_level_select)
	_set_screen(b)


func open_level(i: int) -> void:
	var w = Workbench.new()
	w.setup(levels[i], progress, i + 1 < levels.size())
	w.exit_requested.connect(func():
		progress.save()
		show_level_select())
	w.next_requested.connect(func():
		progress.save()
		open_level(i + 1))
	w.progress_changed.connect(func(): progress.save())
	_set_screen(w)


# ---------------------------------------------------------------------------
# Screenshot mode (self-check visuals)
# ---------------------------------------------------------------------------

func _screenshot(args: Dictionary) -> void:
	var spec := str(args["screenshot"])
	var colon := spec.find(":")
	var what := spec.substr(0, colon)
	var path := spec.substr(colon + 1)
	get_window().size = Vector2i(DESIGN)
	# A throwaway progress with the reference inventions; the real save is untouched.
	progress = Progress.new()
	for level in levels:
		if not level.invention.is_empty():
			progress.inventions[level.invention["id"]] = Invention.package(level, level.reference_machine(), progress.inventions)
	match what:
		"levels":
			for k in 6:
				progress.record_solve(levels[k].id, levels[k].best + (k % 2), 40 + k, 3 - (k % 2))
			show_level_select()
		"book":
			show_book()
		_:
			var i := _level_index(what)
			if i < 0:
				printerr("unknown level: " + what)
				get_tree().quit(1)
				return
			open_level(i)
			screen.load_machine(levels[i].reference_machine())
			screen.frozen = true
			screen.clock = 3.3
			screen.fast_forward(int(args.get("ticks", levels[i].size())), float(args.get("phase", 0.5)))
	for n in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("screenshot %s -> %s (%s)" % [what, path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
