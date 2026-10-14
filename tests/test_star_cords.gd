extends GutTest
## Pisces's cords (StarCords): a link's string stays as cord segments, and a step that properly
## crosses one is blocked; touching one is not.


func test_segments_that_cross_in_their_middles_cross() -> void:
	assert_true(StarCords.properly_cross(Vector2i(0, 0), Vector2i(10, 10), Vector2i(0, 10), Vector2i(10, 0)))
	assert_true(StarCords.properly_cross(Vector2i(0, 5), Vector2i(20, 5), Vector2i(7, 0), Vector2i(8, 30)), "a slanted cut")


func test_touching_never_crosses() -> void:
	assert_false(StarCords.properly_cross(Vector2i(0, 0), Vector2i(10, 10), Vector2i(10, 10), Vector2i(20, 0)), "a shared end")
	assert_false(StarCords.properly_cross(Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 0), Vector2i(5, 10)), "an end lying on the other")
	assert_false(StarCords.properly_cross(Vector2i(5, -10), Vector2i(5, 0), Vector2i(0, 0), Vector2i(10, 0)), "ending on it from the other side")
	assert_false(StarCords.properly_cross(Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 0), Vector2i(15, 0)), "collinear overlap")
	assert_false(StarCords.properly_cross(Vector2i(0, 0), Vector2i(10, 0), Vector2i(20, 0), Vector2i(30, 0)), "collinear apart")


func test_parallel_and_distant_segments_never_cross() -> void:
	assert_false(StarCords.properly_cross(Vector2i(0, 0), Vector2i(10, 0), Vector2i(0, 5), Vector2i(10, 5)), "parallel")
	assert_false(StarCords.properly_cross(Vector2i(0, 0), Vector2i(4, 4), Vector2i(10, 0), Vector2i(6, 4)), "their lines meet past both")
	assert_false(StarCords.properly_cross(Vector2i(3, 3), Vector2i(3, 3), Vector2i(0, 0), Vector2i(6, 6)), "a step of no length")


func test_the_crossing_test_is_symmetric() -> void:
	var a := Vector2i(12, 40)
	var b := Vector2i(60, 18)
	var c := Vector2i(30, 10)
	var d := Vector2i(40, 50)
	var crossing: bool = StarCords.properly_cross(a, b, c, d)
	assert_true(crossing)
	assert_eq(StarCords.properly_cross(b, a, c, d), crossing)
	assert_eq(StarCords.properly_cross(c, d, a, b), crossing)
	assert_eq(StarCords.properly_cross(d, c, b, a), crossing)


func test_a_link_ties_its_two_segments_in_pick_order() -> void:
	var cords := StarCords.new()
	assert_true(cords.is_empty())
	var added: Array[Array] = cords.tie([Vector2i(40, 120), Vector2i(80, 120), Vector2i(80, 160)] as Array[Vector2i])
	assert_eq(added, [[Vector2i(40, 120), Vector2i(80, 120)], [Vector2i(80, 120), Vector2i(80, 160)]])
	assert_eq(cords.count(), 2)
	assert_eq(cords.segments(), added)
	assert_false(cords.is_empty())
	cords.tie([Vector2i(10, 10), Vector2i(20, 10), Vector2i(30, 10)] as Array[Vector2i])
	assert_eq(cords.count(), 4, "cords add up")
	assert_eq(cords.segments()[0], added[0], "oldest first")


func test_a_step_can_touch_a_cord_but_not_cross_it() -> void:
	var cords := StarCords.new()
	cords.tie([Vector2i(40, 120), Vector2i(80, 120), Vector2i(120, 120)] as Array[Vector2i])
	assert_true(cords.crosses(Vector2i(60, 100), Vector2i(60, 140)))
	assert_true(cords.crosses(Vector2i(60, 140), Vector2i(60, 100)), "either way")
	assert_false(cords.crosses(Vector2i(80, 100), Vector2i(80, 140)), "through the knot touches it")
	assert_false(cords.crosses(Vector2i(60, 100), Vector2i(60, 120)), "ending on it")
	assert_false(cords.crosses(Vector2i(20, 100), Vector2i(20, 140)), "past its end")
	assert_false(cords.crosses(Vector2i(40, 120), Vector2i(10, 140)), "from its end")


func test_the_crossing_point_is_the_first_one_met() -> void:
	var cords := StarCords.new()
	cords.tie([Vector2i(40, 120), Vector2i(80, 120), Vector2i(120, 120)] as Array[Vector2i])
	cords.tie([Vector2i(40, 140), Vector2i(80, 140), Vector2i(120, 140)] as Array[Vector2i])
	assert_eq(cords.crossing(Vector2i(60, 100), Vector2i(60, 160)), Vector2i(60, 120))
	assert_eq(cords.crossing(Vector2i(60, 160), Vector2i(60, 100)), Vector2i(60, 140), "from the other end")
	assert_eq(cords.crossing(Vector2i(51, 110), Vector2i(54, 130)), Vector2i(53, 120), "rounded to the pixel")
	assert_eq(cords.crossing(Vector2i(20, 100), Vector2i(20, 160)), StarCords.NO_CROSSING)


func test_clear_removes_every_cord() -> void:
	var cords := StarCords.new()
	cords.tie([Vector2i(40, 120), Vector2i(80, 120), Vector2i(120, 120)] as Array[Vector2i])
	cords.clear()
	assert_true(cords.is_empty())
	assert_eq(cords.count(), 0)
	assert_false(cords.crosses(Vector2i(60, 100), Vector2i(60, 140)))
	assert_eq(cords.segments(), [] as Array[Array])


func test_a_repeated_point_ties_no_segment() -> void:
	var cords := StarCords.new()
	var added: Array[Array] = cords.tie([Vector2i(40, 120), Vector2i(40, 120), Vector2i(80, 120)] as Array[Vector2i])
	assert_eq(added.size(), 1)
	assert_eq(cords.count(), 1)


func test_fixed_cords_block_and_survive_a_clear() -> void:
	var cords := StarCords.new()
	var fish: Array[Array] = cords.tie_fixed([Vector2i(0, 100), Vector2i(60, 140), Vector2i(120, 100)] as Array[Vector2i])
	assert_eq(fish, [[Vector2i(0, 100), Vector2i(60, 140)], [Vector2i(60, 140), Vector2i(120, 100)]])
	assert_eq(cords.fixed_count(), 2)
	assert_eq(cords.link_count(), 0)
	assert_false(cords.is_empty(), "the fixed cord is in the sky")
	assert_true(cords.crosses(Vector2i(30, 100), Vector2i(30, 140)), "it blocks like a link's cord")
	assert_false(cords.crosses(Vector2i(60, 140), Vector2i(60, 180)), "touching its knot doesn't")
	cords.tie([Vector2i(10, 200), Vector2i(30, 200), Vector2i(50, 200)] as Array[Vector2i])
	assert_eq(cords.count(), 4)
	assert_eq(cords.link_count(), 2)
	assert_eq(cords.segments().slice(0, 2), fish, "fixed first")
	assert_eq(cords.fixed_segments(), fish)
	assert_eq(cords.link_segments(), [[Vector2i(10, 200), Vector2i(30, 200)], [Vector2i(30, 200), Vector2i(50, 200)]])
	assert_true(cords.is_fixed(0))
	assert_true(cords.is_fixed(1))
	assert_false(cords.is_fixed(2))
	cords.clear()
	assert_eq(cords.count(), 2, "a clear keeps the fixed cord")
	assert_eq(cords.link_count(), 0)
	assert_eq(cords.segments(), fish)
	assert_true(cords.crosses(Vector2i(30, 100), Vector2i(30, 140)))
	assert_false(cords.crosses(Vector2i(20, 190), Vector2i(20, 210)), "the link's cord is gone")


func test_fixed_cords_stay_ahead_of_link_cords_tied_before() -> void:
	var cords := StarCords.new()
	cords.tie([Vector2i(10, 200), Vector2i(30, 200)] as Array[Vector2i])
	cords.tie_fixed([Vector2i(0, 100), Vector2i(60, 140)] as Array[Vector2i])
	assert_eq(cords.segments(), [[Vector2i(0, 100), Vector2i(60, 140)], [Vector2i(10, 200), Vector2i(30, 200)]])
	cords.clear()
	assert_eq(cords.segments(), [[Vector2i(0, 100), Vector2i(60, 140)]])
