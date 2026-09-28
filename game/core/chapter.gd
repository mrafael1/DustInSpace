class_name Chapter
extends RefCounted
## A chapter (#62): a constellation whose stars are stage points, travelled from the tail. Scorpio
## is the first: its route starts at the stinger (Shaula) and climbs the tail, the body and the
## heart to the head, then the two claws. Each point is a stage; only the first `playable` points
## have a stage built (no empty stages to fill the chart). Completing a stage unlocks the next
## point along the route, if its stage exists. Completed stages can be replayed.
## Pure state, separate from the constellation built inside a stage. Saved as a Dictionary
## (to_save / from_save) by ProgressStore.

enum PointState { LOCKED, AVAILABLE, COMPLETED }

const ID: String = "scorpio"
## The route, as Scorpio landmark indices: stinger first, along the tail and body to the head, then
## the claws (beta, then pi, reached back through the head).
const ROUTE: Array[int] = [13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 1, 0, 2]
## Stages built so far, from the tail (#63: the current map is stage 1; #64 adds stage 2).
const STAGES_BUILT: int = 1

## How many points along the route have a stage (the first `playable`).
var playable: int = STAGES_BUILT
var _completed: Array[bool] = []


func _init(p_playable: int = STAGES_BUILT) -> void:
	playable = p_playable
	for i: int in ROUTE.size():
		_completed.append(false)


static func point_count() -> int:
	return ROUTE.size()


## The name shown for route point `point`'s stage.
static func stage_name(point: int) -> String:
	return "STAGE %d" % (point + 1)


## The Scorpio landmark stage point `point` sits on.
static func landmark(point: int) -> int:
	return ROUTE[point]


func has_stage(point: int) -> bool:
	return point >= 0 and point < playable


func is_completed(point: int) -> bool:
	return _completed[point]


## Playable now: its stage exists, and it's the first or the one before it is complete.
func is_available(point: int) -> bool:
	return has_stage(point) and (point == 0 or _completed[point - 1])


func state(point: int) -> PointState:
	if _completed[point]:
		return PointState.COMPLETED
	if is_available(point):
		return PointState.AVAILABLE
	return PointState.LOCKED


func completed_count() -> int:
	return _completed.count(true)


## The point to play next: the first available one not yet completed, else the last completed
## (everything built is done), else 0.
func current() -> int:
	for point: int in ROUTE.size():
		if is_available(point) and not _completed[point]:
			return point
	for point: int in range(ROUTE.size() - 1, -1, -1):
		if _completed[point]:
			return point
	return 0


## A stage was won. Returns the point it unlocked (the next along the route, if its stage exists),
## or -1. Winning a stage that isn't available changes nothing.
func complete(point: int) -> int:
	if not is_available(point):
		return -1
	var was: bool = _completed[point]
	_completed[point] = true
	if not was and has_stage(point + 1):
		return point + 1
	return -1


func to_save() -> Dictionary:
	var done: Array[int] = []
	for point: int in ROUTE.size():
		if _completed[point]:
			done.append(point)
	return {"completed": done}


## Reads a save. Anything unreadable, out of range or out of order (a gap) is dropped: a point
## counts as completed only if every point before it is.
func from_save(data: Dictionary) -> void:
	for point: int in ROUTE.size():
		_completed[point] = false
	var saved: Variant = data.get("completed", [])
	if not saved is Array:
		return
	var done: Dictionary = {}
	for value: Variant in saved:
		if (value is int or value is float) and int(value) == value:
			done[int(value)] = true
	for point: int in mini(ROUTE.size(), playable):
		if not done.has(point):
			return
		_completed[point] = true


## The landmarks a traveller passes between two points, both ends included, along the strings.
static func path(from_point: int, to_point: int) -> Array[int]:
	return Scorpio.landmark_path(landmark(from_point), landmark(to_point))
