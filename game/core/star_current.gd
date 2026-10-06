class_name StarCurrent
extends RefCounted
## One launch-driven flow. No randomness, nodes or rewards. Existing destinations can be
## reserved before a burst, so newly arriving stars never invalidate the aiming preview.

class Move:
	extends RefCounted
	var star_id: int
	var from: Vector2i
	var to: Vector2i

	func _init(id: int, start: Vector2i, finish: Vector2i) -> void:
		star_id = id
		from = start
		to = finish

var region: Rect2i
var displacement: Vector2i


func _init(area: Rect2i, step: Vector2i) -> void:
	region = area
	displacement = step


## Snapshot membership; stable ID order; one step. A blocked destination leaves the star
## where it is instead of squeezing sprites together or silently moving an unaffected star.
func preview(stars: Array[Star], sky: Rect2i, landmarks: Array[Vector2i], reserved: Dictionary[int, Vector2i] = {}) -> Dictionary[int, Vector2i]:
	var destinations: Dictionary[int, Vector2i] = {}
	for star: Star in stars:
		destinations[star.id] = reserved.get(star.id, star.position)
	var ordered: Array[Star] = stars.duplicate()
	ordered.sort_custom(func(a: Star, b: Star) -> bool: return a.id < b.id)
	for star: Star in ordered:
		if reserved.has(star.id) or not region.has_point(star.position):
			continue
		var wanted: Vector2i = StarScatter.clamp_to_sky(star.position + displacement, sky)
		destinations.erase(star.id)
		destinations[star.id] = wanted if _has_room(wanted, destinations, landmarks) else star.position
	return destinations


func moves(stars: Array[Star], destinations: Dictionary[int, Vector2i]) -> Array[Move]:
	var result: Array[Move] = []
	for star: Star in stars:
		var to: Vector2i = destinations.get(star.id, star.position)
		if star.position != to:
			result.append(Move.new(star.id, star.position, to))
	return result


func _has_room(point: Vector2i, occupied: Dictionary[int, Vector2i], landmarks: Array[Vector2i]) -> bool:
	for other: Vector2i in occupied.values():
		if point.distance_squared_to(other) < StarScatter.MIN_SPACING * StarScatter.MIN_SPACING:
			return false
	for landmark: Vector2i in landmarks:
		if point.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return false
	return true
