## The Pattern Book: a shelf of the paint pots earned so far, then the
## player's inventions, like a sticker album.
## Empty slots show which levels still hold an invention.
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const ToyButton = preload("res://ui/toy_button.gd")
const Keys = preload("res://ui/keys.gd")
const Pieces = preload("res://core/pieces.gd")
const Invention = preload("res://core/invention.gd")

signal back

const DESIGN := Vector2(1280, 800)
const SLOT := Vector2(306, 262)

var levels: Array = []
var progress
var t := 0.0


func setup(p_levels: Array, p_progress) -> void:
	levels = p_levels
	progress = p_progress


func _ready() -> void:
	size = DESIGN
	var b = ToyButton.make("back")
	b.position = Vector2(14, 6)
	b.key = "Esc"
	b.pressed.connect(func(): back.emit())
	add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_B]:
		Keys.handled(self)
		back.emit()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Invention slots in campaign order, pots aside: [level index, invention id, name].
func _slots() -> Array:
	var out := []
	for i in levels.size():
		if not levels[i].invention.is_empty() and Invention.paint_of(levels[i].invention) < 0:
			out.append([i, levels[i].invention["id"], levels[i].invention["name"]])
	return out


## The paint shelf, one place per paint: [paint, level index (-1 for the red
## pot, which is always there), invention id].
func _pots() -> Array:
	var out := []
	for paint in 8:
		out.append([paint, -1, ""])
	for i in levels.size():
		var paint := Invention.paint_of(levels[i].invention)
		if paint >= 0:
			out[paint] = [paint, i, levels[i].invention["id"]]
	return out


func _draw_shelf(page: Rect2) -> void:
	var y := page.position.y + 104
	var plank := Rect2(page.position.x + 30, y + 30, page.size.x - 60, 14)
	K.fill(self, K.round_rect(Rect2(plank.position + Vector2(2, 4), plank.size), 6), P.SHADOW)
	K.shape(self, K.round_rect(plank, 6), P.WOOD_LT, P.INK, 2)
	var step := (page.size.x - 80) / 8.0
	for spot in _pots():
		var paint: int = spot[0]
		var x := page.position.x + 40 + step * (paint + 0.5)
		var price := 1  # the red pot
		if spot[1] >= 0:
			var inv: Dictionary = progress.inventions.get(spot[2], {})
			if inv.is_empty():
				K.pot_outline(self, Vector2(x, y), 0.85, Color(P.INK, 0.3))
				K.text(self, P.ui(700), Vector2(x, y + 64), "Level %d" % levels[spot[1]].number, 14, Color(P.INK, 0.45))
				continue
			price = int(inv["cost"])
		K.pot(self, Vector2(x, y), 0.85, 99, t, paint * 0.37, paint)
		K.icon(self, "pieces", Vector2(x - 12, y + 64), 0.8, P.INK_SOFT)
		K.text(self, P.ui(800), Vector2(x + 2, y + 64), str(price), 15, P.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT)


func _draw() -> void:
	K.icon(self, "book", Vector2(DESIGN.x / 2 - 150, 56), 2.0, P.INK)
	K.text(self, P.display(600), Vector2(DESIGN.x / 2 + 20, 56), "Pattern Book", 44, P.INK)
	K.text(self, P.ui(700), Vector2(DESIGN.x / 2, 100), "Machines you invented become pieces you can use again.", 17, P.INK_SOFT)
	# The album page
	var page := Rect2(120, 140, DESIGN.x - 240, 620)
	K.fill(self, K.round_rect(Rect2(page.position + Vector2(4, 6), page.size), 18), P.SHADOW)
	K.shape(self, K.round_rect(page, 18), P.TAG, P.INK, 2.5)
	_draw_shelf(page)
	var slots := _slots()
	var cols := 3
	var origin := page.position + Vector2(40, 224)
	for k in maxi(slots.size(), 3):
		var r := Rect2(origin + Vector2(k % cols, k / cols) * (SLOT + Vector2(20, 16)), SLOT)
		if k >= slots.size():
			K.dashed(self, K.closed(K.round_rect(r.grow(-20), 16)), Color(P.INK, 0.18), 2, 8, 6)
			continue
		var slot: Array = slots[k]
		var inv: Dictionary = progress.inventions.get(slot[1], {})
		if inv.is_empty():
			K.dashed(self, K.closed(K.round_rect(r.grow(-20), 16)), Color(P.INK, 0.4), 2, 8, 6)
			K.text(self, P.display(600), r.get_center() + Vector2(0, -10), "?", 48, Color(P.INK, 0.35))
			K.text(self, P.ui(700), r.get_center() + Vector2(0, 40), "Level %d" % (slot[0] + 1), 16, Color(P.INK, 0.45))
			continue
		K.sticker(self, r.position + Vector2(r.size.x / 2, 70), 1.5, inv["name"], 99, t, k * 0.7)
		# Price and what is inside
		var y := r.position.y + 150
		K.icon(self, "pieces", Vector2(r.position.x + 40, y), 1.2, P.INK)
		K.text(self, P.ui(800), Vector2(r.position.x + 58, y), "%d pieces" % int(inv["cost"]), 20, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
		var x := r.position.x + 40
		var counts: Dictionary = inv.get("counts", {})
		for kind in counts:
			_mini(kind, Vector2(x + 18, y + 58))
			K.text(self, P.ui(800), Vector2(x + 40, y + 62), "× %d" % int(counts[kind]), 17, P.INK, HORIZONTAL_ALIGNMENT_LEFT)
			x += 96
		K.text(self, P.ui(700), Vector2(r.position.x + r.size.x / 2, r.end.y - 6), "%d inputs · from level %d" % [int(inv["inputs"]), slot[0] + 1], 14, P.INK_SOFT)


func _mini(kind: String, c: Vector2) -> void:
	match Pieces.TABLE.get(kind, {}).get("look", ""):
		"pot":
			K.pot(self, c, 0.36, 99, t, 0.1)
		"mix":
			K.tub(self, c, 0.36, -1, 99, "mix", t, 0.2)
		"invert":
			K.tub(self, c, 0.36, -1, 99, "invert", t, 0.6)
		"filter":
			K.tub(self, c, 0.36, -1, 99, "filter", t, 0.5)
		"shift":
			K.hamster(self, c, 0.44, -1, 99, 0, t, 0.3)
		_:
			K.tub(self, c, 0.36, -1, 99, "tub", t, 0.4)
