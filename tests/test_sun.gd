extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const SunScene := preload("res://game/scenes/sun.tscn")

var run: RunState
var sun: SunView
var sequencer: EventSequencer


func before_each() -> void:
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	sun = SunScene.instantiate()
	add_child_autofree(sun)
	sun.set_process(false)
	sun.setup(run, sequencer)


func test_the_sun_sits_centred_in_its_zone() -> void:
	assert_eq(sun.position, Vector2(90, 39))
	for p_ignited: bool in [false, true]:
		var dots: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, p_ignited, true)
		var outside: Array = dots.keys().filter(func(o: Vector2i) -> bool: return not ScreenZones.SUN.has_point(o + Vector2i(sun.position)))
		assert_eq(outside, [], "every pixel in the Sun zone (ignited: %s)" % p_ignited)


func test_a_dark_sun_is_all_dim_ramp() -> void:
	assert_eq(sun.progress(), 0.0)
	assert_eq(sun.fill_rows(), 0)
	assert_eq(sun.lit_rays(), 0)
	for colour: Color in SunView.pixels(0, 0, false, false).values():
		assert_true(colour in SunView.DIM_RAMP, "no starlight in a dark Sun: %s" % colour.to_html(false))


func test_the_frame_follows_light_over_the_target() -> void:
	run.light = 50
	sun.setup(run, sequencer)
	assert_eq(sun.progress(), 0.5)
	assert_eq(sun.fill_rows(), 17, "half of 35 rows, rounded down")
	assert_eq(sun.lit_rays(), 6)
	run.light = 99
	sun.setup(run, sequencer)
	assert_eq(sun.fill_rows(), SunView.DISC_ROWS - 1, "full only at the target")
	assert_eq(sun.lit_rays(), SunView.RAYS - 1, "the last ray lights at the target")
	run.light = 130
	sun.setup(run, sequencer)
	assert_eq(sun.progress(), 1.0, "past the target stays full")


func test_more_light_never_means_fewer_lit_pixels() -> void:
	var before: int = -1
	for rows: int in range(0, SunView.DISC_ROWS + 1):
		var rays: int = floori(float(rows) / SunView.DISC_ROWS * SunView.RAYS)
		var lit: int = _count_lit(SunView.pixels(rows, rays, false, false))
		assert_gte(lit, before, "%d rows" % rows)
		before = lit


func test_light_pools_from_the_bottom() -> void:
	var dots: Dictionary[Vector2i, Color] = SunView.pixels(5, 0, false, false)
	assert_true(dots[Vector2i(0, SunView.RADIUS)] in SunView.LIT_RAMP, "bottom row lit")
	assert_true(dots[Vector2i(0, -SunView.RADIUS)] in SunView.DIM_RAMP, "top row still dim")


func test_rays_light_clockwise_from_twelve() -> void:
	var root: int = SunView.RADIUS + SunView.RAY_GAP
	var dots: Dictionary[Vector2i, Color] = SunView.pixels(0, 3, false, false)
	assert_eq(dots[Vector2i(0, -root)], Palette.C0, "12 o'clock lights first")
	assert_eq(dots[Vector2i(0, -root - SunView.LIT_RAY_LENGTH + 1)], Palette.C3, "a lit ray ends in C3")
	assert_true(dots[Vector2i(root, 0)] in SunView.DIM_RAMP, "3 o'clock is the 4th ray: still dim")
	assert_eq(dots[Vector2i(-root - SunView.DIM_RAY_LENGTH + 1, 0)], Palette.S1, "a dim ray is short and ends in S1")


func test_light_lands_with_its_particles_and_pulses_each_time() -> void:
	_link_sequence()
	sequencer.advance(0.0)
	assert_eq(sun.progress(), 0.0, "the combo played, but its light is still flying")
	assert_false(sun.is_pulsing())
	sun.receive_light(10)
	assert_eq(sun.progress(), 0.1)
	assert_true(sun.is_pulsing())
	sun.advance(SunView.PULSE_TIME)
	assert_false(sun.is_pulsing(), "a pulse is short")
	sun.receive_light(15)
	assert_eq(sun.progress(), 0.25, "the sequence's 25 light, once all of it landed")
	assert_true(sun.is_pulsing(), "every landing pulses")


func test_a_pulse_lifts_every_pixel_one_step() -> void:
	var calm: Dictionary[Vector2i, Color] = SunView.pixels(10, 3, false, false)
	var pulse: Dictionary[Vector2i, Color] = SunView.pixels(10, 3, false, true)
	assert_eq(calm.keys(), pulse.keys(), "same shape, no scaling")
	assert_eq(calm[Vector2i(0, 10)], Palette.C1)
	assert_eq(pulse[Vector2i(0, 10)], Palette.C0, "C1 light lifts to C0")
	assert_eq(calm[Vector2i(0, -SunView.RADIUS)], Palette.S1)
	assert_eq(pulse[Vector2i(0, -SunView.RADIUS)], Palette.S2, "S1 rim lifts to S2")


func test_a_run_already_won_shows_an_ignited_sun() -> void:
	run.light = 100
	run.outcome = RunState.Outcome.WON
	sun.setup(run, sequencer)
	assert_true(sun.is_ignited(), "a run that is already won shows an ignited Sun")


func test_a_new_run_drops_light_still_in_flight() -> void:
	_link_sequence()
	sequencer.advance(0.0)
	var fresh: RunState = Fixtures.run()
	sequencer.bind(fresh)
	sun.setup(fresh, sequencer)
	sun.receive_light(5)
	assert_eq(sun.progress(), 0.05, "the old run's flight no longer counts")


func test_a_big_bang_brings_no_light_and_no_pulse() -> void:
	run.force_next_big_bang = true
	assert_true(Fixtures.launch(run, Vector2i(90, 150)))
	sequencer.advance(0.0)
	assert_eq(sun.progress(), 0.0)
	assert_false(sun.is_pulsing())


func test_winning_ignites_the_sun_and_holds_the_sequence() -> void:
	run.light = 80
	sun.setup(run, sequencer)
	_link_sequence()
	assert_eq(run.outcome, RunState.Outcome.WON)
	sequencer.advance(0.0)
	assert_false(sun.is_igniting(), "the winning light is still flying")
	assert_true(sequencer.is_busy(), "the win waits for it")
	sequencer.advance(1.0)
	sun.receive_light(20)
	assert_false(sun.is_igniting(), "5 light still to land")
	sun.receive_light(5)
	assert_true(sun.is_igniting(), "the last light ignites it")
	assert_eq(sun.ignite_frame(), 1)
	assert_true(sequencer.is_busy(), "the win waits for the ignition")
	sequencer.advance(SunView.IGNITE_TIME - 0.2)
	assert_true(sequencer.is_busy())
	sun.advance(SunView.IGNITE_TIME / 2)
	assert_true(sun.is_igniting())
	assert_between(sun.ignite_frame(), 2, SunView.IGNITE_FRAMES - 1, "the glow is spreading")
	sun.advance(SunView.IGNITE_TIME / 2)
	assert_true(sun.is_ignited())
	assert_eq(sun.ignite_frame(), SunView.IGNITE_FRAMES)
	sequencer.advance(0.2)
	assert_false(sequencer.is_busy())


func test_an_ignited_sun_has_no_dim_pixels() -> void:
	var dots: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, true, false)
	for colour: Color in dots.values():
		assert_true(colour in SunView.LIT_RAMP, "starlight only: %s" % colour.to_html(false))


func test_the_sky_glow_spreads_over_the_sky_in_halo_colours() -> void:
	var centre := Vector2i(sun.position)
	var reach: Array[int] = []
	for frame: int in [1, SunView.IGNITE_FRAMES]:
		var glow: Image = SunView.sky_glow(frame, centre)
		assert_eq(glow.get_size(), Vector2i(180, ScreenZones.SKY.end.y), "down to the sky's bottom edge")
		var farthest: int = 0
		var off_palette: int = 0
		for y: int in glow.get_height():
			for x: int in glow.get_width():
				var c: Color = glow.get_pixel(x, y)
				if c.a == 0.0:
					continue
				if c.a != 1.0 or not (c.is_equal_approx(Palette.C4) or c.is_equal_approx(Palette.C5)):
					off_palette += 1
				farthest = maxi(farthest, y)
		assert_eq(off_palette, 0, "opaque C4/C5 halo pixels only (frame %d)" % frame)
		reach.append(farthest)
	assert_lt(reach[0], 110, "the first frame stays near the Sun")
	assert_gt(reach[1], ScreenZones.SKY.end.y - 5, "the last frame reaches the bottom of the sky")


func test_the_9_16_glow_is_unchanged() -> void:
	var area: Rect2i = SunView.glow_area(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN))
	assert_eq(area, Rect2i(0, 0, 180, ScreenZones.SKY.end.y))
	assert_eq(SunView.glow_reach(ScreenZones.SUN_CENTRE, area), 230, "the old fixed reach, from the Sun to the far corner")


## Phones from the issue, and a wide tablet: the glow's last frame covers every visible corner of
## the sky, margins included, and its first frame stays near the Sun.
func test_the_last_glow_frame_fills_the_whole_visible_sky_on_any_screen() -> void:
	for window: Vector2i in [Vector2i(1170, 2532), Vector2i(412, 915), Vector2i(1080, 1920), Vector2i(1536, 2048)]:
		var visible: Vector2i = ScreenZones.fill_size(window)
		var offset: Vector2i = ScreenZones.game_offset(Vector2(visible))
		var screen := Rect2i(-offset, visible)
		var centre: Vector2i = ScreenZones.sun_centre(offset.y)
		var area: Rect2i = SunView.glow_area(screen)
		assert_eq(area.position, screen.position, "%s: from the screen's top-left corner" % window)
		assert_eq(area.end, Vector2i(screen.end.x, ScreenZones.SKY.end.y), "%s: to its right edge, down to the sky's bottom" % window)
		var glow: Image = SunView.sky_glow(SunView.IGNITE_FRAMES, centre, area)
		assert_eq(glow.get_size(), area.size)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(area.size.x - 4, 0), Vector2i(0, area.size.y - 4), area.size - Vector2i(4, 4)]:
			assert_true(_lit_in(glow, Rect2i(corner, Vector2i(4, 4))), "%s: the corner at %s is lit" % [window, corner + area.position])
		# No unlit strip down either margin: every 4x4 block of the glow's outer ring has light.
		for y: int in range(SunView.RADIUS + 20, area.size.y - 4, 4):
			assert_true(_lit_in(glow, Rect2i(0, y, 4, 4)), "%s: left edge row %d" % [window, y])
			assert_true(_lit_in(glow, Rect2i(area.size.x - 4, y, 4, 4)), "%s: right edge row %d" % [window, y])
		var first: Image = SunView.sky_glow(1, centre, area)
		assert_false(_lit_in(first, Rect2i(0, area.size.y - 4, 4, 4)), "%s: the first frame stays near the Sun" % window)


func test_the_glow_dither_runs_on_from_the_game_into_the_margins() -> void:
	var centre: Vector2i = ScreenZones.SUN_CENTRE
	var narrow: Image = SunView.sky_glow(SunView.IGNITE_FRAMES, centre, Rect2i(0, 0, 180, 250))
	var wide: Image = SunView.sky_glow(SunView.IGNITE_FRAMES, centre, Rect2i(-20, -30, 220, 280))
	var differ: int = 0
	for y: int in range(0, 250, 3):
		for x: int in range(0, 180, 3):
			if narrow.get_pixel(x, y).a != wide.get_pixel(x + 20, y + 30).a:
				differ += 1
	assert_eq(differ, 0, "same pixels where the areas overlap, apart from the reach")


func test_fit_screen_rebuilds_the_glow_for_the_new_screen() -> void:
	sun.fit_screen(Rect2i(-8, -40, 196, 360))
	assert_eq(sun.get("_screen"), Rect2i(-8, -40, 196, 360))


func _lit_in(image: Image, block: Rect2i) -> bool:
	for y: int in range(block.position.y, block.end.y):
		for x: int in range(block.position.x, block.end.x):
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false


func test_an_ignited_sun_idles_with_shimmering_rays_and_a_moving_glint() -> void:
	var a: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, true, false, 0)
	var b: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, true, false, 1)
	var tip := Vector2i(0, -(SunView.RADIUS + SunView.RAY_GAP + SunView.LIT_RAY_LENGTH - 1))
	var next_tip := Vector2i((Vector2.from_angle(-PI / 2 + TAU / SunView.RAYS) * (SunView.RADIUS + SunView.RAY_GAP + SunView.LIT_RAY_LENGTH - 1)).round())
	assert_eq(a.get(tip), Palette.C3, "12 o'clock at full length")
	assert_ne(b.get(tip), Palette.C3, "then a pixel shorter")
	assert_ne(a.get(next_tip), Palette.C3, "its neighbour does the opposite")
	assert_eq(b.get(next_tip), Palette.C3)
	var core_changes: int = 0
	for dy: int in range(-5, 6):
		for dx: int in range(-5, 6):
			if a[Vector2i(dx, dy)] != b[Vector2i(dx, dy)]:
				core_changes += 1
	assert_gt(core_changes, 0, "the core's glint moves")


func test_rays_only_shimmer_once_ignited() -> void:
	var a: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, false, false, 0)
	var b: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, false, false, 1)
	var tip := Vector2i(0, -(SunView.RADIUS + SunView.RAY_GAP + SunView.LIT_RAY_LENGTH - 1))
	assert_eq(a.get(tip), Palette.C3)
	assert_eq(b.get(tip), Palette.C3, "a full Sun that hasn't ignited keeps its rays still")


func test_a_dark_sun_smoulders() -> void:
	var a: Dictionary[Vector2i, Color] = SunView.pixels(0, 0, false, false, 0)
	var b: Dictionary[Vector2i, Color] = SunView.pixels(0, 0, false, false, 1)
	for i: int in SunView.EMBERS.size():
		var at: Vector2i = SunView.EMBERS[i]
		assert_ne(a[at], b[at], "ember %s swaps" % at)
		assert_true(a[at] in [Palette.S3, Palette.S4] and b[at] in [Palette.S3, Palette.S4])
	var ring: Callable = func(dots: Dictionary[Vector2i, Color]) -> int:
		return dots.keys().filter(func(o: Vector2i) -> bool:
			var d: float = Vector2(o).length()
			return d >= SunView.RADIUS + 2 and d < SunView.RADIUS + 6 and dots[o] == Palette.S1).size()
	assert_lt(ring.call(b), ring.call(a), "the dim halo breathes")
	for colour: Color in b.values():
		assert_true(colour in SunView.DIM_RAMP, "still no starlight: %s" % colour.to_html(false))


func test_embers_stay_off_the_craters_and_on_the_disc() -> void:
	for ember: Vector2i in SunView.EMBERS:
		assert_lte(ember.length_squared(), SunView.RADIUS * SunView.RADIUS)
		for crater: Vector3i in SunView.CRATERS:
			assert_gt(Vector2(ember - Vector2i(crater.x, crater.y)).length(), float(crater.z), "%s clear of the craters" % ember)


func test_lit_light_covers_the_embers() -> void:
	var dots: Dictionary[Vector2i, Color] = SunView.pixels(SunView.DISC_ROWS, SunView.RAYS, false, false, 1)
	for ember: Vector2i in SunView.EMBERS:
		assert_true(dots[ember] in SunView.LIT_RAMP, "no ember under the light")


func test_the_sky_glow_holds_still_once_ignited() -> void:
	run.light = 80
	sun.setup(run, sequencer)
	_link_sequence()
	sequencer.advance(0.0)
	sun.receive_light(25)
	sun.advance(SunView.IGNITE_TIME)
	assert_true(sun.is_ignited())
	var frame: int = sun.ignite_frame()
	sun.advance(SunView.RIPPLE_TIME)
	assert_eq(sun.ignite_frame(), frame, "the glow keeps its last frame while the Sun idles")


func test_a_new_run_brings_back_a_dark_sun() -> void:
	run.light = 80
	sun.setup(run, sequencer)
	_link_sequence()
	sequencer.advance(0.0)
	sun.receive_light(25)
	sun.advance(SunView.IGNITE_TIME)
	assert_true(sun.is_ignited())
	var fresh: RunState = Fixtures.run()
	sequencer.bind(fresh)
	sun.setup(fresh, sequencer)
	assert_false(sun.is_ignited())
	assert_eq(sun.ignite_frame(), 0)
	assert_eq(sun.progress(), 0.0)


func test_a_sun_without_a_run_stays_dark() -> void:
	var lone: SunView = SunScene.instantiate()
	add_child_autofree(lone)
	lone.advance(SunView.RIPPLE_TIME)
	assert_eq(lone.progress(), 0.0)
	assert_eq(lone.fill_rows(), 0)
	assert_eq(lone.ignite_frame(), 0)
	await wait_process_frames(2, "draws and processes with no run")
	assert_engine_error_count(0)


func test_every_sun_pixel_is_a_palette_colour() -> void:
	var palette: Array = SunView.DIM_RAMP + SunView.LIT_RAMP
	for p_ignited: bool in [false, true]:
		for p_lifted: bool in [false, true]:
			for rows: int in [0, 1, 17, SunView.DISC_ROWS]:
				for colour: Color in SunView.pixels(rows, floori(float(rows) / SunView.DISC_ROWS * SunView.RAYS), p_ignited, p_lifted, rows % 2).values():
					assert_true(colour in palette and colour.a == 1.0, colour.to_html())


## Links a small, a medium and a big star: a sequence, worth 25 light in the fixtures.
func _link_sequence() -> void:
	var ids: Array[int] = []
	for i: int in 3:
		ids.append(run.add_star(i as Star.Size, Vector2i(70 + 20 * i, 150)).id)
	assert_eq(run.link(ids), "sequence")


func _count_lit(dots: Dictionary[Vector2i, Color]) -> int:
	return dots.values().filter(func(c: Color) -> bool: return c in SunView.LIT_RAMP).size()
