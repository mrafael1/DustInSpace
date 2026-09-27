class_name Scorpio
extends RefCounted
## The Scorpio constellation map (#40, a prototype). Fixed landmark stars, each small, medium or
## big, trace Scorpio from its head to its stinger. One unlit landmark can stand in for a star in
## a combo: the combo pays as usual and the landmark lights up instead of being used up. When two
## neighbouring landmarks are both lit, the string between them forms. Lighting every landmark
## completes the constellation, which is the map's objective.
## Pure state; RunState owns the rules. Landmark positions and sizes are map layout, not balance.

## Landmarks, head to stinger, on the 180x320 grid, inside the play sky (y 86-242 once the edge
## margin is taken off), about 28-30 px apart, with room above the head for the drawing's claws.
const LANDMARKS: Array[Vector2i] = [
	Vector2i(146, 106), Vector2i(128, 130), Vector2i(110, 154), Vector2i(96, 180),
	Vector2i(88, 208), Vector2i(66, 228), Vector2i(38, 230), Vector2i(24, 206),
]
## Each landmark's size (Star.Size): Antares, the heart, is big; so is the stinger.
const SIZES: Array[int] = [
	Star.Size.MEDIUM, Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM,
	Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.BIG,
]
## Lit from the start: the head's string is already there, so 6 are left to build.
const STARTING_LIT: Array[int] = [0, 1]
## At most this many landmarks in one combo: two would light a whole string with one sky star
## (tools/balance/sim.py: the constellation done in about 2 packs).
const LANDMARKS_PER_COMBO: int = 1

var lit: Array[bool] = []


func _init() -> void:
	for i: int in LANDMARKS.size():
		lit.append(STARTING_LIT.has(i))


static func segment_count() -> int:
	return LANDMARKS.size() - 1


## Landmarks use negative ids in a link so they never collide with star ids: landmark i is -(i + 1).
static func landmark_id(index: int) -> int:
	return -(index + 1)


static func landmark_index(id: int) -> int:
	return -id - 1


static func is_landmark_id(id: int) -> bool:
	return id < 0 and landmark_index(id) < LANDMARKS.size()


static func segment_ends(segment: int) -> Array[Vector2i]:
	return [LANDMARKS[segment], LANDMARKS[segment + 1]]


## A landmark as a star, for links and combos. Its id is its landmark id.
static func landmark_star(index: int) -> Star:
	return Star.new(landmark_id(index), SIZES[index] as Star.Size, LANDMARKS[index])


func is_lit(index: int) -> bool:
	return lit[index]


## The string joining landmarks `segment` and `segment + 1` forms once both are lit.
func is_built(segment: int) -> bool:
	return lit[segment] and lit[segment + 1]


func built_count() -> int:
	var count: int = 0
	for segment: int in segment_count():
		if is_built(segment):
			count += 1
	return count


func is_complete() -> bool:
	return not lit.has(false)


## Lights a landmark. Returns the strings it completes, in order.
func light(index: int) -> Array[int]:
	var formed: Array[int] = []
	if lit[index]:
		return formed
	lit[index] = true
	for segment: int in [index - 1, index]:
		if segment >= 0 and segment < segment_count() and is_built(segment):
			formed.append(segment)
	return formed


## Sizes of the landmarks still unlit.
func unlit_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for i: int in LANDMARKS.size():
		if not lit[i]:
			sizes.append(SIZES[i])
	return sizes
