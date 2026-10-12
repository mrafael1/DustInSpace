extends GutTest

const MainScene := preload("res://game/scenes/main.tscn")


func _main(enabled: bool = true) -> Main:
	var main: Main = MainScene.instantiate()
	main.current_trial = true
	main.current_layout = "black_hole"
	main.current_enabled = enabled
	main.seed_override = 7
	add_child_autofree(main)
	return main


func test_trial_switch_replays_the_same_seed_without_the_hole() -> void:
	var main: Main = _main()
	var view: GravityView = main.get_node("Sky/GravityLayer")
	assert_not_null(main.run.gravity)
	assert_true(view.is_processing())
	assert_eq(main.run.scorpio.map.id, "black_hole_trial")
	main.switch_current()
	assert_null(main.run.gravity)
	assert_false(view.is_processing())
	assert_eq(main.run.run_seed, 7)
	main.switch_current()
	assert_not_null(main.run.gravity)


func test_controls_name_the_hole() -> void:
	var main: Main = _main()
	var controls: CurrentTrialControls = main.get_node("CurrentTrialControls")
	assert_true(controls.visible)
	assert_eq((controls.get("_button") as MapButton).text, "HOLE ON")
	main.switch_current()
	assert_eq((controls.get("_button") as MapButton).text, "HOLE OFF")


func test_hole_pixels_stay_on_the_palette_and_flare_ember() -> void:
	var allowed: Array[Color] = [Palette.N0, Palette.M4, Palette.M5, Palette.M6]
	var pixels: Dictionary[Vector2i, Color] = GravityView.hole_pixels(Vector2i(90, 164), 8, 0.5)
	assert_eq(pixels[Vector2i(90, 164)], Palette.N0, "the disc is dark")
	for color: Color in pixels.values():
		assert_has(allowed, color)
	var flaring: Dictionary[Vector2i, Color] = GravityView.hole_pixels(Vector2i(90, 164), 8, 0.5, 0.02)
	assert_eq(flaring[Vector2i(100, 164)], Palette.S4, "the ring flares ember as it swallows")
	flaring = GravityView.hole_pixels(Vector2i(90, 164), 8, 0.5, 0.08)
	assert_eq(flaring[Vector2i(100, 164)], Palette.S3)


func test_stars_about_to_be_swallowed_are_marked_when_not_aiming() -> void:
	var main: Main = _main()
	var view: GravityView = main.get_node("Sky/GravityLayer")
	var hole: Vector2i = main.run.gravity.center
	var star: Star = main.run.add_star(Star.Size.SMALL, hole + Vector2i(0, -22))
	assert_eq(main.run.launch_swallows(), [star.id] as Array[int])
	view.aiming = false
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	var edge: int = StarView.half_extent(Star.Size.SMALL)
	assert_eq(pixels.get(star.position + Vector2i(0, edge + 3)), Palette.S4)
	view.aiming = true
	pixels = view.pixels()
	assert_true(pixels.values().has(Palette.S4), "its fall into the hole trails ember while aiming")


func test_a_swallow_plays_briefly_on_the_palette_without_the_big_bangs_warm_ring() -> void:
	var allowed: Array[Color] = [Palette.C0, Palette.C1, Palette.M4, Palette.M5, Palette.M6, Palette.S3, Palette.S4]
	var t: float = 0.0
	while t < GravityView.SWALLOW_TIME:
		for color: Color in GravityView.swallow_pixels(Vector2i(90, 164), 8, Vector2.UP, t).values():
			assert_has(allowed, color, "at %.2f s" % t)
			assert_ne(color, Palette.C2, "the C2 photon ring is the Big Bang's")
		t += 0.02
	assert_true(GravityView.swallow_pixels(Vector2i(90, 164), 8, Vector2.UP, GravityView.SWALLOW_TIME).is_empty())
	assert_lt(GravityView.SWALLOW_TIME, 0.7, "a common effect stays under 700 ms")


func test_a_swallow_pinches_at_the_entry_and_the_disc_gulps() -> void:
	var start: Dictionary[Vector2i, Color] = GravityView.swallow_pixels(Vector2i(90, 164), 8, Vector2.UP, 0.0)
	assert_eq(start[Vector2i(90, 156)], Palette.C0, "the core pinches where the star crossed the horizon")
	var resting: Dictionary[Vector2i, Color] = GravityView.hole_pixels(Vector2i(90, 164), 8, 0.0)
	var gulping: Dictionary[Vector2i, Color] = GravityView.hole_pixels(Vector2i(90, 164), 8, 0.0, 0.1)
	assert_ne(resting.get(Vector2i(99, 164)), Palette.N0)
	assert_eq(gulping[Vector2i(99, 164)], Palette.N0, "a pixel wider while it gulps")


func test_a_swallowed_star_plays_its_swallow_and_sound() -> void:
	var main: Main = _main()
	var view: GravityView = main.get_node("Sky/GravityLayer")
	var played: Array[StringName] = []
	(main.get_node("Sfx") as Sfx).cue_played.connect(func(cue: StringName, _pitch: float) -> void: played.append(cue))
	var hole: Vector2i = main.run.gravity.center
	var star: Star = main.run.add_star(Star.Size.SMALL, hole + Vector2i(0, -22))
	main.run.pack_burst.emit("blue", hole, [star] as Array[Star])
	main.run.load_pack("blue")
	assert_true(main.run.launch(Vector2i(20, 240)))
	var start: int = Time.get_ticks_msec()
	while not view.is_swallowing() and Time.get_ticks_msec() - start < 6000:
		await get_tree().process_frame
	assert_true(view.is_swallowing())
	assert_has(played, &"swallow")
