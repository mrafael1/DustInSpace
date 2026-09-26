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


func test_light_waits_for_the_combo_to_play_then_pulses() -> void:
	_link_sequence()
	assert_eq(sun.progress(), 0.0, "not before its event plays")
	sequencer.advance(0.0)
	assert_eq(sun.progress(), 0.25, "the sequence's 25 light")
	assert_true(sun.is_pulsing())
	sun.advance(SunView.PULSE_TIME)
	assert_false(sun.is_pulsing(), "a pulse is short")


func test_a_pulse_lifts_every_pixel_one_step() -> void:
	var calm: Dictionary[Vector2i, Color] = SunView.pixels(10, 3, false, false)
	var pulse: Dictionary[Vector2i, Color] = SunView.pixels(10, 3, false, true)
	assert_eq(calm.keys(), pulse.keys(), "same shape, no scaling")
	assert_eq(calm[Vector2i(0, 10)], Palette.C1)
	assert_eq(pulse[Vector2i(0, 10)], Palette.C0, "C1 light lifts to C0")
	assert_eq(calm[Vector2i(0, -SunView.RADIUS)], Palette.S1)
	assert_eq(pulse[Vector2i(0, -SunView.RADIUS)], Palette.S2, "S1 rim lifts to S2")


func test_a_big_bang_brings_no_light_and_no_pulse() -> void:
	run.force_next_big_bang = true
	assert_true(run.launch(Vector2i(90, 150)))
	sequencer.advance(0.0)
	assert_eq(sun.progress(), 0.0)
	assert_false(sun.is_pulsing())


func test_winning_ignites_the_sun_and_holds_the_sequence() -> void:
	run.light = 80
	sun.setup(run, sequencer)
	_link_sequence()
	assert_eq(run.outcome, RunState.Outcome.WON)
	sequencer.advance(0.0)
	assert_true(sun.is_igniting())
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


func test_a_new_run_brings_back_a_dark_sun() -> void:
	run.light = 80
	sun.setup(run, sequencer)
	_link_sequence()
	sequencer.advance(0.0)
	sun.advance(SunView.IGNITE_TIME)
	assert_true(sun.is_ignited())
	var fresh: RunState = Fixtures.run()
	sequencer.bind(fresh)
	sun.setup(fresh, sequencer)
	assert_false(sun.is_ignited())
	assert_eq(sun.ignite_frame(), 0)
	assert_eq(sun.progress(), 0.0)


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
