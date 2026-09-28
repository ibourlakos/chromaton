## Runs every tests/test_*.gd script, each in its own Godot process.
## Run: godot_console --headless --path . --script res://tests/test_all.gd
extends SceneTree


func _init() -> void:
	var failed := []
	var names := Array(DirAccess.get_files_at("res://tests")).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd") and f != "test_all.gd")
	names.sort()
	for file in names:
		var out := []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/" + file], out, true)
		var text := "".join(out).strip_edges()
		var lines := Array(text.split("\n")).filter(func(l): return not l.begins_with("Godot Engine") and l.strip_edges() != "")
		print("\n".join(lines))
		if code != 0:
			failed.append(file)
	if failed.is_empty():
		print("test_all: %d test scripts passed" % names.size())
	else:
		printerr("test_all: FAILED " + ", ".join(failed))
	quit(1 if failed.size() > 0 else 0)
