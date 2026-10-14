extends GutTest
## Chapter 6, Pisces: its figure and chart, its first two stages (the Circlet, the West Cord), the
## cord intro and the fish's cord's, and how they show.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["pisces_circlet", "pisces_west_cord"]
## No figure star stands this close to the fish's cord (it would read as on it).
const FISH_CLEARANCE: float = 10.0


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
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_pisces_is_chapter_6_after_sagittarius_on_the_ring() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.def.number, 6)
	assert_eq(chapter.def.unlocked_by, "sagittarius")
	assert_eq(chapter.stage_name(0), "CIRCLET")
	assert_eq(chapter.stage_name(1), "WEST CORD")
	for stage: int in BUILT.size():
		assert_eq(chapter.map_id(stage), BUILT[stage])
		assert_true(chapter.has_stage(stage))
	for stage: int in range(BUILT.size(), Chapter.stage_count()):
		assert_false(chapter.has_stage(stage), "stage %d isn't built yet" % stage)
	assert_eq(ChapterSelect.sky_x("pisces") - ChapterSelect.sky_x("sagittarius"), 3 * ChapterSelect.SKY_SPAN, "three signs on, round the ring")
	assert_eq(ChapterSelect.sky_x("pisces"), ChapterSelect.sign_x("pisces") + ChapterSelect.RING, "on the second lap")


func test_the_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.pisces()
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
	assert_eq(StarMap.by_id("pisces").title, "PISCES")


func test_the_first_stages_are_pickable_cord_stages() -> void:
	for id: String in BUILT:
		var map: StarMap = StarMap.by_id(id)
		assert_eq(map.id, id)
		assert_true(map.cords, id)
		assert_true(map.intros, "%s shows what it brings" % id)
		assert_eq(map.segment_count(), map.count() - 1, "%s: the strings form a tree" % id)
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS, "%s: %d and %d apart" % [id, i, j])
	assert_true(StarMap.pisces_circlet().fish_cord.is_empty(), "the Circlet brings the cords alone")


func test_the_fish_cord_splits_the_west_cord_clear_of_its_stars() -> void:
	var map: StarMap = StarMap.pisces_west_cord()
	assert_gte(map.fish_cord.size(), 2)
	var cuts: int = 0
	for k: int in range(1, map.fish_cord.size()):
		var a: Vector2i = map.fish_cord[k - 1]
		var b: Vector2i = map.fish_cord[k]
		for landmark: Vector2i in map.landmarks:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(landmark), Vector2(a), Vector2(b))
			assert_gte(closest.distance_to(Vector2(landmark)), FISH_CLEARANCE, "no star on the cord")
		for segment: int in map.segment_count():
			var ends: Array[Vector2i] = map.segment_ends(segment)
			cuts += 1 if StarCords.properly_cross(a, b, ends[0], ends[1]) else 0
	assert_gt(cuts, 0, "it cuts the figure's strings")
	var run: RunState = _run(map)
	assert_gt(run.cords.fixed_count(), 0, "in the sky from the start")
	assert_eq(run.cords.link_count(), 0)


func test_the_circlet_opens_by_acting_a_net_out() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var placed: Array[Star] = []
	var linked: Array = []
	var netted: Array = []
	run.cord_intro_placed.connect(func(stars: Array[Star]) -> void: placed.assign(stars))
	run.cord_intro_linked.connect(func(link: Array[int], points: Array[Vector2i]) -> void: linked.append([link, points]))
	run.cord_intro_netted.connect(func(link: Array[int], points: Array[Vector2i], loop: Array[Vector2i], snapped: Array[Array], caught: Array[Star]) -> void: netted.append([link, points, loop, snapped, caught]))
	var packs: Dictionary = run.owned_packs.duplicate()
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	run.play_cord_intro()
	assert_eq(placed.size(), 8, "two combos and two stars to catch")
	assert_eq(linked.size(), 1, "the post")
	assert_eq(netted.size(), 1, "the hook closes a net")
	for ids: Array in [linked[0][0], netted[0][0]]:
		var sizes: Array[int] = []
		for star: Star in placed:
			if ids.has(star.id):
				sizes.append(star.size)
		sizes.sort()
		assert_eq(sizes, [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG], "one of each size: a combo")
	var loop: Array[Vector2i] = netted[0][2]
	var polygon := PackedVector2Array()
	for point: Vector2i in loop:
		polygon.append(Vector2(point))
	var caught: Array[Star] = netted[0][4]
	assert_eq(caught.size(), 2)
	for star: Star in caught:
		assert_true(Geometry2D.is_point_in_polygon(Vector2(star.position), polygon), "caught inside the net")
	assert_eq((netted[0][3] as Array).size(), 4, "both demo cords snap")
	assert_true(run.stars.is_empty(), "the sky is empty for the run")
	assert_eq(run.cords.count(), 0, "the run's cords don't change")
	assert_eq(run.owned_packs, packs, "no pack used")
	assert_eq(run.dust, 100, "no reward")
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")


func test_the_cord_intro_stars_stand_in_the_sky_clear_of_the_figure() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var spots: Array[Vector2i] = run.cord_intro_spots()
	assert_eq(spots.size(), 8)
	for i: int in spots.size():
		assert_true(StarScatter.inner_rect(SKY).has_point(spots[i]))
		for landmark: Vector2i in run.scorpio.landmark_positions():
			assert_gte(spots[i].distance_to(landmark), float(StarScatter.MIN_SPACING), "clear of the figure")
		for j: int in range(i + 1, spots.size()):
			assert_gte(spots[i].distance_to(spots[j]), 12.0, "%d and %d apart (placed, not scattered: never overlapping)" % [i, j])


func test_the_cord_intro_plays_only_as_a_stage_with_intros_opens() -> void:
	var shown: Array = []
	var trial: RunState = _run(StarMap.cord_trial())
	trial.cord_intro_placed.connect(func(stars: Array[Star]) -> void: shown.append(stars))
	trial.fish_cord_laid.connect(func(points: Array[Vector2i]) -> void: shown.append(points))
	trial.play_cord_intro()
	assert_true(shown.is_empty(), "the trial opens without one")
	var circlet: RunState = _run(StarMap.pisces_circlet())
	circlet.add_star(Star.Size.SMALL, Vector2i(20, 100))
	circlet.cord_intro_placed.connect(func(stars: Array[Star]) -> void: shown.append(stars))
	circlet.play_cord_intro()
	assert_true(shown.is_empty(), "not once the run has begun")
	var heart: RunState = _run(StarMap.heart())
	assert_false(heart.cord_intro_due(), "nor without cords")


func test_the_west_cord_opens_by_laying_the_fish_cord_and_shows_no_demo_link() -> void:
	var run: RunState = _run(StarMap.pisces_west_cord())
	var laid: Array = []
	var placed: Array = []
	run.fish_cord_laid.connect(func(points: Array[Vector2i]) -> void: laid.append(points))
	run.cord_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	var segments: Array[Array] = run.cords.segments()
	run.play_cord_intro()
	assert_eq(laid.size(), 1)
	var points: Array[Vector2i] = laid[0]
	assert_eq(points.size(), run.scorpio.map.fish_cord.size())
	for i: int in points.size():
		assert_eq(points[i], run.scorpio.map.fish_cord[i] + run.scorpio.shift, "shifted with the map")
	assert_true(placed.is_empty(), "the Circlet already showed a link's cord")
	assert_eq(run.cords.segments(), segments, "nothing changes in the run")


func test_the_fish_cord_is_hidden_until_its_intro_lays_it() -> void:
	var main: Main = _main("pisces_west_cord")
	var view: CordView = main.get_node("Sky/CordLayer")
	view.set_process(false)
	assert_gt(view.fish_count(), 0)
	assert_true(view.pixels().is_empty(), "not drawn before its intro")
	_settle(main)
	view.advance(CordView.FISH_LAY_TIME * 0.5)
	var half: int = view.pixels().size()
	assert_gt(half, 0, "laid from its first end")
	for color: Color in view.pixels().values():
		assert_eq(color, Palette.C2, "solid as it's laid")
	view.advance(CordView.FISH_LAY_TIME)
	assert_gt(view.pixels().size(), half, "then whole, with its knot")
	assert_false(view.is_playing())


func test_each_stage_says_its_rule_in_a_line_that_fits() -> void:
	assert_eq(Hud.cord_rule(_run(StarMap.pisces_circlet()).cords), Hud.NET_MESSAGE)
	assert_eq(Hud.cord_rule(_run(StarMap.pisces_west_cord()).cords), Hud.FISH_NET_MESSAGE)
	for text: String in [Hud.NET_MESSAGE, Hud.FISH_NET_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_each_stage_says_its_rule_as_its_intro_shows_it() -> void:
	var circlet: Main = _main("pisces_circlet")
	var sky: SkyView = circlet.get_node("Sky")
	var hud: Hud = circlet.get_node("HUD")
	var sequencer: EventSequencer = circlet.get_node("EventSequencer")
	assert_true(sequencer.is_busy(), "the intro plays")
	var most: int = 0
	var said: bool = false
	var start: int = Time.get_ticks_msec()
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 10000:
		await get_tree().process_frame
		most = maxi(most, sky.star_count())
		said = said or hud.message() == Hud.NET_MESSAGE
	assert_false(sequencer.is_busy(), "it ends")
	assert_eq(most, 8, "two combos and the two to catch at most")
	assert_true(said, "the rule is said as the intro shows it")
	assert_eq(sky.star_count(), 0, "the demo stars are gone")
	assert_eq(circlet.run.cords.link_count(), 0)
	var west: Main = _main("pisces_west_cord")
	_settle(west)
	assert_eq((west.get_node("HUD") as Hud).message(), Hud.FISH_NET_MESSAGE)
