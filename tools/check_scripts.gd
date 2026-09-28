## Compiles every GDScript file in the project and reports parse errors
## with line numbers (handy when a dependent script only says "failed").
## Run: godot_console --headless --path . --script res://tools/check_scripts.gd
extends SceneTree


func _init() -> void:
	var bad := 0
	for dir in ["res://core", "res://ui", "res://tests", "res://tools"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var path: String = dir + "/" + file
			var script := GDScript.new()
			script.source_code = FileAccess.get_file_as_string(path)
			if script.reload() != OK:
				bad += 1
				printerr("cannot compile " + path)
	print("check_scripts: %s" % ("all scripts compile" if bad == 0 else "%d script(s) failed" % bad))
	quit(1 if bad > 0 else 0)
