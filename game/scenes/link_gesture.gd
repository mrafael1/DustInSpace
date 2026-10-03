class_name LinkGesture
extends RefCounted
## Turns one pointer's press, drag and release into a star selection and link requests.
## Pure input handling on the 180x320 grid: no nodes, and no combo rules. Whether a link is
## valid is up to RunState.link(); this only decides which stars the player meant.
##
## - Press a star to select it (up to 3). Drag from a star to add every star the pointer crosses,
##   including ones between two drag samples.
## - Releasing with 3 selected requests the link, whichever way they were picked.
## - Releasing a drag that added stars but has fewer than 3 still requests it, so the run
##   rejects it and the player sees why. Nothing is used up.
## - Cancel (web playtest: a wrong link was gone the moment the finger lifted):
##   - Dragging back onto the star before the last drops the last one, so a drag can be retraced.
##   - With 3 selected, a drag released away from the last star (off it, and more than
##     CANCEL_DISTANCE from where the pointer last was on it) drops the whole selection and requests
##     nothing: link_cancelled. With fewer, the pointer is still looking for the next star, so a
##     release anywhere requests as above.
## - Tap a selected star to drop it. Tap empty sky to cancel the selection.
## - With `can_join` set, a star it refuses isn't added: join_refused says which, once per contact.

signal selection_changed(star_ids: Array[int])
signal link_requested(star_ids: Array[int])
## A star couldn't join the selection (can_join said no). Nothing changed.
signal join_refused(star_ids: Array[int], star_id: int)
## A drag with 3 selected was released away from its last star: the selection was dropped, nothing
## requested.
signal link_cancelled

## A press that moves further than this (native px) is a drag, not a tap.
const DRAG_THRESHOLD: int = 4
## A full drag released further than this (native px) from where the pointer was last on its last
## star, and off that star, lets the link go. Far enough that a swipe overshooting it still links.
const CANCEL_DISTANCE: int = 16

var selected: Array[int] = []
## Whether a star may join the selection: `func(selected: Array[int], id: int) -> bool`. Unset: any.
var can_join: Callable

## Returns the id of the star under a point, or 0 for none. `func(point: Vector2i) -> int`.
var _star_at: Callable
var _down: bool = false
var _moved: bool = false
var _press_point: Vector2i = Vector2i.ZERO
## The previous drag sample. Drags arrive once per frame, so a fast swipe jumps between samples.
var _last_point: Vector2i = Vector2i.ZERO
## Star under the press, or 0.
var _press_star: int = 0
var _press_was_selected: bool = false
var _added_by_drag: bool = false
## The star last refused while the pointer stays on it, so a drag over it refuses it once.
var _refused: int = 0
## Where the pointer was last on the last selected star.
var _on_last_at: Vector2i = Vector2i.ZERO


func _init(star_at: Callable) -> void:
	_star_at = star_at


func is_pressed() -> bool:
	return _down


## True while the pointer is down on a drag that started on a star (the line follows the finger).
func is_dragging() -> bool:
	return _down and _moved and _press_star != 0


## True while lifting the finger now would cancel the link (the drag has left its last star).
func is_letting_go() -> bool:
	return is_dragging() and _lets_go(_last_point)


## Returns true if the press was used (it landed on a star).
func press(point: Vector2i) -> bool:
	_down = true
	_moved = false
	_added_by_drag = false
	_press_point = point
	_last_point = point
	_refused = 0
	_press_star = _star_at.call(point)
	_press_was_selected = selected.has(_press_star)
	if _press_star != 0 and not _press_was_selected:
		_select(_press_star, point)
	elif _press_star != 0 and selected[-1] == _press_star:
		_on_last_at = point
	return _press_star != 0


## Picks up every star along the path from the previous sample, in the order it's crossed.
func drag(point: Vector2i) -> void:
	if not _down:
		return
	if not _moved and Vector2(point - _press_point).length() > DRAG_THRESHOLD:
		_moved = true
	var from: Vector2i = _last_point
	_last_point = point
	if not is_dragging():
		return
	for p: Vector2i in LinkLayer.line_pixels(from, point):
		# A listener may drop the link as a star joins it (cancel): then the drag is over.
		if not _down:
			return
		var id: int = _star_at.call(p)
		if id != _refused:
			_refused = 0
		if id != 0 and not selected.is_empty() and id == selected[-1]:
			_on_last_at = p
		elif id != 0 and selected.size() > 1 and id == selected[-2]:
			_retrace(p)
		elif id != 0 and not selected.has(id) and _select(id, p):
			_added_by_drag = true


## Returns true if the release was used: it changed the selection or requested a link.
func release(point: Vector2i) -> bool:
	if not _down:
		return false
	_down = false
	if _moved:
		return _release_drag(point)
	return _release_tap()


## Drops the selection and any press in progress, e.g. when a sequence takes the input.
func cancel() -> void:
	_down = false
	_moved = false
	_press_star = 0
	_refused = 0
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


func _release_drag(point: Vector2i) -> bool:
	if _press_star == 0:
		return false
	if _lets_go(point):
		cancel()
		link_cancelled.emit()
		return true
	if selected.size() == Combos.LINK_LENGTH or (_added_by_drag and selected.size() > 1):
		_request()
	return true


func _select(id: int, at: Vector2i) -> bool:
	if selected.size() >= Combos.LINK_LENGTH:
		return false
	if can_join.is_valid() and not can_join.call(selected.duplicate(), id):
		if id != _refused:
			_refused = id
			join_refused.emit(selected.duplicate(), id)
		return false
	selected.append(id)
	_on_last_at = at
	selection_changed.emit(selected.duplicate())
	return true


## The drag came back onto the star before the last: the last one is dropped.
func _retrace(at: Vector2i) -> void:
	selected.pop_back()
	_on_last_at = at
	selection_changed.emit(selected.duplicate())


func _lets_go(point: Vector2i) -> bool:
	if selected.size() < Combos.LINK_LENGTH:
		return false
	return _star_at.call(point) != selected[-1] and Vector2(point - _on_last_at).length() > CANCEL_DISTANCE


func _request() -> void:
	var ids: Array[int] = selected.duplicate()
	selected.clear()
	selection_changed.emit(selected.duplicate())
	link_requested.emit(ids)
