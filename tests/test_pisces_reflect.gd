extends GutTest
## Pisces's reflection: on the Circlet and the West Cord a planet bursts across the seam from where
## it's thrown; the aim's ring shows where; the intro, the rule lines and the seam's view.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["pisces_circlet", "pisces_west_cord"]


func _run(map: StarMap, seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	return run


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_reflect_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_the_first_stages_are_pickable_and_split_by_a_seam() -> void:
	for id: String in BUILT:
		var map: StarMap = StarMap.by_id(id)
		assert_eq(map.id, id)
		assert_false(map.cords, "%s: no cords" % id)
		assert_eq(map.segment_count(), map.count() - 1, "%s: the strings form a tree" % id)
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS, "%s: %d and %d apart" % [id, i, j])
	assert_eq(StarMap.pisces_circlet().seam, StarMap.Seam.VERTICAL, "throw left, play right")
	assert_eq(StarMap.pisces_west_cord().seam, StarMap.Seam.HORIZONTAL, "throw high, play low")
	assert_eq(StarMap.heart().seam, StarMap.Seam.NONE)


func test_the_seam_reflects_through_the_middle_where_the_map_is_drawn() -> void:
	var circlet: RunState = _run(StarMap.pisces_circlet())
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + circlet.scorpio.shift
	assert_eq(circlet.reflect(middle), middle, "the seam reflects onto itself")
	assert_eq(circlet.reflect(middle + Vector2i(-50, 20)), middle + Vector2i(50, 20), "left to right, same height")
	var west: RunState = _run(StarMap.pisces_west_cord())
	assert_eq(west.reflect(middle + Vector2i(30, -40)), middle + Vector2i(30, 40), "high to low, same x")
	var heart: RunState = _run(StarMap.heart())
	assert_eq(heart.burst_centre(Vector2i(40, 120)), Vector2i(40, 120), "elsewhere a planet bursts where it's thrown")


func test_a_planet_bursts_across_the_seam_from_where_its_thrown() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	run.owned_packs["red"] = 0
	run.loaded_pack = "blue"
	var thrown := Vector2i(40, 120)
	var expected: Vector2i = run.burst_centre(thrown)
	assert_eq(expected, run.reflect(thrown))
	var launched: Array = []
	var reflected: Array = []
	var bursts: Array = []
	run.pack_launched.connect(func(kind: String, at: Vector2i) -> void: launched.append(at))
	run.planet_reflected.connect(func(from: Vector2i, to: Vector2i) -> void: reflected.append([from, to]))
	run.pack_burst.connect(func(kind: String, at: Vector2i, stars: Array[Star]) -> void: bursts.append([at, stars]))
	assert_true(run.launch(thrown))
	assert_eq(launched, [thrown], "the planet flies to where it's thrown")
	assert_eq(reflected, [[thrown, expected]], "and goes into the mirror")
	assert_eq(bursts.size(), 1)
	assert_eq(bursts[0][0], expected, "it bursts across the seam")
	for star: Star in bursts[0][1]:
		assert_gt(star.position.x, 90, "its stars land on the far side")


func test_a_split_planet_splits_across_the_seam_too() -> void:
	var run: RunState = _run(StarMap.pisces_west_cord())
	run.owned_packs["red"] = 1
	run.loaded_pack = "red"
	var thrown := Vector2i(90, 110)
	var split: Array = []
	run.pack_split.connect(func(kind: String, at: Vector2i, points: Array[Vector2i]) -> void: split.append(at))
	assert_true(run.launch(thrown))
	assert_eq(split, [run.burst_centre(thrown)], "the twins part where it bursts")
	assert_gt(run.burst_centre(thrown).y, 164, "thrown high, it bursts low")


func test_the_aims_ring_shows_where_the_stars_land() -> void:
	var main: Main = _main("pisces_circlet")
	_settle(main)
	var telescope: Telescope = main.get_node("Telescope")
	var aim: Vector2i = telescope.burst_preview()
	assert_eq(telescope.burst_points(), [main.run.burst_centre(aim)] as Array[Vector2i], "the ring across the seam, the reticle at the aim")


func test_the_circlet_opens_by_showing_a_throw_burst_across_the_seam() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var launched: Array = []
	var reflected: Array = []
	var born: Array = []
	var cleared: Array = []
	run.hunt_intro_launched.connect(func(kind: String, at: Vector2i) -> void: launched.append(at))
	run.planet_reflected.connect(func(from: Vector2i, to: Vector2i) -> void: reflected.append([from, to]))
	run.hunt_intro_burst.connect(func(at: Vector2i, stars: Array[Star]) -> void: born.append(stars))
	run.reflect_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.append(stars))
	var packs: Dictionary = run.owned_packs.duplicate()
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	run.play_reflect_intro()
	assert_eq(launched.size(), 1)
	assert_eq(reflected.size(), 1)
	assert_eq(reflected[0][0], launched[0], "thrown where the demo planet flies")
	assert_eq(run.reflect(reflected[0][0]), reflected[0][1], "and burst at its reflection")
	assert_eq((born[0] as Array).size(), 3)
	assert_eq((cleared[0] as Array).size(), 3, "its stars go after a beat")
	assert_true(run.stars.is_empty(), "the sky is empty for the run")
	assert_eq(run.owned_packs, packs, "no pack used")
	assert_eq(run.dust, 100, "no reward")
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")


func test_the_reflection_intro_plays_only_as_a_stage_with_a_seam_and_intros_opens() -> void:
	var shown: Array = []
	var heart: RunState = _run(StarMap.heart())
	heart.planet_reflected.connect(func(from: Vector2i, to: Vector2i) -> void: shown.append(from))
	heart.play_reflect_intro()
	assert_true(shown.is_empty(), "no seam, no intro")
	var circlet: RunState = _run(StarMap.pisces_circlet())
	circlet.add_star(Star.Size.SMALL, Vector2i(20, 100))
	circlet.planet_reflected.connect(func(from: Vector2i, to: Vector2i) -> void: shown.append(from))
	circlet.play_reflect_intro()
	assert_true(shown.is_empty(), "not once the run has begun")


func test_each_rule_line_fits_and_names_its_seam() -> void:
	assert_eq(Hud.seam_rule(_run(StarMap.pisces_circlet())), Hud.SEAM_VERTICAL_MESSAGE)
	assert_eq(Hud.seam_rule(_run(StarMap.pisces_west_cord())), Hud.SEAM_HORIZONTAL_MESSAGE)
	assert_eq(Hud.seam_rule(_run(StarMap.heart())), "")
	for text: String in [Hud.SEAM_VERTICAL_MESSAGE, Hud.SEAM_HORIZONTAL_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_each_stage_says_its_rule_as_its_intro_shows_it() -> void:
	for id: String in BUILT:
		var main: Main = _main(id)
		var hud: Hud = main.get_node("HUD")
		var sky: SkyView = main.get_node("Sky")
		var sequencer: EventSequencer = main.get_node("EventSequencer")
		var rule: String = Hud.seam_rule(main.run)
		assert_true(sequencer.is_busy(), "%s: the intro plays" % id)
		var said: bool = false
		var most: int = 0
		var start: int = Time.get_ticks_msec()
		while sequencer.is_busy() and Time.get_ticks_msec() - start < 12000:
			await get_tree().process_frame
			said = said or hud.message() == rule
			most = maxi(most, sky.star_count())
		assert_true(said, "%s: the rule is said as the intro shows it" % id)
		assert_eq(most, 3, "%s: the demo planet's three stars" % id)
		assert_eq(sky.star_count(), 0, "%s: and they go" % id)


func test_the_seam_view_draws_the_seam_and_the_splash() -> void:
	var main: Main = _main("pisces_circlet")
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	assert_true(view.visible)
	view.advance(SeamView.SPLASH_TIME)
	var middle_x: int = (Scorpio.HOME_SKY.get_center() + main.run.scorpio.shift).x
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	assert_gt(pixels.size(), 10)
	assert_true(pixels.keys().all(func(p: Vector2i) -> bool: return p.x == middle_x), "an up-and-down seam at the middle")
	view.splash(Vector2i(40, 120), Vector2i(140, 120))
	assert_eq(view.pixels().get(Vector2i(47, 120)), Palette.N8, "the splash's outer ring at the thrown point")
	view.advance(SeamView.SPLASH_TIME)
	assert_false(view.is_splashing())
	var heart: Main = _main("heart")
	assert_false((heart.get_node("Sky/SeamLayer") as SeamView).visible, "no seam elsewhere")
