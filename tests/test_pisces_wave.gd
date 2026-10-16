extends GutTest
## Pisces's wave (the North Fish): from the second launch on, every launch a wave wipes the top or the
## bottom of the water line, in turn. Its map, previews, intro, rule lines and look.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)


func _run(seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, StarMap.pisces_north_fish())
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 0
	run.loaded_pack = "blue"
	return run


func _main() -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = "pisces_north_fish"
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_wave_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


## Plays in real frames until nothing is playing (the scene's tweens run too).
func _play_out(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var start: int = Time.get_ticks_msec()
	await get_tree().process_frame
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 15000:
		await get_tree().process_frame


func _line(run: RunState) -> int:
	return (Scorpio.HOME_SKY.get_center() + run.scorpio.shift).y


func test_the_north_fish_is_stage_5_with_the_wave() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.map_id(4), "pisces_north_fish")
	var map: StarMap = StarMap.pisces_north_fish()
	assert_true(map.wave)
	assert_true(map.splash, "the splash goes on")
	assert_eq(map.seam, StarMap.Seam.HORIZONTAL)
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
	var balance: Balance = Balance.load_file()
	assert_eq(balance.wave_first_launch, 2, "from the second launch")
	var run: RunState = _run()
	assert_eq(run.wave.middle.y, _line(run), "on the water line")
	assert_false(run.wave.turns, "it turns only on the final")
	assert_false(run.wave.vertical)
	for id: String in ["pisces_circlet", "pisces_west_cord", "pisces_knot", "pisces_east_cord"]:
		assert_null(RunState.new(balance, Fixtures.rng(1), SKY, StarMap.by_id(id)).wave, "no wave on %s" % id)


func test_the_first_launch_brings_no_wave() -> void:
	var run: RunState = _run()
	var line: int = _line(run)
	assert_false(run.wave.strikes_next())
	var top: Star = run.add_star(Star.Size.SMALL, Vector2i(30, line - 30))
	var bottom: Star = run.add_star(Star.Size.SMALL, Vector2i(150, line + 30))
	assert_true(run.wave_risk().is_empty(), "nothing marked")
	assert_true(run.launch_wipes(Vector2i(90, line + 40)).is_empty())
	var struck: Array = []
	run.wave_struck.connect(func(side: Vector2i, _lost: Array[Star], _next: Vector2i) -> void: struck.append(side))
	assert_true(run.launch(Vector2i(90, line + 40)))
	assert_true(struck.is_empty())
	assert_not_null(run.find_star(top.id))
	assert_not_null(run.find_star(bottom.id))
	assert_true(run.wave.strikes_next(), "the second does")
	assert_eq(run.wave.next_way(), Vector2i.UP, "the top first")


func test_from_the_second_launch_every_wave_wipes_a_side_in_turn() -> void:
	var run: RunState = _run()
	var line: int = _line(run)
	var aim := Vector2i(90, line + 60)
	assert_true(run.launch(aim))
	run.stars.clear()
	var top: Star = run.add_star(Star.Size.SMALL, Vector2i(20, line - 10))
	var on_line: Star = run.add_star(Star.Size.MEDIUM, Vector2i(160, line))
	var bottom: Star = run.add_star(Star.Size.BIG, Vector2i(20, line + 10))
	assert_eq(run.wave_risk(), [top.id, on_line.id] as Array[int], "marked: the top, and the line itself")
	var preview: Array[int] = run.launch_wipes(aim)
	var struck: Array = []
	var order: Array[String] = []
	run.wave_struck.connect(func(side: Vector2i, lost: Array[Star], next: Vector2i) -> void:
		order.append("wave")
		var ids: Array[int] = []
		for star: Star in lost:
			ids.append(star.id)
		struck.append([side, ids, next]))
	run.pack_burst.connect(func(_k: String, _a: Vector2i, _s: Array[Star]) -> void: order.append("burst"))
	var dust: int = run.dust
	run.load_pack("blue")
	assert_true(run.launch(aim))
	assert_eq(order, ["wave", "burst"] as Array[String], "before the planet bursts")
	assert_eq(struck, [[Vector2i.UP, [top.id, on_line.id] as Array[int], Vector2i.DOWN]])
	assert_eq(preview, [top.id, on_line.id] as Array[int], "as the aim showed")
	assert_null(run.find_star(top.id))
	assert_null(run.find_star(on_line.id))
	assert_not_null(run.find_star(bottom.id), "the other side is spared")
	assert_eq(run.dust, dust, "a wiped star pays nothing")
	# The next takes the bottom, and the stars this burst brought there with it.
	var below: Array[int] = []
	for star: Star in run.stars:
		if star.position.y >= line:
			below.append(star.id)
	run.load_pack("blue")
	assert_true(run.launch(aim))
	assert_eq(struck[1][0], Vector2i.DOWN)
	assert_eq(struck[1][1], below, "the bottom's stars")
	assert_eq(struck[1][2], Vector2i.UP, "then the top again")


func test_the_wave_comes_after_the_splash() -> void:
	var run: RunState = _run()
	run.wave.launches = 1
	var line: int = _line(run)
	# A star the splash pushes along the top: the wave takes it where the splash left it.
	var pushed: Star = run.add_star(Star.Size.SMALL, Vector2i(60, line - 40))
	var aim: Vector2i = pushed.position + Vector2i(6, 8)
	var splashed: Dictionary[int, Vector2i] = run.splash_preview(aim)
	assert_true(splashed.has(pushed.id), "the setup: the splash moves it")
	var preview: Array[int] = run.launch_wipes(aim)
	var lost_at: Array = []
	run.wave_struck.connect(func(_side: Vector2i, lost: Array[Star], _next: Vector2i) -> void:
		for star: Star in lost:
			lost_at.append(star.position))
	assert_lt(splashed[pushed.id].y, line, "the setup: still on the top")
	assert_false(run.launch_splashes(aim).has(pushed.id), "and in the sky")
	assert_true(run.launch(aim))
	assert_eq(preview, [pushed.id] as Array[int])
	assert_eq(lost_at, [splashed[pushed.id]], "taken where the splash left it")


func test_the_north_fish_opens_by_showing_the_wave() -> void:
	var run: RunState = _run()
	var placed: Array = []
	var struck: Array = []
	var cleared: Array = []
	run.splash_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.wave_struck.connect(func(side: Vector2i, lost: Array[Star], next: Vector2i) -> void: struck.append([side, lost.size(), next]))
	run.reflect_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.append(stars.size()))
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	var packs: Dictionary = run.owned_packs.duplicate()
	run.play_reflect_intro()
	assert_eq((placed[0] as Array).size(), 3)
	assert_eq(struck, [[Vector2i.UP, 2, Vector2i.UP]], "it wipes the top's two; the first real wave is still the top's")
	assert_eq(cleared, [4], "the other one and the burst's go")
	assert_eq(run.wave.launches, 0, "the intro doesn't count")
	assert_eq(run.wave.waves, 0)
	assert_true(run.stars.is_empty())
	assert_eq(run.owned_packs, packs)
	assert_eq(run.dust, 100)
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")
	for star: Star in placed[0]:
		assert_true(StarScatter.inner_rect(SKY).has_point(star.position))
		for landmark: Vector2i in run.scorpio.landmark_positions():
			assert_gte(star.position.distance_to(landmark), float(StarScatter.LANDMARK_SPACING), "clear of the figure")


func test_its_lines_fit() -> void:
	var run: RunState = _run()
	assert_eq(Hud.seam_rule(run), Hud.WAVE_MESSAGE % 2, "the launch from balance.json")
	assert_eq(Hud.wave_side_name(run.wave), "TOP")
	for text: String in [Hud.WAVE_MESSAGE % 99, Hud.WAVE_LOSS_MESSAGE, Hud.WAVE_NEXT_MESSAGE % "BOTTOM", Hud.WAVE_NEXT_MESSAGE % "RIGHT"]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_stage_says_its_rule_as_its_intro_shows_it() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var said: bool = false
	var start: int = Time.get_ticks_msec()
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 12000:
		await get_tree().process_frame
		said = said or hud.message() == Hud.seam_rule(main.run)
	assert_true(said)
	assert_eq(sky.star_count(), 0)


func test_the_cue_shows_the_side_and_marks_its_stars_once_settled() -> void:
	var main: Main = _main()
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	view.advance(SeamView.WINDUP_TIME + SeamView.SWEEP_TIME + SeamView.CRASH_TIME)
	view.settled = true
	assert_eq(view.cue_way(), Vector2i.ZERO, "no wave with the first launch: no cue")
	var line: int = _line(main.run)
	main.run.wave.launches = 1
	view.settled = false
	assert_eq(view.cue_way(), Vector2i.ZERO, "not while something plays")
	view.settled = true
	assert_eq(view.cue_way(), Vector2i.UP, "the top")
	assert_eq(view.after_way(), Vector2i.ZERO, "on one line the wave after is always the other half: not shown")
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	var above: int = 0
	var below: int = 0
	for point: Vector2i in pixels:
		if pixels[point] == Palette.S4:
			if point.y < line:
				above += 1
			else:
				below += 1
	assert_gt(above, 0, "ember chevrons on the top")
	assert_eq(below, 0, "none on the bottom")
	var star: Star = main.run.add_star(Star.Size.MEDIUM, Vector2i(30, line - 60))
	view.queue_redraw()
	pixels = view.pixels()
	var ring: Dictionary[Vector2i, Color] = HarvestView.lone_ring_pixels(star.position, star.size, 0.0)
	var marked: int = 0
	for point: Vector2i in ring:
		if pixels.get(point) in [Palette.S4, Palette.S3]:
			marked += 1
	assert_eq(marked, ring.size(), "the star it will take wears an ember ring")


func test_the_wave_rears_up_rushes_out_and_crashes_then_cues_the_next_side() -> void:
	var main: Main = _main()
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var line: int = _line(main.run)
	var sky: Rect2i = main.run.sky_rect
	view.sweep(Vector2i.UP, Vector2i.DOWN, [Vector2i(30, line - 40)] as Array[Vector2i])
	assert_true(view.is_sweeping())
	assert_eq(view.cue_way(), Vector2i.ZERO, "no cue while it plays")
	# The wind-up: the swell rears up past its cue's height.
	view.advance(SeamView.WINDUP_TIME * 0.9)
	assert_lt(_highest(view.pixels(), Palette.M6), line - SeamView.SWELL.max() - 2, "it rears up")
	# Halfway through the rush the wall is past halfway (fast, then slowing).
	view.advance(SeamView.WINDUP_TIME * 0.1 + SeamView.SWEEP_TIME / 2.0)
	var span: int = line - sky.position.y
	var front: int = _highest(view.pixels(), Palette.M6)
	assert_lt(front, line - span / 2, "past halfway at half time")
	assert_almost_eq(float(front), line - SeamView.rush_reach(0.5) * span, 7.0, "its crest, spray a few px ahead")
	var half: Vector2i = Vector2i(10, line - roundi(SeamView.rush_reach(0.5) * span))
	assert_almost_eq(view.sweep_delay(Vector2i.UP, half), SeamView.WINDUP_TIME + SeamView.SWEEP_TIME / 2.0, 0.02, "it reaches there then")
	assert_eq(view.carry_point(Vector2i.UP, Vector2i(30, line - 40)).x, 30, "a star rides straight out")
	assert_lt(view.carry_point(Vector2i.UP, Vector2i(30, line - 40)).y, line - 40)
	# The crash: a flash along the edge, then spray falling back.
	view.advance(SeamView.SWEEP_TIME / 2.0 + 0.02)
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	assert_eq(pixels.get(Vector2i(90, sky.position.y)), Palette.M6, "it breaks white on the edge")
	view.advance(SeamView.CRASH_TIME / 2.0)
	assert_false(view.pixels().get(Vector2i(90, sky.position.y)) == Palette.M6, "the flash is short")
	assert_true(view.is_sweeping(), "the spray still falls")
	main.run.wave.launches = 2
	view.advance(SeamView.CRASH_TIME / 2.0 + 0.01)
	assert_false(view.is_sweeping())
	assert_eq(view.cue_way(), Vector2i.DOWN, "then the bottom is cued")
	assert_almost_eq(SeamView.sweep_hold(), SeamView.WINDUP_TIME + SeamView.SWEEP_TIME, 0.001, "the crash isn't waited for")


## The topmost row holding `colour` above the water line.
func _highest(pixels: Dictionary[Vector2i, Color], colour: Color) -> int:
	var top: int = 1 << 20
	for point: Vector2i in pixels:
		if pixels[point] == colour:
			top = mini(top, point.y)
	return top


func test_a_wave_is_said_the_first_time_with_its_side() -> void:
	var main: Main = _main()
	_settle(main)
	var hud: Hud = main.get_node("HUD")
	hud.show_message("", 0.0, true)
	main.run.wave.launches = 1
	hud.call("_tell_wave")
	assert_eq(hud.message(), Hud.WAVE_NEXT_MESSAGE % "TOP")
	hud.show_message("", 0.0, true)
	hud.call("_tell_wave")
	assert_eq(hud.message(), "", "once a run")


func test_its_first_star_lost_is_said() -> void:
	var main: Main = _main()
	_settle(main)
	var hud: Hud = main.get_node("HUD")
	hud.set("_launch_shown", true)
	hud.show_message("", 0.0, true)
	hud.call("_tell_wave_loss", [])
	assert_eq(hud.message(), "", "nothing taken: nothing said")
	hud.call("_tell_wave_loss", [Star.new(1, Star.Size.SMALL, Vector2i(20, 100))])
	assert_eq(hud.message(), Hud.WAVE_LOSS_MESSAGE)


func test_a_whole_run_plays_its_waves_through_the_scene() -> void:
	var main: Main = _main()
	await _play_out(main)
	var run: RunState = main.run
	var sky: SkyView = main.get_node("Sky")
	assert_eq(sky.star_count(), 0, "the intro's stars gone")
	run.dust = 100
	for i: int in 3:
		if run.is_over():
			break
		if run.total_packs() == 0:
			run.buy("blue")
		for kind: String in ["blue", "red"]:
			if run.load_pack(kind):
				break
		assert_ne(run.loaded_pack, "", "a planet to throw (%s)" % [run.owned_packs])
		assert_true(run.launch(Vector2i(90, _line(run) + (40 if i % 2 == 0 else -40))))
		await _play_out(main)
		assert_eq(sky.star_count(), run.stars.size(), "the views follow the run after launch %d" % (i + 1))
