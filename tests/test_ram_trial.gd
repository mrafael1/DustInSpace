extends GutTest
## Aries's ram in a run (the RAM debug trial): its map, its clock, the lane following the landmark a
## link lit, the charge after a launch, its previews, and the trial off replaying the same seed.

const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
## Well above the lane (the start row, 170): the burst's stars land clear of it.
const HIGH_AIM := Vector2i(90, 100)


func _balance_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))


func _run(map: StarMap = StarMap.ram_trial(), seed_value: int = 7, balance: Balance = Balance.load_file()) -> RunState:
	var run := RunState.new(balance, Fixtures.rng(seed_value), SKY, map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 0
	run.loaded_pack = "blue"
	return run


## Launches high, away from the lane, until the ram is one launch from charging.
func _to_the_charge(run: RunState) -> void:
	while not run.ram.charges_next():
		Fixtures.launch(run, HIGH_AIM)


func _landmark(run: RunState, index: int) -> Vector2i:
	return run.scorpio.landmark_position(index)


func test_the_trial_map_has_the_ram_and_off_has_none() -> void:
	var map: StarMap = StarMap.ram_trial()
	assert_eq(map.id, "ram_trial")
	assert_true(map.ram)
	assert_false(map.intros)
	assert_false(map.orion or map.hunt or map.harvest or map.black_hole or map.cords or map.splash or map.wave, "no other threat")
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	assert_eq(StarMap.current_layout("ram").id, "ram_trial")
	assert_eq(StarMap.current_layout("ram", false).id, "ram_off")
	assert_eq(StarMap.by_id("ram_trial").id, "ram_trial")
	assert_eq(StarMap.by_id("ram_off").id, "ram_off")
	var off: StarMap = StarMap.ram_trial(false)
	assert_false(off.ram)
	assert_eq(off.landmarks, map.landmarks, "the same layout")
	assert_null(_run(off).ram)
	var balance: Balance = Balance.load_file()
	assert_eq([balance.ram_every, balance.ram_lane, balance.ram_butt], [2, 20, 48])
	var ram: StarCharge = _run().ram
	assert_not_null(ram)
	assert_eq([ram.every, ram.lane, ram.butt], [2, 20, 48])


func test_the_chain_holds_the_next_landmark_in_the_lit_ones_lane() -> void:
	var map: StarMap = StarMap.ram_trial()
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
	for i: int in 3:
		var lane := StarCharge.new(2, 20, 48, map.landmarks[i].y)
		assert_true(lane.in_lane(map.landmarks[i + 1]), "landmark %d is in %d's lane" % [i + 1, i])
		assert_gt(map.landmarks[i + 1].x, map.landmarks[i].x, "running right, the way the ram charges")


func test_no_ram_block_means_no_ram() -> void:
	var data: Dictionary = _balance_data()
	data.erase("ram")
	var balance: Balance = Balance.from_dict(data)
	assert_true(balance.is_valid(), str(balance.errors))
	assert_eq(balance.ram_every, 0)
	assert_null(_run(StarMap.ram_trial(), 7, balance).ram)


func test_the_lane_starts_on_the_first_lit_landmark_else_the_middle() -> void:
	var run: RunState = _run()
	assert_eq(run.ram.row, _landmark(run, 0).y)
	var unlit: StarMap = StarMap.ram_trial()
	unlit.starting_lit = []
	assert_eq(_run(unlit).ram.row, SKY.get_center().y, "none lit: the sky's middle")


func test_the_ram_charges_after_every_second_launch() -> void:
	var run: RunState = _run()
	var charged_after: Array[int] = []
	var launches: Array[int] = [0]
	run.pack_launched.connect(func(_kind: String, _at: Vector2i) -> void: launches[0] += 1)
	run.ram_charged.connect(func(_row: int, _moves: Array[StarCurrent.Move], _fleeced: Array[int]) -> void: charged_after.append(launches[0]))
	var announced: Array[bool] = []
	for i: int in 6:
		announced.append(run.ram_charges_next())
		Fixtures.launch(run, HIGH_AIM)
	assert_eq(charged_after, [2, 4, 6] as Array[int], "sent every charge, even when nothing moves")
	assert_eq(announced, [false, true, false, true, false, true] as Array[bool])


func test_intros_dont_count_toward_the_charge() -> void:
	var map: StarMap = StarMap.pisces_north_fish()
	map.ram = true
	var run := RunState.new(Balance.load_file(), Fixtures.rng(3), SKY, map)
	var intro_launched: Array[bool] = [false]
	run.hunt_intro_launched.connect(func(_kind: String, _at: Vector2i) -> void: intro_launched[0] = true)
	run.play_reflect_intro()
	assert_true(intro_launched[0], "the wave's intro threw its demo planet")
	assert_eq(run.ram.launches, 0)
	assert_false(run.ram_charges_next())


## Two small stars either side of landmark `index` (a small one), to link through it.
func _small_pair(run: RunState, index: int) -> Array[Star]:
	var at: Vector2i = _landmark(run, index)
	return [run.add_star(Star.Size.SMALL, at + Vector2i(-14, 26)), run.add_star(Star.Size.SMALL, at + Vector2i(14, 26))]


func test_a_link_moves_the_lane_to_the_landmark_it_lit() -> void:
	var run: RunState = _run()
	var aimed: Array[int] = []
	run.ram_aimed.connect(func(row: int) -> void: aimed.append(row))
	var pair: Array[Star] = _small_pair(run, 1)
	var ids: Array[int] = [pair[0].id, Scorpio.landmark_id(1), pair[1].id]
	assert_eq(run.ram_row_for(ids), _landmark(run, 1).y, "the trace previews the row")
	assert_eq(run.ram.row, _landmark(run, 0).y, "a trace alone (or one cancelled) never moves it")
	assert_eq(run.link(ids), "small_triple")
	assert_eq(run.ram.row, _landmark(run, 1).y)
	assert_eq(aimed, [_landmark(run, 1).y] as Array[int])


func test_a_link_lighting_no_landmark_leaves_the_lane() -> void:
	var run: RunState = _run()
	var row: int = run.ram.row
	var ids: Array[int] = []
	for x: int in [40, 60, 80]:
		ids.append(run.add_star(Star.Size.SMALL, Vector2i(x, 220)).id)
	assert_eq(run.ram_row_for(ids), row)
	assert_eq(run.link(ids), "small_triple")
	assert_eq(run.ram.row, row)


func test_an_invalid_link_never_moves_the_lane() -> void:
	var run: RunState = _run()
	var aimed: Array[int] = []
	run.ram_aimed.connect(func(row: int) -> void: aimed.append(row))
	var at: Vector2i = _landmark(run, 1)
	var small: Star = run.add_star(Star.Size.SMALL, at + Vector2i(-14, 26))
	var medium: Star = run.add_star(Star.Size.MEDIUM, at + Vector2i(14, 26))
	var ids: Array[int] = [small.id, Scorpio.landmark_id(1), medium.id]
	assert_eq(run.ram_row_for(ids), _landmark(run, 0).y, "an invalid trace previews no move")
	assert_eq(run.link(ids), Combos.INVALID)
	assert_eq(run.ram.row, _landmark(run, 0).y)
	assert_true(aimed.is_empty())


func test_a_link_that_rekindles_aims_at_the_last_landmark_lit() -> void:
	var run: RunState = _run()
	run.light = run.light_target() - 1
	var pair: Array[Star] = _small_pair(run, 1)
	var ids: Array[int] = [pair[0].id, Scorpio.landmark_id(1), pair[1].id]
	var rekindled: int = 2
	assert_eq(run.ram_row_for(ids), _landmark(run, rekindled).y, "the rekindle lights the next one, last")
	run.link(ids)
	assert_true(run.scorpio.is_lit(rekindled))
	assert_eq(run.ram.row, _landmark(run, rekindled).y)


func test_the_charge_butts_the_lane_after_the_launch() -> void:
	var run: RunState = _run()
	var row: int = run.ram.row
	var sheltered: Star = run.add_star(Star.Size.SMALL, Vector2i(44, row + 4))
	var off: Star = run.add_star(Star.Size.MEDIUM, Vector2i(150, row + 5))
	var outside: Star = run.add_star(Star.Size.BIG, Vector2i(44, row + 12))
	_to_the_charge(run)
	var seen: Array = []
	run.ram_charged.connect(func(at: int, moves: Array[StarCurrent.Move], fleeced: Array[int]) -> void: seen.append([at, moves, fleeced]))
	var dust: int = run.dust
	Fixtures.launch(run, HIGH_AIM)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], row)
	var landmark: Vector2i = _landmark(run, 1)
	assert_gt(sheltered.position.x, 44, "butted")
	assert_lt(sheltered.position.x, landmark.x, "stopped short of the next landmark")
	assert_gte(sheltered.position.distance_squared_to(landmark), StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING)
	assert_eq(seen[0][2], [sheltered.id] as Array[int])
	assert_true(run.ram.is_fleeced(sheltered.id))
	assert_null(run.find_star(off.id), "butted out of the sky")
	assert_eq(run.dust, dust, "lost for nothing")
	assert_eq(outside.position, Vector2i(44, row + 12), "out of the lane, untouched")


func test_a_star_with_nothing_ahead_is_butted_48_px() -> void:
	var run: RunState = _run()
	# A lane below the figure, with no landmark in it.
	run.ram.aim(220)
	var free: Star = run.add_star(Star.Size.SMALL, Vector2i(40, 215))
	_to_the_charge(run)
	Fixtures.launch(run, HIGH_AIM)
	assert_eq(free.position, Vector2i(88, 215))
	assert_false(run.ram.is_fleeced(free.id))


func test_the_preview_matches_the_charge() -> void:
	var run: RunState = _run()
	var row: int = run.ram.row
	for point: Vector2i in [Vector2i(44, row + 4), Vector2i(76, row - 9), Vector2i(100, row + 8), Vector2i(150, row + 5)]:
		run.add_star(Star.Size.SMALL, point)
	assert_true(run.charge_preview().moves.is_empty(), "no charge with the first launch")
	Fixtures.launch(run, HIGH_AIM)
	var preview: StarCharge.Charge = run.charge_preview()
	assert_eq(preview.moves.size(), 4)
	assert_eq(preview.lost().size(), 1)
	assert_eq(preview.fleeced.size(), 3, "each stopped by the next landmark in the lane")
	var executed: Array = []
	run.ram_charged.connect(func(_row: int, moves: Array[StarCurrent.Move], fleeced: Array[int]) -> void: executed.append_array([moves, fleeced]))
	Fixtures.launch(run, HIGH_AIM)
	var moves: Array[StarCurrent.Move] = executed[0]
	assert_eq(moves.size(), preview.moves.size(), "the launch's stars landed clear of the lane")
	for i: int in moves.size():
		assert_eq([moves[i].star_id, moves[i].from, moves[i].to, moves[i].drained], [preview.moves[i].star_id, preview.moves[i].from, preview.moves[i].to, preview.moves[i].drained])
	assert_eq(executed[1], preview.fleeced)


func test_a_big_bang_launch_leaves_the_charge_nothing() -> void:
	var run: RunState = _run()
	run.add_star(Star.Size.SMALL, Vector2i(80, run.ram.row))
	_to_the_charge(run)
	var seen: Array = []
	run.ram_charged.connect(func(_row: int, moves: Array[StarCurrent.Move], fleeced: Array[int]) -> void: seen.append([moves.size(), fleeced.size()]))
	run.force_next_big_bang = true
	Fixtures.launch(run, HIGH_AIM)
	assert_true(run.stars.is_empty(), "the Big Bang cleared the sky")
	assert_eq(seen, [[0, 0]], "the charge still comes, moving nothing")
	assert_eq(run.ram.launches, 2, "the Big Bang launch counts")


func test_the_charge_draws_no_random_numbers() -> void:
	var on: RunState = _run(StarMap.ram_trial(), 11)
	var off: RunState = _run(StarMap.ram_trial(false), 11)
	for run: RunState in [on, off]:
		for x: int in [40, 80, 120, 150]:
			run.add_star(Star.Size.SMALL, Vector2i(x, 170))
	var preview_state: int = on._rng.state
	on.charge_preview()
	on.ram_row_for([1, 2, 3])
	assert_eq(on._rng.state, preview_state, "previews draw nothing")
	for i: int in 4:
		Fixtures.launch(on, HIGH_AIM)
		Fixtures.launch(off, HIGH_AIM)
	assert_eq(on._rng.state, off._rng.state, "the run's stream is where it would be without the ram")


func _born_sizes(run: RunState, launches: int, aim: Vector2i) -> Array:
	var sizes: Array = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, born: Array[Star]) -> void:
		for star: Star in born:
			sizes.append(star.size))
	for i: int in launches:
		Fixtures.launch(run, aim)
	return sizes


func test_the_trial_off_replays_the_run_without_the_ram() -> void:
	var data: Dictionary = _balance_data()
	data.erase("ram")
	var baseline: RunState = _run(StarMap.ram_trial(), 5, Balance.from_dict(data))
	var off: RunState = _run(StarMap.ram_trial(false), 5)
	var on: RunState = _run(StarMap.ram_trial(), 5)
	assert_null(baseline.ram)
	var aim := Vector2i(90, 170)
	var baseline_sizes: Array = _born_sizes(baseline, 6, aim)
	assert_eq(_born_sizes(off, 6, aim), baseline_sizes)
	assert_eq(_born_sizes(on, 6, aim), baseline_sizes, "the ram changes where stars go, never what the packs hold")
	assert_eq(off.stars.size(), baseline.stars.size())
	for i: int in off.stars.size():
		assert_eq([off.stars[i].id, off.stars[i].size, off.stars[i].position], [baseline.stars[i].id, baseline.stars[i].size, baseline.stars[i].position])


func test_a_charge_that_takes_the_last_combo_loses_the_run() -> void:
	var data: Dictionary = _balance_data()
	data["packs"]["blue"]["stars"] = 1
	data["packs"]["blue"]["weights"] = {"small": 0, "medium": 0, "big": 1}
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	var balance: Balance = Balance.from_dict(data)
	assert_true(balance.is_valid(), str(balance.errors))
	var run: RunState = _run(StarMap.ram_trial(), 7, balance)
	run.dust = 0
	run.owned_packs["blue"] = 1
	run.ram.launches = 1
	var row: int = run.ram.row
	for point: Vector2i in [Vector2i(134, row + 8), Vector2i(150, row + 8), Vector2i(166, row)]:
		run.add_star(Star.Size.SMALL, point)
	assert_true(run.has_remaining_combo(), "a small triple waits in the lane")
	assert_eq(run.charge_preview().lost().size(), 3, "the charge takes all three")
	var events: Array[String] = []
	run.ram_charged.connect(func(_row: int, _moves: Array[StarCurrent.Move], _fleeced: Array[int]) -> void: events.append("charged"))
	run.run_lost.connect(func() -> void: events.append("lost"))
	run.launch(HIGH_AIM)
	assert_eq(run.outcome, RunState.Outcome.LOST)
	assert_eq(events, ["charged", "lost"] as Array[String], "the loss check runs after the charge")


func test_a_fleeced_star_is_forgotten_once_linked() -> void:
	var run: RunState = _run()
	var ids: Array[int] = []
	for x: int in [40, 60, 80]:
		ids.append(run.add_star(Star.Size.SMALL, Vector2i(x, 220)).id)
	run.ram.fleece([ids[1]])
	run.link(ids)
	assert_true(run.ram.fleeced.is_empty())


func test_a_fleeced_star_is_forgotten_once_lost() -> void:
	var run: RunState = _run()
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(150, run.ram.row))
	run.ram.fleece([star.id])
	_to_the_charge(run)
	Fixtures.launch(run, HIGH_AIM)
	assert_null(run.find_star(star.id))
	assert_false(run.ram.is_fleeced(star.id))


func test_a_fleeced_star_stays_fleeced_while_it_stands() -> void:
	var run: RunState = _run()
	var row: int = run.ram.row
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(44, row + 4))
	_to_the_charge(run)
	Fixtures.launch(run, HIGH_AIM)
	assert_true(run.ram.is_fleeced(star.id))
	Fixtures.launch(run, HIGH_AIM)
	Fixtures.launch(run, HIGH_AIM)
	assert_true(run.ram.is_fleeced(star.id), "charged again, stopped again, still fleeced")
