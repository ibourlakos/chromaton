## Saved progress: solved levels, best metrics, the player's machines and
## their inventions. Stored as JSON in user://.
extends RefCounted

const PATH := "user://chromaton_save.json"
const VERSION := 1
const Machine = preload("res://core/machine.gd")

## level id -> {"solved": bool, "stars": int, "best_pieces": int, "best_ticks": int, "machine": Dictionary}
var levels := {}
## invention id -> invention (see core/invention.gd)
var inventions := {}
var unlock_all := false


func level_record(level_id: String) -> Dictionary:
	return levels.get(level_id, {})


func is_solved(level_id: String) -> bool:
	return bool(levels.get(level_id, {}).get("solved", false))


func stars(level_id: String) -> int:
	return int(levels.get(level_id, {}).get("stars", 0))


## A level is open once either of the two levels before it is solved, so one
## hard level never walls off the rest of the campaign.
func is_unlocked(level_ids: Array, index: int) -> bool:
	return unlock_all or index == 0 or is_solved(level_ids[index - 1]) or (index >= 2 and is_solved(level_ids[index - 2]))


## Records a solve. Returns which metrics improved: {"pieces": bool, "ticks": bool, "stars": bool}.
func record_solve(level_id: String, pieces: int, ticks: int, star_count: int) -> Dictionary:
	var rec: Dictionary = levels.get(level_id, {})
	var first: bool = not rec.get("solved", false)
	var better := {
		"pieces": first or pieces < int(rec.get("best_pieces", 0)),
		"ticks": first or ticks < int(rec.get("best_ticks", 0)),
		"stars": star_count > int(rec.get("stars", 0)),
	}
	rec["solved"] = true
	if better["pieces"]:
		rec["best_pieces"] = pieces
	if better["ticks"]:
		rec["best_ticks"] = ticks
	if better["stars"]:
		rec["stars"] = star_count
	levels[level_id] = rec
	return better


## Stores a newly packaged invention and returns the one kept. A pot keeps
## the cheapest price the player has made it for; other inventions take the
## newest machine.
func add_invention(inv: Dictionary) -> Dictionary:
	var old: Dictionary = inventions.get(inv["id"], {})
	var is_pot := str(inv.get("check", "")).begins_with("paint:")
	if is_pot and not old.is_empty() and int(old["cost"]) <= int(inv["cost"]):
		return old
	inventions[inv["id"]] = inv
	return inv


func store_machine(level_id: String, machine_dict: Dictionary) -> void:
	var rec: Dictionary = levels.get(level_id, {})
	rec["machine"] = machine_dict
	levels[level_id] = rec


func stored_machine(level_id: String) -> Dictionary:
	return levels.get(level_id, {}).get("machine", {})


func to_dict() -> Dictionary:
	return {"version": VERSION, "levels": levels, "inventions": inventions}


static func from_dict(d: Dictionary):
	var p = load("res://core/progress.gd").new()
	var lv: Dictionary = d.get("levels", {})
	for id in lv:
		var rec: Dictionary = lv[id].duplicate(true)
		for k in ["stars", "best_pieces", "best_ticks"]:
			if rec.has(k):
				rec[k] = int(rec[k])
		if rec.has("machine"):
			rec["machine"] = Machine.from_dict(rec["machine"]).to_dict()
		p.levels[str(id)] = rec
	var inv: Dictionary = d.get("inventions", {})
	for id in inv:
		var e: Dictionary = inv[id].duplicate(true)
		e["inputs"] = int(e.get("inputs", 0))
		e["cost"] = int(e.get("cost", 0))
		var counts := {}
		for k in e.get("counts", {}):
			counts[k] = int(e["counts"][k])
		e["counts"] = counts
		e["machine"] = Machine.from_dict(e.get("machine", {})).to_dict()
		p.inventions[str(id)] = e
	return p


func save(path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write save file " + path)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


static func load_from(path := PATH):
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				return from_dict(d)
	return load("res://core/progress.gd").new()
