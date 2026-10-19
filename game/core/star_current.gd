class_name StarCurrent
extends RefCounted
## One launch-driven flow. No randomness, nodes or rewards. Existing destinations can be
## reserved before a burst, so newly arriving stars never invalidate the aiming preview.
## A draining flow loses every star it carries out of its field: it pays nothing.
## A turning flow (a tide, a rotating box) runs each way in `turns` in order, one launch each:
## turn() moves it on once a launch has resolved, so the aim always previews the flow it will get.
## A draining flow with a frame (a wide sky's: RunState.frame_rect) also loses every star outside
## its frame at its next step, and any it would carry out of it (docs/wide_sky_design.md, Q4): the
## sky beyond the frame's sides is as lost as beyond a phone's edge. On a 9:16 sky the frame is the
## sky, so this never happens.

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

## A blocked star flows round what's in its way like water: at its full step, then at each shorter
## one, it tries straight on, then shifted this far across the flow (nearest first, alternating
## sides).
const SIDESTEPS: Array[int] = [4, -4, 8, -8, 12, -12, 16, -16]

var region: Rect2i
## This launch's flow: its way times its step.
var displacement: Vector2i
var drains: bool
## The ways a turning flow takes, in order (empty: it always runs one way).
var turns: Array[Vector2i] = []
## The frame a draining flow keeps its stars in (no area: none, the sky's edge is the only one).
var frame: Rect2i = Rect2i()
var _turn: int = 0
var _step: int = 0


## `step`: the first launch's flow. `p_turns`: the ways it takes after each launch, from the first
## (its length is the step's).
func _init(area: Rect2i, step: Vector2i, p_drains: bool = false, p_turns: Array[Vector2i] = []) -> void:
	region = area
	displacement = step
	drains = p_drains
	turns = p_turns
	_step = maxi(absi(step.x), absi(step.y))
	if not turns.is_empty():
		displacement = turns[0] * _step


## A launch resolved: a turning flow takes its next way.
func turn() -> void:
	if turns.size() < 2:
		return
	_turn = (_turn + 1) % turns.size()
	displacement = turns[_turn] * _step


## The way the flow runs after this launch's (the same, unless it turns).
func next_way() -> Vector2i:
	if turns.size() < 2:
		return Vector2i(signi(displacement.x), signi(displacement.y))
	return turns[(_turn + 1) % turns.size()]


## Every way this flow ever runs (one, or each of its turns).
func ways() -> Array[Vector2i]:
	if turns.is_empty():
		return [Vector2i(signi(displacement.x), signi(displacement.y))]
	return turns


## Snapshot membership; downstream first; one step. A star whose step is blocked (another star or
## a landmark too close to where it would land) flows round it (SIDESTEPS) or goes as far as it can;
## only a star with no room at all stays put, so stars are never squeezed together.
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
		if reserved.has(star.id):
			continue
		if stranded(star.position):
			destinations[star.id] = off_frame(star.position)
			continue
		if not region.has_point(star.position):
			continue
		var wanted: Vector2i = StarScatter.clamp_to_sky(star.position + displacement, sky)
		destinations.erase(star.id)
		if leaves(star.position, wanted):
			gone[star.id] = true
			destinations[star.id] = wanted
		else:
			destinations[star.id] = _flow_to(star.position, wanted, sky, destinations, gone, landmarks)
	return destinations


func moves(stars: Array[Star], destinations: Dictionary[int, Vector2i]) -> Array[Move]:
	var result: Array[Move] = []
	for star: Star in stars:
		var to: Vector2i = destinations.get(star.id, star.position)
		if star.position != to:
			result.append(Move.new(star.id, star.position, to, leaves(star.position, to)))
	return result


## Whether a star moving from `from` to `to` is carried out of a draining field, or past its frame's
## sides (and lost). A star already outside the frame is lost wherever it goes (stranded).
func leaves(from: Vector2i, to: Vector2i) -> bool:
	if stranded(from):
		return true
	return drains and from != to and region.has_point(from) and (not region.has_point(to) or (frame.has_area() and not frame.has_point(to)))


## Whether a star at `at` stands outside a draining flow's frame: its next step drains it, in the
## flow or not (a wide sky's outer columns; never on a 9:16 sky, whose frame is the sky).
func stranded(at: Vector2i) -> bool:
	return drains and frame.has_area() and not frame.has_point(at)


## The way out of the frame from `at` (left of it: left; else right).
func outward(at: Vector2i) -> Vector2i:
	return Vector2i.LEFT if at.x < frame.get_center().x else Vector2i.RIGHT


## Where a stranded star at `at` goes: a step further out from the frame (the flow's step, or one
## px), where it leaves the sky.
func off_frame(at: Vector2i) -> Vector2i:
	return at + outward(at) * maxi(_step, 1)


## Vacate downstream positions before upstream stars try to follow. Creation age is only
## a tie-break at the same distance along the flow, never the order of a moving cluster.
func _downstream_first(a: Star, b: Star) -> bool:
	var along_a: int = a.position.x * displacement.x + a.position.y * displacement.y
	var along_b: int = b.position.x * displacement.x + b.position.y * displacement.y
	return a.id < b.id if along_a == along_b else along_a > along_b


## Where a star at `from` that wants `wanted` can go: there, else round what's in the way at the
## same distance, else the furthest spot along its path (or round it) with room, else nowhere.
func _flow_to(from: Vector2i, wanted: Vector2i, sky: Rect2i, occupied: Dictionary[int, Vector2i], gone: Dictionary[int, bool], landmarks: Array[Vector2i]) -> Vector2i:
	if _has_room(wanted, occupied, gone, landmarks):
		return wanted
	var across := Vector2i(signi(-displacement.y), signi(displacement.x))
	var length: int = maxi(absi(displacement.x), absi(displacement.y))
	for k: int in range(length, 0, -1):
		for offset: int in [0] + SIDESTEPS:
			var spot: Vector2i = StarScatter.clamp_to_sky(from + displacement * k / length + across * offset, sky)
			if spot != from and not leaves(from, spot) and _has_room(spot, occupied, gone, landmarks):
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
