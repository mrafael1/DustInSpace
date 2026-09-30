class_name Hunt
extends RefCounted
## Orion's hunting area (#71), the Heart stage's twist: he marks a circle of the sky, and the next
## launch has his arrow strike it once that pack has burst: every loose sky star inside (the new
## ones too) is destroyed, for nothing. Landmarks are never hit. Then he marks a new circle. The
## first launch only marks (there's no circle to strike yet). Links, purchases, aiming and cancelled
## gestures don't move him. Circles are placed at random from their own RNG stream, clear of his
## corner of the sky.
## The stage opens with an intro that plays the whole cycle once: stars in a circle, a demo launch
## bursting into it, and the strike that takes them all (it pays nothing and uses no pack).
## Pure state; RunState applies it inside launch() so a launch stays one atomic step.

## XOR'd into the run seed so the circles have their own stream and never shift packs or layout.
const SEED_SALT: int = 0x4A7E

## The circle's radius in native px (balance.json hunt.radius).
var radius: int = 0
## The marked circle's centre; only meaningful while has_area().
var centre: Vector2i = Vector2i.ZERO

var _marked: bool = false
var _rng := RandomNumberGenerator.new()


func _init(p_radius: int, run_seed: int) -> void:
	radius = p_radius
	_rng.seed = run_seed ^ SEED_SALT


func has_area() -> bool:
	return _marked


## The intro's star sizes: `count` at random, from the hunt's stream.
func intro_sizes(count: int) -> Array[int]:
	var sizes: Array[int] = []
	for i: int in count:
		sizes.append(_rng.randi_range(Star.Size.SMALL, Star.Size.BIG))
	return sizes


## Whether a star at `at` is inside the marked circle (its edge included).
func contains(at: Vector2i) -> bool:
	return _marked and (at - centre).length_squared() <= radius * radius


## The loose stars (landmarks are never in `loose`) the arrow takes: those inside the circle, in
## order. The circle is used up either way.
func strike(loose: Array[Star]) -> Array[Star]:
	var hit: Array[Star] = []
	for star: Star in loose:
		if contains(star.position):
			hit.append(star)
	_marked = false
	return hit


## Marks a new circle, wholly inside `sky` (whose top-left is Orion's corner) and clear of his
## figure. Returns the centre.
func mark(sky: Rect2i) -> Vector2i:
	var corner := Rect2i(sky.position + Volley.ORION_CORNER.position, Volley.ORION_CORNER.size).grow(radius)
	var room: Rect2i = sky.grow(-radius) if sky.grow(-radius).has_area() else StarScatter.inner_rect(sky)
	for attempt: int in 64:
		centre = Vector2i(_rng.randi_range(room.position.x, room.end.x - 1), _rng.randi_range(room.position.y, room.end.y - 1))
		if not corner.has_point(centre):
			break
	_marked = true
	return centre

