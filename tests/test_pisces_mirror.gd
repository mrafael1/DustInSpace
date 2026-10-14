extends GutTest
## Pisces's mirror: the Circlet's and the West Cord's echo across the seam (paid, lost, lighting),
## the mirror intro, the rule lines and the mirror's view.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["pisces_circlet", "pisces_west_cord"]
## A sequence in the open upper left, in pick order, and where its mirror spots fall (near them).
const LINK: Array[Vector2i] = [Vector2i(30, 96), Vector2i(50, 96), Vector2i(40, 116)]
const ECHO: Array[Vector2i] = [Vector2i(150, 98), Vector2i(132, 95), Vector2i(140, 116)]


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
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_mirror_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func _trio(run: RunState, spots: Array[Vector2i]) -> Array[int]:
	var ids: Array[int] = []
	for i: int in spots.size():
		ids.append(run.add_star(RunState.HEAT_INTRO_SIZES[i], spots[i]).id)
	return ids


func _ids(some: Array[Star]) -> Array[int]:
	var ids: Array[int] = []
	for star: Star in some:
		ids.append(star.id)
	return ids


func test_the_first_stages_are_pickable_mirror_stages() -> void:
	for id: String in BUILT:
		var map: StarMap = StarMap.by_id(id)
		assert_eq(map.id, id)
		assert_true(map.mirror, id)
		assert_false(map.cords, "%s: no cords" % id)
		assert_eq(map.segment_count(), map.count() - 1, "%s: the strings form a tree" % id)
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS, "%s: %d and %d apart" % [id, i, j])
	assert_false(StarMap.pisces_circlet().mirror_lights, "the Circlet's echoes don't light")
	assert_true(StarMap.pisces_west_cord().mirror_lights, "the West Cord's do")


func test_the_seam_is_the_skys_middle_where_the_map_is_drawn() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	assert_not_null(run.mirror)
	var middle := Vector2i(90, 120) + run.scorpio.shift
	assert_eq(run.mirror.mirror(middle), middle, "the seam mirrors onto itself")
	assert_eq(run.mirror.mirror(Vector2i(40, 120) + run.scorpio.shift), Vector2i(140, 120) + run.scorpio.shift)
	assert_eq(run.mirror.reach, run.balance.mirror_echo_reach)
	assert_gt(run.mirror.reach, 0)
	assert_null(_run(StarMap.heart()).mirror, "no mirror elsewhere")


func test_a_matched_echo_pays_like_a_link() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var link: Array[int] = _trio(run, LINK)
	var echo: Array[int] = _trio(run, ECHO)
	var stray: Star = run.add_star(Star.Size.SMALL, Vector2i(140, 230))
	assert_eq(_ids(run.link_echo(link)), echo, "the preview says which")
	var echoed: Array = []
	run.mirror_echoed.connect(func(stars: Array[Star], combo: String, dust: int, light: int) -> void: echoed.append([stars, combo, dust, light]))
	var dust: int = run.dust
	var light: int = run.light
	assert_eq(run.link(link), "sequence")
	assert_eq(echoed.size(), 1)
	assert_eq(echoed[0][1], "sequence", "the echo is a combo too")
	assert_eq(echoed[0][2], run.link_dust("sequence"))
	assert_eq(run.dust, dust + 2 * run.link_dust("sequence"), "paid twice")
	assert_eq(run.light, light + 2 * run.balance.combos["sequence"].light)
	assert_eq(run.stars, [stray] as Array[Star], "both trios gone, the rest stays")


func test_an_unmatched_echo_is_lost_for_nothing() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var link: Array[int] = _trio(run, LINK)
	var lone: Star = run.add_star(Star.Size.BIG, Vector2i(152, 99))
	var far: Star = run.add_star(Star.Size.BIG, Vector2i(150, 170))
	var echoed: Array = []
	run.mirror_echoed.connect(func(stars: Array[Star], combo: String, dust: int, light: int) -> void: echoed.append([stars, combo, dust]))
	var dust: int = run.dust
	run.link(link)
	assert_eq(echoed.size(), 1)
	assert_eq((echoed[0][0] as Array).size(), 1, "the lone star echoes the first pick")
	assert_eq(echoed[0][1], Combos.INVALID)
	assert_eq(run.dust, dust + run.link_dust("sequence"), "only the link pays")
	assert_false(run.stars.has(lone), "lost")
	assert_true(run.stars.has(far), "out of reach of every mirror spot: kept")


func test_a_link_with_nothing_across_the_seam_echoes_nothing() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var link: Array[int] = _trio(run, LINK)
	var echoed: Array = []
	run.mirror_echoed.connect(func(stars: Array[Star], combo: String, dust: int, light: int) -> void: echoed.append(stars))
	run.link(link)
	assert_true(echoed.is_empty())


func test_on_the_west_cord_a_matched_echo_lights_the_constellation_star_it_takes() -> void:
	var run: RunState = _run(StarMap.pisces_west_cord())
	var target: Vector2i = run.scorpio.landmark_position(2)
	assert_eq(run.scorpio.map.sizes[2], Star.Size.SMALL)
	var across: Vector2i = run.mirror.mirror(target)
	var spots: Array[Vector2i] = [across, across + Vector2i(-20, 10), across + Vector2i(-6, 28)]
	var link: Array[int] = []
	for spot: Vector2i in spots:
		link.append(run.add_star(Star.Size.SMALL, spot).id)
	var helpers: Array[Star] = [run.add_star(Star.Size.SMALL, run.mirror.mirror(spots[1])), run.add_star(Star.Size.SMALL, run.mirror.mirror(spots[2]))]
	assert_false(run.scorpio.is_lit(2))
	var echo: Array[Star] = run.link_echo(link)
	assert_eq(echo.size(), 3)
	assert_true(_ids(echo).has(Scorpio.landmark_id(2)), "the constellation star is in the echo")
	assert_eq(run.link(link), "small_triple")
	assert_true(run.scorpio.is_lit(2), "lit by the echo")
	assert_false(run.stars.has(helpers[0]) or run.stars.has(helpers[1]))


func test_an_unmatched_echo_leaves_a_constellation_star_as_it_was() -> void:
	var run: RunState = _run(StarMap.pisces_west_cord())
	var across: Vector2i = run.mirror.mirror(run.scorpio.landmark_position(2))
	var link: Array[int] = []
	for spot: Vector2i in [across, across + Vector2i(-20, 10), across + Vector2i(-6, 28)]:
		link.append(run.add_star(Star.Size.SMALL, spot).id)
	run.link(link)
	assert_false(run.scorpio.is_lit(2), "an echo of one isn't a combo")


func test_a_constellation_star_by_the_seam_never_echoes_its_own_link() -> void:
	var run: RunState = _run(StarMap.pisces_west_cord())
	# Landmark 3 (medium) stands 2 px off the seam: its mirror spot is within reach of itself.
	var at: Vector2i = run.scorpio.landmark_position(3)
	assert_lt(run.mirror.mirror(at).distance_to(at), float(run.mirror.reach))
	var link: Array[int] = [run.add_star(Star.Size.SMALL, at + Vector2i(-12, 8)).id, Scorpio.landmark_id(3), run.add_star(Star.Size.BIG, at + Vector2i(-14, -10)).id]
	var preview: Array[int] = _ids(run.link_echo(link))
	assert_false(preview.has(Scorpio.landmark_id(3)), "the preview never takes it")
	var echoed: Array[int] = []
	run.mirror_echoed.connect(func(stars: Array[Star], combo: String, dust: int, light: int) -> void: echoed.assign(_ids(stars)))
	assert_eq(run.link(link), "sequence")
	assert_eq(echoed, preview, "nor does the link: as previewed")
	assert_true(run.scorpio.is_lit(3))


func test_the_circlet_opens_with_an_echo_paid_then_one_lost() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var placed: Array = []
	var linked: Array = []
	run.mirror_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.mirror_intro_linked.connect(func(link: Array[int], echo: Array[Star], paid: bool) -> void: linked.append([link, echo, paid]))
	var packs: Dictionary = run.owned_packs.duplicate()
	var state: int = (run.get("_rng") as RandomNumberGenerator).state
	run.play_mirror_intro()
	assert_eq(placed.size(), 2)
	assert_eq(linked.size(), 2)
	assert_true(linked[0][2], "first, an echo that pays")
	assert_eq((linked[0][1] as Array).size(), 3)
	assert_false(linked[1][2], "then one that's lost")
	assert_eq((linked[1][1] as Array).size(), 1)
	assert_true(run.stars.is_empty(), "the sky is empty for the run")
	assert_eq(run.owned_packs, packs, "no pack used")
	assert_eq(run.dust, 100, "no reward")
	assert_eq((run.get("_rng") as RandomNumberGenerator).state, state, "no RNG drawn")
	var west: RunState = _run(StarMap.pisces_west_cord())
	west.mirror_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	west.play_mirror_intro()
	assert_eq(placed.size(), 2, "the West Cord has no intro")


func test_the_mirror_intro_stands_clear_of_the_figure_and_the_seam() -> void:
	var run: RunState = _run(StarMap.pisces_circlet())
	var spots: Array[Vector2i] = run.mirror_intro_spots()
	assert_eq(spots.size(), 3)
	for spot: Vector2i in spots:
		for at: Vector2i in [spot, run.mirror.mirror(spot)]:
			assert_true(StarScatter.inner_rect(SKY).has_point(at))
			for landmark: Vector2i in run.scorpio.landmark_positions():
				assert_gte(at.distance_to(landmark), float(RunState.MIRROR_INTRO_CLEARANCE), "clear of the figure")
		assert_gt(absi(spot.x * 2 - run.mirror.axis), 2 * StarScatter.MIN_SPACING, "away from the seam")


func test_each_rule_line_fits() -> void:
	for text: String in [Hud.MIRROR_MESSAGE, Hud.MIRROR_LIGHTS_MESSAGE, Hud.ECHO_LOSS_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_circlet_says_its_rule_as_its_intro_shows_it() -> void:
	var circlet: Main = _main("pisces_circlet")
	var sky: SkyView = circlet.get_node("Sky")
	var hud: Hud = circlet.get_node("HUD")
	var sequencer: EventSequencer = circlet.get_node("EventSequencer")
	assert_true(sequencer.is_busy(), "the intro plays")
	var most: int = 0
	var said: bool = false
	var start: int = Time.get_ticks_msec()
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 12000:
		await get_tree().process_frame
		most = maxi(most, sky.star_count())
		said = said or hud.message() == Hud.MIRROR_MESSAGE
	assert_false(sequencer.is_busy(), "it ends")
	assert_eq(most, 6, "a combo and its echo at most")
	assert_true(said, "the rule is said as the intro shows it")
	assert_eq(sky.star_count(), 0, "the demo stars are gone")


func test_the_mirror_view_draws_the_seam_and_marks_the_echo_while_tracing() -> void:
	var main: Main = _main("pisces_circlet")
	_settle(main)
	var view: MirrorView = main.get_node("Sky/MirrorLayer")
	assert_true(view.visible)
	@warning_ignore("integer_division")
	var seam: int = main.run.mirror.axis / 2
	assert_true(view.pixels().keys().any(func(p: Vector2i) -> bool: return p.x == seam), "the seam")
	view.ghosts = [Vector2i(140, 120)] as Array[Vector2i]
	view.echo_marks = [Vector2i(142, 150)] as Array[Vector2i]
	view.echo_outcome = -1
	assert_eq(view.pixels().get(Vector2i(140, 120)), Palette.N7, "where the echo lands")
	assert_true(view.pixels().values().has(Palette.S4), "a lost echo marked ember")
	view.echo_outcome = 1
	assert_false(view.pixels().values().has(Palette.S4))
	assert_true(view.pixels().values().has(Palette.C1), "a paying one gold")
	var heart: Main = _main("heart")
	assert_false((heart.get_node("Sky/MirrorLayer") as MirrorView).visible, "no seam elsewhere")
