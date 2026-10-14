class_name Fish
extends RefCounted
## Pisces's fish (chapter 6, the North Fish): a fish swims under the mirror's water line, drawn to
## each planet thrown as bait: every launch it swims along the line toward the point on it nearest
## where the planet sank, at most `step` px, and bites there, eating every loose star within `bite`
## px, for nothing. No randomness, nodes or rewards. It never leaves the line.

## Where the fish is, on the water line.
var at: Vector2i
var step: int
var bite: int
## The line runs up and down (the fish swims along y), else across (along x).
var vertical: bool
## How far along the line it can swim: its ends.
var low: int
var high: int


## `start`: where it waits, on the line. `p_low`/`p_high`: the line's ends along it.
func _init(start: Vector2i, p_step: int, p_bite: int, p_vertical: bool, p_low: int, p_high: int) -> void:
	at = start
	step = p_step
	bite = p_bite
	vertical = p_vertical
	low = p_low
	high = p_high


## Pure: where the fish swims for a planet that sank at `bait`: toward the point on the line nearest
## it, at most `step` px, and never past the line's ends.
func swims_to(bait: Vector2i) -> Vector2i:
	var here: int = at.y if vertical else at.x
	var wanted: int = clampi(bait.y if vertical else bait.x, low, high)
	var along: int = here + clampi(wanted - here, -step, step)
	return Vector2i(at.x, along) if vertical else Vector2i(along, at.y)


## Pure: the ids of `stars` a bite at `point` eats.
func bites(point: Vector2i, stars: Array[Star]) -> Array[int]:
	var eaten: Array[int] = []
	for star: Star in stars:
		if point.distance_squared_to(star.position) <= bite * bite:
			eaten.append(star.id)
	return eaten


## The fish has swum: it waits at `point` for the next bait.
func move_to(point: Vector2i) -> void:
	at = point
