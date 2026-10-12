extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const HOLE := Vector2i(90, 164)


## Pull 600: a star 100 px out falls 6 px, 50 px out 12 px, 30 px out the 20 px cap.
func _hole() -> StarGravity:
	return StarGravity.new(HOLE, 8, 600, 20)


func test_the_fall_grows_as_a_star_nears_the_hole() -> void:
	var hole: StarGravity = _hole()
	assert_eq(hole.step_at(HOLE + Vector2i(100, 0)), 6)
	assert_eq(hole.step_at(HOLE + Vector2i(50, 0)), 12)
	assert_eq(hole.step_at(HOLE + Vector2i(0, 25)), 20, "capped at max_step")
	assert_eq(hole.step_at(HOLE + Vector2i(-2000, 0)), 1, "always at least a pixel")
	assert_eq(hole.step_at(HOLE), 0)


func test_preview_is_pure_and_falls_straight_toward_the_hole() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, HOLE + Vector2i(60, 0)), Star.new(2, Star.Size.BIG, HOLE + Vector2i(0, -50))]
	var result: Dictionary[int, Vector2i] = _hole().preview(stars, SKY, [])
	assert_eq(result[1], HOLE + Vector2i(50, 0))
	assert_eq(result[2], HOLE + Vector2i(0, -38))
	assert_eq(stars[0].position, HOLE + Vector2i(60, 0), "aiming never changes the board")
	assert_eq(_hole().preview(stars, SKY, []), result)


func test_a_star_reaching_the_horizon_is_swallowed() -> void:
	var hole: StarGravity = _hole()
	var near := Star.new(1, Star.Size.MEDIUM, HOLE + Vector2i(26, 0))
	var safe := Star.new(2, Star.Size.MEDIUM, HOLE + Vector2i(0, 40))
	assert_true(hole.swallows_at(near.position), "26 px out falls the 20 px cap, inside the 8 px horizon")
	assert_false(hole.swallows_at(safe.position))
	var stars: Array[Star] = [near, safe]
	var destinations: Dictionary[int, Vector2i] = hole.preview(stars, SKY, [])
	assert_eq(destinations[1], HOLE)
	var falls: Array[StarGravity.Fall] = hole.falls(stars, destinations)
	assert_eq(falls.size(), 2)
	for fall: StarGravity.Fall in falls:
		assert_eq(fall.swallowed, fall.star_id == 1)


func test_a_star_on_the_hole_itself_is_swallowed() -> void:
	var hole: StarGravity = _hole()
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, HOLE)]
	var falls: Array[StarGravity.Fall] = hole.falls(stars, hole.preview(stars, SKY, []))
	assert_eq(falls.size(), 1)
	assert_true(falls[0].swallowed)


func test_landmarks_never_fall_and_block_like_stars() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, HOLE + Vector2i(60, 0))]
	var landmark: Vector2i = HOLE + Vector2i(50, 0)
	var result: Dictionary[int, Vector2i] = _hole().preview(stars, SKY, [landmark])
	assert_ne(result[1], landmark)
	assert_true(result[1].distance_to(landmark) >= StarScatter.LANDMARK_SPACING, "flows round it, never onto it")
	assert_lt(result[1].distance_to(HOLE), 60.0, "still falls closer")


func test_a_star_with_no_room_stays_put_and_never_climbs_out() -> void:
	var landmarks: Array[Vector2i] = []
	for x: int in range(100, 152, 6):
		for y: int in range(130, 200, 6):
			landmarks.append(Vector2i(x, y))
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, HOLE + Vector2i(60, 0))]
	assert_eq(_hole().preview(stars, SKY, landmarks)[1], HOLE + Vector2i(60, 0), "never squeezed in")


func test_inner_stars_fall_first_so_the_ones_behind_follow() -> void:
	for inner_id: int in [1, 2]:
		var outer_id: int = 3 - inner_id
		var stars: Array[Star] = [Star.new(outer_id, Star.Size.SMALL, HOLE + Vector2i(80, 0)), Star.new(inner_id, Star.Size.SMALL, HOLE + Vector2i(60, 0))]
		var result: Dictionary[int, Vector2i] = _hole().preview(stars, SKY, [])
		assert_eq(result[inner_id], HOLE + Vector2i(50, 0))
		assert_eq(result[outer_id], HOLE + Vector2i(72, 0), "creation order must not hold up the star behind")
		stars.reverse()
		assert_eq(_hole().preview(stars, SKY, []), result, "array order must not matter either")


func test_a_swallowed_star_frees_its_spot() -> void:
	var stars: Array[Star] = [Star.new(1, Star.Size.SMALL, HOLE + Vector2i(20, 0)), Star.new(2, Star.Size.SMALL, HOLE + Vector2i(36, 0))]
	var result: Dictionary[int, Vector2i] = _hole().preview(stars, SKY, [])
	assert_eq(result[1], HOLE)
	assert_eq(result[2], HOLE + Vector2i(19, 0), "falls its full 17 px into the freed space, short of the horizon")


func test_reserved_destination_survives_a_new_arrival() -> void:
	var star := Star.new(1, Star.Size.SMALL, HOLE + Vector2i(60, 0))
	var stars: Array[Star] = [star]
	var reserved: Dictionary[int, Vector2i] = _hole().preview(stars, SKY, [])
	stars.append(Star.new(2, Star.Size.SMALL, HOLE + Vector2i(54, 4)))
	var result: Dictionary[int, Vector2i] = _hole().preview(stars, SKY, [], reserved)
	assert_eq(result[1], reserved[1])
	assert_true(result[2].distance_to(result[1]) >= StarScatter.MIN_SPACING, "the newcomer flows round the reserved spot")
	assert_lt(result[2].distance_to(HOLE), stars[1].position.distance_to(HOLE), "and still falls")


func _run(enabled: bool = true, seed_value: int = 7) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, StarMap.black_hole_trial(enabled))


func test_trial_and_control_have_no_other_rules() -> void:
	for enabled: bool in [true, false]:
		var run: RunState = _run(enabled)
		assert_null(run.orion)
		assert_null(run.volley)
		assert_null(run.hunt)
		assert_null(run.current)
		assert_null(run.heat)
		assert_null(run.harvest)
		assert_eq(run.gravity != null, enabled)


func test_tuning_is_optional_and_validated() -> void:
	assert_eq(Fixtures.balance().black_hole_pull, 0)
	var bad: Balance = Balance.from_dict(Fixtures.balance_dict().merged({"black_hole": {"pull": 0, "max_step": 20, "horizon": 8}}))
	assert_false(bad.is_valid())
	var no_hole: Balance = Fixtures.balance()
	var run := RunState.new(no_hole, Fixtures.rng(), SKY, StarMap.black_hole_trial())
	assert_null(run.gravity, "a map's hole needs the balance block")


func test_launch_executes_the_preview_and_swallows_for_nothing() -> void:
	for seed_value: int in range(1, 41):
		var run: RunState = _run(true, seed_value)
		var hole: Vector2i = run.gravity.center
		var doomed: Star = run.add_star(Star.Size.SMALL, hole + Vector2i(0, 22))
		var far: Star = run.add_star(Star.Size.BIG, Vector2i(14, 90))
		var preview: Dictionary[int, Vector2i] = run.gravity_preview()
		assert_eq(run.launch_swallows(), [doomed.id] as Array[int])
		var dust: int = run.dust
		var light: int = run.light
		assert_true(run.launch(Vector2i(20, 240)))
		assert_null(run.find_star(doomed.id), "swallowed")
		assert_eq(far.position, preview[far.id])
		assert_eq(far.size, Star.Size.BIG)
		assert_eq(run.light, light)
		assert_eq(run.dust, dust)


func test_invalid_actions_do_not_move_stars() -> void:
	var run: RunState = _run()
	var star: Star = run.add_star(Star.Size.SMALL, run.gravity.center + Vector2i(50, 0))
	var before: Vector2i = star.position
	assert_eq(run.link([star.id] as Array[int]), Combos.INVALID)
	run.dust = run.balance.packs["blue"].cost
	assert_true(run.buy("blue"))
	run.loaded_pack = ""
	assert_false(run.launch(Vector2i(20, 100)))
	assert_eq(star.position, before)


func test_burst_stars_fall_too_from_their_landing_spots() -> void:
	var run: RunState = _run()
	var born: Dictionary[int, Vector2i] = {}
	var fell: Array[StarGravity.Fall] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
		for star: Star in stars:
			born[star.id] = star.position)
	run.stars_fell.connect(func(falls: Array[StarGravity.Fall]) -> void: fell.append_array(falls))
	run.launch(Vector2i(30, 110))
	assert_eq(fell.size(), born.size(), "every new star falls")
	for fall: StarGravity.Fall in fell:
		assert_eq(fall.from, born[fall.star_id], "the burst event is a pre-fall snapshot")
		if not fall.swallowed:
			assert_eq(fall.to, run.find_star(fall.star_id).position)


func test_burst_swallowed_at_answers_for_a_landing_star() -> void:
	var run: RunState = _run()
	var hole: Vector2i = run.gravity.center
	assert_true(run.burst_swallowed_at(hole + Vector2i(14, 0)))
	assert_false(run.burst_swallowed_at(Vector2i(14, 90)))
	assert_false(_run(false).burst_swallowed_at(hole))


func test_a_big_bang_clears_the_sky_without_a_fall() -> void:
	var run: RunState = _run()
	run.add_star(Star.Size.SMALL, run.gravity.center + Vector2i(40, 0))
	var fell: Array = []
	run.stars_fell.connect(func(falls: Array[StarGravity.Fall]) -> void: fell.append(falls))
	run.force_next_big_bang = true
	assert_true(run.launch(Vector2i(30, 110)))
	assert_eq(fell.size(), 0)


func test_aiming_does_not_advance_pack_or_scatter_rng() -> void:
	var a: RunState = _run()
	var b: RunState = _run()
	a.add_star(Star.Size.SMALL, Vector2i(30, 100))
	b.add_star(Star.Size.SMALL, Vector2i(30, 100))
	for frame: int in 60:
		a.gravity_preview()
		a.launch_swallows()
		a.burst_swallowed_at(Vector2i(80, 160))
	a.launch(Vector2i(30, 110))
	b.launch(Vector2i(30, 110))
	assert_eq(a.stars.size(), b.stars.size())
	for index: int in a.stars.size():
		assert_eq(a.stars[index].size, b.stars[index].size)
		assert_eq(a.stars[index].position, b.stars[index].position)


func test_hole_follows_a_tall_phone_layout() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(), Rect2i(0, 43, 180, 207), StarMap.black_hole_trial())
	assert_eq(run.gravity.center, StarMap.black_hole_trial().black_hole_center + run.scorpio.shift)


func test_the_loss_check_counts_combos_left_after_the_fall() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))
	data.start_packs = {"blue": 1, "red": 0}
	data.packs.blue.weights = {"small": 1, "medium": 0, "big": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(7), SKY, StarMap.black_hole_trial())
	assert_true(run.launch(Vector2i(20, 96)))
	assert_eq(run.total_packs(), 0)
	assert_eq(run.outcome == RunState.Outcome.LOST, not run.has_remaining_combo())
