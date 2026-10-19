extends GutTest
## Animation timings on a wide sky (docs/wide_sky_design.md §4, commit 15): the lion's breath, the
## scythe's sweep, a launch's flight and the wave's rush each keep today's time over the distance
## they cover on the portrait frame, and take longer at the same speed past it. These are scene
## timings the identity guard can't see, so the portrait cases pin them to the old constants.

const Fixtures := preload("res://tests/fixtures.gd")
const ORIGIN := Vector2i(90, 270)

var _portrait_skies: Array[Rect2i] = [Fixtures.SKY, ScreenZones.play_sky(102)]


func _stage(map: StarMap, sky: Rect2i) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(1), sky, map)


## Every 10th pixel of `sky`, both ways, and its corners.
func _points(sky: Rect2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = [sky.position, sky.end - Vector2i.ONE, Vector2i(sky.position.x, sky.end.y - 1), Vector2i(sky.end.x - 1, sky.position.y)]
	for x: int in range(sky.position.x, sky.end.x, 10):
		for y: int in range(sky.position.y, sky.end.y, 10):
			points.append(Vector2i(x, y))
	return points


# --- helpers ----------------------------------------------------------------------------------

func test_the_stretch_is_one_up_to_the_home_distance_then_in_proportion() -> void:
	assert_eq(ScreenZones.stretch(0.0, 100.0), 1.0)
	assert_eq(ScreenZones.stretch(100.0, 100.0), 1.0)
	assert_eq(ScreenZones.stretch(250.0, 100.0), 2.5)
	assert_eq(ScreenZones.stretch(50.0, 0.0), 1.0, "no home distance: no stretch")
	assert_almost_eq(ScreenZones.farthest_corner(Vector2i(0, 78), Fixtures.SKY), Vector2(179, 171).length(), 0.001, "the far corner's last pixel")


# --- the lion's breath ------------------------------------------------------------------------

func test_a_portrait_breath_keeps_breath_time_from_anywhere() -> void:
	for sky: Rect2i in _portrait_skies:
		var run: RunState = _stage(StarMap.leo_final(), sky)
		for at: Vector2i in _points(sky):
			assert_eq(HeatView.breath_time(at, run.sky_rect, run.frame_rect), HeatView.BREATH_TIME, "%s on %s" % [at, sky])


func test_a_wide_breath_rolls_on_at_the_same_speed() -> void:
	var run: RunState = _stage(StarMap.leo_final(), Fixtures.WIDE_SKY)
	var at: Vector2i = run.frame_rect.get_center()
	var lasts: float = HeatView.breath_time(at, run.sky_rect, run.frame_rect)
	var ratio: float = ScreenZones.farthest_corner(at, run.sky_rect) / ScreenZones.farthest_corner(at, run.frame_rect)
	assert_gt(ratio, 1.5)
	assert_almost_eq(lasts, HeatView.BREATH_TIME * ratio, 0.0001)
	assert_false(HeatView.breath_pixels(at, HeatView.BREATH_TIME, run.sky_rect, lasts).is_empty(), "still rolling where a portrait breath stops")
	assert_true(HeatView.breath_pixels(at, lasts, run.sky_rect, lasts).is_empty(), "gone once its time is up")
	# Same speed: the ring's front at a given time doesn't depend on the sky.
	var portrait: Dictionary[Vector2i, Color] = HeatView.breath_pixels(Vector2i(90, 164), 0.2, Fixtures.SKY)
	var wide: Dictionary[Vector2i, Color] = HeatView.breath_pixels(Vector2i(90, 164), 0.2, Fixtures.SKY, lasts)
	assert_eq(wide, portrait)


func test_a_wide_breath_on_the_view_lasts_its_breath_time() -> void:
	for sky: Rect2i in [Fixtures.SKY, Fixtures.WIDE_SKY] as Array[Rect2i]:
		var run: RunState = _stage(StarMap.leo_final(), sky)
		var view := HeatView.new()
		add_child_autofree(view)
		view.setup(run, null)
		view.set_process(false)
		var at: Vector2i = run.frame_rect.get_center()
		var lasts: float = HeatView.breath_time(at, run.sky_rect, run.frame_rect)
		view.flash_breath(at)
		view.advance(lasts - 0.01)
		assert_true(view.is_breathing(), "%s: breathing until %.2f s" % [sky, lasts])
		view.advance(0.02)
		assert_false(view.is_breathing(), "%s: over after it" % sky)


# --- the scythe -------------------------------------------------------------------------------

func test_the_sweep_keeps_its_time_on_a_portrait_sky_and_its_speed_on_a_wide_one() -> void:
	for sky: Rect2i in _portrait_skies:
		assert_eq(HarvestView.sweep_time(sky), HarvestView.SWEEP_TIME, str(sky))
	assert_almost_eq(HarvestView.sweep_time(Fixtures.WIDE_SKY), HarvestView.SWEEP_TIME * 640.0 / 180.0, 0.0001, "300 px/s over 640 columns")


func test_the_blade_crosses_a_wide_sky_in_its_sweep_time() -> void:
	var run: RunState = _stage(StarMap.virgo_final(), Fixtures.WIDE_SKY)
	var view := HarvestView.new()
	add_child_autofree(view)
	view.setup(run, null)
	view.set_process(false)
	var lasts: float = view.sweep()
	assert_eq(lasts, HarvestView.sweep_time(run.sky_rect))
	assert_almost_eq(view.cut_delay(run.sky_rect.end.x - 1), lasts, 0.01, "it reaches the far edge as it ends")
	assert_almost_eq(view.cut_delay(run.sky_rect.position.x + 180), HarvestView.SWEEP_TIME, 0.001, "180 columns in SWEEP_TIME, as on a phone")
	view.advance(HarvestView.SWEEP_TIME + 0.01)
	assert_true(view.is_sweeping(), "still crossing where a portrait sweep ends")
	view.advance(lasts - HarvestView.SWEEP_TIME)
	assert_false(view.is_sweeping())


func test_a_portrait_sweep_still_takes_sweep_time() -> void:
	var run: RunState = _stage(StarMap.virgo_final(), Fixtures.SKY)
	var view := HarvestView.new()
	add_child_autofree(view)
	view.setup(run, null)
	view.set_process(false)
	assert_eq(view.sweep(), HarvestView.SWEEP_TIME)
	assert_eq(view.cut_delay(run.sky_rect.end.x), HarvestView.SWEEP_TIME)


# --- the flight -------------------------------------------------------------------------------

func test_every_portrait_flight_keeps_flight_time() -> void:
	for sky: Rect2i in _portrait_skies:
		var run: RunState = Fixtures.run({}, 1, sky)
		# From the slingshot's fork and from round the telescope's mouth.
		for from: Vector2i in [ORIGIN, Vector2i(80, 290), Vector2i(70, 284), Vector2i(96, 280)] as Array[Vector2i]:
			for burst: Vector2i in _points(sky):
				assert_eq(Launcher.flight_time(from, burst, run.frame_rect), Launcher.FLIGHT_TIME, "%s to %s on %s" % [from, burst, sky])


func test_a_wide_flight_past_the_frame_keeps_the_portrait_top_speed() -> void:
	var run: RunState = Fixtures.run({}, 1, Fixtures.WIDE_SKY)
	var frame: Rect2i = run.frame_rect
	for burst: Vector2i in _points(frame):
		assert_eq(Launcher.flight_time(ORIGIN, burst, frame), Launcher.FLIGHT_TIME, "inside the frame: %s" % burst)
	var corner: Vector2i = StarScatter.inner_rect(run.sky_rect).position
	var far: float = ScreenZones.farthest_corner(ORIGIN, frame)
	var d: float = Vector2(corner - ORIGIN).length()
	assert_gt(d, far * 1.5)
	assert_almost_eq(Launcher.flight_time(ORIGIN, corner, frame), Launcher.FLIGHT_TIME * d / far, 0.0001)


# --- the wave ---------------------------------------------------------------------------------

func _seam(run: RunState) -> SeamView:
	var view := SeamView.new()
	add_child_autofree(view)
	view.setup(run)
	view.set_process(false)
	return view


func test_a_portrait_wave_keeps_sweep_time_every_way() -> void:
	for map: StarMap in [StarMap.pisces_north_fish(), StarMap.pisces_final()]:
		for sky: Rect2i in _portrait_skies:
			var view: SeamView = _seam(_stage(map, sky))
			for way: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT] as Array[Vector2i]:
				assert_eq(view.rush_seconds(way), SeamView.SWEEP_TIME, "%s %s %s" % [map.id, sky, way])
			for great: bool in [false, true]:
				view.sweep(Vector2i.RIGHT, Vector2i.ZERO, [] as Array[Vector2i], great)
				assert_eq(view.sweep_wait(), SeamView.sweep_hold(), "%s great %s" % [map.id, great])


func test_a_wide_wave_across_the_columns_rushes_on_at_the_same_speed() -> void:
	var run: RunState = _stage(StarMap.pisces_final(), Fixtures.WIDE_SKY)
	var view: SeamView = _seam(run)
	var line: int = run.wave.middle.x
	var span: float = float(line - run.sky_rect.position.x)
	var home: float = float(line - run.frame_rect.position.x)
	assert_gt(span, home * 2.0)
	var rush: float = view.rush_seconds(Vector2i.LEFT)
	assert_almost_eq(rush, SeamView.SWEEP_TIME * span / home, 0.0001)
	assert_almost_eq(view.sweep_delay(Vector2i.LEFT, Vector2i(run.sky_rect.position.x, 100)), SeamView.WINDUP_TIME + rush, 0.0001, "it reaches the far edge as its rush ends")
	view.sweep(Vector2i.LEFT, Vector2i.RIGHT)
	assert_almost_eq(view.sweep_wait(), SeamView.WINDUP_TIME + rush, 0.0001)
	view.advance(SeamView.WINDUP_TIME + SeamView.SWEEP_TIME + SeamView.CRASH_TIME + 0.01)
	assert_true(view.is_sweeping(), "still rushing where a portrait wave has crashed")
	view.advance(rush - SeamView.SWEEP_TIME)
	assert_false(view.is_sweeping())


func test_a_wide_great_wave_waits_for_its_longer_side() -> void:
	var run: RunState = _stage(StarMap.pisces_final(), Fixtures.WIDE_SKY)
	var view: SeamView = _seam(run)
	view.sweep(Vector2i.RIGHT, Vector2i.ZERO, [] as Array[Vector2i], true)
	var longer: float = maxf(view.rush_seconds(Vector2i.LEFT), view.rush_seconds(Vector2i.RIGHT))
	assert_almost_eq(view.sweep_wait(), SeamView.WINDUP_TIME + longer, 0.0001)


func test_a_wide_wave_up_or_down_keeps_sweep_time() -> void:
	# The frame is the sky's full height, so a line across runs as far either way as on a phone.
	var view: SeamView = _seam(_stage(StarMap.pisces_north_fish(), Fixtures.WIDE_SKY))
	assert_eq(view.rush_seconds(Vector2i.UP), SeamView.SWEEP_TIME)
	assert_eq(view.rush_seconds(Vector2i.DOWN), SeamView.SWEEP_TIME)


func test_a_side_is_drawn_until_its_own_crash_ends_and_then_not() -> void:
	var sky: Rect2i = Fixtures.WIDE_SKY
	var rush: float = 1.0
	var end: float = SeamView.WINDUP_TIME + rush + SeamView.CRASH_TIME
	assert_false(SeamView.sweep_pixels(-1, 90, true, sky, SeamView.WINDUP_TIME + SeamView.SWEEP_TIME + 0.01, rush).is_empty(), "rushing")
	assert_false(SeamView.sweep_pixels(-1, 90, true, sky, end - 0.01, rush).is_empty(), "crashing")
	assert_true(SeamView.sweep_pixels(-1, 90, true, sky, end, rush).is_empty(), "over")
