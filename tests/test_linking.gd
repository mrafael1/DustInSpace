extends GutTest
## Linking end to end: touch events into SkyView, run.link() in the core, feedback out.

const Fixtures := preload("res://tests/fixtures.gd")
const SkyScene := preload("res://game/scenes/sky.tscn")
const S := Star.Size.SMALL
const M := Star.Size.MEDIUM
const B := Star.Size.BIG
## Far apart so hit circles never overlap.
const SPOTS: Array[Vector2i] = [Vector2i(30, 150), Vector2i(90, 150), Vector2i(150, 150), Vector2i(90, 210)]
const EMPTY := Vector2i(90, 100)

var run: RunState
var sky: SkyView
var sequencer: EventSequencer


func before_each() -> void:
	# A Sun that never fills, so the run doesn't end while every combo is tried.
	run = Fixtures.run({"sun_target": 100000})
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	sky = SkyScene.instantiate()
	add_child_autofree(sky)
	sky.setup(run, sequencer)


func test_every_combo_links_by_tapping_in_any_order() -> void:
	for combo: Array in _every_combo_in_every_order():
		var sizes: Array[int] = []
		sizes.assign(combo)
		var ids: Array[int] = _seed_sky(sizes)
		var expected: String = Combos.evaluate(sizes)
		var before := Vector2i(run.dust, run.light)
		for id: int in ids:
			_tap(run.find_star(id).position)
		var reward: Balance.ComboReward = run.balance.combos[expected]
		assert_eq(Vector2i(run.dust, run.light), before + Vector2i(reward.dust, reward.light), "%s pays" % [sizes])
		assert_true(run.stars.is_empty(), "%s uses its stars" % [sizes])


func test_every_combo_links_by_dragging_in_any_order() -> void:
	for combo: Array in _every_combo_in_every_order():
		var sizes: Array[int] = []
		sizes.assign(combo)
		var ids: Array[int] = _seed_sky(sizes)
		var points: Array[Vector2i] = []
		for id: int in ids:
			points.append(run.find_star(id).position)
		var light_before: int = run.light
		_drag_through(points)
		assert_gt(run.light, light_before, "%s pays light" % [sizes])
		assert_true(run.stars.is_empty(), "%s uses its stars" % [sizes])


func test_an_invalid_link_cancels_cleanly_and_uses_nothing() -> void:
	var ids: Array[int] = _seed_sky([S, S, B])
	for id: int in ids:
		_tap(run.find_star(id).position)
	sequencer.advance(0.0)
	assert_eq(run.stars.size(), 3, "every star stays")
	assert_eq([run.dust, run.light], [0, 0], "nothing is paid")
	assert_eq(sky.star_count(), 3, "every view stays")
	assert_true(sky.selected_ids().is_empty(), "the selection is dropped")
	for id: int in ids:
		assert_false(sky.star_view(id).selected)
	assert_true((sky.get_node("LinkLayer") as LinkLayer).is_flashing(), "the rejected line shows")
	assert_false(sequencer.is_busy(), "rejection feedback doesn't lock input")


func test_a_short_drag_is_rejected_and_uses_nothing() -> void:
	var ids: Array[int] = _seed_sky([S, S, S])
	watch_signals(run)
	_drag_through([run.find_star(ids[0]).position, run.find_star(ids[1]).position, EMPTY])
	assert_signal_emitted(run, "link_rejected")
	assert_eq(run.stars.size(), 3)
	sequencer.advance(0.0)
	assert_true((sky.get_node("LinkLayer") as LinkLayer).is_flashing())


func test_a_collected_link_flares_its_line_and_dissolves_its_stars() -> void:
	var ids: Array[int] = _seed_sky([S, M, B])
	for id: int in ids:
		_tap(run.find_star(id).position)
	sequencer.advance(0.0)
	assert_true((sky.get_node("LinkLayer") as LinkLayer).is_flashing())
	assert_eq(sky.star_count(), 0)


func test_the_hit_circle_is_44_pt_whatever_the_sprite() -> void:
	var ids: Array[int] = _seed_sky([S])
	var star: Vector2i = run.find_star(ids[0]).position
	assert_eq(sky.star_at(star + Vector2i(SkyView.HIT_RADIUS, 0)), ids[0], "a small star is hit 11 px away")
	assert_eq(sky.star_at(star + Vector2i(8, 8)), 0, "but not outside the circle")
	assert_eq(sky.star_at(star + Vector2i(0, SkyView.HIT_RADIUS + 1)), 0)


func test_the_nearest_star_wins_where_hit_circles_overlap() -> void:
	run.add_star(S, Vector2i(80, 150))
	run.add_star(B, Vector2i(96, 150))
	sky.setup(run, sequencer)
	assert_eq(sky.star_at(Vector2i(87, 150)), run.stars[0].id)
	assert_eq(sky.star_at(Vector2i(89, 150)), run.stars[1].id)


func test_selected_stars_show_as_selected() -> void:
	var ids: Array[int] = _seed_sky([S, M, B])
	_tap(run.find_star(ids[1]).position)
	assert_true(sky.star_view(ids[1]).selected)
	assert_false(sky.star_view(ids[0]).selected)
	_tap(run.find_star(ids[1]).position)
	assert_false(sky.star_view(ids[1]).selected, "tapping it again drops it")


func test_tapping_empty_sky_cancels() -> void:
	var ids: Array[int] = _seed_sky([S, M, B])
	_tap(run.find_star(ids[0]).position)
	_tap(run.find_star(ids[1]).position)
	assert_true(_tap(EMPTY), "the cancelling tap is used")
	assert_true(sky.selected_ids().is_empty())
	assert_eq(run.stars.size(), 3)


func test_empty_taps_with_nothing_selected_are_left_for_others() -> void:
	_seed_sky([S])
	assert_false(_tap(EMPTY))
	assert_false(_tap(Vector2i(90, 300)), "HUD taps are not the sky's")


func test_the_plaque_previews_the_reward_while_three_are_selected() -> void:
	var ids: Array[int] = _seed_sky([B, S, M])
	var plaque: RewardPlaque = sky.get_node("UILayer/RewardPlaque")
	_tap(run.find_star(ids[0]).position)
	_tap(run.find_star(ids[1]).position)
	assert_false(plaque.visible, "no preview before the third star")
	var last: Vector2i = run.find_star(ids[2]).position
	_touch(last, true)
	assert_true(plaque.visible)
	var reward: Balance.ComboReward = run.balance.combos[Combos.SEQUENCE]
	assert_eq((plaque.get_node("Dust") as Label).text, "+%d" % reward.dust)
	assert_eq((plaque.get_node("Light") as Label).text, "+%d" % reward.light)
	assert_eq(plaque.position, plaque.position.round(), "whole pixels")
	_touch(last, false)
	assert_false(plaque.visible, "gone once the link resolves")


func test_the_plaque_says_when_three_stars_are_no_combo() -> void:
	var ids: Array[int] = _seed_sky([S, S, B])
	var plaque: RewardPlaque = sky.get_node("UILayer/RewardPlaque")
	_tap(run.find_star(ids[0]).position)
	_tap(run.find_star(ids[1]).position)
	_touch(run.find_star(ids[2]).position, true)
	assert_true((plaque.get_node("NoCombo") as Label).visible)


func test_a_sequence_starting_drops_a_link_in_progress() -> void:
	var ids: Array[int] = _seed_sky([S, M, B])
	_tap(run.find_star(ids[0]).position)
	_touch(run.find_star(ids[1]).position, true)
	run.launch(Vector2i(90, 180))
	assert_true(sky.selected_ids().is_empty())
	assert_false(sky.star_view(ids[0]).selected)
	_touch(run.find_star(ids[1]).position, false)
	assert_eq(run.stars.size(), 3 + 3, "the swallowed release links nothing")


func test_nothing_links_once_the_run_is_over() -> void:
	var ids: Array[int] = _seed_sky([S, S, S])
	run.outcome = RunState.Outcome.LOST
	for id: int in ids:
		_tap(run.find_star(id).position)
	assert_eq(run.stars.size(), 3)


## Every triple, and the sequence in all six orders.
func _every_combo_in_every_order() -> Array[Array]:
	return [[S, S, S], [M, M, M], [B, B, B],
		[S, M, B], [S, B, M], [M, S, B], [M, B, S], [B, S, M], [B, M, S]]


## Clears the sky, adds stars at SPOTS and rebuilds the views. Returns their ids in order.
func _seed_sky(sizes: Array[int]) -> Array[int]:
	# Let the previous link's events finish first.
	sequencer.advance(0.0)
	sequencer.advance(10.0)
	run.stars.clear()
	var ids: Array[int] = []
	for i: int in sizes.size():
		ids.append(run.add_star(sizes[i] as Star.Size, SPOTS[i]).id)
	sky.setup(run, sequencer)
	return ids


func _tap(point: Vector2i) -> bool:
	_touch(point, true)
	return _touch(point, false)


## Sends one touch to the sky. Returns whether the sky used it.
func _touch(point: Vector2i, pressed: bool) -> bool:
	var event := InputEventScreenTouch.new()
	event.position = Vector2(point)
	event.pressed = pressed
	return _send(event)


## Presses the first point, drags through the rest pixel by pixel, and releases on the last.
func _drag_through(points: Array[Vector2i]) -> void:
	_touch(points[0], true)
	for i: int in range(1, points.size()):
		for p: Vector2i in LinkLayer.line_pixels(points[i - 1], points[i]):
			var drag := InputEventScreenDrag.new()
			drag.position = Vector2(p)
			_send(drag)
	_touch(points[-1], false)


func _send(event: InputEvent) -> bool:
	return sky.handle_pointer(event)
