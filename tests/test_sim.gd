## Unit tests for the pieces table, the machine graph and the simulator.
## Run: godot_console --headless --path . --script res://tests/test_sim.gd
extends SceneTree

const Paint = preload("res://core/paint.gd")
const Pieces = preload("res://core/pieces.gd")
const Machine = preload("res://core/machine.gd")
const Simulator = preload("res://core/simulator.gd")
const Level = preload("res://core/level.gd")

const S = Simulator.Status

var failures := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func seq(letters: String) -> PackedByteArray:
	return Level.parse_rows([letters])


## A bench with `card_count` cards and a loom; returns [machine, card ids, loom id].
func bench(card_count: int) -> Array:
	var m = Machine.new()
	var cards := []
	for i in card_count:
		cards.append(m.add_node(Pieces.CARD, 0, 0, {"card": i}))
	var loom: int = m.add_node(Pieces.LOOM)
	return [m, cards, loom]


func run(m, cards: Array, target: String) -> Simulator:
	var sim := Simulator.new(m, cards, seq(target))
	sim.run()
	return sim


func _init() -> void:
	test_piece_table()
	test_each_piece()
	test_timing()
	test_backpressure()
	test_split()
	test_unconnected()
	test_wrong_stitch()
	test_stall_and_run_out()
	test_order_independence()
	test_determinism()
	test_machine_edits()
	if failures == 0:
		print("test_sim: all %d checks passed" % checks)
	quit(1 if failures > 0 else 0)


func test_piece_table() -> void:
	for kind in Pieces.TABLE:
		var e: Dictionary = Pieces.TABLE[kind]
		for key in ["name", "inputs", "outputs", "op", "cost", "look"]:
			check(e.has(key), "%s has %s" % [kind, key])
	check(Pieces.TABLE["split"]["cost"] == 0, "splits are free")
	check(Pieces.apply("red", []) == [Paint.RED], "pot makes red")
	check(Pieces.apply("mix", [Paint.RED, Paint.BLUE]) == [Paint.PURPLE], "mix op")
	check(Pieces.apply("invert", [Paint.YELLOW]) == [Paint.PURPLE], "invert op")
	check(Pieces.apply("shift", [Paint.ORANGE]) == [Paint.GREEN], "shift op")
	check(Pieces.apply("copy", [Paint.GREEN]) == [Paint.GREEN, Paint.GREEN], "split copies")


func test_each_piece() -> void:
	# Red pot straight to the loom.
	var b := bench(0)
	var pot: int = b[0].add_node("red_pot", 0, 0)
	b[0].connect_ports(pot, 0, b[2], 0)
	check(run(b[0], [], "RRRR").status == S.SOLVED, "red pot weaves red")

	# One-input pieces between a card and the loom.
	for case in [["invert", "RYBWK", "GPOKW"], ["shift", "RYBOGPWK", "YBRGPOWK"]]:
		b = bench(1)
		var p: int = b[0].add_node(case[0], 0, 0)
		b[0].connect_ports(b[1][0], 0, p, 0)
		b[0].connect_ports(p, 0, b[2], 0)
		var sim := run(b[0], [seq(case[1])], case[2])
		check(sim.status == S.SOLVED, "%s weaves %s from %s" % case)

	# Mix of two cards.
	b = bench(2)
	var mix: int = b[0].add_node("mix", 0, 0)
	b[0].connect_ports(b[1][0], 0, mix, 0)
	b[0].connect_ports(b[1][1], 0, mix, 1)
	b[0].connect_ports(mix, 0, b[2], 0)
	check(run(b[0], [seq("RYWK"), seq("YBWR")], "OGWK").status == S.SOLVED, "mix of two cards")


func test_timing() -> void:
	# Card straight to loom: the card fills the tube, the loom empties it the
	# next tick, and the card can only refill it the tick after.
	var b := bench(1)
	b[0].connect_ports(b[1][0], 0, b[2], 0)
	var sim := run(b[0], [seq("RYB")], "RYB")
	check(sim.status == S.SOLVED and sim.tick == 6, "direct card: 3 stitches in 6 ticks (got %d)" % sim.tick)

	# One piece in between adds one tick of latency.
	b = bench(1)
	var inv: int = b[0].add_node("invert", 0, 0)
	b[0].connect_ports(b[1][0], 0, inv, 0)
	b[0].connect_ports(inv, 0, b[2], 0)
	sim = run(b[0], [seq("RYB")], "GPO")
	check(sim.status == S.SOLVED and sim.tick == 7, "card-invert-loom: 7 ticks (got %d)" % sim.tick)

	# Step by step: nothing moves at tick 0, the card fires first.
	sim = Simulator.new(b[0], [seq("RYB")], seq("GPO"))
	var tube: int = b[0].tube_from(b[1][0], 0)
	check(sim.tube_drop(tube) == -1, "tubes start empty")
	sim.step()
	check(sim.tick == 1 and sim.tube_drop(tube) == Paint.RED, "tick 1: card releases red")
	sim.step()
	check(sim.tube_drop(tube) == -1 and sim.tube_drop(b[0].tube_from(inv, 0)) == Paint.GREEN, "tick 2: invert fires, card waits")
	check(sim.node_color(inv) == Paint.GREEN and sim.node_last_fire(inv) == 2, "invert remembers what it made")


func test_backpressure() -> void:
	# A split whose second branch dead-ends: that tube fills once and then
	# blocks the split, so the loom starves after one stitch.
	var b := bench(1)
	var split: int = b[0].add_node("split", 0, 0)
	var inv: int = b[0].add_node("invert", 1, 0)
	b[0].connect_ports(b[1][0], 0, split, 0)
	b[0].connect_ports(split, 0, b[2], 0)
	b[0].connect_ports(split, 1, inv, 0)
	var sim := run(b[0], [seq("RRRR")], "RRRR")
	check(sim.status == S.STALLED, "blocked branch stalls the machine")
	check(sim.woven.size() == 1, "only one stitch gets through (got %d)" % sim.woven.size())
	check(sim.card_remaining(0) == 2, "the card stops releasing when its tube is full (left %d)" % sim.card_remaining(0))

	# A full tube holds its drop until the piece below takes it.
	var m = Machine.new()
	var pot: int = m.add_node("red_pot", 0, 0)
	var mix: int = m.add_node("mix", 0, 1)
	m.connect_ports(pot, 0, mix, 0)
	sim = Simulator.new(m, [], seq("R"))
	sim.step()
	sim.step()
	check(sim.status == S.STALLED and sim.tick == 1, "pot fires once, then waits on the half-fed mix")
	check(sim.tube_drop(0) == Paint.RED, "the drop stays in its tube")


func test_split() -> void:
	# Pot -> split -> both inputs of a mix -> loom.
	var b := bench(0)
	var pot: int = b[0].add_node("red_pot", 0, 0)
	var split: int = b[0].add_node("split", 0, 1)
	var mix: int = b[0].add_node("mix", 0, 2)
	b[0].connect_ports(pot, 0, split, 0)
	b[0].connect_ports(split, 0, mix, 0)
	b[0].connect_ports(split, 1, mix, 1)
	b[0].connect_ports(mix, 0, b[2], 0)
	check(run(b[0], [], "RRR").status == S.SOLVED, "split copies feed one mix")
	check(b[0].cost({}) == 2, "split is not counted as a piece")

	# Branches of different lengths stay in step: Mix(A, Shift(Shift(A))).
	b = bench(1)
	split = b[0].add_node("split", 0, 0)
	var h1: int = b[0].add_node("shift", 1, 0)
	var h2: int = b[0].add_node("shift", 1, 1)
	mix = b[0].add_node("mix", 0, 2)
	b[0].connect_ports(b[1][0], 0, split, 0)
	b[0].connect_ports(split, 0, mix, 0)
	b[0].connect_ports(split, 1, h1, 0)
	b[0].connect_ports(h1, 0, h2, 0)
	b[0].connect_ports(h2, 0, mix, 1)
	b[0].connect_ports(mix, 0, b[2], 0)
	check(run(b[0], [seq("RYBWOK")], "POGWKK").status == S.SOLVED, "uneven branches pair up the right drops")


func test_unconnected() -> void:
	var b := bench(1)
	var mix: int = b[0].add_node("mix", 0, 0)
	b[0].connect_ports(b[1][0], 0, mix, 0)
	b[0].connect_ports(mix, 0, b[2], 0)
	var sim := run(b[0], [seq("RR")], "RR")
	check(sim.status == S.STALLED and sim.woven.size() == 0, "a mix with one empty input never fires")

	var m = Machine.new()
	m.add_node("red_pot", 0, 0)
	m.add_node(Pieces.LOOM)
	sim = Simulator.new(m, [], seq("R"))
	sim.run()
	check(sim.status == S.STALLED and sim.tick == 0, "a pot with no tube never fires")


func test_wrong_stitch() -> void:
	var b := bench(1)
	b[0].connect_ports(b[1][0], 0, b[2], 0)
	var sim := run(b[0], [seq("RYBW")], "RYYW")
	check(sim.status == S.WRONG, "a wrong stitch stops the run")
	check(sim.wrong_index == 2 and sim.woven.size() == 3, "stops at the first wrong stitch (index %d)" % sim.wrong_index)
	var ticks := sim.tick
	sim.step()
	check(sim.tick == ticks, "a finished run does not advance")


func test_stall_and_run_out() -> void:
	var b := bench(1)
	b[0].connect_ports(b[1][0], 0, b[2], 0)
	var sim := run(b[0], [seq("RR")], "RRR")
	check(sim.status == S.STALLED and sim.woven.size() == 2, "a card that runs out stalls the loom")
	var empty := bench(0)
	sim = run(empty[0], [], "R")
	check(sim.status == S.STALLED and sim.tick == 0, "an empty bench stalls at once")


## Builds Invert(Mix(A, B)) with its nodes added in the given order.
func third_color(order: Array):
	var m = Machine.new()
	var ids := {}
	for name in order:
		match name:
			"a":
				ids[name] = m.add_node(Pieces.CARD, 0, 0, {"card": 0})
			"b":
				ids[name] = m.add_node(Pieces.CARD, 0, 0, {"card": 1})
			"loom":
				ids[name] = m.add_node(Pieces.LOOM)
			_:
				ids[name] = m.add_node(name, 0, 0)
	m.connect_ports(ids["invert"], 0, ids["loom"], 0)
	m.connect_ports(ids["mix"], 0, ids["invert"], 0)
	m.connect_ports(ids["b"], 0, ids["mix"], 1)
	m.connect_ports(ids["a"], 0, ids["mix"], 0)
	return m


func test_order_independence() -> void:
	var cards := [seq("RYBRYB"), seq("YBRBRY")]
	var target := "BRYYBR"
	var first := ""
	for order in [["a", "b", "mix", "invert", "loom"], ["loom", "invert", "mix", "b", "a"], ["mix", "loom", "a", "invert", "b"]]:
		var sim := Simulator.new(third_color(order), cards, seq(target))
		sim.run()
		check(sim.status == S.SOLVED, "third color solves in node order %s" % str(order))
		if first == "":
			first = sim.signature()
		check(sim.signature() == first, "result does not depend on node order %s" % str(order))


func test_determinism() -> void:
	var level = Level.load_file("res://levels/black_cat.json")
	var runs := []
	for n in 2:
		var sim := Simulator.new(level.reference_machine(), level.cards, level.target)
		var trace := PackedStringArray()
		while sim.status == S.RUNNING:
			sim.step()
			trace.append(sim.signature())
		runs.append("\n".join(trace))
	check(runs[0] == runs[1], "the same machine runs the same way twice")


func test_machine_edits() -> void:
	var b := bench(1)
	var m = b[0]
	var inv: int = m.add_node("invert", 2, 1)
	m.connect_ports(b[1][0], 0, inv, 0)
	m.connect_ports(inv, 0, b[2], 0)
	check(m.piece_at(2, 1) == inv and m.piece_at(1, 1) == -1, "piece_at finds placed pieces")
	var shift: int = m.add_node("shift", 3, 1)
	m.connect_ports(shift, 0, b[2], 0)
	check(m.tubes.size() == 2 and m.tube_into(b[2], 0) == m.tube_from(shift, 0), "a new tube replaces the old one on the same port")
	m.remove_node(shift)
	check(m.tubes.size() == 1, "removing a piece removes its tubes")
	var copy = Machine.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(copy.to_dict() == m.to_dict(), "machine survives a JSON round trip")
	check(copy.add_node("mix") > inv, "new ids continue after loading")
	check(m.cost({}) == 1 and m.piece_counts({}) == {"invert": 1}, "cost and counts")
