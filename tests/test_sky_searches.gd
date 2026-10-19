extends GutTest
## The run's spot searches on a sky that reaches left of x 0 (docs/wide_sky_design.md §2): each
## keeps an explicit "found" flag, so a best spot at a negative x counts as found; and the hole
## intro's search reaches as far as the sky does.

const Fixtures := preload("res://tests/fixtures.gd")
## A 1920x1080 window's play sky (the game's frame centred in 640 columns, 20 rows more above).
const WIDE_SKY := Rect2i(-230, 38, 640, 212)
## Far enough left that every spot in the sky is at a negative x (a multiple of the search grid, so
## the same spots are scanned).
const LEFT := Vector2i(-200, 0)


func test_the_open_launch_spot_left_of_x_0_is_the_same_spot_moved() -> void:
	var home: RunState = Fixtures.run()
	var left := RunState.new(Fixtures.balance(), Fixtures.rng(), Rect2i(Fixtures.SKY.position + LEFT, Fixtures.SKY.size))
	var spot: Vector2i = left.open_launch_spot(left.sky_rect.position.y)
	assert_lt(spot.x, 0)
	assert_eq(spot, home.open_launch_spot(home.sky_rect.position.y) + LEFT, "nearest the sky's centre, not the clearest")


func test_the_safe_launch_spot_left_of_x_0_is_the_same_spot_moved() -> void:
	var home: RunState = _hunted(Fixtures.SKY)
	var left: RunState = _hunted(Rect2i(Fixtures.SKY.position + LEFT, Fixtures.SKY.size))
	assert_false(home.is_safe_launch(home.hunt.centre), "the circle covers the goal: the grid is searched")
	var spot: Vector2i = left.safe_launch_spot()
	assert_lt(spot.x, 0)
	assert_true(left.is_safe_launch(spot))
	assert_eq(spot, home.safe_launch_spot() + LEFT, "the safe spot nearest the goal, not the one furthest from the circle")


func test_the_open_middle_left_of_x_0_is_the_middle() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(), Rect2i(Fixtures.SKY.position + LEFT, Fixtures.SKY.size), StarMap.stinger())
	var inner: Rect2i = StarScatter.inner_rect(run.sky_rect).grow(-StarScatter.RING_MAX)
	var middle: Vector2i = run._open_middle()
	assert_lt(middle.x, 0)
	assert_lte(Vector2(middle).distance_to(Vector2(inner.get_center())), Vector2(RunState.SAFE_SPOT_GRID, RunState.SAFE_SPOT_GRID).length() / 2.0, "the figure is far off: the open spot nearest the middle")


func test_the_ram_intro_finds_its_layout_left_of_x_0() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(7), Rect2i(Fixtures.SKY.position + LEFT, Fixtures.SKY.size), StarMap.aries_horns())
	var layout: Array[Vector2i] = run.ram_intro_layout()
	assert_eq(layout.size(), 3, "a kept star, a lost one and one out of the lane")
	if layout.size() != 3:
		return
	for spot: Vector2i in layout:
		assert_lt(spot.x, 0)
		assert_true(StarScatter.inner_rect(run.sky_rect).has_point(spot))
	assert_true(run.ram.in_lane(layout[0]) and run.ram.in_lane(layout[1]))
	assert_false(run.ram.in_lane(layout[2]))


func test_the_hole_intro_reaches_as_far_as_a_wide_sky() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(), WIDE_SKY, StarMap.black_hole_trial())
	# A hole whose third demo star must stand over 400 px out: one pull swallows from 208 px, two from
	# 408 (well past 2 x 180 columns, inside the wide sky's diagonal).
	run.gravity = StarGravity.new(Vector2i(-200, 150), 8, 80000, 200)
	var spots: Array[Vector2i] = run.hole_intro_spots()
	assert_eq(spots.size(), 3)
	if spots.size() != 3:
		return
	assert_gt(spots[2].distance_to(run.gravity.center), 360.0)
	assert_true(StarScatter.inner_rect(run.sky_rect).has_point(spots[2]))


func test_the_hole_intro_search_stops_at_the_sky() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(), Fixtures.SKY, StarMap.black_hole_trial())
	run.gravity = StarGravity.new(Vector2i(90, 164), 8, 80000, 200)
	assert_eq(run.hole_intro_spots(), [] as Array[Vector2i], "no third spot fits in a 9:16 sky")


func _hunted(sky: Rect2i) -> RunState:
	var run := RunState.new(Fixtures.balance(), Fixtures.rng(), sky)
	run.hunt = Hunt.new(38, run.run_seed)
	run.hunt.mark(sky)
	run.hunt.centre = StarScatter.inner_rect(sky).get_center()
	return run
