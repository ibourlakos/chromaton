## Critter Workshop drawing, ported from mockups/style-studies.html.
##
## Chunky toy shapes with thick ink outlines, drawn with CanvasItem calls.
## Every function takes the CanvasItem to draw on. Critters are drawn in
## their own local coordinates (as in the mockup) and placed with a
## transform, so `s` scales the whole critter.
##
## Living things are drawn again every frame, so shapes are worked out once and
## kept: a unit circle per point count, a rounded rectangle per size, a drop
## per radius, the critters' bodies. Each use only places the kept shape with
## one transform (done by the engine, not point by point in script). The
## shapes the public functions hand back are fresh copies, safe to change.
extends RefCounted

const P = preload("res://ui/palette.gd")

const PIP := [[1, -PI / 2], [2, PI / 6], [4, 5 * PI / 6]]

static var _circles := {}  # point count -> unit circle
static var _round_rects := {}  # Vector4(w, h, radius, n) -> outline from (0, 0)
static var _arcs := {}  # Vector4(r, a0, a1, n) -> arc around (0, 0)
static var _teardrops := {}  # radius -> drop around (0, 0)
static var _bodies := {}  # name -> a critter body in its own coordinates
## Sizes that animate (a drop shrinking into the loom, a note popping up)
## would fill the caches without end: past this many, a shape is worked out
## each time instead of kept.
const KEEP_MAX := 512


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

static func ellipse(c: Vector2, rx: float, ry: float, rot := 0.0, n := 36) -> PackedVector2Array:
	if not _circles.has(n):
		var unit := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			unit.append(Vector2(cos(a), sin(a)))
		_circles[n] = unit
	return Transform2D(rot, Vector2(rx, ry), 0.0, c) * (_circles[n] as PackedVector2Array)


## Points of a quadratic curve, without its start point.
static func quad(p0: Vector2, p1: Vector2, p2: Vector2, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(1, n + 1):
		var t := float(i) / n
		pts.append(p0 * (1 - t) * (1 - t) + p1 * 2 * (1 - t) * t + p2 * t * t)
	return pts


static func cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array([p0])
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		pts.append(p0 * u * u * u + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t * t * t)
	return pts


## Points on a circular arc from a0 to a1, both ends included.
static func arc(c: Vector2, r: float, a0: float, a1: float, n := 16) -> PackedVector2Array:
	var key := Vector4(r, a0, a1, n)
	var pts: PackedVector2Array = _arcs.get(key, PackedVector2Array())
	if pts.is_empty():
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(Vector2(cos(a), sin(a)) * r)
		if _arcs.size() < KEEP_MAX:
			_arcs[key] = pts
	return Transform2D(0.0, c) * pts


static func round_rect(r: Rect2, rad: float, n := 5) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2)
	var key := Vector4(r.size.x, r.size.y, rad, n)
	var pts: PackedVector2Array = _round_rects.get(key, PackedVector2Array())
	if pts.is_empty():
		pts = _round_rect_at_origin(r.size, rad, n)
		if _round_rects.size() < KEEP_MAX:
			_round_rects[key] = pts
	return Transform2D(0.0, r.position) * pts


static func _round_rect_at_origin(size: Vector2, rad: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rad, rad), PI],
		[Vector2(size.x - rad, rad), 1.5 * PI],
		[size - Vector2(rad, rad), 0.0],
		[Vector2(rad, size.y - rad), 0.5 * PI],
	]
	# When the radius is half a side, neighbouring corner arcs meet in one
	# point: skip repeats, or the polygon can fail to triangulate.
	for corner in corners:
		for i in n + 1:
			var a: float = corner[1] + 0.5 * PI * i / n
			var p: Vector2 = corner[0] + Vector2(cos(a), sin(a)) * rad
			if pts.is_empty() or not p.is_equal_approx(pts[pts.size() - 1]):
				pts.append(p)
	if pts.size() > 1 and pts[0].is_equal_approx(pts[pts.size() - 1]):
		pts.remove_at(pts.size() - 1)
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if pts.size() > 0:
		out.append(pts[0])
	return out


## Point at fraction f of the way along a polyline.
static func along(pts: PackedVector2Array, f: float) -> Vector2:
	if pts.size() == 0:
		return Vector2.ZERO
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var d := clampf(f, 0, 1) * total
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if d <= seg or i == pts.size() - 1:
			return pts[i - 1].lerp(pts[i], clampf(d / seg, 0, 1) if seg > 0 else 0.0)
		d -= seg
	return pts[pts.size() - 1]


static func distance_to_polyline(pts: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for i in range(1, pts.size()):
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
		best = minf(best, q.distance_to(p))
	return best


# ---------------------------------------------------------------------------
# Primitive drawing
# ---------------------------------------------------------------------------

static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


static func stroke(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, is_closed := true) -> void:
	if pts.size() < 2:
		return
	ci.draw_polyline(closed(pts) if is_closed else pts, col, w, true)


static func shape(ci: CanvasItem, pts: PackedVector2Array, fill_col: Color, line_col: Color, w: float) -> void:
	fill(ci, pts, fill_col)
	stroke(ci, pts, line_col, w)


## A thick line with round ends.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w / 2, col, true, -1, true)
	ci.draw_circle(b, w / 2, col, true, -1, true)


## Round caps at the ends, and round joints only where the line turns
## sharply: on a smooth curve (a tube) a disc at every point would be
## invisible but costly.
static func polyline_round(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	_polyline_joined(ci, pts, round_joints(pts), col, w)


## The points of a polyline that need a round cap or joint: both ends, and
## wherever it turns by more than about 20°.
static func round_joints(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		if i > 0 and i < n - 1:
			var a := pts[i] - pts[i - 1]
			var b := pts[i + 1] - pts[i]
			if a.length_squared() > 0 and b.length_squared() > 0 and a.normalized().dot(b.normalized()) > 0.94:
				continue
		out.append(pts[i])
	return out


static func _polyline_joined(ci: CanvasItem, pts: PackedVector2Array, joints: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(pts, col, w, true)
	for p in joints:
		ci.draw_circle(p, w / 2, col, true, -1, true)


static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col, true, -1, true)


static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w: float) -> void:
	ci.draw_arc(c, r, 0, TAU, maxi(16, int(r * 1.5)), col, w, true)


static func dashed(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	var run := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		var pos := 0.0
		while seg - pos > left:
			pos += left
			var p := a.lerp(b, pos / seg)
			if on:
				run.append(p)
				ci.draw_polyline(run, col, w, true)
			run = PackedVector2Array([p])
			on = not on
			left = gap if not on else dash
		left -= seg - pos
		run.append(b)
	if on and run.size() > 1:
		ci.draw_polyline(run, col, w, true)


static func set_xf(ci: CanvasItem, origin: Vector2, scale: Vector2, rot := 0.0) -> void:
	ci.draw_set_transform(origin, rot, scale)


static func reset_xf(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0) -> void:
	# pos is the middle of the text line (centered) or its left middle.
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var y := pos.y + (asc - desc) / 2
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_string(font, Vector2(pos.x - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_string(font, Vector2(pos.x - w, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	else:
		ci.draw_string(font, Vector2(pos.x, y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)


# ---------------------------------------------------------------------------
# Paint drops
# ---------------------------------------------------------------------------

static func teardrop(c: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = _teardrops.get(r, PackedVector2Array())
	if pts.is_empty():
		pts = _teardrop_at(Vector2.ZERO, r)
		if _teardrops.size() < KEEP_MAX:
			_teardrops[r] = pts
	return Transform2D(0.0, c) * pts


static func _teardrop_at(c: Vector2, r: float) -> PackedVector2Array:
	var top := c + Vector2(0, -1.45 * r)
	var pts := PackedVector2Array([top])
	var right := c + Vector2(r, 0.05 * r)
	pts.append_array(quad(top, c + Vector2(1.02 * r, -0.35 * r), right, 8))
	for i in range(1, 18):
		var a := PI * i / 18.0
		pts.append(c + Vector2(0, 0.05 * r) + Vector2(cos(a), sin(a)) * r)
	var left := c + Vector2(-r, 0.05 * r)
	pts.append(left)
	var back := quad(left, c + Vector2(-1.02 * r, -0.35 * r), top, 8)
	back.remove_at(back.size() - 1)
	pts.append_array(back)
	return pts


## A paint drop with its glyph dots. White is a dashed, hollow drop.
static func drop(ci: CanvasItem, c: Vector2, r: float, color: int) -> void:
	var pts := teardrop(c, r)
	if color == 0:
		fill(ci, pts, P.SIG[0])
		dashed(ci, closed(pts), P.INK, maxf(1.2, r * 0.18), r * 0.38, r * 0.28)
	else:
		fill(ci, pts, P.SIG[color])
		stroke(ci, pts, P.INK, maxf(1.4, r * 0.22))
		fill(ci, ellipse(c + Vector2(-0.45, -0.35) * r, r * 0.14, r * 0.26, -0.5, 12), P.SHINE)
	pips(ci, c + Vector2(0, 0.12 * r), r, color)


## Glyph dots: top for red, right for yellow, left for blue; filled if present.
static func pips(ci: CanvasItem, c: Vector2, r: float, color: int) -> void:
	var ink: Color = P.PIP_LIGHT if P.is_dark(color) else P.PIP_DARK
	for pip in PIP:
		var pc: Vector2 = c + Vector2(cos(pip[1]), sin(pip[1])) * r * 0.5
		if color & pip[0]:
			ci.draw_circle(pc, r * 0.21, ink, true, -1, true)
		else:
			ci.draw_arc(pc, r * 0.2, 0, TAU, 14, Color(ink, 0.55), maxf(1.0, r * 0.09), true)


## A round swatch with glyph dots (for card holes and legends).
static func swatch(ci: CanvasItem, c: Vector2, r: float, color: int) -> void:
	disc(ci, c, r, P.SIG[color])
	if color == 0:
		dashed(ci, closed(ellipse(c, r, r, 0, 24)), P.INK, 1.2, 2.5, 2.0)
	else:
		ring(ci, c, r, P.INK, 1.5)
	pips(ci, c + Vector2(0, 0.05 * r), r * 0.95, color)


# ---------------------------------------------------------------------------
# Tubes and ports
# ---------------------------------------------------------------------------

## A glass tube: an ink outline, the glass, a thin glint along its upper
## inner edge and a faint shade along its lower one, so a drop sits inside.
static func tube(ci: CanvasItem, pts: PackedVector2Array, selected := false) -> void:
	var joints := round_joints(pts)
	if selected:
		_polyline_joined(ci, pts, joints, P.HOOP, 20)
	_polyline_joined(ci, pts, joints, P.INK, 12)
	_polyline_joined(ci, pts, joints, P.GLASS, 7)
	_glass_edges(ci, pts)


## The glint (paper white, above) and shade (hoop grey, below) along the
## inside of a glass tube or stub, following its curve.
static func _glass_edges(ci: CanvasItem, pts: PackedVector2Array) -> void:
	if pts.size() < 2:
		return
	var up := PackedVector2Array()
	var down := PackedVector2Array()
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(d.y, -d.x)
		if n.y > 0 or (n.y == 0 and n.x > 0):
			n = -n  # the upper side, whichever way the tube runs
		up.append(pts[i] + n * 1.9)
		down.append(pts[i] - n * 2.1)
	ci.draw_polyline(down, P.TUBE_SHADE, 2.2, true)
	ci.draw_polyline(up, P.TUBE_GLINT, 1.6, true)


## A tube leaves an output going right and enters an input from the left.
static func tube_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var d := clampf(absf(b.x - a.x) * 0.5, 26, 120)
	if b.x < a.x + 20:
		d = 60 + (a.x - b.x) * 0.4
	return cubic(a, a + Vector2(d, 0), b - Vector2(d, 0), b, 24)


## A short pipe from a piece's side to one of its ports: glass going in,
## a wooden spout coming out.
static func stub(ci: CanvasItem, port: Vector2, body: Vector2, spout: bool) -> void:
	var pts := PackedVector2Array([body, port])
	polyline_round(ci, pts, P.INK, 12)
	polyline_round(ci, pts, P.WOOD_DK if spout else P.GLASS, 7)
	if spout:  # an ink collar where the glass tube slips over the spout
		var d := (port - body).normalized()
		line(ci, port - d * 4 + Vector2(-d.y, d.x) * 6, port - d * 4 - Vector2(-d.y, d.x) * 6, P.INK, 3)
	else:
		_glass_edges(ci, pts)


static func port_in(ci: CanvasItem, p: Vector2, lit := false) -> void:
	if lit:
		disc(ci, p, 13, Color(P.HOOP, 0.35))
	disc(ci, p, 7, P.GLASS)
	ring(ci, p, 7, P.INK, 2.5)
	ci.draw_arc(p, 4.4, PI * 1.05, PI * 1.6, 6, P.TUBE_GLINT, 1.6, true)  # the glass ring's highlight


static func port_out(ci: CanvasItem, p: Vector2, lit := false) -> void:
	if lit:
		disc(ci, p, 13, Color(P.HOOP, 0.35))
	disc(ci, p, 6.5, P.WOOD_DK)
	ring(ci, p, 6.5, P.INK, 2.5)


# ---------------------------------------------------------------------------
# Critters
# ---------------------------------------------------------------------------

static func _eyes(ci: CanvasItem, y: float, dx: float, blink: bool, look := Vector2(1, 1.5)) -> void:
	for ex in [-dx, dx]:
		if blink:
			line(ci, Vector2(ex - 6, y), Vector2(ex + 6, y), P.INK, 2.5)
			continue
		shape(ci, ellipse(Vector2(ex, y - 1), 7, 8, 0, 20), P.EYE_WHITE, P.INK, 2)
		disc(ci, Vector2(ex, y - 1) + look, 3.6, P.INK)


static func _blush(ci: CanvasItem, y: float, dx: float) -> void:
	for bx in [-dx, dx]:
		fill(ci, ellipse(Vector2(bx, y), 6, 3.5, 0, 16), P.BLUSH)


## Any piece, drawn through its look (core/pieces.gd): the one way a piece
## is drawn, on the bench, in the tray and in the journal, so a look can be
## swapped (a theme) without touching who draws it. `more` gives what some
## looks need: "turns" (the Shift Wheel's notches), "caught" (the catch pot's
## drops), "ins" and "outs" (Split's ports).
static func piece(ci: CanvasItem, look: String, c: Vector2, s: float, liq: int, age: float, t: float, seed := 0.0, more := {}) -> void:
	match look:
		"pot":
			pot(ci, c + Vector2(0, -2) * s, s, age, t, seed)
		"catch":
			catch_pot(ci, c + Vector2(0, -4) * s, s, more.get("caught", []), age, t, seed)
		"mix":
			mixing_tub(ci, c, s, liq, age, t, seed)
		"filter":
			sieve(ci, c, s, liq, age, t, seed)
		"invert":
			flip_pan(ci, c, s, liq, age, t, seed)
		"shift":
			hamster(ci, c + Vector2(0, -2) * s, s * 1.1, liq, age, int(more.get("turns", 0)), t, seed)
		"split":
			split(ci, c, more.get("ins", [c + Vector2(-34, 0)]), more.get("outs", [c + Vector2(34, -17), c + Vector2(34, 17)]), liq, age)
		_:
			tub(ci, c, s, liq, age, "tub", t, seed)


## The Mixing Tub: wide, round and jolly. Stubby arms stir a spoon round the
## paint; its cheeks puff as the swirl turns into the new paint.
static func mixing_tub(ci: CanvasItem, c: Vector2, s: float, liq: int, age: float, t: float, seed := 0.0) -> void:
	var k := exp(-age * 6.0)
	fill(ci, ellipse(c + Vector2(0, 36) * s, 54 * s, 7 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32) * s, Vector2(s * (1 + 0.05 * k), s * (1 - 0.06 * k)))
	var body := _body("bowl")
	fill(ci, body, P.WOOD)
	for stave in [-30, -10, 10, 30]:
		ci.draw_polyline(quad(Vector2(stave, -55), Vector2(stave * 1.25, -24), Vector2(stave * 0.7, 2), 6), P.WOOD_DK, 1.5, true)
	for hy in [-46.0, -14.0]:
		var hw := 50.0 if hy < -30 else 46.0
		ci.draw_polyline(quad(Vector2(-hw, hy), Vector2(0, hy + 7), Vector2(hw, hy), 10), P.HOOP, 5, true)
	stroke(ci, body, P.INK, 3.5)
	# Stubby arms out of its sides, reaching up to the spoon.
	var a := t * (1.2 + 5 * k)
	var grip := Vector2(cos(a) * 14 + 4, -66 + sin(a) * 3)
	for side in [-1, 1]:  # stubby arms: short and thick, from the rim's ends
		var shoulder := Vector2(side * 44, -50)
		var hand := grip + Vector2(side * 9, 2)
		var elbow := (shoulder + hand) / 2 + Vector2(side * 4, -5)
		var arm := quad(shoulder, elbow, hand, 6)
		arm.insert(0, shoulder)
		ci.draw_polyline(arm, P.INK, 12, true)
		ci.draw_polyline(arm, P.WOOD, 7.5, true)
	var blink := fmod(t * 0.31 + seed, 1.0) < 0.035
	_eyes(ci, -33, 16, blink)
	var puff := 1.0 + 0.7 * k
	for bx in [-31, 31]:
		fill(ci, ellipse(Vector2(bx, -22), 7 * puff, 4.5 * puff, 0, 16), P.BLUSH)
	# A wide smile that opens as it stirs.
	var smile := arc(Vector2(0, -27), 10, 0.12 * PI, 0.88 * PI, 12)
	if k > 0.15:
		fill(ci, smile, P.INK)
	ci.draw_polyline(smile, P.INK, 2.6, true)
	var surface := ellipse(Vector2(0, -56), 47, 10)
	fill(ci, surface, P.EMPTY_PAINT if liq < 0 else P.SIG[liq])
	stroke(ci, surface, P.INK, 3.5)
	if liq >= 0:
		fill(ci, ellipse(Vector2(-18, -58), 12, 2.5, 0, 16), P.SHINE_SOFT)
		var swirl := PackedVector2Array()
		for i in 9:
			var aa := a + i * 0.22
			swirl.append(Vector2(cos(aa) * 30, -56 + sin(aa) * 6))
		ci.draw_polyline(swirl, P.SWIRL if not P.is_dark(liq) else P.SWIRL_DARK, 2.5, true)
		if liq == 0:
			dashed(ci, closed(ellipse(Vector2(0, -56), 40, 6.5, 0, 30)), P.INK_SOFT, 1.5, 5, 4)
		_surface_pips(ci, Vector2(0, -56), liq)
	# The spoon: in the paint, its handle held by both hands.
	var bowl := Vector2(cos(a) * 24, -56 + sin(a) * 5)
	var knob := grip + Vector2(6, -22)
	line(ci, bowl, knob, P.INK, 8)
	line(ci, bowl, knob, P.WOOD_LT, 4)
	shape(ci, ellipse(knob, 4.5, 4.5, 0, 12), P.WOOD_LT, P.INK, 2)
	for side in [-1, 1]:
		shape(ci, ellipse(grip + Vector2(side * 9, 2), 7, 6.5, 0, 14), P.WOOD, P.INK, 2.4)
	reset_xf(ci)


## The Sieve: an actual sieve, a round mesh in a wooden hoop on little feet,
## with a fussy face on its hoop. It shakes when it fires and the grains it
## held back hop on the mesh (in neutrals: only paint wears the signal hues).
static func sieve(ci: CanvasItem, c: Vector2, s: float, liq: int, age: float, t: float, seed := 0.0) -> void:
	var shake := sin(age * 38.0) * 5.0 * exp(-age * 4.0) if age < 1.0 else 0.0
	fill(ci, ellipse(c + Vector2(0, 36) * s, 46 * s, 6 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(shake * s, 32 * s), Vector2(s, s))
	# Little feet under the mesh.
	for fx in [-24, 0, 24]:
		shape(ci, round_rect(Rect2(fx - 6, -6, 12, 10), 4), P.WOOD_DK, P.INK, 2.2)
	# The mesh, a shallow dome below the hoop, then the hoop's band.
	var dome := PackedVector2Array([Vector2(-42, -30)])
	dome.append_array(quad(Vector2(-42, -30), Vector2(0, 12), Vector2(42, -30), 12))
	fill(ci, dome, P.GLASS)
	var mesh := Color(P.INK, 0.28)
	for x in range(-36, 37, 8):
		var depth := -30.0 + 21.0 * (1.0 - pow(x / 42.0, 2))
		ci.draw_line(Vector2(x, -30), Vector2(x, depth), mesh, 1.2, true)
	for yy in [-22.0, -14.0, -7.0]:
		var w := 42.0 * sqrt(clampf(1.0 - (yy + 30.0) / 21.0, 0, 1))
		ci.draw_line(Vector2(-w, yy), Vector2(w, yy), mesh, 1.2, true)
	stroke(ci, dome, P.INK, 3)
	var band := PackedVector2Array([Vector2(-48, -52), Vector2(48, -52), Vector2(46, -30)])
	band.append_array(quad(Vector2(46, -30), Vector2(0, -24), Vector2(-46, -30), 10))
	shape(ci, band, P.WOOD, P.INK, 3.5)
	ci.draw_polyline(quad(Vector2(-47, -41), Vector2(0, -35), Vector2(47, -41), 10), P.WOOD_DK, 1.5, true)
	# A fussy face on the band: heavy lids, a pursed mouth.
	var blink := fmod(t * 0.31 + seed, 1.0) < 0.035
	for ex in [-14, 14]:
		if blink:
			line(ci, Vector2(ex - 5, -40), Vector2(ex + 5, -40), P.INK, 2.2)
			continue
		shape(ci, ellipse(Vector2(ex, -40), 5.5, 5.5, 0, 16), P.EYE_WHITE, P.INK, 1.8)
		disc(ci, Vector2(ex, -38.5), 2.6, P.INK)
		fill(ci, arc(Vector2(ex, -40), 5.8, PI, TAU, 10), P.WOOD_LT)
		line(ci, Vector2(ex - 6, -40), Vector2(ex + 6, -40), P.INK, 2)
	stroke(ci, PackedVector2Array([Vector2(-5, -31), Vector2(-1.5, -32.5), Vector2(1.5, -31), Vector2(5, -32.5)]), P.INK, 2.2, false)
	# The hoop's rim, the paint on the mesh inside it.
	var rim := ellipse(Vector2(0, -52), 48, 11)
	fill(ci, rim, P.EMPTY_PAINT if liq < 0 else P.SIG[liq])
	for x in range(-36, 37, 9):
		var h := 10.0 * sqrt(1.0 - pow(x / 48.0, 2))
		ci.draw_line(Vector2(x, -52 - h), Vector2(x, -52 + h), mesh, 1.1, true)
	stroke(ci, rim, P.INK, 3.5)
	stroke(ci, ellipse(Vector2(0, -52), 44, 9), P.WOOD_DK, 1.5)
	if liq >= 0:
		if liq == 0:
			dashed(ci, closed(ellipse(Vector2(0, -52), 38, 6, 0, 30)), P.INK_SOFT, 1.5, 5, 4)
		_surface_pips(ci, Vector2(0, -52), liq)
	if age < 0.8:
		var fade := 1.0 - age / 0.8
		for i in 3:
			var gx: float = [-22.0, 2.0, 24.0][i] + shake * 1.4
			var gy := -absf(sin(age * 24.0 + i * 1.7)) * 8.0 * fade
			shape(ci, ellipse(Vector2(gx, gy - 62), 3.2, 2.4, 0.4 * i, 10), Color(P.HOOP, fade), Color(P.INK, fade), 1.4)
	reset_xf(ci)


## The Flip Pan: a dark iron frying pan with a wooden handle and a face. Its
## paint sits in it like an omelette; when it fires it tosses it, the paint
## it got showing in the air, and the omelette lands on its other side: the
## opposite paint.
static func flip_pan(ci: CanvasItem, c: Vector2, s: float, liq: int, age: float, t: float, seed := 0.0) -> void:
	var tossing := age < 0.55
	var u := age / 0.55 if tossing else 1.0
	var tilt := -sin(u * PI) * 0.12 if tossing else 0.0
	fill(ci, ellipse(c + Vector2(0, 36) * s, 48 * s, 6 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32) * s, Vector2(s, s), tilt)
	# The handle, behind the pan, out to the lower left.
	line(ci, Vector2(-30, -24), Vector2(-66, -2), P.INK, 13)
	line(ci, Vector2(-30, -24), Vector2(-66, -2), P.WOOD, 8)
	disc(ci, Vector2(-62, -4.5), 2.2, P.WOOD_DK)
	shape(ci, ellipse(Vector2(-34, -22), 6, 5, 0.5, 12), P.IRON_DK, P.INK, 2)
	# The pan: its wall with a face, then the cooking face on top.
	var wall := PackedVector2Array([Vector2(-48, -40), Vector2(48, -40), Vector2(42, -14)])
	wall.append_array(quad(Vector2(42, -14), Vector2(0, -4), Vector2(-42, -14), 10))
	shape(ci, wall, P.IRON, P.INK, 3.5)
	ci.draw_polyline(quad(Vector2(-46, -33), Vector2(0, -26), Vector2(46, -33), 10), P.IRON_LT, 2, true)
	var blink := fmod(t * 0.31 + seed, 1.0) < 0.035
	for ex in [-15, 15]:
		fill(ci, ellipse(Vector2(ex * 1.75, -17), 5, 3, 0, 12), P.BLUSH)
		if blink:
			line(ci, Vector2(ex - 6, -25), Vector2(ex + 6, -25), P.TAG, 2.4)
			continue
		shape(ci, ellipse(Vector2(ex, -25), 7, 7.5, 0, 16), P.EYE_WHITE, P.INK, 2)
		disc(ci, Vector2(ex + 1, -23.5), 3.4, P.INK)
	if tossing:  # an "o" while it tosses
		stroke(ci, ellipse(Vector2(0, -14.5), 3, 3.5, 0, 12), P.TAG, 2)
	else:
		ci.draw_polyline(arc(Vector2(0, -18), 5, 0.2 * PI, 0.8 * PI, 8), P.TAG, 2, true)
	var top := ellipse(Vector2(0, -40), 48, 11)
	shape(ci, top, P.IRON_DK, P.INK, 3.5)
	stroke(ci, ellipse(Vector2(0, -40), 43, 8.5), P.IRON_LT, 1.5)
	# The omelette of paint: in the pan, or in the air, flipping.
	if liq >= 0:
		var shown := liq
		var lift := 0.0
		var flat := 1.0
		if tossing:
			lift = -sin(u * PI) * 46
			flat = cos(u * TAU)
			if u < 0.5:
				shown = 7 ^ liq
		var o := Vector2(0, -41 + lift)
		var cake := ellipse(o, 30, maxf(0.8, 7 * absf(flat)), 0, 24)
		fill(ci, cake, P.SIG[shown])
		stroke(ci, cake, P.INK, 2.2)
		if absf(flat) > 0.5:
			if shown == 0:
				dashed(ci, closed(ellipse(o, 24, 4.5, 0, 24)), P.INK_SOFT, 1.3, 4, 3)
			_surface_pips(ci, o, shown)
	reset_xf(ci)


## Wooden vat with a face. kind: "mix" (spoon, stirs), "invert" (flips like
## a pancake), "filter" (a sieve that shakes) or "tub" (any other vat). liq is
## the paint it holds (-1 empty); age is ticks since it last fired.
static func tub(ci: CanvasItem, c: Vector2, s: float, liq: int, age: float, kind: String, t: float, seed := 0.0) -> void:
	var k := exp(-age * 6.0)
	var sx := 1 + 0.05 * k
	var sy := 1 - 0.06 * k
	var hop := 0.0
	var shown := liq
	if kind == "invert" and age < 0.5:
		var u := age / 0.5
		sy = cos(u * TAU)
		hop = -sin(u * PI) * 18
		if u < 0.5 and liq >= 0:
			shown = 7 ^ liq
	fill(ci, ellipse(c + Vector2(0, 36) * s, 50 * s * (1 + hop / 60), 7 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32 + hop) * s, Vector2(s * sx, s * sy))
	var body := _body("tub")
	fill(ci, body, P.WOOD)
	for stave in [-24, 0, 24]:
		ci.draw_line(Vector2(stave, -60), Vector2(stave * 0.84, -2), P.WOOD_DK, 1.5, true)
	for hy in [-50, -10]:
		var hw: float = 46 - (hy + 62) / 62.0 * 8 - 1.5
		ci.draw_line(Vector2(-hw, hy), Vector2(hw, hy), P.HOOP, 5, true)
	stroke(ci, body, P.INK, 3.5)
	var blink := fmod(t * 0.31 + seed, 1.0) < 0.035
	_eyes(ci, -32, 15, blink, Vector2(0, 2.5) if kind == "filter" else Vector2(1, 1.5))
	_blush(ci, -21, 28)
	match kind:
		"invert":
			fill(ci, ellipse(Vector2(0, -19), 4.5, 5.5, 0, 16), P.INK)
		"filter":
			# Fussy: heavy lids and a pursed mouth, as if checking every grain.
			if not blink:
				for ex in [-15, 15]:
					var lid := arc(Vector2(ex, -33), 7.2, PI, TAU, 10)
					fill(ci, lid, P.WOOD_LT)
					line(ci, Vector2(ex - 7.5, -33), Vector2(ex + 7.5, -33), P.INK, 2.2)
			stroke(ci, PackedVector2Array([Vector2(-6, -21), Vector2(-2, -22.5), Vector2(2, -21), Vector2(6, -22.5)]), P.INK, 2.4, false)
		_:
			stroke(ci, arc(Vector2(0, -23), 8, 0.15 * PI, 0.85 * PI, 10), P.INK, 2.5, false)
	var surface := ellipse(Vector2(0, -62), 45, 9.5)
	fill(ci, surface, P.EMPTY_PAINT if shown < 0 else P.SIG[shown])
	stroke(ci, surface, P.INK, 3.5)
	if kind == "filter":
		_sieve(ci, age)
	if shown >= 0:
		fill(ci, ellipse(Vector2(-16, -64), 12, 2.5, 0, 16), P.SHINE_SOFT)
		if kind == "mix":
			var a := t * (1.5 + 5 * k)
			var swirl := PackedVector2Array()
			for i in 9:
				var aa := a + i * 0.22
				swirl.append(Vector2(cos(aa) * 28, -62 + sin(aa) * 5.5))
			ci.draw_polyline(swirl, P.SWIRL if not P.is_dark(shown) else P.SWIRL_DARK, 2.5, true)
		if shown == 0:
			dashed(ci, closed(ellipse(Vector2(0, -62), 38, 6, 0, 30)), P.INK_SOFT, 1.5, 5, 4)
		_surface_pips(ci, Vector2(0, -62), shown)
	reset_xf(ci)
	if kind == "mix":
		var a := t * (1.2 + 5 * k)
		var b := c + Vector2(cos(a) * 26, -30 + sin(a) * 5) * s
		var tip := b + Vector2(10, -42) * s
		line(ci, b, tip, P.INK, 8 * s)
		line(ci, b, tip, P.WOOD, 4 * s)


## Filter's sieve, set in the tub's rim (tub coordinates). When the tub fires
## the sieve shakes and a few grains rattle in it: the paint it held back,
## drawn in neutrals because only paint may wear the signal colors.
static func _sieve(ci: CanvasItem, age: float) -> void:
	var shake := 0.0
	if age < 1.0:
		shake = sin(age * 38.0) * 6.0 * exp(-age * 4.0)
	var o := Vector2(0, -62)
	var mesh := Color(P.INK, 0.3)
	for x in range(-36, 37, 9):
		var h := 9.5 * sqrt(1.0 - pow(x / 45.0, 2))
		ci.draw_line(o + Vector2(x, -h), o + Vector2(x, h), mesh, 1.3, true)
	for dy in [-5.5, -2.0, 2.0, 5.5]:
		var w := 45.0 * sqrt(1.0 - pow(dy / 9.5, 2))
		ci.draw_line(o + Vector2(-w, dy), o + Vector2(w, dy), mesh, 1.3, true)
	# The sieve's own hoop and two ear handles, riding the shake.
	var rim := o + Vector2(shake, -1)
	stroke(ci, ellipse(rim, 49, 11.5), P.INK, 7)
	stroke(ci, ellipse(rim, 49, 11.5), P.HOOP, 3.5)
	for side in [-1, 1]:
		var ear := rim + Vector2(side * 53, -1)
		shape(ci, ellipse(ear, 6, 4, 0, 14), P.HOOP, P.INK, 2.2)
	if age < 0.8:
		var fade := 1.0 - age / 0.8
		for i in 3:
			var gx: float = [-18.0, 4.0, 21.0][i] + shake * 1.4
			var gy := -absf(sin(age * 24.0 + i * 1.7)) * 7.0 * fade
			var g := o + Vector2(gx, gy - 10)  # along the back rim, clear of the glyph dots
			shape(ci, ellipse(g, 3.2, 2.4, 0.4 * i, 10), Color(P.HOOP, fade), Color(P.INK, fade), 1.4)


## Sleepy clay pot of paint (red unless told otherwise). Burps a drop when it
## fires. Pots of other paints wear a swatch tag with the paint's dots.
static func pot(ci: CanvasItem, c: Vector2, s: float, age: float, t: float, seed := 0.0, paint := 1) -> void:
	var k := exp(-age * 6.0)
	fill(ci, ellipse(c + Vector2(0, 36) * s, 44 * s, 7 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32) * s, Vector2(s * (1 + 0.08 * k), s * (1 - 0.1 * k)))
	shape(ci, _body("pot"), P.CLAY, P.INK, 3.5)
	stroke(ci, _body("pot_belt"), P.CLAY_DK, 4, false)
	var rim := ellipse(Vector2(0, -62), 30, 7.5)
	shape(ci, rim, P.CLAY_DK, P.INK, 3)
	fill(ci, ellipse(Vector2(0, -61.5), 23, 4.5, 0, 24), P.WHITE_STITCH if paint == 0 else P.SIG[paint])
	fill(ci, ellipse(Vector2(-9, -63), 7, 1.5, 0, 12), P.SHINE_SOFT)
	# Every pot wears a swatch tag with its paint's glyph dots, the red pot too.
	line(ci, Vector2(-27, -52), Vector2(-37, -44), P.INK, 2)
	swatch(ci, Vector2(-40, -38), 9, paint)
	# Sleepy face: closed eyes, open mouth when it burps.
	for ex in [-13, 13]:
		stroke(ci, arc(Vector2(ex, -34), 6, 0.15 * PI, 0.85 * PI, 8), P.INK, 2.5, false)
	_blush(ci, -24, 24)
	if age < 0.45:
		shape(ci, ellipse(Vector2(0, -21), 5, 6 * (1 - age), 0, 16), P.INK, P.INK, 1)
	else:
		stroke(ci, arc(Vector2(0, -24), 4, 0.2 * PI, 0.8 * PI, 6), P.INK, 2.2, false)
	reset_xf(ci)
	if age > 2.5:
		var u := fmod(t * 0.5 + seed, 1.0)
		var zc := c + Vector2(24 + u * 10, -44 - u * 18) * s
		var zs := (5 + u * 3) * s
		var col := Color(P.INK, 0.7 * (1 - u))
		ci.draw_polyline(PackedVector2Array([zc + Vector2(-zs, -zs), zc + Vector2(zs, -zs), zc + Vector2(-zs, zs), zc + Vector2(zs, zs)]), col, 2 * s + 0.5, true)


## A dashed pot outline: a pot not earned yet.
static func pot_outline(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in _body("pot"):
		pts.append(c + (p + Vector2(0, 32)) * s)
	dashed(ci, closed(pts), col, 2, 7, 5)
	dashed(ci, closed(ellipse(c + Vector2(0, -30) * s, 30 * s, 7.5 * s, 0, 24)), col, 2, 7, 5)


## A critter's body outline in its own coordinates (the rim sits at y = -62),
## worked out once. Shared, not a copy: don't change it.
static func _body(part: String) -> PackedVector2Array:
	if _bodies.has(part):
		return _bodies[part]
	var body := PackedVector2Array()
	match part:
		"tub":
			body = PackedVector2Array([Vector2(-46, -62), Vector2(46, -62), Vector2(38, 0)])
			body.append_array(quad(Vector2(38, 0), Vector2(0, 6), Vector2(-38, 0), 10))
		"bowl":  # the Mixing Tub: wide and round
			body = PackedVector2Array([Vector2(-50, -56)])
			body.append_array(cubic(Vector2(-50, -56), Vector2(-60, -22), Vector2(-40, 6), Vector2(0, 6), 14))
			body.append_array(cubic(Vector2(0, 6), Vector2(40, 6), Vector2(60, -22), Vector2(50, -56), 14))
		"pot":
			body = _jar(26, 27, 31, 42)
		"pot_belt":
			body = quad(Vector2(-39, -20), Vector2(0, -10), Vector2(39, -20), 12)
		"catch":
			body = _jar(32, 33, 37, 44)
		"catch_glaze":
			body = quad(Vector2(-41, -14), Vector2(0, -4), Vector2(41, -14), 12)
	_bodies[part] = body
	return body


## A round jar: a neck from the rim (half width `neck`) flaring out to the
## shoulder, then a belly of half width `belly`.
static func _jar(neck: float, flare: float, shoulder: float, belly: float) -> PackedVector2Array:
	var body := PackedVector2Array([Vector2(-neck, -62)])
	body.append_array(quad(Vector2(-neck, -62), Vector2(-flare, -54), Vector2(-shoulder, -48.3), 5))
	for i in range(1, 29):
		var a := lerpf(3.88, -0.74, i / 28.0)
		body.append(Vector2(belly * cos(a), -26 + 28 * sin(a)))
	body.append_array(quad(Vector2(shoulder, -48.3), Vector2(flare, -54), Vector2(neck, -62), 5))
	return body


## Catch pot: a pale glazed jar, wide awake, that gulps every drop it is given.
## Its surface shows the last color it caught, and a tag underneath the last
## few, newest first (nearest the tube they came in by).
static func catch_pot(ci: CanvasItem, c: Vector2, s: float, caught: Array, age: float, t: float, seed := 0.0) -> void:
	var k := exp(-age * 6.0)
	fill(ci, ellipse(c + Vector2(0, 36) * s, 44 * s, 7 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32) * s, Vector2(s * (1 - 0.06 * k), s * (1 + 0.08 * k)))
	shape(ci, _body("catch"), P.TAG, P.INK, 3.5)
	stroke(ci, _body("catch_glaze"), P.HOOP, 4, false)
	var rim := ellipse(Vector2(0, -62), 36, 8)
	shape(ci, rim, P.WOOD_LT, P.INK, 3)
	var last: int = caught[0] if caught.size() > 0 else -1
	var surface := ellipse(Vector2(0, -61.5), 29, 5, 0, 24)
	fill(ci, surface, P.EMPTY_PAINT if last < 0 else P.SIG[last])
	if last == 0:
		dashed(ci, closed(ellipse(Vector2(0, -61.5), 24, 3.5, 0, 24)), P.INK_SOFT, 1.2, 4, 3)
	elif last > 0:
		_surface_pips(ci, Vector2(0, -61.5), last)
	# Wide awake, looking back up the tube; gulps when a drop lands.
	var blink := fmod(t * 0.27 + seed, 1.0) < 0.035
	_eyes(ci, -36, 14, blink, Vector2(-1.8, -0.5))
	_blush(ci, -25, 27)
	if age < 0.45:
		shape(ci, ellipse(Vector2(0, -21), 5.5, 6.5 * (1 - age), 0, 16), P.INK, P.INK, 1)
	else:
		stroke(ci, arc(Vector2(0, -25), 5, 0.2 * PI, 0.8 * PI, 6), P.INK, 2.2, false)
	reset_xf(ci)
	var n := mini(caught.size(), 4)
	if n > 0:
		var tag := Rect2(c + Vector2(-8 - n * 8, 25), Vector2(16 + n * 16, 18))
		shape(ci, round_rect(tag, 6), P.TAG, Color(P.INK, 0.6), 1.5)
		for i in n:
			swatch(ci, Vector2(tag.position.x + 16 + i * 16, tag.get_center().y), 5.5, caught[i])


## Hamster in a red/yellow/blue wheel. The wheel clicks one notch per drop.
static func hamster(ci: CanvasItem, c: Vector2, s: float, liq: int, age: float, turns: int, t: float, seed := 0.0) -> void:
	var u := clampf(age / 0.6, 0, 1)
	var eased := 1.0 - pow(1.0 - u, 3)
	var notch: float = float(turns) if age >= 0.6 or turns == 0 else turns - 1 + eased
	var angle := notch * TAU / 3.0
	fill(ci, ellipse(c + Vector2(0, 36) * s, 42 * s, 7 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32) * s, Vector2(s, s))
	var hub := Vector2(0, -34)
	# Stand
	for leg in [Vector2(-26, 0), Vector2(26, 0)]:
		line(ci, leg, hub, P.INK, 9)
		line(ci, leg, hub, P.WOOD, 5)
	line(ci, Vector2(-34, 0), Vector2(34, 0), P.INK, 9)
	line(ci, Vector2(-34, 0), Vector2(34, 0), P.WOOD_DK, 5)
	# Wheel
	disc(ci, hub, 33, P.GLASS)
	for i in 3:
		var a0 := angle - PI / 2 - PI / 3 + i * TAU / 3
		ci.draw_arc(hub, 29.5, a0 + 0.04, a0 + TAU / 3 - 0.04, 16, P.SIG[[1, 2, 4][i]], 7, true)
	ring(ci, hub, 33, P.INK, 3)
	ring(ci, hub, 26, P.INK, 2)
	for i in 3:
		var a := angle - PI / 2 + PI / 3 + i * TAU / 3
		ci.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 26, P.HOOP, 2, true)
	# The hamster, running at the bottom of the wheel: a bigger one with
	# ears, its four legs in a real run cycle while the wheel turns.
	var run := age < 1.0
	var ph := t * 26.0
	var bob := absf(sin(ph)) * -1.8 if run else sin(t * 3 + seed) * 0.5
	var hb := Vector2(-1, -17 + bob)
	for leg in 4:
		var front := leg >= 2
		var base := hb + Vector2((7.0 if front else -7.0) + (leg % 2) * 3.0, 7)
		var swing: float = sin(ph + (0.0 if leg % 2 == 0 else PI) + (PI / 2 if front else 0.0)) * 5.0 if run else 0.0
		line(ci, base, base + Vector2(swing, 5 - absf(swing) * 0.3), P.INK, 2.6)
	shape(ci, ellipse(hb, 15.5, 10, 0, 24), P.FUR, P.INK, 2.2)
	fill(ci, ellipse(hb + Vector2(-3, 4), 9, 4, 0, 16), P.SHINE_MID)
	shape(ci, ellipse(hb + Vector2(-15, -1), 3, 2.5, 0, 10), P.FUR_DK, P.INK, 1.4)  # a stub of a tail
	var head := hb + Vector2(13, -4)
	for ear in [Vector2(-4, -7.5), Vector2(1.5, -8.5)]:
		shape(ci, ellipse(head + ear, 3.4, 3.8, 0, 12), P.FUR_DK, P.INK, 1.6)
		fill(ci, ellipse(head + ear + Vector2(0, 0.6), 1.6, 2, 0, 10), P.BLUSH)
	shape(ci, ellipse(head, 8.5, 7.5, 0, 20), P.FUR, P.INK, 2.2)
	disc(ci, head + Vector2(3, -1.5), 1.8, P.INK)
	fill(ci, ellipse(head + Vector2(3.5, 2.8), 2.8, 1.6, 0, 10), P.BLUSH)
	disc(ci, head + Vector2(8.2, 0.6), 1.4, P.INK)
	# Hub cap shows the paint it just turned
	if liq >= 0:
		drop(ci, hub + Vector2(0, 2), 7, liq)
	else:
		shape(ci, ellipse(hub, 5, 5, 0, 16), P.WOOD, P.INK, 2)
	reset_xf(ci)


## Split: plumbing, on purpose not a critter (it's free): a glass and brass
## fitting matching the tubes, that copies a drop into both of its tubes.
static func split(ci: CanvasItem, c: Vector2, ins: Array, outs: Array, liq: int, age: float) -> void:
	for p in ins + outs:
		polyline_round(ci, PackedVector2Array([c, p]), P.INK, 12)
	for p in ins + outs:
		polyline_round(ci, PackedVector2Array([c, p]), P.GLASS, 7)
		_glass_edges(ci, PackedVector2Array([c, p]))
		var d: Vector2 = (p - c).normalized()  # a brass ferrule where each tube meets the fitting
		line(ci, c + d * 13 + Vector2(-d.y, d.x) * 6.5, c + d * 13 - Vector2(-d.y, d.x) * 6.5, P.BRASS_DK, 4)
	var k := exp(-age * 6.0)
	var r := 12.0 * (1 + 0.12 * k)
	shape(ci, ellipse(c, r, r, 0, 24), P.BRASS, P.INK, 3)
	ci.draw_arc(c, r - 3, PI * 1.05, PI * 1.55, 8, P.TUBE_GLINT, 1.6, true)
	for i in 6:
		var a := i * TAU / 6
		disc(ci, c + Vector2(cos(a), sin(a)) * (r - 3), 1.3, P.BRASS_DK)
	if liq >= 0 and age < 1:
		disc(ci, c, 5.5, P.SIG[liq])
		ring(ci, c, 5.5, P.INK, 1.5)
	else:
		disc(ci, c, 5, P.GLASS)
		ring(ci, c, 5, P.INK, 1.5)


## An invention: a sticker with the invention's name.
## A small sticker mark beside an invention level's machine phrase: a tilted
## white sticker with the gear-and-drop badge, no name (the phrase is the
## name).
static func sticker_mark(ci: CanvasItem, c: Vector2) -> void:
	fill(ci, round_rect(Rect2(c + Vector2(-11, -7), Vector2(26, 18)), 5), P.SHADOW)
	set_xf(ci, c, Vector2.ONE, -0.12)
	shape(ci, round_rect(Rect2(-13, -9, 26, 18), 5), P.STICKER, P.INK, 1.8)
	fill(ci, round_rect(Rect2(-10, -6, 20, 12), 3), P.TAG)
	for i in 6:
		var a := i * TAU / 6
		disc(ci, Vector2(cos(a), sin(a)) * 4.2, 1.5, P.HOOP)
	disc(ci, Vector2.ZERO, 3.2, P.HOOP)
	disc(ci, Vector2.ZERO, 1.2, P.TAG)
	reset_xf(ci)


static func sticker(ci: CanvasItem, c: Vector2, s: float, name: String, age: float, t: float, seed := 0.0) -> void:
	var k := exp(-age * 5.0)
	var rot := -0.05 + sin(seed * 7) * 0.02 + sin(t * 22) * 0.05 * k
	var font := P.display(600)
	# A long name goes on two lines, so the sticker stays about a cell wide.
	var lines := [name]
	var size := 17
	if font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > 96 and name.contains(" "):
		var best := name.length()
		for i in name.length():
			if name[i] == " " and absi(i * 2 - name.length()) < absi(best * 2 - name.length()):
				best = i
		lines = [name.substr(0, best), name.substr(best + 1)]
		size = 15
	var w := 84.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 30)
	fill(ci, round_rect(Rect2(c + Vector2(-w / 2 + 3, -26 + 5) * s, Vector2(w, 52) * s), 12 * s), P.SHADOW)
	set_xf(ci, c, Vector2(s * (1 + 0.04 * k), s * (1 - 0.04 * k)), rot)
	var outer := round_rect(Rect2(-w / 2, -26, w, 52), 12)
	shape(ci, outer, P.STICKER, P.INK, 2.5)
	var inner := round_rect(Rect2(-w / 2 + 5, -21, w - 10, 42), 8)
	fill(ci, inner, P.TAG)
	stroke(ci, inner, P.WARP, 1.5)
	# a little gear-and-drop badge
	var badge := Vector2(-w / 2 + 16, -12)
	for i in 6:
		var a := i * TAU / 6 + t * 0.5
		disc(ci, badge + Vector2(cos(a), sin(a)) * 6, 2.2, P.HOOP)
	disc(ci, badge, 5, P.HOOP)
	disc(ci, badge, 2, P.TAG)
	for i in lines.size():
		text(ci, font, Vector2(4, 1 + (i - (lines.size() - 1) / 2.0) * 16), lines[i], size, P.INK)
	reset_xf(ci)


# ---------------------------------------------------------------------------
# Level furniture
# ---------------------------------------------------------------------------

## A pattern card is a picture, the loom cloth's counterpart (DESIGN.md 4,
## "The pattern card's look", Path B): the same grid in the same order, read
## left to right and row by row, as wide as its two cells allow. The cell
## shrinks only for a picture too big to fit (the lost Harbour).
const CARD_W := 156.0
const CARD_CELL := 16.0


## A card picture's cell size.
static func card_cell(cols: int, rows: int) -> float:
	return minf(CARD_CELL, minf((CARD_W - 28.0) / cols, 104.0 / rows))


## A card's body, around its centre, for a picture cols wide and rows tall.
static func card_rect(cols: int, rows: int) -> Rect2:
	var h := rows * card_cell(cols, rows) + 24.0
	return Rect2(-CARD_W / 2, -h / 2, CARD_W, h)


## Where a card's picture starts: its top-left corner, for a card centred on c.
static func _card_origin(c: Vector2, cols: int, rows: int) -> Vector2:
	var cs := card_cell(cols, rows)
	var r := card_rect(cols, rows)
	return c + Vector2(-cols * cs / 2, r.position.y + 14)


## A punched pattern card with every cell veiled, a sunken slot like the
## loom's unwoven ones (card_paints uncovers them): it never changes, so it
## can be drawn once.
static func card_body(ci: CanvasItem, c: Vector2, name: String, cols: int, rows: int) -> void:
	var r := card_rect(cols, rows)
	r.position += c
	fill(ci, round_rect(Rect2(r.position + Vector2(3, 4), r.size), 8), P.SHADOW)
	shape(ci, round_rect(r, 8), P.TAG, P.INK, 2)
	var cs := card_cell(cols, rows)
	var o := _card_origin(c, cols, rows)
	for i in cols * rows:
		var cell := Rect2(o + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs, cs))
		fill(ci, round_rect(cell.grow(-cs * 0.1), cs * 0.2, 2), Color(P.HOOP, 0.28))
	# name tab
	var tab := Vector2(r.position.x + 16, r.position.y + 1)  # on the top edge, clear of the picture
	shape(ci, ellipse(tab, 9, 9, 0, 20), P.WOOD_LT, P.INK, 2)
	text(ci, P.display(600), tab + Vector2(0, 0.5), name, 13, P.INK)


## A card's drops on its picture: the ones read already (`cursor` of them),
## dimmed under a paper tint like the loom's woven stitches stay put, and the
## `shows` coming up, uncovered, with their glyphs; the rest stay veiled. A
## small shuttle stands before the next drop, never on it, and slides on as
## the card releases one (`age` 0 to 1). After a wrong stitch the card stays
## as it was, the drop that wove it (`ringed`) ringed in ink and no shuttle.
static func card_paints(ci: CanvasItem, c: Vector2, cols: int, rows: int, colors: PackedByteArray, cursor: int, shows: int, age := 1.0, ringed := -1) -> void:
	var cs := card_cell(cols, rows)
	var o := _card_origin(c, cols, rows)
	var radius := cs * 0.5 - 1.0
	# The trail is a plain muted disc while the card runs (a redraw each tick,
	# and up to a picture's worth of them); glyphs come back once it stops.
	for i in mini(cursor + shows, colors.size()):
		var p := o + Vector2((i % cols + 0.5) * cs, (i / cols + 0.5) * cs)
		if i < cursor and ringed < 0:
			disc(ci, p, radius * 0.8, Color(P.SIG[colors[i]], 0.45))
			continue
		swatch(ci, p, radius, colors[i])
		if i < cursor:
			disc(ci, p, radius + 0.5, Color(P.TAG, 0.55))
		if i == ringed:
			ring(ci, p, radius + 3.0, P.INK, 2.0)
	if ringed >= 0 or cursor >= colors.size():
		return
	var to := _card_stop(o, cols, cs, cursor)
	var from := to
	if age < 1.0 and cursor > 0:
		from = _card_stop(o, cols, cs, cursor - 1)
		if cursor % cols == 0:  # a new row: in from the card's edge
			from = Vector2(o.x - cs, to.y)
	var at := from.lerp(to, 1.0 - pow(1.0 - clampf(age, 0, 1), 3))
	shuttle(ci, at, cs * 0.5, 6.0, 3.0)


## Where the shuttle stands before cell i of a card's picture: just left of it.
static func _card_stop(o: Vector2, cols: int, cs: float, i: int) -> Vector2:
	return Vector2(o.x + (i % cols) * cs - 6.0, o.y + (i / cols + 0.5) * cs)


## The loom: cloth with warp threads, wooden frame, woven stitches. It holds
## still between stitches; the shuttle and a wrong stitch's mark move on it
## (loom_shuttle).
static func loom(ci: CanvasItem, cloth: Rect2, cols: int, cs: float, woven: PackedByteArray, target: PackedByteArray, shown: int, ghost: bool, wrong: int) -> void:
	fill(ci, PackedVector2Array([cloth.position, Vector2(cloth.end.x, cloth.position.y), cloth.end, Vector2(cloth.position.x, cloth.end.y)]), P.CLOTH)
	for col in cols:
		var x := cloth.position.x + (col + 0.5) * cs
		ci.draw_line(Vector2(x, cloth.position.y), Vector2(x, cloth.end.y), P.WARP, 1.5, true)
	# weft threads, one per row, crossing the warp
	for row in ceili(float(target.size()) / cols):
		var y := cloth.position.y + (row + 0.5) * cs
		ci.draw_line(Vector2(cloth.position.x, y), Vector2(cloth.end.x, y), P.WARP, 1.5, true)
	# Unwoven cells are sunken slots, darker than the cloth, so an empty slot
	# never looks like a woven white stitch (bright, full size). The ghost of
	# the target shows as a small faint chip inside; white as a pale chip.
	for i in range(shown, target.size()):
		var cell := Rect2(cloth.position + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs, cs))
		var slot := round_rect(cell.grow(-cs * 0.1), cs * 0.2, 2)
		fill(ci, slot, Color(P.WARP, 0.55))
		ci.draw_line(cell.position + Vector2(cs * 0.22, cs * 0.14), cell.position + Vector2(cs * 0.78, cs * 0.14), Color(P.INK, 0.12), maxf(1, cs * 0.06), true)
		if ghost:
			var chip := round_rect(cell.grow(-cs * 0.3), cs * 0.12, 2)
			if target[i] == 0:
				fill(ci, chip, Color(P.WHITE_STITCH, 0.85))
				stroke(ci, chip, P.CHIP_EDGE, 1)
			else:
				fill(ci, chip, Color(P.SIG[target[i]], 0.35))
	# The shuttle's weft trails back to the cloth's edge, under the stitches it
	# has laid; loom_shuttle draws the rest of it, past them.
	if _threading(woven, target, shown, wrong) and shown % cols != 0:
		var y := cloth.position.y + (shown / cols + 0.5) * cs
		_weft(ci, Vector2(cloth.position.x, y), Vector2(_laid_edge(cloth, cols, cs, shown), y), cs)
	for i in mini(shown, woven.size()):
		var cell := Rect2(cloth.position + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs, cs))
		var c: int = woven[i]
		var sq := round_rect(cell.grow(-1), cs * 0.25, 3)
		fill(ci, sq, P.WHITE_STITCH if c == 0 else P.SIG[c])
		stroke(ci, sq, P.CHIP_EDGE if c == 0 else P.STITCH_EDGE, 1)
		ci.draw_line(cell.position + Vector2(cs * 0.25, cs * 0.3), cell.position + Vector2(cs * 0.5, cs * 0.25), P.SHINE_SOFT, maxf(1, cs * 0.075), true)
	var post_h := cloth.size.y + 32
	for px in [cloth.position.x - 26, cloth.end.x + 12]:
		shape(ci, round_rect(Rect2(px, cloth.position.y - 20, 14, post_h), 5), P.WOOD, P.INK, 2.5)
	for py in [cloth.position.y - 22, cloth.end.y + 4]:
		shape(ci, round_rect(Rect2(cloth.position.x - 34, py, cloth.size.x + 68, 13), 6), P.WOOD_DK, P.INK, 2.5)


## What moves on the loom (drawn over it): a wrong stitch's pulsing mark, or
## else the shuttle. The shuttle threads along the row it weaves, right across
## the slots, and slides on to the next one after a stitch lands (glide 0 → 1),
## coming in from the left edge for a new row, its weft trailing behind it.
static func loom_shuttle(ci: CanvasItem, cloth: Rect2, cols: int, cs: float, woven: PackedByteArray, target: PackedByteArray, shown: int, wrong: int, t: float, glide := 1.0) -> void:
	if wrong >= 0 and wrong < woven.size():
		var wc := cloth.position + Vector2((wrong % cols + 0.5) * cs, (wrong / cols + 0.5) * cs)
		var pulse := 1 + 0.12 * sin(t * 8)
		ring(ci, wc, cs * 0.8 * pulse, P.INK, 3)
		var d := cs * 0.32
		line(ci, wc + Vector2(-d, -d), wc + Vector2(d, d), P.INK, 3)
		line(ci, wc + Vector2(-d, d), wc + Vector2(d, -d), P.INK, 3)
		return
	if not _threading(woven, target, shown, wrong):
		return
	var to := cloth.position + Vector2((shown % cols + 0.5) * cs, (shown / cols + 0.5) * cs)
	var from := to
	if glide < 1.0 and shown > 0:
		from = to - Vector2(cs, 0) if shown % cols != 0 else Vector2(cloth.position.x - cs * 0.6, to.y)
	var at := from.lerp(to, 1.0 - pow(1.0 - clampf(glide, 0, 1), 3))
	if shown % cols == 0:  # a new row: the weft runs from the cloth's edge
		_weft(ci, Vector2(cloth.position.x, at.y), at, cs)
	else:  # past the stitches laid in this row (loom draws it under them)
		var edge := _laid_edge(cloth, cols, cs, shown)
		if at.x > edge:
			_weft(ci, Vector2(edge, at.y), at, cs)
	shuttle(ci, at, cs)


static func _threading(woven: PackedByteArray, target: PackedByteArray, shown: int, wrong: int) -> bool:
	return not (wrong >= 0 and wrong < woven.size()) and shown < target.size()


## Where the stitches laid in the shuttle's row end (the right edge of the last).
static func _laid_edge(cloth: Rect2, cols: int, cs: float, shown: int) -> float:
	return cloth.position.x + (shown % cols) * cs - 1


static func _weft(ci: CanvasItem, a: Vector2, b: Vector2, cs: float) -> void:
	ci.draw_line(a, b, Color(P.HOOP, 0.8), maxf(1.5, cs * 0.08), true)


## A loom shuttle: a pointed wooden boat with a bobbin of thread in its hollow.
## It is at least min_hl long from the middle to a tip and min_hh from the
## middle to the hollow's edge (a card's is smaller than the loom's).
static func shuttle(ci: CanvasItem, c: Vector2, cs: float, min_hl := 11.0, min_hh := 4.0) -> void:
	var hl := maxf(cs * 0.62, min_hl)
	var hh := maxf(cs * 0.19, min_hh)
	var body := quad(c + Vector2(-hl, 0), c + Vector2(0, -hh * 2), c + Vector2(hl, 0), 12)
	body.append_array(quad(c + Vector2(hl, 0), c + Vector2(0, hh * 2), c + Vector2(-hl, 0), 12))
	fill(ci, ellipse(c + Vector2(0, hh * 0.9), hl * 0.9, hh * 0.6, 0, 20), P.SHADOW)
	shape(ci, body, P.WOOD, P.INK, 1.8)
	var hollow := Rect2(c - Vector2(hl * 0.42, hh * 0.5), Vector2(hl * 0.84, hh))
	fill(ci, round_rect(hollow, hh * 0.5, 3), P.WOOD_DK)
	var bobbin := hollow.grow_individual(-hl * 0.08, -hh * 0.12, -hl * 0.08, -hh * 0.12)
	shape(ci, round_rect(bobbin, hh * 0.38, 3), P.TAG, Color(P.HOOP, 0.9), 1)
	for k in 3:
		var x := bobbin.position.x + bobbin.size.x * (0.3 + k * 0.2)
		ci.draw_line(Vector2(x, bobbin.position.y + 1), Vector2(x, bobbin.end.y - 1), Color(P.HOOP, 0.6), 1, true)


## A small copy of the target picture, pinned like a design sketch.
static func design(ci: CanvasItem, r: Rect2, cols: int, target: PackedByteArray) -> void:
	var cs := minf((r.size.x - 16) / cols, (r.size.y - 16) / (target.size() / cols))
	var rows := target.size() / cols
	var size := Vector2(cols, rows) * cs
	var box := Rect2(r.get_center() - size / 2 - Vector2(8, 8), size + Vector2(16, 16))
	fill(ci, round_rect(Rect2(box.position + Vector2(3, 4), box.size), 6), P.SHADOW)
	shape(ci, round_rect(box, 6), P.TAG, P.INK, 2)
	var origin := box.position + Vector2(8, 8)
	for i in target.size():
		var cell := Rect2(origin + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs, cs))
		ci.draw_rect(cell, P.WHITE_STITCH if target[i] == 0 else P.SIG[target[i]])
	ci.draw_rect(Rect2(origin, size), Color(P.INK, 0.25), false, 1)
	# pin
	var pin := Vector2(box.get_center().x, box.position.y + 2)
	shape(ci, ellipse(pin, 6, 6, 0, 16), P.HOOP, P.INK, 2)
	disc(ci, pin + Vector2(-1.5, -1.5), 1.6, P.PIN_GLINT)


## A woven cloth hung from a wooden rod, as big as fits in r (centred).
## Returns the cloth's own rectangle.
static func cloth(ci: CanvasItem, r: Rect2, cols: int, target: PackedByteArray) -> Rect2:
	var rows := target.size() / cols
	var cs := minf(r.size.x / cols, (r.size.y - 10) / rows)
	if cs >= 4:
		cs = floorf(cs)
	var size := Vector2(cols, rows) * cs
	var o := (r.position + Vector2(0, 10) + (r.size - Vector2(0, 10) - size) / 2).floor()
	fill(ci, round_rect(Rect2(o + Vector2(3, 4), size), 3), P.SHADOW)
	ci.draw_rect(Rect2(o, size), P.CLOTH)
	_stitches(ci, o, cols, cs, target)
	ci.draw_rect(Rect2(o, size), Color(P.INK, 0.35), false, 1.5)
	shape(ci, round_rect(Rect2(o.x - 8, o.y - 9, size.x + 16, 7), 3.5), P.WOOD, P.INK, 1.8)
	return Rect2(o, size)


## Woven stitches from o, cs across, in rows of cols.
static func _stitches(ci: CanvasItem, o: Vector2, cols: int, cs: float, target: PackedByteArray) -> void:
	for i in target.size():
		var cell := Rect2(o + Vector2(i % cols, i / cols) * cs, Vector2(cs, cs))
		var c: int = target[i]
		if cs >= 6:
			fill(ci, round_rect(cell.grow(-0.5), cs * 0.25, 2), P.WHITE_STITCH if c == 0 else P.SIG[c])
		else:
			ci.draw_rect(cell, P.WHITE_STITCH if c == 0 else P.SIG[c])


## A chapter's quilt: its cloths sewn together, as big as fits in r. patches
## holds one entry per level in the chapter: [cols, target] once woven, []
## while not. stack_cols > 0 stacks them row on row, each a thread that many
## stitches wide (the paint box's nine threads); otherwise each cloth is sewn
## into an equal patch, aspect wide to 1 high (the chapter's pictures share a
## shape), across of them to a row (0: whatever grid makes them biggest).
## Unwoven places stay bare, stitched round.
static func quilt(ci: CanvasItem, r: Rect2, patches: Array, stack_cols := 0, across := 0, aspect := 1.0) -> void:
	var stacked := stack_cols > 0
	var n := patches.size()
	var grid := Vector2i(1, n)
	if not stacked and across > 0:  # the chapter pins its patches across
		grid = Vector2i(across, ceili(float(n) / across))
	elif not stacked:  # the most columns-by-rows that makes the biggest patches
		var best := 0.0
		for c in range(1, n + 1):
			var rows := ceili(float(n) / c)
			var b := minf(r.size.x / c, r.size.y / rows) - (c * rows - n) * 0.01
			if b > best:
				best = b
				grid = Vector2i(c, rows)
	var unit := Vector2(stack_cols, 1) if stacked else Vector2(aspect, 1)
	var block := minf((r.size.x - 24) / (grid.x * unit.x), (r.size.y - 24) / (grid.y * unit.y))
	var bsize := unit * block
	var size := Vector2(grid) * bsize
	var o := r.get_center() - size / 2
	var edge := Rect2(o - Vector2(10, 10), size + Vector2(20, 20))
	fill(ci, round_rect(Rect2(edge.position + Vector2(4, 5), edge.size), 8), P.SHADOW)
	shape(ci, round_rect(edge, 8), P.WARP, P.INK, 2)
	dashed(ci, closed(round_rect(edge.grow(-5), 5)), Color(P.HOOP, 0.9), 1.5, 5, 4)
	for k in patches.size():
		var b := Rect2(o + Vector2(k % grid.x, k / grid.x) * bsize, bsize)
		ci.draw_rect(b, P.PAPER_DK if patches[k].is_empty() else P.CLOTH)
		if not patches[k].is_empty():
			var cols: int = patches[k][0]
			var target: PackedByteArray = patches[k][1]
			var rows := target.size() / cols
			var cs := minf((b.size.x - (0 if stacked else 6)) / cols, (b.size.y - (0 if stacked else 6)) / rows)
			_stitches(ci, b.get_center() - Vector2(cols, rows) * cs / 2, cols, cs, target)
		dashed(ci, closed(round_rect(b.grow(-1.5), 2)), Color(P.HOOP, 0.8), 1.2, 4, 3)
	ci.draw_rect(Rect2(o, size), Color(P.INK, 0.45), false, 1.5)


# ---------------------------------------------------------------------------
# Stars and icons
# ---------------------------------------------------------------------------

static func star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		var rr := r if i % 2 == 0 else r * 0.48
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func star(ci: CanvasItem, c: Vector2, r: float, filled: bool) -> void:
	var pts := star_pts(c, r)
	if filled:
		shape(ci, pts, P.WOOD, P.INK, maxf(2, r * 0.12))
		fill(ci, ellipse(c + Vector2(-r * 0.2, -r * 0.25), r * 0.14, r * 0.26, -0.6, 12), P.SHINE_MID)
	else:
		shape(ci, pts, P.PAPER_DK, Color(P.INK, 0.45), maxf(1.5, r * 0.1))


## Simple line icons for buttons (no text needed).
static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	var w := 3.5 * s
	match kind:
		"play":
			shape(ci, PackedVector2Array([c + Vector2(-6, -9) * s, c + Vector2(10, 0) * s, c + Vector2(-6, 9) * s]), col, col, w * 0.6)
		"pause":
			for dx in [-5, 5]:
				line(ci, c + Vector2(dx, -8) * s, c + Vector2(dx, 8) * s, col, w * 1.3)
		"step":
			shape(ci, PackedVector2Array([c + Vector2(-9, -8) * s, c + Vector2(4, 0) * s, c + Vector2(-9, 8) * s]), col, col, w * 0.6)
			line(ci, c + Vector2(9, -8) * s, c + Vector2(9, 8) * s, col, w)
		"step_back":
			shape(ci, PackedVector2Array([c + Vector2(9, -8) * s, c + Vector2(-4, 0) * s, c + Vector2(9, 8) * s]), col, col, w * 0.6)
			line(ci, c + Vector2(-9, -8) * s, c + Vector2(-9, 8) * s, col, w)
		"reset":
			ci.draw_arc(c, 9 * s, -0.3 * PI, 1.2 * PI, 20, col, w, true)
			var tip := c + Vector2(cos(-0.3 * PI), sin(-0.3 * PI)) * 9 * s
			shape(ci, PackedVector2Array([tip + Vector2(-2, -6) * s, tip + Vector2(6, 1) * s, tip + Vector2(-4, 4) * s]), col, col, w * 0.5)
		"undo":
			ci.draw_arc(c + Vector2(1, 3) * s, 8 * s, -PI, 0.4 * PI, 18, col, w, true)
			var tip2 := c + Vector2(-7, 3) * s
			shape(ci, PackedVector2Array([tip2 + Vector2(-6, -2) * s, tip2 + Vector2(6, -2) * s, tip2 + Vector2(0, -9) * s]), col, col, w * 0.5)
		"back":
			line(ci, c + Vector2(9, 0) * s, c + Vector2(-8, 0) * s, col, w)
			polyline_round(ci, PackedVector2Array([c + Vector2(-1, -8) * s, c + Vector2(-9, 0) * s, c + Vector2(-1, 8) * s]), col, w)
		"next":
			line(ci, c + Vector2(-9, 0) * s, c + Vector2(8, 0) * s, col, w)
			polyline_round(ci, PackedVector2Array([c + Vector2(1, -8) * s, c + Vector2(9, 0) * s, c + Vector2(1, 8) * s]), col, w)
		"slow", "normal", "fast":
			var n: int = {"slow": 1, "normal": 2, "fast": 3}[kind]
			for i in n:
				var x := (i - (n - 1) / 2.0) * 7 - 2
				polyline_round(ci, PackedVector2Array([c + Vector2(x - 3, -7) * s, c + Vector2(x + 4, 0) * s, c + Vector2(x - 3, 7) * s]), col, w * 0.85)
		"trash", "delete":
			var lid := c + Vector2(0, -8) * s
			line(ci, lid + Vector2(-10, 0) * s, lid + Vector2(10, 0) * s, col, w)
			line(ci, lid + Vector2(-3, -3) * s, lid + Vector2(3, -3) * s, col, w)
			stroke(ci, PackedVector2Array([c + Vector2(-7, -4) * s, c + Vector2(7, -4) * s, c + Vector2(5.5, 11) * s, c + Vector2(-5.5, 11) * s]), col, w * 0.8)
			for dx in [-2.5, 2.5]:
				ci.draw_line(c + Vector2(dx, 0) * s, c + Vector2(dx, 7) * s, col, w * 0.5, true)
		"levels":
			for i in 9:
				disc(ci, c + Vector2((i % 3 - 1) * 7, (i / 3 - 1) * 7) * s, 2.6 * s, col)
		"book":
			stroke(ci, PackedVector2Array([c + Vector2(0, -6) * s, c + Vector2(-11, -9) * s, c + Vector2(-11, 8) * s, c + Vector2(0, 11) * s, c + Vector2(11, 8) * s, c + Vector2(11, -9) * s]), col, w * 0.8)
			ci.draw_line(c + Vector2(0, -6) * s, c + Vector2(0, 11) * s, col, w * 0.8, true)
		"options":
			# A wooden cog: eight teeth round a ring.
			for i in 8:
				var a := i * TAU / 8
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * 7 * s, c + d * 12 * s, col, w * 1.1, true)
			ring(ci, c, 8 * s, col, w * 0.9)
			ring(ci, c, 3 * s, col, w * 0.7)
		"lock":
			ci.draw_arc(c + Vector2(0, -3) * s, 6 * s, PI, TAU, 12, col, w * 0.9, true)
			ci.draw_line(c + Vector2(-6, -3) * s, c + Vector2(-6, 1) * s, col, w * 0.9, true)
			ci.draw_line(c + Vector2(6, -3) * s, c + Vector2(6, 1) * s, col, w * 0.9, true)
			shape(ci, round_rect(Rect2(c + Vector2(-9, 0) * s, Vector2(18, 12) * s), 3 * s), col, col, 1)
		"pieces":
			var tb := PackedVector2Array([c + Vector2(-9, -7) * s, c + Vector2(9, -7) * s, c + Vector2(7, 8) * s, c + Vector2(-7, 8) * s])
			stroke(ci, tb, col, w * 0.7)
			ci.draw_line(c + Vector2(-8, -1) * s, c + Vector2(8, -1) * s, col, w * 0.5, true)
		"ticks":
			ring(ci, c, 9 * s, col, w * 0.7)
			line(ci, c, c + Vector2(0, -6) * s, col, w * 0.6)
			line(ci, c, c + Vector2(4, 2) * s, col, w * 0.6)
		"check":
			polyline_round(ci, PackedVector2Array([c + Vector2(-8, 0) * s, c + Vector2(-2, 6) * s, c + Vector2(9, -7) * s]), col, w)
		"x":
			line(ci, c + Vector2(-7, -7) * s, c + Vector2(7, 7) * s, col, w)
			line(ci, c + Vector2(-7, 7) * s, c + Vector2(7, -7) * s, col, w)
		"paints":
			# Three overlapping rings where the glyph dots sit: the paints mixing.
			for pip in PIP:
				ring(ci, c + Vector2(cos(pip[1]), sin(pip[1])) * 4.6 * s, 6.4 * s, col, w * 0.55)
		"zzz":
			for i in 2:
				var o := c + Vector2(-5 + i * 9, 3 - i * 8) * s
				var z := (4 - i) * s
				ci.draw_polyline(PackedVector2Array([o + Vector2(-z, -z), o + Vector2(z, -z), o + Vector2(-z, z), o + Vector2(z, z)]), col, w * 0.7, true)


## A pointing hand for wordless hints. The fingertip is at p.
static func hand(ci: CanvasItem, p: Vector2, down: bool, alpha: float) -> void:
	var fill_col := Color(P.TAG, alpha)
	var ink := Color(P.INK, alpha)
	if down:
		ring(ci, p, 14, Color(P.INK, 0.4 * alpha), 3)
	var o := p + (Vector2(2, 3) if down else Vector2(6, 8))
	fill(ci, round_rect(Rect2(o + Vector2(-6, 18), Vector2(30, 26)), 10), Color(P.SHADOW, P.SHADOW.a * alpha))
	var palm := round_rect(Rect2(o + Vector2(-8, 14), Vector2(28, 26)), 10)
	shape(ci, palm, fill_col, ink, 2.5)
	shape(ci, ellipse(o + Vector2(-9, 26), 5, 8, 0.5, 16), fill_col, ink, 2.5)
	var finger := round_rect(Rect2(o + Vector2(-5, -4), Vector2(10, 28)), 5)
	shape(ci, finger, fill_col, ink, 2.5)
	for k in 2:
		ci.draw_line(o + Vector2(5 + k * 6, 16), o + Vector2(5 + k * 6, 22), Color(ink, 0.6 * alpha), 2, true)


## Glyph dots lying flat on a paint surface (a squashed version of pips()).
static func _surface_pips(ci: CanvasItem, c: Vector2, color: int) -> void:
	var ink: Color = P.PIP_LIGHT if P.is_dark(color) else P.PIP_DARK
	for pip in PIP:
		var pc: Vector2 = c + Vector2(cos(pip[1]) * 13, sin(pip[1]) * 4.5)
		if color & pip[0]:
			fill(ci, ellipse(pc, 4, 2.4, 0, 12), ink)
		else:
			stroke(ci, ellipse(pc, 3.6, 2.1, 0, 12), Color(ink, 0.55), 1.3)
