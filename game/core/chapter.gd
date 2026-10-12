class_name Chapter
extends RefCounted
## A chapter (#62): a constellation split into stages (its ChapterDef: Scorpio, Aquarius...).
## Each part stage is its own small "false constellation" shaped like that part (StarMap); winning
## it lights its group of stars on the chapter chart. The final stage is the full constellation
## (for Scorpio, Orion's boss stage, StarMap.final). Only stages whose map is built can be played
## (no empty stages to fill the chart); completing a part unlocks the next one, and winning the
## fifth part unlocks the final (complete() returns FINAL, so the chart plays its unlock).
## Completed stages can be replayed. Every chapter has five parts and a final.
## Pure state, separate from the constellation built inside a stage. Saved as a Dictionary
## (to_save / from_save) by ProgressStore, under the chapter's id.
## For testing (the web build's ?all): with all_open, every built stage can be played at once;
## wins still count and save as usual.

enum PointState { LOCKED, AVAILABLE, COMPLETED }

## The final stage, after the five parts: the full constellation.
const FINAL: int = 5

## The chapter's stages, figure and chart (ChapterDef).
var def: ChapterDef
## Its saved progress's key (ProgressStore).
var id: String:
	get:
		return def.id
## Every built stage is playable, won or not (testing: the web build's ?all).
var all_open: bool = false
var _completed: Array[bool] = []
## Which stages have a map (tests may build more).
var _built: Array[bool] = []


## `p_def`: the chapter (Scorpio unless given).
func _init(p_def: ChapterDef = null) -> void:
	def = p_def if p_def != null else ChapterDef.scorpio()
	assert(def.stages.size() == FINAL + 1, "every chapter has five parts and a final")
	for stage: Dictionary in def.stages:
		_completed.append(false)
		_built.append(stage["map"] != "")


## The same for every chapter: five parts and a final.
static func stage_count() -> int:
	return FINAL + 1


func stage_name(stage: int) -> String:
	return def.stages[stage]["name"]


## The StarMap id stage `stage` plays, or "" while it isn't built.
func map_id(stage: int) -> String:
	return def.stages[stage]["map"] if _built[stage] else ""


static func is_final(stage: int) -> bool:
	return stage == FINAL


## The chart stars stage `stage` owns (empty for the final: it's the whole figure).
func stars(stage: int) -> Array[int]:
	var found: Array[int] = []
	found.assign(def.stages[stage]["stars"])
	return found


## The part stage that owns chart star `landmark`, or -1.
func stage_of(landmark: int) -> int:
	for stage: int in def.stages.size():
		if (def.stages[stage]["stars"] as Array).has(landmark):
			return stage
	return -1


## Tests (and a stage coming online) can mark a stage built.
func set_built(stage: int, built: bool) -> void:
	_built[stage] = built


func has_stage(stage: int) -> bool:
	return stage >= 0 and stage < stage_count() and _built[stage]


func is_completed(stage: int) -> bool:
	return _completed[stage]


## Playable now: its map exists, and it's the first part, or the part before it is won; the final
## once every part is won.
func is_available(stage: int) -> bool:
	if not has_stage(stage):
		return false
	if all_open:
		return true
	if is_final(stage):
		return parts_done()
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
	for stage: int in stage_count():
		if is_available(stage) and not _completed[stage]:
			return stage
	for stage: int in range(stage_count() - 1, -1, -1):
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
	if is_available(next) and not _completed[next]:
		return next
	return -1


func to_save() -> Dictionary:
	var done: Array[int] = []
	for stage: int in stage_count():
		if _completed[stage]:
			done.append(stage)
	return {"completed": done}


## Reads a save. Anything unreadable, out of range or out of order is dropped: a part counts as
## won only if every part before it is, and only stages that can be played count.
func from_save(data: Dictionary) -> void:
	for stage: int in stage_count():
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


## Every part stage is won (the final is open).
func parts_done() -> bool:
	for stage: int in FINAL:
		if not _completed[stage]:
			return false
	return true
