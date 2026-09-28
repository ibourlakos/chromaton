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
	check(levels.size() == 15, "fifteen campaign levels (got %d)" % levels.size())
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
			check(p.get("invention", "") == "" or p["invention"] in level.inventions, "%s reference uses an offered invention" % level.id)
	check(Level.parse_rows(["WRYOBPGK"]) == PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7]), "color letters")
	check(Level.letters(PackedByteArray([1, 2, 3, 4]), 2) == ["RY", "OB"], "letters round trip")
	var inv_levels := levels.filter(func(l): return not l.invention.is_empty())
	check(inv_levels.size() == 1 and inv_levels[0].invention["id"] == "filter", "one invention level, and it makes Filter")


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
		check(sim.tick >= 2 * level.size(), "%s: at least two ticks per stitch" % level.id)


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
		"third_no_invert":
			return Paint.mix(a, b)
		"flower_swapped":
			return Paint.mix(Paint.filter(a, c), b)
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
		["third_color", {"pieces": [{"id": "m", "kind": "mix", "x": 0, "y": 0}], "tubes": [["card0", "m.0"], ["card1", "m.1"], ["m", "loom"]]}, "third_no_invert"],
		["keep_what_they_share", {"pieces": [], "tubes": [["card1", "loom"]]}, "B"],
		["wash_out", {"pieces": [
			{"id": "ia", "kind": "invert", "x": 0, "y": 0}, {"id": "m", "kind": "mix", "x": 0, "y": 1}, {"id": "o", "kind": "invert", "x": 0, "y": 2}],
			"tubes": [["card1", "ia"], ["ia", "m.0"], ["card0", "m.1"], ["m", "o"], ["o", "loom"]]}, "bleach_swapped"],
		["the_flower", {"pieces": [
			{"id": "ia", "kind": "invert", "x": 0, "y": 0}, {"id": "ib", "kind": "invert", "x": 1, "y": 0},
			{"id": "m", "kind": "mix", "x": 0, "y": 1}, {"id": "o", "kind": "invert", "x": 0, "y": 2}, {"id": "m2", "kind": "mix", "x": 0, "y": 3}],
			"tubes": [["card0", "ia"], ["card2", "ib"], ["ia", "m.0"], ["ib", "m.1"], ["m", "o"], ["o", "m2.0"], ["card1", "m2.1"], ["m2", "loom"]]}, "flower_swapped"],
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
	check(p.is_unlocked(ids, 1), "solving a level opens the next")
	better = p.record_solve(ids[0], 4, 30, 1)
	check(not better["pieces"] and better["ticks"] and not better["stars"], "records only improve")
	var rec: Dictionary = p.level_record(ids[0])
	check(rec["best_pieces"] == 3 and rec["best_ticks"] == 30 and rec["stars"] == 2, "best pieces and ticks kept separately")

	var level7 = levels.filter(func(l): return l.id == "keep_what_they_share")[0]
	p.inventions["filter"] = Invention.package(level7, level7.reference_machine(), {})
	p.store_machine(level7.id, level7.reference_machine().to_dict())
	var path := "user://test_progress.json"
	check(p.save(path), "progress saves")
	var q = Progress.load_from(path)
	check(q.to_dict() == p.to_dict(), "progress loads back the same")
	check(q.inventions["filter"]["cost"] == 4 and q.inventions["filter"]["inputs"] == 2, "saved invention keeps its ports and price")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var fresh = Progress.load_from("user://no_such_save.json")
	check(fresh.levels.is_empty(), "a missing save starts fresh")
