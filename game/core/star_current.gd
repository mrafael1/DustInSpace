class_name StarCurrent
extends RefCounted
## One launch-driven flow. No randomness, nodes or rewards. Existing destinations can be
## reserved before a burst, so newly arriving stars never invalidate the aiming preview.
## A draining flow loses every star it carries out of its field: it pays nothing.

class Move:
	extends RefCounted
	var star_id: int
	var from: Vector2i
	var to: Vector2i
	## Carried out of a draining field: `to` is where it leaves the sky.
	var drained: bool

	func _init(id: int, start: Vector2i, finish: Vector2i, lost: bool = false) -> void:
		star_id = id
		from = start
		to = finish
		drained = lost

var region: Rect2i
var displacement: Vector2i
var drains: bool


func _init(area: Rect2i, step: Vector2i, p_drains: bool = false) -> void:
	region = area
	displacement = step
	drains = p_drains


## Snapshot membership; downstream first; one step. A blocked destination leaves the star
## where it is instead of squeezing sprites together or silently moving an unaffected star.
## A star leaving a draining field is never blocked, and its spot frees for the stars behind it.
func preview(stars: Array[Star], sky: Rect2i, landmarks: Array[Vector2i], reserved: Dictionary[int, Vector2i] = {}) -> Dictionary[int, Vector2i]:
	var destinations: Dictionary[int, Vector2i] = {}
	var gone: Dictionary[int, bool] = {}
	for star: Star in stars:
		destinations[star.id] = reserved.get(star.id, star.position)
		if leaves(star.position, destinations[star.id]):
			gone[star.id] = true
	var ordered: Array[Star] = stars.duplicate()
	ordered.sort_custom(_downstream_first)
	for star: Star in ordered:
		if reserved.has(star.id) or not region.has_point(star.position):
			continue
		var wanted: Vector2i = StarScatter.clamp_to_sky(star.position + displacement, sky)
		destinations.erase(star.id)
		if leaves(star.position, wanted):
			gone[star.id] = true
			destinations[star.id] = wanted
		else:
			destinations[star.id] = wanted if _has_room(wanted, destinations, gone, landmarks) else star.position
	return destinations


func moves(stars: Array[Star], destinations: Dictionary[int, Vector2i]) -> Array[Move]:
	var result: Array[Move] = []
	for star: Star in stars:
		var to: Vector2i = destinations.get(star.id, star.position)
		if star.position != to:
			result.append(Move.new(star.id, star.position, to, leaves(star.position, to)))
	return result


## Whether a star moving from `from` to `to` is carried out of a draining field (and lost).
func leaves(from: Vector2i, to: Vector2i) -> bool:
	return drains and from != to and region.has_point(from) and not region.has_point(to)


## Vacate downstream positions before upstream stars try to follow. Creation age is only
## a tie-break at the same distance along the flow, never the order of a moving cluster.
func _downstream_first(a: Star, b: Star) -> bool:
	var along_a: int = a.position.x * displacement.x + a.position.y * displacement.y
	var along_b: int = b.position.x * displacement.x + b.position.y * displacement.y
	return a.id < b.id if along_a == along_b else along_a > along_b


func _has_room(point: Vector2i, occupied: Dictionary[int, Vector2i], gone: Dictionary[int, bool], landmarks: Array[Vector2i]) -> bool:
	for id: int in occupied:
		if not gone.has(id) and point.distance_squared_to(occupied[id]) < StarScatter.MIN_SPACING * StarScatter.MIN_SPACING:
			return false
	for landmark: Vector2i in landmarks:
		if point.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return false
	return true
