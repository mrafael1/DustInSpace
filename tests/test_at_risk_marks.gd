extends GutTest
## At-risk marks (#149): the stars the next launch will take, known before any aim. Aquarius's drain
## and Leo's burn and fade come from the core's pure queries (launch_drains, launch_burns,
## launch_fades), whatever the aim; the views mark them while the player links.

const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)


func _run(map: StarMap, seed_value: int = 7) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)


func _heat_map(change: int, burns: bool = true, turns: bool = false) -> StarMap:
	var map: StarMap = StarMap.aquarius_hand()
	map.current_region = Rect2i()
	map.heat_change = change
	map.heat_burns = burns
	map.heat_turns = turns
	return map


func test_the_drain_marks_the_stars_the_next_flow_carries_out() -> void:
	var run: RunState = _run(StarMap.aquarius_body())
	var doomed: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 230))
	var safe: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 230))
	var outside: Star = run.add_star(Star.Size.SMALL, Vector2i(20, 230))
	assert_eq(run.launch_drains(), [doomed.id] as Array[int], "a step from the drain; the safe one and the one past it stay")
	assert_false(run.launch_drains().has(safe.id))
	assert_false(run.launch_drains().has(outside.id), "a star past the field doesn't move")


func test_a_current_that_doesnt_drain_marks_nothing() -> void:
	var run: RunState = _run(StarMap.aquarius_hand())
	run.add_star(Star.Size.SMALL, Vector2i(80, 230))
	assert_eq(run.launch_drains(), [] as Array[int])
	assert_eq(_run(_heat_map(1)).launch_drains(), [] as Array[int], "no current at all")


func test_the_marked_stars_are_the_ones_drained_wherever_the_launch_is_aimed() -> void:
	for aim: Vector2i in [Vector2i(30, 120), Vector2i(150, 120), Vector2i(70, 220), Vector2i(120, 240)]:
		var run: RunState = _run(StarMap.aquarius_body(), 11)
		run.add_star(Star.Size.SMALL, Vector2i(60, 230))
		run.add_star(Star.Size.MEDIUM, Vector2i(64, 110))
		run.add_star(Star.Size.BIG, Vector2i(150, 230))
		run.add_star(Star.Size.SMALL, Vector2i(100, 236))
		var marked: Array[int] = run.launch_drains()
		var existing: Array[int] = Fixtures.ids(run.stars)
		watch_signals(run)
		assert_true(run.launch(aim), str(aim))
		var drained: Array[int] = []
		for move: StarCurrent.Move in get_signal_parameters(run, "stars_shifted")[0]:
			# The launch's own stars drift with the flow too: they weren't in the sky to mark.
			if move.drained and existing.has(move.star_id):
				drained.append(move.star_id)
		drained.sort()
		marked.sort()
		assert_eq(drained, marked, "aimed at %s: the marks were the stars it drained" % aim)


func test_the_tide_marks_the_way_the_next_launch_goes() -> void:
	var run: RunState = _run(StarMap.aquarius_jar(), 3)
	var kept: Star = run.add_star(Star.Size.SMALL, Vector2i(110, 230))
	var going: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 230))
	assert_eq(run.launch_drains(), [going.id] as Array[int], "out to the left first")
	assert_true(run.launch(Vector2i(140, 120)))
	assert_false(run.stars.has(going), "it went")
	assert_eq(kept.position, Vector2i(54, 230))
	assert_eq(run.launch_drains(), [] as Array[int], "the tide turned: it comes back")
	var right: Star = run.add_star(Star.Size.SMALL, Vector2i(110, 160))
	assert_eq(run.launch_drains(), [right.id] as Array[int], "now the right side takes a star there")


func test_the_heat_marks_the_bigs_it_burns_out() -> void:
	var run: RunState = _run(_heat_map(1))
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
	run.add_star(Star.Size.MEDIUM, Vector2i(150, 110))
	run.add_star(Star.Size.SMALL, Vector2i(30, 230))
	assert_eq(run.launch_burns(), [big.id] as Array[int])
	assert_eq(run.launch_fades(), [] as Array[int], "nothing fades in the heat")
	assert_eq(_run(_heat_map(1, false)).launch_burns(), [] as Array[int], "a heat that doesn't burn")


func test_the_cold_marks_the_smalls_it_fades() -> void:
	var run: RunState = _run(_heat_map(-1))
	run.add_star(Star.Size.BIG, Vector2i(150, 230))
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 230))
	assert_eq(run.launch_fades(), [small.id] as Array[int])
	assert_eq(run.launch_burns(), [] as Array[int])


func test_day_and_night_marks_turn_with_the_heat() -> void:
	var run: RunState = _run(_heat_map(1, true, true))
	run.owned_packs["blue"] = 2
	run.loaded_pack = "blue"
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 230))
	assert_eq(run.launch_burns(), [big.id] as Array[int], "by day the big burns")
	assert_eq(run.launch_fades(), [] as Array[int])
	assert_true(run.launch(Vector2i(90, 120)))
	assert_eq(small.size, Star.Size.MEDIUM)
	assert_eq(run.launch_burns(), [] as Array[int], "by night nothing burns")
	for id: int in run.launch_fades():
		assert_eq(run.find_star(id).size, Star.Size.SMALL, "by night the smalls fade")


func test_the_head_never_marks_the_lions_own_stars() -> void:
	var run: RunState = _run(StarMap.leo_head())
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(150, 236))
	assert_eq(run.launch_burns(), [big.id] as Array[int], "they burn back to small, they aren't lost")


func test_a_drained_star_isnt_also_marked_to_burn() -> void:
	var map: StarMap = StarMap.aquarius_body()
	map.heat_change = 1
	map.heat_burns = true
	var run: RunState = _run(map)
	var doomed: Star = run.add_star(Star.Size.BIG, Vector2i(60, 230))
	var burning: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
	assert_eq(run.launch_drains(), [doomed.id] as Array[int])
	assert_eq(run.launch_burns(), [burning.id] as Array[int])


func test_a_star_linked_away_is_no_longer_marked() -> void:
	var run: RunState = _run(StarMap.aquarius_body())
	var trio: Array[Star] = [
		run.add_star(Star.Size.SMALL, Vector2i(56, 230)),
		run.add_star(Star.Size.SMALL, Vector2i(66, 212)),
		run.add_star(Star.Size.SMALL, Vector2i(70, 238)),
	]
	assert_eq(run.launch_drains().size(), 3)
	assert_ne(run.link(Fixtures.ids(trio)), Combos.INVALID)
	assert_eq(run.launch_drains(), [] as Array[int], "linked: nothing left to drain")
	var hot: RunState = _run(_heat_map(1))
	var bigs: Array[Star] = [
		hot.add_star(Star.Size.BIG, Vector2i(130, 220)),
		hot.add_star(Star.Size.BIG, Vector2i(150, 236)),
		hot.add_star(Star.Size.BIG, Vector2i(160, 210)),
	]
	assert_eq(hot.launch_burns().size(), 3)
	assert_ne(hot.link(Fixtures.ids(bigs)), Combos.INVALID)
	assert_eq(hot.launch_burns(), [] as Array[int], "linked: nothing left to burn")


func test_a_run_that_is_over_marks_nothing() -> void:
	var run: RunState = _run(_heat_map(1))
	run.add_star(Star.Size.BIG, Vector2i(150, 230))
	run.outcome = RunState.Outcome.LOST
	assert_eq(run.launch_burns(), [] as Array[int])


# The views: the marks show while the player isn't aiming, and give way to the aim's full preview.

const MainScene := preload("res://game/scenes/main.tscn")


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	add_child_autofree(main)
	return main


func _idle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		if not sequencer.is_busy():
			return
		sequencer.advance(0.03)


func test_a_star_the_drain_takes_wears_an_ember_arrow_while_not_aiming() -> void:
	var main: Main = _main("aquarius_body")
	_idle(main)
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var star: Star = main.run.add_star(Star.Size.SMALL, Vector2i(60, 230))
	var mark: Dictionary[Vector2i, Color] = CurrentView.drain_mark_pixels(star.position, star.size, Vector2i.LEFT, 0.0)
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in mark:
		assert_eq(dots.get(point), mark[point], "the arrow shows")
		assert_lt(point.x, star.position.x - StarView.half_extent(star.size), "beside the star, on the side it goes")
	view.aiming = true
	dots = view.pixels()
	var arm: Vector2i = star.position + Vector2i(-StarView.half_extent(star.size) - CurrentView.MARK_GAP + 1, 1)
	assert_true(mark.has(arm))
	assert_false(dots.has(arm), "the aim's trail takes over")


func test_the_drain_arrow_nudges_on_a_slow_two_step() -> void:
	var at := Vector2i(90, 160)
	var a: Dictionary[Vector2i, Color] = CurrentView.drain_mark_pixels(at, Star.Size.SMALL, Vector2i.DOWN, 0.0)
	var b: Dictionary[Vector2i, Color] = CurrentView.drain_mark_pixels(at, Star.Size.SMALL, Vector2i.DOWN, CurrentView.MARK_STEP)
	assert_eq(a, CurrentView.drain_mark_pixels(at, Star.Size.SMALL, Vector2i.DOWN, CurrentView.MARK_STEP * 2.0), "two steps")
	assert_eq(a.size(), b.size())
	for point: Vector2i in a:
		assert_eq(b.get(point + Vector2i.DOWN), a[point], "a pixel further down the flow")
		assert_eq(a[point], Palette.S4, "ember")


func test_a_star_the_heat_burns_wears_its_crown_while_not_aiming() -> void:
	var main: Main = _main("leo_haunch")
	_idle(main)
	var view: HeatView = main.get_node("Sky/HeatLayer")
	var big: Star = main.run.add_star(Star.Size.BIG, Vector2i(30, 236))
	var top: Vector2i = big.position + Vector2i(0, -StarView.half_extent(big.size) - 2)
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	for offset: Vector2i in HeatView.FLAMES:
		if offset != Vector2i(0, -5):
			assert_eq(dots.get(top + offset), HeatView.FLAMES[offset], "the crown shows")
	var ring: Array[Vector2i] = []
	for offset: Vector2i in StarView.outline_pixels(big.size):
		if (offset.x + offset.y) % 2 == 0:
			ring.append(big.position + offset)
	assert_false(ring.any(func(p: Vector2i) -> bool: return dots.get(p) == Palette.S4), "quiet: no dotted ring until the aim")
	view.aiming = true
	dots = view.pixels()
	assert_true(ring.all(func(p: Vector2i) -> bool: return dots.get(p) == Palette.S4), "the aim's full preview rings it")
	assert_eq(dots.get(top + Vector2i(0, -3)), HeatView.FLAMES[Vector2i(0, -3)], "and keeps the crown")


func test_the_marks_flicker_a_point_on_a_slow_two_step() -> void:
	var run: RunState = _run(_heat_map(-1))
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 230))
	var a: Dictionary[Vector2i, Color] = HeatView.mark_pixels(run, 0.0)
	var b: Dictionary[Vector2i, Color] = HeatView.mark_pixels(run, HeatView.MARK_STEP)
	assert_eq(a.size(), HeatView.SNOWFLAKE.size(), "the snowflake")
	assert_eq(b.size(), HeatView.SNOWFLAKE.size() - HeatView.FLAKE_POINTS.size(), "its points drop out")
	assert_eq(HeatView.mark_pixels(run, HeatView.MARK_STEP * 2.0), a)
	var over := Vector2i(0, -StarView.half_extent(small.size) - 2)
	for point: Vector2i in a:
		assert_lt(point.y, small.position.y - StarView.half_extent(small.size), "above the star, never over it")
	assert_true(a.has(small.position + over + Vector2i(0, -1)))


func test_no_marks_while_a_launch_plays_out() -> void:
	var main: Main = _main("leo_haunch")
	_idle(main)
	var view: HeatView = main.get_node("Sky/HeatLayer")
	main.run.owned_packs["blue"] = 1
	main.run.loaded_pack = "blue"
	assert_true(main.run.launch(Vector2i(150, 120)))
	var big: Star = main.run.add_star(Star.Size.BIG, Vector2i(30, 236))
	var flame: Vector2i = big.position + Vector2i(0, -StarView.half_extent(big.size) - 5)
	assert_true(main.get_node("EventSequencer").is_busy())
	assert_false(view.pixels().has(flame), "the stars' views haven't caught up: no marks yet")
	_idle(main)
	assert_eq(view.pixels().get(flame), HeatView.FLAMES[Vector2i(0, -3)], "then the crown")
