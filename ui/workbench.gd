## The workbench: parts tray, bench grid, pattern cards, tubes, the loom and
## the run controls.
##
## Everything on the bench is drawn in _draw(). Every gesture is a
## press-drag-release (no hover, no right-click-only), so mouse and touch work the
## same way:
## - drag a piece from the tray onto a free cell to place it, or tap it to
##   pick it up and tap a free cell to put it down;
## - drag a placed piece to move it, or onto the tray to throw it away;
## - drag from an output port to an input port to lay a tube (or the other
##   way round); drag a tube's end off an input port to re-route or remove it;
## - tap a tube or a placed piece to select it, then tap its delete button.
## Any edit stops the run and rewinds it to the start.
##
## Keys (see keys.gd for the defaults; they can be changed in Options) only
## do what a tap already does: run controls and speed, a tray piece's key
## picks it up (it follows the pointer until a click puts it down), Delete
## removes only what is selected, Back drops a carried piece, then clears the
## selection, then leaves the level. A right-click likewise only speeds up a
## tap: it drops a carried piece.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const SuccessPanel = preload("res://ui/success_panel.gd")
const Pieces = preload("res://core/pieces.gd")
const Machine = preload("res://core/machine.gd")
const Simulator = preload("res://core/simulator.gd")
const Invention = preload("res://core/invention.gd")

signal exit_requested
signal next_requested
signal progress_changed

const DESIGN := Vector2(1280, 800)
const TOP_H := 64.0
# Paint flows left to right: cards sit on the left of the bench (each covers
# the first two cells of its row), the loom stands on the right, and the parts
# tray is a shelf along the bottom.
const TRAY := Rect2(12, 662, 1256, 128)
const TRASH := Rect2(1150, 670, 110, 112)
const BENCH := Rect2(12, 74, 956, 578)
const GRID_ORIGIN := Vector2(24, 84)
const CELL := Vector2(84, 80)
const COLS := 11
const ROWS := 7
const CARD_ROWS := {1: [3], 2: [1, 5], 3: [0, 3, 6]}
const SIDE := Rect2(980, 74, 288, 578)  # design card, loom and status
const PORT_DX := 34.0
const PORT_DY := 17.0
const PORT_HIT := 20.0
const TICK_SECONDS := [0.55, 0.22, 0.05]
const SPEEDS := ["slow", "normal", "fast"]
const PIECE_SCALE := 0.6
const DROP_R := 9.0
const IDLE_AGE := 99.0
## Held keys repeat only where repeating helps: stepping and undo.
const REPEATING := ["step", "step_back", "undo"]

var level
var progress
var has_next := false
var inventions := {}
var machine
var sim

var running := false
var phase := 1.0
var speed := Keys.speed  # kept across levels (keys.gd's settings file)
var clock := 0.0
var frozen := false  # screenshot mode: hold the current frame still
var placed_at := {}  # node id -> clock when it landed on a cell (for the bounce)
var landed_at := -9.0  # clock when the last stitch landed (for the puff)
var undo_stack := []
var selected_tube := -1
var selected_piece := -1  # a placed piece (only one of the two is selected)
var hover_pos := Vector2(-1, -1)  # last pointer position over the bench (for keys)
var carrying := -1  # tray index of a picked-up piece that follows the pointer
var outcome := ""  # "", "solved", "wrong", "stalled", "unused", "not_general"
var panel: Control
var still: Control  # the still layer (see _draw_still)
var still_look := []

var tray := []  # [{"kind": String, "rect": Rect2}]
var loom_cloth := Rect2()
var loom_cs := 20.0
var loom_port := Vector2.ZERO

var drag := ""  # "", "new", "move", "tube", "tube_in"
var drag_kind := ""
var drag_index := -1  # tray index of a "new" drag
var drag_node := -1
var drag_port := -1
var drag_detach := -1
var grab := Vector2.ZERO
var press_pos := Vector2.ZERO
var drag_pos := Vector2.ZERO
var drag_moved := false

var btn_run
var btn_step
var btn_back
var btn_reset
var btn_undo
var btn_speed := []


func setup(p_level, p_progress, p_has_next: bool) -> void:
	level = p_level
	progress = p_progress
	has_next = p_has_next
	inventions = progress.inventions
	var saved: Dictionary = progress.stored_machine(level.id)
	machine = Machine.from_dict(saved) if not saved.is_empty() else level.new_machine()
	if not _fixed_nodes_match():
		machine = level.new_machine()
	machine.prune(inventions)
	_build_tray()
	_layout_loom()
	_rebuild()


## Puts a machine on the bench (used by the screenshot mode).
func load_machine(m) -> void:
	machine = m
	undo_stack.clear()
	_rebuild()


func _fixed_nodes_match() -> bool:
	if machine.find_kind(Pieces.LOOM) < 0:
		return false
	for i in level.cards.size():
		if machine.find_kind(Pieces.CARD, i) < 0:
			return false
	for id in machine.nodes:
		var n: Dictionary = machine.nodes[id]
		if n["kind"] == Pieces.CARD and int(n["card"]) >= level.cards.size():
			return false
	return true


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	still = Control.new()
	still.size = DESIGN
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still.show_behind_parent = true
	still.draw.connect(_draw_still)
	still.add_to_group(Keys.GROUP)  # redraws when key caps are toggled
	add_child(still)
	still_look = _still_look()
	var back = ToyButton.make("back")
	back.position = Vector2(14, 6)
	back.key = Keys.label("back")
	back.pressed.connect(func(): exit_requested.emit())
	add_child(back)
	var x := DESIGN.x - 16
	for i in range(2, -1, -1):
		var b = ToyButton.make(SPEEDS[i], Vector2(46, 46))
		x -= 46
		b.position = Vector2(x, 9)
		b.key = Keys.label(["slower", "speed", "faster"][i])
		b.pressed.connect(_set_speed.bind(i))
		add_child(b)
		btn_speed.push_front(b)
		x -= 4
	x -= 20
	btn_run = _control_button("play", x - 58, _toggle_run, Vector2(58, 52))
	btn_step = _control_button("step", x - 58 - 58, _step_pressed)
	btn_back = _control_button("step_back", x - 58 - 58 * 2, _step_back_pressed)
	btn_reset = _control_button("reset", x - 58 - 58 * 3, _reset_pressed)
	btn_undo = _control_button("undo", x - 58 - 58 * 4 - 12, _undo)
	btn_run.key = Keys.label("run")
	btn_step.key = Keys.label("step")
	btn_back.key = Keys.label("step_back")
	btn_reset.key = Keys.label("reset")
	btn_undo.key = Keys.label("undo")
	_set_speed(speed)


func _control_button(icon: String, x: float, action: Callable, size_px := Vector2(52, 52)):
	var b = ToyButton.make(icon, size_px)
	b.position = Vector2(x, 6)
	b.pressed.connect(action)
	add_child(b)
	return b


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

func _build_tray() -> void:
	var kinds: Array = level.pieces.duplicate()
	for inv_id in level.inventions:
		if inventions.has(inv_id):
			kinds.append("inv:" + inv_id)
	tray.clear()
	var left := TRAY.position.x + 8
	var w := minf(118.0, (TRASH.position.x - 8 - left) / maxf(1, kinds.size()))
	for i in kinds.size():
		tray.append({"kind": kinds[i], "rect": Rect2(left + i * w, TRAY.position.y + 8, w - 8, TRAY.size.y - 16)})


## The loom sits in the side column, its intake on the left facing the bench.
func _layout_loom() -> void:
	var avail := Vector2(SIDE.size.x - 100, 200)
	loom_cs = floorf(clampf(minf(avail.y / level.rows, avail.x / level.cols), 10, 30))
	var w: float = level.cols * loom_cs
	var h: float = level.rows * loom_cs
	var mid := Vector2(SIDE.position.x + 62 + avail.x / 2, SIDE.position.y + 276)
	loom_cloth = Rect2(mid - Vector2(w, h) / 2, Vector2(w, h))
	loom_port = Vector2(loom_cloth.position.x - 52, mid.y)


func cell_center(x: int, y: int) -> Vector2:
	return GRID_ORIGIN + Vector2((x + 0.5) * CELL.x, (y + 0.5) * CELL.y)


func cell_at(pos: Vector2) -> Vector2i:
	var rel := pos - GRID_ORIGIN
	var c := Vector2i(floori(rel.x / CELL.x), floori(rel.y / CELL.y))
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return Vector2i(-1, -1)
	return c


## A cell holds a placed piece or part of a pattern card.
func cell_taken(cell: Vector2i) -> bool:
	return machine.piece_at(cell.x, cell.y) >= 0 or _card_cell(cell)


func _card_cell(cell: Vector2i) -> bool:
	return level.cards.size() > 0 and cell.x <= 1 and cell.y in CARD_ROWS.get(level.cards.size(), [])


func node_center(id: int) -> Vector2:
	var n: Dictionary = machine.nodes[id]
	if drag == "move" and drag_node == id:
		return drag_pos - grab
	match n["kind"]:
		Pieces.CARD:
			var rows: Array = CARD_ROWS.get(level.cards.size(), [3])
			return Vector2(GRID_ORIGIN.x + CELL.x, GRID_ORIGIN.y + (rows[int(n["card"])] + 0.5) * CELL.y)
		Pieces.LOOM:
			return loom_port
	return cell_center(n["x"], n["y"])


## Port offsets on one side of a piece (dx < 0: inputs, dx > 0: outputs),
## the first port on top.
func _offsets(count: int, dx: float) -> Array:
	match count:
		1:
			return [Vector2(dx, 0)]
		2:
			return [Vector2(dx, -PORT_DY), Vector2(dx, PORT_DY)]
		3:
			return [Vector2(dx, -22), Vector2(dx, 0), Vector2(dx, 22)]
	var out := []
	for i in count:
		out.append(Vector2(dx, (i - (count - 1) / 2.0) * 18))
	return out


func in_port(id: int, p: int) -> Vector2:
	var n: Dictionary = machine.nodes[id]
	if n["kind"] == Pieces.LOOM:
		return loom_port
	var count := Pieces.ports(n, inventions).x
	return node_center(id) + _offsets(count, -PORT_DX)[p]


func out_port(id: int, p: int) -> Vector2:
	var n: Dictionary = machine.nodes[id]
	if n["kind"] == Pieces.CARD:
		return node_center(id) + Vector2(CELL.x / 2 + PORT_DX, 0)
	var count := Pieces.ports(n, inventions).y
	return node_center(id) + _offsets(count, PORT_DX)[p]


func tube_points(i: int) -> PackedVector2Array:
	var t: Dictionary = machine.tubes[i]
	return K.tube_path(out_port(t["from"], t["fp"]), in_port(t["to"], t["tp"]))


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	running = false
	sim = Simulator.new(machine, level.cards, level.target, inventions)
	phase = 1.0
	outcome = ""
	if panel != null:
		panel.queue_free()
		panel = null
	_sync_buttons()


func _edited() -> void:
	selected_tube = -1
	selected_piece = -1
	_rebuild()
	progress.store_machine(level.id, machine.to_dict())


func _push_undo() -> void:
	undo_stack.append(machine.to_dict())
	if undo_stack.size() > 200:
		undo_stack.pop_front()


func _undo() -> void:
	if undo_stack.is_empty():
		return
	machine = Machine.from_dict(undo_stack.pop_back())
	_edited()


func _set_speed(i: int) -> void:
	speed = i
	Keys.set_speed(i)
	for k in btn_speed.size():
		btn_speed[k].toggled_on = k == i
		btn_speed[k].queue_redraw()


func _toggle_run() -> void:
	if sim.status != Simulator.Status.RUNNING:
		_rebuild()
	running = not running
	_sync_buttons()


func _step_pressed() -> void:
	running = false
	if sim.status != Simulator.Status.RUNNING:
		_rebuild()
	_do_step()
	_sync_buttons()


## Goes back one tick: the run is deterministic, so replay it to one tick earlier.
func _step_back_pressed() -> void:
	var to: int = sim.tick - 1
	if to < 0:
		return
	_rebuild()
	fast_forward(to, 1.0)


func _reset_pressed() -> void:
	_rebuild()


func _sync_buttons() -> void:
	if btn_run == null:
		return
	btn_run.icon = "pause" if running else "play"
	btn_run.toggled_on = running
	btn_run.queue_redraw()
	btn_undo.disabled = undo_stack.is_empty()
	btn_back.disabled = sim.tick == 0
	btn_back.queue_redraw()


func _do_step() -> void:
	if sim.status != Simulator.Status.RUNNING:
		running = false
		if sim.status == Simulator.Status.UNUSED and outcome == "":
			outcome = "unused"  # a card with no tube: the run fails before it starts
		return
	var before: int = sim.tick
	sim.step()
	if sim.tick == before:
		running = false
		outcome = "stalled"
		_sync_buttons()
		return
	phase = 0.0
	if sim.status != Simulator.Status.RUNNING:
		running = false
	_sync_buttons()


func _process(delta: float) -> void:
	if frozen:
		queue_redraw()
		return
	clock += delta
	if phase < 1.0:
		phase = minf(1.0, phase + delta / TICK_SECONDS[speed])
		if phase >= 1.0:
			if sim.last_weave_tick == sim.tick and sim.tick > 0:
				landed_at = clock
			_on_tick_shown()
	elif running:
		_do_step()
	queue_redraw()
	var look := _still_look()
	if still != null and look != still_look:
		still_look = look
		still.queue_redraw()


func _on_tick_shown() -> void:
	if outcome != "":
		return
	if sim.status == Simulator.Status.SOLVED:
		_finish_solve()
	elif sim.status == Simulator.Status.WRONG:
		outcome = "wrong"
	elif sim.status == Simulator.Status.UNUSED:
		outcome = "unused"


## Runs to a tick without animation (for screenshots).
func fast_forward(ticks: int, at_phase := 0.5) -> void:
	for i in ticks:
		if sim.status != Simulator.Status.RUNNING:
			break
		sim.step()
	phase = at_phase
	_sync_buttons()


func _finish_solve() -> void:
	var pieces: int = machine.cost(inventions)
	var ticks: int = sim.tick
	if not level.invention.is_empty():
		if not Invention.works_for_every_paint(machine, level.cards.size(), level.invention["check"], inventions):
			outcome = "not_general"
			return
	outcome = "solved"
	var stars: int = level.stars_for(pieces)
	var better: Dictionary = progress.record_solve(level.id, pieces, ticks, stars)
	var invention := {}
	if not level.invention.is_empty():
		invention = progress.add_invention(Invention.package(level, machine, inventions))
	progress.store_machine(level.id, machine.to_dict())
	progress_changed.emit()
	panel = SuccessPanel.new()
	panel.setup(level, pieces, ticks, stars, better, invention, has_next)
	panel.replay.connect(_rebuild)
	panel.levels.connect(func(): exit_requested.emit())
	panel.next.connect(func(): next_requested.emit())
	add_child(panel)


# ---------------------------------------------------------------------------
# Gestures
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# A right-click puts a carried piece back, like Back does (a tap
		# anywhere but a free cell does the same on touch).
		if event.pressed and carrying >= 0:
			carrying = -1
		accept_event()
	elif event is InputEventMouseMotion:
		hover_pos = event.position
		if drag != "":
			drag_pos = event.position
			if drag_pos.distance_to(press_pos) > 8:
				drag_moved = true
			accept_event()


func _notification(what: int) -> void:
	# The pointer went off the bench (or onto a button): no ghost to show.
	if what == NOTIFICATION_MOUSE_EXIT_SELF:
		hover_pos = Vector2(-1, -1)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or panel != null:
		return
	var act := Keys.action(event, "Workbench")
	if event.echo and not act in REPEATING:
		return
	if _key(act, event):
		Keys.handled(self)


## Does a key's action; false if the key means nothing here.
func _key(act: String, event: InputEventKey) -> bool:
	var editing := drag == ""  # keys don't edit under a finger mid-drag
	if act.begins_with("piece_"):
		if editing:
			_pick(int(act.substr(6)) - 1)
		return true
	match act:
		"run":
			_toggle_run()
		"step":
			_step_pressed()
		"step_back":
			_step_back_pressed()
		"reset":
			_reset_pressed()
		"undo":
			if editing and not event.shift_pressed:
				_undo()
		"slower":
			_set_speed(maxi(speed - 1, 0))
		"faster":
			_set_speed(mini(speed + 1, SPEEDS.size() - 1))
		"speed":
			_set_speed((speed + 1) % SPEEDS.size())  # slow, normal, fast, slow...
		"delete":
			if editing:
				_delete_selected()
		"back":
			if carrying >= 0:
				carrying = -1
			elif _has_selection():
				selected_tube = -1
				selected_piece = -1
			elif editing:
				exit_requested.emit()
		_:
			return false
	return true


## Picks up a tray piece (a tap on it or its key): it follows the pointer
## until a click on a free cell puts it down. Picking it again puts it back.
func _pick(i: int) -> void:
	if i >= tray.size():
		return
	carrying = -1 if carrying == i else i
	selected_tube = -1
	selected_piece = -1


func _has_selection() -> bool:
	return (selected_piece >= 0 and machine.nodes.has(selected_piece)) or (selected_tube >= 0 and selected_tube < machine.tubes.size())


func _delete_selected() -> void:
	if selected_piece >= 0 and machine.nodes.has(selected_piece):
		_push_undo()
		machine.remove_node(selected_piece)
		_edited()
	elif selected_tube >= 0 and selected_tube < machine.tubes.size():
		_push_undo()
		machine.remove_tube(selected_tube)
		_edited()
	_sync_buttons()


func _press(pos: Vector2) -> void:
	press_pos = pos
	drag_pos = pos
	drag_moved = false
	drag = ""
	if _has_selection() and pos.distance_to(_delete_button_pos()) < 26:
		_delete_selected()
		return
	selected_piece = -1
	for i in tray.size():
		if tray[i]["rect"].has_point(pos):
			drag = "new"
			drag_kind = tray[i]["kind"]
			drag_index = i
			selected_tube = -1
			return
	if carrying >= 0:
		# A click puts the carried piece down on a free cell; anywhere else
		# it goes back to the tray.
		var cell := cell_at(pos)
		if cell.x >= 0 and not cell_taken(cell):
			_place(tray[carrying]["kind"], cell)
		carrying = -1
		return
	var port := _port_at(pos, "any", -1)
	if not port.is_empty():
		selected_tube = -1
		if port["out"]:
			drag = "tube"
			drag_node = port["id"]
			drag_port = port["port"]
			drag_detach = -1
		else:
			var ti: int = machine.tube_into(port["id"], port["port"])
			if ti >= 0:
				drag = "tube"
				drag_node = machine.tubes[ti]["from"]
				drag_port = machine.tubes[ti]["fp"]
				drag_detach = ti
			else:
				drag = "tube_in"
				drag_node = port["id"]
				drag_port = port["port"]
		return
	var pid := _piece_at_pos(pos)
	if pid >= 0:
		drag = "move"
		drag_node = pid
		grab = pos - node_center(pid)
		selected_tube = -1
		return
	selected_tube = _tube_at(pos)


func _release(pos: Vector2) -> void:
	drag_pos = pos
	match drag:
		"new":
			if drag_moved:
				_place_new(pos)
			else:
				_pick(drag_index)  # a tap picks the piece up
		"move":
			_finish_move(pos)
		"tube":
			var target := _port_at(pos, "in", drag_node)
			if not target.is_empty():
				_push_undo()
				if drag_detach >= 0:
					machine.remove_tube(drag_detach)
				machine.connect_ports(drag_node, drag_port, target["id"], target["port"])
				_edited()
			elif drag_detach >= 0:
				if drag_moved:
					_push_undo()
					machine.remove_tube(drag_detach)
					_edited()
				else:
					selected_tube = drag_detach
		"tube_in":
			var source := _port_at(pos, "out", drag_node)
			if not source.is_empty():
				_push_undo()
				machine.connect_ports(source["id"], source["port"], drag_node, drag_port)
				_edited()
	drag = ""
	drag_detach = -1
	_sync_buttons()


func _place_new(pos: Vector2) -> void:
	_place(drag_kind, cell_at(pos))


## Puts a new piece of a tray kind on a free cell.
func _place(kind: String, cell: Vector2i) -> void:
	if cell.x < 0 or cell_taken(cell):
		return
	_push_undo()
	var id: int
	if kind.begins_with("inv:"):
		id = machine.add_node(Pieces.INVENTION, cell.x, cell.y, {"invention": kind.substr(4)})
	else:
		id = machine.add_node(kind, cell.x, cell.y)
	placed_at[id] = clock
	_edited()


func _finish_move(pos: Vector2) -> void:
	var id := drag_node
	drag = ""
	if not drag_moved:
		selected_piece = id  # a tap selects the piece
		selected_tube = -1
		return
	if TRAY.has_point(pos):
		_push_undo()
		machine.remove_node(id)
		_edited()
		return
	var cell := cell_at(pos - grab)
	var n: Dictionary = machine.nodes[id]
	if cell.x < 0 or (cell.x == n["x"] and cell.y == n["y"]):
		return
	if cell_taken(cell):
		return
	_push_undo()
	machine.move_node(id, cell.x, cell.y)
	placed_at[id] = clock
	_edited()


## Nearest port within reach: {"id", "port", "out": bool}, or {}.
func _port_at(pos: Vector2, which: String, exclude: int) -> Dictionary:
	var best := {}
	var best_d := PORT_HIT
	for id in machine.nodes:
		if id == exclude:
			continue
		var p := Pieces.ports(machine.nodes[id], inventions)
		if which != "out":
			for k in p.x:
				var d := in_port(id, k).distance_to(pos)
				if d < best_d:
					best_d = d
					best = {"id": id, "port": k, "out": false}
		if which != "in":
			for k in p.y:
				var d := out_port(id, k).distance_to(pos)
				if d < best_d:
					best_d = d
					best = {"id": id, "port": k, "out": true}
	if which == "in" and best.is_empty() and exclude >= 0:
		# Dropping a tube anywhere on the loom counts as its port.
		var loom_id: int = machine.find_kind(Pieces.LOOM)
		if loom_cloth.grow(30).has_point(pos) and loom_id != exclude:
			best = {"id": loom_id, "port": 0, "out": false}
	return best


func _piece_at_pos(pos: Vector2) -> int:
	for id in machine.nodes:
		if machine.is_fixed(id):
			continue
		var c := node_center(id)
		if Rect2(c - Vector2(34, 28), Vector2(68, 56)).has_point(pos):
			return id
	return -1


func _tube_at(pos: Vector2) -> int:
	var best := -1
	var best_d := 12.0
	for i in machine.tubes.size():
		var d := K.distance_to_polyline(tube_points(i), pos)
		if d < best_d:
			best_d = d
			best = i
	return best


## Where the selection's delete button floats: above a piece (below one in the
## top row), or above the middle of a tube.
func _delete_button_pos() -> Vector2:
	if selected_piece >= 0:
		var below: bool = machine.nodes[selected_piece]["y"] == 0
		return node_center(selected_piece) + Vector2(0, 52 if below else -52)
	return K.along(tube_points(selected_tube), 0.5) + Vector2(0, -30)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _age(id: int) -> float:
	var last: int = sim.node_last_fire(id)
	if last <= 0:
		return IDLE_AGE
	return (sim.tick - last) + phase


func _draw() -> void:
	_draw_run_halo()
	_draw_aim()
	_draw_bench()
	_draw_loom_area()
	_draw_hint()
	if drag == "new":
		_draw_piece_kind(drag_kind, drag_pos, -1)
	elif _carried_ghost():
		_draw_piece_kind(tray[carrying]["kind"], hover_pos, -1)
	if drag == "move":
		_draw_piece(drag_node, node_center(drag_node))


## A picked-up piece follows the pointer while it is over the bench.
func _carried_ghost() -> bool:
	return carrying >= 0 and drag == "" and BENCH.has_point(hover_pos)


## What the still layer shows that can change: redrawn only when this does.
func _still_look() -> Array:
	return [carrying, drag == "move" and drag_moved and TRAY.has_point(drag_pos)]


## The still layer: top bar, tray, bench and grid, design card. Drawn behind
## everything else, and only when its look changes; tray pieces hold still.
func _draw_still() -> void:
	_draw_frame(still)
	_draw_tray(still)
	K.shape(still, K.round_rect(BENCH, 14), Color(P.TAG, 0.35), Color(P.INK, 0.12), 2)
	if Keys.grid:  # faint cell lines (Options)
		var span := Vector2(COLS * CELL.x, ROWS * CELL.y)
		for gx in COLS + 1:
			var x := GRID_ORIGIN.x + gx * CELL.x
			still.draw_line(Vector2(x, GRID_ORIGIN.y), Vector2(x, GRID_ORIGIN.y + span.y), Color(P.INK, 0.07), 1.5)
		for gy in ROWS + 1:
			var y := GRID_ORIGIN.y + gy * CELL.y
			still.draw_line(Vector2(GRID_ORIGIN.x, y), Vector2(GRID_ORIGIN.x + span.x, y), Color(P.INK, 0.07), 1.5)
	for gx in COLS + 1:
		for gy in ROWS + 1:
			still.draw_circle(GRID_ORIGIN + Vector2(gx * CELL.x, gy * CELL.y), 2, Color(P.INK, 0.12))
	K.design(still, Rect2(SIDE.position.x + 20, SIDE.position.y + 4, SIDE.size.x - 40, 136), level.cols, level.target)


func _draw_frame(ci: CanvasItem) -> void:
	# Top bar
	K.fill(ci, PackedVector2Array([Vector2(0, 0), Vector2(DESIGN.x, 0), Vector2(DESIGN.x, TOP_H), Vector2(0, TOP_H)]), Color(P.PAPER_DK, 0.6))
	ci.draw_line(Vector2(0, TOP_H), Vector2(DESIGN.x, TOP_H), Color(P.INK, 0.15), 2)
	var index := str(level.number)
	K.text(ci, P.display(600), Vector2(80, 22), "%s · %s" % [index, level.name], 24, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	K.text(ci, P.ui(600), Vector2(80, 47), level.goal, 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


func _draw_tray(ci: CanvasItem) -> void:
	K.shape(ci, K.round_rect(TRAY, 14), Color(P.PAPER_DK, 0.9), Color(P.INK, 0.35), 2)
	for i in tray.size():
		var item: Dictionary = tray[i]
		var r: Rect2 = item["rect"]
		# A picked-up piece's slot is lit until it is put down.
		if i == carrying:
			K.shape(ci, K.round_rect(r, 10), Color(P.HOOP, 0.3), P.INK, 3)
		else:
			K.shape(ci, K.round_rect(r, 10), P.TAG, Color(P.INK, 0.5), 1.5)
		var label := ""
		var kind: String = item["kind"]
		if kind.begins_with("inv:"):
			var inv: Dictionary = inventions[kind.substr(4)]
			label = "%d pieces" % int(inv["cost"])
		else:
			label = Pieces.display_name(kind) + ("  free" if Pieces.TABLE[kind]["cost"] == 0 else "")
		_draw_piece_kind(kind, r.get_center() + Vector2(0, -8), -1, 0.82, ci, 0.0)
		K.text(ci, P.ui(700), Vector2(r.get_center().x, r.end.y - 11), label, 13, P.INK_SOFT)
		if i < 9:
			Keys.cap(ci, r.position + Vector2(16, 16), Keys.label("piece_%d" % (i + 1)))
	# Trash: lights up while a piece is dragged over the tray.
	var lit: bool = _still_look()[1]
	K.shape(ci, K.round_rect(TRASH, 12), Color(P.HOOP, 0.35) if lit else Color(P.PAPER, 0.8), Color(P.INK, 0.45), 2)
	K.icon(ci, "trash", TRASH.get_center(), 1.5 if lit else 1.3, Color(P.INK, 0.9 if lit else 0.5))


## The target cell while dragging or carrying a piece.
func _draw_aim() -> void:
	var aim := Vector2(-1, -1)
	if drag == "new" or (drag == "move" and drag_moved):
		aim = drag_pos - (grab if drag == "move" else Vector2.ZERO)
	elif _carried_ghost():
		aim = hover_pos
	if aim.x >= 0:
		var cell := cell_at(aim)
		if cell.x >= 0:
			var ok: bool = not cell_taken(cell) or (drag == "move" and machine.piece_at(cell.x, cell.y) == drag_node)
			var r := Rect2(GRID_ORIGIN + Vector2(cell) * CELL, CELL).grow(-4)
			K.fill(self, K.round_rect(r, 10), Color(P.HOOP, 0.22) if ok else Color(P.INK, 0.08))


func _draw_bench() -> void:
	# Cards
	for id in machine.nodes:
		var n: Dictionary = machine.nodes[id]
		if n["kind"] == Pieces.CARD:
			var c: int = n["card"]
			var upcoming := []
			var smudged := []
			for k in range(sim.card_cursor[c], mini(sim.card_cursor[c] + 6, level.cards[c].size())):
				upcoming.append(level.cards[c][k])
				smudged.append(k in level.smudges[c])
			K.card(self, node_center(id), level.card_names[c], upcoming, _age(id), smudged)
	# Tubes
	for i in machine.tubes.size():
		if drag == "tube" and i == drag_detach and drag_moved:
			continue
		K.tube(self, tube_points(i), i == selected_tube)
	if drag == "tube" and drag_moved:
		K.tube(self, K.tube_path(out_port(drag_node, drag_port), drag_pos), false)
	if drag == "tube_in" and drag_moved:
		K.tube(self, K.tube_path(drag_pos, in_port(drag_node, drag_port)), false)
	# Pieces, with short pipes from their sides to their ports; a selected
	# piece sits on a lit cell.
	if selected_piece >= 0 and machine.nodes.has(selected_piece) and drag == "":
		var r := Rect2(node_center(selected_piece) - CELL / 2, CELL).grow(-3)
		K.shape(self, K.round_rect(r, 12), Color(P.HOOP, 0.25), Color(P.INK, 0.5), 2)
	for id in machine.nodes:
		if machine.is_fixed(id) or (drag == "move" and id == drag_node):
			continue
		_draw_stubs(id, node_center(id))
		_draw_piece(id, node_center(id))
	# Ports
	for id in machine.nodes:
		if drag == "move" and id == drag_node:
			continue
		var p := Pieces.ports(machine.nodes[id], inventions)
		for k in p.x:
			if machine.nodes[id]["kind"] != Pieces.LOOM:
				var lit: bool = drag == "tube" and drag_moved and id != drag_node
				K.port_in(self, in_port(id, k), lit)
		for k in p.y:
			var lit: bool = drag == "tube_in" and drag_moved and id != drag_node
			K.port_out(self, out_port(id, k), lit)
	# Drops travelling down the tubes
	var eased := 1.0 - pow(1.0 - phase, 2)
	for i in machine.tubes.size():
		var c: int = sim.tube_drop(i)
		if c < 0 or (drag == "tube" and i == drag_detach and drag_moved):
			continue
		var f := 0.8
		if sim.tube_filled_at(i) == sim.tick:
			f = lerpf(0.06, 0.8, eased)
		K.drop(self, K.along(tube_points(i), f), DROP_R, c)
	# Delete button for the selected tube or piece
	if _has_selection():
		var b := _delete_button_pos()
		K.fill(self, K.ellipse(b + Vector2(0, 3), 22, 22), P.SHADOW)
		K.shape(self, K.ellipse(b, 22, 22), P.TAG, P.INK, 2.5)
		K.icon(self, "trash", b, 1.0, P.INK)
		Keys.cap(self, b + Vector2(0, 24), Keys.label("delete"))


## Glass pipes into a piece's left side, wooden spouts out of its right side.
func _draw_stubs(id: int, c: Vector2) -> void:
	var n: Dictionary = machine.nodes[id]
	if n["kind"] == "split":
		return
	var p := Pieces.ports(n, inventions)
	for o in _offsets(p.x, -PORT_DX):
		K.stub(self, c + o, c + Vector2(-18, o.y * 0.7), false)
	for o in _offsets(p.y, PORT_DX):
		K.stub(self, c + o, c + Vector2(18, o.y * 0.7), true)


func _draw_piece(id: int, c: Vector2) -> void:
	var n: Dictionary = machine.nodes[id]
	var kind: String = n["kind"]
	if kind == Pieces.INVENTION:
		kind = "inv:" + str(n.get("invention", ""))
	var s := 1.0
	var u: float = (clock - placed_at.get(id, -9.0)) / 0.45
	if u < 1.0:
		s = 1.0 + 0.22 * sin(u * PI) * (1.0 - u)
	_draw_piece_kind(kind, c, id, s)


## Draws a piece. id < 0 draws it idle (tray, drag ghost). It draws on ci
## (default: the workbench) at time t (default: now).
func _draw_piece_kind(kind: String, c: Vector2, id: int, s := 1.0, ci: CanvasItem = null, t := -1.0) -> void:
	if ci == null:
		ci = self
	if t < 0:
		t = clock
	var age := IDLE_AGE if id < 0 else _age(id)
	var liq: int = -1 if id < 0 else sim.node_color(id)
	var seed := 0.37 * id if id >= 0 else 0.5
	if kind.begins_with("inv:"):
		var inv: Dictionary = inventions.get(kind.substr(4), {})
		var paint := Invention.paint_of(inv)
		if paint >= 0:
			K.pot(ci, c + Vector2(0, -2) * s, PIECE_SCALE * s, age, t, seed, paint)
		else:
			K.sticker(ci, c, 0.8 * s, str(inv.get("name", "?")), age, t, seed)
		return
	if not Pieces.TABLE.has(kind):
		return
	match Pieces.TABLE[kind]["look"]:
		"pot":
			K.pot(ci, c + Vector2(0, -2) * s, PIECE_SCALE * s, age, t, seed)
		"catch":
			K.catch_pot(ci, c + Vector2(0, -4) * s, PIECE_SCALE * s, [] if id < 0 else sim.node_caught(id), age, t, seed)
		"mix":
			K.tub(ci, c, PIECE_SCALE * s, liq, age, "mix", t, seed)
		"invert":
			K.tub(ci, c, PIECE_SCALE * s, liq, age, "invert", t, seed)
		"filter":
			K.tub(ci, c, PIECE_SCALE * s, liq, age, "filter", t, seed)
		"shift":
			K.hamster(ci, c + Vector2(0, -2) * s, 0.66 * s, liq, age, 0 if id < 0 else sim.node_fire_count(id), t, seed)
		"split":
			var ins := []
			var outs := []
			for o in _offsets(1, -PORT_DX):
				ins.append(c + o * s)
			for o in _offsets(2, PORT_DX):
				outs.append(c + o * s)
			K.split(ci, c, ins, outs, liq, age)
		_:
			K.tub(ci, c, PIECE_SCALE * s, liq, age, "tub", t, seed)
			K.text(ci, P.display(600), c + Vector2(0, 30) * s, Pieces.display_name(kind), 13, P.INK)


func _draw_loom_area() -> void:
	var shown: int = sim.woven.size()
	var flying: bool = sim.last_weave_tick == sim.tick and sim.tick > 0 and phase < 1.0
	if flying:
		shown -= 1
	var wrong: int = sim.wrong_index if outcome == "wrong" else -1
	# The shuttle slides on to the next slot just after a stitch lands.
	var glide := clampf((clock - landed_at) / minf(0.3, TICK_SECONDS[speed] * 0.8), 0, 1)
	K.loom(self, loom_cloth, level.cols, loom_cs, sim.woven, level.target, shown, true, wrong, clock, glide)
	# The loom's intake funnel, opening towards the bench
	var port := loom_port
	K.shape(self, PackedVector2Array([port + Vector2(-6, -16), port + Vector2(18, -6), port + Vector2(18, 6), port + Vector2(-6, 16)]), P.WOOD_LT, P.INK, 2.5)
	K.port_in(self, port)
	if flying:
		var i: int = sim.woven.size() - 1
		var cell := loom_cloth.position + Vector2((i % level.cols + 0.5) * loom_cs, (i / level.cols + 0.5) * loom_cs)
		var eased := 1.0 - pow(1.0 - phase, 2)
		K.drop(self, port.lerp(cell, eased), DROP_R * lerpf(1.0, 0.7, eased), sim.woven[i])
	_draw_stitch_puff()
	_draw_status()


func _draw_status() -> void:
	var box := Rect2(SIDE.position.x, SIDE.position.y + 410, SIDE.size.x, SIDE.end.y - SIDE.position.y - 410)
	var font := P.ui(700)
	var pieces: int = machine.cost(inventions)
	K.icon(self, "pieces", box.position + Vector2(18, 16), 1.0, P.INK)
	K.text(self, font, box.position + Vector2(36, 16), "Pieces  %d" % pieces, 18, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	K.icon(self, "ticks", box.position + Vector2(158, 16), 1.0, P.INK)
	K.text(self, font, box.position + Vector2(176, 16), "Ticks  %d" % sim.tick, 18, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	# Star targets: two stars within budget, three at the best known
	# (none on a level with nothing to place).
	var x := box.position.x + 16
	for row in ([[2, level.budget], [3, level.best]] if tray.size() > 0 else []):
		for s in row[0]:
			K.star(self, Vector2(x + s * 20, box.position.y + 50), 8, pieces <= row[1] and pieces > 0)
		K.text(self, font, Vector2(x + row[0] * 20 + 4, box.position.y + 50), "≤ %d" % row[1], 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		x += 142
	var bubble := Rect2(box.position + Vector2(0, 78), Vector2(box.size.x, 52))
	match outcome:
		"wrong":
			K.shape(self, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			var i: int = sim.wrong_index
			K.icon(self, "x", bubble.position + Vector2(24, 26), 1.0, P.INK)
			K.drop(self, bubble.position + Vector2(62, 28), 11, sim.woven[i])
			# Nunito, not Fredoka: Fredoka has no "≠"
			K.text(self, P.ui(800), bubble.position + Vector2(95, 26), "≠", 26, P.INK)
			K.drop(self, bubble.position + Vector2(128, 28), 11, level.target[i])
			K.text(self, font, bubble.position + Vector2(158, 26), "stitch %d" % (i + 1), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		"stalled":
			K.shape(self, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			K.icon(self, "zzz", bubble.position + Vector2(26, 26), 1.0, P.INK)
			K.text(self, font, bubble.position + Vector2(52, 26), "Stuck: paint can't reach the loom", 15, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		"unused":
			# Every card must be used: at tick 0 the card has no tube; later it
			# still held paint when the loom was full.
			K.shape(self, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			K.icon(self, "x", bubble.position + Vector2(24, 26), 1.0, P.INK)
			var card: String = level.card_names[sim.unused_card]
			var why := "Card %s has no tube" % card if sim.tick == 0 else "Card %s still has paint left" % card
			K.text(self, font, bubble.position + Vector2(48, 26), why, 15, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		"not_general":
			K.shape(self, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			K.text(self, font, bubble.position + Vector2(14, 16), "Right picture! But a real %s must" % level.invention["name"], 14, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			K.text(self, font, bubble.position + Vector2(14, 36), "work for every pair of paints.", 14, P.INK, HORIZONTAL_ALIGNMENT_LEFT)


# ---------------------------------------------------------------------------
# Hints and juice
# ---------------------------------------------------------------------------

## True once the loom is fed and the run hasn't started: the Run button glows.
func _run_ready() -> bool:
	var loom: int = machine.find_kind(Pieces.LOOM)
	return machine.tube_into(loom, 0) >= 0 and sim.tick == 0 and not running and outcome == "" and drag == ""


func _draw_run_halo() -> void:
	if btn_run == null or not _run_ready():
		return
	var c: Vector2 = btn_run.position + btn_run.size / 2
	var r := 36.0 + 4.0 * sin(clock * 5.0)
	K.ring(self, c, r, Color(P.HOOP, 0.55), 5)


## For levels marked "hints": a hand shows the next gesture (no words).
func _hint_path() -> Array:
	if not level.raw.get("hints", false) or drag != "" or carrying >= 0 or running or outcome != "":
		return []
	var placed := []
	for id in machine.nodes:
		if not machine.is_fixed(id):
			placed.append(id)
	if placed.is_empty() and tray.size() > 0:
		return [tray[0]["rect"].get_center(), cell_center(4, 3)]
	if placed.is_empty():
		# Nothing to place: the card itself feeds the loom.
		var card: int = machine.find_kind(Pieces.CARD, 0)
		placed = [card] if card >= 0 else []
	var loom: int = machine.find_kind(Pieces.LOOM)
	for id in placed:
		var p := Pieces.ports(machine.nodes[id], inventions)
		for k in p.y:
			if machine.tube_from(id, k) < 0 and machine.tube_into(loom, 0) < 0:
				return [out_port(id, k), loom_port]
	return []


func _draw_hint() -> void:
	var path := _hint_path()
	if path.is_empty():
		return
	var cycle := fmod(clock, 2.6)
	var from: Vector2 = path[0]
	var to: Vector2 = path[1]
	var pos := from
	var down := false
	var alpha := 1.0
	if cycle < 0.4:
		alpha = cycle / 0.4
		down = cycle > 0.25
	elif cycle < 1.7:
		var u := (cycle - 0.4) / 1.3
		pos = from.lerp(to, u * u * (3 - 2 * u))
		down = true
	elif cycle < 2.1:
		pos = to
	else:
		pos = to
		alpha = 1.0 - (cycle - 2.1) / 0.5
	if down:
		K.dashed(self, PackedVector2Array([from, pos]), Color(P.INK, 0.35 * alpha), 3, 8, 7)
	K.hand(self, pos, down, alpha)


## A little puff where the last stitch landed.
func _draw_stitch_puff() -> void:
	var age := clock - landed_at
	if age < 0 or age > 0.5 or sim.woven.size() == 0:
		return
	var i: int = sim.woven.size() - 1
	var cell := loom_cloth.position + Vector2((i % level.cols + 0.5) * loom_cs, (i / level.cols + 0.5) * loom_cs)
	var u := age / 0.5
	K.ring(self, cell, loom_cs * (0.55 + u * 0.7), Color(P.INK, 0.35 * (1 - u)), 2)
	for k in 4:
		var a := k * PI / 2 + PI / 4
		K.disc(self, cell + Vector2(cos(a), sin(a)) * loom_cs * (0.5 + u * 0.8), 2.2 * (1 - u), Color(P.WOOD_DK, 1 - u))
