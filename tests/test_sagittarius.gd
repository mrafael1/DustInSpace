extends GutTest
## Chapter 5, Sagittarius: its figure and chart, its first three stages (the Arrow, the Bow, the
## Body), the hungry hole, the hole intro, and how they show.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs", "sagittarius_head"]


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
	assert_eq(chapter.map_id(Chapter.FINAL), "sagittarius_final", "every stage is built")
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


func test_the_gauge_drinks_a_share_of_light_and_empties_when_full() -> void:
	var hole := StarGravity.new(Vector2i(92, 158), 8, 800, 24)
	hole.set_gauge(25, 50)
	assert_eq(hole.drinks(25), 12, "half, rounded down")
	assert_eq(hole.drinks(5), 2)
	assert_false(hole.absorb(12))
	assert_eq(hole.absorbed, 12)
	assert_true(hole.fills_with(13))
	assert_false(hole.fills_with(12))
	assert_true(hole.absorb(13), "full")
	assert_eq(hole.absorbed, 0, "and it empties")
	var plain := StarGravity.new(Vector2i(92, 158), 8, 800, 24)
	assert_eq(plain.drinks(25), 0, "a hole without a gauge drinks nothing")


func _head_link(run: RunState, size: Star.Size, at: Vector2i) -> Array[int]:
	var ids: Array[int] = []
	for k: int in 3:
		ids.append(run.add_star(size, at + Vector2i(k * 18, 0)).id)
	return ids


func test_the_head_drinks_all_of_a_links_light_so_the_sun_gets_none() -> void:
	var run: RunState = _run(StarMap.sagittarius_head())
	var absorbed: Array = []
	var collected: Array = []
	run.light_absorbed.connect(func(_from: Vector2i, amount: int, now: int, capacity: int) -> void: absorbed.append([amount, now, capacity]))
	run.combo_collected.connect(func(_combo: String, _stars: Array[Star], _dust: int, light: int) -> void: collected.append(light))
	var light: int = run.light
	assert_eq(run.link(_head_link(run, Star.Size.MEDIUM, Vector2i(20, 100))), "medium_triple")
	var full: int = run.balance.combos["medium_triple"].light
	assert_eq(absorbed, [[full, full, run.gravity.capacity]])
	assert_eq(collected, [0], "no light flies to the Sun")
	assert_eq(run.light, light, "the Sun can't fill, so it never rekindles")


func test_the_link_that_fills_the_gauge_bangs_the_sky_for_no_dust() -> void:
	var run: RunState = _run(StarMap.sagittarius_head())
	var banged: Array = []
	run.big_bang_started.connect(func(at: Vector2i, cleared: Array[Star], dust: int) -> void: banged.append([at, cleared.size(), dust]))
	run.gravity.absorbed = run.gravity.capacity - 10
	var bystander: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 230))
	var ids: Array[int] = _head_link(run, Star.Size.BIG, Vector2i(20, 100))
	assert_true(run.link_fills_gauge(ids), "the trace can warn before the release")
	var dust: int = run.dust
	run.scorpio.light(2)
	var lit: Array[bool] = run.scorpio.lit.duplicate()
	run.link(ids)
	assert_eq(banged.size(), 1)
	assert_eq(banged[0][0], run.gravity.center, "it bangs at the hole")
	assert_eq(banged[0][2], 0, "for no dust")
	assert_null(run.find_star(bystander.id), "the sky is cleared")
	assert_eq(run.dust, dust + run.link_dust("big_triple"), "the link still pays its own dust")
	assert_eq(run.scorpio.lit, lit, "lit stars stay lit")
	assert_eq(run.gravity.absorbed, 0, "the gauge empties")


func test_a_small_link_doesnt_fill_the_gauge_and_other_stages_have_none() -> void:
	var run: RunState = _run(StarMap.sagittarius_head())
	run.gravity.absorbed = run.gravity.capacity - 10
	assert_false(run.link_fills_gauge(_head_link(run, Star.Size.SMALL, Vector2i(20, 100))))
	var arrow: RunState = _run(StarMap.sagittarius_arrow())
	assert_false(arrow.gravity.has_gauge())
	assert_false(arrow.link_fills_gauge(_head_link(arrow, Star.Size.BIG, Vector2i(20, 100))))


func test_the_head_opens_by_showing_a_link_whose_light_the_hole_drinks_and_changes_nothing() -> void:
	var run: RunState = _run(StarMap.sagittarius_head())
	var placed: Array[Star] = []
	var linked: Array = []
	run.gauge_intro_placed.connect(func(stars: Array[Star]) -> void: placed.assign(stars))
	run.gauge_intro_linked.connect(func(link: Array[int], amount: int) -> void: linked.append([link, amount]))
	var light: int = run.light
	var packs: Dictionary = run.owned_packs.duplicate()
	run.play_gauge_intro()
	assert_eq(placed.size(), 3, "one star of each size")
	var sizes: Array[int] = []
	for star: Star in placed:
		sizes.append(star.size)
	assert_eq(Combos.evaluate(sizes), Combos.SEQUENCE, "a link a player could make")
	assert_eq(linked.size(), 1)
	assert_eq((linked[0][0] as Array).size(), 3)
	assert_eq(linked[0][1], run.gravity.drinks(run.balance.combos[Combos.SEQUENCE].light))
	assert_lt(linked[0][1], run.gravity.capacity, "the demo fills it only part way")
	assert_eq(run.gravity.absorbed, 0, "the run's gauge is empty")
	assert_eq(run.light, light)
	assert_eq(run.owned_packs, packs)
	assert_true(run.stars.is_empty())
	for star: Star in placed:
		for landmark: Vector2i in run.scorpio.landmark_positions():
			assert_gte(star.position.distance_to(landmark), float(StarScatter.MIN_SPACING), "clear of the figure")
	assert_eq(Hud.hole_rule(run.gravity), Hud.GAUGE_MESSAGE)
	var falling: Array = []
	run.hole_intro_placed.connect(func(stars: Array[Star]) -> void: falling.append(stars))
	run.play_hole_intro()
	assert_true(falling.is_empty(), "the Head shows its gauge, not the falling stars")


func test_a_holes_big_bang_throws_no_decoys_a_planets_does() -> void:
	var main: Main = _main("sagittarius_head")
	_settle(main)
	var sky: SkyView = main.get_node("Sky")
	assert_eq(sky.call("_decoys", Vector2i(92, 158)).size(), 0, "no planet opened into it")
	sky.set("_launched_kind", "blue")
	assert_eq(sky.call("_decoys", Vector2i(92, 158)).size(), main.run.balance.packs["blue"].stars, "a planet's Big Bang keeps its decoys")


func test_the_gauge_fills_in_gold_and_blinks_ember_when_a_link_would_fill_it() -> void:
	var half: Dictionary[Vector2i, Color] = GravityView.gauge_pixels(Vector2i(92, 158), 14, 0.5, false, 0.0)
	var gold: int = half.values().filter(func(c: Color) -> bool: return c == Palette.C1 or c == Palette.C0).size()
	assert_eq(gold, GravityView.GAUGE_DOTS / 2)
	assert_eq(half[Vector2i(92, 144)], Palette.C0, "it fills from the top")
	var warning: Dictionary[Vector2i, Color] = GravityView.gauge_pixels(Vector2i(92, 158), 14, 0.5, true, 0.0)
	assert_true(warning.values().has(Palette.S4))
	assert_true(warning.values().has(Palette.S3))


func test_a_full_gauges_big_bang_plays_the_void_not_the_reward() -> void:
	var main: Main = _main("sagittarius_head")
	_settle(main)
	var played: Array[StringName] = []
	(main.get_node("Sfx") as Sfx).cue_played.connect(func(cue: StringName, _pitch: float) -> void: played.append(cue))
	var run: RunState = main.run
	run.gravity.absorbed = run.gravity.capacity - 1
	var ids: Array[int] = []
	var made: Array[Star] = []
	for k: int in 3:
		var star: Star = run.add_star(Star.Size.BIG, Vector2i(20 + k * 18, 100))
		made.append(star)
		ids.append(star.id)
	run.pack_burst.emit("blue", Vector2i(38, 100), made)
	run.link(ids)
	var big_bang: BigBangSequence = main.get_node("BigBang")
	var start: int = Time.get_ticks_msec()
	while not played.has(&"big_bang_void") and Time.get_ticks_msec() - start < 10000:
		await get_tree().process_frame
	assert_true(big_bang.is_losing())
	assert_has(played, &"big_bang_void")
	assert_does_not_have(played, &"big_bang_bang")


func test_the_final_is_the_whole_archer_with_every_power_of_the_hole() -> void:
	var map: StarMap = StarMap.sagittarius_final()
	var figure: StarMap = StarMap.sagittarius()
	assert_eq(map.landmarks, figure.landmarks, "the chart's own figure")
	assert_eq(map.count() - map.starting_lit.size(), 12, "twelve to light")
	assert_true(map.black_hole and map.black_hole_twins and map.black_hole_hungry and map.black_hole_gauge)
	assert_true(map.big_bang_finale)
	assert_ne(map.arrival_epithet, "", "it arrives with its title card")


func test_the_finals_twins_run_down_a_clear_corridor_and_merge_at_the_teapots_heart() -> void:
	var run: RunState = _run(StarMap.sagittarius_final())
	var hole: StarGravity = run.gravity.copy()
	var tuning: Dictionary = Balance.load_file().black_hole_for("sagittarius_final")
	for launch: int in hole.launches_to_merge():
		for c: Vector2i in hole.centers:
			for landmark: Vector2i in run.scorpio.landmark_positions():
				assert_gt(Vector2(landmark).distance_to(Vector2(c)), hole.horizon + GravityView.RING_GAP + 4.0, "launch %d: the corridor is clear" % launch)
		hole.drift_holes()
	assert_false(hole.has_twins())
	for landmark: Vector2i in run.scorpio.landmark_positions():
		assert_gt(Vector2(landmark).distance_to(Vector2(hole.center)), tuning.max_horizon + GravityView.RING_GAP + 8.0, "the merged hole, at its widest, keeps clear")


func test_the_twins_neither_grow_nor_drink_until_they_merge() -> void:
	var run: RunState = _run(StarMap.sagittarius_final())
	assert_eq(run.gravity.drinks(25), 0, "act one: no gauge yet")
	assert_eq(run.gravity.feed(3), 0, "and no hunger")
	var light: int = run.light
	run.link(_head_link(run, Star.Size.MEDIUM, Vector2i(20, 236)))
	assert_eq(run.light, light + run.balance.combos["medium_triple"].light, "the Sun still fills while the twins roam")
	while run.gravity.has_twins():
		run.gravity.drift_holes()
	assert_eq(run.gravity.drinks(25), 25, "act two: the merged hole drinks all the light")
	assert_eq(run.gravity.feed(1), 1, "and grows as it swallows")


func test_winning_the_final_ends_in_the_big_bang_a_jackpot_before_the_figure_rises() -> void:
	var run: RunState = _run(StarMap.sagittarius_final())
	while run.gravity.has_twins():
		run.gravity.drift_holes()
	for i: int in run.scorpio.map.count():
		if i != 12:
			run.scorpio.light(i)
	var events: Array[String] = []
	var banged: Array = []
	run.big_bang_started.connect(func(at: Vector2i, cleared: Array[Star], dust: int) -> void:
		events.append("bang")
		banged.append([at, cleared.size(), dust]))
	run.sky_cleared.connect(func(_stars: Array[Star], _dust: int) -> void: events.append("cleared"))
	run.constellation_completed.connect(func() -> void: events.append("completed"))
	run.run_won.connect(func() -> void: events.append("won"))
	var leftover: Star = run.add_star(Star.Size.BIG, Vector2i(160, 100))
	var hoof: Star = run.scorpio.landmark_star(12)
	var a: Star = run.add_star(hoof.size, hoof.position + Vector2i(-20, 0))
	var b: Star = run.add_star(hoof.size, hoof.position + Vector2i(20, 0))
	assert_ne(run.link([a.id, hoof.id, b.id] as Array[int]), Combos.INVALID)
	assert_eq(events, ["bang", "completed", "won"], "the hole bangs, then the figure completes")
	assert_eq(banged[0][0], run.gravity.center)
	assert_eq(banged[0][1], 1, "it took the star left in the sky")
	assert_gt(banged[0][2], 0, "and pays out like a jackpot (the rewarding bang)")
	assert_null(run.find_star(leftover.id))


func test_the_hole_is_gone_once_the_finals_big_bang_has_won() -> void:
	var main: Main = _main("sagittarius_final")
	_settle(main)
	var view: GravityView = main.get_node("Sky/GravityLayer")
	assert_false(view.pixels().is_empty(), "the twins show while it plays")
	main.run.outcome = RunState.Outcome.WON
	assert_false(view.banged_out(), "it stays until the Big Bang begins")
	view.vanish()
	assert_true(view.banged_out())
	assert_true(view.pixels().is_empty(), "it went into the Big Bang")


func test_once_the_finals_twins_merge_the_hud_says_the_hole_drinks_the_light() -> void:
	var main: Main = _main("sagittarius_final")
	_settle(main)
	var hud: Hud = main.get_node("HUD")
	main.run.holes_drifted.emit([Vector2i(106, 156), Vector2i(106, 196)] as Array[Vector2i], [Vector2i(106, 176)] as Array[Vector2i], true)
	main.run.gravity.drift_holes()
	main.run.gravity.drift_holes()
	main.run.gravity.drift_holes()
	_settle(main)
	assert_eq(hud.message(), Hud.GAUGE_MESSAGE)
