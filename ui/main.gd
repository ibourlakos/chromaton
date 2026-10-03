## Entry point: loads levels and progress, switches between screens.
##
## Command-line options (after "--"):
##   --level=<id>                open a level straight away (no intro)
##   --unlock-all                open every level
##   --screenshot=<id>:<path>    load a level's reference solution, run it,
##                               save a PNG and quit. <id> may also be
##                               "levels", "book", "options" or "intro".
##   --ticks=<n>                 ticks to run before the screenshot
##                               (default: one per stitch)
##   --phase=<0..1>              how far drops are along their tubes
##   --finish                    run to the end and show the result
##   --wrong                     tube card A straight to the loom instead
##   --empty                     leave the bench empty
##   --page=<n>                  the level select's chapter page (from 0)
##   --stale                     the intro as it reads for a stale save
##   --grid                      the bench grid on (Options)
##   --touch                     as on a phone build: no keys in Options, no
##                               key labels
extends Control

const P = preload("res://ui/palette.gd")
const Level = preload("res://core/level.gd")
const Progress = preload("res://core/progress.gd")
const Invention = preload("res://core/invention.gd")
const Workbench = preload("res://ui/workbench.gd")
const LevelSelect = preload("res://ui/level_select.gd")
const PatternBook = preload("res://ui/pattern_book.gd")
const Options = preload("res://ui/options.gd")
const Intro = preload("res://ui/intro.gd")
const Keys = preload("res://ui/keys.gd")

const DESIGN := Vector2(1280, 800)

var levels: Array = []
var progress
var stage: Control
var screen: Control
var select_page := 0  # the level select's chapter page
var stale := false  # the save doesn't fit this build and the player hasn't chosen yet
var unlock_all := false
var throwaway := false  # screenshot mode: never write the real save


func _ready() -> void:
	levels = Level.load_all()
	var saved = Progress.read()
	var problems: Array = [] if saved == null else Progress.problems(saved, levels)
	if not problems.is_empty():
		print("The save doesn't fit this build: " + "; ".join(problems))
	stale = not problems.is_empty()
	# Only what still fits the levels is loaded (the intro asks about the rest).
	progress = Progress.from_dict(saved, levels) if saved is Dictionary else Progress.new()
	var args := _args()
	unlock_all = args.has("unlock-all")
	progress.unlock_all = unlock_all
	stage = Control.new()
	stage.size = DESIGN
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	resized.connect(_center)
	_center()
	if args.has("screenshot"):
		_screenshot(args)
		return
	Keys.load_settings()  # not for screenshots: they show the default keys
	# The intro opens every launch; jumping straight into a level skips it
	# unless the save needs an answer.
	if stale or not args.has("level"):
		show_intro()
	else:
		_start()


## The first screen after the intro: the level asked for, or the level select.
func _start() -> void:
	select_page = _first_open_chapter()
	var start := _level_index(str(_args().get("level", "")))
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


## The chapter of the first level that is open and not yet solved.
func _first_open_chapter() -> int:
	var ids := levels.map(func(l): return l.id)
	for i in levels.size():
		if progress.is_unlocked(ids, i) and not progress.is_solved(ids[i]):
			return levels[i].chapter
	return 0


func _center() -> void:
	stage.position = ((size - DESIGN) / 2).floor()
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(P.paper_texture(), Rect2(Vector2.ZERO, size), true)


## Sees every event first: shows or hides the key hints (keys.gd).
func _input(event: InputEvent) -> void:
	if Keys.watch(event, get_tree()):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# A stale save stays as it is until the player chooses.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and progress != null and not stale:
		_save()


func _save() -> void:
	if not throwaway:
		progress.save()


func _set_screen(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	stage.add_child(c)


func show_intro() -> void:
	var s = Intro.new()
	s.stale = stale
	s.done.connect(_start)
	s.fresh.connect(func(): _settle_save(true))
	s.keep.connect(func(): _settle_save(false))
	_set_screen(s)


## The player's answer about a stale save: the old file moves to a .bak, then
## a fresh save, or the parts that still fit, take its place.
func _settle_save(fresh: bool) -> void:
	Progress.back_up()
	if fresh:
		progress = Progress.new()
		progress.unlock_all = unlock_all
	stale = false
	progress.save()
	_start()


func show_level_select() -> void:
	var s = LevelSelect.new()
	s.setup(levels, progress, select_page)
	s.level_chosen.connect(open_level)
	s.book_requested.connect(show_book)
	s.options_requested.connect(show_options)
	s.page_changed.connect(func(c): select_page = c)
	_set_screen(s)


func show_book() -> void:
	var b = PatternBook.new()
	b.setup(levels, progress)
	b.back.connect(show_level_select)
	_set_screen(b)


func show_options() -> void:
	var o = Options.new()
	o.back.connect(show_level_select)
	_set_screen(o)


func open_level(i: int) -> void:
	select_page = levels[i].chapter
	var w = Workbench.new()
	w.setup(levels[i], progress, i + 1 < levels.size())
	w.exit_requested.connect(func():
		_save()
		show_level_select())
	w.next_requested.connect(func():
		_save()
		open_level(i + 1))
	w.progress_changed.connect(func(): _save())
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
	throwaway = true
	progress = Progress.new()
	progress.unlock_all = args.has("unlock-all")
	Keys.grid = args.has("grid")
	if args.has("touch"):  # as on a phone: no keyboard, no key labels
		Keys.keyboard = false
		Keys.shown = false
	for level in levels:
		if not level.invention.is_empty():
			progress.inventions[level.invention["id"]] = Invention.package(level, level.reference_machine(), progress.inventions)
	match what:
		"levels":
			for k in 6:
				progress.record_solve(levels[k].id, levels[k].best + (k % 2), 40 + k, 3 - (k % 2))
			select_page = int(args.get("page", 0))
			show_level_select()
		"book":
			if args.has("empty"):
				progress.inventions = {}
			show_book()
		"intro":
			stale = args.has("stale")
			show_intro()
		"options":
			show_options()
		_:
			var i := _level_index(what)
			if i < 0:
				printerr("unknown level: " + what)
				get_tree().quit(1)
				return
			open_level(i)
			if args.has("empty"):
				screen.load_machine(levels[i].new_machine())
			elif args.has("wrong"):
				screen.load_machine(levels[i].machine_from_spec({"pieces": [], "tubes": [["card0", "loom"]]}))
			else:
				screen.load_machine(levels[i].reference_machine())
			screen.frozen = true
			screen.clock = 3.3
			if args.has("finish") or args.has("wrong"):
				screen.fast_forward(1000000, 1.0)
				screen._on_tick_shown()
				if screen.panel != null:
					screen.panel.t = 3.0
			else:
				screen.fast_forward(int(args.get("ticks", levels[i].size())), float(args.get("phase", 0.5)))
	for n in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("screenshot %s -> %s (%s)" % [what, path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
