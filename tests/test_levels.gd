## Tests for level loading, every level's reference solution, wrong
## solutions, stars and saved progress.
## Run: godot_console --headless --path . --script res://tests/test_levels.gd
extends SceneTree

const Paint = preload("res://core/paint.gd")
const Pieces = preload("res://core/pieces.gd")
const Level = preload("res://core/level.gd")
const Simulator = preload("res://core/simulator.gd")
const Invention = preload("res://core/invention.gd")
const Progress = preload("res://core/progress.gd")

const S = Simulator.Status

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func _init() -> void:
	var levels := Level.load_all()
	test_loading(levels)
	var inventions := reference_inventions(levels)
	test_references(levels, inventions)
	test_wrong_solutions(levels)
	test_stars(levels)
	test_progress(levels)
	test_stale_saves(levels, inventions)
	if failures == 0:
		print("test_levels: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


## Each invention level's reference solution, packaged the way a player's would be.
func reference_inventions(levels: Array) -> Dictionary:
	var inventions := {}
	for level in levels:
		if not level.invention.is_empty():
			inventions[level.invention["id"]] = Invention.package(level, level.reference_machine(), inventions)
	return inventions


func test_loading(levels: Array) -> void:
	check(levels.size() == 33, "thirty-three campaign levels (got %d)" % levels.size())
	check(Level.chapters().map(func(c): return c["levels"].size()) == [9, 12, 6, 6], "four chapters of 9, 12, 6 and 6 levels, each quilt full")
	var ids := {}
	for level in levels:
		check(level.error == "", "level loads cleanly: %s %s" % [level.id, level.error])
		check(not ids.has(level.id), "unique level id " + level.id)
		ids[level.id] = true
		check(level.name != "" and level.goal != "", "%s has a name and goal" % level.id)
		check(level.size() == level.cols * level.rows and level.size() > 0, "%s target is a full picture" % level.id)
		for card in level.cards:
			check(card.size() == level.size(), "%s cards cover every stitch" % level.id)
		check(level.card_names.size() == level.cards.size(), "%s names its cards" % level.id)
		for kind in level.pieces:
			check(Pieces.is_piece(kind), "%s offers a known piece %s" % [level.id, kind])
		check(level.budget >= level.best and (level.best > 0 or level.pieces.is_empty()), "%s star thresholds make sense" % level.id)
		check(level.number == ids.size(), "%s is numbered by its place in the campaign" % level.id)
		check(not level.reference.is_empty(), "%s has a reference solution" % level.id)
		for p in level.reference.get("pieces", []):
			check(p["kind"] == Pieces.INVENTION or p["kind"] in level.pieces, "%s reference uses only offered pieces (%s)" % [level.id, p["kind"]])
			check(p.get("invention", "") == "" or level.offers_invention(p["invention"]), "%s reference uses an offered invention" % level.id)
	check(Level.parse_rows(["WRYOBPGK"]) == PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7]), "color letters")
	check(Level.letters(PackedByteArray([1, 2, 3, 4]), 2) == ["RY", "OB"], "letters round trip")
	var smudgy = levels.filter(func(l): return l.id == "smudges")[0]
	var stray := range(smudgy.size()).filter(func(i): return smudgy.cards[0][i] != smudgy.target[i])
	check(smudgy.smudges[0] == stray and stray.any(func(i): return i < smudgy.cols), "Smudges marks exactly its stray stitches, some in the first row")
	var inv_levels := levels.filter(func(l): return not l.invention.is_empty())
	var pot_ids := inv_levels.filter(func(l): return l.chapter == 0).map(func(l): return l.invention["id"])
	check(pot_ids == ["pot_yellow", "pot_blue", "pot_orange", "pot_purple", "pot_black", "pot_green", "pot_black", "pot_white"], "paint-box levels 2 to 9 each earn a pot, black twice (%s)" % str(pot_ids))
	var others := inv_levels.filter(func(l): return l.chapter > 0).map(func(l): return l.invention["id"])
	check(others == ["third_paint", "contrast", "same_paint", "missing_from_either", "same_paint"], "the inventions after the paint box, Same Paint twice (%s)" % str(others))
	test_pots_in_trays(levels)


func test_references(levels: Array, inventions: Dictionary) -> void:
	for level in levels:
		var m = level.reference_machine()
		var sim := Simulator.new(m, level.cards, level.target, inventions)
		sim.run()
		check(sim.status == S.SOLVED, "%s: reference solution solves it (status %d at stitch %d)" % [level.id, sim.status, sim.wrong_index])
		check(sim.woven == level.target, "%s: woven cloth equals the target" % level.id)
		var cost: int = m.cost(inventions)
		check(cost == level.best, "%s: reference sets the three-star count (%d vs %d)" % [level.id, cost, level.best])
		check(level.stars_for(cost) == 3, "%s: reference earns three stars" % level.id)
		check(sim.tick > level.size(), "%s: at most one stitch per tick" % level.id)


## Evaluates a small formula on one stitch's card colors.
func formula(f: String, a: int, b: int, c: int) -> int:
	match f:
		"A":
			return a
		"B":
			return b
		"red_shift":
			return Paint.shift(Paint.RED)
		"bleach_swapped":
			return Paint.bleach(b, a)
		"mix_ab":
			return Paint.mix(a, b)
		"shift_a":
			return Paint.shift(a)
		"flower_half":
			return Paint.mix(Paint.filter(a, b), c)
	return -1


func test_wrong_solutions(levels: Array) -> void:
	var by_id := {}
	for level in levels:
		by_id[level.id] = level
	var cases := [
		# level, wrong machine, formula it computes
		["one_pot", {"pieces": [{"id": "p", "kind": "red_pot", "x": 0, "y": 0}, {"id": "h", "kind": "shift", "x": 0, "y": 1}], "tubes": [["p", "h"], ["h", "loom"]]}, "red_shift"],
		["orange_sun", {"pieces": [], "tubes": [["card0", "loom"]]}, "A"],
		["green", {"pieces": [{"id": "p", "kind": "red_pot", "x": 0, "y": 0}, {"id": "h", "kind": "shift", "x": 0, "y": 1}], "tubes": [["p", "h"], ["h", "loom"]]}, "red_shift"],
		["third_color", {"pieces": [{"id": "m", "kind": "mix", "x": 0, "y": 0}], "tubes": [["card0", "m.0"], ["card1", "m.1"], ["m", "loom"]]}, "mix_ab"],
		["keep_what_they_share", {"pieces": [{"id": "c", "kind": "catch_pot", "x": 0, "y": 0}], "tubes": [["card1", "loom"], ["card0", "c"]]}, "B"],
		["wash_out", {"pieces": [
			{"id": "ia", "kind": "invert", "x": 0, "y": 0}, {"id": "m", "kind": "mix", "x": 0, "y": 1}, {"id": "o", "kind": "invert", "x": 0, "y": 2}],
			"tubes": [["card1", "ia"], ["ia", "m.0"], ["card0", "m.1"], ["m", "o"], ["o", "loom"]]}, "bleach_swapped"],
		["the_flower", {"pieces": [{"id": "f", "kind": "filter", "x": 0, "y": 0}, {"id": "m", "kind": "mix", "x": 0, "y": 1}],
			"tubes": [["card0", "f.0"], ["card1", "f.1"], ["f", "m.0"], ["card2", "m.1"], ["m", "loom"]]}, "flower_half"],
		["opposites", {"pieces": [{"id": "h", "kind": "shift", "x": 0, "y": 0}], "tubes": [["card0", "h"], ["h", "loom"]]}, "shift_a"],
		["smudges", {"pieces": [], "tubes": [["card0", "loom"]]}, "A"],
		["missing_from_either", {"pieces": [{"id": "m", "kind": "mix", "x": 0, "y": 0}], "tubes": [["card0", "m.0"], ["card1", "m.1"], ["m", "loom"]]}, "mix_ab"],
		["either_not_both", {"pieces": [{"id": "m", "kind": "mix", "x": 0, "y": 0}], "tubes": [["card0", "m.0"], ["card1", "m.1"], ["m", "loom"]]}, "mix_ab"],
	]
	for case in cases:
		var level = by_id[case[0]]
		var expect := -1
		for i in level.size():
			var col := []
			for k in 3:
				col.append(level.cards[k][i] if k < level.cards.size() else 0)
			if formula(case[2], col[0], col[1], col[2]) != level.target[i]:
				expect = i
				break
		check(expect >= 0, "%s: the wrong machine really is wrong somewhere" % level.id)
		var sim := Simulator.new(level.machine_from_spec(case[1]), level.cards, level.target)
		sim.run()
		check(sim.status == S.WRONG, "%s: wrong machine is rejected (status %d)" % [level.id, sim.status])
		check(sim.wrong_index == expect, "%s: rejected at stitch %d (expected %d)" % [level.id, sim.wrong_index, expect])
		check(sim.woven.size() == expect + 1, "%s: weaving stops at the wrong stitch" % level.id)


func test_stars(levels: Array) -> void:
	for level in levels:
		check(level.stars_for(level.best) == 3, "%s: best is three stars" % level.id)
		check(level.stars_for(level.budget) == (3 if level.budget == level.best else 2), "%s: budget is two stars" % level.id)
		check(level.stars_for(level.budget + 1) == 1, "%s: over budget is one star" % level.id)


func test_progress(levels: Array) -> void:
	var ids := levels.map(func(l): return l.id)
	var p = Progress.new()
	check(p.is_unlocked(ids, 0) and not p.is_unlocked(ids, 1), "only the first level starts open")
	var better: Dictionary = p.record_solve(ids[0], 3, 40, 2)
	check(better["pieces"] and better["ticks"] and better["stars"], "first solve sets every record")
	check(p.is_unlocked(ids, 1) and p.is_unlocked(ids, 2) and not p.is_unlocked(ids, 3), "solving a level opens the next two")
	check(Level.index_ids() == ids, "the index lists every level in campaign order")
	var chapters := Level.chapters()
	check(chapters.size() >= 2 and levels[0].chapter == 0 and levels[levels.size() - 1].chapter == chapters.size() - 1, "levels know their chapter")
	better = p.record_solve(ids[0], 4, 30, 1)
	check(not better["pieces"] and better["ticks"] and not better["stars"], "records only improve")
	var rec: Dictionary = p.level_record(ids[0])
	check(rec["best_pieces"] == 3 and rec["best_ticks"] == 30 and rec["stars"] == 2, "best pieces and ticks kept separately")

	var inv_level = levels.filter(func(l): return l.id == "either_not_both")[0]
	p.inventions["contrast"] = Invention.package(inv_level, inv_level.reference_machine(), {})
	p.store_machine(inv_level.id, inv_level.reference_machine().to_dict())
	var path := "user://test_progress.json"
	check(p.save(path), "progress saves")
	var q = Progress.load_from(path)
	check(q.to_dict() == p.to_dict(), "progress loads back the same")
	check(q.inventions["contrast"]["cost"] == 4 and q.inventions["contrast"]["inputs"] == 2, "saved invention keeps its ports and price")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var fresh = Progress.load_from("user://no_such_save.json")
	check(fresh.levels.is_empty(), "a missing save starts fresh")


## A save that no longer fits the levels is stale; loading keeps only what
## fits, and the old file moves aside to a .bak instead of being deleted.
func test_stale_saves(levels: Array, inventions: Dictionary) -> void:
	var full = Progress.new()
	full.inventions = inventions.duplicate(true)
	for level in levels:
		full.record_solve(level.id, level.best, 50, 3)
		full.store_machine(level.id, level.reference_machine().to_dict())
	var good: Dictionary = JSON.parse_string(JSON.stringify(full.to_dict()))
	var found: Array = Progress.problems(good, levels)
	check(found.is_empty(), "a save of every reference machine fits: %s" % str(found))
	check(Progress.from_dict(good, levels).to_dict() == full.to_dict(), "a fitting save loads whole")

	var bad := good.duplicate(true)
	bad["version"] = Progress.VERSION + 1
	check(not Progress.problems(bad, levels).is_empty(), "another version is stale")
	bad = good.duplicate(true)
	bad.erase("inventions")
	check(not Progress.problems(bad, levels).is_empty(), "a missing key is stale")
	check(not Progress.problems("not json", levels).is_empty() and not Progress.problems([], levels).is_empty(), "a file that isn't a save is stale")

	bad = good.duplicate(true)
	bad["levels"]["no_such_level"] = bad["levels"]["one_pot"].duplicate(true)
	check(not Progress.problems(bad, levels).is_empty(), "an unknown level id is stale")
	var kept = Progress.from_dict(bad, levels)
	check(not kept.levels.has("no_such_level") and kept.levels.has("one_pot"), "loading drops the unknown level and keeps the rest")

	bad = good.duplicate(true)
	bad["levels"]["one_pot"]["machine"]["nodes"].append({"id": 99, "kind": "filter", "x": 5, "y": 5})
	check(not Progress.problems(bad, levels).is_empty(), "a machine with a piece the level doesn't offer is stale")
	check(not Progress.from_dict(bad, levels).levels.has("one_pot"), "loading drops that level's record")

	bad = good.duplicate(true)
	bad["levels"]["one_pot"].erase("stars")
	check(not Progress.problems(bad, levels).is_empty(), "a solved level without its stars is stale")

	# An invention on the bench needs the level to offer it and the save to hold it.
	var host = levels.filter(func(l): return l.id == "third_color")[0]
	host.inventions.append("contrast")
	bad = good.duplicate(true)
	bad["levels"]["third_color"]["machine"]["nodes"].append({"id": 99, "kind": "invention", "invention": "contrast", "x": 9, "y": 6})
	check(Progress.problems(bad, levels).is_empty(), "an offered, saved invention on the bench fits")
	bad["inventions"].erase("contrast")
	check(not Progress.problems(bad, levels).is_empty(), "a machine with an invention the save lacks is stale")
	host.inventions.erase("contrast")

	bad = good.duplicate(true)
	bad["inventions"]["made_up"] = bad["inventions"]["contrast"].duplicate(true)
	check(not Progress.problems(bad, levels).is_empty(), "an unknown invention id is stale")
	check(not Progress.from_dict(bad, levels).inventions.has("made_up"), "loading drops the unknown invention")

	var path := "user://test_stale_save.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"version\": 0}")
	f.close()
	check(not Progress.problems(Progress.read(path), levels).is_empty(), "an old file on disk reads as stale")
	var bak := Progress.back_up(path)
	check(bak == path + ".bak" and not FileAccess.file_exists(path) and FileAccess.get_file_as_string(bak) == "{\"version\": 0}", "the old save moves to .bak")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("second")
	f.close()
	var bak2 := Progress.back_up(path)
	check(bak2 == path + ".2.bak" and FileAccess.get_file_as_string(bak) == "{\"version\": 0}", "an older backup is never overwritten")
	check(Progress.read(path) == null and Progress.load_from(path, levels).levels.is_empty(), "after the backup the game starts fresh")
	for p in [bak, bak2]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## From chapter 2 on, a level that offers the red pot offers every pot an
## earlier level earns; one that offers only named pieces offers none.
func test_pots_in_trays(levels: Array) -> void:
	var by_id := {}
	for level in levels:
		by_id[level.id] = level
	var all := ["pot_white", "pot_yellow", "pot_orange", "pot_blue", "pot_purple", "pot_green", "pot_black"]
	check(levels.filter(func(l): return l.chapter == 0).all(func(l): return l.pots.is_empty()), "the paint box offers no earned pots")
	check(by_id["orange_sun"].pots == all, "Orange Sun offers every earned pot, in paint order: %s" % str(by_id["orange_sun"].pots))
	check(by_id["orange_sun"].offers_invention("pot_yellow") and not by_id["orange_sun"].offers_invention("contrast"), "an earned pot counts as offered")
	check(by_id["pattern_card"].pots.is_empty() and by_id["neither_twice"].pots.is_empty() and by_id["only_missing"].pots.is_empty(), "levels without the red pot offer no pots")
	check(by_id["same_paint"].pots == all, "chapter 4's kit levels offer the pots")
	var raw: Dictionary = by_id["orange_sun"].raw.duplicate(true)
	raw["hold_pots"] = ["pot_orange"]
	var copy := levels.duplicate()
	var held = Level.from_dict(raw)
	held.chapter = 1
	copy[copy.find(by_id["orange_sun"])] = held
	Level._lay_trays(copy)
	check(not "pot_orange" in held.pots and held.held_pots == ["pot_orange"] and not held.offers_invention("pot_orange"), "a level can hold a pot back")
	Level._lay_trays(levels)
