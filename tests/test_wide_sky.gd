extends GutTest
## The mechanics on a wide sky (docs/wide_sky_design.md §3): each rule that takes its stakes from an
## edge or an area keeps them on Fixtures.WIDE_SKY, and does exactly what it did on the 9:16 sky.

const Fixtures := preload("res://tests/fixtures.gd")


func _stage(map: StarMap, sky: Rect2i = Fixtures.WIDE_SKY, seed_value: int = 1) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), sky, map)


# --- _stage_area: current regions stretch sideways ---------------------------------------------

func test_a_full_width_region_reaches_the_wide_skys_right_edge() -> void:
	var run: RunState = _stage(StarMap.aquarius_hand())
	assert_eq(run.scorpio.shift, Vector2i(0, -20))
	assert_eq(run.current.region, Rect2i(72, 38, Fixtures.WIDE_SKY.end.x - 72, 212), "from x 72 to the sky's right edge, full height")


func test_the_body_and_legs_flows_run_from_their_drain_to_the_skys_right_edge() -> void:
	for map: StarMap in [StarMap.aquarius_body(), StarMap.aquarius_legs()]:
		var run: RunState = _stage(map)
		assert_eq(run.current.region.position.x, 48, "%s: the drain stays by the figure" % map.id)
		assert_eq(run.current.region.end.x, Fixtures.WIDE_SKY.end.x, map.id)


func test_regions_inside_the_home_sky_stay_where_they_are() -> void:
	var stream: RunState = _stage(StarMap.aquarius_stream())
	assert_eq(stream.current.region, Rect2i(16, 58, 148, 122), "shifted up with the figure, not stretched")
	var jar: RunState = _stage(StarMap.aquarius_jar())
	assert_eq(jar.current.region, Rect2i(24, 38, 132, 212), "full height, not full width")
	var box: RunState = _stage(StarMap.aquarius_final())
	assert_eq(box.current.region, Rect2i(20, 76, 140, 132))


func test_a_region_from_the_home_skys_left_edge_runs_from_the_wide_skys() -> void:
	var run: RunState = _stage(StarMap.aquarius_hand())
	assert_eq(run._stage_area(Rect2i(0, 100, 60, 40)), Rect2i(Fixtures.WIDE_SKY.position.x, 80, 290, 40))
	assert_eq(run._stage_area(Rect2i(0, 78, 180, 172)), Fixtures.WIDE_SKY, "the whole home sky is the whole sky")


func test_on_the_portrait_sky_the_regions_are_as_laid_out() -> void:
	assert_eq(_stage(StarMap.aquarius_hand(), Fixtures.SKY).current.region, StarMap.aquarius_hand().current_region)
	assert_eq(_stage(StarMap.aquarius_body(), Fixtures.SKY).current.region, StarMap.aquarius_body().current_region)
	var run: RunState = _stage(StarMap.aquarius_hand(), Fixtures.SKY)
	assert_eq(run._stage_area(Rect2i(0, 100, 60, 40)), Rect2i(0, 100, 60, 40))
