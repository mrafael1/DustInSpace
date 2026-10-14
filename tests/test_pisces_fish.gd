extends GutTest
## Pisces's fish (the North Fish): a fish waits still on the water line and every second launch
## leaps at the nearest loose star and eats it. Its map, previews, intro, rule line and look.

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
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_fish_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_the_north_fish_is_stage_5() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.map_id(4), "pisces_north_fish")
	var map: StarMap = StarMap.pisces_north_fish()
	assert_true(map.fish)
	assert_true(map.splash, "the splash goes on")
	assert_eq(map.seam, StarMap.Seam.HORIZONTAL)
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
	for segment: Vector2i in map.segments:
		assert_between(Vector2(map.landmarks[segment.x]).distance_to(Vector2(map.landmarks[segment.y])), 30.0, 38.0)
	var balance: Balance = Balance.load_file()
	assert_gt(balance.fish_bite, 0)
	assert_eq(balance.fish_jump_every, 2, "every second launch")
	assert_null(RunState.new(balance, Fixtures.rng(1), SKY, StarMap.pisces_knot()).fish, "no fish elsewhere")


func test_the_fish_waits_mid_line_and_never_moves_toward_the_throw() -> void:
	var run: RunState = _run()
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	assert_eq(run.fish.at, middle, "it waits at the line's middle")
	for aim: Vector2i in [middle + Vector2i(-80, -30), middle + Vector2i(70, 40), middle + Vector2i(-60, 50)]:
		run.load_pack("blue")
		assert_true(run.launch(aim))
		assert_eq(run.fish.at, middle, "the throw doesn't draw it")


func test_a_launch_that_doesnt_leap_eats_nothing() -> void:
	var run: RunState = _run()
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	assert_false(run.fish.jumps_next(), "the first launch doesn't leap")
	var near: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(4, -12))
	var aim: Vector2i = middle + Vector2i(-60, 50)
	assert_true(run.launch_bites(aim).is_empty(), "the aim shows nothing eaten")
	assert_eq(run.fish_leap(aim), StarCords.NO_CROSSING)
	var bitten: Array = []
	run.stars_bitten.connect(func(_at: Vector2i, moves: Array[StarCurrent.Move]) -> void: bitten.append(moves.size()))
	assert_true(run.launch(aim))
	assert_eq(bitten, [0], "said, with nothing eaten")
	assert_not_null(run.find_star(near.id), "even right by it")


func test_every_second_launch_the_fish_leaps_at_the_nearest_star_in_reach() -> void:
	var run: RunState = _run()
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	var aim: Vector2i = middle + Vector2i(-60, 50)
	var jumped: Array = []
	run.fish_jumped.connect(func(from: Vector2i, to: Vector2i, caught: Array[int]) -> void: jumped.append([from, to, caught]))
	assert_true(run.launch(aim))
	run.stars.clear()
	assert_true(jumped.is_empty())
	assert_true(run.fish.jumps_next(), "the second leaps")
	var reach: int = run.fish.jump_reach
	var near: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(30, -40))
	var nearer: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(-20, -36))
	var beside: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(-20 - (run.fish.bite - 4), -36))
	var out: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(0, -(reach + 10)))
	run.load_pack("blue")
	assert_eq(run.fish_leap(aim), nearer.position, "the nearest in reach")
	var preview: Array[int] = run.launch_bites(aim)
	var eaten: Array = []
	var caught_at: Array = []
	var order: Array[String] = []
	run.stars_bitten.connect(func(_at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		order.append("bitten")
		for move: StarCurrent.Move in moves:
			assert_true(move.drained)
			eaten.append(move.star_id)
			caught_at.append(move.to))
	run.pack_burst.connect(func(_k: String, _a: Vector2i, _s: Array[Star]) -> void: order.append("burst"))
	var dust: int = run.dust
	assert_true(run.launch(aim))
	assert_eq(order, ["bitten", "burst"] as Array[String], "before the planet bursts")
	assert_eq(jumped, [[middle, nearer.position, [nearer.id, beside.id] as Array[int]]], "it leaps, catching the stars there")
	assert_eq(eaten, preview, "as the aim showed")
	assert_eq(caught_at, [nearer.position, nearer.position], "caught where it leapt")
	assert_not_null(run.find_star(near.id), "out of its bite there")
	assert_not_null(run.find_star(out.id), "out of its reach")
	assert_eq(run.dust, dust, "an eaten star pays nothing")
	assert_eq(run.fish.at, middle, "back at its spot")
	assert_false(run.fish.jumps_next(), "then the count starts again")


func test_the_leap_preview_counts_the_splash_first() -> void:
	var run: RunState = _run()
	run.fish.launches = run.fish.jump_every - 1
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	# Two stars, the nearer one pushed out of reach by the splash: the leap goes for the other.
	var pushed: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(-30, -40))
	var other: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(40, -36))
	var aim: Vector2i = pushed.position + Vector2i(6, 8)
	var splashed: Dictionary[int, Vector2i] = run.splash_preview(aim)
	assert_true(splashed.has(pushed.id), "the setup: the splash moves it")
	var expected: Star = pushed if middle.distance_squared_to(splashed[pushed.id]) < middle.distance_squared_to(other.position) else other
	var preview: Array[int] = run.launch_bites(aim)
	var eaten: Array = []
	run.stars_bitten.connect(func(_at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		for move: StarCurrent.Move in moves:
			eaten.append(move.star_id))
	assert_true(run.launch(aim))
	assert_eq(eaten, preview, "the preview matches the leap")
	assert_true(eaten.has(expected.id), "it goes for where the splash left the stars")


func test_a_leaping_launch_with_nothing_in_reach_stays() -> void:
	var run: RunState = _run()
	run.fish.launches = run.fish.jump_every - 1
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	var far: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(0, -(run.fish.jump_reach + 10)))
	var jumped: Array = []
	run.fish_jumped.connect(func(_from: Vector2i, to: Vector2i, _caught: Array[int]) -> void: jumped.append(to))
	assert_eq(run.fish_leap(middle + Vector2i(-60, 50)), StarCords.NO_CROSSING)
	assert_true(run.launch(middle + Vector2i(-60, 50)))
	assert_true(jumped.is_empty())
	assert_not_null(run.find_star(far.id))
	assert_false(run.fish.jumps_next(), "the launch still counts")


func test_the_north_fish_opens_by_showing_the_leap() -> void:
	var run: RunState = _run()
	var start: Vector2i = run.fish.at
	var placed: Array = []
	var jumped: Array = []
	var bitten: Array = []
	var cleared: Array = []
	run.splash_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.fish_jumped.connect(func(_from: Vector2i, to: Vector2i, caught: Array[int]) -> void: jumped.append([to, caught]))
	run.stars_bitten.connect(func(_at: Vector2i, moves: Array[StarCurrent.Move]) -> void: bitten.append(moves.size()))
	run.reflect_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.append(stars.size()))
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	var packs: Dictionary = run.owned_packs.duplicate()
	run.play_reflect_intro()
	assert_eq((placed[0] as Array).size(), 3)
	var near: Star = (placed[0] as Array)[0]
	assert_eq(jumped, [[near.position, [near.id] as Array[int]]], "it leaps at the near one")
	assert_eq(bitten, [1], "and eats only it")
	assert_eq(cleared, [5], "the other two and the burst's go")
	assert_eq(run.fish.at, start, "it stays at its spot")
	assert_eq(run.fish.launches, 0, "the intro doesn't count toward the leap")
	assert_true(run.stars.is_empty())
	assert_eq(run.owned_packs, packs)
	assert_eq(run.dust, 100)
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")
	for star: Star in placed[0]:
		assert_true(StarScatter.inner_rect(SKY).has_point(star.position))
		for landmark: Vector2i in run.scorpio.landmark_positions():
			assert_gte(star.position.distance_to(landmark), float(StarScatter.LANDMARK_SPACING), "clear of the figure")


func test_its_rule_and_loss_lines_fit() -> void:
	assert_eq(Hud.seam_rule(_run()), Hud.FISH_MESSAGE % 2, "the rhythm from balance.json")
	for text: String in [Hud.FISH_MESSAGE % 99, Hud.FISH_LOSS_MESSAGE]:
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


func test_the_fish_shows_on_the_line_and_previews_only_a_leap() -> void:
	var main: Main = _main()
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	view.advance(SeamView.JUMP_TIME + SeamView.BITE_TIME)
	var fish: Vector2i = main.run.fish.at
	assert_eq(view.fish_shown(), fish)
	assert_eq(view.pixels().get(fish), Palette.M5, "its back on the line")
	var near: Star = main.run.add_star(Star.Size.SMALL, fish + Vector2i(-20, -30))
	view.aim = fish + Vector2i(60, 40)
	view.aiming = true
	assert_false(view.pixels().values().has(Palette.S4), "no leap this launch: nothing marked")
	main.run.fish.launches = main.run.fish.jump_every - 1
	view.queue_redraw()
	assert_eq(main.run.launch_bites(view.aim), [near.id] as Array[int])
	assert_true(view.pixels().values().has(Palette.S4), "the star it would eat is marked")
	view.aiming = false


func test_a_loss_line_still_being_read_isnt_overwritten_by_the_next() -> void:
	var main: Main = _main()
	_settle(main)
	var hud: Hud = main.get_node("HUD")
	hud.set("_launch_shown", true)
	hud.show_message("", 0.0, true)
	var drained: Array[StarCurrent.Move] = [StarCurrent.Move.new(1, Vector2i(10, 100), Vector2i(-4, 100), true)]
	hud.call("_tell_splash_loss", drained)
	assert_eq(hud.message(), Hud.SPLASH_LOSS_MESSAGE)
	hud.call("_tell_splash_loss", drained, Hud.FISH_LOSS_MESSAGE)
	assert_eq(hud.message(), Hud.SPLASH_LOSS_MESSAGE, "the splash's line stays to be read")
	assert_false((hud.get("_losses_told") as Dictionary).has(Hud.FISH_LOSS_MESSAGE), "the fish's waits for a later loss")


func test_the_fish_glows_before_it_leaps_and_arcs_out_to_the_star() -> void:
	var main: Main = _main()
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	view.advance(1.0)
	var fish: Vector2i = main.run.fish.at
	assert_eq(view.pixels().get(fish), Palette.M5, "not yet")
	main.run.fish.launches = main.run.fish.jump_every - 1
	view.queue_redraw()
	assert_eq(view.pixels().get(fish), Palette.S4, "it glows red before it leaps")
	assert_true(view.pixels().values().has(Palette.S3), "its belly too")
	view.jump(fish, fish + Vector2i(20, -40))
	view.advance(SeamView.JUMP_TIME / 2.0)
	assert_eq(view.fish_shown(), fish + Vector2i(20, -40), "at the star at the top of its leap")
	assert_true(view.is_biting(), "it bites there")
	view.carry()
	view.advance(SeamView.JUMP_TIME / 4.0)
	assert_true(view.pixels().values().has(Palette.M6), "carrying the star back")
	view.advance(SeamView.JUMP_TIME / 4.0 + 0.01)
	assert_false(view.is_jumping())
	assert_false(view.is_carrying(), "into the water")
	assert_eq(view.fish_shown(), fish, "back on the line")
	assert_lt(SeamView.leap_point(fish, fish + Vector2i(20, -40), 0.5).y, fish.y - 20, "the arc's middle, above the straight line")
	assert_lt(SeamView.leap_point(fish, fish + Vector2i(40, -10), 0.5).y, fish.y - 5, "it bows up, out of the water")


func test_the_leap_is_said_the_first_time_and_fits() -> void:
	for line: String in Hud.JUMP_MESSAGE.split("\n"):
		assert_lte(line.length(), 24, line)
	var main: Main = _main()
	_settle(main)
	var hud: Hud = main.get_node("HUD")
	hud.show_message("", 0.0, true)
	main.run.fish.launches = main.run.fish.jump_every - 1
	hud.call("_tell_jump")
	assert_eq(hud.message(), Hud.JUMP_MESSAGE)
