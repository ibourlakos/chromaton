## Profiles over the level select (DESIGN.md 9): its profile chip opens it.
## A badge per profile, its critter and its name; a tap switches to it. The
## "+" badge adds one: tap a critter for its badge, type a name if you like
## (it defaults to the critter's), and the check makes it. The pencil under
## the one playing changes its badge and name the same way. Back, the
## upper-leftmost control as everywhere, closes it.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const Pieces = preload("res://core/pieces.gd")
const Profiles = preload("res://core/profiles.gd")

signal chosen(id: int)
signal added(badge: String, name: String)
signal edited(id: int, badge: String, name: String)
signal back

const DESIGN := Vector2(1280, 800)
const BADGE := Vector2(132, 150)

var profiles
var adding := false
var editing := -1  # the profile whose badge and name are being changed (adding is on too)
var badge := "shift"  # the critter picked for a new profile
var name_edit: LineEdit
var name_edit_text := ""
var buttons: Array = []
var t := 0.0


func setup(p_profiles) -> void:
	profiles = p_profiles


func _ready() -> void:
	size = DESIGN
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for b in buttons:
		b.queue_free()
	buttons = []
	if name_edit != null:  # what was typed stays while another badge is picked
		name_edit_text = name_edit.text
		name_edit.queue_free()
		name_edit = null
	var b = ToyButton.make("back")
	b.position = Vector2(14, 6)
	b.key = Keys.label("back")
	b.pressed.connect(_back)
	_add(b)
	if not adding:
		var row: Array = profiles.list.duplicate()
		var total := (row.size() + 1) * (BADGE.x + 20) - 20
		for i in row.size():
			var e: Dictionary = row[i]
			var id: int = e["id"]
			var nb = badge_button(e, e["id"] == profiles.current)
			nb.position = Vector2(DESIGN.x / 2 - total / 2 + i * (BADGE.x + 20), 300)
			nb.pressed.connect(func(): chosen.emit(id))
			_add(nb)
			if id == profiles.current:  # its badge and name can change
				var pen = ToyButton.make("pencil")
				pen.position = nb.position + Vector2(BADGE.x / 2 - 26, BADGE.y + 16)
				pen.pressed.connect(func(): edit(id))
				_add(pen)
		var plus = ToyButton.new()
		plus.custom_minimum_size = BADGE
		plus.size = BADGE
		plus.position = Vector2(DESIGN.x / 2 - total / 2 + row.size() * (BADGE.x + 20), 300)
		plus.painter = func(btn: Control, r: Rect2, down: bool) -> void:
			var body := Rect2(r.position + (Vector2(0, 2) if down else Vector2.ZERO), r.size)
			K.dashed(btn, K.closed(K.round_rect(body, 18)), Color(P.INK, 0.45), 2.5, 9, 6)
			K.text(btn, P.display(600), body.get_center() + Vector2(0, -10), "+", 54, P.INK_SOFT)
		plus.pressed.connect(func():
			adding = true
			editing = -1
			_build())
		_add(plus)
		return
	# Adding: the critters to pick a badge from, a name, and the check.
	var total := Profiles.BADGES.size() * (BADGE.x + 20) - 20
	for i in Profiles.BADGES.size():
		var kind: String = Profiles.BADGES[i]
		var cb = badge_button({"badge": kind, "name": ""}, kind == badge)
		cb.position = Vector2(DESIGN.x / 2 - total / 2 + i * (BADGE.x + 20), 230)
		cb.pressed.connect(func():
			badge = kind
			_build())
		_add(cb)
	var typed := name_edit_text
	name_edit = LineEdit.new()
	name_edit.text = typed
	name_edit.placeholder_text = Pieces.display_name(badge)
	name_edit.max_length = 16
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.position = Vector2(DESIGN.x / 2 - 170, 430)
	name_edit.size = Vector2(340, 56)
	name_edit.add_theme_font_override("font", P.display(600))
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.add_theme_color_override("font_color", P.INK)
	name_edit.add_theme_color_override("font_placeholder_color", Color(P.INK, 0.4))
	var box := StyleBoxFlat.new()
	box.bg_color = P.TAG
	box.border_color = P.INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	name_edit.add_theme_stylebox_override("normal", box)
	name_edit.add_theme_stylebox_override("focus", box)
	name_edit.text_submitted.connect(func(_s): _make())
	add_child(name_edit)
	var ok = ToyButton.make("check", Vector2(72, 72))
	ok.position = Vector2(DESIGN.x / 2 - 36, 530)
	ok.toggled_on = true
	ok.pressed.connect(_make)
	_add(ok)


func _add(b) -> void:
	add_child(b)
	buttons.append(b)


func _make() -> void:
	var typed := (name_edit.text if name_edit != null else "").strip_edges()
	if editing >= 0:
		edited.emit(editing, badge, typed)
	else:
		added.emit(badge, typed)


## Changes this profile's badge and name: the new player's page, filled in.
func edit(id: int) -> void:
	var e: Dictionary = profiles.find(id)
	adding = true
	editing = id
	badge = str(e.get("badge", "mix"))
	name_edit_text = str(e.get("name", ""))
	if name_edit != null:
		name_edit.text = name_edit_text
	_build()


func _back() -> void:
	if adding:
		adding = false
		editing = -1
		name_edit_text = ""
		if name_edit != null:
			name_edit.text = ""
		_build()
	else:
		back.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and Keys.action(event, Keys.EVERYWHERE) == "back":
		_back()
		Keys.handled(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(P.paper_texture(), Rect2(Vector2.ZERO, DESIGN), true)
	K.text(self, P.display(600), Vector2(DESIGN.x / 2, 120), ("Your badge and name" if editing >= 0 else "A new player") if adding else "Who's playing?", 44, P.INK)
	if adding:
		K.text(self, P.ui(700), Vector2(DESIGN.x / 2, 410), "A name, if you like", 17, P.INK_SOFT)


## A profile's badge: its critter on tag paper, its name under it; ringed
## when it's the one playing (or picked).
static func badge_button(e: Dictionary, lit: bool):
	var b = ToyButton.new()
	b.custom_minimum_size = BADGE
	b.size = BADGE
	b.painter = func(btn: Control, r: Rect2, down: bool) -> void:
		var body := Rect2(r.position + (Vector2(0, 2) if down else Vector2.ZERO), r.size)
		if not down:
			K.fill(btn, K.round_rect(Rect2(r.position + Vector2(3, 5), r.size), 18), P.SHADOW)
		K.shape(btn, K.round_rect(body, 18), Color(P.HOOP, 0.25) if lit else P.TAG, P.INK, 3.5 if lit else 2.5)
		var kind := str(e.get("badge", "mix"))
		var look: String = Pieces.TABLE[kind]["look"] if Pieces.TABLE.has(kind) else "mix"
		var now := Time.get_ticks_msec() / 1000.0
		K.piece(btn, look, body.position + Vector2(body.size.x / 2, 62), 0.8, -1, 99.0, now, float(kind.length()))
		K.text(btn, P.display(600), Vector2(body.get_center().x, body.end.y - 22), Profiles.display_name(e), 19, P.INK)
	return b
