class_name Chapter
extends RefCounted
## A chapter (#62): Scorpio split into stages, travelled from the tail. Each part stage (Stinger,
## Tail, Body, Heart, Claws) is its own small "false constellation" shaped like that part
## (StarMap); winning it lights its group of stars on the chapter chart. The final stage is the
## full Scorpio. Only stages whose map is built can be played (no empty stages to fill the chart);
## completing a part unlocks the next one. While the parts are still being built the final is
## open for playtesting (FINAL_OPEN); after that it opens once every part is won. Completed
## stages can be replayed.
## Pure state, separate from the constellation built inside a stage. Saved as a Dictionary
## (to_save / from_save) by ProgressStore.

enum PointState { LOCKED, AVAILABLE, COMPLETED }

const ID: String = "scorpio"
## The stages, from the tail. `stars`: the chart stars (Scorpio landmark indices) the stage owns,
## the first one its point on the chart; `map`: its StarMap id, or "" while it isn't built.
const STAGES: Array[Dictionary] = [
	{"name": "STINGER", "map": "stinger", "stars": [13, 12, 11]},
	{"name": "TAIL", "map": "tail", "stars": [10, 9, 8]},
	{"name": "BODY", "map": "body", "stars": [7, 6, 5]},
	{"name": "HEART", "map": "", "stars": [4, 3]},
	{"name": "CLAWS", "map": "", "stars": [1, 0, 2]},
	{"name": "SCORPIO", "map": "scorpio", "stars": []},
]
## The final stage: the full Scorpio.
const FINAL: int = 5
## While the part stages are being built, the final can be played from the start (playtesting).
const FINAL_OPEN: bool = true

var _completed: Array[bool] = []
## Which stages have a map (tests may build more).
var _built: Array[bool] = []


func _init() -> void:
	for stage: Dictionary in STAGES:
		_completed.append(false)
		_built.append(stage["map"] != "")


static func stage_count() -> int:
	return STAGES.size()


static func stage_name(stage: int) -> String:
	return STAGES[stage]["name"]


## The StarMap id stage `stage` plays, or "" while it isn't built.
func map_id(stage: int) -> String:
	return STAGES[stage]["map"] if _built[stage] else ""


static func is_final(stage: int) -> bool:
	return stage == FINAL


## The chart stars stage `stage` owns (empty for the final: it's the whole figure).
static func stars(stage: int) -> Array[int]:
	var found: Array[int] = []
	found.assign(STAGES[stage]["stars"])
	return found


## The part stage that owns chart star `landmark`, or -1.
static func stage_of(landmark: int) -> int:
	for stage: int in STAGES.size():
		if (STAGES[stage]["stars"] as Array).has(landmark):
			return stage
	return -1


## Tests (and a stage coming online) can mark a stage built.
func set_built(stage: int, built: bool) -> void:
	_built[stage] = built


func has_stage(stage: int) -> bool:
	return stage >= 0 and stage < STAGES.size() and _built[stage]


func is_completed(stage: int) -> bool:
	return _completed[stage]


## Playable now: its map exists, and it's the first part, or the part before it is won; the final
## once every part is won (or from the start while FINAL_OPEN).
func is_available(stage: int) -> bool:
	if not has_stage(stage):
		return false
	if is_final(stage):
		return FINAL_OPEN or _parts_done()
	return stage == 0 or _completed[stage - 1]


func state(stage: int) -> PointState:
	if _completed[stage]:
		return PointState.COMPLETED
	if is_available(stage):
		return PointState.AVAILABLE
	return PointState.LOCKED


func completed_count() -> int:
	return _completed.count(true)


## The stage to play next: the first part available and not yet won, else the final if it is,
## else the last won, else 0.
func current() -> int:
	for stage: int in STAGES.size():
		if is_available(stage) and not _completed[stage]:
			return stage
	for stage: int in range(STAGES.size() - 1, -1, -1):
		if _completed[stage]:
			return stage
	return 0


## A stage was won. Returns the stage it opened (the next part, or the final once every part is
## won), or -1. Winning a stage that isn't available changes nothing.
func complete(stage: int) -> int:
	if not is_available(stage):
		return -1
	var was: bool = _completed[stage]
	_completed[stage] = true
	if was or is_final(stage):
		return -1
	var next: int = stage + 1
	if is_available(next) and not _completed[next] and (not is_final(next) or not FINAL_OPEN):
		return next
	return -1


func to_save() -> Dictionary:
	var done: Array[int] = []
	for stage: int in STAGES.size():
		if _completed[stage]:
			done.append(stage)
	return {"completed": done}


## Reads a save. Anything unreadable, out of range or out of order is dropped: a part counts as
## won only if every part before it is, and only stages that can be played count.
func from_save(data: Dictionary) -> void:
	for stage: int in STAGES.size():
		_completed[stage] = false
	var saved: Variant = data.get("completed", [])
	if not saved is Array:
		return
	var done: Dictionary = {}
	for value: Variant in saved:
		if (value is int or value is float) and int(value) == value:
			done[int(value)] = true
	for stage: int in FINAL:
		if not done.has(stage) or not has_stage(stage):
			break
		_completed[stage] = true
	if done.has(FINAL) and is_available(FINAL):
		_completed[FINAL] = true


func _parts_done() -> bool:
	for stage: int in FINAL:
		if not _completed[stage]:
			return false
	return true
