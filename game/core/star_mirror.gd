class_name StarMirror
extends RefCounted
## Pisces's mirror (chapter 6): the sky is split down the middle like the two fish, and every link
## echoes across the seam. For each of the link's stars, in pick order, the loose star nearest its
## mirror spot within `reach` px is taken too (each star only once, never one of the link's own).
## With `lights`, an unlit constellation star at a mirror spot counts in the echo as well. An echo of
## three that is a valid combo pays like a link (and lights its constellation stars); any other echo
## (one or two stars, or three that don't match) is taken for nothing. RunState applies it; this only
## finds it. Draws no random numbers.

## The seam's x, doubled (so a sky of odd width mirrors on whole pixels): the mirror of x is axis - x.
var axis: int = 0
var reach: int = 0
var lights: bool = false


func _init(p_axis: int, p_reach: int, p_lights: bool = false) -> void:
	axis = p_axis
	reach = p_reach
	lights = p_lights


## Where `point` falls across the seam.
func mirror(point: Vector2i) -> Vector2i:
	return Vector2i(axis - point.x, point.y)


## The echo of a link through `points` (its stars' places, in pick order): for each, the nearest of
## `candidates` within reach of its mirror spot, not already taken (in pick order, at most one each;
## points with none in reach add nothing).
func echo(points: Array[Vector2i], candidates: Array[Star]) -> Array[Star]:
	var taken: Array[Star] = []
	for point: Vector2i in points:
		var spot: Vector2i = mirror(point)
		var best: Star = null
		var best_distance: int = reach * reach + 1
		for star: Star in candidates:
			if taken.has(star):
				continue
			var distance: int = (star.position - spot).length_squared()
			if distance < best_distance or (distance == best_distance and best != null and star.id < best.id):
				best = star
				best_distance = distance
		if best != null:
			taken.append(best)
	return taken


## The combo an `echo` makes (Combos.INVALID unless it's three that match).
static func combo_of(echo_stars: Array[Star]) -> String:
	if echo_stars.size() != Combos.LINK_LENGTH:
		return Combos.INVALID
	var sizes: Array[int] = []
	for star: Star in echo_stars:
		sizes.append(star.size)
	return Combos.evaluate(sizes)
