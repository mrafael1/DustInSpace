extends GutTest
## Chapter 7, Aries: its figure and chart, its stages so far (the Horns, the Head, the Fleece), and
## the ram's intros.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["aries_horns", "aries_head", "aries_fleece"]


func _run(map: StarMap = StarMap.aries_horns(), seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.loaded_pack = "blue"
	return run


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_aries_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_aries_is_chapter_7_after_pisces_on_the_ring() -> void:
	var chapter := Chapter.new(ChapterDef.aries())
	assert_eq(chapter.def.number, 7)
	assert_eq(chapter.def.unlocked_by, "pisces")
	assert_eq(chapter.stage_name(0), "HORNS")
	for stage: int in BUILT.size():
		assert_eq(chapter.map_id(stage), BUILT[stage])
		assert_true(chapter.has_stage(stage))
	for stage: int in range(BUILT.size(), Chapter.stage_count()):
		assert_false(chapter.has_stage(stage), "stage %d isn't built yet" % stage)
	assert_eq(ChapterSelect.sky_x("aries") - ChapterSelect.sky_x("pisces"), ChapterSelect.SKY_SPAN, "the next sign")
	assert_eq(ChapterSelect.sky_x("aries"), ChapterSelect.sign_x("aries") + ChapterSelect.RING, "on the second lap")


func test_the_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.aries()
	var figure: StarMap = def.figure
	assert_eq(figure.count(), 14)
	assert_eq(figure.segment_count(), 13, "the strings form a tree")
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
	assert_eq(owned, range(14), "every star belongs to exactly one part")
	assert_eq(StarMap.by_id("aries").title, "ARIES")


func test_the_horns_bring_the_ram_and_its_intro() -> void:
	var map: StarMap = StarMap.by_id("aries_horns")
	assert_eq(map.title, "HORNS")
	assert_true(map.ram)
	assert_true(map.intros)
	assert_eq(map.count(), 6)
	assert_eq(map.starting_lit, [0] as Array[int])
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
	for segment: Vector2i in map.segments:
		var length: float = Vector2(map.landmarks[segment.x]).distance_to(Vector2(map.landmarks[segment.y]))
		assert_between(length, 30.0, 40.0, "a string's length")
	var run: RunState = _run()
	assert_not_null(run.ram)
	assert_eq(run.ram.row, map.landmarks[0].y, "the lane starts on the lit root")
	assert_true(run.ram.in_lane(map.landmarks[1]) and run.ram.in_lane(map.landmarks[2]), "the first two to light share the root's lane")
	assert_false(run.ram.in_lane(map.landmarks[4]), "the curl climbs out of it")


func test_the_intro_butts_one_star_past_a_landmark_and_one_out_of_the_sky() -> void:
	var run: RunState = _run()
	var layout: Array[Vector2i] = run.ram_intro_layout()
	assert_eq(layout.size(), 3)
	assert_true(run.ram.in_lane(layout[0]) and run.ram.in_lane(layout[1]))
	assert_false(run.ram.in_lane(layout[2]), "the third waits out of the lane")
	var placed: Array = []
	var bursts: Array = []
	var charges: Array = []
	var cleared: Array = []
	run.ram_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.hunt_intro_burst.connect(func(_at: Vector2i, stars: Array) -> void: bursts.append(stars))
	run.ram_charged.connect(func(row: int, moves: Array[StarCurrent.Move], _way: Vector2i) -> void: charges.append([row, moves]))
	run.ram_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.append(stars))
	var state: int = run._rng.state
	run.play_ram_intro()
	assert_eq(placed.size(), 1)
	var demo: Array[Star] = placed[0]
	assert_eq(demo.size(), 3)
	assert_eq(charges.size(), 1, "the ram charged once")
	var moves: Array[StarCurrent.Move] = charges[0][1]
	var by_id: Dictionary[int, StarCurrent.Move] = {}
	for move: StarCurrent.Move in moves:
		by_id[move.star_id] = move
	var kept: StarCurrent.Move = by_id[demo[0].id]
	assert_false(kept.drained, "the first is kept")
	var passed: bool = false
	for landmark: Vector2i in run.scorpio.landmark_positions():
		passed = passed or (run.ram.in_lane(landmark) and landmark.x > kept.from.x and landmark.x < kept.to.x)
	assert_true(passed, "butted on past a landmark in the lane: none shelters it")
	assert_true(by_id[demo[1].id].drained, "the second is butted out of the sky")
	assert_false(by_id.has(demo[2].id), "the third, out of the lane, stays")
	for star: Star in bursts[0]:
		assert_false(run.ram.in_lane(star.position), "the demo planet's stars land clear of the lane")
	assert_eq(cleared.size(), 1)
	assert_true(run.stars.is_empty(), "every demo star goes")
	assert_eq(run.ram.launches, 0, "the intro doesn't count toward the charge")
	assert_eq(run._rng.state, state, "no RNG drawn from the run")
	assert_eq(run.dust, 100, "no reward")


func test_the_intro_plays_only_on_an_empty_sky_with_intros() -> void:
	var run: RunState = _run()
	run.add_star(Star.Size.SMALL, Vector2i(90, 120))
	var charges: Array[int] = [0]
	run.ram_charged.connect(func(_row: int, _moves: Array[StarCurrent.Move], _way: Vector2i) -> void: charges[0] += 1)
	run.play_ram_intro()
	assert_eq(charges[0], 0, "not with stars already out")
	var quiet: StarMap = StarMap.aries_horns()
	quiet.intros = false
	var other: RunState = _run(quiet)
	other.ram_charged.connect(func(_row: int, _moves: Array[StarCurrent.Move], _way: Vector2i) -> void: charges[0] += 1)
	other.play_ram_intro()
	assert_eq(charges[0], 0, "not on a stage without intros")
	assert_false(StarMap.ram_trial().intros, "the trial opens without it")


func test_the_horns_open_with_the_intro_saying_the_rule() -> void:
	var main: Main = _main("aries_horns")
	var hud: Hud = main.get_node("HUD")
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	assert_true(sequencer.is_busy(), "the intro plays")
	var said: bool = false
	var most: int = 0
	var start: int = Time.get_ticks_msec()
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 12000:
		await get_tree().process_frame
		said = said or hud.message() == Hud.RAM_MESSAGE
		most = maxi(most, sky.star_count())
	assert_true(said, "the rule is said as the intro shows it")
	assert_eq(most, 6, "three demo stars and the demo planet's three")
	assert_eq(sky.star_count(), 0, "and they go")
	assert_true(main.run.stars.is_empty())
	assert_eq(main.run.ram.launches, 0)
	var view: ChargeView = main.get_node("Sky/ChargeLayer")
	assert_true(view.has_ram())
	assert_false(view.is_charging())
	assert_eq(view.row(), main.run.ram.row)


## Each stage's map: a tree of 30-40 px strings in the sky, the first lit, the ram on.
func _assert_ram_stage(map: StarMap, title: String) -> void:
	assert_eq(map.title, title)
	assert_true(map.ram)
	assert_true(map.intros)
	assert_eq(map.count(), 6)
	assert_eq(map.starting_lit, [0] as Array[int])
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
	for segment: Vector2i in map.segments:
		var length: float = Vector2(map.landmarks[segment.x]).distance_to(Vector2(map.landmarks[segment.y]))
		assert_between(length, 30.0, 40.0, "a string's length")


func test_the_head_charges_harder() -> void:
	var map: StarMap = StarMap.by_id("aries_head")
	_assert_ram_stage(map, "HEAD")
	assert_true(map.ram_hard)
	assert_false(map.ram_sides)
	var balance: Balance = Balance.load_file()
	assert_gt(balance.ram_hard_butt, balance.ram_butt)
	var run: RunState = _run(map)
	assert_eq(run.ram.butt, balance.ram_hard_butt)
	assert_false(run.ram.sides)
	assert_eq(_run().ram.butt, balance.ram_butt, "the Horns keep the normal push")
	assert_true(run.ram.in_lane(map.landmarks[1]) and run.ram.in_lane(map.landmarks[2]), "the brow shares the root's lane")


func test_the_fleece_charges_from_each_side_in_turn() -> void:
	var map: StarMap = StarMap.by_id("aries_fleece")
	_assert_ram_stage(map, "FLEECE")
	assert_true(map.ram_sides)
	assert_false(map.ram_hard)
	var run: RunState = _run(map)
	assert_true(run.ram.sides)
	assert_eq(run.ram.butt, Balance.load_file().ram_butt)
	var ways: Array[Vector2i] = []
	run.ram_charged.connect(func(_row: int, _moves: Array[StarCurrent.Move], way: Vector2i) -> void: ways.append(way))
	for i: int in 3:
		Fixtures.launch(run, Vector2i(90, 110))
	assert_eq(ways, [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.RIGHT] as Array[Vector2i], "left, right, left again")
	assert_eq(run.ram.way, Vector2i.LEFT, "the next comes from the right")


func test_the_head_intro_shows_the_harder_push() -> void:
	var run: RunState = _run(StarMap.aries_head())
	var charges: Array = []
	run.ram_charged.connect(func(_row: int, moves: Array[StarCurrent.Move], _way: Vector2i) -> void: charges.append(moves))
	run.play_ram_intro()
	assert_eq(charges.size(), 1)
	var kept: int = 0
	for move: StarCurrent.Move in charges[0]:
		if not move.drained:
			kept += 1
			assert_gte(move.to.x - move.from.x, run.ram.butt, "butted the harder push or more")
	assert_eq(kept, 1)
	assert_true(run.stars.is_empty())


func test_the_fleece_intro_charges_once_from_each_side() -> void:
	var run: RunState = _run(StarMap.aries_fleece())
	var ways: Array[Vector2i] = []
	var placed: Array[int] = [0]
	run.ram_intro_placed.connect(func(_stars: Array[Star]) -> void: placed[0] += 1)
	run.ram_charged.connect(func(_row: int, moves: Array[StarCurrent.Move], way: Vector2i) -> void:
		ways.append(way)
		for move: StarCurrent.Move in moves:
			assert_eq(signi(move.to.x - move.from.x), way.x, "each star goes the ram's way"))
	run.play_ram_intro()
	assert_eq(ways, [Vector2i.RIGHT, Vector2i.LEFT] as Array[Vector2i])
	assert_eq(placed[0], 2, "a round of demo stars for each side")
	assert_eq(run.ram.way, Vector2i.RIGHT, "the first real charge comes from the left")
	assert_true(run.stars.is_empty())
	assert_eq(run.ram.launches, 0)


func test_each_stage_says_its_ram_rule() -> void:
	assert_eq(Hud.ram_rule(_run()), Hud.RAM_MESSAGE)
	assert_eq(Hud.ram_rule(_run(StarMap.aries_head())), Hud.RAM_HARD_MESSAGE)
	assert_eq(Hud.ram_rule(_run(StarMap.aries_fleece())), Hud.RAM_SIDES_MESSAGE)
	for message: String in [Hud.RAM_HARD_MESSAGE, Hud.RAM_SIDES_MESSAGE]:
		for line: String in message.split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_harder_ram_is_heated_ember() -> void:
	for id: String in ["aries_horns", "aries_head", "aries_fleece"]:
		var main: Main = _main(id)
		_settle(main)
		var view: ChargeView = main.get_node("Sky/ChargeLayer")
		var hard: bool = id == "aries_head"
		assert_eq(view.is_hard(), hard, id)
		var head: Dictionary[Vector2i, Color] = ChargeView.head_pixels(main.run.ram.row, main.run.sky_rect, 0, 0, hard)
		var embers: int = 0
		for point: Vector2i in head:
			if head[point] in [Palette.S4, Palette.S3]:
				embers += 1
		if hard:
			assert_gt(embers, head.size() / 3, "ember horns")
		else:
			assert_eq(embers, 2, "just its eyes")
		for colour: Color in ChargeView.HARD_TRAIL.values():
			assert_true(colour in [Palette.S4, Palette.S3, Palette.S2], "the trail heats on the ember ramp")
