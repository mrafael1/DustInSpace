class_name Volley
extends RefCounted
## Orion's arrow volley (#70), the Body stage's twist: he counts successful links, and every
## `interval`th one (after its combo and any Sun clear resolve) looses a volley that destroys a
## random `fraction` of the loose sky stars, rounded up, for nothing. Landmarks are never hit. An
## empty sky loses nothing, and the count starts again either way. Launches, purchases, aiming,
## invalid links and cancelled gestures don't count; a link that completes the stage doesn't either.
## Victims are drawn from their own RNG stream, so packs and layout never shift.
## Pure state; RunState applies it inside link() so the link stays one atomic step.

## XOR'd into the run seed so the volley's picks have their own stream.
const SEED_SALT: int = 0x7011E

## Successful links between volleys (balance.json volley.interval).
var interval: int = 3
## The share of loose stars a volley destroys, rounded up (balance.json volley.fraction).
var fraction: float = 0.5
## Links counted since the last volley.
var counted: int = 0

var _rng := RandomNumberGenerator.new()


func _init(p_interval: int, p_fraction: float, run_seed: int) -> void:
	interval = p_interval
	fraction = p_fraction
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


## The stars a volley takes from `loose` (the sky's stars, landmarks never in it), at random.
func pick(loose: Array[Star]) -> Array[Star]:
	var pool: Array[Star] = loose.duplicate()
	var victims: Array[Star] = []
	for i: int in victim_count(loose.size()):
		victims.append(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
	return victims
