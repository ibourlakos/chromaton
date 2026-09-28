## The eight paint colors and the basic ways to combine them.
##
## A paint is the set of primaries it contains, stored as flags:
## Red = 1, Yellow = 2, Blue = 4. This numeric form is internal only;
## players never see numbers, they see paint.
extends RefCounted

const WHITE := 0
const RED := 1
const YELLOW := 2
const ORANGE := 3
const BLUE := 4
const PURPLE := 5
const GREEN := 6
const BLACK := 7

const ALL := [WHITE, RED, YELLOW, ORANGE, BLUE, PURPLE, GREEN, BLACK]
const PRIMARIES := [RED, YELLOW, BLUE]
const NAMES := ["White", "Red", "Yellow", "Orange", "Blue", "Purple", "Green", "Black"]


## Everything in either paint. Red + Yellow = Orange.
static func mix(a: int, b: int) -> int:
	return a | b


## Only the primaries both paints share. Orange with Purple = Red.
static func filter(a: int, b: int) -> int:
	return a & b


## The complementary color. Red <-> Green, White <-> Black.
static func invert(a: int) -> int:
	return BLACK ^ a


## Turn the color wheel one step: Red -> Yellow -> Blue -> Red.
static func shift(a: int) -> int:
	return ((a << 1) & BLACK) | (a >> 2)


## The primaries in exactly one of the two paints.
static func contrast(a: int, b: int) -> int:
	return a ^ b


## The first paint with the second one's primaries washed out.
static func bleach(a: int, b: int) -> int:
	return a & ~b & BLACK


static func name_of(a: int) -> String:
	return NAMES[a]
