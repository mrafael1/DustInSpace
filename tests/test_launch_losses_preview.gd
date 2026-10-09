extends GutTest
## #149: the aim previewed only the stars already in the sky, never the launch's own: in Aquarius a
## fresh burst can be carried out on the launch that brings it, and on Virgo's harvest launch a red
## planet's first burst is reaped as it lands. The scatter ring now shows those in ember.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")


func _run(map: StarMap, seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), Scorpio.HOME_SKY, map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 20
	return run


# --- The flow -------------------------------------------------------------------------------

func test_a_new_star_landing_a_step_from_the_drain_is_carried_out() -> void:
	var run: RunState = _run(StarMap.aquarius_body())
	var region: Rect2i = run.current.region
	var way: Vector2i = run.current.displacement
	assert_lt(way.x, 0, "the Body flows left, to its drain")
	var y: int = region.get_center().y
	assert_true(run.burst_drains_at(Vector2i(region.position.x + 2, y)), "just inside the drain line")
	assert_true(run.burst_drains_at(Vector2i(region.position.x - way.x - 1, y)), "a step's width from it")
	assert_false(run.burst_drains_at(Vector2i(region.position.x - way.x, y)), "a whole step upstream stays")
	assert_false(run.burst_drains_at(Vector2i(region.position.x - 10, y)), "past the drain: not in the flow")
	var hand: RunState = _run(StarMap.aquarius_hand())
	assert_false(hand.burst_drains_at(Vector2i(hand.current.region.position.x + 2, y)), "the Hand's flow doesn't drain")
	assert_false(_run(StarMap.leo_tail()).burst_drains_at(Vector2i(60, 150)), "no flow")


func test_the_preview_matches_which_new_stars_the_launch_drains() -> void:
	var checked: int = 0
	var drained_seen: int = 0
	for seed_value: int in range(1, 31):
		var run: RunState = _run(StarMap.aquarius_body(), seed_value)
		var expected: Dictionary[int, bool] = {}
		run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
			for star: Star in stars:
				expected[star.id] = run.burst_drains_at(star.position))
		var drained: Dictionary[int, bool] = {}
		run.stars_shifted.connect(func(moves: Array[StarCurrent.Move]) -> void:
			for move: StarCurrent.Move in moves:
				if move.drained:
					drained[move.star_id] = true)
		run.load_pack("blue")
		run.launch(Vector2i(run.current.region.position.x + 14, 150))
		for id: int in expected:
			checked += 1
			drained_seen += int(drained.has(id))
			assert_eq(drained.has(id), expected[id], "seed %d: star %d" % [seed_value, id])
	assert_gt(checked, 60)
	assert_gt(drained_seen, 10, "the launch's own stars do drain there")


# --- The harvest ----------------------------------------------------------------------------

func test_on_the_harvest_launch_a_red_planets_first_burst_is_reaped() -> void:
	var run: RunState = _run(StarMap.virgo_wing())
	assert_eq(run.harvest_reaps_bursts("red"), [false, false] as Array[bool], "not before the harvest launch")
	assert_eq(run.harvest_reaps_bursts("blue"), [false] as Array[bool])
	while not run.harvest.is_next():
		run.load_pack("blue")
		run.launch(Vector2i(90, 150))
	assert_eq(run.harvest_reaps_bursts("red"), [true, false] as Array[bool], "its first burst lands before the scythe")
	assert_eq(run.harvest_reaps_bursts("blue"), [false] as Array[bool], "a blue planet bursts into the clean sky after it")
	var first: Array[int] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
		if first.is_empty():
			for star: Star in stars:
				first.append(star.id))
	var reaped: Array[int] = []
	run.harvested.connect(func(stars: Array[Star]) -> void:
		for star: Star in stars:
			reaped.append(star.id))
	run.load_pack("red")
	run.launch(Vector2i(90, 150))
	assert_eq(first.size(), 3)
	for id: int in first:
		assert_true(reaped.has(id), "the first burst was reaped, as previewed")


# --- The scene ------------------------------------------------------------------------------

func test_the_scatter_ring_shows_the_launchs_own_losses_in_ember() -> void:
	var main: Main = _main("aquarius_body")
	var telescope: Telescope = main.get_node("Telescope")
	var region: Rect2i = main.run.current.region
	var near_drain: Array[Vector2i] = [Vector2i(region.position.x + 8, 150)]
	var ring: Dictionary[Vector2i, Color] = telescope.scatter_ring_pixels(near_drain)
	assert_true(ring.values().has(Palette.S4), "the dots that land in the drain band go ember")
	assert_true(ring.values().has(Palette.M5), "the rest stay as they were")
	for p: Vector2i in ring:
		assert_eq(ring[p] == Palette.S4, main.run.burst_drains_at(p), "%s" % p)
	var upstream: Dictionary[Vector2i, Color] = telescope.scatter_ring_pixels([Vector2i(150, 150)] as Array[Vector2i])
	assert_false(upstream.values().has(Palette.S4), "far upstream: nothing lost")


func test_on_the_harvest_launch_a_reds_first_ring_is_ember_and_the_line_says_why() -> void:
	var main: Main = _main("virgo_wing")
	var run: RunState = main.run
	var hud: Hud = main.get_node("HUD")
	var telescope: Telescope = main.get_node("Telescope")
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 5
	while not run.harvest.is_next():
		run.load_pack("blue")
		run.launch(Vector2i(90, 150))
	_settle(main)
	run.load_pack("red")
	_settle(main)
	var points: Array[Vector2i] = StarScatter.split_points(Vector2i(90, 150), run.balance.packs["red"].burst_spread, 2, run.sky_rect)
	var ring: Dictionary[Vector2i, Color] = telescope.scatter_ring_pixels(points)
	var first_dots: int = 0
	var second_ember: int = 0
	for p: Vector2i in ring:
		if (p - points[0]).length() < (p - points[1]).length():
			first_dots += 1
			assert_eq(ring[p], Palette.S4, "the first burst's ring: reaped")
		else:
			second_ember += int(ring[p] == Palette.S4)
	assert_gt(first_dots, 10)
	assert_eq(second_ember, 0, "the second lands after the scythe")
	hud.clear_message()
	hud.tell_aim("blue")
	assert_eq(hud.message(), "", "a blue planet loses nothing to it")
	hud.tell_aim("red")
	assert_eq(hud.message(), Hud.FIRST_BURST_MESSAGE)
	hud.clear_message()
	hud.tell_aim("red")
	assert_eq(hud.message(), "", "once a run")
	for line: String in Hud.FIRST_BURST_MESSAGE.split("\n"):
		assert_lte(line.length(), 22, line)


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 7
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_launch_losses_settings.cfg"
	add_child_autofree(main)
	_settle(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 600:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return
