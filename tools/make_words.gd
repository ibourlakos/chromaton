## Writes data/words.json, the journal's Words tab, from the lexicon's
## gameplay terms (tools/lexicon.gd). Rerun after editing docs/lexicon/.
##
## Run from the project folder:
##   godot_console --headless --path . --script res://tools/make_words.gd
## Exits with code 1 if a gameplay term can't be read (no level named, no
## Gameplay paragraph), and writes nothing then.
extends SceneTree

const Level = preload("res://core/level.gd")
const Lexicon = preload("res://tools/lexicon.gd")


func _init() -> void:
	var built := Lexicon.build(Level.load_all())
	for e in built["errors"]:
		printerr(e)
	if not built["errors"].is_empty():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Lexicon.OUT.get_base_dir()))
	var f := FileAccess.open(Lexicon.OUT, FileAccess.WRITE)
	if f == null:
		printerr("cannot write " + Lexicon.OUT)
		quit(1)
		return
	f.store_string(Lexicon.to_json(built["words"]))
	f.close()
	for w in built["words"]:
		print("%-12s %-22s %s" % [w["tab"], w["word"], w["level"]])
	print("%d words -> %s" % [built["words"].size(), Lexicon.OUT])
	quit(0)
