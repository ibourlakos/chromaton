## Local profiles (DESIGN.md 9): a profile is a save slot with a critter
## badge (tapped from the critters, no reading needed) and an optional name
## that defaults to the critter's. Each has its own save file; the first is
## the save that was there before profiles (user://chromaton_save.json),
## untouched. Settings stay per device (keys and speed belong to the
## keyboard and screen). The anonymous, local, offline mode: nothing leaves
## the device.
##
## Stored in user://chromaton_profiles.json:
##   {"profiles": [{"id": 1, "badge": "mix", "name": ""}, ...], "current": 1}
## Without the file there is one profile, the first.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")
const Progress = preload("res://core/progress.gd")

const PATH := "user://chromaton_profiles.json"
## The critters a badge can be, by piece kind.
const BADGES := ["mix", "shift", "red_pot", "filter", "invert"]

var list: Array = []  # [{"id": int, "badge": String, "name": String}]
var current := 1


static func load_from(path := PATH):
	var p = load("res://core/profiles.gd").new()
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if d is Dictionary and d.get("profiles") is Array:
		for e in d["profiles"]:
			if e is Dictionary and (e.get("id") is float or e.get("id") is int):
				var badge := str(e.get("badge", "mix"))
				p.list.append({"id": int(e["id"]), "badge": badge if badge in BADGES else "mix", "name": str(e.get("name", ""))})
		p.current = int(d.get("current", 1))
	if p.list.is_empty():
		p.list.append({"id": 1, "badge": "mix", "name": ""})
	if p.find(p.current).is_empty():
		p.current = p.list[0]["id"]
	return p


func save(path := PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"profiles": list, "current": current}, "\t"))


func find(id: int) -> Dictionary:
	for e in list:
		if e["id"] == id:
			return e
	return {}


## A new profile with this badge and name ("" for the critter's); returns
## its id.
func add(badge: String, name := "") -> int:
	var id := 1
	for e in list:
		id = maxi(id, int(e["id"]) + 1)
	list.append({"id": id, "badge": badge, "name": name.strip_edges()})
	return id


## Gives a profile another badge and name ("" for the critter's).
func edit(id: int, badge: String, name := "") -> void:
	var e := find(id)
	if not e.is_empty():
		e["badge"] = badge if badge in BADGES else "mix"
		e["name"] = name.strip_edges()


## The profile's save file: the first keeps the save from before profiles.
static func save_path(id: int) -> String:
	return Progress.PATH if id == 1 else "user://chromaton_save_%d.json" % id


## What the profile is called: its name, or its critter's.
static func display_name(e: Dictionary) -> String:
	return str(e.get("name", "")) if str(e.get("name", "")) != "" else Pieces.display_name(str(e.get("badge", "mix")))
