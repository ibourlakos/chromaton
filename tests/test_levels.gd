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
const Profiles = preload("res://core/profiles.gd")

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
	var by_level := Invention.reference_inventions_by_level(levels)
	var inventions: Dictionary = by_level[by_level.size() - 1]
	test_references(levels, by_level)
	test_wrong_solutions(levels)
	test_stars(levels)
	test_progress(levels, inventions)
	test_stale_saves(levels, inventions)
	test_locks_and_loans(levels, inventions)
	test_profiles()
	if failures == 0:
		print("test_levels: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


func test_loading(levels: Array) -> void:
	check(levels.size() == 42, "forty-two campaign levels (got %d)" % levels.size())
	check(Level.chapters().map(func(c): return c["levels"].size()) == [12, 12, 9, 9], "four chapters of 12, 12, 9 and 9 levels, each quilt full")
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
	for level in levels:
		if not level.cards.is_empty():
			check(level.card_shows >= Level.CARD_SHOWS_MIN and level.card_shows <= Level.CARD_SHOWS_MAX and level.raw.has("card_shows"), "%s: its cards show 4 to 10 drops (%d)" % [level.id, level.card_shows])
			check(level.raw["cards"].all(func(c): return not c.has("smudges")), "%s: no smudges on its cards" % level.id)
			check(level.cols >= Level.CARD_COLS_MIN and level.cols <= Level.CARD_COLS_MAX and level.rows >= Level.CARD_ROWS_MIN and level.rows <= Level.CARD_ROWS_MAX, "%s: its card pictures are 4 to 12 columns by 1 to 9 rows (%d by %d)" % [level.id, level.cols, level.rows])
	var lost := Level.load_lost()
	check(lost.map(func(l): return l.id) == ["flip_side", "the_flower", "chessboard"] and lost.all(func(l): return l.error == ""), "Flip Side, The Harbour and The Chessboard wait in Lost Levels")
	check(not Level.index_ids().has("flip_side") and not Level.index_ids().has("the_flower") and not Level.index_ids().has("chessboard"), "Lost Levels stay out of the campaign")
	var chess = lost.filter(func(l): return l.id == "chessboard")[0]
	check(chess.cols == Level.CARD_COLS_MAX and chess.rows == Level.CARD_ROWS_MAX and chess.cards.size() == 2, "The Chessboard's cards are the largest a card may be (%d by %d)" % [chess.cols, chess.rows])
	check(range(chess.size()).all(func(i): return chess.target[i] == (Paint.BLACK if (i / chess.cols + i % chess.cols) % 2 == 0 else Paint.WHITE)), "and it weaves a black and white chessboard")
	var tables := levels.filter(func(l): return l.id in ["mix_table", "filter_table"])
	for t in tables:
		check(Level.letters(t.cards[1], 8) == ["WRYOBPGK", "WRYOBPGK", "WRYOBPGK", "WRYOBPGK", "WRYOBPGK", "WRYOBPGK"], "%s: card B is every paint on every row" % t.id)
		check(Level.letters(t.cards[0], 8) == ["RRRRRRRR", "YYYYYYYY", "BBBBBBBB", "OOOOOOOO", "PPPPPPPP", "GGGGGGGG"], "%s: card A is one paint a row" % t.id)
	var inv_levels := levels.filter(func(l): return not l.invention.is_empty())
	var pot_ids := inv_levels.filter(func(l): return l.chapter == 0).map(func(l): return l.invention["id"])
	check(pot_ids == ["pot_yellow", "pot_blue", "pot_orange", "pot_purple", "pot_green", "pot_black", "pot_green", "pot_orange", "pot_purple", "pot_black", "pot_white"], "paint-box levels 2 to 12 each earn a pot, then green, orange, purple and black again, cheaper (%s)" % str(pot_ids))
	var others := inv_levels.filter(func(l): return l.chapter > 0).map(func(l): return l.invention["id"])
	check(others == ["third_paint", "contrast", "missing_from_either", "same_paint"], "two inventions a chapter after the paint box (%s)" % str(others))
	test_pots_in_trays(levels)


## Each level's reference, with the inventions the levels before it earn at
## their cheapest so far (Invention.reference_inventions_by_level).
func test_references(levels: Array, by_level: Array) -> void:
	for level in levels:
		var inventions: Dictionary = by_level[level.number - 1]
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
	levels = levels + Level.load_lost()
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


func test_progress(levels: Array, inventions: Dictionary) -> void:
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
	p.inventions["contrast"] = Invention.package(inv_level, inv_level.reference_machine(), inventions)
	p.store_machine(inv_level.id, inv_level.reference_machine().to_dict())
	var path := "user://test_progress.json"
	check(p.save(path), "progress saves")
	var q = Progress.load_from(path)
	check(q.to_dict() == p.to_dict(), "progress loads back the same")
	check(q.inventions["contrast"]["cost"] == 2 and q.inventions["contrast"]["inputs"] == 2, "saved invention keeps its ports and price")
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
	check(by_id["one_pot"].pots.is_empty() and by_id["yellow"].pots.is_empty() and by_id["blue"].pots == ["pot_yellow"], "pots open from Blue on: its tray offers the yellow pot")
	check(by_id["purple"].pots.is_empty() and by_id["purple"].held_pots == ["pot_yellow", "pot_orange", "pot_blue"], "Purple holds every pot back")
	check(not "pot_green" in by_id["green"].pots and "pot_green" in by_id["green"].held_pots and not "pot_black" in by_id["black_short_way"].pots, "a level holds back the pot it earns")
	check(by_id["white"].pots == ["pot_yellow", "pot_orange", "pot_blue", "pot_purple", "pot_green", "pot_black"], "the white pot level offers every pot but white")
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


## A level that can't be built without an invention waits for it, on top of
## solve-two-ahead; force unlock lends every invention and pot at its
## reference price without saving it; keeping what fits forgets an invention
## level whose invention it dropped.
func test_locks_and_loans(levels: Array, inventions: Dictionary) -> void:
	var ids := levels.map(func(l): return l.id)
	var by_id := {}
	for level in levels:
		by_id[level.id] = level
	var waiting := levels.filter(func(l): return not l.waits_for.is_empty()).map(func(l): return l.id)
	check(waiting == ["two_pawns", "neither_twice", "back_to_mix", "little_board", "only_third_paint", "two_black_pawns", "missing_twice", "back_to_filter", "little_black_board", "only_missing"], "the levels offering only inventions and Split wait for them (%s)" % str(waiting))
	var p = Progress.new()
	p.know_levels(levels)
	var rook: int = ids.find("neither_twice")
	p.record_solve("third_color", 2, 70, 3)
	check(not p.is_unlocked(ids, rook), "The Rook stays locked after The Pawn until the Third Paint is owned")
	check(Level.waiting_line(levels, p.waiting_for("neither_twice")) == "Earn the Third Paint in %s." % by_id["third_color"].ref_name(), "its tag says where to earn it")
	p.add_invention(inventions["third_paint"])
	check(p.is_unlocked(ids, rook) and p.waiting_for("neither_twice").is_empty(), "owning the Third Paint opens it")
	check(not p.is_unlocked(ids, ids.find("only_third_paint")), "the rule of two still holds for the rest")

	var q = Progress.new()
	q.unlock_all = true
	q.know_levels(levels)
	check(q.inventions.is_empty() and q.usable().has("third_paint") and q.usable().has("pot_white"), "force unlock lends every invention and pot")
	check(q.usable()["pot_orange"]["cost"] == inventions["pot_orange"]["cost"], "at its reference price")
	var rook_level = by_id["neither_twice"]
	q.store_machine("neither_twice", rook_level.reference_machine().to_dict())
	var saved: Dictionary = q.to_dict()
	check(saved["inventions"].is_empty(), "a loan is never saved")
	check(saved["levels"]["neither_twice"]["machine"]["nodes"].all(func(n): return n["kind"] != "invention") and saved["levels"]["neither_twice"]["machine"]["tubes"].size() == 1, "a saved bench leaves out lent inventions and their tubes")
	check(Progress.problems(JSON.parse_string(JSON.stringify(saved)), levels).is_empty(), "so the save still fits without the cheat")
	var own: Dictionary = inventions["pot_orange"].duplicate(true)
	own["cost"] = 9
	q.add_invention(own)
	check(q.usable()["pot_orange"]["cost"] == 9, "earning one for real replaces the loan")

	var r = Progress.new()
	r.record_solve("yellow", 2, 10, 3)
	r.record_solve("one_pot", 1, 9, 3)
	r.store_machine("yellow", by_id["yellow"].reference_machine().to_dict())
	var kept = Progress.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())), levels)
	check(not kept.is_solved("yellow") and kept.levels["yellow"].has("machine") and kept.is_solved("one_pot"), "a solved invention level without its invention reads unsolved, its bench kept")


## Local profiles: without a roster there's one, the first, whose save is
## the one from before profiles, untouched; each new one gets its own file;
## a name defaults to its critter's.
func test_profiles() -> void:
	var path := "user://test_profiles.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p = Profiles.load_from(path)
	check(p.list.size() == 1 and p.current == 1 and Profiles.save_path(1) == Progress.PATH, "one profile at first, playing the save from before profiles")
	var id: int = p.add("shift", "  andrew ")
	check(id == 2 and Profiles.save_path(2) == "user://chromaton_save_2.json", "a new profile gets its own save file")
	check(Profiles.display_name(p.find(2)) == "andrew" and Profiles.display_name(p.find(1)) == "Mixing Tub", "a name, or the critter's")
	p.current = 2
	p.save(path)
	var q = Profiles.load_from(path)
	check(q.list.size() == 2 and q.current == 2 and q.find(2)["badge"] == "shift", "the roster survives a save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
