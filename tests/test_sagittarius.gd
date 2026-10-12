extends GutTest
## Chapter 5, Sagittarius: its figure and chart, its first three stages (the Arrow, the Bow, the
## Body), the hungry hole, the hole intro, and how they show.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs"]


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
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_sagittarius_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_sagittarius_is_chapter_5_after_virgo_on_the_ring() -> void:
	var chapter := Chapter.new(ChapterDef.sagittarius())
	assert_eq(chapter.def.number, 5)
	assert_eq(chapter.def.unlocked_by, "virgo")
	assert_eq(chapter.stage_name(0), "ARROW")
	assert_eq(chapter.stage_name(1), "BOW")
	assert_eq(chapter.stage_name(2), "BODY")
	for stage: int in BUILT.size():
		assert_eq(chapter.map_id(stage), BUILT[stage])
		assert_true(chapter.has_stage(stage))
	for stage: int in range(BUILT.size(), Chapter.stage_count()):
		assert_false(chapter.has_stage(stage), "the Head and the final aren't built yet")
	assert_eq(ChapterSelect.sky_x("sagittarius") - ChapterSelect.sky_x("virgo"), 3 * ChapterSelect.SKY_SPAN, "three signs on, round the ring")


func test_the_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.sagittarius()
	var figure: StarMap = def.figure
	assert_eq(figure.count(), 13)
	assert_eq(figure.segment_count(), 12, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(Scorpio.HOME_SKY)
	for i: int in figure.count():
		assert_true(inner.has_point(figure.landmarks[i]), "star %d sits in the sky" % i)
		assert_gt(Vector2(figure.landmarks[i]).distance_to(Vector2(def.final_at)), 24.0, "the crown keeps clear")
		for j: int in range(i + 1, figure.count()):
			assert_gte(Vector2(figure.landmarks[i]).distance_to(Vector2(figure.landmarks[j])), 24.0, "%d and %d" % [i, j])
	var owned: Array[int] = []
	for stage: int in Chapter.FINAL:
		owned.append_array(def.stages[stage]["stars"])
	owned.sort()
	assert_eq(owned, range(13), "every star belongs to exactly one part")
	assert_eq(StarMap.by_id("sagittarius").title, "SAGITTARIUS")


func test_the_first_stages_are_pickable_black_hole_stages_with_the_hole_clear_of_the_figure() -> void:
	var balance: Balance = Balance.load_file()
	for id: String in BUILT:
		var map: StarMap = StarMap.by_id(id)
		assert_eq(map.id, id)
		assert_true(map.black_hole, id)
		assert_eq(map.segment_count(), map.count() - 1, "%s: the strings form a tree" % id)
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		var widest: int = balance.black_hole_for(id).max_horizon + GravityView.RING_GAP
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [id, i])
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.black_hole_center)), widest + 8.0, "%s star %d keeps clear of the hole at its widest" % [id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
		assert_gt(balance.black_hole_for(id).pull, 0, "%s has its tuning" % id)
	assert_true(StarMap.sagittarius_body().black_hole_hungry, "the Body brings the hungry hole")
	assert_false(StarMap.sagittarius_arrow().black_hole_hungry)
	assert_false(StarMap.sagittarius_bow().intros, "the Bow brings nothing new to show")


func test_a_stages_tuning_overrides_the_blocks() -> void:
	var balance: Balance = Balance.load_file()
	var arrow: Dictionary = balance.black_hole_for("sagittarius_arrow")
	assert_eq(arrow.pull, balance.black_hole_stages["sagittarius_arrow"]["pull"])
	assert_eq(arrow.horizon, balance.black_hole_horizon, "what a stage doesn't set comes from the block")
	assert_eq(balance.black_hole_for("black_hole_trial").pull, balance.black_hole_pull)
	assert_eq(_run(StarMap.sagittarius_arrow()).gravity.max_step, arrow.max_step)


func test_the_hungry_hole_grows_with_every_star_it_swallows_up_to_its_cap() -> void:
	var hole := StarGravity.new(Vector2i(90, 164), 8, 1400, 40, 1, 10)
	assert_eq(hole.feed(1), 1)
	assert_eq(hole.horizon, 9)
	assert_eq(hole.feed(3), 1, "capped")
	assert_eq(hole.horizon, 10)
	var plain := StarGravity.new(Vector2i(90, 164), 8, 1400, 40)
	assert_eq(plain.feed(5), 0, "a hole without hunger never grows")


func test_the_body_hole_grows_as_it_swallows_and_the_arrows_doesnt() -> void:
	for id: String in ["sagittarius_body", "sagittarius_arrow"]:
		var run: RunState = _run(StarMap.by_id(id))
		var before: int = run.gravity.horizon
		var doomed: Star = run.add_star(Star.Size.SMALL, run.gravity.center + Vector2i(0, -(before + 4)))
		assert_true(run.launch_swallows().has(doomed.id))
		run.load_pack("blue")
		assert_true(run.launch(Vector2i(20, 240)))
		assert_null(run.find_star(doomed.id))
		if id == "sagittarius_body":
			assert_gt(run.gravity.horizon, before, "the Body's hole widened")
		else:
			assert_eq(run.gravity.horizon, before)


func test_the_arrow_opens_by_showing_stars_fall_into_the_hole() -> void:
	var run: RunState = _run(StarMap.sagittarius_arrow())
	var placed: Array[Star] = []
	var fell: Array = []
	var cleared: Array[Star] = []
	run.hole_intro_placed.connect(func(stars: Array[Star]) -> void: placed.assign(stars))
	run.stars_fell.connect(func(falls: Array[StarGravity.Fall]) -> void: fell.append(falls))
	run.hole_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.assign(stars))
	var packs: Dictionary = run.owned_packs.duplicate()
	var horizon: int = run.gravity.horizon
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	run.play_hole_intro()
	assert_eq(placed.size(), 3, "one star of each size")
	assert_eq(fell.size(), RunState.HOLE_INTRO_PULLS)
	var swallowed: int = 0
	for falls: Array in fell:
		for fall: StarGravity.Fall in falls:
			swallowed += 1 if fall.swallowed else 0
	assert_gt(swallowed, 0, "the hole swallows some")
	assert_lt(swallowed, 3, "and one is left to fade")
	assert_eq(cleared.size(), 3 - swallowed)
	assert_true(run.stars.is_empty(), "the sky is empty for the run")
	assert_eq(run.owned_packs, packs, "no pack used")
	assert_eq(run.dust, 100, "no reward")
	assert_eq(run.gravity.horizon, horizon)
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")


func test_the_hole_intro_plays_only_once_where_the_stage_has_intros() -> void:
	var bow: RunState = _run(StarMap.sagittarius_bow())
	var shown: Array = []
	bow.hole_intro_placed.connect(func(stars: Array[Star]) -> void: shown.append(stars))
	bow.play_hole_intro()
	assert_true(shown.is_empty(), "the Bow opens without one")
	var arrow: RunState = _run(StarMap.sagittarius_arrow())
	arrow.add_star(Star.Size.SMALL, Vector2i(20, 100))
	arrow.hole_intro_placed.connect(func(stars: Array[Star]) -> void: shown.append(stars))
	arrow.play_hole_intro()
	assert_true(shown.is_empty(), "not once the run has begun")


func test_the_hole_intro_stars_stand_clear_of_the_figure() -> void:
	for id: String in ["sagittarius_arrow", "sagittarius_body"]:
		var run: RunState = _run(StarMap.by_id(id))
		var spots: Array[Vector2i] = run.hole_intro_spots()
		assert_eq(spots.size(), 3, id)
		for spot: Vector2i in spots:
			assert_true(StarScatter.inner_rect(SKY).has_point(spot))
			for landmark: Vector2i in run.scorpio.landmark_positions():
				assert_gte(spot.distance_to(landmark), float(StarScatter.MIN_SPACING), "%s: clear of the figure" % id)
			for segment: int in run.scorpio.map.segment_count():
				var ends: Array[Vector2i] = run.scorpio.map.segment_ends(segment)
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(spot), Vector2(ends[0] + run.scorpio.shift), Vector2(ends[1] + run.scorpio.shift))
				assert_gte(closest.distance_to(Vector2(spot)), RunState.HOLE_INTRO_STRING_CLEARANCE, "%s: clear of its strings" % id)


func test_the_body_intro_shows_the_hole_grow_then_the_run_starts_with_it_as_it_was() -> void:
	var main: Main = _main("sagittarius_body")
	var view: GravityView = main.get_node("Sky/GravityLayer")
	var horizon: int = main.run.gravity.horizon
	var widest: int = horizon
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 8000:
		await get_tree().process_frame
		widest = maxi(widest, view.shown_horizon())
		if widest > horizon and not sequencer.is_busy() and not view.is_swallowing():
			break
	assert_gt(widest, horizon, "the demo's hole grew as it swallowed")
	await get_tree().process_frame
	assert_eq(view.shown_horizon(), horizon, "and the run's own hole is as it was")


func test_each_stage_says_its_rule_in_a_line_that_fits() -> void:
	assert_eq(Hud.hole_rule(_run(StarMap.sagittarius_arrow()).gravity), Hud.HOLE_MESSAGE)
	assert_eq(Hud.hole_rule(_run(StarMap.sagittarius_body()).gravity), Hud.HUNGRY_MESSAGE)
	for text: String in [Hud.HOLE_MESSAGE, Hud.HUNGRY_MESSAGE, Hud.SWALLOW_LOSS_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_a_stage_with_a_hole_says_its_rule_as_the_intro_shows_it() -> void:
	var main: Main = _main("sagittarius_arrow")
	_settle(main)
	var hud: Hud = main.get_node("HUD")
	assert_eq(hud.message(), Hud.HOLE_MESSAGE)


func _twins() -> StarGravity:
	var hole := StarGravity.new(Vector2i(20, 162), 8, 800, 24)
	hole.add_twin(Vector2i(160, 162), 24, 12)
	return hole


func test_each_star_falls_toward_its_nearest_hole() -> void:
	var hole: StarGravity = _twins()
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, Vector2i(60, 162)), Star.new(2, Star.Size.SMALL, Vector2i(120, 162))]
	var result: Dictionary[int, Vector2i] = hole.preview(stars, SKY, [])
	assert_lt(result[1].x, 60, "toward the left hole")
	assert_gt(result[2].x, 120, "toward the right hole")
	var doomed := Star.new(3, Star.Size.SMALL, Vector2i(150, 162))
	var into: Dictionary[int, Vector2i] = hole.preview([doomed] as Array[Star], SKY, [])
	assert_eq(into[3], Vector2i(160, 162), "swallowed by the nearer twin")
	assert_true(hole.swallowed(into[3]))


func test_twins_drift_together_along_their_path_and_merge_into_one_bigger_hole() -> void:
	var hole: StarGravity = _twins()
	assert_eq(hole.launches_to_merge(), 3)
	assert_eq(hole.next_centers(), [Vector2i(44, 162), Vector2i(136, 162)] as Array[Vector2i])
	assert_false(hole.drift_holes())
	assert_false(hole.drift_holes())
	assert_true(hole.merges_next(), "the next drift would make their horizons touch")
	assert_eq(hole.next_centers(), [Vector2i(90, 162)] as Array[Vector2i], "they meet in the middle")
	assert_true(hole.drift_holes())
	assert_false(hole.has_twins())
	assert_eq(hole.centers, [Vector2i(90, 162)] as Array[Vector2i])
	assert_eq(hole.horizon, 12, "one bigger hole")
	assert_false(hole.drift_holes(), "one hole stays put")


func test_the_legs_holes_path_and_merged_hole_keep_clear_of_the_figure() -> void:
	var map: StarMap = StarMap.sagittarius_legs()
	var run: RunState = _run(map)
	var hole: StarGravity = run.gravity.copy()
	assert_true(hole.has_twins())
	var tuning: Dictionary = Balance.load_file().black_hole_for(map.id)
	for launch: int in hole.launches_to_merge() + 1:
		for i: int in hole.centers.size():
			for landmark: Vector2i in run.scorpio.landmark_positions():
				assert_gt(Vector2(landmark).distance_to(Vector2(hole.centers[i])), hole.horizons[i] + GravityView.RING_GAP + 6.0, "launch %d: hole %d clear of the figure" % [launch, i])
		hole.drift_holes()
	assert_eq(hole.horizon, tuning.merge_horizon)


func test_the_merge_is_a_big_bang_that_clears_the_sky_for_no_dust_and_keeps_lit_stars() -> void:
	var run: RunState = _run(StarMap.sagittarius_legs())
	var banged: Array = []
	var drifted: Array = []
	run.big_bang_started.connect(func(at: Vector2i, cleared: Array[Star], dust: int) -> void: banged.append([at, cleared.size(), dust]))
	run.holes_drifted.connect(func(_from: Array[Vector2i], to: Array[Vector2i], merged: bool) -> void: drifted.append([to, merged]))
	run.scorpio.light(1)
	var lit: Array[bool] = run.scorpio.lit.duplicate()
	for launch: int in 3:
		run.add_star(Star.Size.BIG, Vector2i(90, 96))
		run.load_pack("blue")
		assert_true(run.launch(Vector2i(90, 240)))
	assert_eq(drifted.size(), 3)
	assert_false(drifted[0][1])
	assert_true(drifted[2][1], "they meet on the third launch")
	assert_eq(banged.size(), 1)
	assert_eq(banged[0][0], run.gravity.center, "the Big Bang plays where they met")
	assert_gt(banged[0][1], 0, "it took the loose stars")
	assert_eq(banged[0][2], 0, "and pays no dust")
	assert_true(run.stars.is_empty(), "the sky is clear")
	assert_eq(run.dust, 100)
	assert_eq(run.scorpio.lit, lit, "lit stars stay lit")
	assert_false(run.gravity.has_twins(), "one bigger hole stays")


func test_the_legs_opens_by_forecasting_the_twins_path_and_changes_nothing() -> void:
	var run: RunState = _run(StarMap.sagittarius_legs())
	var forecast: Array = []
	run.holes_forecast.connect(func(paths: Array) -> void: forecast.assign(paths))
	var centers: Array[Vector2i] = run.gravity.centers.duplicate()
	run.play_twins_intro()
	assert_eq(forecast.size(), 2)
	assert_eq((forecast[0] as Array).size(), run.gravity.launches_to_merge())
	assert_eq(forecast[0].back(), forecast[1].back(), "both paths end where they meet")
	assert_eq(run.gravity.centers, centers, "the run's holes haven't moved")
	var shown: Array = []
	run.hole_intro_placed.connect(func(stars: Array[Star]) -> void: shown.append(stars))
	run.play_hole_intro()
	assert_true(shown.is_empty(), "the twins' stage shows its forecast, not the falling stars")
	assert_eq(Hud.hole_rule(run.gravity), Hud.TWINS_MESSAGE)


func test_the_path_shows_where_the_twins_go_and_turns_ember_on_the_last_step() -> void:
	var hole: StarGravity = _twins()
	var calm: Dictionary[Vector2i, Color] = GravityView.path_pixels(hole.centers, hole.next_centers(), 8, false, 12, 0.0)
	assert_true(calm.values().has(Palette.M3), "a dotted line between them")
	assert_true(calm.values().has(Palette.M4), "ghost rings where they'll be")
	assert_false(calm.values().has(Palette.S4))
	hole.drift_holes()
	hole.drift_holes()
	var last: Dictionary[Vector2i, Color] = GravityView.path_pixels(hole.centers, hole.next_centers(), 8, hole.merges_next(), 12, 0.0)
	assert_true(last.values().has(Palette.S4), "the meeting point warns in ember")
	for color: Color in last.values():
		assert_has([Palette.S3, Palette.S4], color)
