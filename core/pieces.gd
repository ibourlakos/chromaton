## The placeable pieces, as one data table.
##
## Each entry gives the display name, the number of input and output ports,
## the operation the piece performs, its piece cost, and how it is drawn
## ("look"). Adding a piece is one new entry: the generic "tub" look draws any
## vat, so a new two-input vat is one line.
##
## Pattern cards, the loom and inventions are not in the table: cards and the
## loom are fixed parts of a level, and an invention's ports come from the
## machine inside it.
extends RefCounted

const Paint = preload("res://core/paint.gd")

const TABLE := {
	"red_pot": {"name": "Red pot", "inputs": 0, "outputs": 1, "op": "red", "cost": 1, "look": "pot"},
	"mix": {"name": "Mix", "inputs": 2, "outputs": 1, "op": "mix", "cost": 1, "look": "mix"},
	# Keeps only the paint both inputs share (DESIGN.md 2.5, the middle kit).
	"filter": {"name": "Filter", "inputs": 2, "outputs": 1, "op": "filter", "cost": 1, "look": "filter"},
	"invert": {"name": "Invert", "inputs": 1, "outputs": 1, "op": "invert", "cost": 1, "look": "invert"},
	"shift": {"name": "Shift", "inputs": 1, "outputs": 1, "op": "shift", "cost": 1, "look": "shift"},
	"split": {"name": "Split", "inputs": 1, "outputs": 2, "op": "copy", "cost": 0, "look": "split"},
	# Swallows every drop it is given and remembers the last few (for looking
	# at what flows through a machine). Free, like Split.
	"catch_pot": {"name": "Catch pot", "inputs": 1, "outputs": 0, "op": "catch", "cost": 0, "look": "catch"},
}

const CARD := "card"
const LOOM := "loom"
const INVENTION := "invention"


static func is_piece(kind: String) -> bool:
	return TABLE.has(kind)


static func display_name(kind: String) -> String:
	return TABLE[kind]["name"] if TABLE.has(kind) else kind.capitalize()


## Input and output port counts of a machine node.
static func ports(node: Dictionary, inventions: Dictionary) -> Vector2i:
	var kind: String = node["kind"]
	if TABLE.has(kind):
		return Vector2i(TABLE[kind]["inputs"], TABLE[kind]["outputs"])
	match kind:
		CARD:
			return Vector2i(0, 1)
		LOOM:
			return Vector2i(1, 0)
		INVENTION:
			var inv: Dictionary = inventions.get(node.get("invention", ""), {})
			return Vector2i(int(inv.get("inputs", 0)), 1 if not inv.is_empty() else 0)
	return Vector2i.ZERO


## Piece cost of one node. Inventions cost what is inside them.
static func cost(node: Dictionary, inventions: Dictionary) -> int:
	var kind: String = node["kind"]
	if TABLE.has(kind):
		return TABLE[kind]["cost"]
	if kind == INVENTION:
		return int(inventions.get(node.get("invention", ""), {}).get("cost", 0))
	return 0


## Runs an operation on the colors at its inputs; returns one color per output.
static func apply(op: String, ins: Array) -> Array:
	match op:
		"red":
			return [Paint.RED]
		"mix":
			return [Paint.mix(ins[0], ins[1])]
		"filter":
			return [Paint.filter(ins[0], ins[1])]
		"invert":
			return [Paint.invert(ins[0])]
		"shift":
			return [Paint.shift(ins[0])]
		"catch":
			return [ins[0]]
		"copy":
			return [ins[0], ins[0]]
	push_error("unknown piece operation: " + op)
	return []
