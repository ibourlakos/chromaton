## Critter Workshop palette and fonts (DESIGN.md 7.2).
##
## The eight signal colors are reserved for paint. Everything else (world,
## UI, critters) uses the neutrals below on a light paper background.
extends RefCounted

## Paint colors, indexed by the color's value (see core/paint.gd).
const SIG := [
	Color("#FFFDF7"),  # White
	Color("#E23A3F"),  # Red
	Color("#F4C21B"),  # Yellow
	Color("#F18A22"),  # Orange
	Color("#2E62D6"),  # Blue
	Color("#8A4BC8"),  # Purple
	Color("#2FA35A"),  # Green
	Color("#1E1B23"),  # Black
]
## Ink for glyph dots on light and dark paint.
const PIP_DARK := Color("#2A2530")
const PIP_LIGHT := Color("#FFFFFF")

const INK := Color("#3A302A")
const INK_SOFT := Color("#7A6C5F")
const PAPER := Color("#ECE5D6")
const PAPER_DK := Color("#E2D9C6")
const WOOD := Color("#C99A69")
const WOOD_DK := Color("#A97C52")
const WOOD_LT := Color("#DDB88C")
const HOOP := Color("#8C7A68")
const TAG := Color("#F8F3E8")
const GLASS := Color("#F6F1E6")
const CLOTH := Color("#F4EFE4")
const WARP := Color("#D3C9B5")
const EMPTY_PAINT := Color("#E6DDCB")
const WHITE_STITCH := Color("#FFFCF4")
const CLAY := Color("#C7A58C")
const CLAY_DK := Color("#A8866E")
const FUR := Color("#EBD8BB")
const FUR_DK := Color("#C9AE8A")
const BLUSH := Color(0.84, 0.59, 0.5, 0.45)
const SHADOW := Color(0.227, 0.188, 0.165, 0.14)
const VEIL := Color(0.925, 0.898, 0.839, 0.82)

const FREDOKA := "res://fonts/Fredoka.ttf"
const NUNITO := "res://fonts/Nunito.ttf"

static var _fonts := {}
static var _paper: Texture2D


static func is_dark(color: int) -> bool:
	return color == 7 or color == 4 or color == 5


## Fredoka for display text, Nunito for small UI text.
static func display(weight := 600) -> Font:
	return _font(FREDOKA, weight)


static func ui(weight := 700) -> Font:
	return _font(NUNITO, weight)


static func _font(path: String, weight: int) -> Font:
	var key := "%s:%d" % [path, weight]
	if _fonts.has(key):
		return _fonts[key]
	var base: Font = null
	if ResourceLoader.exists(path):
		base = load(path)
	if base == null:
		var file := FontFile.new()
		if file.load_dynamic_font(path) == OK:
			base = file
	if base == null:
		base = ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	_fonts[key] = variation
	return variation


## A tile of speckled paper, made once.
static func paper_texture() -> Texture2D:
	if _paper != null:
		return _paper
	var size := 256
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	var x := 12345
	for i in 700:
		x = (x * 1103515245 + 12345) & 0x7fffffff
		var px := (x >> 8) % size
		x = (x * 1103515245 + 12345) & 0x7fffffff
		var py := (x >> 8) % size
		var c := PAPER.darkened(0.06) if i % 2 else PAPER.lightened(0.25)
		img.set_pixel(px, py, c)
		img.set_pixel((px + 1) % size, py, c)
	_paper = ImageTexture.create_from_image(img)
	return _paper
