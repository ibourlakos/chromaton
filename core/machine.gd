## A machine: the nodes on the bench and the tubes between them.
##
## Plain data so it saves as JSON and copies cheaply. A node is a Dictionary:
##   {"id": int, "kind": String, "x": int, "y": int}
## plus "card": int for pattern cards and "invention": String for inventions.
## Pieces sit on spots (x, y), every half cell of the bench (GRID spots a
## cell; a piece still covers a whole cell); cards and the loom are placed by
## the level, a card on the row in its "row" (whole rows; without one the
## workbench puts it on its default row).
## A tube joins one output port to one input port:
##   {"from": id, "fp": port, "to": id, "tp": port}
## Every port holds at most one tube.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")

const GRID := 2  # spots per cell, each way (DESIGN.md 9.1, half-cell snapping)

var nodes := {}
var tubes: Array = []
var next_id := 1


func add_node(kind: String, x := 0, y := 0, extra := {}) -> int:
	var id := next_id
	next_id += 1
	var node := {"id": id, "kind": kind, "x": x, "y": y}
	node.merge(extra)
	nodes[id] = node
	return id


func remove_node(id: int) -> void:
	nodes.erase(id)
	tubes = tubes.filter(func(t): return t["from"] != id and t["to"] != id)


func move_node(id: int, x: int, y: int) -> void:
	nodes[id]["x"] = x
	nodes[id]["y"] = y


func is_fixed(id: int) -> bool:
	var kind: String = nodes[id]["kind"]
	return kind == Pieces.CARD or kind == Pieces.LOOM


## The placed piece on spot (x, y), or -1.
func piece_at(x: int, y: int) -> int:
	for id in nodes:
		if not is_fixed(id) and nodes[id]["x"] == x and nodes[id]["y"] == y:
			return id
	return -1


func find_kind(kind: String, card := -1) -> int:
	for id in nodes:
		var n: Dictionary = nodes[id]
		if n["kind"] == kind and (card < 0 or int(n.get("card", -1)) == card):
			return id
	return -1


## Index of the tube leaving output port (id, port), or -1.
func tube_from(id: int, port: int) -> int:
	for i in tubes.size():
		if tubes[i]["from"] == id and tubes[i]["fp"] == port:
			return i
	return -1


## Index of the tube entering input port (id, port), or -1.
func tube_into(id: int, port: int) -> int:
	for i in tubes.size():
		if tubes[i]["to"] == id and tubes[i]["tp"] == port:
			return i
	return -1


## Lays a tube, replacing whatever was on either port.
func connect_ports(from: int, fp: int, to: int, tp: int) -> void:
	tubes = tubes.filter(func(t): return not ((t["from"] == from and t["fp"] == fp) or (t["to"] == to and t["tp"] == tp)))
	tubes.append({"from": from, "fp": fp, "to": to, "tp": tp})


func remove_tube(index: int) -> void:
	tubes.remove_at(index)


## Drops tubes whose ports no longer exist (for example a missing invention).
func prune(inventions: Dictionary) -> void:
	var kept := []
	for t in tubes:
		if not nodes.has(t["from"]) or not nodes.has(t["to"]):
			continue
		var a := Pieces.ports(nodes[t["from"]], inventions)
		var b := Pieces.ports(nodes[t["to"]], inventions)
		if t["fp"] < a.y and t["tp"] < b.x:
			kept.append(t)
	tubes = kept


## Pieces metric: placed pieces, splits free, inventions at their full price.
func cost(inventions: Dictionary) -> int:
	var total := 0
	for id in nodes:
		total += Pieces.cost(nodes[id], inventions)
	return total


## How many of each basic piece the machine is made of, inventions opened up.
func piece_counts(inventions: Dictionary) -> Dictionary:
	var counts := {}
	for id in nodes:
		var n: Dictionary = nodes[id]
		var kind: String = n["kind"]
		if Pieces.is_piece(kind):
			if Pieces.cost(n, inventions) > 0:
				counts[kind] = counts.get(kind, 0) + 1
		elif kind == Pieces.INVENTION:
			var inner: Dictionary = inventions.get(n.get("invention", ""), {}).get("counts", {})
			for k in inner:
				counts[k] = counts.get(k, 0) + int(inner[k])
	return counts


func to_dict() -> Dictionary:
	var list := []
	var ids := nodes.keys()
	ids.sort()
	for id in ids:
		list.append(nodes[id].duplicate())
	return {"nodes": list, "tubes": tubes.duplicate(true), "next_id": next_id, "grid": GRID}


## Builds a machine from saved data (JSON numbers arrive as floats). A
## machine saved without "grid" was laid on whole cells: its pieces move to
## the matching spots, so old saves stay valid.
static func from_dict(d: Dictionary):
	var m = load("res://core/machine.gd").new()
	var scale: int = GRID / maxi(1, int(d.get("grid", 1)))
	for raw in d.get("nodes", []):
		var n: Dictionary = raw.duplicate()
		n["id"] = int(n["id"])
		n["x"] = int(n.get("x", 0)) * scale
		n["y"] = int(n.get("y", 0)) * scale
		if n.has("card"):
			n["card"] = int(n["card"])
		if n.has("row"):
			n["row"] = int(n["row"])
		m.nodes[n["id"]] = n
		m.next_id = maxi(m.next_id, n["id"] + 1)
	for t in d.get("tubes", []):
		m.tubes.append({"from": int(t["from"]), "fp": int(t["fp"]), "to": int(t["to"]), "tp": int(t["tp"])})
	m.next_id = maxi(m.next_id, int(d.get("next_id", 1)))
	return m


func duplicate():
	return from_dict(to_dict())
