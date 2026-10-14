class_name StarSplash
extends RefCounted
## Pisces's splash (chapter 6): a thrown planet sinking into the mirror splashes where it went in (a
## split planet's twins, each where it is), pushing the loose stars round that point outward; a star
## pushed out of the sky, or onto or across the mirror's water line, is lost, for nothing. No randomness, nodes or rewards. Its moves are StarCurrent.Moves (a lost one `drained`,
## `to` where it would have gone, past the sky's edge).

var radius: int
var push: int
## Where a push from a point to another first meets the water line: Callable(from: Vector2i, to:
## Vector2i) -> Vector2i, StarCords.NO_CROSSING when it doesn't (crossing it, or ending on it). Unset:
## no water line.
var seam_hit: Callable


## `p_radius`: how far from where the planet went in the splash reaches. `p_push`: how far it pushes
## a star it reaches.
func _init(p_radius: int, p_push: int, p_seam_hit: Callable = Callable()) -> void:
	radius = p_radius
	push = p_push
	seam_hit = p_seam_hit


## Whether `point` is one the splash reaches, splashing at `at`.
func reaches(at: Vector2i, point: Vector2i) -> bool:
	return at.distance_squared_to(point) <= radius * radius


## Pure: where each star the splash at `at` moves ends up (stars it doesn't move are left out). Each
## star it reaches is pushed `push` px straight away from `at` (one right on it: straight up); one
## pushed past the sky's edge is lost (its destination past that edge), and so is one pushed onto or
## across the water line (its destination where it meets the line), whatever is in its way. The farthest go first, so
## the stars behind follow into the room; a star blocked by another, or by a landmark, goes as far
## along its way as it has room for, else stays.
func preview(at: Vector2i, stars: Array[Star], sky: Rect2i, landmarks: Array[Vector2i]) -> Dictionary[int, Vector2i]:
	var destinations: Dictionary[int, Vector2i] = {}
	var occupied: Dictionary[int, Vector2i] = {}
	var reached: Array[Star] = []
	for star: Star in stars:
		occupied[star.id] = star.position
		if reaches(at, star.position):
			reached.append(star)
	reached.sort_custom(func(a: Star, b: Star) -> bool:
		var da: int = at.distance_squared_to(a.position)
		var db: int = at.distance_squared_to(b.position)
		return a.id < b.id if da == db else da > db)
	for star: Star in reached:
		var way: Vector2 = Vector2(star.position - at).normalized() if star.position != at else Vector2.UP
		var wanted: Vector2i = star.position + Vector2i((way * push).round())
		var hit: Vector2i = _hit(star.position, wanted)
		if hit != StarCords.NO_CROSSING:
			destinations[star.id] = hit
			occupied.erase(star.id)
			continue
		if leaves(wanted, sky):
			destinations[star.id] = wanted
			occupied.erase(star.id)
			continue
		var to: Vector2i = star.position
		for k: int in range(push, 0, -1):
			var spot: Vector2i = star.position + Vector2i((way * k).round())
			if spot != star.position and _has_room(star.id, spot, occupied, landmarks):
				to = spot
				break
		if to != star.position:
			destinations[star.id] = to
			occupied[star.id] = to
	return destinations


## The moves `destinations` (a preview) make, in the stars' order.
func moves(stars: Array[Star], destinations: Dictionary[int, Vector2i], sky: Rect2i) -> Array[StarCurrent.Move]:
	var result: Array[StarCurrent.Move] = []
	for star: Star in stars:
		if destinations.has(star.id):
			var to: Vector2i = destinations[star.id]
			result.append(StarCurrent.Move.new(star.id, star.position, to, loses(star.position, to, sky)))
	return result


## Whether a star pushed from `from` to `to` is lost: out of the sky, or onto or across the water line.
func loses(from: Vector2i, to: Vector2i, sky: Rect2i) -> bool:
	return leaves(to, sky) or (from != to and _hit(from, to) != StarCords.NO_CROSSING)


func _hit(from: Vector2i, to: Vector2i) -> Vector2i:
	if not seam_hit.is_valid():
		return StarCords.NO_CROSSING
	return seam_hit.call(from, to)


## Whether a star pushed to `point` has left the sky (where stars live: StarScatter.inner_rect).
static func leaves(point: Vector2i, sky: Rect2i) -> bool:
	return not StarScatter.inner_rect(sky).has_point(point)


static func _has_room(id: int, point: Vector2i, occupied: Dictionary[int, Vector2i], landmarks: Array[Vector2i]) -> bool:
	for other: int in occupied:
		if other != id and point.distance_squared_to(occupied[other]) < StarScatter.MIN_SPACING * StarScatter.MIN_SPACING:
			return false
	for landmark: Vector2i in landmarks:
		if point.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return false
	return true
