extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const FIELD := Rect2i(64, 124, 108, 100)


func _current() -> StarCurrent:
	return StarCurrent.new(FIELD, Vector2i(-24, 0))


func test_preview_is_pure_and_only_moves_stars_inside_the_field() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, Vector2i(120, 160)), Star.new(2, Star.Size.BIG, Vector2i(50, 200))]
	var result: Dictionary[int, Vector2i] = _current().preview(stars, SKY, [])
	assert_eq(result[1], Vector2i(96, 160))
	assert_eq(result[2], stars[1].position)
	assert_eq(stars[0].position, Vector2i(120, 160), "aiming never changes the board")
	assert_eq(_current().preview(stars, SKY, []), result)


func test_blocked_destinations_keep_original_positions() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, Vector2i(120, 160)), Star.new(2, Star.Size.BIG, Vector2i(96, 160))]
	var result: Dictionary[int, Vector2i] = _current().preview(stars, SKY, [Vector2i(72, 160)])
	assert_eq(result[1], stars[0].position, "another star blocks this step")
	assert_eq(result[2], stars[1].position, "fixed landmarks block this step")


func test_upstream_stars_follow_downstream_neighbors_regardless_of_age() -> void:
	for left_id: int in [1, 2]:
		var right_id: int = 3 - left_id
		var stars: Array[Star] = [
			Star.new(left_id, Star.Size.SMALL, Vector2i(100, 160)),
			Star.new(right_id, Star.Size.SMALL, Vector2i(120, 160)),
		]
		var result: Dictionary[int, Vector2i] = _current().preview(stars, SKY, [])
		assert_eq(result[left_id], Vector2i(76, 160))
		assert_eq(result[right_id], Vector2i(96, 160), "creation order must not split a moving cluster")
		stars.reverse()
		assert_eq(_current().preview(stars, SKY, []), result, "array order must not affect the flow either")


func test_order_is_stable_and_targets_stay_inside_safe_bounds() -> void:
	var current := StarCurrent.new(Rect2i(0, 78, 180, 172), Vector2i(-80, 0))
	var stars: Array[Star] = [Star.new(2, Star.Size.SMALL, Vector2i(60, 190)), Star.new(1, Star.Size.BIG, Vector2i(32, 190))]
	var first: Dictionary[int, Vector2i] = current.preview(stars, SKY, [])
	stars.reverse()
	assert_eq(current.preview(stars, SKY, []), first)
	assert_eq(first[1], Vector2i(8, 190))
	assert_eq(first[2], Vector2i(60, 190))


func test_reserved_destination_survives_new_arrival() -> void:
	var star := Star.new(1, Star.Size.SMALL, Vector2i(120, 160))
	var stars: Array[Star] = [star]
	var reserved: Dictionary[int, Vector2i] = _current().preview(stars, SKY, [])
	stars.append(Star.new(2, Star.Size.SMALL, Vector2i(120, 190)))
	var result: Dictionary[int, Vector2i] = _current().preview(stars, SKY, [], reserved)
	assert_eq(result[1], reserved[1])
	assert_eq(result[2], Vector2i(96, 190))


func _run(enabled: bool = true, seed_value: int = 7) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, StarMap.current_trial(enabled))


func test_trial_and_control_have_no_orion_threats() -> void:
	for enabled: bool in [true, false]:
		var run: RunState = _run(enabled)
		assert_null(run.orion)
		assert_null(run.volley)
		assert_null(run.hunt)
		assert_false(run.scorpio.map.boss)
		assert_eq(run.current != null, enabled)
	assert_true(StarMap.tail().orion, "normal Tail still belongs to chapter 1")


func test_invalid_launch_buy_and_invalid_link_do_not_move_stars() -> void:
	var run: RunState = _run()
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(120, 160))
	var before: Vector2i = star.position
	assert_eq(run.link([star.id] as Array[int]), Combos.INVALID)
	run.dust = run.balance.packs["blue"].cost
	assert_true(run.buy("blue"))
	run.loaded_pack = ""
	assert_false(run.launch(Vector2i(90, 160)))
	assert_eq(star.position, before)


func test_launch_executes_exact_existing_preview_without_rewards_or_size_changes() -> void:
	for seed_value: int in range(1, 41):
		var run: RunState = _run(true, seed_value)
		var a: Star = run.add_star(Star.Size.SMALL, Vector2i(118, 132))
		var b: Star = run.add_star(Star.Size.BIG, Vector2i(162, 216))
		var preview: Dictionary[int, Vector2i] = run.current_preview()
		var dust: int = run.dust
		assert_true(run.launch(Vector2i(110, 158)))
		assert_eq(a.position, preview[a.id])
		assert_eq(b.position, preview[b.id])
		assert_eq(a.size, Star.Size.SMALL)
		assert_eq(b.size, Star.Size.BIG)
		assert_eq(run.dust, dust)
		assert_eq(run.light, 0)


func test_same_launch_loses_one_landmark_opportunity_and_gains_another() -> void:
	var run: RunState = _run()
	var saved_a: Star = run.add_star(Star.Size.SMALL, Vector2i(118, 132))
	var saved_b: Star = run.add_star(Star.Size.SMALL, Vector2i(108, 154))
	var stranded_a: Star = run.add_star(Star.Size.BIG, Vector2i(162, 216))
	var stranded_b: Star = run.add_star(Star.Size.BIG, Vector2i(162, 192))
	var saved: Array[int] = [saved_b.id, saved_a.id, run.scorpio.landmark_star(1).id]
	var stranded: Array[int] = [stranded_b.id, stranded_a.id, run.scorpio.landmark_star(4).id]
	assert_ne(run.combo_for(saved), Combos.INVALID)
	assert_eq(run.combo_for(stranded), Combos.INVALID)
	assert_true(run.launch(Vector2i(25, 98)))
	assert_eq(run.combo_for(saved), Combos.INVALID, "launch costs the saved small link")
	assert_ne(run.combo_for(stranded), Combos.INVALID, "the same launch unlocks the stranded big link")


func test_red_split_moves_once_after_both_bursts_with_snapshot_events() -> void:
	var run: RunState = _run()
	var old: Star = run.add_star(Star.Size.SMALL, Vector2i(118, 132))
	var expected: Vector2i = run.current_preview()[old.id]
	var events: Array[String] = []
	var born: Array[Star] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
		events.append("burst")
		born.append_array(stars))
	run.stars_shifted.connect(func(_moves: Array[StarCurrent.Move]) -> void: events.append("shift"))
	assert_true(run.load_pack("red"))
	assert_true(run.launch(Vector2i(100, 175)))
	assert_eq(events, ["burst", "burst", "shift"])
	assert_eq(old.position, expected)
	for star: Star in born:
		assert_ne(star, run.find_star(star.id), "burst is an independent pre-flow snapshot")


func test_current_field_follows_tall_phone_layout() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(), Rect2i(0, 43, 180, 207), StarMap.current_trial())
	assert_eq(run.current.region.position, FIELD.position + run.scorpio.shift)


func test_current_tuning_is_optional_and_validated() -> void:
	assert_eq(Fixtures.balance().current_step, 0)
	var bad: Balance = Balance.from_dict(Fixtures.balance_dict().merged({"currents": {"step": 0}}))
	assert_false(bad.is_valid())


func test_aiming_does_not_advance_pack_or_scatter_rng() -> void:
	var a: RunState = _run()
	var b: RunState = _run()
	a.add_star(Star.Size.SMALL, Vector2i(118, 132))
	b.add_star(Star.Size.SMALL, Vector2i(118, 132))
	for frame: int in 60:
		a.current_preview()
	a.launch(Vector2i(110, 158))
	b.launch(Vector2i(110, 158))
	assert_eq(a.stars.size(), b.stars.size())
	for index: int in a.stars.size():
		assert_eq(a.stars[index].size, b.stars[index].size)
		assert_eq(a.stars[index].position, b.stars[index].position)


func test_new_burst_stars_also_move_and_event_from_positions_match_snapshots() -> void:
	var run: RunState = _run()
	var born: Dictionary[int, Vector2i] = {}
	var moved: Array[StarCurrent.Move] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
		for star: Star in stars:
			born[star.id] = star.position)
	run.stars_shifted.connect(func(moves: Array[StarCurrent.Move]) -> void: moved.append_array(moves))
	run.launch(Vector2i(110, 158))
	assert_gt(moved.size(), 0)
	for move: StarCurrent.Move in moved:
		assert_eq(move.from, born[move.star_id])
		assert_eq(move.to, run.find_star(move.star_id).position)


func test_last_pack_keeps_run_alive_when_a_reachable_combo_remains_after_flow() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))
	data.start_packs = {"blue": 1, "red": 0}
	data.packs.blue.weights = {"small": 1, "medium": 0, "big": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(7), SKY, StarMap.current_trial())
	assert_true(run.launch(Vector2i(110, 158)))
	assert_eq(run.total_packs(), 0)
	assert_eq(run.dust, 0)
	assert_true(run.has_remaining_combo())
	assert_eq(run.outcome, RunState.Outcome.PLAYING)
