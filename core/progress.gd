## Saved progress: solved levels, best metrics, the player's machines and
## their inventions. Stored as JSON in user://chromaton_save.json:
##
##   {
##     "version": 3,
##     "levels": {                        level id (levels/<id>.json) -> record
##       "<level id>": {
##         "solved": true,                these four only once solved
##         "stars": 3,
##         "best_pieces": 4,
##         "best_ticks": 39,
##         "machine": {...}               the bench as left (any level opened)
##       }
##     },
##     "inventions": {                    invention id -> packaged machine
##       "<invention id>": {"id", "name", "check", "inputs", "cost",
##                          "counts": {piece kind: n}, "machine": {...},
##                          "from_level": level id}   (core/invention.gd)
##     },
##     "seen": {                          piece kind -> what the player's own
##       "invert": [0, 1, ...],           machines have shown it doing: the
##       "mix": [9, ...]                  journal's Pieces frames (seen_key)
##     }
##   }
##
## A machine is {"nodes": [{"id", "kind", "x", "y", "card" or
## "invention"}], "tubes": [{"from", "fp", "to", "tp"}], "next_id"}
## (core/machine.gd).
##
## A save is stale when it was written by another version or no longer fits
## the levels (see problems()): the game says so at launch and offers to
## start fresh, moving the old file to a .bak beside it (back_up()).
extends RefCounted

const PATH := "user://chromaton_save.json"
const VERSION := 3
const Machine = preload("res://core/machine.gd")
const Pieces = preload("res://core/pieces.gd")
const RECORD_KEYS := ["stars", "best_pieces", "best_ticks"]
const INVENTION_KEYS := ["id", "name", "check", "inputs", "cost", "counts", "machine", "from_level"]
## The pieces whose every-paint behaviour the journal collects, frame by frame.
const LEARNABLE := ["shift", "invert", "mix", "filter"]

## level id -> {"solved": bool, "stars": int, "best_pieces": int, "best_ticks": int, "machine": Dictionary}
var levels := {}
## invention id -> invention (see core/invention.gd)
var inventions := {}
## piece kind -> {seen_key: true}: what the player's machines have shown each
## learnable piece doing, in any run (the journal's Pieces frames)
var seen := {}
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


## Stores a newly packaged invention and returns the one kept: the cheaper
## machine wins, so going back for a cheaper solve lowers the price, and a
## second level that earns the same invention (the Black pot, Same Paint)
## replaces it only if its machine is cheaper. A tie takes the newest.
func add_invention(inv: Dictionary) -> Dictionary:
	var old: Dictionary = inventions.get(inv["id"], {})
	if not old.is_empty() and int(old["cost"]) < int(inv["cost"]):
		return old
	inventions[inv["id"]] = inv
	return inv


## The frame a piece firing on these input paints fills: the paint itself for
## a one-input piece; for Mix and Filter, which don't care about order, the
## pair as smaller + 8 × larger.
static func seen_key(colors: Array) -> int:
	if colors.size() == 1:
		return colors[0]
	return mini(colors[0], colors[1]) + 8 * maxi(colors[0], colors[1])


## Records a piece firing on these input paints; true if the player hadn't
## seen it do that before.
func learn(kind: String, colors: Array) -> bool:
	if not kind in LEARNABLE:
		return false
	var key := seen_key(colors)
	var known: Dictionary = seen.get(kind, {})
	if known.has(key):
		return false
	known[key] = true
	seen[kind] = known
	return true


func knows(kind: String, colors: Array) -> bool:
	return seen.get(kind, {}).has(seen_key(colors))


func store_machine(level_id: String, machine_dict: Dictionary) -> void:
	var rec: Dictionary = levels.get(level_id, {})
	rec["machine"] = machine_dict
	levels[level_id] = rec


func stored_machine(level_id: String) -> Dictionary:
	return levels.get(level_id, {}).get("machine", {})


func to_dict() -> Dictionary:
	var seen_lists := {}
	for kind in seen:
		var keys: Array = seen[kind].keys()
		keys.sort()
		seen_lists[kind] = keys
	return {"version": VERSION, "levels": levels, "inventions": inventions, "seen": seen_lists}


## Builds progress from saved data. Given the levels, it keeps only the
## records and inventions that still fit them (see problems()).
static func from_dict(d: Dictionary, levels := []):
	var p = load("res://core/progress.gd").new()
	var lv: Dictionary = _dict(d.get("levels"))
	var inv: Dictionary = _dict(d.get("inventions"))
	if not levels.is_empty():
		var by_id := _by_id(levels)
		inv = inv.duplicate()
		var dropped := true
		while dropped:  # an invention may be built from one that was dropped
			dropped = false
			for id in inv.keys():
				if not _invention_problems(id, inv[id], by_id, inv).is_empty():
					inv.erase(id)
					dropped = true
		lv = lv.duplicate()
		for id in lv.keys():
			if not _record_problems(id, lv[id], by_id, inv).is_empty():
				lv.erase(id)
	for id in lv:
		var rec: Dictionary = lv[id].duplicate(true)
		for k in ["stars", "best_pieces", "best_ticks"]:
			if rec.has(k):
				rec[k] = int(rec[k])
		if rec.has("machine"):
			rec["machine"] = Machine.from_dict(rec["machine"]).to_dict()
		p.levels[str(id)] = rec
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
	var seen_in: Dictionary = _dict(d.get("seen"))
	for kind in seen_in:
		if kind in LEARNABLE and seen_in[kind] is Array:
			var known := {}
			for k in seen_in[kind]:
				if _is_number(k) and int(k) >= 0 and int(k) < 64:
					known[int(k)] = true
			p.seen[str(kind)] = known
	return p


func save(path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write save file " + path)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


static func load_from(path := PATH, levels := []):
	var d = read(path)
	return from_dict(d, levels) if d is Dictionary else load("res://core/progress.gd").new()


## A save file's data: null when there is no file, else the parsed JSON (the
## text itself when it isn't JSON).
static func read(path := PATH) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	var d = JSON.parse_string(text)
	return d if d != null else text


## Moves a save file aside to <path>.bak (or .2.bak, .3.bak... so an older
## backup is never overwritten). Returns the backup's path, "" on failure.
static func back_up(path := PATH) -> String:
	var to := path + ".bak"
	var n := 2
	while FileAccess.file_exists(to):
		to = "%s.%d.bak" % [path, n]
		n += 1
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(to))
	return to if err == OK else ""


# ---------------------------------------------------------------------------
# Staleness
# ---------------------------------------------------------------------------

## Why saved data doesn't fit this build: another version, missing keys,
## unknown level or invention ids, machines with pieces their level doesn't
## offer. Empty when it fits. The reasons are for the log and tests; the
## player only hears that the save is from an older build.
static func problems(d, levels: Array) -> Array:
	if not d is Dictionary:
		return ["the file is not a save"]
	var out := []
	for k in ["version", "levels", "inventions", "seen"]:
		if not d.has(k):
			out.append("missing \"%s\"" % k)
	if d.has("version") and not (_is_number(d["version"]) and int(d["version"]) == VERSION):
		out.append("version %s, this build writes %d" % [str(d["version"]), VERSION])
	for k in ["levels", "inventions", "seen"]:
		if d.has(k) and not d[k] is Dictionary:
			out.append("\"%s\" is not a table" % k)
	var by_id := _by_id(levels)
	var inv := _dict(d.get("inventions"))
	for id in inv:
		out.append_array(_invention_problems(id, inv[id], by_id, inv))
	var lv := _dict(d.get("levels"))
	for id in lv:
		out.append_array(_record_problems(id, lv[id], by_id, inv))
	return out


static func _record_problems(id, rec, by_id: Dictionary, inventions: Dictionary) -> Array:
	if not by_id.has(id):
		return ["unknown level \"%s\"" % id]
	if not rec is Dictionary:
		return ["level %s: not a record" % id]
	var out := []
	if rec.get("solved", false):
		for k in RECORD_KEYS:
			if not _is_number(rec.get(k)):
				out.append("level %s: solved without \"%s\"" % [id, k])
	if rec.has("machine"):
		for p in _machine_problems(rec["machine"], by_id[id], inventions):
			out.append("level %s: %s" % [id, p])
	return out


static func _invention_problems(id, inv, by_id: Dictionary, inventions: Dictionary) -> Array:
	if not inv is Dictionary:
		return ["invention %s: not a record" % id]
	for k in INVENTION_KEYS:
		if not inv.has(k):
			return ["invention %s: missing \"%s\"" % [id, k]]
	var level = by_id.get(str(inv["from_level"]))  # one of the levels that earn it
	if level == null or level.invention.get("id", "") != id or inv["id"] != id:
		return ["unknown invention \"%s\"" % id]
	if not (_is_number(inv["inputs"]) and _is_number(inv["cost"]) and inv["counts"] is Dictionary):
		return ["invention %s: bad ports, price or counts" % id]
	var out := []
	for p in _machine_problems(inv["machine"], level, inventions):
		out.append("invention %s: %s" % [id, p])
	return out


## Whether a saved machine could be on this level's bench: its pieces are
## offered, its cards exist, its inventions are allowed and saved, and its
## tubes join pieces that are there.
static func _machine_problems(m, level, inventions: Dictionary) -> Array:
	if not (m is Dictionary and m.get("nodes") is Array and m.get("tubes") is Array):
		return ["machine without nodes or tubes"]
	var out := []
	var ids := {}
	for n in m["nodes"]:
		if not (n is Dictionary and _is_number(n.get("id")) and n.get("kind") is String):
			return ["a piece without an id or kind"]
		ids[int(n["id"])] = true
		var kind: String = n["kind"]
		match kind:
			Pieces.LOOM:
				pass
			Pieces.CARD:
				if not (_is_number(n.get("card")) and int(n["card"]) < level.cards.size()):
					out.append("a card the level doesn't have")
			Pieces.INVENTION:
				var inv_id := str(n.get("invention", ""))
				if not level.offers_invention(inv_id):
					out.append("invention %s isn't offered" % inv_id)
				elif not inventions.has(inv_id):
					out.append("invention %s isn't saved" % inv_id)
			_:
				if not kind in level.pieces:
					out.append("piece %s isn't offered" % kind)
	for t in m["tubes"]:
		var ok: bool = t is Dictionary
		for k in ["from", "fp", "to", "tp"]:
			ok = ok and _is_number(t.get(k))
		if not ok or not ids.has(int(t["from"])) or not ids.has(int(t["to"])):
			out.append("a tube to a missing piece")
	return out


static func _is_number(v) -> bool:
	return v is int or v is float


static func _dict(v) -> Dictionary:
	return v if v is Dictionary else {}


static func _by_id(levels: Array) -> Dictionary:
	var out := {}
	for level in levels:
		out[level.id] = level
	return out
