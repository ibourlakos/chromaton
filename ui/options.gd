## Options: a faint grid on the bench, on every build. Where a keyboard is
## likely (not on phone builds, see Keys.rebindable) also the keys (every
## action, up to two keys each) and whether key caps show on the controls.
##
## Tap a key slot, then press the new key; Back's key cancels, and tapping
## the slot again clears it. A key moves off any action it would clash with
## (that action's slot blinks). Every change is saved straight away.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")

signal back

const DESIGN := Vector2(1280, 800)
const ROW := 42.0
const SLOT := Vector2(104, 34)
const PIECE_SLOT := Vector2(52, 34)
const GROUP_NAMES := {"Everywhere": "Everywhere", "Workbench": "Workbench", "Woven": "After weaving", "Levels": "Level select"}

var slots := []  # [{"rect": Rect2, "action": String, "slot": int}]
var labels := []  # [position, text, header?]
var capturing := {}  # {"action", "slot"} while waiting for a key
var flash := {}  # action -> t when a key moved off it
var with_keys := Keys.rebindable()
var toggles := []  # [button, text] for the round buttons with a line beside them
var grid_button
var hints_button
var t := 0.0
var _pressed_slot := -1


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var b = ToyButton.make("back")
	b.position = Vector2(14, 6)
	b.key = Keys.label("back")
	b.pressed.connect(func(): back.emit())
	add_child(b)
	# With keys, the round buttons sit under the right-hand column of keys;
	# without, the grid toggle is all there is.
	var at := Vector2(700, 556) if with_keys else Vector2(DESIGN.x / 2 - 170, 170)
	grid_button = _toggle("check", at, "Show a grid on the bench", _toggle_grid)
	grid_button.toggled_on = Keys.grid
	if not with_keys:
		return
	_layout()
	hints_button = _toggle("check", at + Vector2(0, 62), "Show key labels on the controls", _toggle_hints)
	hints_button.toggled_on = Keys.shown
	hints_button.key = Keys.label("hints")
	_toggle("reset", at + Vector2(0, 124), "Put every key back", _reset_keys)


func _toggle(icon: String, at: Vector2, text: String, action: Callable):
	var b = ToyButton.make(icon, Vector2(44, 44))
	b.position = at
	b.pressed.connect(action)
	add_child(b)
	toggles.append([b, text])
	return b


## Lays out the key slots: Everywhere and Workbench on the left (tray pieces
## as one row of single slots), After weaving and Level select on the right.
func _layout() -> void:
	var columns := {"Everywhere": 0, "Workbench": 0, "Woven": 1, "Levels": 1}
	var y := [150.0, 150.0]
	for g in Keys.GROUPS:
		var col: int = columns[g]
		var x := 70.0 + col * 630
		labels.append([Vector2(x, y[col]), GROUP_NAMES[g], true])
		y[col] += 38
		var pieces := []
		for a in Keys.ACTIONS:
			if a[1] != g:
				continue
			if str(a[0]).begins_with("piece_"):
				pieces.append(a[0])
				continue
			labels.append([Vector2(x, y[col] + SLOT.y / 2), a[2], false])
			for s in Keys.SLOTS:
				slots.append({"rect": Rect2(Vector2(x + 250 + s * (SLOT.x + 10), y[col]), SLOT), "action": a[0], "slot": s})
			y[col] += ROW
		if not pieces.is_empty():
			labels.append([Vector2(x, y[col] + PIECE_SLOT.y / 2), "Tray pieces", false])
			y[col] += ROW
			for i in pieces.size():
				var r := Rect2(Vector2(x + i * (PIECE_SLOT.x + 6), y[col]), PIECE_SLOT)
				slots.append({"rect": r, "action": pieces[i], "slot": 0})
			y[col] += ROW
		y[col] += 14


func _toggle_grid() -> void:
	Keys.set_grid(not Keys.grid)
	grid_button.toggled_on = Keys.grid
	grid_button.queue_redraw()


func _toggle_hints() -> void:
	Keys.set_hints(not Keys.shown, get_tree())
	hints_button.toggled_on = Keys.shown
	hints_button.queue_redraw()


func _reset_keys() -> void:
	Keys.reset()
	Keys.save_settings()
	capturing = {}
	for a in Keys.ACTIONS:
		flash[a[0]] = t


## While waiting for a key, the next key press goes to the slot (before the
## hints key or any screen sees it).
func _input(event: InputEvent) -> void:
	if capturing.is_empty() or not (event is InputEventKey and event.pressed) or event.echo:
		return
	Keys.handled(self)
	if event.keycode in Keys.MODIFIERS:
		return
	if Keys.normalize(event.keycode) in Keys.bindings["back"]:
		capturing = {}
		return
	for moved in Keys.bind(capturing["action"], capturing["slot"], event.keycode):
		flash[moved] = t
	capturing = {}
	Keys.save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and Keys.action(event, Keys.EVERYWHERE) == "back":
		Keys.handled(self)
		back.emit()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var hit := _slot_at(event.position)
	if event.pressed:
		_pressed_slot = hit
		return
	if hit < 0 or hit != _pressed_slot:
		capturing = {}
		return
	tap_slot(hit)


## Tapping a slot waits for a key; tapping it again while waiting clears it.
func tap_slot(i: int) -> void:
	var s: Dictionary = slots[i]
	if capturing.get("action", "") == s["action"] and capturing.get("slot", -1) == s["slot"]:
		Keys.bind(s["action"], s["slot"], 0)
		Keys.save_settings()
		capturing = {}
	else:
		capturing = {"action": s["action"], "slot": s["slot"]}


func _slot_at(pos: Vector2) -> int:
	for i in slots.size():
		if slots[i]["rect"].has_point(pos):
			return i
	return -1


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	K.text(self, P.display(600), Vector2(DESIGN.x / 2, 44), "Options", 40, P.INK)
	if with_keys:
		K.text(self, P.ui(700), Vector2(DESIGN.x / 2, 96), "Tap a key to change it, then press the new one. Tap it again to clear it.", 16, P.INK_SOFT)
	for tg in toggles:
		K.text(self, P.ui(700), tg[0].position + Vector2(60, 22), tg[1], 17, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	for l in labels:
		if l[2]:
			K.text(self, P.display(600), l[0] + Vector2(0, 8), l[1], 22, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		else:
			K.text(self, P.ui(700), l[0], l[1], 17, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
	for s in slots:
		_draw_slot(s)


func _draw_slot(s: Dictionary) -> void:
	var r: Rect2 = s["rect"]
	var waiting: bool = capturing.get("action", "") == s["action"] and capturing.get("slot", -1) == s["slot"]
	var k: int = Keys.bindings[s["action"]][s["slot"]]
	var fill := P.TAG
	if waiting:
		fill = Color(P.HOOP, 0.25 + 0.15 * sin(t * 6))
	elif t - flash.get(s["action"], -9.0) < 1.0 and int((t - flash[s["action"]]) * 6) % 2 == 0:
		fill = Color(P.HOOP, 0.35)
	K.fill(self, K.round_rect(Rect2(r.position + Vector2(0, 2), r.size), 8), P.SHADOW)
	K.shape(self, K.round_rect(r, 8), fill, Color(P.INK, 0.8 if waiting else 0.5), 2.5 if waiting else 1.5)
	if waiting:
		K.text(self, P.ui(700), r.get_center(), "press a key", 13, P.INK_SOFT)
	elif k == 0:
		K.text(self, P.ui(700), r.get_center(), "–", 16, Color(P.INK, 0.3))
	else:
		Keys.key_text(self, r.get_center(), Keys.key_name(k), 15, P.INK)
