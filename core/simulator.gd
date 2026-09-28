## Runs a machine on a level's pattern cards, one tick at a time.
##
## Dataflow with one-drop tubes (DESIGN.md 9):
## - every tube holds at most one drop;
## - on each tick a piece fires if every input tube holds a drop and every
##   output tube is empty; it takes one drop per input and puts its result in
##   its output tubes (a split puts a copy in each);
## - a red pot fires whenever its tube is empty; a pattern card releases its
##   next color whenever its tube is empty, until it runs out;
## - the loom takes one drop per tick and weaves the next stitch; a catch pot
##   takes one drop per tick and keeps it;
## - every node decides from the state at the start of the tick, so the result
##   never depends on the order nodes are visited.
##
## Inventions are flattened: the machine inside is wired straight into the
## outer tubes (its cards become the outer input tubes, its loom the outer
## output tube), so an invention behaves exactly like the machine inside.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")
const Machine = preload("res://core/machine.gd")

enum Status { RUNNING, SOLVED, WRONG, STALLED }

const MAX_TICKS := 20000
const MAX_DEPTH := 16

var tick := 0
var status := Status.RUNNING
var woven := PackedByteArray()
var wrong_index := -1
var last_weave_tick := 0
var target := PackedByteArray()
var cards: Array = []
var card_cursor := PackedInt32Array()

# The flat network: every piece at any invention depth, plus the top-level
# cards and loom. Node "kind" is "card", "loom" or a piece operation.
var drops := PackedInt32Array()       # per tube: its color, or -1 when empty
var filled_at := PackedInt32Array()   # per tube: tick its drop arrived
var node_kind: Array = []
var node_ins: Array = []              # per node: PackedInt32Array of tubes (-1 = none)
var node_outs: Array = []
var node_card := PackedInt32Array()
var last_fire := PackedInt32Array()   # per node: tick it last fired (0 = never)
var last_color := PackedInt32Array()  # per node: color it last made or wove
var fire_count := PackedInt32Array()
var caught := {}  # per catch-pot node: the colors it swallowed, oldest first

const CAUGHT_KEPT := 8

var tube_of := {}   # top-level tube index -> flat tube
var nodes_of := {}  # top-level node id -> Array of flat nodes (all pieces inside an invention)

var _parent := PackedInt32Array()


func _init(machine, level_cards: Array, level_target: PackedByteArray, inventions := {}) -> void:
	cards = level_cards
	target = level_target
	card_cursor.resize(cards.size())
	card_cursor.fill(0)
	_expand(machine, inventions, [], -1, true, -1, 0)
	var index := {}
	for i in node_kind.size():
		node_ins[i] = _renumber(node_ins[i], index)
		node_outs[i] = _renumber(node_outs[i], index)
	for k in tube_of:
		tube_of[k] = _renumber_one(tube_of[k], index)
	drops.resize(index.size())
	drops.fill(-1)
	filled_at.resize(index.size())
	filled_at.fill(0)
	last_fire.resize(node_kind.size())
	last_color.resize(node_kind.size())
	fire_count.resize(node_kind.size())
	last_fire.fill(0)
	last_color.fill(-1)
	fire_count.fill(0)


# ---------------------------------------------------------------------------
# Building the flat network
# ---------------------------------------------------------------------------

func _expand(machine, inventions: Dictionary, bind_in: Array, bind_out: int, top: bool, owner: int, depth: int) -> void:
	if depth > MAX_DEPTH:
		push_error("inventions nested too deeply")
		return
	var raw := []
	for i in machine.tubes.size():
		var r := _new_tube()
		raw.append(r)
		if top:
			tube_of[i] = r
	var ids: Array = machine.nodes.keys()
	ids.sort()
	for id in ids:
		var n: Dictionary = machine.nodes[id]
		var kind: String = n["kind"]
		var who: int = id if top else owner
		var p := Pieces.ports(n, inventions)
		var ins := PackedInt32Array()
		for k in p.x:
			var ti: int = machine.tube_into(id, k)
			ins.append(raw[ti] if ti >= 0 else -1)
		var outs := PackedInt32Array()
		for k in p.y:
			var ti: int = machine.tube_from(id, k)
			outs.append(raw[ti] if ti >= 0 else -1)
		match kind:
			Pieces.CARD:
				if top:
					_add_node("card", ins, outs, int(n["card"]), who)
				else:
					var c := int(n["card"])
					_union(outs[0], bind_in[c] if c < bind_in.size() else -1)
			Pieces.LOOM:
				if top:
					_add_node("loom", ins, outs, -1, who)
				else:
					_union(ins[0], bind_out)
			Pieces.INVENTION:
				var inv: Dictionary = inventions.get(n.get("invention", ""), {})
				if inv.is_empty():
					continue
				var inner = Machine.from_dict(inv["machine"])
				_expand(inner, inventions, Array(ins), outs[0] if outs.size() > 0 else -1, false, who, depth + 1)
			_:
				if Pieces.is_piece(kind):
					_add_node(Pieces.TABLE[kind]["op"], ins, outs, -1, who)


func _add_node(kind: String, ins: PackedInt32Array, outs: PackedInt32Array, card: int, owner: int) -> void:
	var i := node_kind.size()
	node_kind.append(kind)
	node_ins.append(ins)
	node_outs.append(outs)
	node_card.append(card)
	if owner >= 0:
		if not nodes_of.has(owner):
			nodes_of[owner] = []
		nodes_of[owner].append(i)


func _new_tube() -> int:
	_parent.append(_parent.size())
	return _parent.size() - 1


func _find(t: int) -> int:
	while _parent[t] != t:
		_parent[t] = _parent[_parent[t]]
		t = _parent[t]
	return t


func _union(a: int, b: int) -> void:
	if a < 0 or b < 0:
		return
	a = _find(a)
	b = _find(b)
	if a != b:
		_parent[a] = b


func _renumber_one(raw: int, index: Dictionary) -> int:
	if raw < 0:
		return -1
	var r := _find(raw)
	if not index.has(r):
		index[r] = index.size()
	return index[r]


func _renumber(list: PackedInt32Array, index: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for raw in list:
		out.append(_renumber_one(raw, index))
	return out


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

func _can_fire(i: int) -> bool:
	for t in node_ins[i]:
		if t < 0 or drops[t] < 0:
			return false
	for t in node_outs[i]:
		if t < 0 or drops[t] >= 0:
			return false
	match node_kind[i]:
		"card":
			var c: int = node_card[i]
			return card_cursor[c] < cards[c].size()
		"loom":
			return woven.size() < target.size()
	return true


## Advances one tick. Does nothing once the run has ended.
func step() -> void:
	if status != Status.RUNNING:
		return
	if tick >= MAX_TICKS:
		status = Status.STALLED
		return
	var firing := PackedInt32Array()
	for i in node_kind.size():
		if _can_fire(i):
			firing.append(i)
	if firing.is_empty():
		status = Status.STALLED
		return
	tick += 1
	var results := []
	var wrong := false
	for i in firing:
		var colors := []
		for t in node_ins[i]:
			colors.append(drops[t])
		match node_kind[i]:
			"card":
				var c: int = node_card[i]
				results.append([int(cards[c][card_cursor[c]])])
				card_cursor[c] += 1
			"loom":
				var idx := woven.size()
				woven.append(colors[0])
				last_weave_tick = tick
				if colors[0] != target[idx] and not wrong:
					wrong = true
					wrong_index = idx
				results.append([colors[0]])
			_:
				results.append(Pieces.apply(node_kind[i], colors))
	for i in firing:
		for t in node_ins[i]:
			drops[t] = -1
	for k in firing.size():
		var i: int = firing[k]
		var res: Array = results[k]
		var outs: PackedInt32Array = node_outs[i]
		for j in outs.size():
			drops[outs[j]] = res[j]
			filled_at[outs[j]] = tick
		last_fire[i] = tick
		last_color[i] = res[0]
		fire_count[i] += 1
		if node_kind[i] == "catch":
			var list: Array = caught.get(i, [])
			list.append(res[0])
			if list.size() > CAUGHT_KEPT:
				list.pop_front()
			caught[i] = list
	if wrong:
		status = Status.WRONG
	elif woven.size() == target.size():
		status = Status.SOLVED


## Runs until the loom is full, a stitch is wrong or nothing can move.
func run(max_ticks := MAX_TICKS) -> int:
	while status == Status.RUNNING and tick < max_ticks:
		step()
	if status == Status.RUNNING and tick >= MAX_TICKS:
		status = Status.STALLED
	return status


# ---------------------------------------------------------------------------
# Views for the workbench
# ---------------------------------------------------------------------------

## Color in a top-level tube, or -1.
func tube_drop(tube_index: int) -> int:
	var t: int = tube_of.get(tube_index, -1)
	return drops[t] if t >= 0 else -1


## Tick the drop in a top-level tube arrived.
func tube_filled_at(tube_index: int) -> int:
	var t: int = tube_of.get(tube_index, -1)
	return filled_at[t] if t >= 0 else 0


## Most recent tick any part of a top-level node fired (0 = never).
func node_last_fire(node_id: int) -> int:
	var best := 0
	for i in nodes_of.get(node_id, []):
		best = maxi(best, last_fire[i])
	return best


## Color a top-level piece last made (-1 = none yet).
func node_color(node_id: int) -> int:
	var list: Array = nodes_of.get(node_id, [])
	return last_color[list[0]] if list.size() == 1 else -1


func node_fire_count(node_id: int) -> int:
	var list: Array = nodes_of.get(node_id, [])
	return fire_count[list[0]] if list.size() > 0 else 0


## The last colors a top-level catch pot swallowed, newest first.
func node_caught(node_id: int) -> Array:
	var list: Array = nodes_of.get(node_id, [])
	if list.size() != 1:
		return []
	var out: Array = caught.get(list[0], []).duplicate()
	out.reverse()
	return out


func card_remaining(card: int) -> int:
	return cards[card].size() - card_cursor[card]


## A compact fingerprint of the whole state, for determinism checks.
func signature() -> String:
	return "%d|%d|%s|%s|%s" % [tick, status, str(woven), str(drops), str(card_cursor)]
