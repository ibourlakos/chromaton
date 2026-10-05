## Inventions: a solved machine packaged as a new piece for the Pattern Book.
##
## The level's pattern cards become the invention's input ports (in card
## order) and the loom becomes its one output port. The simulator runs an
## invention as one piece that takes one tick, looking up what the machine
## inside makes (exact, because of the every-paint check below).
## Its piece cost is the total of the pieces inside it (inventions inside at
## their own price) minus one, never below 1: the invention discount
## (DESIGN.md 5.1), so inventing pays on Pieces too, and it compounds.
##
## A color pot is an invention with no inputs (check "paint:<letter>", e.g.
## "paint:Y"): each paint-box level packages its machine as a pot of that
## color.
extends RefCounted

const Paint = preload("res://core/paint.gd")
const Machine = preload("res://core/machine.gd")
const Simulator = preload("res://core/simulator.gd")

const LETTERS := "WRYOBPGK"


## Packages the player's machine for an invention level.
static func package(level, machine, inventions: Dictionary) -> Dictionary:
	return {
		"id": level.invention["id"],
		"name": level.invention["name"],
		"check": level.invention["check"],
		"inputs": level.cards.size(),
		"cost": price(machine.cost(inventions)),
		"counts": machine.piece_counts(inventions),
		"machine": machine.to_dict(),
		"from_level": level.id,
	}


## What an invention made by a machine of this many pieces costs: one less,
## never below 1 (the invention discount).
static func price(machine_cost: int) -> int:
	return maxi(1, machine_cost - 1)


## Every invention the levels earn, packaged from the levels' reference
## solutions, the cheaper machine winning where two levels earn the same one
## (as a player's save keeps it). So each costs its cheapest price: what
## force unlock lends.
static func reference_inventions(levels: Array) -> Dictionary:
	var by_level := reference_inventions_by_level(levels)
	return by_level[by_level.size() - 1]


## What each level can count on, in campaign order: the inventions the levels
## before it earn, each at the cheapest price so far (a pot re-earned cheaper
## later in the campaign costs its old price until then), plus, as the last
## entry, everything at its cheapest. What the solver and the card maker
## search with, and what star thresholds assume.
static func reference_inventions_by_level(levels: Array) -> Array:
	var out := []
	var inventions := {}
	for level in levels:
		out.append(inventions)
		if not level.invention.is_empty():
			var inv := package(level, level.reference_machine(), inventions)
			var old: Dictionary = inventions.get(inv["id"], {})
			if old.is_empty() or int(inv["cost"]) <= int(old["cost"]):
				inventions = inventions.duplicate()
				inventions[inv["id"]] = inv
	out.append(inventions)
	return out


## The paint a pot makes, or -1 if this invention (or level invention entry,
## anything with a "check") isn't a pot.
static func paint_of(inv: Dictionary) -> int:
	var check := str(inv.get("check", ""))
	if not check.begins_with("paint:"):
		return -1
	return LETTERS.find(check.substr(6))


## The color an invention with this check should make from these inputs.
static func expected(check: String, ins: Array) -> int:
	if check.begins_with("paint:") and LETTERS.find(check.substr(6)) >= 0:
		return LETTERS.find(check.substr(6))
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
		"third_paint":  # what neither paint has
			return Paint.invert(Paint.mix(ins[0], ins[1]))
		"missing_from_either":  # what one paint or the other lacks
			return Paint.invert(Paint.filter(ins[0], ins[1]))
		"same_paint":  # what both paints have or both lack
			return Paint.invert(Paint.contrast(ins[0], ins[1]))
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
