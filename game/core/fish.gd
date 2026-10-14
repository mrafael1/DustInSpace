class_name Fish
extends RefCounted
## Pisces's fish (chapter 6, the North Fish): a fish waits still under the mirror's water line.
## Every `jump_every`-th launch it leaps from there at the nearest loose star within `jump_reach` px,
## eating it and every loose star within `bite` px of it, for nothing, and drops back to its spot.
## No randomness, nodes or rewards.

## Where the fish waits, on the water line.
var at: Vector2i
var bite: int
## The line runs up and down, else across (it lies along it).
var vertical: bool
## Every this many launches it leaps; how far.
var jump_every: int
var jump_reach: int
## Launches thrown since the run began (intros don't count).
var launches: int = 0


func _init(start: Vector2i, p_bite: int, p_vertical: bool, p_jump_every: int, p_jump_reach: int) -> void:
	at = start
	bite = p_bite
	vertical = p_vertical
	jump_every = p_jump_every
	jump_reach = p_jump_reach


## It leaps on its next launch.
func jumps_next() -> bool:
	return jump_every > 0 and (launches + 1) % jump_every == 0


## Pure: where it leaps: the loose star of `stars` nearest it within jump_reach (ties: the first),
## or StarCords.NO_CROSSING for none.
func leap_target(stars: Array[Star]) -> Vector2i:
	var best: Vector2i = StarCords.NO_CROSSING
	var best_distance: int = jump_reach * jump_reach + 1
	for star: Star in stars:
		var distance: int = at.distance_squared_to(star.position)
		if distance < best_distance:
			best_distance = distance
			best = star.position
	return best


## A launch was thrown.
func count_launch() -> void:
	launches += 1


## Pure: the ids of `stars` its bite at `point` eats.
func bites(point: Vector2i, stars: Array[Star]) -> Array[int]:
	var eaten: Array[int] = []
	for star: Star in stars:
		if point.distance_squared_to(star.position) <= bite * bite:
			eaten.append(star.id)
	return eaten
