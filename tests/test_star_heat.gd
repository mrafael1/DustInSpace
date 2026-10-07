extends GutTest
## Leo's heat (chapter 3), over the whole stage: once a launch resolves, every loose star changes a
## size; the launch's own stars wait for the next; a star pushed past the last size is lost when it
## burns.

const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
func _heat(change: int = 1, burns: bool = true) -> StarHeat:
	return StarHeat.new(change, burns)


func _sizes(changes: Array[StarHeat.Change]) -> Dictionary:
	var result: Dictionary = {}
	for change: StarHeat.Change in changes:
		result[change.star_id] = "lost" if change.lost else Star.size_key(change.to)
	return result


func test_the_heat_grows_every_star_one_size_and_burns_a_big_one() -> void:
	var stars: Array[Star] = [
		Star.new(1, Star.Size.SMALL, Vector2i(120, 160)),
		Star.new(2, Star.Size.MEDIUM, Vector2i(150, 100)),
		Star.new(3, Star.Size.BIG, Vector2i(100, 230)),
		Star.new(4, Star.Size.SMALL, Vector2i(40, 160)),
	]
	assert_eq(_sizes(_heat().preview(stars)), {1: "medium", 2: "big", 3: "lost", 4: "medium"}, "wherever it is")
	var changes: Array[StarHeat.Change] = _heat().preview(stars)
	assert_eq(changes[2].from, Star.Size.BIG)
	assert_eq(changes[2].to, Star.Size.BIG, "a lost star keeps its size")


func test_a_heat_that_doesnt_burn_leaves_a_big_star_big() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.BIG, Vector2i(120, 160)), Star.new(2, Star.Size.SMALL, Vector2i(130, 190))]
	assert_eq(_sizes(_heat(1, false).preview(stars)), {2: "medium"})


func test_the_cold_shrinks_and_fades_a_small_one() -> void:
	var stars: Array[Star] = [
		Star.new(1, Star.Size.BIG, Vector2i(120, 160)),
		Star.new(2, Star.Size.MEDIUM, Vector2i(150, 100)),
		Star.new(3, Star.Size.SMALL, Vector2i(100, 230)),
	]
	assert_eq(_sizes(_heat(-1).preview(stars)), {1: "medium", 2: "small", 3: "lost"})
	assert_eq(_sizes(_heat(-1, false).preview(stars)), {1: "medium", 2: "small"}, "without burning a small stays small")


func test_a_skipped_star_waits() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, Vector2i(120, 160)), Star.new(2, Star.Size.SMALL, Vector2i(40, 160))]
	assert_eq(_sizes(_heat().preview(stars, {1: true})), {2: "medium"})


func _map(change: int = 1, burns: bool = true) -> StarMap:
	var map: StarMap = StarMap.aquarius_hand()
	map.current_region = Rect2i()
	map.heat_change = change
	map.heat_burns = burns
	return map


func _run(map: StarMap = _map(), seed_value: int = 7) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)


func test_a_map_without_heat_has_none() -> void:
	assert_null(RunState.new(Balance.load_file(), Fixtures.rng(), SKY, StarMap.aquarius_hand()).heat)
	assert_not_null(_run().heat)
	assert_null(_run().current)


func test_a_launch_resizes_the_stars_already_in_the_heat_but_not_its_own() -> void:
	for kind: String in ["blue", "red"]:
		var run: RunState = _run()
		run.owned_packs[kind] = 1
		run.loaded_pack = kind
		var small: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 110))
		var big: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
		var far: Star = run.add_star(Star.Size.SMALL, Vector2i(20, 230))
		var preview: Array[StarHeat.Change] = run.heat_preview()
		watch_signals(run)
		assert_true(run.launch(Vector2i(130, 160)), kind)
		assert_eq(small.size, Star.Size.MEDIUM, kind)
		assert_false(run.stars.has(big), "%s: the big one burned out" % kind)
		assert_eq(far.size, Star.Size.MEDIUM, "%s: anywhere in the sky" % kind)
		assert_signal_emitted(run, "stars_resized")
		var changes: Array = get_signal_parameters(run, "stars_resized")[0]
		assert_eq(_sizes(changes), _sizes(preview), "%s: the aim's preview is what happens" % kind)
		# The launch's own stars (both of red's bursts) landed in the heat at their drawn sizes.
		var burst_sizes: Dictionary = {}
		for params: int in get_signal_emit_count(run, "pack_burst"):
			for star: Star in get_signal_parameters(run, "pack_burst", params)[2]:
				burst_sizes[star.id] = star.size
		assert_eq(burst_sizes.size(), run.balance.packs[kind].stars * run.balance.packs[kind].bursts)
		for id: int in burst_sizes:
			assert_eq(run.find_star(id).size, burst_sizes[id], "%s: a new star waits for the next launch" % kind)


func test_the_launch_after_ripens_the_stars_the_first_one_brought() -> void:
	var run: RunState = _run(_map(1, false))
	run.owned_packs["blue"] = 2
	run.loaded_pack = "blue"
	assert_true(run.launch(Vector2i(150, 160)))
	var before: Dictionary = {}
	for star: Star in run.stars:
		before[star.id] = star.size
	run.loaded_pack = "blue"
	assert_true(run.launch(Vector2i(20, 230)))
	for id: int in before:
		assert_eq(run.find_star(id).size, mini(before[id] + 1, Star.Size.BIG))


func test_the_heat_draws_nothing_from_the_packs_rng() -> void:
	var with_heat: RunState = _run()
	var without: RunState = RunState.new(Balance.load_file(), Fixtures.rng(7), SKY, StarMap.aquarius_hand())
	without.current = null
	for run: RunState in [with_heat, without]:
		run.owned_packs["blue"] = 3
		run.add_star(Star.Size.SMALL, Vector2i(150, 110))
	var sizes: Array = [[], []]
	for i: int in 3:
		for k: int in 2:
			var run: RunState = [with_heat, without][k]
			run.loaded_pack = "blue"
			watch_signals(run)
			assert_true(run.launch(Vector2i(40, 200)))
			for star: Star in get_signal_parameters(run, "pack_burst")[2]:
				sizes[k].append(star.size)
	assert_eq(sizes[0], sizes[1], "the same packs open with or without the heat")


func test_buying_linking_and_refused_actions_change_no_size() -> void:
	var run: RunState = _run()
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 110))
	var pair: Array[Star] = [run.add_star(Star.Size.MEDIUM, Vector2i(150, 200)), run.add_star(Star.Size.MEDIUM, Vector2i(130, 220)), run.add_star(Star.Size.MEDIUM, Vector2i(160, 230))]
	watch_signals(run)
	assert_eq(run.link([star.id] as Array[int]), Combos.INVALID)
	assert_ne(run.link(Fixtures.ids(pair)), Combos.INVALID)
	run.dust = 20
	assert_true(run.buy("blue"))
	run.loaded_pack = ""
	assert_false(run.launch(Vector2i(90, 160)))
	assert_eq(star.size, Star.Size.SMALL)
	assert_signal_not_emitted(run, "stars_resized")


func test_a_forced_big_bang_clears_the_sky_and_heats_nothing() -> void:
	var run: RunState = _run()
	run.add_star(Star.Size.SMALL, Vector2i(150, 110))
	run.force_next_big_bang = true
	watch_signals(run)
	assert_true(run.launch(Vector2i(130, 160)))
	assert_signal_emitted(run, "big_bang_started")
	assert_signal_not_emitted(run, "stars_resized")


func test_the_loss_check_comes_after_the_burn() -> void:
	var run: RunState = _run()
	run.owned_packs = {"blue": 1, "red": 0}
	run.loaded_pack = "blue"
	run.dust = 0
	for at: Vector2i in [Vector2i(150, 110), Vector2i(160, 140), Vector2i(140, 170)]:
		run.add_star(Star.Size.BIG, at)
	assert_true(run.has_remaining_combo(), "a big triple waits")
	assert_true(run.launch(Vector2i(30, 230)))
	assert_eq(run.stars.size(), 3, "the triple burned out; only the last pack's stars remain")
	assert_eq(run.is_over(), not run.has_remaining_combo(), "lost only if the new stars hold no link")


func test_a_change_knows_whether_the_cold_made_it() -> void:
	assert_false(StarHeat.Change.new(1, Star.Size.SMALL, Star.Size.MEDIUM).is_cold())
	assert_false(StarHeat.Change.new(1, Star.Size.BIG, Star.Size.BIG, true).is_cold(), "a big burned in the heat")
	assert_true(StarHeat.Change.new(1, Star.Size.BIG, Star.Size.MEDIUM).is_cold())
	assert_true(StarHeat.Change.new(1, Star.Size.SMALL, Star.Size.SMALL, true).is_cold(), "a small faded in the cold")


func test_a_heat_that_doesnt_turn_stays_the_heat() -> void:
	var heat := StarHeat.new(1, true)
	heat.turn()
	assert_eq(heat.change, 1)
	var turning := StarHeat.new(1, true, true)
	turning.turn()
	assert_eq(turning.change, -1, "night falls")
	turning.turn()
	assert_eq(turning.change, 1, "and day comes back")


func test_day_and_night_take_turns_launch_by_launch() -> void:
	var map: StarMap = _map(1, true)
	map.heat_turns = true
	var run: RunState = _run(map)
	assert_true(run.heat.turns)
	run.owned_packs["blue"] = 3
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 110))
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
	run.loaded_pack = "blue"
	assert_true(run.launch(Vector2i(30, 230)))
	assert_eq(small.size, Star.Size.MEDIUM, "day: it grew")
	assert_false(run.stars.has(big), "day: the big one burned")
	assert_eq(run.heat.change, -1, "night is next")
	var preview: Array[StarHeat.Change] = run.heat_preview()
	watch_signals(run)
	run.loaded_pack = "blue"
	assert_true(run.launch(Vector2i(30, 120)))
	assert_eq(small.size, Star.Size.SMALL, "night: it shrank back")
	var changes: Array = get_signal_parameters(run, "stars_resized")[0]
	assert_eq(_sizes(changes), _sizes(preview), "the aim's preview shows the night's change")
	for change: StarHeat.Change in changes:
		assert_true(change.is_cold())
	assert_eq(run.heat.change, 1, "day again")


func test_buying_linking_and_refused_launches_dont_turn_day_and_night() -> void:
	var map: StarMap = _map(1, true)
	map.heat_turns = true
	var run: RunState = _run(map)
	var triple: Array[Star] = [run.add_star(Star.Size.MEDIUM, Vector2i(150, 200)), run.add_star(Star.Size.MEDIUM, Vector2i(130, 220)), run.add_star(Star.Size.MEDIUM, Vector2i(160, 230))]
	assert_ne(run.link(Fixtures.ids(triple)), Combos.INVALID)
	run.dust = 20
	assert_true(run.buy("blue"))
	run.loaded_pack = ""
	assert_false(run.launch(Vector2i(90, 160)), "a refused launch")
	assert_eq(run.heat.change, 1)


func test_the_cold_fades_a_small_star_on_launch() -> void:
	var run: RunState = _run(_map(-1, true))
	run.owned_packs["blue"] = 1
	run.loaded_pack = "blue"
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 110))
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
	assert_true(run.launch(Vector2i(30, 230)))
	assert_false(run.stars.has(small), "it faded, for nothing")
	assert_eq(big.size, Star.Size.MEDIUM)
	assert_eq(run.heat.change, -1, "the cold stays the cold")
