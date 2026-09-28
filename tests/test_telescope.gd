extends GutTest
## The telescope launcher (issue #52): load, aim by pointing, launch exactly one pack, cancel.

const Fixtures := preload("res://tests/fixtures.gd")
const TelescopeScene := preload("res://game/scenes/telescope.tscn")
const HudScene := preload("res://game/ui/hud.tscn")
const SkyScene := preload("res://game/scenes/sky.tscn")
const STEP: float = 1.0 / 60.0
const ORIGIN := Vector2i(90, 270)
## The telescope's own press point (its pivot), in its coordinates.
const SCOPE := Telescope.PIVOT

var run: RunState
var scope: Telescope
var sequencer: EventSequencer
var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)


func before_each() -> void:
	run = Fixtures.run({"start_packs": {"blue": 5, "red": 0}, "sun_target": 100000})
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	scope = TelescopeScene.instantiate()
	scope.position = Vector2(ORIGIN)
	add_child_autofree(scope)
	scope.set_process(false)
	scope.setup(run, sequencer)


func test_it_holds_the_loaded_planet_at_its_mouth() -> void:
	assert_eq(scope.loaded_pack(), "blue")
	var pack: PackView = scope.get_node("RestPack")
	assert_true(pack.visible)
	assert_eq(Vector2i(pack.position), scope.pack_position())
	assert_lt(scope.pack_position().y, scope.mouth().y, "above the mouth while it points up")


func test_an_empty_telescope_says_so_and_cannot_launch() -> void:
	run = Fixtures.run({"start_packs": {"blue": 0, "red": 0}})
	sequencer.bind(run)
	scope.setup(run, sequencer)
	watch_signals(scope)
	watch_signals(run)
	_tap(SCOPE)
	assert_signal_emitted_with_parameters(scope, "message_shown", [Telescope.EMPTY_MESSAGE])
	assert_signal_emitted(scope, "empty_tapped")
	assert_false(scope.is_aiming())
	_tap(Vector2i(0, -120))
	assert_signal_not_emitted(run, "pack_launched")
	assert_false(scope.start_aim(), "no aim without a planet")


func test_tapping_the_loaded_telescope_aims() -> void:
	watch_signals(scope)
	_tap(SCOPE)
	assert_true(scope.is_aiming())
	assert_signal_emitted(scope, "aim_started")
	assert_signal_emitted_with_parameters(scope, "message_shown", [Telescope.AIM_MESSAGE])
	assert_true(inner.has_point(scope.burst_preview()), "the preview starts in the sky")


func test_a_tap_in_the_sky_launches_exactly_one_pack_there() -> void:
	_tap(SCOPE)
	watch_signals(run)
	var target := Vector2i(40, 120)
	_tap(target - ORIGIN)
	assert_signal_emit_count(run, "pack_launched", 1)
	assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", target])
	assert_eq(run.owned_packs["blue"], 4)
	assert_false(scope.is_aiming(), "the launch ends the aim")
	_tap(target - ORIGIN)
	assert_signal_emit_count(run, "pack_launched", 1, "a second tap doesn't launch again")


func test_touch_shows_the_aim_drag_adjusts_it_release_launches() -> void:
	_tap(SCOPE)
	watch_signals(run)
	assert_true(_touch(Vector2i(30, 100) - ORIGIN, true))
	assert_eq(scope.burst_preview(), Vector2i(30, 100), "the press shows the aim")
	assert_signal_not_emitted(run, "pack_launched", "nothing launches on the press")
	assert_true(_drag(Vector2i(140, 180) - ORIGIN))
	assert_eq(scope.burst_preview(), Vector2i(140, 180), "the drag moves it")
	assert_true(_touch(Vector2i(140, 180) - ORIGIN, false))
	assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", Vector2i(140, 180)])


func test_mouse_hover_aims_only_while_aiming() -> void:
	assert_false(_hover(Vector2i(20, 90) - ORIGIN), "hovering is left alone when not aiming")
	_tap(SCOPE)
	assert_true(_hover(Vector2i(20, 90) - ORIGIN))
	assert_eq(scope.burst_preview(), Vector2i(20, 90))


func test_the_aim_is_clamped_into_the_sky_at_every_edge() -> void:
	_tap(SCOPE)
	for point: Vector2i in [Vector2i(-50, -50), Vector2i(400, 0), Vector2i(-10, 300), Vector2i(250, 260), Vector2i(90, 10), Vector2i(90, 275)]:
		_hover(point - ORIGIN)
		var aim: Vector2i = scope.burst_preview()
		assert_true(inner.has_point(aim), "%s aims at %s, inside the sky" % [point, aim])
		assert_eq(aim, StarScatter.clamp_to_sky(point, run.sky_rect))


func test_every_corner_and_edge_of_the_sky_launches_with_stars_inside() -> void:
	run.owned_packs["blue"] = 12
	scope.setup(run, sequencer)
	for target: Vector2i in [inner.position, Vector2i(inner.end.x - 1, inner.position.y), Vector2i(inner.position.x, inner.end.y - 1), inner.end - Vector2i.ONE, Vector2i(90, inner.position.y), Vector2i(inner.position.x, 160)]:
		_tap(SCOPE)
		watch_signals(run)
		_tap(target - ORIGIN)
		assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", target])
		for star: Star in run.stars:
			assert_true(inner.has_point(star.position), "%s inside the sky" % star.position)
		_play_until_idle()


func test_tapping_the_telescope_again_cancels_and_spends_nothing() -> void:
	_tap(SCOPE)
	_hover(Vector2i(60, 120) - ORIGIN)
	watch_signals(scope)
	watch_signals(run)
	_tap(SCOPE)
	assert_false(scope.is_aiming())
	assert_signal_emitted(scope, "aim_cancelled")
	assert_signal_not_emitted(run, "pack_launched")
	assert_eq(run.owned_packs["blue"], 5, "nothing spent")
	assert_eq(scope.loaded_pack(), "blue", "still loaded")
	assert_false(_touch(Vector2i(60, 120) - ORIGIN, true), "the sky is the stars' again")


func test_the_tube_points_at_the_target_in_direction_frames() -> void:
	assert_eq(scope.direction_frame(), 0, "up at rest")
	_tap(SCOPE)
	var pivot: Vector2i = ORIGIN + Telescope.PIVOT
	_hover(Vector2i(pivot.x, 100) - ORIGIN)
	assert_eq(scope.direction_frame(), 0, "straight up")
	_hover(Vector2i(pivot.x + 100, pivot.y - 100) - ORIGIN)
	assert_eq(scope.direction_frame(), Telescope.DIRECTIONS / 8, "up-right")
	_hover(Vector2i(pivot.x - 100, pivot.y - 100) - ORIGIN)
	assert_eq(scope.direction_frame(), Telescope.DIRECTIONS - Telescope.DIRECTIONS / 8, "up-left")
	var pack: Vector2i = scope.pack_position()
	assert_lt(pack.x, Telescope.PIVOT.x, "the planet follows the mouth")


func test_the_flight_starts_at_the_mouth() -> void:
	_tap(SCOPE)
	var from: Vector2i = scope.pack_position()
	_tap(Vector2i(90, 120) - ORIGIN)
	sequencer.advance(0.0)
	var flying: PackView = scope.get_node("FlyingPack")
	assert_true(flying.visible)
	assert_eq(Vector2i(flying.position), from)
	assert_eq(scope.loaded_pack(), "", "the planet left the telescope")


func test_no_aim_while_a_sequence_plays_then_it_aims_when_asked() -> void:
	run.launch(Vector2i(90, 160))
	assert_true(sequencer.is_busy())
	scope.request_aim()
	scope.advance(0.0)
	assert_false(scope.is_aiming(), "waits for the sequence")
	_play_until_idle()
	assert_true(scope.is_aiming(), "then aims with the next planet")


func test_a_sequence_starting_ends_the_aim() -> void:
	_tap(SCOPE)
	run.dust = 50
	run.buy("red")
	assert_false(scope.is_aiming())
	assert_eq(run.owned_packs["blue"], 5)


func test_picking_a_planet_in_the_hud_loads_it_and_aims_with_it() -> void:
	run = Fixtures.run({"start_packs": {"blue": 1, "red": 1}, "sun_target": 100000})
	sequencer.bind(run)
	scope.setup(run, sequencer)
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(run, sequencer)
	hud.planet_chosen.connect(func(_kind: String) -> void: scope.request_aim())
	var icon: Vector2i = Vector2i(hud.slot("red").position) + PackSlot.ICON_TARGET.get_center()
	_hud_tap(hud, icon)
	assert_eq(run.loaded_pack, "red")
	_play_until_idle()
	assert_eq(scope.loaded_pack(), "red", "the telescope holds the picked planet")
	assert_true(scope.is_aiming())
	watch_signals(run)
	_tap(Vector2i(90, 120) - ORIGIN)
	assert_signal_emitted_with_parameters(run, "pack_launched", ["red", Vector2i(90, 120)])


func test_a_refused_hud_tap_does_not_aim() -> void:
	run = Fixtures.run({"start_packs": {"blue": 1, "red": 0}, "sun_target": 100000})
	run.dust = 0
	sequencer.bind(run)
	scope.setup(run, sequencer)
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(run, sequencer)
	watch_signals(hud)
	_hud_tap(hud, Vector2i(hud.slot("red").position) + PackSlot.ICON_TARGET.get_center())
	assert_signal_not_emitted(hud, "planet_chosen")
	assert_signal_emitted(hud, "tap_refused")


func test_aiming_takes_every_touch_so_no_star_is_linked() -> void:
	var sky: SkyView = SkyScene.instantiate()
	add_child_autofree(sky)
	sky.setup(run, sequencer)
	run.launch(Vector2i(90, 160))
	_play_until_idle()
	var star: Star = run.stars[0]
	_tap(SCOPE)
	var local: Vector2i = star.position - ORIGIN
	# The telescope comes first (a later sibling in Main); what it takes never reaches the sky.
	var press := _touch_event(local, true)
	assert_true(scope.handle_pointer(press), "the telescope takes the press on a star")
	assert_true(scope.handle_pointer(_drag_event(local + Vector2i(3, 0))))
	assert_eq(sky.selected_ids(), [] as Array[int], "no star selected")
	_play_until_idle()


func test_when_not_aiming_touches_in_the_sky_are_left_for_the_stars() -> void:
	assert_false(_touch(Vector2i(90, 150) - ORIGIN, true))
	assert_false(_drag(Vector2i(95, 150) - ORIGIN))
	assert_false(_touch(Vector2i(95, 150) - ORIGIN, false))
	assert_false(scope.is_aiming())


func test_a_press_on_the_telescope_released_elsewhere_does_nothing() -> void:
	_touch(SCOPE, true)
	_touch(Vector2i(0, -100), false)
	assert_false(scope.is_aiming())


func test_a_run_that_is_over_ignores_the_telescope() -> void:
	run.outcome = RunState.Outcome.WON
	assert_false(_touch(SCOPE, true))
	assert_false(scope.start_aim())


func test_every_direction_frame_keeps_the_tube_on_whole_pixels() -> void:
	_tap(SCOPE)
	var pivot: Vector2i = ORIGIN + Telescope.PIVOT
	var seen: Dictionary[int, bool] = {}
	for x: int in range(inner.position.x, inner.end.x, 4):
		_hover(Vector2i(x, inner.position.y) - ORIGIN)
		seen[scope.direction_frame()] = true
		assert_eq(Vector2(scope.mouth()), Vector2(scope.mouth()).round())
		assert_lt(scope.pack_position().y, Telescope.PIVOT.y, "the planet stays above the pivot")
	assert_gt(seen.size(), 2, "the tube turns through several frames across the sky (%s)" % pivot)


func test_empty_and_loaded_differ_in_shape_not_only_colour() -> void:
	var lens: int = Telescope.MOUTH
	assert_null(scope._barrel_colour(lens, 0, true), "loaded: the lens is open and the planet shows through")
	assert_eq(scope._barrel_colour(lens - 1, 0, false), Palette.N0, "empty: a dark, hollow lens")
	var pack: PackView = scope.get_node("RestPack")
	assert_true(pack.show_behind_parent, "the planet is seated behind the hood, not balanced on it")
	var seated: int = (Vector2(scope.pack_position() - scope.mouth())).length()
	assert_lt(seated, PackView.HUD_RADIUS + 1, "part of the planet sits inside the mouth")


func test_the_barrel_is_wider_than_its_eyepiece_and_the_hood_wider_still() -> void:
	assert_gt(Telescope.BARREL_HALF, Telescope.EYEPIECE_HALF)
	assert_gt(Telescope.HOOD_HALF, Telescope.BARREL_HALF)
	for v: int in range(-Telescope.HOOD_HALF - 1, Telescope.HOOD_HALF + 2):
		for u: int in range(Telescope.EYEPIECE_BACK - 1, Telescope.MOUTH + 2):
			var colour: Variant = scope._barrel_colour(u, v, false)
			if colour != null:
				assert_true(colour is Color, "(%d, %d)" % [u, v])


func test_only_the_barrel_turns_the_tripod_stays() -> void:
	_tap(SCOPE)
	var before: int = scope.direction_frame()
	_hover(Vector2i(170, 200) - ORIGIN)
	assert_ne(scope.direction_frame(), before)
	assert_true(scope.on_scope(Telescope.PIVOT + Vector2i(0, 10)), "the tripod is still pressable where it stands")
	assert_true(scope.on_scope(scope.mouth()), "and so is the barrel's mouth, wherever it points")


func test_the_planet_sits_deep_in_the_mouth() -> void:
	var inside: int = PackView.HUD_RADIUS - (Vector2(scope.pack_position() - scope.mouth())).length()
	assert_gte(inside, PackView.HUD_RADIUS / 2, "at least half the planet is behind the rim")


func test_the_sight_line_starts_clear_of_the_planet() -> void:
	assert_gt(Telescope.sight_start(), PackView.HUD_RADIUS + 1, "a gap between the planet and the first dot")


func _tap(point: Vector2i) -> void:
	_touch(point, true)
	_touch(point, false)


func _touch(point: Vector2i, pressed: bool) -> bool:
	return scope.handle_pointer(_touch_event(point, pressed))


func _drag(point: Vector2i) -> bool:
	return scope.handle_pointer(_drag_event(point))


func _hover(point: Vector2i) -> bool:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(point)
	return scope.handle_pointer(motion)


func _touch_event(point: Vector2i, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(point)
	touch.pressed = pressed
	return touch


func _drag_event(point: Vector2i) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(point)
	return drag


func _hud_tap(hud: Hud, point: Vector2i) -> void:
	hud.handle_pointer(_touch_event(point, true))
	hud.handle_pointer(_touch_event(point, false))


func _play_until_idle() -> void:
	for i: int in 600:
		if not sequencer.is_busy():
			scope.advance(STEP)
			return
		sequencer.advance(STEP)
		scope.advance(STEP)
