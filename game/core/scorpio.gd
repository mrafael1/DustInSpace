class_name Scorpio
extends RefCounted
## A constellation map in play (#40): the full Scorpio, or one of its chapter's part stages
## (`map`, a StarMap: #62). Its landmark stars, each small, medium or big, trace the figure. One unlit landmark can stand in for a star in
## a combo: the combo pays as usual and the landmark lights up instead of being used up. When the
## two landmarks a string joins (SEGMENTS) are both lit, that string forms. Lighting every landmark
## completes the constellation, which is the map's objective.
## Pure state; RunState owns the rules. Landmark positions and sizes are map layout, not balance.
## The constants below are the full Scorpio's layout (StarMap.scorpio); the static helpers answer
## for it (the chapter chart draws it). A run asks its own instance (`map`) instead.

## Landmarks: the 14 stars of Scorpius's usual figure (#61), on the 180x320 grid, inside the play
## sky (y 86-242 once the edge margin is taken off). Their real layout (RA/Dec, east to the left)
## is spread out to at least 24 px apart so each can be picked on its own, keeping the shape: the
## claw arc on the right (beta, Dschubba, pi), sigma and Antares, the heart, to its left; the body
## (tau, epsilon, mu) falling steeply; the tail curling left along the bottom (zeta, eta, theta)
## and hooking back up to the right (iota, kappa) to the stinger (Shaula).
const LANDMARKS: Array[Vector2i] = [
	Vector2i(146, 90), Vector2i(160, 112), Vector2i(158, 138), Vector2i(134, 122),
	Vector2i(110, 134), Vector2i(100, 158), Vector2i(95, 182), Vector2i(92, 207),
	Vector2i(88, 233), Vector2i(62, 236), Vector2i(36, 232), Vector2i(14, 214),
	Vector2i(28, 192), Vector2i(52, 184),
]
## The strings, as pairs of landmark indices: the head branches (Dschubba to each claw and down to
## sigma), then one line to the stinger. 24-29 px each.
const SEGMENTS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(3, 4), Vector2i(4, 5), Vector2i(5, 6),
	Vector2i(6, 7), Vector2i(7, 8), Vector2i(8, 9), Vector2i(9, 10), Vector2i(10, 11),
	Vector2i(11, 12), Vector2i(12, 13),
]
## The head (Dschubba), where the claws meet, and the heart.
const HEAD: int = 1
const ANTARES: int = 4
## Each landmark's size (Star.Size), from the star's brightness: Antares, Shaula and theta, the
## brightest, are big; Dschubba, beta, epsilon and kappa medium; the rest small.
const SIZES: Array[int] = [
	Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.SMALL, Star.Size.SMALL,
	Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.SMALL,
	Star.Size.SMALL, Star.Size.SMALL, Star.Size.BIG, Star.Size.SMALL,
	Star.Size.MEDIUM, Star.Size.BIG,
]
## Lit from the start: the claw arc (beta, Dschubba, pi) and its two strings, so 11 landmarks and
## 11 strings are left to build.
const STARTING_LIT: Array[int] = [0, 1, 2]
## At most this many landmarks in one combo: two would light a whole string with one sky star
## (tools/balance/sim.py: the constellation done in about 2 packs).
const LANDMARKS_PER_COMBO: int = 1
## The play sky LANDMARKS are laid out in (a 9:16 screen). A taller sky (a taller phone) moves the
## whole map by `shift` so it stays centred in it; spacing, sizes and reach don't change.
const HOME_SKY := Rect2i(0, 78, 180, 172)

var lit: Array[bool] = []
## How far the map sits from its home layout in this run's sky (whole pixels, vertical only).
var shift: Vector2i = Vector2i.ZERO
## The layout in play.
var map: StarMap


## `sky`: the run's play sky; the map is centred in it as it is in HOME_SKY. `p_map`: the layout
## (the full Scorpio unless a stage says otherwise).
func _init(sky: Rect2i = HOME_SKY, p_map: StarMap = null) -> void:
	map = p_map if p_map != null else StarMap.scorpio()
	for i: int in map.count():
		lit.append(map.starting_lit.has(i))
	shift = Vector2i(0, (sky.get_center().y - HOME_SKY.get_center().y))


## Landmark `index`'s position in this run's sky.
func landmark_position(index: int) -> Vector2i:
	return map.landmarks[index] + shift


## Every landmark's position in this run's sky.
func landmark_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for i: int in map.count():
		positions.append(landmark_position(i))
	return positions


## True if `id` is one of this map's landmarks in a link.
func is_landmark(id: int) -> bool:
	return id < 0 and landmark_index(id) < map.count()


## A landmark as a star, for links and combos, where it sits in this run's sky. Its id is its
## landmark id.
func landmark_star(index: int) -> Star:
	return Star.new(landmark_id(index), map.sizes[index] as Star.Size, landmark_position(index))


func is_lit(index: int) -> bool:
	return lit[index]


## String `segment` forms once both the landmarks it joins are lit.
func is_built(segment: int) -> bool:
	return lit[map.segments[segment].x] and lit[map.segments[segment].y]


func built_count() -> int:
	var count: int = 0
	for segment: int in map.segment_count():
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
	for segment: int in map.segments_of(index):
		if is_built(segment):
			formed.append(segment)
	return formed


## Sizes of the landmarks still unlit.
func unlit_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for i: int in map.count():
		if not lit[i]:
			sizes.append(map.sizes[i])
	return sizes


## Landmarks use negative ids in a link so they never collide with star ids: landmark i is -(i + 1).
static func landmark_id(index: int) -> int:
	return -(index + 1)


static func landmark_index(id: int) -> int:
	return -id - 1


# The full Scorpio's layout, for the chapter chart and tests.

static func segment_count() -> int:
	return SEGMENTS.size()


static func segment_landmarks(segment: int) -> Array[int]:
	return [SEGMENTS[segment].x, SEGMENTS[segment].y]


static func segment_ends(segment: int) -> Array[Vector2i]:
	return [LANDMARKS[SEGMENTS[segment].x], LANDMARKS[SEGMENTS[segment].y]]


static func neighbours(index: int) -> Array[int]:
	return _full().neighbours(index)


static func segments_of(index: int) -> Array[int]:
	return _full().segments_of(index)


static func landmark_path(from: int, to: int) -> Array[int]:
	return _full().path(from, to)


static func is_landmark_id(id: int) -> bool:
	return id < 0 and landmark_index(id) < LANDMARKS.size()


static func _full() -> StarMap:
	return StarMap.scorpio()
