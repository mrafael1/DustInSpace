extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const StarViewScene := preload("res://game/scenes/star_view.tscn")
const PALETTE_PATH := "res://assets/palettes/stellar_sun.gpl"
const STEP: float = 1.0 / 60.0

var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)


func test_flight_starts_at_the_burst_and_ends_on_the_target() -> void:
	var from := Vector2i(90, 150)
	var to := Vector2i(110, 170)
	assert_eq(StarView.flight_point(from, to, 0.0, inner), from)
	assert_eq(StarView.flight_point(from, to, 1.0, inner), to)


func test_flight_overshoots_the_target_in_open_sky() -> void:
	var from := Vector2i(60, 150)
	var to := Vector2i(100, 150)
	var furthest: int = 0
	for i: int in 101:
		furthest = maxi(furthest, StarView.flight_point(from, to, i / 100.0, inner).x)
	assert_gt(furthest, to.x, "ease-out-back carries the star past its spot before it settles")


func test_flight_overshoot_never_leaves_the_sky_at_any_edge() -> void:
	var corners: Array[Vector2i] = [inner.position, inner.end - Vector2i.ONE,
		Vector2i(inner.position.x, inner.end.y - 1), Vector2i(inner.end.x - 1, inner.position.y)]
	var center: Vector2i = inner.get_center()
	for corner: Vector2i in corners:
		for i: int in 101:
			var point: Vector2i = StarView.flight_point(center, corner, i / 100.0, inner)
			assert_true(inner.has_point(point), "%s inside the sky on the way to %s" % [point, corner])


func test_setup_shows_the_star_settled_at_its_position() -> void:
	var view: StarView = _view(Star.new(4, Star.Size.BIG, Vector2i(100, 120)))
	assert_eq(view.star_id, 4)
	assert_eq(view.size, Star.Size.BIG)
	assert_eq(view.state, StarView.State.IDLE)
	assert_eq(view.position, Vector2(100, 120))


func test_fly_from_waits_its_delay_then_settles_on_whole_pixels() -> void:
	var view: StarView = _view(Star.new(1, Star.Size.MEDIUM, Vector2i(120, 200)))
	watch_signals(view)
	view.fly_from(Vector2i(90, 160), 0.1)
	assert_false(view.visible, "hidden until its turn in the stagger")
	var elapsed: float = 0.0
	while view.state == StarView.State.SETTLING:
		view.advance(STEP)
		elapsed += STEP
		assert_eq(view.position, view.position.round(), "integer position while flying")
		assert_true(inner.has_point(Vector2i(view.position)), "inside the sky while flying")
		assert_lt(elapsed, 2.0, "the flight ends")
	assert_true(view.visible)
	assert_almost_eq(elapsed, 0.1 + StarView.SETTLE_TIME, STEP * 2)
	assert_eq(view.position, Vector2(120, 200))
	assert_signal_emitted_with_parameters(view, "settled", [view])


func test_selected_is_a_view_flag_only() -> void:
	var view: StarView = _view(Star.new(1, Star.Size.SMALL, Vector2i(50, 150)))
	view.selected = true
	assert_true(view.selected)
	assert_eq(view.state, StarView.State.IDLE)


func test_dissolve_frees_the_view_after_its_time() -> void:
	var view: StarView = _view(Star.new(1, Star.Size.SMALL, Vector2i(50, 150)))
	view.selected = true
	watch_signals(view)
	view.dissolve()
	assert_false(view.selected, "a dissolving star drops its selection ring")
	view.advance(StarView.DISSOLVE_TIME * 0.5)
	assert_signal_not_emitted(view, "dissolved")
	view.advance(StarView.DISSOLVE_TIME * 0.5)
	assert_signal_emitted_with_parameters(view, "dissolved", [view])
	assert_true(view.is_queued_for_deletion())


func test_halo_shows_when_settled_and_on_the_dissolve_flare_only() -> void:
	var view: StarView = _view(Star.new(1, Star.Size.BIG, Vector2i(100, 150)))
	var dots: Dictionary[Vector2i, Color] = view.halo_dots()
	assert_false(dots.is_empty())
	for dot: Vector2i in dots:
		assert_lte(Vector2(dot).distance_to(Vector2(100, 150)), float(StarView.HALO_RADIUS[Star.Size.BIG]),
			"halo dots are in sky coordinates around the star")
		assert_true(dots[dot] == Palette.C4 or dots[dot] == Palette.C5, "halos use C4-C5 only")
	view.fly_from(Vector2i(90, 160))
	assert_true(view.halo_dots().is_empty(), "no halo while flying")
	view.advance(StarView.SETTLE_TIME)
	view.dissolve()
	assert_false(view.halo_dots().is_empty(), "the flare keeps the halo")
	view.advance(StarView.DISSOLVE_TIME / StarView.DISSOLVE_FRAMES + 0.01)
	assert_true(view.halo_dots().is_empty(), "then it goes")


func test_overshoot_peak_is_where_the_flight_turns_back() -> void:
	var from := Vector2i(20, 150)
	var to := Vector2i(120, 150)
	var furthest: int = 0
	for i: int in 1001:
		furthest = maxi(furthest, StarView.flight_point(from, to, i / 1000.0, inner).x)
	var peak: int = StarView.flight_point(from, to, StarView.OVERSHOOT_PEAK, inner).x
	assert_eq(peak, furthest, "at its furthest pixel at the peak")
	var previous: int = peak
	for i: int in range(ceili(StarView.OVERSHOOT_PEAK * 1000.0), 1001):
		var x: int = StarView.flight_point(from, to, i / 1000.0, inner).x
		assert_lte(x, previous, "only drifts back after the peak")
		previous = x


func test_star_art_matches_the_art_direction_sizes() -> void:
	var sizes: Array[int] = [5, 11, 15]
	for size: int in Star.Size.values():
		var sheet: Texture2D = StarView.SHEETS[size]
		assert_eq(sheet.get_height(), sizes[size], "%s is %d px" % [Star.size_key(size), sizes[size]])
		assert_eq(sheet.get_width(), sizes[size] * StarView.FRAMES.size(), "one square frame per state")
		assert_eq(StarView.RING_SHEETS[size].get_width(), 2 * StarView.RING_SHEETS[size].get_height(), "2 ring frames")
		assert_eq(StarView.half_extent(size), sizes[size] >> 1)


func test_frame_names_match_the_json_sidecars() -> void:
	for key: String in ["small", "medium", "big"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/stars_%s.json" % key))
		var names: Array[StringName] = []
		for name: String in data["frames"]:
			names.append(StringName(name))
		assert_eq(names, StarView.FRAMES, key)


func test_star_art_is_opaque_palette_pixels_only() -> void:
	var gpl: Array[Color] = _gpl_colours()
	var sheets: Array[Texture2D] = StarView.SHEETS + StarView.RING_SHEETS
	for sheet: Texture2D in sheets:
		var image: Image = sheet.get_image()
		var bad: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c: Color = image.get_pixel(x, y)
				if c.a == 0.0:
					continue
				if c.a < 1.0 or not gpl.any(func(g: Color) -> bool: return g.to_html(false) == c.to_html(false)):
					bad += 1
		assert_eq(bad, 0, "%s: opaque Stellar Sun colours only" % sheet.resource_path)


func test_warm_stars_are_told_apart_by_silhouette() -> void:
	var counts: Array[int] = []
	for size: int in Star.Size.values():
		var mask: Image = StarView.SHEETS[size].get_image().get_region(Rect2i(0, 0, StarView.SHEETS[size].get_height(), StarView.SHEETS[size].get_height()))
		var lit: int = 0
		for y: int in mask.get_height():
			for x: int in mask.get_width():
				if mask.get_pixel(x, y).a > 0.0:
					lit += 1
		counts.append(lit)
	assert_lt(counts[0], counts[1], "small < medium")
	assert_lt(counts[1], counts[2], "medium < big")


func test_palette_colours_come_from_the_gpl_file() -> void:
	var gpl: Array[Color] = _gpl_colours()
	assert_eq(gpl.size(), 40, "the full Stellar Sun palette")
	var constants: Dictionary = (Palette as Script).get_script_constant_map()
	assert_false(constants.is_empty())
	for name: String in constants:
		var colours: Array = constants[name] if constants[name] is Array else [constants[name]]
		for colour: Color in colours:
			assert_true(gpl.any(func(c: Color) -> bool: return c.to_html(false) == colour.to_html(false)),
				"Palette.%s (%s) is in stellar_sun.gpl" % [name, colour.to_html(false)])


func _view(star: Star) -> StarView:
	var view: StarView = StarViewScene.instantiate()
	view.setup(star, Fixtures.SKY)
	add_child_autofree(view)
	return view


func _gpl_colours() -> Array[Color]:
	var colours: Array[Color] = []
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 3 and fields[0].is_valid_int():
			colours.append(Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()))
	return colours
