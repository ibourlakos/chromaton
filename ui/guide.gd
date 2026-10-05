## The guide on a guided level (DESIGN.md 5.7, "Guided levels teach"): show,
## then you do. Each step has one line and what it asks, against the level's
## reference machine ("steps" in the level file):
##   ["place", ref id]        put that piece on the bench
##   ["tube", ref a, ref b]   lay a tube from a to b (any ports; "card0", ...
##                            and "loom" too); listed twice, two tubes
##   ["fan"]                  open the pot slot's fan
##   ["run"]                  run the machine
## A step that asks nothing leads into the next step's line.
##
## The guide never blocks: it reads the bench, so a step already done is
## skipped (in any order, by any route), and a step undone comes back. The
## workbench draws the hand acting out the step's first undone action.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")


## Which bench piece stands for each reference piece: the i-th reference
## piece of a kind is the i-th one of that kind on the bench. Cards and the
## loom by name.
static func bind(level, machine) -> Dictionary:
	var out := {"loom": machine.find_kind(Pieces.LOOM)}
	for i in level.cards.size():
		out["card%d" % i] = machine.find_kind(Pieces.CARD, i)
	var ids: Array = machine.nodes.keys()
	ids.sort()
	var used := {}
	for p in level.reference.get("pieces", []):
		for id in ids:
			var n: Dictionary = machine.nodes[id]
			if not used.has(id) and n["kind"] == p["kind"] and str(n.get("invention", "")) == str(p.get("invention", "")):
				used[id] = true
				out[p["id"]] = id
				break
	return out


## The step to show: {"index", "lines" (lead-in lines, then the step's),
## "action" (its first undone action)}, or {} when every step is done.
## `state` gives what isn't on the bench: {"fan_open", "ran"}.
static func current(level, machine, state: Dictionary) -> Dictionary:
	var bound := bind(level, machine)
	var lead := []
	for i in level.steps.size():
		var step: Dictionary = level.steps[i]
		var acts: Array = step.get("do", [])
		if acts.is_empty():
			lead.append(str(step["line"]))
			continue
		var undone := _first_undone(acts, bound, machine, state)
		if undone.is_empty():
			lead = []
			continue
		return {"index": i, "lines": lead + [str(step["line"])], "action": undone, "bound": bound}
	return {}


static func _first_undone(acts: Array, bound: Dictionary, machine, state: Dictionary) -> Array:
	var wanted := {}  # tube a>b -> how many the step asks for so far
	for a in acts:
		match str(a[0]):
			"place":
				if not bound.has(a[1]):
					return a
			"tube":
				var key := "%s>%s" % [a[1], a[2]]
				wanted[key] = wanted.get(key, 0) + 1
				if tubes_between(machine, bound.get(a[1], -1), bound.get(a[2], -1)) < wanted[key]:
					return a
			"fan":
				if not state.get("fan_open", false) and not _has_pot(machine):
					return a
			"run":
				if not state.get("ran", false):
					return a
	return []


## How many tubes run from piece a to piece b (any ports).
static func tubes_between(machine, a: int, b: int) -> int:
	if a < 0 or b < 0:
		return 0
	return machine.tubes.filter(func(t): return t["from"] == a and t["to"] == b).size()


static func _has_pot(machine) -> bool:
	for id in machine.nodes:
		if str(machine.nodes[id].get("invention", "")).begins_with("pot_"):
			return true
	return false
