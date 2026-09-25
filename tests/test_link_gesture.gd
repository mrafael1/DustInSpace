extends GutTest
## LinkGesture on its own: stars are ids 1-4 at fixed points, found by a stub hit test.

const STARS: Dictionary[int, Vector2i] = {1: Vector2i(30, 150), 2: Vector2i(90, 150), 3: Vector2i(150, 150), 4: Vector2i(90, 200)}
const EMPTY := Vector2i(90, 100)

var gesture: LinkGesture
var requests: Array[Array] = []


func before_each() -> void:
	gesture = LinkGesture.new(_star_at)
	requests.clear()
	gesture.link_requested.connect(func(ids: Array[int]) -> void: requests.append(ids))


func test_tapping_three_stars_requests_them_in_tap_order() -> void:
	_tap(STARS[3])
	_tap(STARS[1])
	assert_eq(gesture.selected, [3, 1] as Array[int])
	assert_true(requests.is_empty(), "two stars are not a link yet")
	_tap(STARS[2])
	assert_eq(requests, [[3, 1, 2]] as Array[Array])
	assert_true(gesture.selected.is_empty(), "the selection clears once the link is requested")


func test_the_third_press_selects_before_the_release_requests() -> void:
	_tap(STARS[1])
	_tap(STARS[2])
	gesture.press(STARS[3])
	assert_eq(gesture.selected.size(), 3, "three selected while the finger is down: the preview shows")
	assert_true(requests.is_empty())
	gesture.release(STARS[3])
	assert_eq(requests.size(), 1)


func test_dragging_through_three_stars_requests_them() -> void:
	gesture.press(STARS[2])
	_drag_to(STARS[4])
	_drag_to(STARS[1])
	assert_true(gesture.is_dragging())
	assert_eq(gesture.selected, [2, 4, 1] as Array[int])
	gesture.release(STARS[1])
	assert_eq(requests, [[2, 4, 1]] as Array[Array])


func test_a_fast_swipe_picks_every_star_it_crosses() -> void:
	# Drag events arrive once per frame, so a quick swipe jumps 15 px between samples. Passing
	# 9 px below the stars, the swipe crosses each 11 px hit circle along a chord of about 12 px,
	# so no sample lands inside the other two.
	var row: Dictionary[int, Vector2i] = {1: Vector2i(40, 150), 2: Vector2i(70, 150), 3: Vector2i(100, 150)}
	gesture = LinkGesture.new(func(point: Vector2i) -> int:
		for id: int in row:
			if (row[id] - point).length_squared() <= SkyView.HIT_RADIUS * SkyView.HIT_RADIUS:
				return id
		return 0)
	gesture.link_requested.connect(func(ids: Array[int]) -> void: requests.append(ids))
	gesture.press(Vector2i(40, 150))
	for x: int in range(47, 108, 15):
		gesture.drag(Vector2i(x, 159))
	assert_eq(gesture.selected, [1, 2, 3] as Array[int], "the stars are on the path between samples")
	gesture.release(Vector2i(107, 159))
	assert_eq(requests, [[1, 2, 3]] as Array[Array])


func test_a_drag_never_picks_a_fourth_star() -> void:
	gesture.press(STARS[1])
	_drag_to(STARS[2])
	_drag_to(STARS[3])
	_drag_to(STARS[4])
	assert_eq(gesture.selected, [1, 2, 3] as Array[int])


func test_a_drag_can_finish_a_link_started_by_taps() -> void:
	_tap(STARS[1])
	gesture.press(STARS[2])
	_drag_to(STARS[3])
	gesture.release(STARS[3])
	assert_eq(requests, [[1, 2, 3]] as Array[Array])


func test_a_drag_released_short_still_requests_so_the_run_can_reject_it() -> void:
	gesture.press(STARS[1])
	_drag_to(STARS[2])
	_drag_to(EMPTY)
	gesture.release(EMPTY)
	assert_eq(requests, [[1, 2]] as Array[Array])
	assert_true(gesture.selected.is_empty())


func test_a_wobbly_press_on_a_selected_star_keeps_the_selection() -> void:
	_tap(STARS[1])
	_tap(STARS[2])
	gesture.press(STARS[2])
	_drag_to(STARS[2] + Vector2i(6, 0))
	gesture.release(STARS[2] + Vector2i(6, 0))
	assert_true(requests.is_empty(), "the drag added no star, so nothing is requested")
	assert_eq(gesture.selected, [1, 2] as Array[int])


func test_a_small_move_is_still_a_tap() -> void:
	gesture.press(STARS[1])
	gesture.drag(STARS[1] + Vector2i(LinkGesture.DRAG_THRESHOLD, 0))
	assert_false(gesture.is_dragging())


func test_tapping_a_selected_star_drops_it() -> void:
	_tap(STARS[1])
	_tap(STARS[2])
	assert_true(_tap(STARS[1]))
	assert_eq(gesture.selected, [2] as Array[int])


func test_tapping_empty_sky_cancels_the_selection() -> void:
	_tap(STARS[1])
	_tap(STARS[2])
	assert_true(_tap(EMPTY), "the cancel uses the tap")
	assert_true(gesture.selected.is_empty())
	assert_true(requests.is_empty())


func test_tapping_empty_sky_with_nothing_selected_is_not_used() -> void:
	assert_false(_tap(EMPTY), "left for others, e.g. the launcher")


func test_a_drag_from_empty_sky_selects_nothing() -> void:
	gesture.press(EMPTY)
	_drag_to(STARS[1])
	_drag_to(STARS[2])
	assert_false(gesture.release(STARS[2]))
	assert_true(gesture.selected.is_empty())


func test_cancel_drops_the_press_and_the_selection() -> void:
	var changes: Array[Array] = []
	gesture.selection_changed.connect(func(ids: Array[int]) -> void: changes.append(ids))
	_tap(STARS[1])
	gesture.press(STARS[2])
	gesture.cancel()
	assert_false(gesture.is_pressed())
	assert_true(gesture.selected.is_empty())
	assert_eq(changes[-1], [] as Array[int])
	assert_false(gesture.release(STARS[2]), "the release of a cancelled press does nothing")
	assert_true(requests.is_empty())


func test_selection_changes_are_reported_as_copies() -> void:
	var changes: Array[Array] = []
	gesture.selection_changed.connect(func(ids: Array[int]) -> void: changes.append(ids))
	_tap(STARS[1])
	_tap(STARS[2])
	assert_eq(changes, [[1], [1, 2]] as Array[Array])


func _tap(point: Vector2i) -> bool:
	gesture.press(point)
	return gesture.release(point)


func _drag_to(point: Vector2i) -> void:
	gesture.drag(point)


func _star_at(point: Vector2i) -> int:
	for id: int in STARS:
		if (STARS[id] - point).length_squared() <= 25:
			return id
	return 0
