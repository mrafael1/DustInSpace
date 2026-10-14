extends GutTest
## Pisces's splash (the Knot on) and both seams at once (the East Cord): a planet splashes where it
## sinks, pushing the stars round it outward and out of the sky; with both seams it bursts in the
## opposite corner. Their maps, intros, rule lines and how they show.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["pisces_knot", "pisces_east_cord"]


func _run(map: StarMap, seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 0
	run.loaded_pack = "blue"
	return run


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_splash_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_the_knot_and_the_east_cord_are_stages_3_and_4() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.map_id(2), "pisces_knot")
	assert_eq(chapter.map_id(3), "pisces_east_cord")
	for id: String in BUILT:
		var map: StarMap = StarMap.by_id(id)
		assert_eq(map.id, id)
		assert_true(map.splash, "%s splashes" % id)
		assert_false(map.cords, "%s: no cords" % id)
		assert_eq(map.segment_count(), map.count() - 1, "%s: the strings form a tree" % id)
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS, "%s: %d and %d apart" % [id, i, j])
		for segment: Vector2i in map.segments:
			var length: float = Vector2(map.landmarks[segment.x]).distance_to(Vector2(map.landmarks[segment.y]))
			assert_between(length, 30.0, 38.0, "%s: string %s" % [id, segment])
	assert_eq(StarMap.pisces_knot().seam, StarMap.Seam.VERTICAL)
	assert_true(StarMap.pisces_knot().splash_intro, "the Knot brings the splash")
	assert_eq(StarMap.pisces_east_cord().seam, StarMap.Seam.CROSS)
	assert_false(StarMap.pisces_east_cord().splash_intro)
	assert_false(StarMap.pisces_circlet().splash, "the first two stages don't splash")
	assert_false(StarMap.pisces_west_cord().splash)


func test_the_splash_is_tuned_in_balance_and_absent_without_its_block() -> void:
	var balance: Balance = Balance.load_file()
	assert_gt(balance.splash_radius, 0)
	assert_gt(balance.splash_push, 0)
	assert_not_null(_run(StarMap.pisces_knot()).splash)
	assert_null(_run(StarMap.pisces_circlet()).splash, "no splash where the map has none")
	var data: Dictionary = Fixtures.balance_dict()
	data.erase("splash")
	var bare: Balance = Balance.from_dict(data)
	assert_eq(bare.splash_radius, 0)
	var broken: Dictionary = Fixtures.balance_dict()
	broken["splash"] = {"radius": 0, "push": 4}
	var bad: Balance = Balance.from_dict(broken)
	assert_false(bad.is_valid(), "a splash needs a reach")


func test_a_splash_pushes_the_stars_it_reaches_straight_out() -> void:
	var splash := StarSplash.new(30, 14)
	var near := Star.new(1, Star.Size.SMALL, Vector2i(110, 160))
	var far := Star.new(2, Star.Size.SMALL, Vector2i(150, 160))
	var on := Star.new(3, Star.Size.SMALL, Vector2i(90, 160))
	var moved: Dictionary[int, Vector2i] = splash.preview(Vector2i(90, 160), [near, far, on] as Array[Star], SKY, [] as Array[Vector2i])
	assert_eq(moved.get(1), Vector2i(124, 160), "pushed straight away")
	assert_false(moved.has(2), "out of reach: left alone")
	assert_eq(moved.get(3), Vector2i(90, 146), "one right on it goes straight up")


func test_a_splash_pushes_a_star_by_the_edge_out_of_the_sky() -> void:
	var splash := StarSplash.new(30, 14)
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	var edge := Star.new(1, Star.Size.SMALL, Vector2i(inner.position.x + 4, 160))
	var stars: Array[Star] = [edge]
	var moved: Dictionary[int, Vector2i] = splash.preview(Vector2i(inner.position.x + 20, 160), stars, SKY, [] as Array[Vector2i])
	assert_true(StarSplash.leaves(moved[1], SKY), "pushed past the edge")
	var moves: Array[StarCurrent.Move] = splash.moves(stars, moved, SKY)
	assert_eq(moves.size(), 1)
	assert_true(moves[0].drained, "and lost")


func test_a_blocked_star_goes_as_far_as_it_has_room() -> void:
	var splash := StarSplash.new(30, 14)
	var pushed := Star.new(1, Star.Size.SMALL, Vector2i(100, 160))
	var beyond := Star.new(2, Star.Size.SMALL, Vector2i(124, 160))
	var moved: Dictionary[int, Vector2i] = splash.preview(Vector2i(90, 160), [pushed, beyond] as Array[Star], SKY, [] as Array[Vector2i])
	assert_false(moved.has(2), "out of reach")
	assert_eq(moved.get(1), Vector2i(124 - StarScatter.MIN_SPACING, 160), "short of its full push, as far as it has room")
	var landmark: Array[Vector2i] = [Vector2i(104, 160)]
	var held: Dictionary[int, Vector2i] = splash.preview(Vector2i(90, 160), [pushed] as Array[Star], SKY, landmark)
	assert_false(held.has(1), "with no room at all it stays")


func test_a_launch_splashes_where_its_thrown_before_it_bursts() -> void:
	var run: RunState = _run(StarMap.pisces_knot())
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	var thrown := Vector2i(inner.position.x + 20, 100)
	var edge: Star = run.add_star(Star.Size.SMALL, Vector2i(inner.position.x + 2, 100))
	var near: Star = run.add_star(Star.Size.MEDIUM, Vector2i(inner.position.x + 26, 120))
	var preview: Dictionary[int, Vector2i] = run.splash_preview(thrown)
	assert_eq(run.launch_splashes(thrown), [edge.id] as Array[int], "the edge star's going")
	assert_eq(run.stars.size(), 2, "a preview changes nothing")
	var order: Array[String] = []
	var splashed: Array = []
	run.planet_reflected.connect(func(_f: Vector2i, _t: Vector2i) -> void: order.append("reflected"))
	run.stars_splashed.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		order.append("splashed")
		splashed.append([at, moves]))
	run.pack_burst.connect(func(_k: String, _a: Vector2i, _s: Array[Star]) -> void: order.append("burst"))
	var dust: int = run.dust
	assert_true(run.launch(thrown))
	assert_eq(order, ["reflected", "splashed", "burst"] as Array[String], "it sinks, splashes, then bursts")
	assert_eq(splashed[0][0], thrown, "where it went in")
	assert_null(run.find_star(edge.id), "pushed out of the sky")
	assert_eq(near.position, preview[near.id], "pushed on as the aim showed")
	assert_eq(run.dust, dust, "a lost star pays nothing")


func test_a_red_planet_splashes_where_its_twins_are_not_where_its_thrown() -> void:
	var run: RunState = _run(StarMap.pisces_knot())
	run.owned_packs["red"] = 1
	run.loaded_pack = "red"
	var thrown := Vector2i(60, 120)
	var twins: Array[Vector2i] = run.splash_points("red", thrown)
	assert_eq(twins.size(), 2, "one splash a twin")
	assert_false(twins.has(thrown))
	assert_eq(run.splash_points("blue", thrown), [thrown] as Array[Vector2i], "a blue splashes where it sinks")
	# A star beside each twin, and one beside the throw that no splash reaches.
	var by_twin: Star = run.add_star(Star.Size.SMALL, twins[0] + Vector2i(0, 18))
	var by_throw: Star = run.add_star(Star.Size.SMALL, thrown + Vector2i(0, -18))
	var preview: Dictionary[int, Vector2i] = run.splash_preview(thrown)
	var order: Array[String] = []
	var at: Array[Vector2i] = []
	run.pack_split.connect(func(_k: String, _a: Vector2i, _p: Array[Vector2i]) -> void: order.append("split"))
	run.stars_splashed.connect(func(point: Vector2i, _m: Array[StarCurrent.Move]) -> void:
		order.append("splashed")
		at.append(point))
	run.pack_burst.connect(func(_k: String, _a: Vector2i, _s: Array[Star]) -> void: order.append("burst"))
	var by_throw_at: Vector2i = by_throw.position
	assert_true(run.launch(thrown))
	assert_eq(order, ["split", "splashed", "splashed", "burst", "burst"] as Array[String], "it splits, each twin splashes, then both burst")
	assert_eq(at, twins)
	assert_eq(by_throw.position, by_throw_at, "nothing splashes where it was thrown")
	assert_ne(by_twin.position, twins[0] + Vector2i(0, 18), "the twin's splash pushed its star")
	assert_eq(by_twin.position, preview[by_twin.id], "as the aim showed")


func test_a_splash_that_reaches_nothing_still_shows() -> void:
	var run: RunState = _run(StarMap.pisces_knot())
	var shown: Array = []
	run.stars_splashed.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void: shown.append(moves.size()))
	assert_true(run.launch(Vector2i(40, 100)))
	assert_eq(shown, [0], "the water ring plays on an empty sky too")


func test_both_seams_burst_a_planet_in_the_opposite_corner() -> void:
	var run: RunState = _run(StarMap.pisces_east_cord())
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	assert_eq(run.reflect(middle + Vector2i(-40, -30)), middle + Vector2i(40, 30), "top left to bottom right")
	assert_eq(run.reflect(middle + Vector2i(30, -20)), middle + Vector2i(-30, 20), "top right to bottom left")
	var bursts: Array = []
	run.pack_burst.connect(func(_k: String, at: Vector2i, _s: Array[Star]) -> void: bursts.append(at))
	assert_true(run.launch(middle + Vector2i(-40, -30)))
	assert_eq(bursts, [run.burst_centre(middle + Vector2i(-40, -30))])
	assert_gt(bursts[0].x, middle.x)
	assert_gt(bursts[0].y, middle.y)


func test_the_knot_opens_by_showing_the_splash() -> void:
	var run: RunState = _run(StarMap.pisces_knot())
	var placed: Array = []
	var splashed: Array = []
	var born: Array = []
	var cleared: Array = []
	run.splash_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.stars_splashed.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void: splashed.append(moves))
	run.hunt_intro_burst.connect(func(_at: Vector2i, stars: Array[Star]) -> void: born.append(stars))
	run.reflect_intro_cleared.connect(func(stars: Array[Star]) -> void: cleared.append(stars))
	var packs: Dictionary = run.owned_packs.duplicate()
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	run.play_reflect_intro()
	assert_eq((placed[0] as Array).size(), 3, "demo stars by the edge")
	var spot: Vector2i = run.splash_intro_spot()
	for i: int in 3:
		assert_eq((placed[0][i] as Star).position, spot + RunState.SPLASH_INTRO_STARS[i], "shown where they stand before the splash")
	var lost: int = 0
	var pushed: int = 0
	for move: StarCurrent.Move in splashed[0]:
		if move.drained:
			lost += 1
		else:
			pushed += 1
	assert_eq(lost, 1, "the splash pushes one out of the sky")
	assert_eq(pushed, 2, "and the others on")
	assert_eq((born[0] as Array).size(), 3, "then the planet bursts across the seam")
	assert_eq((cleared[0] as Array).size(), 5, "every demo star left goes")
	assert_true(run.stars.is_empty())
	assert_eq(run.owned_packs, packs, "no pack used")
	assert_eq(run.dust, 100, "no reward")
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")
	for star: Star in placed[0]:
		for landmark: Vector2i in run.scorpio.landmark_positions():
			assert_gte(star.position.distance_to(landmark), float(StarScatter.LANDMARK_SPACING), "clear of the figure")


func test_the_east_cord_opens_with_a_throw_into_the_opposite_corner() -> void:
	var run: RunState = _run(StarMap.pisces_east_cord())
	var reflected: Array = []
	var splashed: Array = []
	run.planet_reflected.connect(func(from: Vector2i, to: Vector2i) -> void: reflected.append([from, to]))
	run.stars_splashed.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void: splashed.append(at))
	run.play_reflect_intro()
	assert_eq(reflected.size(), 1)
	assert_eq(run.reflect(reflected[0][0]), reflected[0][1], "burst at its reflection through the middle")
	assert_true(splashed.is_empty(), "the plain reflection's intro: the splash is known by now")
	assert_true(run.stars.is_empty())


func test_each_rule_line_fits() -> void:
	assert_eq(Hud.seam_rule(_run(StarMap.pisces_knot())), Hud.SPLASH_MESSAGE)
	assert_eq(Hud.seam_rule(_run(StarMap.pisces_east_cord())), Hud.SEAM_CROSS_MESSAGE)
	for text: String in [Hud.SPLASH_MESSAGE, Hud.SEAM_CROSS_MESSAGE, Hud.SPLASH_LOSS_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_each_stage_says_its_rule_as_its_intro_shows_it() -> void:
	for id: String in BUILT:
		var main: Main = _main(id)
		var hud: Hud = main.get_node("HUD")
		var sky: SkyView = main.get_node("Sky")
		var sequencer: EventSequencer = main.get_node("EventSequencer")
		var rule: String = Hud.seam_rule(main.run)
		assert_true(sequencer.is_busy(), "%s: the intro plays" % id)
		var said: bool = false
		var start: int = Time.get_ticks_msec()
		while sequencer.is_busy() and Time.get_ticks_msec() - start < 12000:
			await get_tree().process_frame
			said = said or hud.message() == rule
		assert_true(said, "%s: the rule is said as the intro shows it" % id)
		assert_eq(sky.star_count(), 0, "%s: the demo stars go" % id)


func test_the_seam_view_draws_both_seams_the_ripple_and_the_aims_preview() -> void:
	var main: Main = _main("pisces_east_cord")
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	view.advance(SeamView.RIPPLE_TIME)
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + main.run.scorpio.shift
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	assert_true(pixels.has(Vector2i(middle.x, middle.y - 40)), "the seam up and down")
	assert_true(pixels.has(Vector2i(middle.x - 40, middle.y)), "and the one across")
	view.ripple(Vector2i(40, 110))
	view.advance(SeamView.RIPPLE_TIME * 0.9)
	var radius: int = main.run.splash.radius
	assert_true(view.pixels().has(Vector2i(40 + radius, 110)), "the ripple reaches the splash's edge")
	view.advance(SeamView.RIPPLE_TIME)
	assert_false(view.is_rippling())
	var inner: Rect2i = StarScatter.inner_rect(main.run.sky_rect)
	var edge: Star = main.run.add_star(Star.Size.SMALL, Vector2i(inner.position.x + 2, 110))
	view.aim = Vector2i(inner.position.x + 18, 110)
	view.aiming = true
	var aimed: Dictionary[Vector2i, Color] = view.pixels()
	assert_true(aimed.values().has(Palette.S4), "a star it would push out trails ember")
	assert_eq(main.run.launch_splashes(view.aim), [edge.id] as Array[int])
	view.aiming = false
	assert_false(view.pixels().values().has(Palette.S4), "only while aiming")


func test_no_link_steps_across_the_seam() -> void:
	var circlet: RunState = _run(StarMap.pisces_circlet())
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + circlet.scorpio.shift
	assert_true(circlet.crosses_seam(middle + Vector2i(-10, 0), middle + Vector2i(10, 4)), "left to right")
	assert_false(circlet.can_step(middle + Vector2i(-10, 0), middle + Vector2i(10, 4)))
	assert_true(circlet.can_step(middle + Vector2i(-30, 0), middle + Vector2i(-10, 20)), "same side")
	assert_false(circlet.crosses_seam(middle + Vector2i(0, -10), middle + Vector2i(10, 10)), "a star on the seam is on both sides")
	assert_eq(circlet.seam_crossing(middle + Vector2i(-10, 0), middle + Vector2i(10, 20)), middle + Vector2i(0, 10))
	var west: RunState = _run(StarMap.pisces_west_cord())
	assert_true(west.crosses_seam(middle + Vector2i(0, -8), middle + Vector2i(4, 8)), "high to low")
	assert_false(west.crosses_seam(middle + Vector2i(-10, -8), middle + Vector2i(10, -8)), "along it")
	var east: RunState = _run(StarMap.pisces_east_cord())
	assert_true(east.crosses_seam(middle + Vector2i(-10, -8), middle + Vector2i(10, -8)), "both seams: across")
	assert_true(east.crosses_seam(middle + Vector2i(-10, -8), middle + Vector2i(-10, 8)), "and up and down")
	assert_false(_run(StarMap.heart()).crosses_seam(Vector2i(80, 160), Vector2i(100, 160)), "no seam elsewhere")


func test_a_link_across_the_seam_is_refused_and_uses_nothing() -> void:
	var run: RunState = _run(StarMap.pisces_knot())
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + run.scorpio.shift
	var a: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(-40, -50))
	var b: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(-14, -50))
	var c: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(12, -50))
	var across: Array[int] = [a.id, b.id, c.id]
	assert_false(run.link_in_reach(across))
	assert_false(run.valid_links().has(across), "never offered")
	var dust: int = run.dust
	assert_eq(run.link(across), Combos.INVALID)
	assert_eq(run.stars.size(), 3, "nothing used")
	assert_eq(run.dust, dust)
	var d: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(-40, -24))
	assert_ne(run.link([a.id, b.id, d.id] as Array[int]), Combos.INVALID, "the same link on one side pays")


func test_the_refusal_says_why_and_fits() -> void:
	var text: String = Hud.REFUSAL_MESSAGES[RunState.PickRefusal.ACROSS_SEAM]
	for line: String in text.split("\n"):
		assert_lte(line.length(), 24, line)


func test_a_step_refused_at_the_seam_lights_it() -> void:
	var main: Main = _main("pisces_circlet")
	_settle(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var before: Dictionary[Vector2i, Color] = view.pixels()
	view.flash_block(LinkLayer.REJECT_TIME)
	assert_true(view.is_blocking())
	var lit: Dictionary[Vector2i, Color] = view.pixels()
	assert_gt(lit.values().count(SeamView.GLINT_COLOUR), before.values().count(SeamView.GLINT_COLOUR), "the line glows")
	view.advance(LinkLayer.REJECT_TIME + 0.01)
	assert_false(view.is_blocking())
