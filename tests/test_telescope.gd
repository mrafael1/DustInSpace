extends GutTest
## The telescope launcher (issue #52): starts ready, aims by pointing, launches exactly one pack,
## reloads and aims again, and a tap on it goes back to linking.

const Fixtures := preload("res://tests/fixtures.gd")
const TelescopeScene := preload("res://game/scenes/telescope.tscn")
const HudScene := preload("res://game/ui/hud.tscn")
const SkyScene := preload("res://game/scenes/sky.tscn")
const STEP: float = 1.0 / 60.0
const ORIGIN := Vector2i(80, 300)
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


func test_a_run_starts_ready_loaded_and_aiming() -> void:
	assert_eq(scope.shown_pack(), "blue")
	assert_eq(scope.seated_pack(), "blue", "seated at once: no load animation at the start")
	assert_true(scope.is_aiming())
	assert_false((scope.get_node("RestPack") as PackView).visible, "the planet is hidden inside")
	assert_true(inner.has_point(scope.burst_preview()), "the preview starts in the sky")


func test_an_empty_telescope_says_so_and_cannot_launch() -> void:
	_start({"blue": 0, "red": 0})
	assert_false(scope.is_aiming())
	watch_signals(scope)
	watch_signals(run)
	_tap(SCOPE)
	assert_signal_emitted_with_parameters(scope, "message_shown", [Telescope.EMPTY_MESSAGE])
	assert_signal_emitted(scope, "empty_tapped")
	assert_false(scope.is_aiming())
	_tap(Vector2i(0, -150))
	assert_signal_not_emitted(run, "pack_launched")
	assert_false(scope.start_aim(), "no aim without a planet")


func test_tapping_the_telescope_goes_back_to_linking_and_again_aims() -> void:
	watch_signals(scope)
	watch_signals(run)
	_tap(SCOPE)
	assert_false(scope.is_aiming())
	assert_signal_emitted(scope, "aim_cancelled")
	assert_signal_not_emitted(run, "pack_launched")
	assert_eq(run.owned_packs["blue"], 5, "nothing spent")
	assert_eq(scope.seated_pack(), "blue", "still loaded")
	assert_false(_touch(Vector2i(60, 150) - ORIGIN, true), "the sky is the stars' again")
	_touch(Vector2i(60, 150) - ORIGIN, false)
	_tap(SCOPE)
	assert_true(scope.is_aiming())
	assert_signal_emitted(scope, "aim_started")


func test_a_tap_in_the_sky_launches_exactly_one_pack_there() -> void:
	watch_signals(run)
	var target := Vector2i(40, 120)
	_tap(target - ORIGIN)
	assert_signal_emit_count(run, "pack_launched", 1)
	assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", target])
	assert_eq(run.owned_packs["blue"], 4)
	assert_false(scope.is_aiming(), "the launch ends this aim")
	_tap(target - ORIGIN)
	assert_signal_emit_count(run, "pack_launched", 1, "a second tap doesn't launch again")


func test_after_a_launch_the_next_planet_drops_in_and_it_aims_again() -> void:
	watch_signals(scope)
	_tap(Vector2i(40, 120) - ORIGIN)
	sequencer.advance(0.0)
	assert_eq(scope.seated_pack(), "", "empty while the pack flies")
	_play_until_idle()
	assert_signal_emitted_with_parameters(scope, "planet_seated", ["blue"])
	assert_eq(scope.seated_pack(), "blue")
	assert_true(scope.is_aiming(), "aiming again with the next planet")
	assert_eq(scope.burst_preview(), Vector2i(40, 120), "at the same spot")


func test_after_the_last_planet_it_goes_back_to_linking() -> void:
	_start({"blue": 1, "red": 0})
	_tap(Vector2i(40, 120) - ORIGIN)
	_play_until_idle()
	assert_eq(scope.shown_pack(), "")
	assert_false(scope.is_aiming())
	assert_false(_touch(Vector2i(60, 150) - ORIGIN, true), "touches go to the stars")


func test_the_planet_drops_into_the_mouth_then_hides() -> void:
	_start({"blue": 1, "red": 1})
	run.load_pack("red")
	sequencer.advance(0.0)
	assert_true(scope.is_loading())
	var pack: PackView = scope.get_node("RestPack")
	assert_true(pack.visible and pack.show_behind_parent, "dropping in, behind the barrel")
	assert_eq(pack.kind, "red")
	var start: float = (pack.position - Vector2(Telescope.PIVOT)).length()
	assert_true(sequencer.is_busy(), "the load holds the sequence")
	for i: int in 8:
		sequencer.advance(STEP)
		scope.advance(STEP)
	assert_lt((pack.position - Vector2(Telescope.PIVOT)).length(), start, "moving down into the barrel")
	_play_until_idle()
	assert_false(pack.visible, "hidden inside")
	assert_eq(scope.seated_pack(), "red")
	assert_true(scope.is_aiming())


func test_the_seated_planet_shows_in_a_window_on_the_barrel() -> void:
	var u: int = (Telescope.WINDOW_FROM + Telescope.WINDOW_TO) / 2
	assert_true(Palette.BLUE_PACK.has(scope._barrel_colour(u, 0, "blue")))
	assert_true(Palette.RED_PACK.has(scope._barrel_colour(u, 0, "red")))
	assert_eq(scope._barrel_colour(u, 0, ""), Palette.M4, "empty: plain barrel")
	assert_eq(scope._barrel_colour(Telescope.MOUTH - 1, 0, "blue"), Palette.N0, "the lens stays a dark opening")
	assert_eq(scope._barrel_colour(Telescope.MOUTH - 1, 0, ""), Palette.N0)


func test_touch_shows_the_aim_drag_adjusts_it_release_launches() -> void:
	watch_signals(run)
	assert_true(_touch(Vector2i(30, 100) - ORIGIN, true))
	assert_eq(scope.burst_preview(), Vector2i(30, 100), "the press shows the aim")
	assert_signal_not_emitted(run, "pack_launched", "nothing launches on the press")
	assert_true(_drag(Vector2i(140, 180) - ORIGIN))
	assert_eq(scope.burst_preview(), Vector2i(140, 180), "the drag moves it")
	assert_true(_touch(Vector2i(140, 180) - ORIGIN, false))
	assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", Vector2i(140, 180)])


func test_mouse_hover_aims_only_while_aiming() -> void:
	assert_true(_hover(Vector2i(20, 90) - ORIGIN))
	assert_eq(scope.burst_preview(), Vector2i(20, 90))
	_tap(SCOPE)
	assert_false(_hover(Vector2i(60, 90) - ORIGIN), "hovering is left alone when not aiming")
	assert_eq(scope.burst_preview(), Vector2i(20, 90))


func test_the_aim_is_clamped_into_the_sky_at_every_edge() -> void:
	for point: Vector2i in [Vector2i(-50, -50), Vector2i(400, 0), Vector2i(-10, 300), Vector2i(250, 260), Vector2i(90, 10), Vector2i(90, 275)]:
		_hover(point - ORIGIN)
		var aim: Vector2i = scope.burst_preview()
		assert_true(inner.has_point(aim), "%s aims at %s, inside the sky" % [point, aim])
		assert_eq(aim, StarScatter.clamp_to_sky(point, run.sky_rect))


func test_every_corner_and_edge_of_the_sky_launches_with_stars_inside() -> void:
	_start({"blue": 12, "red": 0})
	for target: Vector2i in [inner.position, Vector2i(inner.end.x - 1, inner.position.y), Vector2i(inner.position.x, inner.end.y - 1), inner.end - Vector2i.ONE, Vector2i(90, inner.position.y), Vector2i(inner.position.x, 160)]:
		assert_true(scope.is_aiming(), "aiming again before %s" % target)
		watch_signals(run)
		_tap(target - ORIGIN)
		assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", target])
		for star: Star in run.stars:
			assert_true(inner.has_point(star.position), "%s inside the sky" % star.position)
		_play_until_idle()


func test_the_barrel_points_at_the_target_in_direction_frames() -> void:
	var pivot: Vector2i = ORIGIN + Telescope.PIVOT
	_hover(Vector2i(pivot.x, 100) - ORIGIN)
	assert_eq(scope.direction_frame(), 0, "straight up")
	_hover(Vector2i(pivot.x + 100, pivot.y - 100) - ORIGIN)
	assert_eq(scope.direction_frame(), Telescope.DIRECTIONS / 8, "up-right")
	_hover(Vector2i(pivot.x - 100, pivot.y - 100) - ORIGIN)
	assert_eq(scope.direction_frame(), Telescope.DIRECTIONS - Telescope.DIRECTIONS / 8, "up-left")
	assert_lt(scope.mouth().x, Telescope.PIVOT.x, "the mouth follows")


func test_the_flight_starts_at_the_mouth() -> void:
	var from: Vector2i = scope.mouth()
	_tap(Vector2i(90, 120) - ORIGIN)
	sequencer.advance(0.0)
	var flying: PackView = scope.get_node("FlyingPack")
	assert_true(flying.visible)
	assert_eq(Vector2i(flying.position), from)


func test_a_sequence_interrupting_the_aim_resumes_it_after() -> void:
	run.dust = 50
	run.buy("red")
	assert_false(scope.is_aiming(), "the sequence takes the input")
	assert_eq(run.owned_packs["blue"], 5)
	_play_until_idle()
	assert_true(scope.is_aiming(), "and gives it back")
	assert_eq(scope.seated_pack(), "red")


func test_picking_a_planet_in_the_hud_loads_it_and_aims_with_it() -> void:
	_start({"blue": 1, "red": 1})
	_tap(SCOPE)
	assert_false(scope.is_aiming(), "linking")
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.set_process(false)
	hud.setup(run, sequencer)
	hud.planet_chosen.connect(func(_kind: String) -> void: scope.request_aim())
	_hud_tap(hud, Vector2i(hud.slot("red").position) + PackSlot.ICON_TARGET.get_center())
	assert_eq(run.loaded_pack, "red")
	_play_until_idle()
	assert_eq(scope.seated_pack(), "red", "the telescope holds the picked planet")
	assert_true(scope.is_aiming())
	watch_signals(run)
	_tap(Vector2i(90, 120) - ORIGIN)
	assert_signal_emitted_with_parameters(run, "pack_launched", ["red", Vector2i(90, 120)])


func test_a_refused_hud_tap_does_not_aim() -> void:
	_start({"blue": 1, "red": 0})
	run.dust = 0
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
	assert_true(scope.is_aiming())
	var local: Vector2i = run.stars[0].position - ORIGIN
	# The telescope comes first (a later sibling in Main); what it takes never reaches the sky.
	assert_true(scope.handle_pointer(_touch_event(local, true)), "the telescope takes the press on a star")
	assert_true(scope.handle_pointer(_drag_event(local + Vector2i(3, 0))))
	assert_eq(sky.selected_ids(), [] as Array[int], "no star selected")


func test_a_press_on_the_telescope_released_elsewhere_does_nothing() -> void:
	_touch(SCOPE, true)
	_touch(Vector2i(0, -150), false)
	assert_true(scope.is_aiming(), "still aiming")


func test_a_run_that_is_over_ignores_the_telescope() -> void:
	run.outcome = RunState.Outcome.WON
	assert_false(_touch(SCOPE, true))
	assert_false(_touch(Vector2i(0, -150), true))


func test_every_direction_frame_keeps_the_barrel_on_whole_pixels() -> void:
	var seen: Dictionary[int, bool] = {}
	for x: int in range(inner.position.x, inner.end.x, 4):
		_hover(Vector2i(x, inner.position.y) - ORIGIN)
		seen[scope.direction_frame()] = true
		assert_eq(Vector2(scope.mouth()), Vector2(scope.mouth()).round())
		assert_lt(scope.mouth().y, Telescope.PIVOT.y, "the mouth stays above the pivot")
	assert_gt(seen.size(), 2, "the barrel turns through several frames across the sky")


func test_the_barrel_is_wider_than_its_eyepiece_and_the_hood_wider_still() -> void:
	assert_gt(Telescope.BARREL_HALF, Telescope.EYEPIECE_HALF)
	assert_gt(Telescope.HOOD_HALF, Telescope.BARREL_HALF)
	for kind: String in ["", "blue", "red"]:
		for v: int in range(-Telescope.HOOD_HALF - 1, Telescope.HOOD_HALF + 2):
			for u: int in range(Telescope.EYEPIECE_BACK - 1, Telescope.MOUTH + 2):
				var colour: Variant = scope._barrel_colour(u, v, kind)
				assert_true(colour == null or colour is Color, "(%d, %d)" % [u, v])


func test_only_the_barrel_turns_the_tripod_stays() -> void:
	var before: int = scope.direction_frame()
	_hover(Vector2i(175, 200) - ORIGIN)
	assert_ne(scope.direction_frame(), before)
	assert_true(scope.on_scope(Telescope.PIVOT + Vector2i(0, 10)), "the tripod is still pressable where it stands")
	assert_true(scope.on_scope(scope.mouth()), "and so is the barrel's mouth, wherever it points")


func test_the_telescope_sits_in_the_hud_row_clear_of_the_pack_buttons() -> void:
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.setup(run, sequencer)
	for kind: String in ["blue", "red"]:
		var slot: Vector2i = Vector2i(hud.slot(kind).position)
		var icon := Rect2i(PackSlot.ICON_TARGET.position + slot, PackSlot.ICON_TARGET.size)
		for x: int in range(icon.position.x, icon.end.x):
			for y: int in range(icon.position.y, icon.end.y):
				assert_false(scope.on_scope(Vector2i(x, y) - ORIGIN), "%s's button stays the HUD's" % kind)
	assert_true(Rect2i(ScreenZones.HUD.position - Vector2i(0, 10), ScreenZones.HUD.size + Vector2i(0, 10)).has_point(ORIGIN))


func _start(packs: Dictionary) -> void:
	run = Fixtures.run({"start_packs": packs, "sun_target": 100000})
	sequencer.bind(run)
	scope.setup(run, sequencer)


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


## Plays the events, and the next planet's drop into the telescope, to the end.
func _play_until_idle() -> void:
	for i: int in 600:
		if not sequencer.is_busy() and not scope.is_loading():
			scope.advance(STEP)
			return
		sequencer.advance(STEP)
		scope.advance(STEP)
