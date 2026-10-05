## The workbench: parts tray, bench grid, pattern cards, tubes, the loom and
## the run controls.
##
## The bench is drawn in code, in layers that redraw only when what they show
## changes (see Drawing). Every gesture is a
## press-drag-release (no hover, no right-click-only), so mouse and touch work the
## same way:
## - drag a piece from the tray onto a free cell to place it, or tap it to
##   pick it up and tap a free cell to put it down (a locked tray piece, one an
##   earlier level offered but this one holds back, places nothing);
## - drag a placed piece to move it, or onto the tray to throw it away;
## - drag from an output port to an input port to lay a tube (or the other
##   way round); drag a tube's end off an input port to re-route or remove it;
## - tap a tube or a placed piece to select it, then tap its delete button;
## - select a piece (or pick one up from the tray), then tap the journal by
##   the trash to read its page (peek); with nothing selected it opens the
##   journal at Pieces, with a tube selected at Loom.
## Any edit stops the run and rewinds it to the start.
##
## Keys (see keys.gd for the defaults; they can be changed in Options) only
## do what a tap already does: run controls and speed, a tray piece's key
## picks it up (it follows the pointer until a click puts it down), Delete
## removes only what is selected, P puts the paint card up or away, Back drops
## a carried piece, then clears the selection, then puts the paint card away,
## then leaves the level. A right-click likewise only speeds up a tap: it
## drops a carried piece.
##
## The Paints button in the top bar hangs a card of the eight paints over the
## bench (ui/paint_card.gd). It isn't modal: the bench works around it, and a
## tap on the card puts it away.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const SuccessPanel = preload("res://ui/success_panel.gd")
const Journal = preload("res://ui/journal.gd")
const JournalNews = preload("res://ui/journal_news.gd")
const Words = preload("res://core/words.gd")
const LevelNote = preload("res://ui/level_note.gd")
const Options = preload("res://ui/options.gd")
const Guide = preload("res://ui/guide.gd")
const PaintCard = preload("res://ui/paint_card.gd")
const Paint = preload("res://core/paint.gd")
const Pieces = preload("res://core/pieces.gd")
const Machine = preload("res://core/machine.gd")
const Simulator = preload("res://core/simulator.gd")
const Invention = preload("res://core/invention.gd")
const Level = preload("res://core/level.gd")

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
const PEEK := Rect2(1034, 670, 108, 112)  # the journal: tap it to read a piece's page
const BENCH := Rect2(12, 74, 956, 578)
const GRID_ORIGIN := Vector2(24, 84)
const CELL := Vector2(84, 80)
const COLS := 11
const ROWS := 7
const CARD_ROWS := {1: [3], 2: [1, 5], 3: [0, 3, 6]}  # a card's row when the bench doesn't say
const SPOTS := Vector2i(COLS * 2 - 1, ROWS * 2 - 1)  # where a piece can sit: every half cell
const SIDE := Rect2(980, 74, 288, 578)  # design card, loom and status
const TITLE_X := 132.0  # the title starts right of Back and the Options gear
const TITLE_END := 716.0  # and ends before the Paints button
const PORT_DX := 34.0
const PORT_DY := 17.0
const PORT_HIT := 20.0
## Seconds a tick: slow (one drop to follow and talk through), normal, and
## fast, 30 ticks a second on any machine (DESIGN.md 9.1, wider speeds).
const TICK_SECONDS := [0.8, 0.22, 1.0 / 30.0]
const MAX_TICKS_A_FRAME := 8  # a very long frame catches up this far, no further
const SPEEDS := ["slow", "normal", "fast"]
const PIECE_SCALE := 0.6
const FAN_SLOT := Vector2(96, 104)  # a pot in the pot slot's fan
const DROP_R := 9.0
const IDLE_AGE := 99.0
## Held keys repeat only where repeating helps: stepping and undo.
const REPEATING := ["step", "step_back", "undo"]


## A layer of the bench. It keeps what it drew until show_look() hands it a
## different look (whatever its drawing depends on), so a layer that holds
## still costs nothing from frame to frame.
class Layer extends Control:
	var look = null

	func show_look(new_look) -> void:
		if new_look != look:
			look = new_look
			queue_redraw()

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
var note: Control  # the level's note while it is up (see show_note)
var journal: Control  # the journal, open over the bench (peek)
var options_view: Control  # Options, open over the bench (the gear)
var hint_glow := false  # after a failed run, until the hint panel opens or a run starts
var _glowed_for := -1  # the bench_gen whose failure last lit the "?"
var guide_on := false  # a guided level's guide shows (unsolved, or brought back by the "?")
var ran := false  # the machine has been run here (the guide's run step)
var news: Control  # "New in your journal", after the success panel
var levels: Array = []  # the campaign, for the journal
var fresh := []  # [piece kind, input colors] first seen here, not yet in the news
var new_words := []  # words the last solve unlocked, not yet in the news
var news_extra := {}  # what else the last solve brought: a new chapter, levels opened, cheaper (journal_news.gd)
# The layers the bench is drawn in, back to front (see Drawing).
var still: Layer
var shelf: Layer
var tray_layer: Layer
var aim_layer: Layer
var cards_layer: Layer
var paints_layer: Layer
var wiring: Layer
var loom_layer: Layer
var critters: Layer
var ports: Layer
var bench_gen := 0  # counts rebuilds: the machine or its run started over

var tray := []  # [{"kind": String, "locked": bool, "rect": Rect2}], plus
# "pots" on the pot slot and "fan" on the pots it fans out (see _build_tray)
var shelf_size := 0  # the tray entries on the shelf; the fanned-out pots follow
var fan_open := false
var wiggle_slot := -1  # the locked tray slot last tapped, whose lock wiggles
var wiggled_at := -9.0
var loom_cloth := Rect2()
var loom_cs := 20.0
var loom_port := Vector2.ZERO
var tube_paths := {}  # Vector4(from end, to end) -> curve (see _tube_path)

var drag := ""  # "", "new", "move", "card", "tube", "tube_in"
var card_wiggle := {}  # card node id -> clock when a refused slide sent it back
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
var btn_paints
var paint_card: Control  # the paints, pinned under their button while up


func setup(p_level, p_progress, p_has_next: bool, p_levels := []) -> void:
	level = p_level
	progress = p_progress
	has_next = p_has_next
	levels = p_levels
	inventions = progress.usable()
	guide_on = not level.steps.is_empty() and not progress.is_solved(level.id)
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


## Pops up the level's note (title, goal, hint); a tap or any key lands it
## under the title. Tapping the title brings it back.
func show_note() -> void:
	if note != null:
		return
	hint_glow = false
	guide_on = not level.steps.is_empty()  # the "?" brings the guide back too
	note = LevelNote.new()
	note.setup(level, _title_parts()["badge_rect"])
	note.landed.connect(func(): note = null)
	add_child(note)


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
	still = _layer(_draw_still)
	shelf = _layer(_draw_shelf)
	tray_layer = _layer(_draw_tray)
	tray_layer.add_to_group(Keys.GROUP)  # redraws when key caps are toggled
	aim_layer = _layer(_draw_aim)
	cards_layer = _layer(_draw_cards)
	paints_layer = _layer(_draw_card_paints)
	wiring = _layer(_draw_wiring)
	loom_layer = _layer(_draw_loom)
	critters = _layer(_draw_critters)
	ports = _layer(_draw_ports)
	var back = ToyButton.make("back")
	back.position = Vector2(14, 6)
	back.key = Keys.label("back")
	back.pressed.connect(func(): exit_requested.emit())
	add_child(back)
	# The Options gear, right of Back (Back stays the upper-leftmost control),
	# away from the run controls so a reach for Undo never lands on it.
	var gear = ToyButton.make("options", Vector2(46, 46))
	gear.position = Vector2(74, 9)
	gear.key = Keys.label("bench_options")
	gear.pressed.connect(open_options)
	add_child(gear)
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
	btn_paints = _control_button("paints", btn_undo.position.x - 64, _toggle_paints)
	btn_paints.key = Keys.label("paints")
	_set_speed(speed)
	_show_paints(Keys.paints)


func _layer(painter: Callable) -> Layer:
	var l := Layer.new()
	l.size = DESIGN
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.show_behind_parent = true  # under the workbench's own drawing, the top layer
	l.draw.connect(painter)
	add_child(l)
	return l


func _control_button(icon: String, x: float, action: Callable, size_px := Vector2(52, 52)):
	var b = ToyButton.make(icon, size_px)
	b.position = Vector2(x, 6)
	b.pressed.connect(action)
	add_child(b)
	return b


## The Paints button (or its key): puts the paint card up or away, for every
## level (kept in the settings file).
func _toggle_paints() -> void:
	_show_paints(paint_card == null)


func _show_paints(on: bool) -> void:
	Keys.set_paints(on)
	btn_paints.toggled_on = on
	btn_paints.queue_redraw()
	if on == (paint_card != null):
		return
	if not on:
		paint_card.queue_free()
		paint_card = null
		return
	paint_card = PaintCard.new()
	# Hung from its button, over the bench, under the level's note and the
	# success panel.
	var c: Vector2 = btn_paints.position + btn_paints.size / 2
	paint_card.position = Vector2(minf(c.x - PaintCard.SIZE.x / 2, BENCH.end.x - PaintCard.SIZE.x - 8), BENCH.position.y)
	paint_card.tapped.connect(_show_paints.bind(false))
	add_child(paint_card)
	move_child(paint_card, btn_paints.get_index() + 1)


# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

## The level's tray (Level._lay_trays): what it offers, and earlier levels'
## pieces locked in their usual slots, then the owned inventions it lists.
##
## Where the level opens earned pots and the player owns some, the red pot's
## slot is the pot slot ("pots"): a tap fans the pots out above the shelf
## (the red pot among them, in paint order; held-back pots locked), and
## dragging the slot itself places the red pot. The fanned-out pots are tray
## entries too ("fan"), after the shelf's slots, so a carried pot is a tray
## index like any piece; they take taps only while the fan is open.
func _build_tray() -> void:
	var kinds: Array = level.tray.duplicate()
	for inv_id in level.inventions:
		if inventions.has(inv_id):
			kinds.append("inv:" + inv_id)
	tray.clear()
	fan_open = false
	var left := TRAY.position.x + 8
	var w := minf(118.0, (PEEK.position.x - 8 - left) / maxf(1, kinds.size()))
	for i in kinds.size():
		tray.append({"kind": kinds[i], "locked": level.is_locked(kinds[i]), "rect": Rect2(left + i * w, TRAY.position.y + 8, w - 8, TRAY.size.y - 16)})
	shelf_size = tray.size()
	var fan := _fan_kinds()
	var slot := kinds.find("red_pot")
	if fan.size() < 2 or slot < 0 or tray[slot]["locked"]:
		return
	tray[slot]["pots"] = true
	var step := FAN_SLOT.x + 8
	var x := clampf(tray[slot]["rect"].get_center().x - step * fan.size() / 2.0, BENCH.position.x + 12, BENCH.end.x - 12 - step * fan.size())
	for k in fan.size():
		var r := Rect2(Vector2(x + k * step + 4, TRAY.position.y - FAN_SLOT.y - 22), FAN_SLOT)
		tray.append({"kind": fan[k][0], "locked": fan[k][1], "rect": r, "fan": true})


## The pots in the pot slot's fan, in paint order: [kind, locked]. The red
## pot, then every pot the player owns that the level opens or holds back.
func _fan_kinds() -> Array:
	var out := []
	for paint in 8:
		if paint == 1:
			out.append(["red_pot", false])
			continue
		for pot_id in level.pots + level.held_pots:
			if inventions.has(pot_id) and Invention.paint_of(inventions[pot_id]) == paint:
				out.append(["inv:" + pot_id, pot_id in level.held_pots])
	return out


## Opens or closes the pot slot's fan.
func _show_fan(on: bool) -> void:
	fan_open = on


## Whether a tray entry takes taps now: the shelf's slots always, the
## fanned-out pots while the fan is open.
func _slot_live(i: int) -> bool:
	return fan_open or not tray[i].get("fan", false)


## The first tray slot that isn't locked, or -1 when there's nothing to place.
func _first_open_slot() -> int:
	for i in shelf_size:
		if not tray[i]["locked"]:
			return i
	return -1


## The loom sits in the side column, its intake on the left facing the bench.
func _layout_loom() -> void:
	var avail := Vector2(SIDE.size.x - 100, 200)
	loom_cs = floorf(clampf(minf(avail.y / level.rows, avail.x / level.cols), 10, 30))
	var w: float = level.cols * loom_cs
	var h: float = level.rows * loom_cs
	# The inlet sits on the bench's middle row, so a machine laid along it
	# runs straight into the loom.
	var mid := Vector2(SIDE.position.x + 62 + avail.x / 2, GRID_ORIGIN.y + 3.5 * CELL.y)
	loom_cloth = Rect2(mid - Vector2(w, h) / 2, Vector2(w, h))
	loom_port = Vector2(loom_cloth.position.x - 52, mid.y)


## Pieces sit on spots, every half cell (DESIGN.md 9.1): SPOTS of them. A
## piece still covers a whole cell around its spot and never overlaps
## another, so it can sit between two rows. Spot (2x, 2y) is cell (x, y).
func spot_center(x: int, y: int) -> Vector2:
	return GRID_ORIGIN + Vector2((x + 1) * CELL.x / 2, (y + 1) * CELL.y / 2)


## The middle of whole cell (x, y).
func cell_center(x: int, y: int) -> Vector2:
	return spot_center(2 * x, 2 * y)


## The spot a piece centred near pos snaps to, or (-1, -1) off the bench.
func spot_at(pos: Vector2) -> Vector2i:
	var rel := pos - GRID_ORIGIN
	if rel.x < 0 or rel.y < 0 or rel.x >= COLS * CELL.x or rel.y >= ROWS * CELL.y:
		return Vector2i(-1, -1)
	return Vector2i(clampi(roundi(rel.x / (CELL.x / 2)) - 1, 0, SPOTS.x - 1), clampi(roundi(rel.y / (CELL.y / 2)) - 1, 0, SPOTS.y - 1))


## The piece placed on whole cell (x, y), or -1.
func piece_in_cell(x: int, y: int) -> int:
	return machine.piece_at(2 * x, 2 * y)


## A piece on this spot would overlap a placed piece (other than `except`)
## or a pattern card.
func spot_taken(spot: Vector2i, except := -1) -> bool:
	for id in machine.nodes:
		if id == except or machine.is_fixed(id):
			continue
		var n: Dictionary = machine.nodes[id]
		if absi(int(n["x"]) - spot.x) < 2 and absi(int(n["y"]) - spot.y) < 2:
			return true
	return _card_spot(spot) >= 0


## The card a piece on this spot would overlap, or -1. A card covers the
## first two cells of its row.
func _card_spot(spot: Vector2i) -> int:
	if spot.x >= 4:
		return -1
	for c in level.cards.size():
		var row := _card_row(c)
		if spot.y > 2 * row - 2 and spot.y < 2 * row + 2:
			return c
	return -1


func node_center(id: int) -> Vector2:
	var n: Dictionary = machine.nodes[id]
	if drag == "move" and drag_node == id:
		return drag_pos - grab
	match n["kind"]:
		Pieces.CARD:
			var c := _card_center(int(n["card"]))
			if drag == "card" and drag_node == id and drag_moved:  # sliding along the edge
				c.y = clampf(drag_pos.y - grab.y, GRID_ORIGIN.y + CELL.y / 2, GRID_ORIGIN.y + (ROWS - 0.5) * CELL.y)
			elif card_wiggle.has(id):  # a refused slide: back with a wiggle
				var u: float = (clock - card_wiggle[id]) / 0.45
				if u < 1.0:
					c.x += sin(u * TAU * 3.0) * 5.0 * (1.0 - u)
			return c
		Pieces.LOOM:
			return loom_port
	return spot_center(n["x"], n["y"])


## A pattern card covers the first two cells of its row.
func _card_center(card: int) -> Vector2:
	return Vector2(GRID_ORIGIN.x + CELL.x, GRID_ORIGIN.y + (_card_row(card) + 0.5) * CELL.y)


## The row a card sits on: its own, saved with the bench, or else the
## default for the level's number of cards (CARD_ROWS).
func _card_row(card: int) -> int:
	var id: int = machine.find_kind(Pieces.CARD, card) if machine != null else -1
	if id >= 0 and machine.nodes[id].has("row"):
		return int(machine.nodes[id]["row"])
	return CARD_ROWS.get(level.cards.size(), [3, 3, 3])[card]


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
	return _tube_path(out_port(t["from"], t["fp"]), in_port(t["to"], t["tp"]))


## A tube's curve depends only on its two ends, which hardly ever move, and
## every frame asks for it several times: keep the curves. Shared: don't
## change one.
func _tube_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var key := Vector4(a.x, a.y, b.x, b.y)
	if not tube_paths.has(key):
		if tube_paths.size() >= 256:  # dragged ends leave old curves behind
			tube_paths.clear()
		tube_paths[key] = K.tube_path(a, b)
	return tube_paths[key]


# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	bench_gen += 1
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
	if running:
		hint_glow = false
		ran = true
	_sync_buttons()


func _step_pressed() -> void:
	running = false
	ran = true
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
	_learn()
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
		_refresh_layers()
		return
	clock += delta
	_advance(delta / TICK_SECONDS[speed])
	_update_glow()
	_refresh_layers()


## Moves the run on by this many ticks of time, by the clock, not the frame:
## a tick's animation ends and, while running, the next tick starts in the
## same frame, so every speed runs at its rate; when a frame is longer than a
## tick, several ticks step and the last is drawn (drops jump, not glide).
func _advance(ticks: float) -> void:
	var steps := 0
	while true:
		if phase < 1.0:
			if ticks < 1.0 - phase:
				phase += ticks
				return
			ticks -= 1.0 - phase
			phase = 1.0
			if sim.last_weave_tick == sim.tick and sim.tick > 0:
				landed_at = clock
			_on_tick_shown()
		if not running or steps >= MAX_TICKS_A_FRAME:
			return
		_do_step()
		steps += 1
		if phase >= 1.0:  # nothing stepped: the run is over or stuck
			return


## After a failed run the title's "?" glows softly, once per run, until the
## hint panel opens or a run starts.
func _update_glow() -> void:
	if outcome in ["wrong", "stalled", "unused", "not_general"] and _glowed_for != bench_gen:
		_glowed_for = bench_gen
		hint_glow = true


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
		_learn()
	phase = at_phase
	_sync_buttons()


## The journal learns what the pieces just did (Progress.learn): every first
## is a frame filled on a piece's page, and news after the next solve.
func _learn() -> void:
	for f in sim.fired:
		if progress.learn(f[0], f[1]):
			fresh.append(f)


func _finish_solve() -> void:
	var pieces: int = machine.cost(inventions)
	var ticks: int = sim.tick
	if not level.invention.is_empty():
		if not Invention.works_for_every_paint(machine, level.cards.size(), level.invention["check"], inventions):
			outcome = "not_general"
			return
	outcome = "solved"
	var stars: int = level.stars_for(pieces)
	if not progress.is_solved(level.id):  # a first solve unlocks the level's words
		new_words = Words.unlocked_by(level.id)
	var opened_before := _open_levels()
	var owned_before: Dictionary = progress.inventions.get(level.invention.get("id", ""), {})
	var better: Dictionary = progress.record_solve(level.id, pieces, ticks, stars)
	var invention := {}
	if not level.invention.is_empty():
		invention = progress.add_invention(Invention.package(level, machine, inventions))
		inventions = progress.usable()  # earning one replaces a loan
		if not owned_before.is_empty() and int(invention["cost"]) < int(owned_before["cost"]):
			news_extra["cheaper"] = [{"inv": invention, "old": int(owned_before["cost"]), "new": int(invention["cost"])}]
	_note_openings(opened_before, owned_before.is_empty())
	progress.store_machine(level.id, machine.to_dict())
	progress_changed.emit()
	panel = SuccessPanel.new()
	panel.setup(level, pieces, ticks, stars, better, invention, has_next)
	panel.replay.connect(func(): show_news(_rebuild))
	panel.levels.connect(func(): show_news(exit_requested.emit))
	panel.next.connect(func(): show_news(next_requested.emit))
	add_child(panel)


## After the success panel: "New in your journal" when the solve brought new
## words or the runs filled frames, then on to where the panel was going.
func show_news(then: Callable) -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	if new_words.is_empty() and fresh.is_empty() and news_extra.is_empty():
		then.call()
		return
	news = JournalNews.new()
	news.setup(new_words, fresh, func(ci, id, c, s): Journal.picture(ci, id, c, s, clock, _levels()), news_extra)
	new_words = []
	fresh = []
	news_extra = {}
	news.done.connect(func():
		news.queue_free()
		news = null
		then.call())
	news.open_journal.connect(func(tab, focus): open_journal(focus, tab))
	add_child(news)


## The campaign levels open now (their indexes).
func _open_levels() -> Array:
	var all := _levels()
	var ids := all.map(func(l): return l.id)
	return range(all.size()).filter(func(i): return progress.is_unlocked(ids, i))


## What a solve opened that the level select wouldn't make plain, for "New in
## your journal": a new chapter, and the levels the invention just earned
## opens (they waited for it).
func _note_openings(before: Array, first_earn: bool) -> void:
	var all := _levels()
	var now := _open_levels().filter(func(i): return not i in before)
	var chapters_before := before.map(func(i): return all[i].chapter)
	for i in now:
		if not all[i].chapter in chapters_before:
			news_extra["chapter"] = {"name": all[i].chapter_name, "level": all[i]}
			break
	var inv_id: String = level.invention.get("id", "")
	if first_earn and inv_id != "":
		var opened := now.filter(func(i): return inv_id in all[i].waits_for).map(func(i): return all[i])
		if not opened.is_empty():
			news_extra["opens"] = {"what": level.invention.get("in_text", level.invention["name"]), "levels": opened}


func _levels() -> Array:
	if levels.is_empty():
		levels = Level.load_all()
	return levels


## Opens the journal over the bench (peek): at a piece's page, a tube's tab,
## or the tab asked for. The run pauses; closing it comes back to the bench
## as it was.
func open_journal(focus := "", tab := "") -> void:
	if journal != null:
		return
	running = false
	carrying = -1
	_sync_buttons()
	journal = Journal.new()
	journal.overlay = true
	journal.here = level
	journal.setup(_levels(), progress, tab if tab != "" else ("pieces" if focus == "" else ""), focus)
	journal.back.connect(func():
		journal.queue_free()
		journal = null)
	add_child(journal)


## Opens Options over the bench (the gear, or its key), as peek opens the
## journal: the run pauses, a carried piece drops back, and Back closes it
## to the bench as it was. Not while the success panel or "New in your
## journal" is up.
func open_options() -> void:
	if options_view != null or journal != null or panel != null or news != null:
		return
	running = false
	carrying = -1
	_show_fan(false)
	_sync_buttons()
	options_view = Options.new()
	options_view.overlay = true
	options_view.back.connect(func():
		options_view.queue_free()
		options_view = null
		if still != null:  # the grid may have been turned on or off
			still.queue_redraw())
	add_child(options_view)


## The journal by the trash: the page of what is selected or picked up.
func _peek() -> void:
	var focus := ""
	if carrying >= 0:
		focus = tray[carrying]["kind"]
	elif selected_piece >= 0 and machine.nodes.has(selected_piece):
		var n: Dictionary = machine.nodes[selected_piece]
		if n["kind"] == Pieces.CARD:
			focus = "card"
		else:
			focus = "inv:" + str(n.get("invention", "")) if n["kind"] == Pieces.INVENTION else n["kind"]
	elif selected_tube >= 0 and selected_tube < machine.tubes.size():
		focus = "tube"
	open_journal(focus)


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
	if not (event is InputEventKey and event.pressed) or panel != null or note != null or journal != null or news != null or options_view != null:
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
			# With the pots fanned out, the keys pick from the fan.
			var n := int(act.substr(6)) - 1
			if fan_open:
				if shelf_size + n < tray.size():
					_pick(shelf_size + n)
			elif n < shelf_size:
				_pick(n)
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
		"bench_options":
			open_options()
		"paints":
			_toggle_paints()
		"peek":
			if editing:
				_peek()
		"back":
			if carrying >= 0:
				carrying = -1
			elif fan_open:
				_show_fan(false)
			elif _has_selection():
				selected_tube = -1
				selected_piece = -1
			elif paint_card != null:
				_show_paints(false)
			elif editing:
				exit_requested.emit()
		_:
			return false
	return true


## Picks up a tray piece (a tap on it or its key): it follows the pointer
## until a click on a free cell puts it down. Picking it again puts it back.
## A locked piece places nothing: its lock wiggles and the hand empties. The
## pot slot fans its pots out instead (or folds them away); picking a pot
## from the fan folds it.
func _pick(i: int) -> void:
	if i >= tray.size():
		return
	if tray[i].get("pots", false):
		_show_fan(not fan_open)
		carrying = -1
		return
	if tray[i]["locked"]:
		_wiggle(i)
		carrying = -1
		return
	if tray[i].get("fan", false):
		_show_fan(false)
	carrying = -1 if carrying == i else i
	selected_tube = -1
	selected_piece = -1


func _has_selection() -> bool:
	return (selected_piece >= 0 and machine.nodes.has(selected_piece)) or (selected_tube >= 0 and selected_tube < machine.tubes.size())


func _card_selected() -> bool:
	return selected_piece >= 0 and machine.nodes.has(selected_piece) and machine.nodes[selected_piece]["kind"] == Pieces.CARD


func _delete_selected() -> void:
	if _card_selected():  # a card is never removed
		return
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
	if _title_parts()["hit"].has_point(pos):
		show_note()
		return
	if _has_selection() and pos.distance_to(_book_button_pos()) < 22:
		_peek()
		return
	if _has_selection() and not _card_selected() and pos.distance_to(_delete_button_pos()) < 26:
		_delete_selected()
		return
	if PEEK.has_point(pos):
		_peek()
		return
	selected_piece = -1
	for i in tray.size():
		if _slot_live(i) and tray[i]["rect"].has_point(pos):
			if tray[i]["locked"]:  # no drag either
				_pick(i)
				selected_tube = -1
				return
			drag = "new"
			drag_kind = tray[i]["kind"]
			drag_index = i
			selected_tube = -1
			return
	_show_fan(false)  # a tap anywhere else folds the pots away
	if carrying >= 0:
		# A click puts the carried piece down on a free cell; anywhere else
		# it goes back to the tray.
		var spot := spot_at(pos)
		if spot.x >= 0 and not spot_taken(spot):
			_place(tray[carrying]["kind"], spot)
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
	var cid := _card_at_pos(pos)
	if cid >= 0:  # a card: a tap selects it, a drag slides it along the left edge
		drag = "card"
		drag_node = cid
		grab = pos - node_center(cid)
		selected_tube = -1
		return
	selected_tube = _tube_at(pos)


func _release(pos: Vector2) -> void:
	drag_pos = pos
	match drag:
		"new":
			if drag_moved:
				_place_new(pos)
				_show_fan(false)
			else:
				_pick(drag_index)  # a tap picks the piece up
		"move":
			_finish_move(pos)
		"card":
			_finish_card(pos)
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
	_place(drag_kind, spot_at(pos))


## Puts a new piece of a tray kind on a free spot.
func _place(kind: String, spot: Vector2i) -> void:
	if spot.x < 0 or spot_taken(spot):
		return
	_push_undo()
	var id: int
	if kind.begins_with("inv:"):
		id = machine.add_node(Pieces.INVENTION, spot.x, spot.y, {"invention": kind.substr(4)})
	else:
		id = machine.add_node(kind, spot.x, spot.y)
	placed_at[id] = clock
	_edited()


## A card's slide ends: a tap selects it; dropped on a row whose first two
## cells are free it moves there, on another card the two swap, and dropped
## on a piece, off the bench or on the trash it slides back with a wiggle.
## Cards never leave the left edge, so paint still enters on the left.
func _finish_card(pos: Vector2) -> void:
	var id := drag_node
	drag = ""
	if not drag_moved:
		selected_piece = id  # a tap selects the card
		selected_tube = -1
		return
	var card := int(machine.nodes[id]["card"])
	var from := _card_row(card)
	var row := clampi(floori((pos.y - grab.y - GRID_ORIGIN.y) / CELL.y), 0, ROWS - 1)
	if not BENCH.has_point(pos):
		card_wiggle[id] = clock
		return
	if row == from:
		return
	var other := -1
	for c in level.cards.size():
		if c != card and _card_row(c) == row:
			other = c
	if other < 0 and not _row_free_for_card(row):
		card_wiggle[id] = clock
		return
	_push_undo()
	for c in level.cards.size():  # every card says its row from now on
		machine.nodes[machine.find_kind(Pieces.CARD, c)]["row"] = _card_row(c)
	machine.nodes[id]["row"] = row
	if other >= 0:
		machine.nodes[machine.find_kind(Pieces.CARD, other)]["row"] = from
	_edited()


## Whether a card fits on this row: no piece covers its first two cells.
func _row_free_for_card(row: int) -> bool:
	for id in machine.nodes:
		if machine.is_fixed(id):
			continue
		var n: Dictionary = machine.nodes[id]
		if int(n["x"]) < 4 and int(n["y"]) > 2 * row - 2 and int(n["y"]) < 2 * row + 2:
			return false
	return true


## The card under the pointer, or -1.
func _card_at_pos(pos: Vector2) -> int:
	for c in level.cards.size():
		var id: int = machine.find_kind(Pieces.CARD, c)
		var r := K.CARD_RECT
		r.position += node_center(id)
		if id >= 0 and r.has_point(pos):
			return id
	return -1


func _finish_move(pos: Vector2) -> void:
	var id := drag_node
	drag = ""
	if not drag_moved:
		selected_piece = id  # a tap selects the piece
		selected_tube = -1
		return
	if PEEK.has_point(pos):  # the journal isn't a bin: the piece stays put
		return
	if TRAY.has_point(pos):
		_push_undo()
		machine.remove_node(id)
		_edited()
		return
	var spot := spot_at(pos - grab)
	var n: Dictionary = machine.nodes[id]
	if spot.x < 0 or (spot.x == n["x"] and spot.y == n["y"]):
		return
	if spot_taken(spot, id):
		return
	_push_undo()
	machine.move_node(id, spot.x, spot.y)
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


## The book button beside the delete button: a tap opens the selection's
## journal page, as the journal by the trash does. A card, which has no
## delete button, shows it alone in that place.
func _book_button_pos() -> Vector2:
	if _card_selected():
		var below := _card_row(int(machine.nodes[selected_piece]["card"])) == 0
		return node_center(selected_piece) + Vector2(0, 52 if below else -52)
	return _delete_button_pos() + Vector2(50, 0)


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
#
# The bench is drawn in layers, back to front: children drawn behind the
# workbench, whose own drawing is the top layer. Most of the bench holds still
# most of the time, and those layers are drawn again only when what they show
# changes (_refresh_layers): drawing all of it every frame made busy levels
# stutter, on the web most of all.
#   still     top bar, bench and grid, design card
#   shelf     the tray and its slots (one lit while its piece is carried), trash
#   tray      the pieces in the tray, their names and keys
#   aim       the cell a dragged or carried piece would land on
#   cards     the pattern cards
#   paints    the colors coming up on them (they slide as a card releases)
#   wiring    tubes, a selected piece's lit cell, the pipes into pieces
#   loom      the cloth and its stitches, the status under it
#   critters  the pieces: they're alive, drawn every frame
#   ports     ports
#   top       drops, delete button, shuttle, the loom's intake, hints, a
#             carried or dragged piece

func _age(id: int) -> float:
	var last: int = sim.node_last_fire(id)
	if last <= 0:
		return IDLE_AGE
	return (sim.tick - last) + phase


## Hands each layer what it shows now; the ones whose look changed redraw.
func _refresh_layers() -> void:
	if still == null:
		return
	still.show_look(_still_look())
	shelf.show_look([carrying, fan_open, _trash_lit(), _peek_lit()])
	tray_layer.show_look([level, tray.size()])
	aim_layer.show_look([_aim_cell(), bench_gen, drag, drag_node])
	cards_layer.show_look([level, _cards_look()])
	paints_layer.show_look(_card_paints_look())
	# Ports stay put while a piece or tube is dragged (the dragged piece's go
	# with it); tubes follow the pointer.
	var editing := [bench_gen, drag, drag_node, drag_moved, _cards_look()]
	ports.show_look(editing)
	if drag in ["move", "card", "tube", "tube_in"]:
		editing.append(drag_pos)
	wiring.show_look(editing + [selected_tube, selected_piece, drag_port, drag_detach])
	loom_layer.show_look([bench_gen, sim.tick, outcome, _loom_shown()])
	critters.queue_redraw()
	queue_redraw()


## Where the cards are drawn (they slide and wiggle), for the layers that
## show them.
func _cards_look() -> Array:
	var out := []
	for c in level.cards.size():
		var id: int = machine.find_kind(Pieces.CARD, c)
		out.append(node_center(id) if id >= 0 else Vector2.ZERO)
	return out


func _draw() -> void:
	_draw_hint_glow()
	_draw_run_halo()
	_draw_drops()
	_draw_delete_button()
	_draw_loom_motion()
	_draw_fan()
	_draw_locks()
	_draw_guide()
	if drag == "new":
		_draw_piece_kind(drag_kind, drag_pos, -1)
	elif _carried_ghost():
		_draw_piece_kind(tray[carrying]["kind"], hover_pos, -1)
	if drag == "move":
		_draw_piece(drag_node, node_center(drag_node))


## A soft breathing halo round the title's "?" after a failed run.
func _draw_hint_glow() -> void:
	if not hint_glow or note != null:
		return
	var badge: Vector2 = _title_parts()["badge"]
	var pulse := 0.5 + 0.5 * sin(clock * 3.2)
	for k in 3:
		K.disc(self, badge, 13.0 + k * 4.0 + pulse * 3.0, Color(P.HOOP, (0.22 - k * 0.06) * (0.6 + 0.4 * pulse)))


## Locked tray slots wear a lock where the key cap would sit; a tapped one
## wiggles for a moment.
func _draw_locks() -> void:
	for i in tray.size():
		if not tray[i]["locked"] or not _slot_live(i):
			continue
		var c: Vector2 = tray[i]["rect"].position + Vector2(18, 18)
		var u := (clock - wiggled_at) / 0.45 if i == wiggle_slot else 1.0
		if u < 1.0:
			c.x += sin(u * TAU * 3.0) * 4.0 * (1.0 - u)
		K.icon(self, "lock", c, 0.9, Color(P.INK, 0.55))


## The pot slot's fan, while it is open: the pots on a paper card above the
## shelf, pointing down at their slot, each with its paint and price (a lock
## on one the level holds back) and, with key labels on, the key that picks
## it up.
func _draw_fan() -> void:
	if not fan_open or shelf_size >= tray.size():
		return
	var first: Rect2 = tray[shelf_size]["rect"]
	var last: Rect2 = tray[tray.size() - 1]["rect"]
	var card := Rect2(first.position - Vector2(10, 10), last.end - first.position + Vector2(20, 20))
	var slot := Vector2.ZERO
	for i in shelf_size:
		if tray[i].get("pots", false):
			slot = tray[i]["rect"].get_center()
	var tip := Vector2(slot.x, TRAY.position.y + 6)
	var tail := PackedVector2Array([Vector2(tip.x - 14, card.end.y - 1), tip, Vector2(tip.x + 14, card.end.y - 1)])
	K.fill(self, K.round_rect(Rect2(card.position + Vector2(3, 5), card.size), 14), P.SHADOW)
	K.shape(self, tail, P.PAPER, Color(P.INK, 0.5), 2)
	K.shape(self, K.round_rect(card, 14), P.PAPER, Color(P.INK, 0.5), 2)
	K.fill(self, PackedVector2Array([tail[0] + Vector2(2, -3), tip + Vector2(0, -3), tail[2] + Vector2(-2, -3)]), P.PAPER)
	for k in range(shelf_size, tray.size()):
		var item: Dictionary = tray[k]
		var r: Rect2 = item["rect"]
		var lit := k == carrying or (drag == "new" and drag_index == k)
		K.shape(self, K.round_rect(r, 10), Color(P.HOOP, 0.3) if lit else P.TAG, P.INK if lit else Color(P.INK, 0.5), 3 if lit else 1.5)
		_draw_piece_kind(item["kind"], r.get_center() + Vector2(0, -8), -1, 0.78, self, 0.0)
		var label := "Red"
		if item["kind"] != "red_pot":
			label = Paint.name_of(Invention.paint_of(inventions[item["kind"].substr(4)]))
		if item["locked"]:
			K.fill(self, K.round_rect(r.grow(-2), 9), Color(P.TAG, 0.72))
			K.text(self, P.ui(700), Vector2(r.get_center().x, r.end.y - 11), label, 13, Color(P.INK_SOFT, 0.45))
			_cost_chip(self, r, _price(item["kind"]), true)
			continue
		K.text(self, P.ui(700), Vector2(r.get_center().x, r.end.y - 11), label, 13, P.INK_SOFT)
		_cost_chip(self, r, _price(item["kind"]), false)
		if k - shelf_size < 9:
			Keys.cap(self, r.position + Vector2(16, 16), Keys.label("piece_%d" % (k - shelf_size + 1)))


## What a tray kind costs the player: a piece its table price, an invention
## or pot the player's own price.
func _price(kind: String) -> int:
	if kind.begins_with("inv:"):
		return int(inventions.get(kind.substr(4), {}).get("cost", 0))
	return int(Pieces.TABLE[kind]["cost"]) if Pieces.TABLE.has(kind) else 0


## A slot's cost chip in its top-right corner: the cost bar's piece icon and
## the number, "free" after Split's 0 (the key cap is top left, the name on
## the bottom line). Faded under a locked slot's veil.
func _cost_chip(ci: CanvasItem, r: Rect2, cost: int, faded: bool) -> void:
	var font := P.ui(800)
	var text := str(cost) if cost > 0 else "0 free"
	var w := 24.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var chip := Rect2(r.end.x - 7 - w, r.position.y + 6, w, 20)
	var a := 0.45 if faded else 1.0
	K.shape(ci, K.round_rect(chip, 10), Color(P.PAPER, a), Color(P.INK, 0.35 * a), 1.2)
	K.icon(ci, "pieces", chip.position + Vector2(11, 10), 0.6, Color(P.INK_SOFT, a))
	K.text(ci, font, chip.position + Vector2(19, 10), text, 12, Color(P.INK_SOFT, a), HORIZONTAL_ALIGNMENT_LEFT)


func _wiggle(i: int) -> void:
	wiggle_slot = i
	wiggled_at = clock


## A picked-up piece follows the pointer while it is over the bench.
func _carried_ghost() -> bool:
	return carrying >= 0 and drag == "" and BENCH.has_point(hover_pos)


## What the still layer shows that can change.
func _still_look() -> Array:
	return [note != null, level]


## The trash lights up while a placed piece is dragged over the tray.
func _trash_lit() -> bool:
	return drag == "move" and drag_moved and TRAY.has_point(drag_pos) and not PEEK.has_point(drag_pos)


## The journal lights up while there's something to read about: a selected
## piece or tube, or a piece picked up from the tray.
func _peek_lit() -> bool:
	return carrying >= 0 or _has_selection()


## The still layer: top bar, bench and grid, design card.
func _draw_still() -> void:
	_draw_frame(still)
	K.shape(still, K.round_rect(BENCH, 14), Color(P.TAG, 0.35), Color(P.INK, 0.12), 2)
	if Keys.grid:  # faint cell lines (Options)
		var span := Vector2(COLS * CELL.x, ROWS * CELL.y)
		for gx in COLS + 1:
			var x := GRID_ORIGIN.x + gx * CELL.x
			still.draw_line(Vector2(x, GRID_ORIGIN.y), Vector2(x, GRID_ORIGIN.y + span.y), Color(P.INK, 0.07), 1.5)
		for gy in ROWS + 1:
			var y := GRID_ORIGIN.y + gy * CELL.y
			still.draw_line(Vector2(GRID_ORIGIN.x, y), Vector2(GRID_ORIGIN.x + span.x, y), Color(P.INK, 0.07), 1.5)
		# Faint dots at the half points: pieces snap every half cell.
		for hx in COLS * 2 + 1:
			for hy in ROWS * 2 + 1:
				if hx % 2 == 1 or hy % 2 == 1:
					still.draw_circle(GRID_ORIGIN + Vector2(hx, hy) * CELL / 2, 1.3, Color(P.INK, 0.1))
	for gx in COLS + 1:
		for gy in ROWS + 1:
			still.draw_circle(GRID_ORIGIN + Vector2(gx * CELL.x, gy * CELL.y), 2, Color(P.INK, 0.12))
	K.design(still, Rect2(SIDE.position.x + 20, SIDE.position.y + 4, SIDE.size.x - 40, 136), level.cols, level.target)


func _draw_frame(ci: CanvasItem) -> void:
	# Top bar
	K.fill(ci, PackedVector2Array([Vector2(0, 0), Vector2(DESIGN.x, 0), Vector2(DESIGN.x, TOP_H), Vector2(0, TOP_H)]), Color(P.PAPER_DK, 0.6))
	ci.draw_line(Vector2(0, TOP_H), Vector2(DESIGN.x, TOP_H), Color(P.INK, 0.15), 2)
	# The title: the level's number, what the cloth is, then what the machine
	# is (on an invention level the piece it becomes, with a sticker mark),
	# then the "?" that brings the hint panel back.
	var parts := _title_parts()
	var font := P.display(600)
	var size: int = parts["size"]
	var y := TOP_H / 2
	K.text(ci, font, Vector2(parts["number_x"], y), str(level.number), size, Color(P.WOOD_DK, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	K.text(ci, font, Vector2(parts["cloth_x"], y), level.cloth_phrase, size, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	if level.machine_phrase != "":
		K.text(ci, font, Vector2(parts["dot_x"], y), "·", size, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		K.text(ci, font, Vector2(parts["machine_x"], y), level.machine_phrase, size, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	if parts["mark_x"] > 0:
		K.sticker_mark(ci, Vector2(parts["mark_x"], y))
	var badge: Vector2 = parts["badge"]
	K.shape(ci, K.ellipse(badge, 11, 11, 0, 20), P.TAG, Color(P.INK, 0.6), 1.5)
	K.text(ci, P.ui(800), badge + Vector2(0, 0.5), "?", 15, P.INK)


## Where the title's parts sit: {"size", "number_x", "cloth_x", "dot_x",
## "machine_x", "mark_x" (0 without a mark), "badge", "badge_rect", "hit"}.
## It shrinks to fit between the gear and the Paints button.
func _title_parts() -> Dictionary:
	var font := P.display(600)
	var mark: bool = not level.invention.is_empty() and level.machine_phrase != ""
	var size := 24
	var w := func(s: String, sz: int) -> float: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var total := 0.0
	while true:
		var gap := size * 0.45
		total = w.call(str(level.number), size) + gap + w.call(level.cloth_phrase, size)
		if level.machine_phrase != "":
			total += gap + w.call("·", size) + gap + w.call(level.machine_phrase, size)
		total += (30.0 if mark else 0.0) + 34.0
		if TITLE_X + total <= TITLE_END or size <= 15:
			break
		size -= 1
	var gap := size * 0.45
	var out := {"size": size, "number_x": TITLE_X}
	var x: float = TITLE_X + w.call(str(level.number), size) + gap
	out["cloth_x"] = x
	x += w.call(level.cloth_phrase, size)
	if level.machine_phrase != "":
		out["dot_x"] = x + gap
		out["machine_x"] = x + gap + w.call("·", size) + gap
		x = out["machine_x"] + w.call(level.machine_phrase, size)
	out["mark_x"] = x + 18.0 if mark else 0.0
	if mark:
		x += 30.0
	var badge := Vector2(x + 22, TOP_H / 2)
	out["badge"] = badge
	out["badge_rect"] = Rect2(badge - Vector2(11, 11), Vector2(22, 22))
	out["hit"] = Rect2(TITLE_X - 6, 2, badge.x + 16 - TITLE_X, TOP_H - 4)
	return out


## The tray's shelf: its slots (a picked-up piece's slot is lit until it is
## put down) and the trash (lit while a piece is dragged over the tray).
func _draw_shelf() -> void:
	K.shape(shelf, K.round_rect(TRAY, 14), Color(P.PAPER_DK, 0.9), Color(P.INK, 0.35), 2)
	var carried_pot := carrying >= shelf_size  # a pot from the fan
	for i in shelf_size:
		var r: Rect2 = tray[i]["rect"]
		if i == carrying or (tray[i].get("pots", false) and (fan_open or carried_pot)):
			K.shape(shelf, K.round_rect(r, 10), Color(P.HOOP, 0.3), P.INK, 3)
		else:
			K.shape(shelf, K.round_rect(r, 10), P.TAG, Color(P.INK, 0.5), 1.5)
	var lit := _trash_lit()
	K.shape(shelf, K.round_rect(TRASH, 12), Color(P.HOOP, 0.35) if lit else Color(P.PAPER, 0.8), Color(P.INK, 0.45), 2)
	K.icon(shelf, "trash", TRASH.get_center(), 1.5 if lit else 1.3, Color(P.INK, 0.9 if lit else 0.5))
	var peek := _peek_lit()
	K.shape(shelf, K.round_rect(PEEK, 12), Color(P.HOOP, 0.3) if peek else Color(P.PAPER, 0.8), Color(P.INK, 0.6 if peek else 0.45), 2.5 if peek else 2)
	K.icon(shelf, "book", PEEK.get_center() + Vector2(0, -10), 1.6 if peek else 1.4, Color(P.INK, 0.9 if peek else 0.55))
	K.text(shelf, P.ui(700), Vector2(PEEK.get_center().x, PEEK.end.y - 18), "Journal", 13, Color(P.INK_SOFT, 1.0 if peek else 0.7))


## The pieces in the tray's slots, with their names and keys. They hold still.
func _draw_tray() -> void:
	var ci := tray_layer
	for i in shelf_size:
		var item: Dictionary = tray[i]
		var r: Rect2 = item["rect"]
		var label := ""
		var kind: String = item["kind"]
		if item.get("pots", false):
			# The pot slot: two of the earned pots peek out behind the red one.
			var behind := tray.slice(shelf_size).filter(func(e): return e["kind"] != "red_pot")
			for k in mini(2, behind.size()):
				var pot: Dictionary = behind[behind.size() - 1 - k]
				_draw_piece_kind(pot["kind"], r.get_center() + Vector2(-22 if k == 0 else 22, -16), -1, 0.56, ci, 0.0)
			label = "Pots"
		elif not kind.begins_with("inv:"):  # an invention's sticker carries its name
			label = Pieces.display_name(kind)
		_draw_piece_kind(kind, r.get_center() + Vector2(0, -8), -1, 0.82, ci, 0.0)
		if item["locked"]:
			# Under a paper veil, its lock (drawn live, so it can wiggle)
			# where the key cap sits.
			K.fill(ci, K.round_rect(r.grow(-2), 9), Color(P.TAG, 0.72))
			K.text(ci, P.ui(700), Vector2(r.get_center().x, r.end.y - 11), label, 13, Color(P.INK_SOFT, 0.45))
			if not item.get("pots", false):
				_cost_chip(ci, r, _price(kind), true)
			continue
		K.text(ci, P.ui(700), Vector2(r.get_center().x, r.end.y - 11), label, 13, P.INK_SOFT)
		if not item.get("pots", false):  # one number on the folded pots would read as every pot's
			_cost_chip(ci, r, _price(kind), false)
		if i < 9:
			Keys.cap(ci, r.position + Vector2(16, 16), Keys.label("piece_%d" % (i + 1)))
	Keys.cap(ci, PEEK.position + Vector2(16, 16), Keys.label("peek"))


## The spot aimed at while dragging or carrying a piece ((-1, -1): none).
func _aim_cell() -> Vector2i:
	var aim := Vector2(-1, -1)
	if drag == "new" or (drag == "move" and drag_moved):
		aim = drag_pos - (grab if drag == "move" else Vector2.ZERO)
	elif _carried_ghost():
		aim = hover_pos
	return spot_at(aim)


## The aim layer: the cell a dragged or carried piece would cover, lit if
## it is free.
func _draw_aim() -> void:
	var spot := _aim_cell()
	if spot.x >= 0:
		var ok: bool = not spot_taken(spot, drag_node if drag == "move" else -1)
		var r := Rect2(GRID_ORIGIN + Vector2(spot) * CELL / 2, CELL).grow(-4)
		K.fill(aim_layer, K.round_rect(r, 10), Color(P.HOOP, 0.22) if ok else Color(P.INK, 0.08))


func _draw_cards() -> void:
	for c in level.cards.size():
		K.card_body(cards_layer, node_center(machine.find_kind(Pieces.CARD, c)), level.card_names[c])


## What the paints layer shows: each card's next colors, and how far they
## have slid since it released one.
func _card_paints_look() -> Array:
	var look := [bench_gen, _cards_look(), outcome]
	for id in machine.nodes:
		if machine.nodes[id]["kind"] == Pieces.CARD:
			look.append(sim.card_cursor[machine.nodes[id]["card"]])
			look.append(minf(_age(id), 1.0))
	return look


## The paints layer: the colors coming up on each card.
func _draw_card_paints() -> void:
	for id in machine.nodes:
		var n: Dictionary = machine.nodes[id]
		if n["kind"] != Pieces.CARD:
			continue
		var c: int = n["card"]
		var upcoming := []
		if outcome == "wrong":
			# A look back: the drops the card showed at the start, or as many
			# ending at the one that wove the wrong stitch, which is ringed.
			var wrong: int = sim.wrong_index
			var start := maxi(0, wrong - level.card_shows + 1)
			for k in range(start, mini(start + level.card_shows, level.cards[c].size())):
				upcoming.append(level.cards[c][k])
			K.card_paints(paints_layer, node_center(id), upcoming, 1.0, level.card_shows, wrong - start, start > 0)
			continue
		for k in range(sim.card_cursor[c], mini(sim.card_cursor[c] + level.card_shows, level.cards[c].size())):
			upcoming.append(level.cards[c][k])
		K.card_paints(paints_layer, node_center(id), upcoming, _age(id), level.card_shows)


## The wiring layer: tubes, a selected piece's lit cell, and the pipes into
## the pieces.
func _draw_wiring() -> void:
	var ci := wiring
	for i in machine.tubes.size():
		if drag == "tube" and i == drag_detach and drag_moved:
			continue
		K.tube(ci, tube_points(i), i == selected_tube)
	if drag == "tube" and drag_moved:
		K.tube(ci, K.tube_path(out_port(drag_node, drag_port), drag_pos), false)
	if drag == "tube_in" and drag_moved:
		K.tube(ci, K.tube_path(drag_pos, in_port(drag_node, drag_port)), false)
	if selected_piece >= 0 and machine.nodes.has(selected_piece) and drag == "":
		var r := Rect2(node_center(selected_piece) - CELL / 2, CELL).grow(-3)
		if _card_selected():  # a card: the usual outline round its body
			r = K.CARD_RECT.grow(6)
			r.position += node_center(selected_piece)
		K.shape(ci, K.round_rect(r, 12), Color(P.HOOP, 0.25), Color(P.INK, 0.5), 2)
	for id in machine.nodes:
		if machine.is_fixed(id) or (drag == "move" and id == drag_node):
			continue
		_draw_stubs(ci, id, node_center(id))


## The critters layer, every frame: the pieces.
func _draw_critters() -> void:
	for id in machine.nodes:
		if machine.is_fixed(id) or (drag == "move" and id == drag_node):
			continue
		_draw_piece(id, node_center(id), critters)


## The ports layer: every port over the pieces (lit where a dragged tube
## can end). The loom's intake is drawn with what moves on the loom.
func _draw_ports() -> void:
	var ci := ports
	for id in machine.nodes:
		if drag == "move" and id == drag_node:
			continue
		var p := Pieces.ports(machine.nodes[id], inventions)
		for k in p.x:
			if machine.nodes[id]["kind"] != Pieces.LOOM:
				var lit: bool = drag == "tube" and drag_moved and id != drag_node
				K.port_in(ci, in_port(id, k), lit)
		for k in p.y:
			var lit: bool = drag == "tube_in" and drag_moved and id != drag_node
			K.port_out(ci, out_port(id, k), lit)


## Drops travelling down the tubes.
func _draw_drops() -> void:
	var eased := 1.0 - pow(1.0 - phase, 2)
	for i in machine.tubes.size():
		var c: int = sim.tube_drop(i)
		if c < 0 or (drag == "tube" and i == drag_detach and drag_moved):
			continue
		var f := 0.8
		if sim.tube_filled_at(i) == sim.tick:
			f = lerpf(0.06, 0.8, eased)
		K.drop(self, K.along(tube_points(i), f), DROP_R, c)


## The delete button for the selected tube or piece, and the book button
## beside it (alone on a card), drawn the same way.
func _draw_delete_button() -> void:
	if not _has_selection():
		return
	if not _card_selected():
		var b := _delete_button_pos()
		K.fill(self, K.ellipse(b + Vector2(0, 3), 22, 22), P.SHADOW)
		K.shape(self, K.ellipse(b, 22, 22), P.TAG, P.INK, 2.5)
		K.icon(self, "trash", b, 1.0, P.INK)
		Keys.cap(self, b + Vector2(0, 24), Keys.label("delete"))
	var k := _book_button_pos()
	K.fill(self, K.ellipse(k + Vector2(0, 3), 20, 20), P.SHADOW)
	K.shape(self, K.ellipse(k, 20, 20), P.TAG, P.INK, 2.5)
	K.icon(self, "book", k, 0.9, P.INK)
	Keys.cap(self, k + Vector2(0, 22), Keys.label("peek"))


## Glass pipes into a piece's left side, wooden spouts out of its right side.
func _draw_stubs(ci: CanvasItem, id: int, c: Vector2) -> void:
	var n: Dictionary = machine.nodes[id]
	if n["kind"] == "split":
		return
	var p := Pieces.ports(n, inventions)
	for o in _offsets(p.x, -PORT_DX):
		K.stub(ci, c + o, c + Vector2(-18, o.y * 0.7), false)
	for o in _offsets(p.y, PORT_DX):
		K.stub(ci, c + o, c + Vector2(18, o.y * 0.7), true)


func _draw_piece(id: int, c: Vector2, ci: CanvasItem = null) -> void:
	var n: Dictionary = machine.nodes[id]
	var kind: String = n["kind"]
	if kind == Pieces.INVENTION:
		kind = "inv:" + str(n.get("invention", ""))
	var s := 1.0
	var u: float = (clock - placed_at.get(id, -9.0)) / 0.45
	if u < 1.0:
		s = 1.0 + 0.22 * sin(u * PI) * (1.0 - u)
	_draw_piece_kind(kind, c, id, s, ci)


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
	var more := {}
	match Pieces.TABLE[kind]["look"]:
		"catch":
			more["caught"] = [] if id < 0 else sim.node_caught(id)
		"shift":
			more["turns"] = 0 if id < 0 else sim.node_fire_count(id)
		"split":
			more["ins"] = _offsets(1, -PORT_DX).map(func(o): return c + o * s)
			more["outs"] = _offsets(2, PORT_DX).map(func(o): return c + o * s)
	K.piece(ci, Pieces.TABLE[kind]["look"], c, PIECE_SCALE * s, liq, age, t, seed, more)


## Stitches on the cloth: all those woven but one still flying to it.
func _loom_shown() -> int:
	return sim.woven.size() - (1 if _stitch_flying() else 0)


func _stitch_flying() -> bool:
	return sim.last_weave_tick == sim.tick and sim.tick > 0 and phase < 1.0


## The loom layer: the cloth as woven so far, and the status under it.
func _draw_loom() -> void:
	var wrong: int = sim.wrong_index if outcome == "wrong" else -1
	K.loom(loom_layer, loom_cloth, level.cols, loom_cs, sim.woven, level.target, _loom_shown(), true, wrong)
	_draw_status(loom_layer)


## What moves on the loom: the shuttle (or a wrong stitch's mark), a stitch
## flying in from the intake, the puff where it lands. The intake funnel sits
## between them: over the shuttle and a drop resting at the end of a short
## tube, under the stitch flying out of it.
func _draw_loom_motion() -> void:
	var wrong: int = sim.wrong_index if outcome == "wrong" else -1
	# The shuttle slides on to the next slot just after a stitch lands.
	var glide := clampf((clock - landed_at) / minf(0.3, TICK_SECONDS[speed] * 0.8), 0, 1)
	K.loom_shuttle(self, loom_cloth, level.cols, loom_cs, sim.woven, level.target, _loom_shown(), wrong, clock, glide)
	# The loom's intake funnel, opening towards the bench
	var port := loom_port
	K.shape(self, PackedVector2Array([port + Vector2(-6, -16), port + Vector2(18, -6), port + Vector2(18, 6), port + Vector2(-6, 16)]), P.WOOD_LT, P.INK, 2.5)
	K.port_in(self, port)
	if _stitch_flying():
		var i: int = sim.woven.size() - 1
		var cell := loom_cloth.position + Vector2((i % level.cols + 0.5) * loom_cs, (i / level.cols + 0.5) * loom_cs)
		var eased := 1.0 - pow(1.0 - phase, 2)
		K.drop(self, loom_port.lerp(cell, eased), DROP_R * lerpf(1.0, 0.7, eased), sim.woven[i])
	_draw_stitch_puff()


## The pieces bar: one slot per piece placed, so it reads as progress, not a
## limit. Markers stand after the three-star count (stars to its left) and the
## two-star count (stars to its right); they light while the bench is within.
## Room for two pieces past two stars; beyond that the bar stays full.
func _draw_piece_bar(ci: CanvasItem, bar: Rect2, pieces: int) -> void:
	K.icon(ci, "pieces", Vector2(bar.position.x - 20, bar.get_center().y), 1.0, P.INK)
	var slots: int = level.budget + 2
	var w := bar.size.x / slots
	for s in slots:
		var cell := Rect2(bar.position.x + s * w + 1.5, bar.position.y, w - 3, bar.size.y)
		K.shape(ci, K.round_rect(cell, 5), P.WOOD if s < pieces else P.PAPER_DK, Color(P.INK, 0.6 if s < pieces else 0.3), 1.5)
	var marks := [[3, level.best]]
	if level.budget != level.best:
		marks.append([2, level.budget])
	for m in marks:
		var x: float = bar.position.x + m[1] * w
		K.line(ci, Vector2(x, bar.position.y - 28), Vector2(x, bar.end.y + 4), P.INK, 2)
		var side := -1.0 if m[0] == 3 else 1.0
		for s in m[0]:
			K.star(ci, Vector2(x + side * (12 + s * 17), bar.position.y - 16), 8, pieces > 0 and pieces <= m[1])


func _draw_status(ci: CanvasItem) -> void:
	var box := Rect2(SIDE.position.x, SIDE.position.y + 410, SIDE.size.x, SIDE.end.y - SIDE.position.y - 410)
	var font := P.ui(700)
	if _first_open_slot() >= 0:  # nothing to place: no bar
		_draw_piece_bar(ci, Rect2(box.position + Vector2(38, 36), Vector2(166, 20)), machine.cost(inventions))
	K.icon(ci, "ticks", box.position + Vector2(220, 46), 1.0, P.INK)
	K.text(ci, font, box.position + Vector2(236, 46), str(sim.tick), 18, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	var bubble := Rect2(box.position + Vector2(0, 78), Vector2(box.size.x, 52))
	match outcome:
		"wrong":
			K.shape(ci, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			var i: int = sim.wrong_index
			K.icon(ci, "x", bubble.position + Vector2(24, 26), 1.0, P.INK)
			K.drop(ci, bubble.position + Vector2(62, 28), 11, sim.woven[i])
			# Nunito, not Fredoka: Fredoka has no "≠"
			K.text(ci, P.ui(800), bubble.position + Vector2(95, 26), "≠", 26, P.INK)
			K.drop(ci, bubble.position + Vector2(128, 28), 11, level.target[i])
			K.text(ci, font, bubble.position + Vector2(158, 26), "stitch %d" % (i + 1), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		"stalled":
			K.shape(ci, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			K.icon(ci, "zzz", bubble.position + Vector2(26, 26), 1.0, P.INK)
			K.text(ci, font, bubble.position + Vector2(52, 26), "Stuck: paint can't reach the loom", 15, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		"unused":
			# Every card must be used: at tick 0 the card has no tube; later it
			# still held paint when the loom was full.
			K.shape(ci, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			K.icon(ci, "x", bubble.position + Vector2(24, 26), 1.0, P.INK)
			var card: String = level.card_names[sim.unused_card]
			var why := "Card %s has no tube" % card if sim.tick == 0 else "Card %s still has paint left" % card
			K.text(ci, font, bubble.position + Vector2(48, 26), why, 15, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		"not_general":
			K.shape(ci, K.round_rect(bubble, 12), P.TAG, P.INK, 2)
			K.text(ci, font, bubble.position + Vector2(14, 16), "Right picture! But a real %s must" % level.invention["name"], 14, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			K.text(ci, font, bubble.position + Vector2(14, 36), "work for every pair of paints.", 14, P.INK, HORIZONTAL_ALIGNMENT_LEFT)


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


## What the guide shows now (ui/guide.gd), or {} when it's hidden: {"lines",
## "from", "to", "tap" (a tap at `to` instead of a drag), "slot" (the tray
## slot to light, -1), "ghost" (the kind to show faintly at `to`, or "")}.
## It hides while the player is doing something (a drag, a carried piece, a
## run, an overlay) and once every step is done.
func _guide() -> Dictionary:
	if not guide_on or level.steps.is_empty() or drag != "" or carrying >= 0 or running or outcome != "":
		return {}
	if note != null or journal != null or options_view != null or panel != null or news != null:
		return {}
	var step := Guide.current(level, machine, {"fan_open": fan_open, "ran": ran})
	if step.is_empty():
		return {}
	var out := {"lines": step["lines"], "from": Vector2(-1, -1), "to": Vector2(-1, -1), "tap": false, "slot": -1, "ghost": ""}
	var act: Array = step["action"]
	var bound: Dictionary = step["bound"]
	match str(act[0]):
		"place":
			var p := {}
			for q in level.reference.get("pieces", []):
				if q["id"] == act[1]:
					p = q
			var kind: String = p["kind"] if p["kind"] != Pieces.INVENTION else "inv:" + str(p["invention"])
			var target := cell_center(int(p["x"]), int(p["y"]))
			var slot := _slot_of(kind)
			if kind.begins_with("inv:pot_") and not fan_open:
				slot = _slot_of("red_pot")  # the pot slot: open its fan first
				out["tap"] = true
				out["from"] = tray[slot]["rect"].get_center() if slot >= 0 else target
				out["to"] = out["from"]
			elif slot >= 0:
				out["from"] = tray[slot]["rect"].get_center()
				out["to"] = target
				out["ghost"] = kind
			out["slot"] = slot
		"tube":
			var a: int = bound.get(act[1], -1)
			var b: int = bound.get(act[2], -1)
			if a >= 0 and b >= 0:
				out["from"] = out_port(a, _free_port(a, false))
				out["to"] = loom_port if machine.nodes[b]["kind"] == Pieces.LOOM else in_port(b, _free_port(b, true))
		"fan":
			var slot := _slot_of("red_pot")
			if slot >= 0:
				out["from"] = tray[slot]["rect"].get_center()
				out["to"] = out["from"]
				out["tap"] = true
				out["slot"] = slot
		"run":
			out["from"] = btn_run.position + btn_run.size / 2
			out["to"] = out["from"]
			out["tap"] = true
	return out


## The live tray slot (shelf or open fan) that holds this kind, or -1.
func _slot_of(kind: String) -> int:
	for i in tray.size():
		if tray[i]["kind"] == kind and _slot_live(i) and not tray[i]["locked"]:
			return i
	return -1


## A piece's first input (or output) port with no tube, or its first.
func _free_port(id: int, inputs: bool) -> int:
	var p := Pieces.ports(machine.nodes[id], inventions)
	for k in (p.x if inputs else p.y):
		if (machine.tube_into(id, k) if inputs else machine.tube_from(id, k)) < 0:
			return k
	return 0


## The guide: the slot it takes a piece from lights, a faint ghost waits
## where the piece goes, the hand acts the step out, and the step's line sits
## beside it.
func _draw_guide() -> void:
	var g := _guide()
	if g.is_empty():
		return
	var slot: int = g["slot"]
	if slot >= 0:
		var r: Rect2 = tray[slot]["rect"]
		var pulse := 0.5 + 0.5 * sin(clock * 4.0)
		K.stroke(self, K.closed(K.round_rect(r.grow(3 + pulse * 2), 12)), Color(P.HOOP, 0.5 + 0.3 * pulse), 3)
	var from: Vector2 = g["from"]
	var to: Vector2 = g["to"]
	if g["ghost"] != "":
		_draw_piece_kind(g["ghost"], to, -1, 0.82, self, 0.0)
		K.fill(self, K.round_rect(Rect2(to - CELL / 2, CELL).grow(-2), 12), Color(P.TAG, 0.62))
		K.dashed(self, K.closed(K.round_rect(Rect2(to - CELL / 2, CELL).grow(-4), 12)), Color(P.INK, 0.3), 2, 7, 6)
	if from.x >= 0:
		if g["tap"]:
			var cycle := fmod(clock, 1.4)
			K.hand(self, to + Vector2(6, 10), cycle > 0.5 and cycle < 0.8, clampf(cycle / 0.3, 0, 1))
		else:
			_draw_hand_drag(from, to)
	_draw_guide_line(g["lines"], to if to.x >= 0 else BENCH.get_center())


## The hand presses at `from`, drags to `to` and lifts, over and over.
func _draw_hand_drag(from: Vector2, to: Vector2) -> void:
	var cycle := fmod(clock, 2.6)
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


## The step's line (after any lead-in lines) on a paper slip beside where the
## hand acts: above it, or below near the top of the bench.
func _draw_guide_line(lines: Array, at: Vector2) -> void:
	var font := P.ui(700)
	var width := 0.0
	for l in lines:
		width = maxf(width, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var size := Vector2(minf(width, 520.0) + 32, 14 + 24 * lines.size())
	var pos := Vector2(at.x - size.x / 2, at.y - 70 - size.y if at.y > BENCH.position.y + 160 else at.y + 64)
	if at.y >= TRAY.position.y:  # acting on the tray or the run controls: just above the tray
		pos.y = TRAY.position.y - size.y - 74
	if at.y < TOP_H + 10:  # the run button: below the top bar
		pos = Vector2(at.x - size.x + 40, TOP_H + 24)
	pos.x = clampf(pos.x, BENCH.position.x + 8, BENCH.end.x - size.x - 8)
	var r := Rect2(pos, size)
	K.fill(self, K.round_rect(Rect2(r.position + Vector2(3, 4), r.size), 12), P.SHADOW)
	K.shape(self, K.round_rect(r, 12), P.TAG, Color(P.INK, 0.6), 2)
	for i in lines.size():
		var last := i == lines.size() - 1
		K.text(self, font, Vector2(r.position.x + 16, r.position.y + 19 + i * 24), lines[i], 16, P.INK if last else P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32)

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
