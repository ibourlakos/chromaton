## Tests for inventions: packaging a solved machine, checking it works for
## every paint, and using it inside later levels.
## Run: godot_console --headless --path . --script res://tests/test_inventions.gd
extends SceneTree

const Paint = preload("res://core/paint.gd")
const Pieces = preload("res://core/pieces.gd")
const Machine = preload("res://core/machine.gd")
const Level = preload("res://core/level.gd")
const Simulator = preload("res://core/simulator.gd")
const Invention = preload("res://core/invention.gd")
const Progress = preload("res://core/progress.gd")

const S = Simulator.Status

var failures := 0
var checks := 0
var by_id := {}
var campaign: Array = []


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func _init() -> void:
	campaign = Level.load_all()
	for level in campaign + Level.load_lost():
		by_id[level.id] = level
	by_id["make_filter"] = filter_level()
	var inventions := test_packaging()
	test_every_paint(inventions)
	test_in_later_levels(inventions)
	test_one_tick(inventions)
	test_nested(inventions)
	test_edges()
	test_pots(inventions)
	if failures == 0:
		print("test_inventions: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


## A test fixture: Keep What They Share as an invention level that makes a
## Filter sticker (the campaign's version earns stars only), solved the
## De Morgan way with basic pieces: Invert(Mix(Invert A, Invert B)).
func filter_level():
	var raw: Dictionary = by_id["keep_what_they_share"].raw.duplicate(true)
	raw["invention"] = {"id": "filter", "name": "Filter", "check": "filter"}
	raw["reference"] = {
		"pieces": [
			{"id": "ia", "kind": "invert", "x": 3, "y": 1}, {"id": "ib", "kind": "invert", "x": 3, "y": 5},
			{"id": "m", "kind": "mix", "x": 6, "y": 3}, {"id": "o", "kind": "invert", "x": 8, "y": 3}],
		"tubes": [["card0", "ia"], ["card1", "ib"], ["ia", "m.0"], ["ib", "m.1"], ["m", "o"], ["o", "loom"]]}
	return Level.from_dict(raw)


func test_packaging() -> Dictionary:
	var level = by_id["make_filter"]
	var inv := Invention.package(level, level.reference_machine(), {})
	check(inv["id"] == "filter" and inv["name"] == "Filter", "the level makes Filter")
	check(inv["inputs"] == 2, "its cards become two input ports")
	check(inv["cost"] == 3, "it costs the four pieces inside it, minus one")
	check(inv["counts"] == {"invert": 3, "mix": 1}, "it remembers what it is made of")
	check(Pieces.ports({"kind": Pieces.INVENTION, "invention": "filter"}, {"filter": inv}) == Vector2i(2, 1), "two inputs, one output")
	var round_trip = JSON.parse_string(JSON.stringify(inv))
	check(Machine.from_dict(round_trip["machine"]).to_dict() == inv["machine"], "its machine survives saving")
	return {"filter": inv}


func test_every_paint(inventions: Dictionary) -> void:
	var level = by_id["make_filter"]
	check(Invention.works_for_every_paint(level.reference_machine(), 2, "filter", {}), "the reference Filter works for every pair of paints")
	# Invert(Mix(A, B)) is not a Filter.
	var nor = level.machine_from_spec({
		"pieces": [{"id": "m", "kind": "mix", "x": 0, "y": 0}, {"id": "o", "kind": "invert", "x": 0, "y": 1}],
		"tubes": [["card0", "m.0"], ["card1", "m.1"], ["m", "o"], ["o", "loom"]]})
	check(not Invention.works_for_every_paint(nor, 2, "filter", {}), "a machine that isn't a Filter is caught")
	# Mix(A, B) with B's tube swapped for a pot only matches some pairs.
	var half = level.machine_from_spec({
		"pieces": [{"id": "p", "kind": "red_pot", "x": 0, "y": 0}, {"id": "m", "kind": "mix", "x": 0, "y": 1}],
		"tubes": [["card0", "m.0"], ["p", "m.1"], ["m", "loom"]]})
	check(not Invention.works_for_every_paint(half, 2, "filter", {}), "a machine ignoring an input is caught")


func test_in_later_levels(inventions: Dictionary) -> void:
	# Wash Out with the Filter sticker: Filter(A, Invert(B)).
	var level = by_id["wash_out"]
	var m = level.machine_from_spec({
		"pieces": [{"id": "ib", "kind": "invert", "x": 8, "y": 1}, {"id": "f", "kind": "invention", "invention": "filter", "x": 6, "y": 2}],
		"tubes": [["card0", "f.0"], ["card1", "ib"], ["ib", "f.1"], ["f", "loom"]]})
	var sim := Simulator.new(m, level.cards, level.target, inventions)
	sim.run()
	check(sim.status == S.SOLVED, "Filter solves Wash Out (status %d, stitch %d)" % [sim.status, sim.wrong_index])
	check(m.cost(inventions) == 4 and level.stars_for(4) == 1, "the sticker counts its price: 4 pieces, where the Filter critter needs 2")
	check(m.piece_counts(inventions) == {"invert": 4, "mix": 1}, "counts open the invention up")

	# The Flower with two Filter stickers: Filter(Mix(C, B), Mix(A, Filter(C, B))).
	level = by_id["the_flower"]
	m = level.machine_from_spec({
		"pieces": [
			{"id": "sb", "kind": "split", "x": 2, "y": 3}, {"id": "sc", "kind": "split", "x": 2, "y": 6},
			{"id": "f1", "kind": "invention", "invention": "filter", "x": 4, "y": 4}, {"id": "m1", "kind": "mix", "x": 5, "y": 6},
			{"id": "m2", "kind": "mix", "x": 6, "y": 1}, {"id": "f2", "kind": "invention", "invention": "filter", "x": 8, "y": 4}],
		"tubes": [["card1", "sb"], ["card2", "sc"], ["sc.0", "f1.1"], ["sb.0", "f1.0"], ["sc.1", "m1.1"], ["sb.1", "m1.0"],
			["card0", "m2.0"], ["f1", "m2.1"], ["m1", "f2.1"], ["m2", "f2.0"], ["f2", "loom"]]})
	sim = Simulator.new(m, level.cards, level.target, inventions)
	sim.run()
	check(sim.status == S.SOLVED, "Filter stickers solve The Flower")
	check(m.cost(inventions) == 8, "two stickers and two Mixes cost 8")

	# Without the invention the same machine can't run.
	sim = Simulator.new(m, level.cards, level.target, {})
	sim.run()
	check(sim.status == S.STALLED, "a missing invention does nothing")


## An invention makes the same colors as the machine inside it, but it is one
## piece that takes one tick.
func test_one_tick(inventions: Dictionary) -> void:
	var table := Simulator.invention_table(inventions["filter"], inventions)
	var exact := table.size() == 64
	for a in 8:
		for b in 8:
			exact = exact and table[a + 8 * b] == Paint.filter(a, b)
	check(exact, "Filter's table holds the right color for every pair of paints")

	# The level's own cards, woven by the sticker and by the machine inside it.
	var level = by_id["make_filter"]
	var boxed_machine = level.machine_from_spec({
		"pieces": [{"id": "f", "kind": "invention", "invention": "filter", "x": 5, "y": 3}],
		"tubes": [["card0", "f.0"], ["card1", "f.1"], ["f", "loom"]]})
	var boxed := Simulator.new(boxed_machine, level.cards, level.target, inventions)
	var flat := Simulator.new(level.reference_machine(), level.cards, level.target, inventions)
	boxed.run()
	flat.run()
	check(boxed.status == S.SOLVED and flat.status == S.SOLVED and boxed.woven == flat.woven, "boxed and unboxed Filter weave the same cloth")
	# Card, Filter, loom: one piece deep. Unboxed it is three deep.
	var n: int = level.size()
	check(boxed.tick == n + 2 and flat.tick == n + 4, "the Filter sticker takes one tick, its inside three (%d and %d ticks for %d stitches)" % [boxed.tick, flat.tick, n])
	var f: int = boxed_machine.find_kind(Pieces.INVENTION)
	var probe := Simulator.new(boxed_machine, level.cards, level.target, inventions)
	for k in 2:
		probe.step()
	check(probe.node_last_fire(f) == 2 and probe.node_fire_count(f) == 1 and probe.node_color(f) == Paint.filter(level.cards[0][0], level.cards[1][0]), "the sticker fires on the tick after its paint arrives")


func test_nested(inventions: Dictionary) -> void:
	# Package level 8's Filter solution as a Bleach invention: an invention
	# that contains an invention.
	var raw: Dictionary = by_id["wash_out"].raw.duplicate(true)
	raw["invention"] = {"id": "bleach", "name": "Bleach", "check": "bleach"}
	var level = Level.from_dict(raw)
	var m = level.machine_from_spec({
		"pieces": [{"id": "ib", "kind": "invert", "x": 8, "y": 1}, {"id": "f", "kind": "invention", "invention": "filter", "x": 6, "y": 2}],
		"tubes": [["card0", "f.0"], ["card1", "ib"], ["ib", "f.1"], ["f", "loom"]]})
	var all := inventions.duplicate()
	all["bleach"] = Invention.package(level, m, inventions)
	check(all["bleach"]["cost"] == 3, "a nested invention costs everything inside it, the inner one at its price, minus one")
	var outer := Machine.new()
	var a: int = outer.add_node(Pieces.CARD, 0, 0, {"card": 0})
	var b: int = outer.add_node(Pieces.CARD, 0, 0, {"card": 1})
	var loom: int = outer.add_node(Pieces.LOOM)
	var box: int = outer.add_node(Pieces.INVENTION, 0, 0, {"invention": "bleach"})
	outer.connect_ports(a, 0, box, 0)
	outer.connect_ports(b, 0, box, 1)
	outer.connect_ports(box, 0, loom, 0)
	check(Invention.works_for_every_paint(outer, 2, "bleach", all), "an invention inside an invention works for every paint")


func test_edges() -> void:
	# An invention whose card goes straight to its loom is just a tube.
	var inner := Machine.new()
	var c: int = inner.add_node(Pieces.CARD, 0, 0, {"card": 0})
	var l: int = inner.add_node(Pieces.LOOM)
	inner.connect_ports(c, 0, l, 0)
	var inventions := {"pipe": {"id": "pipe", "name": "Pipe", "inputs": 1, "cost": 0, "counts": {}, "machine": inner.to_dict()}}
	var outer := Machine.new()
	var a: int = outer.add_node(Pieces.CARD, 0, 0, {"card": 0})
	var loom: int = outer.add_node(Pieces.LOOM)
	var box: int = outer.add_node(Pieces.INVENTION, 0, 0, {"invention": "pipe"})
	outer.connect_ports(a, 0, box, 0)
	outer.connect_ports(box, 0, loom, 0)
	var seq := Level.parse_rows(["RYBK"])
	var sim := Simulator.new(outer, [seq], seq, inventions)
	sim.run()
	check(sim.status == S.SOLVED and sim.tick == 6, "a pass-through invention takes one tick like any piece (%d)" % sim.tick)
	check(sim.tube_drop(0) == -1 and sim.tube_drop(1) == -1, "its tubes are empty once the cloth is woven")

	# An invention with an unconnected input never fires (its card pours into
	# a catch pot, so the card still counts as used).
	outer.remove_tube(outer.tube_from(a, 0))
	outer.connect_ports(a, 0, outer.add_node("catch_pot", 0, 1), 0)
	sim = Simulator.new(outer, [seq], seq, inventions)
	sim.run()
	check(sim.status == S.STALLED and sim.woven.size() == 0, "an unfed invention stays still")


## A color pot is an invention with no inputs: one stitch checks it, it makes
## its paint every tick, and it keeps the cheapest price the player has made
## it for.
func test_pots(inventions: Dictionary) -> void:
	var refs := Invention.reference_inventions_by_level(campaign)
	var level = by_id["orange"]
	var before: Dictionary = refs[level.number - 1]  # the yellow pot, at 1
	var pot := Invention.package(level, level.reference_machine(), before)
	check(pot["id"] == "pot_orange" and pot["inputs"] == 0 and pot["cost"] == 2, "Orange earns an orange pot: red and the yellow pot mixed, 3 pieces, less one (%d)" % pot["cost"])
	check(Invention.paint_of(pot) == Paint.ORANGE and Invention.paint_of(inventions["filter"]) == -1, "a pot knows its paint; other inventions aren't pots")
	check(Invention.works_for_every_paint(level.reference_machine(), 0, "paint:O", before), "the orange machine passes the every-paint check")
	check(not Invention.works_for_every_paint(by_id["yellow"].reference_machine(), 0, "paint:O", {}), "a yellow machine is no orange pot")
	var all := before.duplicate()
	all["pot_orange"] = pot
	check(Simulator.invention_table(pot, all) == PackedByteArray([Paint.ORANGE]), "a pot's table has one entry")
	var m = level.machine_from_spec({
		"pieces": [{"id": "o", "kind": "invention", "invention": "pot_orange", "x": 4, "y": 3}],
		"tubes": [["o", "loom"]]})
	var sim := Simulator.new(m, level.cards, level.target, all)
	sim.run()
	check(sim.status == S.SOLVED and sim.tick == level.size() + 1, "the orange pot weaves an orange cloth, one drop a tick (%d ticks)" % sim.tick)
	check(m.cost(all) == 2, "and costs its price")
	check(Invention.price(1) == 1 and Invention.price(0) == 1 and Invention.price(5) == 4, "the discount is one piece, never below 1")
	var paint_box := campaign.filter(func(l): return l.chapter == 0 and not l.invention.is_empty())
	var prices := paint_box.map(func(l): return Invention.package(l, l.reference_machine(), refs[l.number - 1])["cost"])
	check(prices == [1, 1, 2, 3, 2, 3, 1, 1, 1, 2, 2], "the paint box earns Yellow 1, Blue 1, Orange 2, Purple 3, Green 2, Black 3, then Green, Orange and Purple at 1, Black 2, White 2 (%s)" % str(prices))

	var p = Progress.new()
	p.add_invention(pot)
	var dearer := pot.duplicate(true)
	dearer["cost"] = 6
	check(p.add_invention(dearer)["cost"] == 2 and p.inventions["pot_orange"]["cost"] == 2, "a dearer orange pot keeps the cheaper price")
	var cheaper := pot.duplicate(true)
	cheaper["cost"] = 1
	check(p.add_invention(cheaper)["cost"] == 1 and p.inventions["pot_orange"]["cost"] == 1, "a cheaper orange pot lowers the price")
	var filter: Dictionary = inventions["filter"]
	p.add_invention(filter)
	var bigger := filter.duplicate(true)
	bigger["cost"] = 9
	check(p.add_invention(bigger)["cost"] == 3, "every invention keeps its cheaper machine")
	var same := filter.duplicate(true)
	same["machine"] = {"nodes": [], "tubes": [], "next_id": 1}
	check(p.add_invention(same)["machine"] == same["machine"], "a machine as cheap takes its place")
	test_earned_twice()


## The discount compounds: four Third Paints at 1 each make a 4-piece
## machine, so Same Paint built from them would cost 3. Two inventions a
## chapter: Same Paint is earned only in The Black Queen, and the Black pot
## twice, the cheaper machine winning.
func test_earned_twice() -> void:
	var p = Progress.new()
	for id in ["third_color", "same_paint"]:
		var level = by_id[id]
		var inv := Invention.package(level, level.reference_machine(), p.inventions)
		check(Invention.works_for_every_paint(level.reference_machine(), level.cards.size(), inv["check"], p.inventions), "%s earns a real %s" % [id, inv["name"]])
		p.add_invention(inv)
	check(p.inventions["third_paint"]["cost"] == 1, "the Third Paint costs 1: Mix and Flip, less one")
	check(p.inventions["same_paint"]["cost"] == 3 and p.inventions["same_paint"]["from_level"] == "same_paint", "the 4-piece Same Paint costs 3")
	var king = by_id["only_third_paint"]
	check(king.invention.is_empty(), "Only the Third Paint earns nothing now")
	check(Invention.price(king.reference_machine().cost(p.inventions)) == 3, "four Third Paints would make Same Paint at 4 - 1 = 3")
	var refs := Invention.reference_inventions_by_level(campaign)
	var black := [by_id["black"], by_id["black_short_way"]].map(func(l): return Invention.package(l, l.reference_machine(), refs[l.number - 1]))
	var q = Progress.new()
	q.add_invention(black[1])
	q.add_invention(black[0])
	check(black[0]["cost"] == 3 and black[1]["cost"] == 2 and q.inventions["pot_black"]["cost"] == 2, "the first Black pot (3) doesn't replace the cheaper one (2)")
