extends GutTest
## Pisces's final, PISCES, THE TWO FISH: the whole figure on one water line, up and down. From the
## second throw the waves wipe the left, then the right, then a great wave floods the whole sky, and
## round again. Winning ends in a great wave that washes the loose stars left into dust.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)


func _run(seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, StarMap.pisces_final())
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 0
	run.loaded_pack = "blue"
	return run


func _main() -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = "pisces_final"
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_final_settings.cfg"
	add_child_autofree(main)
	return main


## Plays in real frames until nothing is playing (the scene's tweens run too).
func _play_out(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var start: int = Time.get_ticks_msec()
	await get_tree().process_frame
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 15000:
		await get_tree().process_frame


## One loose star in each corner round the sky's middle: [top left, top right, bottom right,
## bottom left].
func _corners(run: RunState) -> Array[Star]:
	run.stars.clear()
	var middle: Vector2i = run.wave.middle
	var corners: Array[Star] = []
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		corners.append(run.add_star(Star.Size.SMALL, middle + Vector2i(corner.x * 70, corner.y * 70)))
	return corners


func test_the_final_is_the_whole_figure_on_one_line_with_the_great_wave() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.map_id(Chapter.FINAL), "pisces_final")
	var map: StarMap = StarMap.pisces_final()
	assert_eq(map.landmarks, StarMap.pisces().landmarks, "the whole Pisces")
	assert_eq(map.starting_lit, [0], "gamma lit: thirteen to light")
	assert_eq(map.seam, StarMap.Seam.VERTICAL, "one line, between the fish")
	assert_true(map.splash)
	assert_true(map.wave)
	assert_true(map.wave_great)
	assert_true(map.wave_finale)
	assert_false(map.intros, "the stages showed every rule")
	assert_eq(map.arrival_epithet, "THE TWO FISH")
	var balance: Balance = Balance.load_file()
	assert_eq(balance.wave_great_after, 2, "a great wave after every two")
	assert_gt(balance.wave_finale_dust_per_star, 0)
	var run: RunState = _run()
	assert_eq(run.seam, StarMap.Seam.VERTICAL)
	assert_true(run.wave.vertical)
	assert_eq(RunState.new(balance, Fixtures.rng(1), SKY, StarMap.pisces_north_fish()).wave.great_after, 0, "only the final has them")


func test_left_right_then_a_great_wave_and_round_again() -> void:
	var run: RunState = _run()
	var struck: Array = []
	run.wave_struck.connect(func(way: Vector2i, lost: Array[Star], next: Vector2i, great: bool) -> void:
		var ids: Array[int] = []
		for star: Star in lost:
			ids.append(star.id)
		ids.sort()
		struck.append([way, ids, next, great]))
	var aim: Vector2i = run.wave.middle + Vector2i(30, 50)
	assert_true(run.launch(aim), "the first throw: no wave")
	assert_true(struck.is_empty())
	# Throws 2 to 7: left, right, great, left, right, great.
	var rhythm: Array[String] = ["left", "right", "great", "left", "right", "great"]
	for i: int in rhythm.size():
		var corners: Array[Star] = _corners(run)
		var expected: Array[int] = []
		match rhythm[i]:
			"left":
				expected.assign([corners[0].id, corners[3].id])
			"right":
				expected.assign([corners[1].id, corners[2].id])
			"great":
				for star: Star in corners:
					expected.append(star.id)
		expected.sort()
		assert_eq(run.wave.great_next(), rhythm[i] == "great", "throw %d" % (i + 2))
		assert_eq(run.wave_risk().size(), expected.size(), "its stars marked (throw %d)" % (i + 2))
		run.load_pack("blue")
		assert_true(run.launch(aim))
		assert_eq(struck[i][3], rhythm[i] == "great", "throw %d: %s" % [i + 2, rhythm[i]])
		assert_eq(struck[i][1], expected, "throw %d takes its half (or all)" % (i + 2))
		if rhythm[i] != "great":
			assert_eq(struck[i][0], Vector2i.LEFT if rhythm[i] == "left" else Vector2i.RIGHT)
	assert_eq(run.seam, StarMap.Seam.VERTICAL, "still one line")


func test_winning_ends_in_a_great_wave_that_washes_the_loose_stars_into_dust() -> void:
	var run: RunState = _run()
	for i: int in run.scorpio.map.count():
		if i != 13:
			run.scorpio.light(i)
	var events: Array[String] = []
	var paid: Array[int] = []
	run.wave_struck.connect(func(_way: Vector2i, lost: Array[Star], _next: Vector2i, great: bool) -> void:
		events.append("great wave" if great and lost.is_empty() else "wave"))
	run.sky_cleared.connect(func(stars: Array[Star], dust: int) -> void:
		events.append("cleared")
		paid.append(stars.size())
		paid.append(dust))
	run.constellation_completed.connect(func() -> void: events.append("completed"))
	run.run_won.connect(func() -> void: events.append("won"))
	var leftover: Star = run.add_star(Star.Size.BIG, Vector2i(150, 220))
	var other: Star = run.add_star(Star.Size.SMALL, Vector2i(130, 100))
	var tau: Star = run.scorpio.landmark_star(13)
	var a: Star = run.add_star(tau.size, tau.position + Vector2i(-20, 0))
	var b: Star = run.add_star(tau.size, tau.position + Vector2i(20, 0))
	assert_ne(run.link([a.id, tau.id, b.id] as Array[int]), Combos.INVALID)
	assert_eq(events, ["great wave", "cleared", "completed", "won"], "the great wave washes the sky, then the figure completes")
	assert_eq(paid[0], 2, "the stars left")
	assert_eq(paid[1], 2 * run.balance.wave_finale_dust_per_star, "each paid as a jackpot")
	assert_null(run.find_star(leftover.id))
	assert_null(run.find_star(other.id))


func test_its_lines_fit() -> void:
	for text: String in [Hud.GREAT_WAVE_MESSAGE, Hud.WAVE_NEXT_MESSAGE % "RIGHT", Hud.WAVE_NEXT_MESSAGE % "LEFT"]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_great_wave_is_cued_on_both_sides_and_said() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var hud: Hud = main.get_node("HUD")
	var run: RunState = main.run
	run.wave.launches = 3
	run.wave.waves = 2
	view.settled = true
	assert_true(view.cue_great())
	var left: int = 0
	var right: int = 0
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in pixels:
		if pixels[point] == Palette.S4:
			if point.x < run.wave.middle.x:
				left += 1
			else:
				right += 1
	assert_gt(left, 0, "chevrons left of the line")
	assert_gt(right, 0, "and right of it")
	hud.show_message("", 0.0, true)
	hud.call("_tell_wave")
	assert_eq(hud.message(), Hud.GREAT_WAVE_MESSAGE)
	hud.show_message("", 0.0, true)
	hud.call("_tell_wave")
	assert_eq(hud.message(), "", "said once a run")


func test_the_great_wave_rushes_both_ways() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var run: RunState = main.run
	var middle: Vector2i = run.wave.middle
	view.sweep(Vector2i.RIGHT, Vector2i.LEFT, [] as Array[Vector2i], true)
	view.advance(SeamView.WINDUP_TIME + SeamView.SWEEP_TIME / 2.0)
	var left: int = 0
	var right: int = 0
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in pixels:
		if pixels[point] == Palette.M6 and absi(point.x - middle.x) > 8:
			if point.x < middle.x:
				left += 1
			else:
				right += 1
	assert_gt(left, 20, "a wall rushing left")
	assert_gt(right, 20, "and one rushing right")
	assert_eq(view.way_for(Vector2i.RIGHT, middle + Vector2i(-30, 5)), Vector2i.LEFT, "a star left of the line goes out left")
	assert_eq(view.way_for(Vector2i.RIGHT, middle + Vector2i(30, 5)), Vector2i.RIGHT)


func test_it_arrives_with_its_title_card_and_plays_its_acts_through_the_scene() -> void:
	var main: Main = _main()
	var banner: BossBanner = main.get_node("HUD").get("_banner")
	await get_tree().process_frame
	assert_true(banner.is_playing(), "the title card")
	await _play_out(main)
	var run: RunState = main.run
	var sky: SkyView = main.get_node("Sky")
	var view: SeamView = main.get_node("Sky/SeamLayer")
	assert_eq(sky.star_count(), 0, "no intro stars")
	run.dust = 100
	for i: int in 5:
		if run.is_over():
			break
		if run.total_packs() == 0:
			run.buy("blue")
		for kind: String in ["blue", "red"]:
			if run.load_pack(kind):
				break
		assert_true(run.launch(run.wave.middle + Vector2i(40 if i % 2 == 0 else -40, 40)))
		await _play_out(main)
		assert_eq(sky.star_count(), run.stars.size(), "the views follow the run after launch %d" % (i + 1))
	assert_eq(run.seam, StarMap.Seam.VERTICAL)

