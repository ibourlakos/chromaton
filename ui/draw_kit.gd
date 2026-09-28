## Critter Workshop drawing, ported from mockups/style-studies.html.
##
## Chunky toy shapes with thick ink outlines, drawn with CanvasItem calls.
## Every function takes the CanvasItem to draw on. Critters are drawn in
## their own local coordinates (as in the mockup) and placed with a
## transform, so `s` scales the whole critter.
extends RefCounted

const P = preload("res://ui/palette.gd")

const PIP := [[1, -PI / 2], [2, PI / 6], [4, 5 * PI / 6]]


# ---------------------------------------------------------------------------
# Geometry
# ---------------------------------------------------------------------------

static func ellipse(c: Vector2, rx: float, ry: float, rot := 0.0, n := 36) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / n
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts.append(c + Vector2(x * cr - y * sr, x * sr + y * cr))
	return pts


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
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func round_rect(r: Rect2, rad: float, n := 5) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) / 2)
	var pts := PackedVector2Array()
	var corners := [
		[r.position + Vector2(rad, rad), PI],
		[Vector2(r.end.x - rad, r.position.y + rad), 1.5 * PI],
		[r.end - Vector2(rad, rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), 0.5 * PI],
	]
	for corner in corners:
		for i in n + 1:
			var a: float = corner[1] + 0.5 * PI * i / n
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * rad)
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


static func polyline_round(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	ci.draw_polyline(pts, col, w, true)
	for p in pts:
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
		fill(ci, ellipse(c + Vector2(-0.45, -0.35) * r, r * 0.14, r * 0.26, -0.5, 12), Color(1, 1, 1, 0.55))
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

static func tube(ci: CanvasItem, pts: PackedVector2Array, selected := false) -> void:
	if selected:
		polyline_round(ci, pts, P.HOOP, 20)
	polyline_round(ci, pts, P.INK, 13)
	polyline_round(ci, pts, P.GLASS, 8)


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
	polyline_round(ci, pts, P.INK, 12 if spout else 13)
	polyline_round(ci, pts, P.WOOD_DK if spout else P.GLASS, 7 if spout else 8)


static func port_in(ci: CanvasItem, p: Vector2, lit := false) -> void:
	if lit:
		disc(ci, p, 13, Color(P.HOOP, 0.35))
	disc(ci, p, 7, P.GLASS)
	ring(ci, p, 7, P.INK, 2.5)


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
		shape(ci, ellipse(Vector2(ex, y - 1), 7, 8, 0, 20), Color.WHITE, P.INK, 2)
		disc(ci, Vector2(ex, y - 1) + look, 3.6, P.INK)


static func _blush(ci: CanvasItem, y: float, dx: float) -> void:
	for bx in [-dx, dx]:
		fill(ci, ellipse(Vector2(bx, y), 6, 3.5, 0, 16), P.BLUSH)


## Wooden vat with a face. kind: "mix" (spoon, stirs), "invert" (flips like
## a pancake) or "tub" (any other vat). liq is the paint it holds (-1 empty);
## age is ticks since it last fired.
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
	var body := PackedVector2Array([Vector2(-46, -62), Vector2(46, -62), Vector2(38, 0)])
	body.append_array(quad(Vector2(38, 0), Vector2(0, 6), Vector2(-38, 0), 10))
	fill(ci, body, P.WOOD)
	for stave in [-24, 0, 24]:
		ci.draw_line(Vector2(stave, -60), Vector2(stave * 0.84, -2), P.WOOD_DK, 1.5, true)
	for hy in [-50, -10]:
		var hw: float = 46 - (hy + 62) / 62.0 * 8 - 1.5
		ci.draw_line(Vector2(-hw, hy), Vector2(hw, hy), P.HOOP, 5, true)
	stroke(ci, body, P.INK, 3.5)
	var blink := fmod(t * 0.31 + seed, 1.0) < 0.035
	_eyes(ci, -32, 15, blink)
	_blush(ci, -21, 28)
	match kind:
		"invert":
			fill(ci, ellipse(Vector2(0, -19), 4.5, 5.5, 0, 16), P.INK)
		_:
			stroke(ci, arc(Vector2(0, -23), 8, 0.15 * PI, 0.85 * PI, 10), P.INK, 2.5, false)
	var surface := ellipse(Vector2(0, -62), 45, 9.5)
	fill(ci, surface, P.EMPTY_PAINT if shown < 0 else P.SIG[shown])
	stroke(ci, surface, P.INK, 3.5)
	if shown >= 0:
		fill(ci, ellipse(Vector2(-16, -64), 12, 2.5, 0, 16), Color(1, 1, 1, 0.35))
		if kind == "mix":
			var a := t * (1.5 + 5 * k)
			var swirl := PackedVector2Array()
			for i in 9:
				var aa := a + i * 0.22
				swirl.append(Vector2(cos(aa) * 28, -62 + sin(aa) * 5.5))
			ci.draw_polyline(swirl, Color(1, 1, 1, 0.45) if not P.is_dark(shown) else Color(1, 1, 1, 0.3), 2.5, true)
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


## Sleepy clay pot of red paint. Burps a drop when it fires.
static func pot(ci: CanvasItem, c: Vector2, s: float, age: float, t: float, seed := 0.0) -> void:
	var k := exp(-age * 6.0)
	fill(ci, ellipse(c + Vector2(0, 36) * s, 44 * s, 7 * s, 0, 24), P.SHADOW)
	set_xf(ci, c + Vector2(0, 32) * s, Vector2(s * (1 + 0.08 * k), s * (1 - 0.1 * k)))
	var body := PackedVector2Array([Vector2(-26, -62)])
	body.append_array(quad(Vector2(-26, -62), Vector2(-27, -54), Vector2(-31, -48.3), 5))
	for i in range(1, 29):
		var a := lerpf(3.88, -0.74, i / 28.0)
		body.append(Vector2(42 * cos(a), -26 + 28 * sin(a)))
	body.append_array(quad(Vector2(31, -48.3), Vector2(27, -54), Vector2(26, -62), 5))
	shape(ci, body, P.CLAY, P.INK, 3.5)
	stroke(ci, quad(Vector2(-39, -20), Vector2(0, -10), Vector2(39, -20), 12), P.CLAY_DK, 4, false)
	var rim := ellipse(Vector2(0, -62), 30, 7.5)
	shape(ci, rim, P.CLAY_DK, P.INK, 3)
	fill(ci, ellipse(Vector2(0, -61.5), 23, 4.5, 0, 24), P.SIG[1])
	fill(ci, ellipse(Vector2(-9, -63), 7, 1.5, 0, 12), Color(1, 1, 1, 0.35))
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
	# Hamster running at the bottom of the wheel
	var run := age < 1.0
	var bob := sin(t * 30) * 1.2 if run else sin(t * 3 + seed) * 0.5
	var hb := Vector2(0, -16 + bob)
	for leg in 2:
		var ph := t * 30 + leg * PI
		var dx: float = sin(ph) * 5 if run else (-4.0 + leg * 8)
		line(ci, hb + Vector2(-3 + leg * 7, 5), hb + Vector2(-3 + leg * 7 + dx, 9), P.INK, 2.5)
	shape(ci, ellipse(hb, 13, 8.5, 0, 24), P.FUR, P.INK, 2.2)
	fill(ci, ellipse(hb + Vector2(-2, 3), 8, 4, 0, 16), Color(1, 1, 1, 0.5))
	var head := hb + Vector2(10, -4)
	shape(ci, ellipse(head, 7, 6.5, 0, 20), P.FUR, P.INK, 2.2)
	shape(ci, ellipse(head + Vector2(-2, -6.5), 3, 3, 0, 12), P.FUR_DK, P.INK, 1.6)
	disc(ci, head + Vector2(2.5, -1), 1.6, P.INK)
	fill(ci, ellipse(head + Vector2(3, 2.5), 2.5, 1.5, 0, 10), P.BLUSH)
	disc(ci, head + Vector2(6.8, 0.8), 1.2, P.INK)
	# Hub cap shows the paint it just turned
	if liq >= 0:
		drop(ci, hub + Vector2(0, 2), 7, liq)
	else:
		shape(ci, ellipse(hub, 5, 5, 0, 16), P.WOOD, P.INK, 2)
	reset_xf(ci)


## Plumbing junction: copies a drop into both of its tubes.
static func split(ci: CanvasItem, c: Vector2, ins: Array, outs: Array, liq: int, age: float) -> void:
	for p in ins + outs:
		polyline_round(ci, PackedVector2Array([c, p]), P.INK, 13)
	for p in ins + outs:
		polyline_round(ci, PackedVector2Array([c, p]), P.GLASS, 8)
	var k := exp(-age * 6.0)
	var r := 12.0 * (1 + 0.12 * k)
	shape(ci, ellipse(c, r, r, 0, 24), P.HOOP, P.INK, 3)
	for i in 6:
		var a := i * TAU / 6
		disc(ci, c + Vector2(cos(a), sin(a)) * (r - 3), 1.3, P.INK)
	if liq >= 0 and age < 1:
		disc(ci, c, 5.5, P.SIG[liq])
		ring(ci, c, 5.5, P.INK, 1.5)
	else:
		disc(ci, c, 5, P.GLASS)
		ring(ci, c, 5, P.INK, 1.5)


## An invention: a sticker with the invention's name.
static func sticker(ci: CanvasItem, c: Vector2, s: float, name: String, age: float, t: float, seed := 0.0) -> void:
	var k := exp(-age * 5.0)
	var rot := -0.05 + sin(seed * 7) * 0.02 + sin(t * 22) * 0.05 * k
	var font := P.display(600)
	var w := maxf(84.0, font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 30)
	fill(ci, round_rect(Rect2(c + Vector2(-w / 2 + 3, -26 + 5) * s, Vector2(w, 52) * s), 12 * s), P.SHADOW)
	set_xf(ci, c, Vector2(s * (1 + 0.04 * k), s * (1 - 0.04 * k)), rot)
	var outer := round_rect(Rect2(-w / 2, -26, w, 52), 12)
	shape(ci, outer, Color.WHITE, P.INK, 2.5)
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
	text(ci, font, Vector2(4, 1), name, 17, P.INK)
	reset_xf(ci)


# ---------------------------------------------------------------------------
# Level furniture
# ---------------------------------------------------------------------------

## A punched pattern card showing its next colors.
static func card(ci: CanvasItem, c: Vector2, name: String, upcoming: Array, age: float) -> void:
	var r := Rect2(c + Vector2(-78, -26), Vector2(156, 52))
	fill(ci, round_rect(Rect2(r.position + Vector2(3, 4), r.size), 8), P.SHADOW)
	shape(ci, round_rect(r, 8), P.TAG, P.INK, 2)
	for i in 9:
		disc(ci, Vector2(r.position.x + 14 + i * 16, r.end.y - 7), 2, P.HOOP)
	# name tab
	var tab := Vector2(r.position.x + 13, r.position.y + 13)
	shape(ci, ellipse(tab, 9, 9, 0, 20), P.WOOD_LT, P.INK, 2)
	text(ci, P.display(600), tab + Vector2(0, 0.5), name, 13, P.INK)
	# next colors, the next one on the right by the card's port; they slide
	# right as the card releases
	var slide := -clampf(1.0 - age, 0, 1) * 18 if age < 1 else 0.0
	for i in mini(upcoming.size(), 6):
		var p := Vector2(r.end.x - 20 - i * 19 + slide, r.position.y + 21)
		swatch(ci, p, 7.5 if i > 0 else 8.5, upcoming[i])
	if upcoming.is_empty():
		stroke(ci, arc(Vector2(c.x + 10, r.position.y + 21), 6, 0, TAU, 16), P.WARP, 2)
	# the card's spout, towards the bench
	var spout := PackedVector2Array([Vector2(r.end.x - 2, c.y), Vector2(c.x + 86, c.y)])
	polyline_round(ci, spout, P.INK, 12)
	polyline_round(ci, spout, P.WOOD_DK, 7)


## The loom: cloth with warp threads, wooden frame, woven stitches, shuttle.
static func loom(ci: CanvasItem, cloth: Rect2, cols: int, cs: float, woven: PackedByteArray, target: PackedByteArray, shown: int, ghost: bool, wrong: int, t: float) -> void:
	fill(ci, PackedVector2Array([cloth.position, Vector2(cloth.end.x, cloth.position.y), cloth.end, Vector2(cloth.position.x, cloth.end.y)]), P.CLOTH)
	for col in cols:
		var x := cloth.position.x + (col + 0.5) * cs
		ci.draw_line(Vector2(x, cloth.position.y), Vector2(x, cloth.end.y), P.WARP, 1.5, true)
	if ghost:
		for i in target.size():
			if i < shown:
				continue
			var cell := Rect2(cloth.position + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs, cs))
			if target[i] != 0:
				fill(ci, round_rect(cell.grow(-cs * 0.3), cs * 0.15, 2), Color(P.SIG[target[i]], 0.28))
	for i in mini(shown, woven.size()):
		var cell := Rect2(cloth.position + Vector2((i % cols) * cs, (i / cols) * cs), Vector2(cs, cs))
		var c: int = woven[i]
		var sq := round_rect(cell.grow(-1), cs * 0.25, 3)
		fill(ci, sq, P.WHITE_STITCH if c == 0 else P.SIG[c])
		stroke(ci, sq, Color("#DDD3C1") if c == 0 else Color(0.16, 0.12, 0.1, 0.22), 1)
		ci.draw_line(cell.position + Vector2(cs * 0.25, cs * 0.3), cell.position + Vector2(cs * 0.5, cs * 0.25), Color(1, 1, 1, 0.35), maxf(1, cs * 0.075), true)
	var post_h := cloth.size.y + 32
	for px in [cloth.position.x - 26, cloth.end.x + 12]:
		shape(ci, round_rect(Rect2(px, cloth.position.y - 20, 14, post_h), 5), P.WOOD, P.INK, 2.5)
	for py in [cloth.position.y - 22, cloth.end.y + 4]:
		shape(ci, round_rect(Rect2(cloth.position.x - 34, py, cloth.size.x + 68, 13), 6), P.WOOD_DK, P.INK, 2.5)
	if wrong >= 0 and wrong < woven.size():
		var wc := cloth.position + Vector2((wrong % cols + 0.5) * cs, (wrong / cols + 0.5) * cs)
		var pulse := 1 + 0.12 * sin(t * 8)
		ring(ci, wc, cs * 0.8 * pulse, P.INK, 3)
		var d := cs * 0.32
		line(ci, wc + Vector2(-d, -d), wc + Vector2(d, d), P.INK, 3)
		line(ci, wc + Vector2(-d, d), wc + Vector2(d, -d), P.INK, 3)
	elif shown < target.size():
		var sc := cloth.position + Vector2((shown % cols + 0.5) * cs, (shown / cols + 0.5) * cs)
		shape(ci, ellipse(sc + Vector2(0, cs * 0.42), cs * 0.62, maxf(3.5, cs * 0.17), 0, 24), P.WOOD, P.INK, 1.8)


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
	disc(ci, pin + Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.6))


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
		fill(ci, ellipse(c + Vector2(-r * 0.2, -r * 0.25), r * 0.14, r * 0.26, -0.6, 12), Color(1, 1, 1, 0.5))
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
