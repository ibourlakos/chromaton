## Runs every tests/test_*.gd script, each in its own Godot process.
## Run: godot_console --headless --path . --script res://tests/test_all.gd [-- sim ...]
## Names after "--" run only those suites (test_sim.gd, ...).
##
## Suites do all their work in _init and quit there. One whose _init stops on
## a runtime error would idle forever, so each runs with --quit-after 2.
## A suite fails if it exits non-zero or prints a GDScript error: a script
## that fails to compile or hits a runtime error can still exit 0.
extends SceneTree


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	var failed := []
	var names := Array(DirAccess.get_files_at("res://tests")).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_all.gd")
	if not only.is_empty():
		names = names.filter(func(f): return f.trim_prefix("test_").trim_suffix(".gd") in only)
		if names.size() != only.size():
			printerr("test_all: unknown suite in %s" % str(only))
			quit(1)
			return
	names.sort()
	for file in names:
		var out := []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--quit-after", "2", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/" + file], out, true)
		var text := "".join(out).strip_edges()
		var lines := Array(text.split("\n")).filter(func(l): return not l.begins_with("Godot Engine") and l.strip_edges() != "")
		print("\n".join(lines))
		if code != 0:
			failed.append(file)
		elif text.contains("SCRIPT ERROR") or text.contains("ERROR:"):
			printerr("%s printed errors, so it counts as failed" % file)
			failed.append(file)
	if failed.is_empty():
		print("test_all: %d test scripts passed" % names.size())
	else:
		printerr("test_all: FAILED " + ", ".join(failed))
	quit(1 if failed.size() > 0 else 0)
