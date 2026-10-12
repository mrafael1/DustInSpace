class_name StarGravity
extends RefCounted
## Sagittarius's black hole (chapter 5, a debug trial for now): a hole at a fixed point of the sky.
## Once each launch has burst, every loose star falls toward it, a step that grows the closer it is
## (`pull` / its distance, at least 1 px, at most `max_step`); a star whose fall reaches the event
## horizon (`horizon` px from the hole) is swallowed, lost for nothing. Landmarks never fall.
## No randomness, nodes or rewards. Existing destinations can be reserved before a burst, so newly
## arriving stars never invalidate the aiming preview (as StarCurrent's).

class Fall:
	extends RefCounted
	var star_id: int
	var from: Vector2i
	var to: Vector2i
	## Fell past the horizon: `to` is the hole, and the star is gone.
	var swallowed: bool

	func _init(id: int, start: Vector2i, finish: Vector2i, lost: bool = false) -> void:
		star_id = id
		from = start
		to = finish
		swallowed = lost

## A blocked star flows round what's in its way (as the current's do): at its full step, then at
## each shorter one, it tries straight on, then shifted this far across its fall (nearest first,
## alternating sides), never further from the hole than it was.
const SIDESTEPS: Array[int] = [4, -4, 8, -8, 12, -12]

## Where the hole is (the play sky's pixels).
var center: Vector2i
## The event horizon's radius: a star that falls to within it is swallowed.
var horizon: int
## A star `d` px from the hole falls pull / d px a launch.
var pull: int
var max_step: int


func _init(p_center: Vector2i, p_horizon: int, p_pull: int, p_max_step: int) -> void:
	assert(p_horizon >= 0 and p_pull >= 0 and p_max_step >= 1, "a black hole needs a horizon, a pull and a step")
	center = p_center
	horizon = p_horizon
	pull = p_pull
	max_step = p_max_step


## How far a star at `point` falls on a launch (0 at the hole itself, or with no pull).
func step_at(point: Vector2i) -> int:
	var distance: float = Vector2(point).distance_to(Vector2(center))
	if distance <= 0.0 or pull <= 0:
		return 0
	return clampi(roundi(pull / distance), 1, max_step)


## Whether a star at `point` is inside the horizon (swallowed).
func inside(point: Vector2i) -> bool:
	return point.distance_squared_to(center) <= horizon * horizon


## Whether a star at `point` falls past the horizon on its next fall.
func swallows_at(point: Vector2i) -> bool:
	var distance: float = Vector2(point).distance_to(Vector2(center))
	return pull > 0 and distance - step_at(point) <= horizon


## Snapshot membership; nearest the hole first; one fall each. A star the hole swallows frees its
## spot for the stars behind it. A blocked star (another star or a landmark too close to where it
## would land) flows round it or falls as far as it can; only a star with no room at all stays put,
## so stars are never squeezed together. Reserved stars keep their reserved destination.
func preview(stars: Array[Star], sky: Rect2i, landmarks: Array[Vector2i], reserved: Dictionary[int, Vector2i] = {}) -> Dictionary[int, Vector2i]:
	var destinations: Dictionary[int, Vector2i] = {}
	var gone: Dictionary[int, bool] = {}
	for star: Star in stars:
		destinations[star.id] = reserved.get(star.id, star.position)
		if destinations[star.id] == center:
			gone[star.id] = true
	var ordered: Array[Star] = stars.duplicate()
	ordered.sort_custom(_nearest_first)
	for star: Star in ordered:
		if reserved.has(star.id):
			continue
		destinations.erase(star.id)
		if swallows_at(star.position):
			gone[star.id] = true
			destinations[star.id] = center
		else:
			destinations[star.id] = _fall_to(star.position, sky, destinations, gone, landmarks)
	return destinations


func falls(stars: Array[Star], destinations: Dictionary[int, Vector2i]) -> Array[Fall]:
	var result: Array[Fall] = []
	for star: Star in stars:
		var to: Vector2i = destinations.get(star.id, star.position)
		if star.position != to or to == center:
			result.append(Fall.new(star.id, star.position, to, swallowed(to)))
	return result


## Whether a star whose fall ends at `to` was swallowed (it ends in the hole).
func swallowed(to: Vector2i) -> bool:
	return to == center


func _nearest_first(a: Star, b: Star) -> bool:
	var da: int = a.position.distance_squared_to(center)
	var db: int = b.position.distance_squared_to(center)
	return a.id < b.id if da == db else da < db


## Where a star at `from` can fall: its full step, else round what's in the way at the same
## distance, else the furthest spot along its fall (or round it) with room, else nowhere.
func _fall_to(from: Vector2i, sky: Rect2i, occupied: Dictionary[int, Vector2i], gone: Dictionary[int, bool], landmarks: Array[Vector2i]) -> Vector2i:
	var way: Vector2 = Vector2(center - from).normalized()
	var across := Vector2(-way.y, way.x)
	var reach: int = from.distance_squared_to(center)
	for k: int in range(step_at(from), 0, -1):
		for offset: int in [0] + SIDESTEPS:
			var spot: Vector2i = StarScatter.clamp_to_sky(Vector2i((Vector2(from) + way * k + across * offset).round()), sky)
			if spot == from or spot.distance_squared_to(center) >= reach or inside(spot):
				continue
			if _has_room(spot, occupied, gone, landmarks):
				return spot
	return from


func _has_room(point: Vector2i, occupied: Dictionary[int, Vector2i], gone: Dictionary[int, bool], landmarks: Array[Vector2i]) -> bool:
	for id: int in occupied:
		if not gone.has(id) and point.distance_squared_to(occupied[id]) < StarScatter.MIN_SPACING * StarScatter.MIN_SPACING:
			return false
	for landmark: Vector2i in landmarks:
		if point.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return false
	return true
