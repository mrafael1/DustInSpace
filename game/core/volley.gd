class_name Volley
extends RefCounted
## Orion's arrow volley (#70), the Body stage's twist: he counts successful links, and every
## `interval`th one (after its combo and any Sun clear resolve) looses a volley that destroys a
## random `fraction` of the loose sky stars, rounded up, for nothing. Landmarks are never hit. An
## empty sky loses nothing, and the count starts again either way. Launches, purchases, aiming,
## invalid links and cancelled gestures don't count; a link that completes the stage doesn't either.
## Victims are drawn from their own RNG stream, so packs and layout never shift.
## The stage opens with an intro: stars already in the sky, and a volley at once that destroys them
## (it pays nothing and doesn't count), to show what's coming.
## Pure state; RunState applies it inside link() so the link stays one atomic step.

## XOR'd into the run seed so the volley's picks have their own stream.
const SEED_SALT: int = 0x7011E
## Orion's corner of the sky (from its top-left), where his figure stands: the intro keeps its
## stars' spots out of it, and INTRO_CLEAR px further.
const ORION_CORNER := Rect2i(0, 0, 44, 44)
const INTRO_CLEAR: int = 24

## Successful links between volleys (balance.json volley.interval).
var interval: int = 0
## The share of loose stars a volley destroys, rounded up (balance.json volley.fraction).
var fraction: float = 0.0
## The stars the stage opens with, which the intro volley destroys (0: no intro).
var intro_stars: int = 0
## Links counted since the last volley.
var counted: int = 0

var _rng := RandomNumberGenerator.new()


func _init(p_interval: int, p_fraction: float, run_seed: int, p_intro_stars: int = 0) -> void:
	interval = p_interval
	fraction = p_fraction
	intro_stars = p_intro_stars
	_rng.seed = run_seed ^ SEED_SALT


## Successful links left before the next volley: interval down to 1.
func links_left() -> int:
	return interval - counted


## A successful link: counts it. Returns true when it's the one that looses the volley (the count
## starts again).
func count_link() -> bool:
	counted += 1
	if counted < interval:
		return false
	counted = 0
	return true


## How many of `loose` stars a volley takes: the fraction, rounded up.
func victim_count(loose: int) -> int:
	return mini(ceili(loose * fraction - 0.0001), loose)


## The intro's star sizes: `count` at random, from the volley's stream.
func intro_sizes(count: int) -> Array[int]:
	var sizes: Array[int] = []
	for i: int in count:
		sizes.append(_rng.randi_range(Star.Size.SMALL, Star.Size.BIG))
	return sizes


## The intro stars' centres: two spots in `inner` (the sky's, whose top-left is Orion's corner) clear
## of his figure, from the volley's stream.
func intro_spots(inner: Rect2i, sky: Rect2i) -> Array[Vector2i]:
	var corner := Rect2i(sky.position + ORION_CORNER.position, ORION_CORNER.size).grow(INTRO_CLEAR)
	var spots: Array[Vector2i] = []
	while spots.size() < 2:
		var spot := Vector2i(_rng.randi_range(inner.position.x, inner.end.x - 1), _rng.randi_range(inner.position.y, inner.end.y - 1))
		if not corner.has_point(spot):
			spots.append(spot)
	return spots


## The stars a volley takes from `loose` (the sky's stars, landmarks never in it), at random.
func pick(loose: Array[Star]) -> Array[Star]:
	var pool: Array[Star] = loose.duplicate()
	var victims: Array[Star] = []
	for i: int in victim_count(loose.size()):
		victims.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	return victims
