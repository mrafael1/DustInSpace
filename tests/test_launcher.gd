extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const LauncherScene := preload("res://game/scenes/launcher.tscn")
const STEP: float = 1.0 / 60.0
const ORIGIN := Vector2i(90, 270)

var run: RunState
var launcher: Launcher
var sequencer: EventSequencer
var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)


func before_each() -> void:
	run = Fixtures.run({"start_packs": {"blue": 12, "red": 0}, "sun_target": 100000})
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	launcher = LauncherScene.instantiate()
	launcher.position = Vector2(ORIGIN)
	add_child_autofree(launcher)
	launcher.set_process(false)
	launcher.setup(run, sequencer)


func test_the_fork_shows_the_loaded_pack() -> void:
	assert_eq(launcher.shown_pack(), "blue")


func test_every_corner_and_edge_of_the_sky_can_be_aimed_at() -> void:
	for target: Vector2i in _corners_and_edges():
		var pull: Vector2 = _pull_toward(target)
		assert_lte(pull.length(), float(Launcher.MAX_PULL), "%s is within a full pull" % target)
		assert_eq(StarScatter.clamp_to_sky(Launcher.aim_target(ORIGIN, pull), run.sky_rect), target)


func test_launching_at_corners_and_edges_keeps_every_star_in_the_sky() -> void:
	watch_signals(run)
	for target: Vector2i in _corners_and_edges():
		var pull: Vector2 = _pull_toward(target)
		var stars_before: int = run.stars.size()
		_pull_and_release(pull)
		assert_signal_emitted_with_parameters(run, "pack_launched", ["blue", target])
		assert_gt(run.stars.size(), stars_before, "the pack burst at %s" % target)
		for star: Star in run.stars:
			assert_true(inner.has_point(star.position), "%s inside the sky" % star.position)
		_play_until_idle()


func test_the_weakest_launch_still_reaches_the_sky() -> void:
	var weakest: Vector2i = Launcher.aim_target(ORIGIN, Vector2(0, Launcher.MIN_PULL))
	assert_true(Fixtures.SKY.has_point(weakest), "a minimum pull aims into the sky zone; the core's clamp does the rest")


func test_the_preview_shows_the_clamped_burst_point() -> void:
	_press(Vector2i.ZERO)
	_drag(Vector2(0, Launcher.MAX_PULL))
	assert_eq(launcher.burst_preview(), Vector2i(90, inner.position.y), "a full pull down aims at the top")


func test_the_aim_is_finer_than_a_whole_pixel_of_pull() -> void:
	_press(Vector2i.ZERO)
	_drag(Vector2(0.2, 12))
	var a: Vector2i = launcher.burst_preview()
	_drag(Vector2(0.4, 12))
	assert_ne(launcher.burst_preview(), a, "a fifth of a pixel of pull moves the aim")
	assert_eq(launcher.get_node("RestPack").position, Vector2(0, 12), "the pack itself stays on the grid")


func test_a_short_pull_cancels() -> void:
	_press(Vector2i.ZERO)
	_drag(Vector2(2, 2))
	assert_true(_release())
	assert_eq(run.owned_packs["blue"], 12, "nothing launched")
	assert_false(launcher.is_pulling())


func test_the_pull_is_clamped_and_the_pack_follows_it_on_whole_pixels() -> void:
	_press(Vector2i(3, -2))
	_drag(Vector2(40.4, 60.3))
	var pack: Node2D = launcher.get_node("RestPack")
	assert_lte(pack.position.length(), float(Launcher.MAX_PULL) + 0.5)
	assert_eq(pack.position, pack.position.round())
	_release()
	assert_eq(pack.position, Vector2.ZERO, "back in the fork")


func test_pull_frames_step_up_with_the_pull() -> void:
	assert_eq(launcher.pull_frame(), 0)
	_press(Vector2i.ZERO)
	var frames: Array[int] = []
	for length: int in [0, 7, 13, 19, 24]:
		_drag(Vector2(0, length))
		frames.append(launcher.pull_frame())
	assert_eq(frames, [0, 1, 2, 3, 3] as Array[int])


func test_presses_off_the_pack_are_left_for_others() -> void:
	assert_false(_press(Vector2i(0, -Launcher.HIT_RADIUS - 1)))
	assert_false(launcher.is_pulling())


func test_no_pull_while_a_sequence_plays() -> void:
	run.launch(Vector2i(90, 160))
	assert_true(sequencer.is_busy())
	assert_false(_press(Vector2i.ZERO))


func test_a_sequence_starting_cancels_a_pull() -> void:
	_press(Vector2i.ZERO)
	_drag(Vector2(0, 20))
	run.launch(Vector2i(90, 160))  # e.g. the debug key
	assert_false(launcher.is_pulling())
	_release()
	assert_eq(run.owned_packs["blue"], 11, "the swallowed release launches nothing more")


func test_the_pack_flies_trembles_then_bursts() -> void:
	_pull_and_release(Vector2(0, 12))
	var burst: Vector2i = StarScatter.clamp_to_sky(Launcher.aim_target(ORIGIN, Vector2(0, 12)), run.sky_rect)
	sequencer.advance(0.0)
	var flying: PackView = launcher.get_node("FlyingPack")
	assert_true(flying.visible)
	assert_eq(launcher.shown_pack(), "", "the fork is empty while the pack is in the air")
	var elapsed: float = 0.0
	while elapsed < Launcher.FLIGHT_TIME + Launcher.TREMBLE_TIME - 0.02:
		_step()
		elapsed += STEP
		assert_eq(flying.position, flying.position.round(), "whole pixels in flight")
		assert_true(sequencer.is_busy(), "the burst waits for the flight and tremble")
	var at: Vector2i = Vector2i(flying.position) + ORIGIN
	assert_lte(float((at - burst).length_squared()), 2.0, "trembling on the burst point")
	assert_true(flying.grown and flying.bright, "the tremble grows and brightens by drawn frames")
	_step()
	_step()
	assert_false(flying.visible, "gone once pack_burst plays")
	assert_eq(launcher.shown_pack(), "blue", "the next pack is in the fork")


func test_the_fork_updates_on_pack_loaded() -> void:
	run.dust = 20
	run.buy("red")
	assert_eq(launcher.shown_pack(), "blue", "waits for the event")
	sequencer.advance(0.0)
	assert_eq(launcher.shown_pack(), "red")


func test_the_fork_is_empty_after_the_last_pack() -> void:
	run = Fixtures.run({"start_packs": {"blue": 1, "red": 0}})
	sequencer.bind(run)
	launcher.setup(run, sequencer)
	_pull_and_release(Vector2(0, 12))
	_play_until_idle()
	assert_eq(launcher.shown_pack(), "")
	assert_false(_press(Vector2i.ZERO), "nothing to pull")


func test_a_big_bang_bursts_the_flying_pack_too() -> void:
	run.force_next_big_bang = true
	_pull_and_release(Vector2(0, 12))
	_play_until_idle()
	assert_false((launcher.get_node("FlyingPack") as PackView).visible)
	assert_eq(launcher.shown_pack(), "blue")


func test_pack_pixels_are_whole_and_from_their_own_ramp() -> void:
	for kind: String in ["blue", "red"]:
		var ramp: Array[Color] = Palette.BLUE_PACK if kind == "blue" else Palette.RED_PACK
		for grown: bool in [false, true]:
			for bright: bool in [false, true]:
				var dots: Dictionary[Vector2i, Color] = PackView.pixels(kind, grown, bright)
				assert_false(dots.is_empty())
				for dot: Vector2i in dots:
					assert_true(ramp.has(dots[dot]), "%s uses only its own ramp" % kind)
	assert_true(PackView.pixels("").is_empty())


func test_the_grown_frame_is_one_pixel_bigger() -> void:
	assert_true(PackView.pixels("blue", true).has(Vector2i(0, -9)))
	assert_false(PackView.pixels("blue").has(Vector2i(0, -9)))
	assert_ne(PackView.pixels("blue", false, true), PackView.pixels("blue"), "bright lifts the ramp")


## Inner sky corners and edge midpoints.
func _corners_and_edges() -> Array[Vector2i]:
	var lo: Vector2i = inner.position
	var hi: Vector2i = inner.end - Vector2i.ONE
	var mid: Vector2i = (lo + hi) / 2
	return [lo, Vector2i(hi.x, lo.y), Vector2i(lo.x, hi.y), hi,
		Vector2i(mid.x, lo.y), Vector2i(mid.x, hi.y), Vector2i(lo.x, mid.y), Vector2i(hi.x, mid.y)]


## The pull that aims straight at `target` (aim_target inverted).
func _pull_toward(target: Vector2i) -> Vector2:
	var away := Vector2(ORIGIN - target)
	var length: float = Launcher.MIN_PULL + (away.length() - Launcher.MIN_REACH) / Launcher.AIM_GAIN
	return away.normalized() * length


func _pull_and_release(pull: Vector2) -> void:
	assert_true(_press(Vector2i.ZERO), "the press lands on the pack")
	_drag(pull)
	assert_true(_release())


func _press(point: Vector2i) -> bool:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(point)
	e.pressed = true
	return launcher.handle_pointer(e)


func _drag(point: Vector2) -> bool:
	var e := InputEventScreenDrag.new()
	e.position = point
	return launcher.handle_pointer(e)


func _release() -> bool:
	var e := InputEventScreenTouch.new()
	e.pressed = false
	return launcher.handle_pointer(e)


func _step() -> void:
	sequencer.advance(STEP)
	launcher.advance(STEP)


func _play_until_idle() -> void:
	sequencer.advance(0.0)
	var elapsed: float = 0.0
	while sequencer.is_busy() and elapsed < 10.0:
		_step()
		elapsed += STEP
	_step()
