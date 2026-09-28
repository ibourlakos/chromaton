## Inventions: a solved machine packaged as a new piece for the Pattern Book.
##
## The level's pattern cards become the invention's input ports (in card
## order) and the loom becomes its one output port. The simulator runs an
## invention as one piece that takes one tick, looking up what the machine
## inside makes (exact, because of the every-paint check below).
## Its piece cost is the total of the pieces inside it.
extends RefCounted

const Paint = preload("res://core/paint.gd")
const Machine = preload("res://core/machine.gd")
const Simulator = preload("res://core/simulator.gd")


## Packages the player's machine for an invention level.
static func package(level, machine, inventions: Dictionary) -> Dictionary:
	return {
		"id": level.invention["id"],
		"name": level.invention["name"],
		"inputs": level.cards.size(),
		"cost": machine.cost(inventions),
		"counts": machine.piece_counts(inventions),
		"machine": machine.to_dict(),
		"from_level": level.id,
	}


## The color an invention with this check should make from these inputs.
static func expected(check: String, ins: Array) -> int:
	match check:
		"filter":
			return Paint.filter(ins[0], ins[1])
		"mix":
			return Paint.mix(ins[0], ins[1])
		"bleach":
			return Paint.bleach(ins[0], ins[1])
		"contrast":
			return Paint.contrast(ins[0], ins[1])
		"invert":
			return Paint.invert(ins[0])
		"shift":
			return Paint.shift(ins[0])
	push_error("unknown invention check: " + check)
	return -1


## True if the machine gives the right color for every combination of input
## paints, not just the ones on the level's cards.
static func works_for_every_paint(machine, input_count: int, check: String, inventions: Dictionary) -> bool:
	var total := int(pow(8, input_count))
	var columns := []
	for k in input_count:
		columns.append([])
	var target := PackedByteArray()
	for n in total:
		var ins := []
		var rest := n
		for k in input_count:
			ins.append(rest % 8)
			columns[k].append(rest % 8)
			rest /= 8
		target.append(expected(check, ins))
	var cards := []
	for column in columns:
		cards.append(PackedByteArray(column))
	var sim = Simulator.new(machine, cards, target, inventions)
	return sim.run() == Simulator.Status.SOLVED
