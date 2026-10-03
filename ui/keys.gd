## Keyboard keys: which key does what, and the small key caps drawn on the
## controls they press.
##
## Every key only speeds up something a tap already does, so nothing needs a
## keyboard. Each action has up to two keys, changeable in Options (not on
## mobile builds) and kept in their own settings file, apart from progress.
## The caps show by default unless the device has a touch screen; touching the
## screen hides them, pressing a key brings them back, and the hints key (H or
## ?) or Options turns them on and off for good.
extends RefCounted

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")

const GROUP := "key_hints"  # nodes that draw caps and must redraw on a toggle
const PATH := "user://chromaton_settings.json"
const EVERYWHERE := "Everywhere"
const GROUPS := [EVERYWHERE, "Workbench", "Woven", "Levels"]

## [action, group, name shown in Options, default keys]. Keys only clash
## within a group, or with a group and Everywhere.
const ACTIONS := [
	["back", EVERYWHERE, "Back", [KEY_ESCAPE]],
	["hints", EVERYWHERE, "Show key labels", [KEY_SLASH, KEY_H]],
	["run", "Workbench", "Run / pause", [KEY_SPACE]],
	["step", "Workbench", "Step", [KEY_S, KEY_RIGHT]],
	["step_back", "Workbench", "Step back", [KEY_A, KEY_LEFT]],
	["reset", "Workbench", "Reset", [KEY_R]],
	["undo", "Workbench", "Undo", [KEY_Z]],
	["slower", "Workbench", "Slower", [KEY_MINUS]],
	["faster", "Workbench", "Faster", [KEY_EQUAL]],
	["speed", "Workbench", "Next speed", [KEY_TAB]],
	["delete", "Workbench", "Delete selected", [KEY_DELETE, KEY_BACKSPACE]],
	["piece_1", "Workbench", "Tray piece 1", [KEY_1]],
	["piece_2", "Workbench", "Tray piece 2", [KEY_2]],
	["piece_3", "Workbench", "Tray piece 3", [KEY_3]],
	["piece_4", "Workbench", "Tray piece 4", [KEY_4]],
	["piece_5", "Workbench", "Tray piece 5", [KEY_5]],
	["piece_6", "Workbench", "Tray piece 6", [KEY_6]],
	["piece_7", "Workbench", "Tray piece 7", [KEY_7]],
	["piece_8", "Workbench", "Tray piece 8", [KEY_8]],
	["piece_9", "Workbench", "Tray piece 9", [KEY_9]],
	["next", "Woven", "Next level", [KEY_ENTER, KEY_RIGHT]],
	["replay", "Woven", "Weave again", [KEY_R]],
	["prev_page", "Levels", "Page back", [KEY_LEFT, KEY_A]],
	["next_page", "Levels", "Page forward", [KEY_RIGHT, KEY_D]],
	["continue", "Levels", "Next unsolved level", [KEY_ENTER]],
	["book", "Levels", "Pattern Book", [KEY_B]],
	["options", "Levels", "Options", [KEY_O]],
]
const SLOTS := 2
## Keys that only modify others; they can't be bound.
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK, KEY_NUMLOCK]
## Keys that count as another key (number pad, shifted symbols).
const SAME_AS := {
	KEY_KP_1: KEY_1, KEY_KP_2: KEY_2, KEY_KP_3: KEY_3, KEY_KP_4: KEY_4, KEY_KP_5: KEY_5,
	KEY_KP_6: KEY_6, KEY_KP_7: KEY_7, KEY_KP_8: KEY_8, KEY_KP_9: KEY_9, KEY_KP_0: KEY_0,
	KEY_KP_ADD: KEY_EQUAL, KEY_PLUS: KEY_EQUAL, KEY_KP_SUBTRACT: KEY_MINUS,
	KEY_KP_ENTER: KEY_ENTER, KEY_QUESTION: KEY_SLASH,
}
## Short names for keys whose own names are long or are symbols.
const NAMES := {
	KEY_ESCAPE: "Esc", KEY_DELETE: "Del", KEY_BACKSPACE: "Bksp", KEY_MINUS: "−",
	KEY_EQUAL: "+", KEY_SLASH: "?", KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_BACKSLASH: "\\",
	KEY_QUOTELEFT: "`", KEY_PAGEUP: "PgUp", KEY_PAGEDOWN: "PgDn", KEY_INSERT: "Ins",
	KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓",
}

static var bindings := defaults()  # action -> [key, key] (0: none)
static var settings_path := PATH  # tests point this elsewhere
static var shown := not DisplayServer.is_touchscreen_available()
static var _choice = null  # true/false once chosen for good (hints key, Options)


static func defaults() -> Dictionary:
	var out := {}
	for a in ACTIONS:
		var keys: Array = a[3].duplicate()
		keys.resize(SLOTS)
		out[a[0]] = keys.map(func(k): return 0 if k == null else k)
	return out


static func group_of(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return ""


## Options shows keys only where a keyboard is likely (not phone builds).
static func rebindable() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))


## The key an event counts as.
static func normalize(k: int) -> int:
	return SAME_AS.get(k, k)


## The action a key press means on a screen ("" for none). The digit row also
## matches by position, for layouts (AZERTY) that need Shift for digits.
static func action(event: InputEventKey, group: String) -> String:
	var found := _action_for(normalize(event.keycode), group)
	var pk := normalize(event.physical_keycode)
	if found == "" and pk >= KEY_0 and pk <= KEY_9:
		found = _action_for(pk, group)
	return found


static func _action_for(k: int, group: String) -> String:
	for a in ACTIONS:
		if (a[1] == group or a[1] == EVERYWHERE) and k in bindings[a[0]]:
			return a[0]
	return ""


static func _clash(g1: String, g2: String) -> bool:
	return g1 == g2 or g1 == EVERYWHERE or g2 == EVERYWHERE


## Puts a key on an action's slot (0 clears it). The key leaves any action it
## would clash with; returns those actions.
static func bind(act: String, slot: int, k: int) -> Array:
	k = normalize(k)
	var moved := []
	if k != 0:
		var g := group_of(act)
		for a in ACTIONS:
			var keys: Array = bindings[a[0]]
			if _clash(g, a[1]) and k in keys and not (a[0] == act and keys.find(k) == slot):
				keys[keys.find(k)] = 0
				if a[0] != act:
					moved.append(a[0])
	bindings[act][slot] = k
	return moved


static func reset() -> void:
	bindings = defaults()


## A key's name for caps and Options.
static func key_name(k: int) -> String:
	if k == 0:
		return ""
	if NAMES.has(k):
		return NAMES[k]
	return OS.get_keycode_string(k)


## The cap label for an action: its first key.
static func label(act: String) -> String:
	for k in bindings.get(act, []):
		if k != 0:
			return key_name(k)
	return ""


# ---------------------------------------------------------------------------
# Settings file
# ---------------------------------------------------------------------------

static func save_settings(path := "") -> void:
	path = settings_path if path == "" else path
	var keys := {}
	for act in bindings:
		keys[act] = bindings[act]
	var d := {"keys": keys}
	if _choice != null:
		d["hints"] = _choice
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))


static func load_settings(path := "") -> void:
	path = settings_path if path == "" else path
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if not d is Dictionary:
		return
	reset()
	var keys = d.get("keys", {})
	if keys is Dictionary:
		for act in keys:
			if bindings.has(act) and keys[act] is Array:
				for slot in mini(SLOTS, keys[act].size()):
					bindings[act][slot] = int(keys[act][slot])
	if d.has("hints"):
		_choice = bool(d["hints"])
		shown = _choice


# ---------------------------------------------------------------------------
# Key caps
# ---------------------------------------------------------------------------

## Watches every input event (called from the root screen before anything
## handles it). Returns true when the event was the hints key.
static func watch(event: InputEvent, tree: SceneTree) -> bool:
	if event is InputEventScreenTouch and event.pressed and shown:
		_show(false, tree)
	elif event is InputEventKey and event.pressed and not event.echo:
		if normalize(event.keycode) in bindings["hints"]:
			set_hints(not shown, tree)
			return true
		if not shown and (_choice == null or _choice):
			_show(true, tree)
	return false


## Turns the caps on or off for good (the hints key, Options).
static func set_hints(on: bool, tree: SceneTree) -> void:
	_choice = on
	_show(on, tree)
	save_settings()


static func _show(on: bool, tree: SceneTree) -> void:
	shown = on
	tree.call_group(GROUP, "queue_redraw")


## Draws a key cap centred on c (when hints are shown).
static func cap(ci: CanvasItem, c: Vector2, text: String) -> void:
	if not shown or text == "":
		return
	var w := maxf(20.0, text_width(text, 12) + 10)
	var r := Rect2(c - Vector2(w / 2, 10), Vector2(w, 20))
	K.fill(ci, K.round_rect(Rect2(r.position + Vector2(0, 2), r.size), 5), P.SHADOW)
	K.shape(ci, K.round_rect(r, 5), P.PAPER, Color(P.INK, 0.7), 1.5)
	key_text(ci, c, text, 12, P.INK)


static func text_width(text: String, size: int) -> float:
	if text in ["←", "→", "↑", "↓"]:
		return size
	return P.ui(800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A key name centred on c. The fonts have no arrows, so arrows are drawn.
static func key_text(ci: CanvasItem, c: Vector2, text: String, size: int, col: Color) -> void:
	var dirs := {"←": Vector2.LEFT, "→": Vector2.RIGHT, "↑": Vector2.UP, "↓": Vector2.DOWN}
	if dirs.has(text):
		var d: Vector2 = dirs[text]
		var s := size / 12.0
		var n := Vector2(-d.y, d.x)
		ci.draw_line(c - d * 5 * s, c + d * 4 * s, col, 2 * s)
		ci.draw_colored_polygon(PackedVector2Array([c + d * 6 * s, c + (d + n * 4) * s, c + (d - n * 4) * s]), col)
	else:
		K.text(ci, P.ui(800), c, text, size, col)


## Marks a key as used so no other screen acts on it.
static func handled(node: Node) -> void:
	if node.is_inside_tree():
		node.get_viewport().set_input_as_handled()
