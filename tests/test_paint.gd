## Unit tests for core/paint.gd.
## Run: godot_console --headless --path . --script res://tests/test_paint.gd
extends SceneTree

const Paint = preload("res://core/paint.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


func _init() -> void:
	check(Paint.mix(Paint.RED, Paint.YELLOW) == Paint.ORANGE, "red + yellow = orange")
	check(Paint.mix(Paint.YELLOW, Paint.BLUE) == Paint.GREEN, "yellow + blue = green")
	check(Paint.mix(Paint.RED, Paint.BLUE) == Paint.PURPLE, "red + blue = purple")
	check(Paint.mix(Paint.ORANGE, Paint.YELLOW) == Paint.ORANGE, "red + yellow + yellow = orange")
	check(Paint.mix(Paint.WHITE, Paint.YELLOW) == Paint.YELLOW, "white adds nothing")
	check(Paint.mix(Paint.RED, Paint.BLACK) == Paint.BLACK, "black absorbs everything")

	check(Paint.filter(Paint.ORANGE, Paint.PURPLE) == Paint.RED, "orange filtered by purple = red")

	check(Paint.invert(Paint.RED) == Paint.GREEN, "red <-> green")
	check(Paint.invert(Paint.YELLOW) == Paint.PURPLE, "yellow <-> purple")
	check(Paint.invert(Paint.BLUE) == Paint.ORANGE, "blue <-> orange")
	check(Paint.invert(Paint.WHITE) == Paint.BLACK, "white <-> black")

	check(Paint.shift(Paint.RED) == Paint.YELLOW, "shift red -> yellow")
	check(Paint.shift(Paint.YELLOW) == Paint.BLUE, "shift yellow -> blue")
	check(Paint.shift(Paint.BLUE) == Paint.RED, "shift blue -> red")
	check(Paint.shift(Paint.ORANGE) == Paint.GREEN, "shift orange -> green")
	check(Paint.shift(Paint.GREEN) == Paint.PURPLE, "shift green -> purple")
	check(Paint.shift(Paint.WHITE) == Paint.WHITE, "shift keeps white")
	check(Paint.shift(Paint.BLACK) == Paint.BLACK, "shift keeps black")

	check(Paint.contrast(Paint.ORANGE, Paint.PURPLE) == Paint.GREEN, "contrast orange/purple = green")
	check(Paint.bleach(Paint.BLACK, Paint.RED) == Paint.GREEN, "black bleached of red = green")

	for a in Paint.ALL:
		check(Paint.invert(Paint.invert(a)) == a, "invert twice is identity for " + Paint.name_of(a))
		check(Paint.shift(Paint.shift(Paint.shift(a))) == a, "three shifts is identity for " + Paint.name_of(a))
		for b in Paint.ALL:
			check(Paint.mix(a, b) == Paint.mix(b, a), "mix is symmetric")
			check(Paint.invert(Paint.mix(a, b)) == Paint.filter(Paint.invert(a), Paint.invert(b)), "invert of a mix is the filter of the inverts")

	if failures == 0:
		print("test_paint: all checks passed")
	quit(1 if failures > 0 else 0)
