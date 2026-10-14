extends GutTest
## Pisces's fish (the North Fish): a fish under the water line swims toward each planet thrown, as
## bait, and eats the loose stars near where it stops. Its map, previews, intro, rule line and look.

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
	assert_gt(balance.fish_step, 0)
	assert_gt(balance.fish_bite, 0)
	assert_null(RunState.new(balance, Fixtures.rng(1), SKY, StarMap.pisces_knot()).fish, "no fish elsewhere")


func test_the_fish_waits_mid_line_and_swims_a_step_toward_the_bait() -> void:
	var run: RunState = _run()
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	assert_eq(run.fish.at, middle, "it waits at the line's middle")
	var step: int = run.fish.step
	assert_eq(run.fish_target(middle + Vector2i(-100, -30)), middle + Vector2i(-step, 0), "a step at most, along the line")
	assert_eq(run.fish_target(middle + Vector2i(10, 40)), middle + Vector2i(10, 0), "right under a near bait")
	var swum: Array = []
	run.fish_swam.connect(func(from: Vector2i, to: Vector2i) -> void: swum.append([from, to]))
	assert_true(run.launch(middle + Vector2i(-100, -30)))
	assert_eq(swum, [[middle, middle + Vector2i(-step, 0)]])
	assert_eq(run.fish.at, middle + Vector2i(-step, 0), "and waits there for the next")


func test_the_fish_never_leaves_the_line() -> void:
	var fish := Fish.new(Vector2i(90, 164), 48, 22, false, 8, 171)
	fish.move_to(Vector2i(20, 164))
	assert_eq(fish.swims_to(Vector2i(-50, 100)), Vector2i(8, 164))
	var up := Fish.new(Vector2i(90, 164), 48, 22, true, 86, 241)
	assert_eq(up.swims_to(Vector2i(10, 100)), Vector2i(90, 116), "along a line up and down")


func test_the_fish_eats_the_stars_near_where_it_stops_before_the_planet_bursts() -> void:
	var run: RunState = _run()
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	var bait: Vector2i = middle + Vector2i(-48, -40)
	var under: Vector2i = run.fish_target(bait)
	var near: Star = run.add_star(Star.Size.SMALL, under + Vector2i(6, 14))
	var far: Star = run.add_star(Star.Size.SMALL, under + Vector2i(0, run.fish.bite + 20))
	assert_eq(run.launch_bites(bait), [near.id] as Array[int], "the aim shows which it eats")
	var order: Array[String] = []
	var eaten: Array = []
	run.stars_bitten.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		order.append("bitten")
		for move: StarCurrent.Move in moves:
			assert_true(move.drained)
			assert_eq(move.to, at, "into the fish")
			eaten.append(move.star_id))
	run.pack_burst.connect(func(_k: String, _a: Vector2i, _s: Array[Star]) -> void: order.append("burst"))
	var dust: int = run.dust
	assert_true(run.launch(bait))
	assert_eq(order, ["bitten", "burst"] as Array[String])
	assert_eq(eaten, [near.id])
	assert_null(run.find_star(near.id))
	assert_not_null(run.find_star(far.id), "out of its bite")
	assert_eq(run.dust, dust, "an eaten star pays nothing")


func test_the_bite_preview_counts_the_splash_first() -> void:
	var run: RunState = _run()
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	var bait: Vector2i = middle + Vector2i(-48, -40)
	var under: Vector2i = run.fish_target(bait)
	# Just out of the bite, between it and the throw: the splash pushes it into the bite.
	var pushed: Star = run.add_star(Star.Size.SMALL, under + Vector2i(0, -(run.fish.bite + 6)))
	var preview: Array[int] = run.launch_bites(bait)
	var eaten: Array = []
	run.stars_bitten.connect(func(_at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		for move: StarCurrent.Move in moves:
			eaten.append(move.star_id))
	var lost: Array[int] = run.launch_splashes(bait)
	assert_true(run.launch(bait))
	assert_eq(eaten, preview, "the preview matches the bite")
	assert_lt(run.splash.push, run.fish.bite + 6, "the setup: the splash leaves it short of the line")
	assert_false(lost.has(pushed.id), "it survives the splash")
	assert_true(preview.has(pushed.id), "the splash pushed it into the bite")


func test_a_red_planet_baits_the_fish_where_it_sank_not_at_its_twins() -> void:
	var run: RunState = _run()
	run.owned_packs["red"] = 1
	run.loaded_pack = "red"
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	var thrown: Vector2i = middle + Vector2i(-30, -40)
	var swum: Array = []
	run.fish_swam.connect(func(_from: Vector2i, to: Vector2i) -> void: swum.append(to))
	var expected: Vector2i = run.fish_target(thrown)
	assert_true(run.launch(thrown))
	assert_eq(swum, [expected], "drawn to where the planet sank")
	assert_eq(expected, middle + Vector2i(-30, 0))


func test_the_north_fish_opens_by_showing_the_fish() -> void:
	var run: RunState = _run()
	var start: Vector2i = run.fish.at
	var placed: Array = []
	var swum: Array = []
	var bitten: Array = []
	var cleared: Array = []
	run.splash_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.fish_swam.connect(func(from: Vector2i, to: Vector2i) -> void: swum.append([from, to]))
	run.stars_bitten.connect(func(_at: Vector2i, moves: Array[StarCurrent.Move]) -> void: bitten.append(moves.size()))
	run.reflect_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.append(stars.size()))
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	var packs: Dictionary = run.owned_packs.duplicate()
	run.play_reflect_intro()
	assert_eq((placed[0] as Array).size(), 3)
	assert_eq(bitten, [2], "it eats the two by the line")
	assert_eq(cleared, [4], "the third and the burst's go")
	assert_eq(swum.size(), 2, "it swims to the bait, then back")
	assert_eq(swum[1][1], start)
	assert_eq(run.fish.at, start, "the run starts with it mid-line")
	assert_true(run.stars.is_empty())
	assert_eq(run.owned_packs, packs)
	assert_eq(run.dust, 100)
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")
	for star: Star in placed[0]:
		assert_true(StarScatter.inner_rect(SKY).has_point(star.position))
		for landmark: Vector2i in run.scorpio.landmark_positions():
			assert_gte(star.position.distance_to(landmark), float(StarScatter.LANDMARK_SPACING), "clear of the figure")


func test_its_rule_and_loss_lines_fit() -> void:
	assert_eq(Hud.seam_rule(_run()), Hud.FISH_MESSAGE)
	for text: String in [Hud.FISH_MESSAGE, Hud.FISH_LOSS_MESSAGE]:
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
		said = said or hud.message() == Hud.FISH_MESSAGE
	assert_true(said)
	assert_eq(sky.star_count(), 0)


func test_the_fish_shows_on_the_line_swims_and_previews_its_bite() -> void:
	var main: Main = _main()
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	view.advance(SeamView.SWIM_TIME + SeamView.BITE_TIME)
	var fish: Vector2i = main.run.fish.at
	assert_eq(view.fish_shown(), fish)
	assert_eq(view.pixels().get(fish), Palette.M5, "its back on the line")
	view.swim(fish, fish + Vector2i(-40, 0))
	view.advance(SeamView.SWIM_TIME / 2.0)
	assert_eq(view.fish_shown(), fish + Vector2i(-20, 0), "gliding")
	view.advance(SeamView.SWIM_TIME)
	assert_false(view.is_swimming())
	view.swim(fish + Vector2i(-40, 0), fish)
	view.advance(SeamView.SWIM_TIME + 0.01)
	view.bite(fish)
	assert_true(view.pixels().values().has(Palette.M5), "the bite's ring")
	view.advance(SeamView.BITE_TIME + 0.01)
	var near: Star = main.run.add_star(Star.Size.SMALL, main.run.fish_target(fish + Vector2i(-48, -40)) + Vector2i(4, 12))
	view.aim = fish + Vector2i(-48, -40)
	view.aiming = true
	assert_eq(main.run.launch_bites(view.aim), [near.id] as Array[int])
	assert_true(view.pixels().values().has(Palette.S4), "the star it would eat is marked")
	view.aiming = false
	assert_false(view.pixels().values().has(Palette.S4))


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
