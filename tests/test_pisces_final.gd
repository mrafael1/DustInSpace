extends GutTest
## Pisces's final, PISCES, THE TWO FISH: the whole figure on both seams, the splash, and the wave
## turning a quarter every launch (up, right, down, left). Its map, the turning, its cue, its lines
## and its arrival.

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


func test_the_final_is_the_whole_figure_on_both_seams_with_the_turning_wave() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.map_id(Chapter.FINAL), "pisces_final")
	var map: StarMap = StarMap.pisces_final()
	var figure: StarMap = StarMap.pisces()
	assert_eq(map.landmarks, figure.landmarks, "the whole Pisces")
	assert_eq(map.starting_lit, [0], "gamma lit: thirteen to light")
	assert_eq(map.seam, StarMap.Seam.CROSS)
	assert_true(map.splash)
	assert_true(map.wave)
	assert_true(map.wave_turns)
	assert_false(map.intros, "the stages showed every rule")
	assert_eq(map.title, "PISCES")
	assert_eq(map.arrival_epithet, "THE TWO FISH")
	var run: RunState = _run()
	assert_not_null(run.wave)
	assert_true(run.wave.turns)
	assert_eq(run.wave.middle, Scorpio.HOME_SKY.get_center() + run.scorpio.shift)


func test_the_wave_turns_a_quarter_every_launch_and_wipes_its_half() -> void:
	var run: RunState = _run()
	var middle: Vector2i = run.wave.middle
	var aim: Vector2i = middle + Vector2i(40, 40)
	assert_true(run.launch(aim))
	var struck: Array = []
	run.wave_struck.connect(func(way: Vector2i, lost: Array[Star], next: Vector2i) -> void:
		var ids: Array[int] = []
		for star: Star in lost:
			ids.append(star.id)
		struck.append([way, ids, next]))
	var ways: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for i: int in ways.size():
		run.stars.clear()
		# One star in each corner, clear of the figure's stars (none sit this near the sky's corners).
		var corners: Dictionary[Vector2i, Star] = {}
		for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
			corners[corner] = run.add_star(Star.Size.SMALL, middle + Vector2i(corner.x * 60, corner.y * 50))
		var expected: Array[int] = []
		for corner: Vector2i in corners:
			if corner.x == ways[i].x or corner.y == ways[i].y:
				expected.append(corners[corner].id)
		assert_eq(run.wave_risk(), expected, "marked: the half it wipes (wave %d)" % i)
		run.load_pack("blue")
		assert_true(run.launch(aim))
		assert_eq(struck[i][0], ways[i], "wave %d rushes %s" % [i, ways[i]])
		assert_eq(struck[i][1], expected, "and takes that half's two")
		assert_eq(struck[i][2], ways[(i + 1) % 4] if i < 4 else Vector2i.RIGHT, "the next a quarter on")


func test_a_star_on_a_line_goes_with_either_half() -> void:
	var wave := StarWave.new(Vector2i(90, 164), false, 2, true)
	var on_cross := Star.new(1, Star.Size.SMALL, Vector2i(90, 164))
	for way: Vector2i in StarWave.TURNS:
		assert_eq(wave.sweeps(way, [on_cross] as Array[Star]), [1] as Array[int], "on both lines: in every half")
	assert_true(wave.in_reach(Vector2i.RIGHT, Vector2i(90, 100)), "on the line up and down: the right half's")
	assert_true(wave.in_reach(Vector2i.LEFT, Vector2i(90, 100)), "and the left's")
	assert_false(wave.in_reach(Vector2i.DOWN, Vector2i(90, 100)), "but above the line across")


func test_a_one_line_wave_never_turns() -> void:
	var wave := StarWave.new(Vector2i(90, 164), false, 2)
	assert_eq([wave.way_of(0), wave.way_of(1), wave.way_of(2)], [Vector2i.UP, Vector2i.DOWN, Vector2i.UP])
	var up_down := StarWave.new(Vector2i(90, 164), true, 2)
	assert_eq([up_down.way_of(0), up_down.way_of(1)], [Vector2i.LEFT, Vector2i.RIGHT])
	assert_null(RunState.new(Balance.load_file(), Fixtures.rng(1), SKY, StarMap.pisces_east_cord()).wave, "both seams without the final: no wave")


func test_its_lines_name_each_way() -> void:
	var wave := StarWave.new(Vector2i(90, 164), false, 2, true)
	var names: Array[String] = []
	for i: int in 4:
		wave.waves = i
		names.append(Hud.wave_side_name(wave))
	assert_eq(names, ["TOP", "RIGHT", "BOTTOM", "LEFT"] as Array[String])
	for name: String in names:
		for line: String in (Hud.WAVE_NEXT_MESSAGE % name).split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_cue_shows_on_the_line_up_and_down_for_a_wave_to_the_right() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var run: RunState = main.run
	run.wave.launches = 1
	run.wave.waves = 1
	view.settled = true
	assert_eq(view.cue_way(), Vector2i.RIGHT)
	var right: int = 0
	var left: int = 0
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in pixels:
		if pixels[point] == Palette.S4:
			if point.x > run.wave.middle.x:
				right += 1
			else:
				left += 1
	assert_gt(right, 0, "ember chevrons right of the line")
	assert_eq(left, 0, "none left of it")
	assert_eq(view.carry_point(Vector2i.RIGHT, Vector2i(120, 140)).y, 140, "a star rides straight out to the right")
	assert_gt(view.carry_point(Vector2i.RIGHT, Vector2i(120, 140)).x, 120)


func test_it_arrives_with_its_title_card_and_plays_its_waves_through_the_scene() -> void:
	var main: Main = _main()
	var banner: BossBanner = main.get_node("HUD").get("_banner")
	await get_tree().process_frame
	assert_true(banner.is_playing(), "the title card")
	await _play_out(main)
	var run: RunState = main.run
	var sky: SkyView = main.get_node("Sky")
	assert_eq(sky.star_count(), 0, "no intro stars")
	run.dust = 100
	for i: int in 4:
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
