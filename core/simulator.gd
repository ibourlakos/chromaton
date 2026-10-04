## Runs a machine on a level's pattern cards, one tick at a time.
##
## Dataflow with one-drop tubes (DESIGN.md 9):
## - every tube holds at most one drop;
## - on each tick a piece fires if every input tube holds a drop and every
##   output tube is empty or is being emptied this same tick (a chain
##   reaction); it takes one drop per input and puts its result in its output
##   tubes (a split puts a copy in each);
## - a red pot fires whenever its tube is free; a pattern card releases its
##   next color whenever its tube is free, until it runs out;
## - the loom takes one drop per tick and weaves the next stitch; a catch pot
##   takes one drop per tick and keeps it;
## - every node decides from the state at the start of the tick, so the result
##   never depends on the order nodes are visited;
## - every card must be used: a card with no tube out of it fails the run
##   before it starts, and a card still holding paint when the loom is full
##   fails it at the end.
##
## An invention is one piece that takes one tick (DESIGN.md 5.1): it looks its
## answer up in a table of what the machine inside makes from every
## combination of input paints. The every-paint check makes that table exact.
extends RefCounted

const Pieces = preload("res://core/pieces.gd")
const Machine = preload("res://core/machine.gd")

enum Status { RUNNING, SOLVED, WRONG, STALLED, UNUSED }

const MAX_TICKS := 20000
const MAX_DEPTH := 16
const NO_COLOR := 255  # a table entry where the machine inside makes nothing

var tick := 0
var status := Status.RUNNING
var woven := PackedByteArray()
var wrong_index := -1
var unused_card := -1  # the card an UNUSED run left out
var last_weave_tick := 0
var target := PackedByteArray()
var cards: Array = []
var card_cursor := PackedInt32Array()

# The network: one node per card, loom, piece and invention, one tube per
# machine tube. Node "kind" is "card", "loom", "table" (an invention) or a
# piece operation.
var drops := PackedInt32Array()       # per tube: its color, or -1 when empty
var filled_at := PackedInt32Array()   # per tube: tick its drop arrived
var consumer := PackedInt32Array()    # per tube: the node it feeds (-1 = none)
var node_kind: Array = []
var node_ins: Array = []              # per node: PackedInt32Array of tubes (-1 = none)
var node_outs: Array = []
var node_card := PackedInt32Array()
var node_table: Array = []            # per node: an invention's PackedByteArray
var last_fire := PackedInt32Array()   # per node: tick it last fired (0 = never)
var last_color := PackedInt32Array()  # per node: color it last made or wove
var fire_count := PackedInt32Array()
var caught := {}  # per catch-pot node: the colors it swallowed, oldest first

const CAUGHT_KEPT := 8

var node_of := {}  # machine node id -> network node (missing inventions have none)


func _init(machine, level_cards: Array, level_target: PackedByteArray, inventions := {}) -> void:
	cards = level_cards
	target = level_target
	card_cursor.resize(cards.size())
	card_cursor.fill(0)
	var tables := {}
	var ids: Array = machine.nodes.keys()
	ids.sort()
	for id in ids:
		var n: Dictionary = machine.nodes[id]
		var kind: String = n["kind"]
		var table := PackedByteArray()
		match kind:
			Pieces.CARD, Pieces.LOOM:
				pass
			Pieces.INVENTION:
				var inv_id: String = n.get("invention", "")
				if not inventions.has(inv_id):
					continue
				if not tables.has(inv_id):
					tables[inv_id] = invention_table(inventions[inv_id], inventions)
				table = tables[inv_id]
				kind = "table"
			_:
				if not Pieces.is_piece(kind):
					continue
				kind = Pieces.TABLE[kind]["op"]
		var p := Pieces.ports(n, inventions)
		var ins := PackedInt32Array()
		for k in p.x:
			ins.append(machine.tube_into(id, k))
		var outs := PackedInt32Array()
		for k in p.y:
			outs.append(machine.tube_from(id, k))
		node_of[id] = node_kind.size()
		node_kind.append(kind)
		node_ins.append(ins)
		node_outs.append(outs)
		node_card.append(int(n.get("card", -1)))
		node_table.append(table)
	var tube_count: int = machine.tubes.size()
	drops.resize(tube_count)
	drops.fill(-1)
	filled_at.resize(tube_count)
	filled_at.fill(0)
	consumer.resize(tube_count)
	consumer.fill(-1)
	for i in node_kind.size():
		for t in node_ins[i]:
			if t >= 0:
				consumer[t] = i
	last_fire.resize(node_kind.size())
	last_color.resize(node_kind.size())
	fire_count.resize(node_kind.size())
	last_fire.fill(0)
	last_color.fill(-1)
	fire_count.fill(0)
	var wired := []
	wired.resize(cards.size())
	wired.fill(false)
	for i in node_kind.size():
		var c: int = node_card[i]
		if node_kind[i] == "card" and c >= 0 and c < cards.size() and not node_outs[i].has(-1):
			wired[c] = true
	unused_card = wired.find(false)
	if unused_card >= 0:
		status = Status.UNUSED


# ---------------------------------------------------------------------------
# Inventions
# ---------------------------------------------------------------------------

## What an invention's machine makes from every combination of input paints.
## Input k's color counts 8^k in the index; NO_COLOR where it makes nothing.
static func invention_table(inv: Dictionary, inventions: Dictionary, depth := 0) -> PackedByteArray:
	var input_count := int(inv.get("inputs", 0))
	var table := PackedByteArray()
	table.resize(int(pow(8, input_count)))
	table.fill(NO_COLOR)
	if depth > MAX_DEPTH:
		push_error("inventions nested too deeply")
		return table
	var machine = Machine.from_dict(inv.get("machine", {}))
	var loom: int = machine.find_kind(Pieces.LOOM)
	var into: int = machine.tube_into(loom, 0) if loom >= 0 else -1
	if into < 0:
		return table
	var inner_tables := {}
	for index in table.size():
		var ins := []
		var rest := index
		for k in input_count:
			ins.append(rest % 8)
			rest /= 8
		var color := _tube_color(machine, into, ins, inventions, inner_tables, {}, depth)
		if color >= 0:
			table[index] = color
	return table


## The color a tube of an invention's machine carries for these input paints,
## or -1 if nothing reaches it.
static func _tube_color(machine, tube: int, ins: Array, inventions: Dictionary, tables: Dictionary, memo: Dictionary, depth: int) -> int:
	if memo.has(tube):
		return memo[tube]
	memo[tube] = -1
	var t: Dictionary = machine.tubes[tube]
	var n: Dictionary = machine.nodes[t["from"]]
	var kind: String = n["kind"]
	var colors := []
	for k in Pieces.ports(n, inventions).x:
		var into: int = machine.tube_into(n["id"], k)
		var c := _tube_color(machine, into, ins, inventions, tables, memo, depth) if into >= 0 else -1
		if c < 0:
			return -1
		colors.append(c)
	var color := -1
	match kind:
		Pieces.CARD:
			var card := int(n.get("card", -1))
			color = ins[card] if card >= 0 and card < ins.size() else -1
		Pieces.INVENTION:
			var inv_id: String = n.get("invention", "")
			if inventions.has(inv_id):
				if not tables.has(inv_id):
					tables[inv_id] = invention_table(inventions[inv_id], inventions, depth + 1)
				var v: int = tables[inv_id][_index_of(colors)]
				color = v if v != NO_COLOR else -1
		_:
			if Pieces.is_piece(kind):
				var made: Array = Pieces.apply(Pieces.TABLE[kind]["op"], colors)
				color = made[t["fp"]] if t["fp"] < made.size() else -1
	memo[tube] = color
	return color


static func _index_of(colors: Array) -> int:
	var index := 0
	for k in range(colors.size() - 1, -1, -1):
		index = index * 8 + colors[k]
	return index


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

## True if node i has what it needs to fire, not counting full output tubes.
func _ready_to_fire(i: int) -> bool:
	for t in node_ins[i]:
		if t < 0 or drops[t] < 0:
			return false
	for t in node_outs[i]:
		if t < 0:
			return false
	match node_kind[i]:
		"card":
			var c: int = node_card[i]
			return card_cursor[c] < cards[c].size()
		"loom":
			return woven.size() < target.size()
		"table":
			return node_table[i][_index_of(_colors_in(i))] != NO_COLOR
	return true


func _colors_in(i: int) -> Array:
	var colors := []
	for t in node_ins[i]:
		colors.append(drops[t])
	return colors


## The nodes that fire this tick: ready nodes whose every output tube is empty
## or is emptied this tick by a node that fires. The set only grows while it
## is worked out, so it doesn't depend on the order nodes are visited.
func _firing() -> PackedInt32Array:
	var ready := []
	for i in node_kind.size():
		ready.append(_ready_to_fire(i))
	var fires := []
	fires.resize(node_kind.size())
	fires.fill(false)
	var changed := true
	while changed:
		changed = false
		for i in node_kind.size():
			if fires[i] or not ready[i]:
				continue
			var free := true
			for t in node_outs[i]:
				if drops[t] >= 0 and (consumer[t] < 0 or not fires[consumer[t]]):
					free = false
					break
			if free:
				fires[i] = true
				changed = true
	var out := PackedInt32Array()
	for i in node_kind.size():
		if fires[i]:
			out.append(i)
	return out


## Advances one tick. Does nothing once the run has ended.
func step() -> void:
	if status != Status.RUNNING:
		return
	if tick >= MAX_TICKS:
		status = Status.STALLED
		return
	var firing := _firing()
	if firing.is_empty():
		status = Status.STALLED
		return
	tick += 1
	var results := []
	var wrong := false
	for i in firing:
		var colors := _colors_in(i)
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
			"table":
				results.append([int(node_table[i][_index_of(colors)])])
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
		for c in cards.size():
			if card_remaining(c) > 0:
				unused_card = c
				break
		status = Status.UNUSED if unused_card >= 0 else Status.SOLVED


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

## Color in a tube, or -1.
func tube_drop(tube_index: int) -> int:
	return drops[tube_index] if tube_index >= 0 and tube_index < drops.size() else -1


## Tick the drop in a tube arrived.
func tube_filled_at(tube_index: int) -> int:
	return filled_at[tube_index] if tube_index >= 0 and tube_index < filled_at.size() else 0


## Tick a machine node last fired (0 = never).
func node_last_fire(node_id: int) -> int:
	return last_fire[node_of[node_id]] if node_of.has(node_id) else 0


## Color a machine node last made (-1 = none yet).
func node_color(node_id: int) -> int:
	return last_color[node_of[node_id]] if node_of.has(node_id) else -1


func node_fire_count(node_id: int) -> int:
	return fire_count[node_of[node_id]] if node_of.has(node_id) else 0


## The last colors a catch pot swallowed, newest first.
func node_caught(node_id: int) -> Array:
	if not node_of.has(node_id):
		return []
	var out: Array = caught.get(node_of[node_id], []).duplicate()
	out.reverse()
	return out


func card_remaining(card: int) -> int:
	return cards[card].size() - card_cursor[card]


## A compact fingerprint of the whole state, for determinism checks.
func signature() -> String:
	return "%d|%d|%s|%s|%s" % [tick, status, str(woven), str(drops), str(card_cursor)]
