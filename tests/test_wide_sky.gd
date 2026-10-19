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


# --- Orion's corner is the frame's --------------------------------------------------------------

func _figure(corner: Vector2i, grow: int) -> Rect2i:
	return Rect2i(corner + Volley.ORION_CORNER.position, Volley.ORION_CORNER.size).grow(grow)


func test_the_hunt_may_circle_a_star_in_the_wide_skys_corner() -> void:
	var frame: Vector2i = Vector2i(0, Fixtures.WIDE_SKY.position.y)
	var prey := Star.new(1, Star.Size.SMALL, Fixtures.WIDE_SKY.position + Vector2i(15, 15))
	for seed_value: int in range(1, 11):
		var hunt := Hunt.new(38, seed_value)
		var centre: Vector2i = hunt.mark(Fixtures.WIDE_SKY, frame, [prey] as Array[Star])
		assert_lte((centre - prey.position).length(), 38.0, "Orion doesn't stand there: the circle goes round it")


func test_the_hunt_keeps_off_orion_in_the_frames_corner() -> void:
	var frame: Vector2i = Vector2i(0, Fixtures.WIDE_SKY.position.y)
	var hugging := Star.new(1, Star.Size.SMALL, frame + Vector2i(20, 22))
	for seed_value: int in range(1, 11):
		var hunt := Hunt.new(38, seed_value)
		var centre: Vector2i = hunt.mark(Fixtures.WIDE_SKY, frame, [hugging] as Array[Star])
		assert_false(_figure(frame, 38).has_point(centre), "never over his figure")


func test_a_wide_hunt_marks_off_the_frames_corner() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(2), Fixtures.WIDE_SKY, StarMap.heart())
	var marks: Array[Vector2i] = []
	run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: marks.append(at))
	for i: int in 4:
		if run.is_over():
			break
		if run.loaded_pack == "":
			for kind: String in run.owned_packs:
				if run.load_pack(kind):
					break
		if run.loaded_pack == "":
			break
		run.launch(run.figure_middle())
	assert_false(marks.is_empty())
	for at: Vector2i in marks:
		assert_false(_figure(run.frame_rect.position, run.hunt.radius).has_point(at), "%s off Orion" % at)


func test_the_volley_intro_keeps_off_the_frames_corner() -> void:
	var frame: Vector2i = Vector2i(0, Fixtures.WIDE_SKY.position.y)
	var inner: Rect2i = StarScatter.inner_rect(Rect2i(frame, Vector2i(180, Fixtures.WIDE_SKY.size.y)))
	for seed_value: int in range(1, 21):
		var volley := Volley.new(3, 0.5, seed_value)
		for spot: Vector2i in volley.intro_spots(inner, frame):
			assert_false(_figure(frame, Volley.INTRO_CLEAR).has_point(spot), "%s clear of his figure" % spot)


# --- Intros and guide spots play by the figure -------------------------------------------------

## Every map with an intro that commit 8 limits to the frame (the splash, wave and ram intros follow
## their own edge rules; the hole's stands round the hole).
const INTRO_MAPS: Array[String] = [
	"body", "heart", "claws", "final",
	"aquarius_hand", "aquarius_body", "aquarius_stream", "aquarius_jar", "aquarius_final",
	"leo_tail", "leo_haunch", "leo_heart", "leo_mane", "leo_head",
	"virgo_head", "virgo_wing", "virgo_robe", "virgo_feet", "virgo_wheat",
	"sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs", "sagittarius_head",
	"pisces_circlet", "pisces_west_cord",
]


func test_the_intros_place_their_demo_stars_inside_the_frame() -> void:
	for map_id: String in INTRO_MAPS:
		for seed_value: int in range(1, 6):
			_check_intros_in_frame(map_id, seed_value)


func _check_intros_in_frame(map_id: String, seed_value: int) -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), Fixtures.WIDE_SKY, StarMap.by_id(map_id))
	var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
	var seen: Array[Vector2i] = []
	var record: Callable = func(placed: Array[Star]) -> void:
		for star: Star in placed:
			seen.append(star.position)
	for name: StringName in [&"volley_intro_placed", &"hunt_intro_placed", &"heat_intro_placed", &"harvest_intro_placed", &"current_intro_placed", &"gauge_intro_placed"]:
		run.connect(name, record)
	run.hunt_intro_burst.connect(func(_at: Vector2i, placed: Array[Star]) -> void: record.call(placed))
	run.play_volley_intro()
	run.play_hunt_intro()
	run.play_heat_intro()
	run.play_harvest_intro()
	run.play_current_intro()
	run.play_gauge_intro()
	if run.splash == null and run.wave == null:
		run.play_reflect_intro()
	for at: Vector2i in seen:
		assert_true(inner.has_point(at), "%s: demo star at %s inside the frame %s" % [map_id, at, inner])


func test_the_hunt_intros_circle_stands_in_the_frame() -> void:
	for seed_value: int in range(1, 11):
		var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), Fixtures.WIDE_SKY, StarMap.heart())
		var circles: Array[Vector2i] = []
		run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: circles.append(at))
		run.play_hunt_intro()
		assert_eq(circles.size(), 1)
		for at: Vector2i in circles:
			assert_true(run.frame_rect.grow(-run.hunt.radius).has_point(at), "%s wholly inside the frame" % at)


func test_the_guide_spots_and_open_middle_stay_in_the_frame() -> void:
	for map_id: String in ["tail", "heart", "leo_mane", "virgo_wheat", "pisces_circlet"]:
		var run := RunState.new(Balance.load_file(), Fixtures.rng(6), Fixtures.WIDE_SKY, StarMap.by_id(map_id))
		var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
		assert_true(inner.has_point(run.open_launch_spot(run.sky_rect.position.y)), "%s: the guided launch by the figure" % map_id)
		assert_true(inner.has_point(run.safe_launch_spot()), map_id)
		assert_true(inner.has_point(run._open_middle()), map_id)


func test_a_hunted_wide_runs_safe_spot_is_in_the_frame() -> void:
	var run := RunState.new(Fixtures.balance(), Fixtures.rng(), Fixtures.WIDE_SKY)
	run.hunt = Hunt.new(38, run.run_seed)
	run.hunt.mark(run.sky_rect, run.frame_rect.position)
	run.hunt.centre = run.figure_middle()
	var spot: Vector2i = run.safe_launch_spot()
	assert_true(run.is_safe_launch(spot))
	assert_true(StarScatter.inner_rect(run.frame_rect).has_point(spot), "%s: the frame is scanned, not the 640 columns" % spot)


# --- The frame edge drains (Q4) -----------------------------------------------------------------

func _launch_once(run: RunState) -> void:
	if run.loaded_pack == "":
		for kind: String in run.owned_packs:
			if run.load_pack(kind):
				break
	assert_true(run.launch(run.figure_middle()), "the launch goes")


func test_on_a_drain_stage_a_star_outside_the_frame_drains_at_the_next_step() -> void:
	var run: RunState = _stage(StarMap.aquarius_body())
	var flowing: Star = run.add_star(Star.Size.BIG, Vector2i(300, 150))
	var still: Star = run.add_star(Star.Size.SMALL, Vector2i(-100, 150))
	var kept: Star = run.add_star(Star.Size.MEDIUM, Vector2i(150, 230))
	assert_true(run.current.region.has_point(flowing.position), "in the stretched flow, right of the frame")
	assert_false(run.current.region.has_point(still.position), "in the still strip left of the frame")
	var drains: Array[int] = run.launch_drains()
	assert_true(drains.has(flowing.id) and drains.has(still.id), "both marked before the launch")
	assert_false(drains.has(kept.id), "a star in the frame, a step from the drain, stays")
	var drained: Array[int] = []
	run.stars_shifted.connect(func(moves: Array[StarCurrent.Move]) -> void:
		for move: StarCurrent.Move in moves:
			if move.drained:
				drained.append(move.star_id))
	_launch_once(run)
	assert_true(drained.has(flowing.id) and drained.has(still.id))
	assert_null(run.find_star(flowing.id))
	assert_null(run.find_star(still.id))
	assert_not_null(run.find_star(kept.id))


func test_a_burst_outside_the_frame_shows_as_draining() -> void:
	var run: RunState = _stage(StarMap.aquarius_body())
	assert_true(run.burst_drains_at(Vector2i(-100, 150)), "the aim's ring marks it red")
	assert_true(run.burst_drains_at(Vector2i(300, 150)))
	assert_false(run.burst_drains_at(Vector2i(120, 150)), "inside the frame only the drain itself counts")


func test_a_stranded_star_leaves_outward() -> void:
	var run: RunState = _stage(StarMap.aquarius_stream())
	var left: Star = run.add_star(Star.Size.SMALL, Vector2i(-50, 120))
	var right: Star = run.add_star(Star.Size.SMALL, Vector2i(250, 120))
	var preview: Dictionary[int, Vector2i] = run.current_preview()
	assert_lt(preview[left.id].x, left.position.x, "out to the left")
	assert_gt(preview[right.id].x, right.position.x, "out to the right")
	assert_true(run.current.leaves(left.position, preview[left.id]))


func test_a_flow_without_a_drain_keeps_the_outer_columns() -> void:
	var run: RunState = _stage(StarMap.aquarius_hand())
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(300, 150))
	assert_false(run.current.stranded(star.position))
	assert_true(run.launch_drains().is_empty())
	_launch_once(run)
	assert_not_null(run.find_star(star.id), "the Hand has no drain: it only drifts")
	assert_lt(run.find_star(star.id).position.x, 300)


func test_a_flow_carrying_a_star_past_its_frames_side_drains_it() -> void:
	var flow := StarCurrent.new(Rect2i(0, 0, 200, 50), Vector2i(24, 0), true)
	flow.frame = Rect2i(0, 0, 100, 50)
	var star := Star.new(1, Star.Size.SMALL, Vector2i(90, 20))
	var to: Dictionary[int, Vector2i] = flow.preview([star] as Array[Star], Rect2i(-50, 0, 300, 50), [] as Array[Vector2i])
	assert_eq(to[1], Vector2i(114, 20))
	assert_true(flow.leaves(star.position, to[1]), "out past the frame's side: lost")
	var moves: Array[StarCurrent.Move] = flow.moves([star] as Array[Star], to)
	assert_true(moves[0].drained)


func test_on_the_portrait_sky_no_star_is_stranded() -> void:
	for map: StarMap in [StarMap.aquarius_body(), StarMap.aquarius_jar(), StarMap.aquarius_final()]:
		var run: RunState = _stage(map, Fixtures.SKY)
		assert_eq(run.current.frame, Fixtures.SKY)
		var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
		for at: Vector2i in [inner.position, inner.end - Vector2i.ONE, inner.get_center()]:
			assert_false(run.current.stranded(at), "%s %s" % [map.id, at])
