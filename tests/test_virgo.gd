extends GutTest
## Chapter 4, Virgo: the harvest's clock and scythe, the bound sheaves, Virgo's link dust, the
## intros, the figure and its first stages, and how the harvest shows (previews, the blade, the
## wheat clock, the rule).

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)


func _run(map: StarMap, seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)
	# Enough dust and packs that the run never ends for want of them while a test launches.
	run.dust = 100
	run.owned_packs["blue"] = 20
	return run


## Launches until the next launch brings the harvest (at most a clock's worth).
func _launch_until_harvest_next(run: RunState) -> void:
	for i: int in run.harvest.every:
		if run.harvest.is_next():
			return
		assert_true(Fixtures.launch(run, Vector2i(150, 110)), "a launch")
	assert_true(run.harvest.is_next(), "the harvest is next")


func test_the_clock_counts_launches_and_starts_over_at_the_harvest() -> void:
	var harvest := StarHarvest.new(3)
	assert_eq(harvest.launches_left, 3)
	assert_false(harvest.count_launch())
	assert_false(harvest.is_next())
	assert_false(harvest.count_launch())
	assert_true(harvest.is_next(), "the next launch brings it")
	assert_true(harvest.count_launch(), "the harvest")
	assert_eq(harvest.launches_left, 3, "and the clock starts over")


func test_a_lit_star_not_joined_to_the_bound_figure_goes_dark() -> void:
	# A chain 0-1-2-3, 0 bound: 1 is joined through lit 0; 3 is lit but 2 isn't.
	var neighbours := func(i: int) -> Array[int]:
		var found: Array[int] = []
		if i > 0:
			found.append(i - 1)
		if i < 3:
			found.append(i + 1)
		return found
	var lit: Array[bool] = [true, true, false, true]
	var bound: Array[bool] = [true, false, false, false]
	assert_eq(StarHarvest.unbound(lit, bound, neighbours), [3] as Array[int])
	lit[2] = true
	assert_eq(StarHarvest.unbound(lit, bound, neighbours), [] as Array[int], "a path of lit stars joins it")


func test_the_head_reaps_the_standing_stars_every_third_launch() -> void:
	var run: RunState = _run(StarMap.virgo_head())
	assert_not_null(run.harvest)
	assert_false(run.harvest.binds, "the scythe alone")
	assert_eq(run.harvest.every, 3)
	var old: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 100))
	var reaped: Array = []
	var counted: Array[int] = []
	run.harvested.connect(func(stars: Array[Star]) -> void: reaped.append(stars))
	run.harvest_counted.connect(func(left: int, _period: int) -> void: counted.append(left))
	_launch_until_harvest_next(run)
	assert_true(run.stars.has(old), "it stands until the harvest")
	assert_eq(run.harvest_preview().has(old.id), true, "the aim shows it will be reaped")
	var before: int = _next_id(run)
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	assert_eq(reaped.size(), 1, "one harvest")
	assert_true(reaped[0].has(old))
	assert_false(run.stars.has(old), "reaped, for nothing")
	for star: Star in run.stars:
		assert_gte(star.id, before, "only the last launch's stars stand")
	assert_eq(counted, [2, 1, 3] as Array[int], "the clock after each launch")


func test_a_red_planets_first_burst_is_reaped_by_the_harvest_it_brings() -> void:
	var run: RunState = _run(StarMap.virgo_head())
	run.owned_packs["red"] = 5
	_launch_until_harvest_next(run)
	run.stars.clear()
	var bursts: Array = []
	var order: Array[String] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
		order.append("burst")
		bursts.append(stars.duplicate()))
	var reaped: Array[Star] = []
	run.harvested.connect(func(stars: Array[Star]) -> void:
		order.append("harvest")
		reaped.assign(stars))
	run.load_pack("red")
	assert_true(run.launch(Vector2i(90, 150)))
	assert_eq(bursts.size(), 2, "a red planet bursts twice")
	assert_eq(order, ["burst", "harvest", "burst"] as Array[String], "the scythe sweeps between them")
	for star: Star in bursts[0]:
		assert_true(reaped.has(star), "its first burst is reaped")
		assert_false(run.stars.has(star))
	for star: Star in bursts[1]:
		assert_false(reaped.has(star), "its last burst stands")
		assert_true(run.stars.has(star))


func test_the_scythe_sweeps_before_a_blue_planet_bursts() -> void:
	var run: RunState = _run(StarMap.virgo_head())
	_launch_until_harvest_next(run)
	var order: Array[String] = []
	run.harvested.connect(func(_stars: Array[Star]) -> void: order.append("harvest"))
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, _stars: Array[Star]) -> void: order.append("burst"))
	run.load_pack("blue")
	assert_true(run.launch(Vector2i(90, 150)))
	assert_eq(order, ["harvest", "burst"] as Array[String])


func test_the_harvest_comes_over_an_empty_sky_too() -> void:
	var run: RunState = _run(StarMap.virgo_head())
	var harvests: Array[int] = []
	run.harvested.connect(func(stars: Array[Star]) -> void: harvests.append(stars.size()))
	_launch_until_harvest_next(run)
	run.stars.clear()
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	assert_eq(harvests, [0] as Array[int], "the scythe still sweeps")


func test_the_wing_puts_out_a_lit_star_not_joined_to_the_figure() -> void:
	var run: RunState = _run(StarMap.virgo_wing())
	assert_true(run.harvest.binds)
	# The shoulder (0) starts lit; 1 is joined to it; 3 (the far hand) isn't: 2 is still dark.
	run.scorpio.light(1)
	run.scorpio.light(3)
	_launch_until_harvest_next(run)
	assert_eq(run.unbound_preview(), [3] as Array[int], "the aim shows the far hand going dark")
	var out: Array = []
	var order: Array[String] = []
	run.harvested.connect(func(_stars: Array[Star]) -> void: order.append("reaped"))
	run.landmarks_unbound.connect(func(indices: Array[int]) -> void:
		order.append("put out")
		out.append_array(indices))
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	assert_eq(out, [3])
	assert_eq(order, ["reaped", "put out"] as Array[String], "the scythe sweeps, then the stars go dark")
	assert_false(run.scorpio.is_lit(3), "it goes dark")
	assert_true(run.scorpio.is_lit(1), "the joined one stays")
	# Lit again now and joined later, by the next harvest, it stays bound.
	run.scorpio.light(2)
	run.scorpio.light(3)
	_launch_until_harvest_next(run)
	assert_eq(run.unbound_preview(), [] as Array[int])
	out.clear()
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	assert_eq(out, [], "joined through the lit arm")


func test_the_head_never_puts_a_star_out() -> void:
	var run: RunState = _run(StarMap.virgo_head())
	run.scorpio.light(4)
	_launch_until_harvest_next(run)
	assert_eq(run.unbound_preview(), [] as Array[int])
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	assert_true(run.scorpio.is_lit(4), "the scythe alone doesn't bind")


func test_virgos_links_pay_less_dust_from_the_wing_on() -> void:
	var balance: Balance = Balance.load_file()
	var head: RunState = _run(StarMap.virgo_head())
	var wing: RunState = _run(StarMap.virgo_wing())
	var leo := RunState.new(balance, Fixtures.rng(), SKY, StarMap.leo_tail())
	for combo: String in balance.combos:
		var full: int = balance.combos[combo].dust
		assert_eq(head.link_dust(combo), full, "the Head teaches the scythe alone")
		assert_eq(leo.link_dust(combo), full, "other chapters pay in full")
		assert_eq(wing.link_dust(combo), full * balance.harvest_link_dust_percent_for("virgo_wing") / 100)
	assert_lt(wing.link_dust("small_triple"), balance.combos["small_triple"].dust)


func test_a_link_pays_virgos_dust() -> void:
	var run: RunState = _run(StarMap.virgo_wing())
	var a: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 100))
	var b: Star = run.add_star(Star.Size.SMALL, Vector2i(50, 100))
	var c: Star = run.add_star(Star.Size.SMALL, Vector2i(70, 100))
	var before: int = run.dust
	var paid: Array[int] = []
	run.combo_collected.connect(func(_combo: String, _stars: Array[Star], dust: int, _light: int) -> void: paid.append(dust))
	assert_eq(run.link([a.id, b.id, c.id]), "small_triple")
	assert_eq(run.dust - before, run.link_dust("small_triple"))
	assert_eq(paid, [run.link_dust("small_triple")] as Array[int], "the payout shows what was paid")


func test_harvest_stages_read_from_balance_json() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["harvest"] = {"every": 3, "link_dust_percent": 80, "stages": {"virgo_head": {"every": 4, "link_dust_percent": 100}}}
	var balance: Balance = Balance.from_dict(data)
	assert_true(balance.is_valid(), str(balance.errors))
	assert_eq(balance.harvest_every_for("virgo_head"), 4)
	assert_eq(balance.harvest_link_dust_percent_for("virgo_head"), 100)
	assert_eq(balance.harvest_every_for("virgo_wing"), 3, "the default")
	assert_eq(balance.harvest_link_dust_percent_for("virgo_wing"), 80)
	data["harvest"] = {"every": 0}
	assert_false(Balance.from_dict(data).is_valid(), "a clock needs a launch")


func test_the_head_opens_by_showing_the_scythe_reap_three_stars() -> void:
	var run: RunState = _run(StarMap.virgo_head())
	var packs: Dictionary = run.owned_packs.duplicate()
	var placed: Array = []
	var reaped: Array = []
	var order: Array[String] = []
	var clock: Array[int] = []
	var landed: Array = []
	var ended: Array = []
	run.harvest_intro_placed.connect(func(stars: Array[Star]) -> void:
		order.append("placed")
		placed.append_array(stars))
	run.harvest_intro_clock.connect(func(left: int) -> void:
		order.append("clock")
		clock.append(left))
	run.hunt_intro_launched.connect(func(kind: String, _at: Vector2i) -> void:
		order.append("launched")
		assert_eq(kind, "blue", "a blue planet"))
	run.harvested.connect(func(stars: Array[Star]) -> void:
		order.append("scythe")
		reaped.append_array(stars))
	run.hunt_intro_burst.connect(func(_at: Vector2i, stars: Array[Star]) -> void:
		order.append("burst")
		landed.append_array(stars))
	run.harvest_intro_ended.connect(func(stars: Array[Star]) -> void:
		order.append("ended")
		ended.append_array(stars))
	run.play_harvest_intro()
	assert_eq(order, ["clock", "placed", "launched", "scythe", "burst", "clock", "ended"] as Array[String], "it opens on the last ear, a planet is launched, the scythe clears the sky, then the planet bursts")
	assert_eq(clock, [1, run.harvest.every] as Array[int], "on its last ear, then grown back")
	assert_eq(placed.size(), 3, "one of each size")
	assert_eq(reaped.size(), 3, "the scythe takes them all")
	for star: Star in landed:
		assert_false(reaped.has(star), "the planet's stars land after the scythe")
	assert_eq(ended, landed, "and leave once seen")
	assert_true(run.stars.is_empty())
	assert_eq(run.harvest.launches_left, run.harvest.every, "the clock doesn't move")
	assert_eq(run.owned_packs, packs)
	assert_eq(run.dust, 100, "it pays nothing")


func test_the_wing_opens_by_showing_a_joined_star_kept_and_a_lone_one_put_out() -> void:
	var run: RunState = _run(StarMap.virgo_wing())
	var order: Array[String] = []
	var lit: Array = []
	var kept: Array[int] = []
	var out: Array[int] = []
	var cleared: Array[int] = []
	var links: Array = []
	var placed: Array = []
	run.harvest_intro_placed.connect(func(stars: Array[Star]) -> void:
		order.append("placed")
		placed.append(stars))
	run.harvest_intro_lit.connect(func(index: int, alone: bool, link: Array[int]) -> void:
		order.append("lit")
		lit.append([index, alone])
		links.append(link))
	run.harvested.connect(func(stars: Array[Star]) -> void:
		order.append("sweep")
		assert_true(stars.is_empty(), "the demo has no loose stars"))
	run.harvest_intro_kept.connect(func(index: int) -> void:
		order.append("kept")
		kept.append(index))
	run.landmarks_unbound.connect(func(indices: Array[int]) -> void:
		order.append("out")
		out.append_array(indices))
	run.harvest_intro_cleared.connect(func(indices: Array[int]) -> void:
		order.append("cleared")
		cleared.append_array(indices))
	run.play_harvest_intro()
	assert_eq(order, ["placed", "lit", "placed", "lit", "sweep", "kept", "out", "cleared"] as Array[String])
	for k: int in 2:
		var pair: Array = placed[k]
		assert_eq(pair.size(), 2, "two demo stars for each combo")
		var size: int = StarMap.virgo_wing().sizes[lit[k][0]]
		for star: Star in pair:
			assert_eq(star.size, size, "a triple with the star it lights")
		var link: Array[int] = links[k]
		assert_eq(link.size(), 3)
		assert_true(link.has(Scorpio.landmark_id(lit[k][0])), "the combo lights it")
		assert_true(run.link_in_reach(link), "a link a player could trace")
	assert_true(run.stars.is_empty(), "the demo stars are gone")
	var near: int = lit[0][0]
	var far: int = lit[1][0]
	assert_false(lit[0][1], "the first is joined")
	assert_true(lit[1][1], "the second alone")
	assert_true(StarMap.virgo_wing().neighbours(near).has(0), "next to the lit shoulder")
	assert_true(far == 3 or far == 6, "an arm's far end")
	assert_eq(kept, [near] as Array[int])
	assert_eq(out, [far] as Array[int])
	assert_eq(cleared, [near] as Array[int])
	for index: int in [near, far]:
		assert_false(run.scorpio.is_lit(index), "no progress changes")
	assert_eq(run.harvest.launches_left, run.harvest.every, "the clock doesn't move")


func test_a_lone_lit_star_is_marked_from_the_moment_its_lit() -> void:
	var main: Main = _main("virgo_wing")
	var run: RunState = main.run
	var view: HarvestView = main.get_node("Sky/HarvestLayer")
	_settle(main)
	assert_eq(run.loose_landmarks(), [] as Array[int])
	run.scorpio.light(3)
	assert_eq(run.loose_landmarks(), [3] as Array[int], "alone, far from the lit shoulder")
	assert_false(run.harvest.is_next(), "long before the harvest")
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	var at: Vector2i = run.scorpio.landmark_position(3)
	var ring: int = 0
	for p: Vector2i in HarvestView.lone_ring_pixels(at, Star.Size.SMALL, 0.0):
		ring += int(dots.get(p) in [Palette.S4, Palette.S3])
	assert_gt(ring, 12, "its ember ring shows at once, not only while aiming")
	run.scorpio.light(1)
	run.scorpio.light(2)
	assert_eq(run.loose_landmarks(), [] as Array[int], "joined through the arm: safe")


func test_lighting_a_lone_star_says_the_scythe_cuts_it() -> void:
	var main: Main = _main("virgo_wing")
	var run: RunState = main.run
	var hud: Hud = main.get_node("HUD")
	_settle(main)
	run.scorpio.light(3)
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	sequencer.event_played.emit(EventSequencer.RunEvent.new(&"landmark_lit", [3]))
	assert_eq(hud.message(), Hud.LONE_MESSAGE)


func test_the_hint_grows_the_figure_where_the_harvest_binds() -> void:
	var run: RunState = _run(StarMap.virgo_wing())
	# Bigs that can light the joined star 1, and mediums that could light star 2 alone.
	run.add_star(Star.Size.BIG, Vector2i(60, 190))
	run.add_star(Star.Size.BIG, Vector2i(84, 168))
	run.add_star(Star.Size.MEDIUM, Vector2i(40, 160))
	run.add_star(Star.Size.MEDIUM, Vector2i(60, 140))
	var rng := Fixtures.rng(3)
	for i: int in 20:
		var link: Array[int] = run.idle_hint_link(rng)
		for id: int in link:
			if run.scorpio.is_landmark(id):
				assert_true(Scorpio.landmark_index(id) in [1, 4], "the hint lights a star next to the shoulder, never the lone one")


func test_the_intro_never_shifts_the_packs() -> void:
	var sizes: Array = [[], []]
	for k: int in 2:
		var run: RunState = _run(StarMap.virgo_head(), 11)
		if k == 1:
			run.play_harvest_intro()
		var bursts: Array = []
		run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
			for star: Star in stars:
				bursts.append(star.size))
		for i: int in 2:
			Fixtures.launch(run, Vector2i(40 + 60 * i, 200))
		sizes[k] = bursts
	assert_eq(sizes[0], sizes[1], "the same packs open with or without it")


func test_the_virgo_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.virgo()
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
	assert_eq(StarMap.by_id("virgo").title, "VIRGO")


func test_virgo_is_chapter_4_after_leo_on_the_sky() -> void:
	var virgo := Chapter.new(ChapterDef.virgo())
	assert_eq(virgo.def.number, 4)
	assert_eq(virgo.def.unlocked_by, "leo")
	assert_eq(virgo.stage_name(0), "HEAD")
	assert_eq(virgo.map_id(0), "virgo_head")
	assert_eq(virgo.map_id(1), "virgo_wing")
	assert_eq(virgo.map_id(2), "virgo_robe")
	assert_gt(ChapterSelect.sky_x("virgo"), ChapterSelect.sky_x("leo"), "the next sign east")


func test_the_head_and_wing_are_pickable_harvest_stages() -> void:
	for map: StarMap in [StarMap.virgo_head(), StarMap.virgo_wing()]:
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [map.id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
		assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
		assert_eq(map.sizes.size(), map.count())
		assert_true(map.harvest)
		assert_eq(map.starting_lit, [0] as Array[int])
		assert_eq(map.heat_change, 0, "Leo's heat stays in chapter 3")
		assert_false(map.orion or map.current_region.has_area())
	assert_eq(StarMap.virgo_wing().neighbours(0).size(), 2, "the wing's two arms leave the shoulder")


func test_the_aim_previews_the_reap_and_the_put_out() -> void:
	var main: Main = _main("virgo_wing")
	var run: RunState = main.run
	var view: HarvestView = main.get_node("Sky/HarvestLayer")
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.scorpio.light(3)
	var star: Star = run.add_star(Star.Size.MEDIUM, Vector2i(120, 110))
	view.aiming = true
	assert_true(view.pixels().is_empty(), "nothing while the harvest isn't next")
	_launch_until_harvest_next(run)
	var dots: Dictionary[Vector2i, Color] = HarvestView.preview_pixels(run)
	var ember: int = 0
	for offset: Vector2i in StarView.outline_pixels(Star.Size.MEDIUM):
		ember += int(dots.get(star.position + offset) == Palette.S4)
	assert_gt(ember, 3, "the star it reaps wears an ember outline")
	var ring: int = 0
	var at: Vector2i = run.scorpio.landmark_position(3)
	for p: Vector2i in HarvestView.lone_ring_pixels(at, Star.Size.SMALL, 0.0):
		ring += int(dots.get(p) in [Palette.S4, Palette.S3])
	assert_gt(ring, 12, "the star it puts out its lone ring")


func test_the_blade_chaff_and_put_out_stay_in_the_palette_and_on_the_grid() -> void:
	for k: float in [0.0, 0.3, 0.7, 1.0]:
		var blade: Dictionary[Vector2i, Color] = HarvestView.blade_pixels(SKY, k)
		assert_false(blade.is_empty())
		for p: Vector2i in blade:
			assert_true(SKY.has_point(p), "inside the sky")
	for t: float in [0.0, 0.2, 0.4]:
		for dots: Dictionary in [HarvestView.chaff_pixels(Vector2i(90, 150), t), HarvestView.put_out_pixels(Vector2i(90, 150), t)]:
			for p: Vector2i in dots:
				assert_true(dots[p] in [Palette.C2, Palette.C3, Palette.S4, Palette.S3, Palette.S2], "palette")
	for k: float in [0.0, 0.5]:
		for colour: Color in HarvestView.blade_pixels(SKY, k).values():
			assert_true(colour in [Palette.C0, Palette.C1, Palette.C2, Palette.C3], "the blade is warm palette gold")


func test_a_harvest_sweeps_and_cuts_the_star_views() -> void:
	var main: Main = _main("virgo_head")
	var run: RunState = main.run
	run.dust = 100
	run.owned_packs["blue"] = 20
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var view: HarvestView = main.get_node("Sky/HarvestLayer")
	_settle(main)
	var old: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 100))
	sky.setup(run, sequencer)
	_launch_until_harvest_next(run)
	_settle(main)
	watch_signals(sky)
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	var swept: bool = false
	for i: int in 200:
		sequencer.advance(0.03)
		view.advance(0.03)
		swept = swept or view.is_sweeping()
		for child: Node in sky.get_node("StarLayer").get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				(child as StarView).advance(0.03)
		if not sequencer.is_busy():
			break
	assert_true(swept, "the blade swept the sky")
	assert_signal_emitted(sky, "harvest_swept")
	assert_null(sky.star_view(old.id), "the old star was cut")


func test_the_wheat_clock_counts_down_and_ripens() -> void:
	var main: Main = _main("virgo_head")
	var hud: Hud = main.get_node("HUD")
	var clock: HarvestClock = hud.get_node("HarvestClock")
	assert_true(clock.visible)
	assert_eq(clock.standing(), 3)
	clock.count(1)
	var gold: int = 0
	for colour: Color in clock.pixels().values():
		gold += int(colour == HarvestClock.RIPE_GRAIN)
	assert_gt(gold, 0, "the last ear is ripe gold")
	clock.count(3)
	assert_eq(clock.standing(), 3, "the harvest grows them back")
	var leo: Main = _main("leo_tail")
	assert_false((leo.get_node("HUD/HarvestClock") as HarvestClock).visible, "only under the harvest")


func test_each_harvest_says_its_rule_in_a_line_that_fits() -> void:
	assert_eq(Hud.harvest_rule(StarHarvest.new(3)), "EVERY 3 LAUNCHES THE\nSCYTHE REAPS THE SKY")
	assert_eq(Hud.harvest_rule(StarHarvest.new(3, true)), Hud.BIND_MESSAGE)
	for text: String in [Hud.harvest_rule(StarHarvest.new(3)), Hud.BIND_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 22, line)


func test_the_table_shows_virgos_dust() -> void:
	var balance: Balance = Balance.load_file()
	var rows: Array[Dictionary] = PaytableView.rows_for(balance, 90)
	for row: Dictionary in rows:
		assert_eq(row["dust"], balance.combos[row["key"]].dust * 90 / 100)


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_virgo_settings.cfg"
	add_child_autofree(main)
	return main


## Plays out whatever the sequencer holds (the intro).
func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func _next_id(run: RunState) -> int:
	return run.get("_next_star_id")


func test_the_quickening_shortens_the_clock_each_harvest_down_to_one() -> void:
	var harvest := StarHarvest.new(3, false, true)
	var periods: Array[int] = []
	for launch: int in 9:
		if harvest.count_launch():
			periods.append(harvest.period)
	assert_eq(periods, [2, 1, 1, 1, 1, 1] as Array[int], "3 launches, then 2, then 1 at a time")


func test_tied_at_once_puts_out_an_unjoined_star_after_any_launch() -> void:
	var map: StarMap = StarMap.virgo_feet()
	map.harvest_ties = true
	var run: RunState = _run(map)
	run.scorpio.light(3)
	assert_eq(run.unbound_preview(), [3] as Array[int], "the aim shows it at once, harvest or not")
	var out: Array[int] = []
	run.landmarks_unbound.connect(func(indices: Array[int]) -> void: out.append_array(indices))
	assert_false(run.harvest.is_next())
	assert_true(Fixtures.launch(run, Vector2i(150, 110)))
	assert_eq(out, [3] as Array[int], "put out after the first launch")


func test_virgos_later_stages_are_pickable_branching_harvest_stages() -> void:
	for map: StarMap in [StarMap.virgo_robe(), StarMap.virgo_feet(), StarMap.virgo_wheat()]:
		var inner: Rect2i = StarScatter.inner_rect(SKY)
		for i: int in map.count():
			assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [map.id, i])
			for j: int in range(i + 1, map.count()):
				assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS, "%s %d-%d" % [map.id, i, j])
		assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
		assert_true(map.harvest and map.harvest_binds)
		var forks: int = 0
		for i: int in map.count():
			forks += int(map.neighbours(i).size() > 2)
		assert_gt(forks, 0, "%s branches" % map.id)
	var final: StarMap = StarMap.virgo_final()
	assert_eq(final.count(), StarMap.virgo().count(), "the whole Virgo")
	assert_eq(final.arrival_epithet, "MAIDEN OF THE HARVEST")
	var virgo := Chapter.new(ChapterDef.virgo())
	for stage: int in Chapter.stage_count():
		assert_ne(virgo.map_id(stage), "", "stage %d is built" % stage)


func test_a_quickening_clock_loses_an_ear_each_harvest() -> void:
	var clock := HarvestClock.new()
	add_child_autofree(clock)
	clock.setup(3, 3)
	clock.count(2, 3)
	clock.count(1, 3)
	clock.count(2, 2)
	assert_eq(clock.period(), 2)
	assert_eq(clock.standing(), 2)
	var columns: Dictionary[int, bool] = {}
	for p: Vector2i in clock.pixels():
		columns[p.x] = true
	assert_false(columns.has(HarvestClock.SPACING), "the lost ear's place is empty")


func test_the_twists_say_their_rules() -> void:
	assert_eq(Hud.harvest_rule(StarHarvest.new(3, true, false, true)), Hud.TIE_MESSAGE)
	assert_eq(Hud.harvest_rule(StarHarvest.new(3, true, true)), Hud.QUICKEN_MESSAGE)
	for text: String in [Hud.TIE_MESSAGE, Hud.QUICKEN_MESSAGE, Hud.LONE_MESSAGE, Hud.BIND_MESSAGE]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 22, line)


func test_a_cropped_star_is_caught_slashed_and_split_and_its_strings_snap() -> void:
	var at := Vector2i(90, 150)
	var end := Vector2i(90, 190)
	var caught: Dictionary[Vector2i, Color] = HarvestView.crop_pixels(at, Star.Size.MEDIUM, [end], 0.02)
	assert_true(caught.values().has(Palette.C0), "the blade catches it: a white flicker")
	var slash_t: float = HarvestView.CROP_CHARGE + 0.02
	var slashed: Dictionary[Vector2i, Color] = HarvestView.crop_pixels(at, Star.Size.MEDIUM, [end], slash_t)
	var reach: int = StarView.half_extent(Star.Size.MEDIUM) + 5
	assert_eq(slashed.get(at + Vector2i(reach, reach)), Palette.C0, "a white slash across it")
	var late: Dictionary[Vector2i, Color] = HarvestView.crop_pixels(at, Star.Size.MEDIUM, [end], HarvestView.CROP_TIME * 0.8)
	var below: int = 0
	var above: int = 0
	for p: Vector2i in late:
		if p.y > at.y + 6:
			below += 1
		if p.y < at.y - 3:
			above += 1
	assert_gt(below, 0, "the lower half falls away")
	assert_gt(above, 0, "the upper half slides off")
	var snapping: int = 0
	for p: Vector2i in LinkLayer.line_pixels(at, end):
		snapping += int(slashed.get(p) == Palette.S4)
	assert_gt(snapping, 5, "the string to the lit star flares ember")
	assert_true(HarvestView.crop_pixels(at, Star.Size.MEDIUM, [end], HarvestView.CROP_TIME).is_empty(), "then it's over")
	for t: float in [0.0, 0.1, 0.2, 0.35, 0.5]:
		for colour: Color in HarvestView.crop_pixels(at, Star.Size.BIG, [end], t).values():
			assert_true(colour in [Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.S4, Palette.S3, Palette.M6, Palette.M5] or ConstellationView.star_pixels(Star.Size.BIG, &"lit").values().has(colour), "palette")


func test_the_constellation_hides_a_cropped_star_then_shows_it_dark() -> void:
	var main: Main = _main("virgo_wing")
	var constellation: ConstellationView = main.get_node("Sky/ConstellationLayer")
	constellation.flash_landmark(3)
	constellation.crop(3, HarvestView.CROP_TIME)
	assert_false(constellation.shows_lit(3), "dark")
	assert_true(constellation.is_cropping(3), "hidden while its halves fly")
	constellation.advance(HarvestView.CROP_TIME + 0.01)
	assert_false(constellation.is_cropping(3), "then shown, unlit")


func test_the_head_opens_with_the_clock_on_its_last_ear() -> void:
	var main: Main = _main("virgo_head")
	var clock: HarvestClock = main.get_node("HUD/HarvestClock")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	sequencer.advance(0.01)
	assert_eq(clock.standing(), 1, "the demo opens on the last ear")
	var cut: bool = false
	for colour: Color in clock.pixels().values():
		cut = cut or colour == Palette.C0
	assert_false(cut, "a jump, not a cut")
	_settle(main)
	assert_eq(clock.standing(), main.run.harvest.every, "back to full for play")
