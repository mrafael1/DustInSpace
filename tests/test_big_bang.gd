extends GutTest
## The Big Bang sequence: timeline, hold, flash, rings, debris, banner and dust stream.

const Fixtures := preload("res://tests/fixtures.gd")
const BigBangScene := preload("res://game/fx/big_bang.tscn")

var run: RunState
var sequencer: EventSequencer
var big_bang: BigBangSequence


func before_each() -> void:
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	big_bang = BigBangScene.instantiate()
	add_child_autofree(big_bang)
	big_bang.set_process(false)
	big_bang.setup(run, sequencer)


func test_the_timeline_follows_the_game_feel_script() -> void:
	assert_almost_eq(BigBangSequence.FREEZE_AT, 0.26, 0.001, "freeze at +260 ms")
	assert_almost_eq(BigBangSequence.COLLAPSE_TIME, 0.75, 0.001)
	assert_almost_eq(BigBangSequence.PAUSE_TIME, 0.5, 0.001, "a short silent pause")
	assert_almost_eq(BigBangSequence.BANG_AT, 1.51, 0.001)
	assert_almost_eq(BigBangSequence.INPUT_BACK_AFTER, 1.1, 0.001)
	assert_almost_eq(BigBangSequence.BANNER_TIME, 2.5, 0.001)
	assert_eq(BigBangSequence.RINGS, 3)
	assert_eq(BigBangSequence.DEBRIS, 200)


func test_input_comes_back_about_a_second_after_the_bang() -> void:
	_big_bang()
	assert_true(big_bang.is_playing())
	sequencer.advance(BigBangSequence.BANG_AT + BigBangSequence.INPUT_BACK_AFTER - 0.05)
	assert_true(sequencer.is_busy(), "held through the collapse and the bang")
	sequencer.advance(0.1)
	assert_false(sequencer.is_busy())


func test_the_bang_flashes_full_white_then_fades_in_dithered_steps() -> void:
	_big_bang()
	big_bang.advance(BigBangSequence.BANG_AT - 0.01)
	assert_eq(big_bang.flash_frame(), -1, "no flash before the bang")
	big_bang.advance(0.02)
	assert_eq(big_bang.flash_frame(), 0, "full white first")
	big_bang.advance(BigBangSequence.FLASH_TIME * 0.5)
	assert_eq(big_bang.flash_frame(), 2)
	big_bang.advance(BigBangSequence.FLASH_TIME * 0.5)
	assert_eq(big_bang.flash_frame(), -1, "gone after ~700 ms")


func test_the_banner_shows_the_dust_for_two_and_a_half_seconds() -> void:
	_big_bang()
	assert_false(big_bang.is_banner_shown(), "no banner before the bang: the surprise")
	big_bang.advance(BigBangSequence.BANG_AT + 0.01)
	assert_true(big_bang.is_banner_shown())
	assert_eq(big_bang.banner_text(), "BIG BANG +%d" % run.balance.big_bang_base_dust)
	big_bang.advance(BigBangSequence.BANNER_TIME)
	assert_false(big_bang.is_banner_shown())


func test_the_banner_font_has_its_letters() -> void:
	for c: String in "BIG BANG+0123456789":
		assert_true(HudText.PRIMARY_FONT.has_char(c.unicode_at(0)), c)


func test_the_white_point_pulses_between_a_pixel_and_a_plus() -> void:
	assert_eq(BigBangSequence.point_pixels(0.0).size(), 1)
	assert_eq(BigBangSequence.point_pixels(BigBangSequence.POINT_PULSE).size(), 5)
	assert_eq(BigBangSequence.point_pixels(2 * BigBangSequence.POINT_PULSE).size(), 1)


func test_a_black_hole_opens_during_the_collapse_then_implodes_into_the_point() -> void:
	assert_eq(BigBangSequence.hole_radius(-0.01), 0, "no hole before the freeze")
	assert_gt(BigBangSequence.hole_radius(0.0), 0, "it opens at the freeze")
	assert_lt(BigBangSequence.hole_radius(BigBangSequence.COLLAPSE_TIME * 0.2), BigBangSequence.hole_radius(BigBangSequence.COLLAPSE_TIME * 0.9), "it grows")
	assert_eq(BigBangSequence.hole_radius(BigBangSequence.COLLAPSE_TIME - 0.001), BigBangSequence.HOLE_RADIUS)
	assert_lt(BigBangSequence.hole_radius(BigBangSequence.COLLAPSE_TIME + BigBangSequence.HOLE_IMPLODE * 0.7), BigBangSequence.HOLE_RADIUS, "then implodes")
	assert_eq(BigBangSequence.hole_radius(BigBangSequence.COLLAPSE_TIME + BigBangSequence.HOLE_IMPLODE), 0, "leaving the white point")
	assert_lt(BigBangSequence.COLLAPSE_TIME + BigBangSequence.HOLE_IMPLODE, BigBangSequence.COLLAPSE_TIME + BigBangSequence.PAUSE_TIME, "inside the pause")


func test_the_hole_is_black_in_a_photon_ring_with_a_lensed_arc_and_a_front_band() -> void:
	var r: int = BigBangSequence.HOLE_RADIUS
	var a: Dictionary[Vector2i, Color] = BigBangSequence.hole_pixels(r, 0)
	var b: Dictionary[Vector2i, Color] = BigBangSequence.hole_pixels(r, 1)
	assert_eq(a[Vector2i(0, -r + 1)], Palette.N0, "a black disc")
	assert_true(a[Vector2i(-(r + 1), 0)] in [Palette.C0, Palette.C2], "in a bright photon ring")
	assert_eq(a[Vector2i(0, -(r + 2))], Palette.C3, "the far side lensed over the top: not a ringed planet")
	var band_y: int = roundi((r + BigBangSequence.DISC_GAP) * BigBangSequence.DISC_TILT)
	assert_true(a[Vector2i(0, band_y)] in [Palette.C1, Palette.C2], "the near side crosses in front of the hole")
	assert_ne(a, b, "highlights and dashes move each spin step")
	for colour: Color in a.values():
		assert_true(colour in [Palette.N0, Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.C5], colour.to_html(false))
	var reach: float = a.keys().map(func(o: Vector2i) -> float: return Vector2(o).length()).max()
	assert_lte(reach, r + BigBangSequence.HOLE_HALO + 0.5)


func test_stars_and_specks_spiral_into_the_hole() -> void:
	var from := Vector2i(60, 0)
	var at: Callable = func(k: float) -> float:
		return Vector2(StarView.collapse_point(from, Vector2i.ZERO, k, BigBangSequence.SWIRL, BigBangSequence.HOVER)).length()
	assert_eq(StarView.collapse_point(from, Vector2i.ZERO, 0.0, BigBangSequence.SWIRL, BigBangSequence.HOVER), from)
	assert_gt(at.call(0.0) - at.call(0.2), at.call(0.5) - at.call(0.7), "fast at first, slower near the hole")
	assert_between(at.call(0.8), float(BigBangSequence.HOVER), BigBangSequence.HOVER + 3.0, "hanging just outside the hole")
	var half: Vector2i = StarView.collapse_point(from, Vector2i.ZERO, 0.5, BigBangSequence.SWIRL, BigBangSequence.HOVER)
	assert_ne(half.y, 0, "and turned: a spiral, not a straight line")
	assert_eq(at.call(1.0), 0.0, "swallowed at the end")
	var near := Vector2i(5, 0)
	assert_lte(Vector2(StarView.collapse_point(near, Vector2i.ZERO, 0.5, BigBangSequence.SWIRL, BigBangSequence.HOVER)).length(), 5.0 + sqrt(0.5),
		"a star already inside the hover distance never moves outward (beyond whole-pixel rounding)")
	for colour: Color in BigBangSequence.SPECK_COLOURS:
		assert_true(colour in [Palette.N6, Palette.N7, Palette.N8], "cool: sky dust isn't worth anything")


func test_a_shockwave_ring_grows_and_cools() -> void:
	assert_true(BigBangSequence.ring_pixels(-0.1).is_empty(), "a staggered ring waits")
	assert_true(BigBangSequence.ring_pixels(1.0).is_empty())
	var early: Dictionary[Vector2i, Color] = BigBangSequence.ring_pixels(0.1)
	var late: Dictionary[Vector2i, Color] = BigBangSequence.ring_pixels(0.9)
	assert_eq(early.values()[0], Palette.C0, "hot")
	assert_eq(late.values()[0], Palette.C3, "cooled")
	var reach: Callable = func(dots: Dictionary[Vector2i, Color]) -> float:
		return dots.keys().map(func(o: Vector2i) -> float: return Vector2(o).length()).max()
	assert_lt(reach.call(early), reach.call(late), "it grows")
	assert_lte(reach.call(late), BigBangSequence.RING_REACH + 1.0)


func test_dithers_cover_their_density() -> void:
	for density: float in [0.25, 0.5, 0.75, 1.0]:
		var tile: Image = BigBangSequence.dither_tile(density, Palette.C0)
		var lit: int = 0
		for y: int in 4:
			for x: int in 4:
				if tile.get_pixel(x, y).a > 0.0:
					assert_eq(tile.get_pixel(x, y), Palette.C0)
					lit += 1
		assert_eq(lit, roundi(density * 16), "%s of the pixels" % density)


func test_debris_uses_palette_colours_only() -> void:
	for colour: Color in BigBangSequence.DEBRIS_COLOURS:
		assert_true(colour in [Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.N8, Palette.N9, Palette.N10, Palette.D0])


func test_a_new_run_stops_the_sequence() -> void:
	_big_bang()
	big_bang.advance(BigBangSequence.BANG_AT + 0.1)
	big_bang.setup(Fixtures.run(), sequencer)
	assert_false(big_bang.is_playing())
	assert_false(big_bang.is_banner_shown())


func test_the_dust_streams_from_the_burst_after_the_bang() -> void:
	var particles := CollectParticles.new()
	add_child_autofree(particles)
	particles.set_process(false)
	particles.setup(run, sequencer)
	var landed: Array[int] = []
	particles.dust_arrived.connect(func(n: int) -> void: landed.append(n))
	_big_bang()
	var dust: int = run.balance.big_bang_base_dust
	assert_eq(particles.in_flight(CollectParticles.Kind.DUST), dust)
	particles.advance(BigBangSequence.BANG_AT)
	assert_eq(landed, [] as Array[int], "nothing lands before the bang")
	particles.advance(CollectParticles.STAGGER * CollectParticles.BIG_BANG_PARTICLES + CollectParticles.FLIGHT_MAX)
	assert_eq(landed.reduce(func(a: int, b: int) -> int: return a + b, 0), dust)
	assert_eq(landed.size(), mini(dust, CollectParticles.BIG_BANG_PARTICLES), "a stream, not a lump")


func test_debug_key_b_forces_the_next_big_bang() -> void:
	var keys := DebugKeys.new()
	add_child_autofree(keys)
	keys.setup(run, sequencer)
	assert_true(keys.force_big_bang())
	assert_true(run.force_next_big_bang)


## Launches a forced Big Bang into an empty sky and plays its event.
func _big_bang() -> void:
	run.force_next_big_bang = true
	assert_true(run.launch(Vector2i(90, 160)))
	sequencer.advance(0.0)
