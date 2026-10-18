## The paint card: the eight paints as a mixing triangle, pinned under the
## workbench's Paints button (DESIGN.md 9.1). Red, yellow and blue sit at the
## corners where their glyph dots sit (red on top, yellow lower right, blue
## lower left); each mix sits on the edge between its two paints, black (all
## three) in the middle and white (no paint) apart. Opposites face each other
## across the middle, along the dashed lines, and Shift turns the triangle one
## corner clockwise.
##
## Not modal: the bench keeps working around it. A tap on the card puts it
## away (as does the Paints button, its key or Back).
extends Control

const P = preload("res://ui/palette.gd")
const K = preload("res://ui/draw_kit.gd")
const Paint = preload("res://core/paint.gd")

signal tapped

const SIZE := Vector2(290, 256)
const SIDE := 180.0  # the triangle's side
const DROP := 14.0
const TOP := 28.0  # the red corner's height on the card
## The Shift arrows: arcs of one ring round black, one over each side, in
## degrees (clockwise from the right): red to yellow, yellow to blue, blue to
## red, each stopping short of the corner drops and their names.
const RING := 112.0
const ARCS := [[-78.0, 18.0], [52.0, 128.0], [162.0, 258.0]]


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tapped.emit()
		accept_event()


## Where each paint sits on the card, by its value.
static func spots() -> Dictionary:
	var h := SIDE * sqrt(3.0) / 2
	var red := Vector2(SIZE.x / 2, TOP)
	var blue := red + Vector2(-SIDE / 2, h)
	var yellow := red + Vector2(SIDE / 2, h)
	return {
		1: red, 2: yellow, 4: blue,
		3: (red + yellow) / 2, 6: (yellow + blue) / 2, 5: (blue + red) / 2,
		7: (red + yellow + blue) / 3,
		0: Vector2(SIZE.x - 24, 26),
	}


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, SIZE)
	K.fill(self, K.round_rect(Rect2(box.position + Vector2(3, 4), box.size), 8), P.SHADOW)
	K.shape(self, K.round_rect(box, 8), P.TAG, P.INK, 2)
	var at := spots()
	# Opposites across the middle, then the triangle's edges.
	for pair in [[1, 6], [2, 5], [4, 3]]:
		K.dashed(self, PackedVector2Array([at[pair[0]], at[pair[1]]]), Color(P.INK, 0.28), 1.5, 5, 4)
	K.stroke(self, PackedVector2Array([at[1], at[2], at[4]]), Color(P.INK, 0.4), 2)
	_draw_shift_arrows(at)
	for color in at:
		K.drop(self, at[color], DROP, color)
	# Names under the drops, so the arrows can hug the sides; black's above
	# it, out of orange's and purple's way.
	for color in at:
		_label(at[color] + Vector2(0, -DROP - 17 if color == 7 else DROP + 12), Paint.name_of(color))
	var pin := Vector2(SIZE.x / 2, 2)
	K.shape(self, K.ellipse(pin, 6, 6, 0, 16), P.HOOP, P.INK, 2)
	K.disc(self, pin + Vector2(-1.5, -1.5), 1.6, P.PIN_GLINT)


## Bold ink arrows round the triangle, one arching over each side from
## near one corner to near the next, turning the way the Shift Wheel does: red to yellow to
## blue, and the mixes with them (orange to green to purple). Each spans a
## whole side, so it reads as one corner on (playtest R3: short arrows from
## red to orange read as red turning orange). Ink, never a paint's hue.
func _draw_shift_arrows(at: Dictionary) -> void:
	var mid: Vector2 = at[7]
	for arc in ARCS:
		var pts := PackedVector2Array()
		for i in 25:
			var a := deg_to_rad(lerpf(arc[0], arc[1], i / 24.0))
			pts.append(mid + Vector2(cos(a), sin(a)) * RING)
		_arrow(pts)


## An ink arrow along pts, its head at the end.
func _arrow(pts: PackedVector2Array) -> void:
	var ink := Color(P.INK, 0.85)
	var tip := pts[pts.size() - 1]
	var back := (tip - pts[pts.size() - 2]).normalized()
	var side := Vector2(-back.y, back.x)
	pts[pts.size() - 1] = tip - back * 6  # the line stops inside the head
	K.stroke(self, pts, ink, 3, false)
	K.fill(self, PackedVector2Array([tip + back * 3, tip - back * 8 + side * 6, tip - back * 8 - side * 6]), ink)


## A paint's name on a scrap of tag paper, so the lines pass behind it.
func _label(c: Vector2, s: String) -> void:
	var w := _width(s)
	K.fill(self, K.round_rect(Rect2(c - Vector2(w / 2 + 4, 9), Vector2(w + 8, 18)), 4), P.TAG)
	K.text(self, P.ui(700), c, s, 13, P.INK)


static func _width(s: String) -> float:
	return P.ui(700).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
