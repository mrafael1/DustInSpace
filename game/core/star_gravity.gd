class_name StarGravity
extends RefCounted
## Sagittarius's black hole (chapter 5): a hole at a fixed point of the sky.
## Once each launch has burst, every loose star falls toward it, a step that grows the closer it is
## (`pull` / its distance, at least 1 px, at most `max_step`); a star whose fall reaches the event
## horizon (`horizon` px from the hole) is swallowed, lost for nothing. Landmarks never fall.
## A hungry hole (`hunger` > 0) grows: each star it swallows widens its horizon by `hunger` px, up to
## `max_horizon`.
## Twin holes (add_twin): each star falls toward its nearest hole. Once each launch has resolved the
## two drift `drift` px toward each other along the line between them (a fixed path); when the next
## drift would make their horizons touch, they merge at the middle into one hole of `merge_horizon`
## (the run plays it as a Big Bang).
## No randomness, nodes or rewards. Existing destinations can be reserved before a burst, so newly
## arriving stars never invalidate the aiming preview (as StarCurrent's).

class Fall:
	extends RefCounted
	var star_id: int
	var from: Vector2i
	var to: Vector2i
	## Fell past the horizon: `to` is the hole it fell into, and the star is gone.
	var swallowed: bool

	func _init(id: int, start: Vector2i, finish: Vector2i, lost: bool = false) -> void:
		star_id = id
		from = start
		to = finish
		swallowed = lost

## A blocked star flows round what's in its way (as the current's do): at its full step, then at
## each shorter one, it tries straight on, then shifted this far across its fall (nearest first,
## alternating sides), never further from its hole than it was.
const SIDESTEPS: Array[int] = [4, -4, 8, -8, 12, -12]

## Where each hole is (the play sky's pixels), and its event horizon's radius: a star that falls to
## within it is swallowed. One hole, or two twins before they merge.
var centers: Array[Vector2i] = []
var horizons: Array[int] = []
## The first hole (the only one, but for twins).
var center: Vector2i:
	get:
		return centers[0]
	set(value):
		centers[0] = value
var horizon: int:
	get:
		return horizons[0]
	set(value):
		horizons[0] = value
## A star `d` px from its hole falls pull / d px a launch.
var pull: int
var max_step: int
## Px the horizon widens for each star swallowed (0: it never grows), up to max_horizon.
var hunger: int = 0
var max_horizon: int = 0
## Twins: px each drifts toward the other a launch, and the merged hole's horizon.
var drift: int = 0
var merge_horizon: int = 0


func _init(p_center: Vector2i, p_horizon: int, p_pull: int, p_max_step: int, p_hunger: int = 0, p_max_horizon: int = 0) -> void:
	assert(p_horizon >= 0 and p_pull >= 0 and p_max_step >= 1, "a black hole needs a horizon, a pull and a step")
	centers = [p_center]
	horizons = [p_horizon]
	pull = p_pull
	max_step = p_max_step
	hunger = p_hunger
	max_horizon = maxi(p_max_horizon, p_horizon)


## A second hole at `at` with the same horizon, the two drifting `p_drift` px toward each other a
## launch until they merge into one of `p_merge_horizon`.
func add_twin(at: Vector2i, p_drift: int, p_merge_horizon: int) -> void:
	centers.append(at)
	horizons.append(horizon)
	drift = p_drift
	merge_horizon = maxi(p_merge_horizon, horizon)


## Whether there are two holes still to merge.
func has_twins() -> bool:
	return centers.size() > 1


## A copy as it is now (an intro's demo plays on one, never on the run's own hole).
func copy() -> StarGravity:
	var twin := StarGravity.new(center, horizon, pull, max_step, hunger, max_horizon)
	twin.centers = centers.duplicate()
	twin.horizons = horizons.duplicate()
	twin.drift = drift
	twin.merge_horizon = merge_horizon
	return twin


## The hole swallowed `count` stars: a hungry one grows (up to max_horizon). Returns how much.
func feed(count: int) -> int:
	var before: int = horizon
	horizon = mini(horizon + hunger * count, max_horizon)
	return horizon - before


## Where the holes will be once the next launch has resolved: each a drift on, or the one they merge
## into (at the middle). One hole stays where it is.
func next_centers() -> Array[Vector2i]:
	if not has_twins():
		return centers.duplicate()
	if merges_next():
		return [merge_point()]
	var way: Vector2 = Vector2(centers[1] - centers[0]).normalized()
	return [centers[0] + Vector2i((way * drift).round()), centers[1] - Vector2i((way * drift).round())]


## Whether the next drift merges the twins (their horizons would touch).
func merges_next() -> bool:
	if not has_twins():
		return false
	return Vector2(centers[0]).distance_to(Vector2(centers[1])) - 2 * drift <= horizons[0] + horizons[1]


## Where the twins meet: the middle of the line between them.
func merge_point() -> Vector2i:
	return (centers[0] + centers[1]) / 2 if has_twins() else center


## How many launches until the twins merge (0: no twins).
func launches_to_merge() -> int:
	if not has_twins() or drift <= 0:
		return 0
	var gap: float = Vector2(centers[0]).distance_to(Vector2(centers[1]))
	var launches: int = 1
	while gap - 2 * drift > horizons[0] + horizons[1]:
		gap -= 2 * drift
		launches += 1
	return launches


## A launch resolved: the twins drift toward each other, or merge. Returns true when they merged.
func drift_holes() -> bool:
	if not has_twins() or drift <= 0:
		return false
	var merging: bool = merges_next()
	var next: Array[Vector2i] = next_centers()
	centers = next
	if merging:
		horizons = [merge_horizon]
	return merging


## The hole nearest `point` (by the gap to its horizon).
func nearest(point: Vector2i) -> int:
	var best: int = 0
	var gap: float = INF
	for i: int in centers.size():
		var d: float = Vector2(point).distance_to(Vector2(centers[i])) - horizons[i]
		if d < gap:
			gap = d
			best = i
	return best


## How far a star at `point` falls on a launch (0 at a hole itself, or with no pull).
func step_at(point: Vector2i) -> int:
	var distance: float = Vector2(point).distance_to(Vector2(centers[nearest(point)]))
	if distance <= 0.0 or pull <= 0:
		return 0
	return clampi(roundi(pull / distance), 1, max_step)


## Whether a star at `point` is inside a horizon (swallowed).
func inside(point: Vector2i) -> bool:
	for i: int in centers.size():
		if point.distance_squared_to(centers[i]) <= horizons[i] * horizons[i]:
			return true
	return false


## How many falls a lone star `distance` px out from the first hole takes to be swallowed, straight
## in and unblocked (the hole not growing), at most `limit` (more: limit + 1).
func pulls_to_swallow(distance: int, limit: int = 8) -> int:
	var r: float = distance
	for k: int in range(1, limit + 1):
		if pull <= 0:
			break
		var step: int = clampi(roundi(pull / r), 1, max_step) if r > 0.0 else 0
		if r - step <= horizon:
			return k
		r -= step
	return limit + 1


## Whether a star at `point` falls past its hole's horizon on its next fall.
func swallows_at(point: Vector2i) -> bool:
	var hole: int = nearest(point)
	var distance: float = Vector2(point).distance_to(Vector2(centers[hole]))
	return pull > 0 and distance - step_at(point) <= horizons[hole]


## Snapshot membership; nearest a hole first; one fall each. A star a hole swallows frees its spot
## for the stars behind it. A blocked star (another star or a landmark too close to where it would
## land) flows round it or falls as far as it can; only a star with no room at all stays put, so
## stars are never squeezed together. Reserved stars keep their reserved destination.
func preview(stars: Array[Star], sky: Rect2i, landmarks: Array[Vector2i], reserved: Dictionary[int, Vector2i] = {}) -> Dictionary[int, Vector2i]:
	var destinations: Dictionary[int, Vector2i] = {}
	var gone: Dictionary[int, bool] = {}
	for star: Star in stars:
		destinations[star.id] = reserved.get(star.id, star.position)
		if swallowed(destinations[star.id]):
			gone[star.id] = true
	var ordered: Array[Star] = stars.duplicate()
	ordered.sort_custom(_nearest_first)
	for star: Star in ordered:
		if reserved.has(star.id):
			continue
		destinations.erase(star.id)
		if swallows_at(star.position):
			gone[star.id] = true
			destinations[star.id] = centers[nearest(star.position)]
		else:
			destinations[star.id] = _fall_to(star.position, sky, destinations, gone, landmarks)
	return destinations


func falls(stars: Array[Star], destinations: Dictionary[int, Vector2i]) -> Array[Fall]:
	var result: Array[Fall] = []
	for star: Star in stars:
		var to: Vector2i = destinations.get(star.id, star.position)
		if star.position != to or swallowed(to):
			result.append(Fall.new(star.id, star.position, to, swallowed(to)))
	return result


## Whether a star whose fall ends at `to` was swallowed (it ends in a hole).
func swallowed(to: Vector2i) -> bool:
	return centers.has(to)


func _gap(point: Vector2i) -> int:
	return point.distance_squared_to(centers[nearest(point)])


func _nearest_first(a: Star, b: Star) -> bool:
	var da: int = _gap(a.position)
	var db: int = _gap(b.position)
	return a.id < b.id if da == db else da < db


## Where a star at `from` can fall: its full step, else round what's in the way at the same
## distance, else the furthest spot along its fall (or round it) with room, else nowhere.
func _fall_to(from: Vector2i, sky: Rect2i, occupied: Dictionary[int, Vector2i], gone: Dictionary[int, bool], landmarks: Array[Vector2i]) -> Vector2i:
	var hole: Vector2i = centers[nearest(from)]
	var way: Vector2 = Vector2(hole - from).normalized()
	var across := Vector2(-way.y, way.x)
	var reach: int = from.distance_squared_to(hole)
	for k: int in range(step_at(from), 0, -1):
		for offset: int in [0] + SIDESTEPS:
			var spot: Vector2i = StarScatter.clamp_to_sky(Vector2i((Vector2(from) + way * k + across * offset).round()), sky)
			if spot == from or spot.distance_squared_to(hole) >= reach or inside(spot):
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
