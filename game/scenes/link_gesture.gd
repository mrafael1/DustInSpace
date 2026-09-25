class_name LinkGesture
extends RefCounted
## Turns one pointer's press, drag and release into a star selection and link requests.
## Pure input handling on the 180x320 grid: no nodes, and no combo rules. Whether a link is
## valid is up to RunState.link(); this only decides which stars the player meant.
##
## - Press a star to select it (up to 3). Drag from a star to add every star the pointer crosses.
## - Releasing with 3 selected requests the link, whichever way they were picked.
## - Releasing a drag that added stars but has fewer than 3 still requests it, so the run
##   rejects it and the player sees why. Nothing is used up.
## - Tap a selected star to drop it. Tap empty sky to cancel the selection.

signal selection_changed(star_ids: Array[int])
signal link_requested(star_ids: Array[int])

## A press that moves further than this (native px) is a drag, not a tap.
const DRAG_THRESHOLD: int = 4

var selected: Array[int] = []

## Returns the id of the star under a point, or 0 for none. `func(point: Vector2i) -> int`.
var _star_at: Callable
var _down: bool = false
var _moved: bool = false
var _press_point: Vector2i = Vector2i.ZERO
## Star under the press, or 0.
var _press_star: int = 0
var _press_was_selected: bool = false
var _added_by_drag: bool = false


func _init(star_at: Callable) -> void:
	_star_at = star_at


func is_pressed() -> bool:
	return _down


## True while the pointer is down on a drag that started on a star (the line follows the finger).
func is_dragging() -> bool:
	return _down and _moved and _press_star != 0


## Returns true if the press was used (it landed on a star).
func press(point: Vector2i) -> bool:
	_down = true
	_moved = false
	_added_by_drag = false
	_press_point = point
	_press_star = _star_at.call(point)
	_press_was_selected = selected.has(_press_star)
	if _press_star != 0 and not _press_was_selected:
		_select(_press_star)
	return _press_star != 0


func drag(point: Vector2i) -> void:
	if not _down:
		return
	if not _moved and Vector2(point - _press_point).length() > DRAG_THRESHOLD:
		_moved = true
	if not is_dragging():
		return
	var id: int = _star_at.call(point)
	if id != 0 and not selected.has(id) and _select(id):
		_added_by_drag = true


## Returns true if the release was used: it changed the selection or requested a link.
func release(_point: Vector2i) -> bool:
	if not _down:
		return false
	_down = false
	if _moved:
		return _release_drag()
	return _release_tap()


## Drops the selection and any press in progress, e.g. when a sequence takes the input.
func cancel() -> void:
	_down = false
	_moved = false
	_press_star = 0
	if not selected.is_empty():
		selected.clear()
		selection_changed.emit(selected.duplicate())


func _release_tap() -> bool:
	if _press_star == 0:
		if selected.is_empty():
			return false
		cancel()
		return true
	if _press_was_selected:
		selected.erase(_press_star)
		selection_changed.emit(selected.duplicate())
		return true
	if selected.size() == Combos.LINK_LENGTH:
		_request()
	return true


func _release_drag() -> bool:
	if _press_star == 0:
		return false
	if selected.size() == Combos.LINK_LENGTH or (_added_by_drag and selected.size() > 1):
		_request()
	return true


func _select(id: int) -> bool:
	if selected.size() >= Combos.LINK_LENGTH:
		return false
	selected.append(id)
	selection_changed.emit(selected.duplicate())
	return true


func _request() -> void:
	var ids: Array[int] = selected.duplicate()
	selected.clear()
	selection_changed.emit(selected.duplicate())
	link_requested.emit(ids)
