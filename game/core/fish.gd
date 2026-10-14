class_name Fish
extends RefCounted
## Pisces's fish (chapter 6, the North Fish): a fish swims under the mirror's water line, drawn to
## each planet thrown as bait: every launch it swims along the line toward the point on it nearest
## where the planet sank, at most `step` px, and bites there, eating every loose star within `bite`
## px, for nothing. Every `jump_every`-th launch it also jumps: from where it stopped it leaps at the
## nearest loose star its bite left, within `jump_reach` px, eating it and every star within its bite
## there, and drops back to the line. No randomness, nodes or rewards.

## Where the fish is, on the water line.
var at: Vector2i
var step: int
var bite: int
## The line runs up and down (the fish swims along y), else across (along x).
var vertical: bool
## How far along the line it can swim: its ends.
var low: int
var high: int
## Every this many launches it jumps (0: never); how far it leaps.
var jump_every: int = 0
var jump_reach: int = 0
## Launches it has been baited (intros don't count).
var launches: int = 0


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


## It leaps on its next launch.
func jumps_next() -> bool:
	return jump_every > 0 and (launches + 1) % jump_every == 0


## Pure: where it leaps from `point`: the loose star of `stars` nearest it within jump_reach (ties:
## the lowest id), or StarCords.NO_CROSSING for none.
func leap_target(point: Vector2i, stars: Array[Star]) -> Vector2i:
	var best: Vector2i = StarCords.NO_CROSSING
	var best_distance: int = jump_reach * jump_reach + 1
	for star: Star in stars:
		var distance: int = point.distance_squared_to(star.position)
		if distance < best_distance:
			best_distance = distance
			best = star.position
	return best


## A launch baited it.
func count_launch() -> void:
	launches += 1


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
