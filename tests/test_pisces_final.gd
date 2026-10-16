extends GutTest
## Pisces's final, PISCES, THE TWO FISH: the whole figure in two acts. Act one, one water line up and
## down, the waves wiping the left then the right; the great wave floods the whole sky and raises the
## line across too; act two, both seams, the waves wiping the top then the bottom. Winning ends in a
## great wave that washes the loose stars left into dust.

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
	assert_eq(map.seam, StarMap.Seam.VERTICAL, "act one: one line, between the fish")
	assert_true(map.splash)
	assert_true(map.wave)
	assert_true(map.wave_great)
	assert_true(map.wave_finale)
	assert_false(map.intros, "the stages showed every rule")
	assert_eq(map.arrival_epithet, "THE TWO FISH")
	var balance: Balance = Balance.load_file()
	assert_eq(balance.wave_great_launch, 4, "the great wave on the fourth throw")
	assert_gt(balance.wave_finale_dust_per_star, 0)
	var run: RunState = _run()
	assert_eq(run.seam, StarMap.Seam.VERTICAL)
	assert_true(run.wave.vertical)
	assert_eq(RunState.new(balance, Fixtures.rng(1), SKY, StarMap.pisces_north_fish()).wave.great_launch, 0, "only the final has it")


func test_act_one_left_and_right_then_the_great_wave_then_act_two_on_both_seams() -> void:
	var run: RunState = _run()
	var struck: Array = []
	var turned: Array = []
	run.wave_struck.connect(func(way: Vector2i, lost: Array[Star], next: Vector2i, great: bool) -> void:
		var ids: Array[int] = []
		for star: Star in lost:
			ids.append(star.id)
		ids.sort()
		struck.append([way, ids, next, great]))
	run.seam_turned.connect(func(seam: StarMap.Seam) -> void: turned.append(seam))
	var aim: Vector2i = run.wave.middle + Vector2i(30, 50)
	assert_true(run.launch(aim), "the first throw: no wave")
	assert_true(struck.is_empty())
	# Act one: the left, then the right.
	for i: int in 2:
		var corners: Array[Star] = _corners(run)
		var half: Array[int] = []
		half.assign([corners[0].id, corners[3].id] if i == 0 else [corners[1].id, corners[2].id])
		half.sort()
		assert_false(run.wave.great_next())
		run.load_pack("blue")
		assert_true(run.launch(aim))
		assert_eq(struck[i][0], Vector2i.LEFT if i == 0 else Vector2i.RIGHT)
		assert_eq(struck[i][1], half, "its half's two")
		assert_false(struck[i][3])
	# The fourth throw: the great wave takes every loose star.
	var all: Array[Star] = _corners(run)
	assert_true(run.wave.great_next())
	assert_eq(run.wave_risk().size(), 4, "every loose star marked")
	run.load_pack("blue")
	assert_true(run.launch(aim))
	var ids: Array[int] = []
	for star: Star in all:
		ids.append(star.id)
	ids.sort()
	assert_eq(struck[2][1], ids, "the great wave floods the whole sky")
	assert_true(struck[2][3])
	assert_eq(struck[2][2], Vector2i.UP, "act two's first wave: the top")
	assert_eq(turned, [StarMap.Seam.CROSS], "the line across rises too")
	assert_eq(run.seam, StarMap.Seam.CROSS)
	assert_eq(run.reflect(run.wave.middle + Vector2i(20, 30)), run.wave.middle - Vector2i(20, 30), "a planet bursts in the opposite corner")
	assert_true(run.crosses_seam(run.wave.middle + Vector2i(-10, -10), run.wave.middle + Vector2i(-10, 10)), "no link crosses the new line")
	# Act two: the top, then the bottom.
	for i: int in 2:
		var corners: Array[Star] = _corners(run)
		var half: Array[int] = []
		half.assign([corners[0].id, corners[1].id] if i == 0 else [corners[2].id, corners[3].id])
		half.sort()
		run.load_pack("blue")
		assert_true(run.launch(aim))
		assert_eq(struck[3 + i][0], Vector2i.UP if i == 0 else Vector2i.DOWN)
		assert_eq(struck[3 + i][1], half)
	assert_eq(turned.size(), 1, "the great wave comes once")


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
	for text: String in [Hud.GREAT_WAVE_MESSAGE, Hud.SEAM_CROSS_MESSAGE, Hud.WAVE_NEXT_MESSAGE % "RIGHT", Hud.WAVE_NEXT_MESSAGE % "LEFT"]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_great_wave_is_cued_on_both_sides_and_said() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var hud: Hud = main.get_node("HUD")
	var run: RunState = main.run
	run.wave.launches = 3
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


func test_the_great_wave_rushes_both_ways_and_the_second_line_rises() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var run: RunState = main.run
	var middle: Vector2i = run.wave.middle
	view.sweep(Vector2i.RIGHT, Vector2i.UP, [] as Array[Vector2i], true)
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
	view.advance(SeamView.SWEEP_TIME / 2.0 + SeamView.CRASH_TIME)
	assert_eq(view.shown_seam(), StarMap.Seam.VERTICAL)
	view.turn_seam(StarMap.Seam.CROSS)
	assert_true(view.is_turning())
	view.advance(SeamView.TURN_TIME / 2.0)
	pixels = view.pixels()
	assert_true(pixels.has(Vector2i(middle.x, run.sky_rect.position.y + 30)), "the first line stays whole")
	assert_false(pixels.has(Vector2i(run.sky_rect.position.x + 20, middle.y)), "the new one still growing out")
	assert_true(pixels.has(Vector2i(middle.x + 20, middle.y)), "from the middle")
	view.advance(SeamView.TURN_TIME / 2.0 + 0.01)
	assert_false(view.is_turning())
	assert_eq(view.shown_seam(), StarMap.Seam.CROSS)


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
	if run.wave.launches >= 4:
		assert_eq(view.shown_seam(), StarMap.Seam.CROSS, "the second line shows once the great wave has played")
