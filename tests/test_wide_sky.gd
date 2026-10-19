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


# --- The splash loses stars at the frame's edge -------------------------------------------------

func test_a_splash_pushing_a_star_past_the_frames_side_loses_it() -> void:
	var run: RunState = _stage(StarMap.pisces_knot())
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(14, 100))
	var kept: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 100))
	var moves: Array[StarCurrent.Move] = []
	run.stars_splashed.connect(func(_at: Vector2i, moved: Array[StarCurrent.Move]) -> void: moves.assign(moved))
	run._splash(Vector2i(32, 100))
	assert_null(run.find_star(star.id), "pushed to x -4: past the frame, though the sky goes on")
	assert_not_null(run.find_star(kept.id), "pushed on, inside the frame")
	assert_eq(moves.size(), 2)
	for move: StarCurrent.Move in moves:
		assert_eq(move.drained, move.star_id == star.id)


func test_a_splash_in_the_outer_columns_loses_what_it_pushes_outward() -> void:
	var run: RunState = _stage(StarMap.pisces_knot())
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(-100, 100))
	run._splash(Vector2i(-90, 100))
	assert_null(run.find_star(star.id), "pushed to x -118: still over the sky, but out of the frame")


func test_the_aims_splash_preview_marks_the_frames_losses() -> void:
	var run: RunState = _stage(StarMap.pisces_knot())
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(14, 100))
	assert_true(run.launch_splashes(Vector2i(32, 100)).has(star.id), "the aim's preview loses it too")


func test_on_the_portrait_sky_the_splash_loses_at_the_skys_edge() -> void:
	var run: RunState = _stage(StarMap.pisces_knot(), Fixtures.SKY)
	assert_eq(run.frame_rect, run.sky_rect)
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(14, 120))
	run._splash(Vector2i(32, 120))
	assert_null(run.find_star(star.id), "as before: out of the sky")


func test_the_splash_intro_throws_by_the_frames_edge() -> void:
	var run: RunState = _stage(StarMap.pisces_knot())
	var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
	assert_eq(run.splash_intro_spot().x, inner.position.x + RunState.SPLASH_INTRO_IN, "measured from the frame, not the sky")
	var placed: Array[Star] = []
	var lost: Array[int] = []
	run.splash_intro_placed.connect(func(shown: Array[Star]) -> void: placed.assign(shown))
	run.stars_splashed.connect(func(_at: Vector2i, moved: Array[StarCurrent.Move]) -> void:
		for move: StarCurrent.Move in moved:
			if move.drained:
				lost.append(move.star_id))
	run.play_reflect_intro()
	assert_eq(placed.size(), 3)
	for star: Star in placed:
		assert_true(inner.has_point(star.position), "demo star %s by the figure" % star.position)
	assert_eq(lost.size(), 1, "the splash pushes the edge one out of the frame")


# --- The black hole's pull: d_eff = min(d, reach) -----------------------------------------------

const HOLE_MAPS: Array[String] = ["black_hole_trial", "sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs", "sagittarius_head", "sagittarius_final"]


func _hole_run(map_id: String, sky: Rect2i = Fixtures.WIDE_SKY) -> RunState:
	var map: StarMap = StarMap.by_id(map_id) if map_id != "black_hole_trial" else StarMap.black_hole_trial()
	return RunState.new(Balance.load_file(), Fixtures.rng(1), sky, map)


func _uncapped(hole: StarGravity, point: Vector2i) -> int:
	var free: StarGravity = hole.copy()
	free.frame = Rect2i()
	return free.step_at(point)


func test_a_star_out_past_the_frame_falls_at_the_frame_edges_rate() -> void:
	var run: RunState = _hole_run("sagittarius_arrow")
	var hole: StarGravity = run.gravity
	assert_eq(hole.frame, run.frame_rect)
	var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
	var far: float = hole.reach(hole.center)
	assert_gt(far, 0.0)
	var out := Vector2i(Fixtures.WIDE_SKY.position.x + 10, hole.center.y)
	assert_false(inner.has_point(out))
	assert_eq(hole.step_at(out), clampi(roundi(hole.pull / far), 1, hole.max_step), "reckoned at the reach")
	assert_gt(hole.step_at(out), _uncapped(hole, out), "faster than its own distance would give")


func test_inside_the_frame_the_pull_is_unchanged() -> void:
	var run: RunState = _hole_run("sagittarius_bow")
	var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
	for x: int in range(inner.position.x, inner.end.x, 9):
		for y: int in range(inner.position.y, inner.end.y, 9):
			var at := Vector2i(x, y)
			assert_eq(run.gravity.step_at(at), _uncapped(run.gravity, at), "%s" % at)


func test_on_the_portrait_sky_no_star_is_past_the_reach() -> void:
	for sky: Rect2i in [Fixtures.SKY, ScreenZones.play_sky(102)]:
		for map_id: String in HOLE_MAPS:
			var run: RunState = _hole_run(map_id, sky)
			var inner: Rect2i = StarScatter.inner_rect(sky)
			for hole: Vector2i in run.gravity.centers:
				for corner: Vector2i in [inner.position, Vector2i(inner.end.x - 1, inner.position.y), Vector2i(inner.position.x, inner.end.y - 1), inner.end - Vector2i.ONE]:
					assert_lte(Vector2(hole).distance_to(Vector2(corner)), run.gravity.reach(hole) + 0.001, "%s %s" % [map_id, sky])
				assert_eq(run.gravity.step_at(inner.position), _uncapped(run.gravity, inner.position))


func test_the_reach_follows_drifting_twins() -> void:
	var run: RunState = _hole_run("sagittarius_legs")
	var hole: StarGravity = run.gravity
	assert_true(hole.has_twins())
	var before: float = hole.reach(hole.centers[0])
	hole.drift_holes()
	assert_ne(hole.reach(hole.centers[0]), before, "reckoned from where the hole is now")
	assert_eq(hole.copy().frame, hole.frame, "an intro's copy keeps the frame")


func test_pulls_to_swallow_counts_with_the_reach() -> void:
	var run: RunState = _hole_run("sagittarius_arrow")
	var hole: StarGravity = run.gravity
	var far: int = ceili(hole.reach(hole.center)) + 120
	assert_lt(hole.pulls_to_swallow(far, 40), _free_pulls(hole, far), "a far star comes in at the reach's rate")


func _free_pulls(hole: StarGravity, distance: int) -> int:
	var free: StarGravity = hole.copy()
	free.frame = Rect2i()
	return free.pulls_to_swallow(distance, 40)


# --- The ram charges against the frame ---------------------------------------------------------

func _ram_run(sky: Rect2i = Fixtures.WIDE_SKY) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(1), sky, StarMap.aries_horns())


func test_the_ram_butts_a_star_out_past_the_frames_far_side() -> void:
	var run: RunState = _ram_run()
	var row: int = run.ram.row
	var near: Star = run.add_star(Star.Size.SMALL, Vector2i(150, row))
	var ahead: Star = run.add_star(Star.Size.SMALL, Vector2i(250, row))
	var behind: Star = run.add_star(Star.Size.SMALL, Vector2i(-100, row))
	var preview: StarCharge.Charge = run.charge_preview()
	assert_true(preview.lost().has(near.id), "butted to x 222: past the frame, though the sky goes on")
	assert_true(preview.lost().has(ahead.id), "in its way, out past the frame")
	assert_false(preview.destinations().has(behind.id), "behind the ram: out of its way")
	run._charge_ram()
	assert_null(run.find_star(near.id))
	assert_null(run.find_star(ahead.id))
	assert_eq(run.find_star(behind.id).position, Vector2i(-100, row), "stays where it stood")


func test_a_star_the_ram_keeps_in_the_frame_is_butted_on() -> void:
	var run: RunState = _ram_run()
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(20, run.ram.row))
	var preview: StarCharge.Charge = run.charge_preview()
	assert_false(preview.lost().has(star.id))
	assert_gt(preview.destinations()[star.id].x, 20 + run.ram.butt - 1)


func test_a_ram_charging_down_or_from_the_right_keeps_off_whats_behind_it() -> void:
	var frame := Rect2i(0, 38, 180, 212)
	var left := StarCharge.new(1, 36, 72, 100, [Vector2i.LEFT] as Array[Vector2i])
	assert_true(left.behind(Vector2i(200, 100), frame))
	assert_false(left.behind(Vector2i(-20, 100), frame), "ahead of a ram from the right")
	var down := StarCharge.new(1, 36, 72, 100, [Vector2i.DOWN] as Array[Vector2i], 90)
	assert_false(down.behind(Vector2i(90, 40), frame))


func test_on_the_portrait_sky_the_ram_loses_at_the_skys_edge() -> void:
	var run: RunState = _ram_run(Fixtures.SKY)
	assert_eq(run.frame_rect, run.sky_rect)
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(150, run.ram.row))
	assert_true(run.charge_preview().lost().has(star.id), "as before")


func test_the_ram_intro_plays_inside_the_frame() -> void:
	for map: StarMap in [StarMap.aries_horns(), StarMap.aries_head(), StarMap.aries_fleece()]:
		var run := RunState.new(Balance.load_file(), Fixtures.rng(2), Fixtures.WIDE_SKY, map)
		var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
		var placed: Array[Vector2i] = []
		var lost: Array[int] = []
		run.ram_intro_placed.connect(func(shown: Array[Star]) -> void:
			for star: Star in shown:
				placed.append(star.position))
		run.ram_charged.connect(func(_line: int, moves: Array[StarCurrent.Move], _way: Vector2i) -> void:
			for move: StarCurrent.Move in moves:
				if move.drained:
					lost.append(move.star_id)
					assert_false(inner.has_point(move.to), "%s: lost past the frame" % map.id))
		run.play_ram_intro()
		assert_false(placed.is_empty(), map.id)
		assert_false(lost.is_empty(), "%s: the demo butts one out" % map.id)
		for at: Vector2i in placed:
			assert_true(inner.has_point(at), "%s: demo star %s by the figure" % [map.id, at])


# --- The fish's cord ends run to the sky's sides ------------------------------------------------

func _cord_run(fish: Array[Vector2i], sky: Rect2i = Fixtures.WIDE_SKY) -> RunState:
	var map: StarMap = StarMap.cord_trial()
	map.fish_cord = fish
	return RunState.new(Balance.load_file(), Fixtures.rng(1), sky, map)


func test_a_cord_end_on_the_home_skys_side_runs_on_to_the_wide_skys() -> void:
	var run: RunState = _cord_run(StarMap.cord_trial().fish_cord)
	var points: Array[Array] = run.cords.fixed_segments()
	assert_eq(points[0][0], Vector2i(166, 58), "an end on the home sky's top stays, shifted (as on a tall phone)")
	assert_eq(points[0][1], Vector2i(56, 166))
	assert_eq(points[-1][1], Vector2i(Fixtures.WIDE_SKY.end.x - 1, 246), "on along its arm from (179, 194) to the right side")
	assert_true(run.cords.crosses(Vector2i(300, 200), Vector2i(300, 250)), "it splits the outer columns too")


func test_an_arm_reaching_the_top_first_stops_there() -> void:
	var fish: Array[Vector2i] = [Vector2i(0, 100), Vector2i(90, 140), Vector2i(179, 100)]
	var run: RunState = _cord_run(fish)
	var segments: Array[Array] = run.cords.fixed_segments()
	for end: Vector2i in [segments[0][0], segments[-1][1]]:
		assert_eq(end.y, Fixtures.WIDE_SKY.position.y, "%s: the arm climbs 42 px over 95 columns, so it meets the top" % end)
		assert_true(Fixtures.WIDE_SKY.has_point(end))
	assert_eq(segments[0][0].x, -94, "on the arm's line: from (90, 120) through (0, 80), 42 px up to y 38 (94.5 columns on)")
	assert_eq(segments[-1][1].x, 179 + 93, "from (90, 120) through (179, 80): 93.45 columns on")


func test_on_the_portrait_sky_the_cord_ends_stay() -> void:
	for sky: Rect2i in [Fixtures.SKY, ScreenZones.play_sky(102)]:
		var run: RunState = _cord_run(StarMap.cord_trial().fish_cord, sky)
		var expected: Array[Vector2i] = []
		for point: Vector2i in StarMap.cord_trial().fish_cord:
			expected.append(point + run.scorpio.shift)
		var segments: Array[Array] = run.cords.fixed_segments()
		assert_eq(segments[0][0], expected[0])
		assert_eq(segments[-1][1], expected[-1], "%s" % sky)
