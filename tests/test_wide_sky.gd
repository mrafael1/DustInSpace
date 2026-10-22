extends GutTest
## The mechanics on a wide sky (docs/wide_sky_design.md §3): each rule that takes its stakes from an
## edge or an area keeps them on Fixtures.WIDE_SKY, and does exactly what it did on the 9:16 sky.

const Fixtures := preload("res://tests/fixtures.gd")


func _stage(map: StarMap, sky: Rect2i = Fixtures.WIDE_SKY, seed_value: int = 1) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), sky, map)


# --- The phone box (§9): edge-stake stages play in the 9:16 sky round the figure --------------

## Every stage whose mechanic takes or excludes stars at an edge (hunt, drain, splash, ram).
const BOX_MAPS: Array[String] = [
	"heart", "claws", "final",
	"aquarius_body", "aquarius_legs", "aquarius_stream", "aquarius_jar", "aquarius_final",
	"pisces_knot", "pisces_east_cord", "pisces_north_fish", "pisces_final",
	"aries_horns", "aries_head", "aries_fleece", "ram_trial",
]
## Stages with no edge stake: they keep the full wide sky.
const FULL_SKY_MAPS: Array[String] = [
	"tail", "body", "aquarius_hand",
	"leo_tail", "leo_haunch", "leo_heart", "leo_mane", "leo_head",
	"virgo_head", "virgo_wing", "virgo_robe", "virgo_feet", "virgo_wheat",
	"sagittarius_arrow", "sagittarius_bow", "sagittarius_body", "sagittarius_legs", "sagittarius_head",
	"pisces_circlet", "pisces_west_cord",
]


func test_the_phone_box_is_the_9x16_sky_round_the_figure() -> void:
	assert_eq(RunState.phone_box(Fixtures.WIDE_SKY), Rect2i(0, 58, 180, 172), "1080p: 20 rows shaded above and below")
	assert_eq(RunState.phone_box(ScreenZones.play_sky(80, 230)), Rect2i(0, 38, 180, 172), "Steam Deck: 40 above and below")
	assert_eq(RunState.phone_box(ScreenZones.play_sky(64, 166)), Rect2i(0, 46, 180, 172), "iPad landscape: 32")
	for sky: Rect2i in [Fixtures.SKY, ScreenZones.play_sky(102), ScreenZones.play_sky(40)]:
		assert_eq(RunState.phone_box(sky), sky, "a 180-wide sky is its own box: %s" % sky)


func test_edge_stake_stages_take_the_phone_box_as_their_frame() -> void:
	for map_id: String in BOX_MAPS:
		var run: RunState = _stage(StarMap.by_id(map_id))
		assert_true(run.plays_in_box(), map_id)
		assert_eq(run.frame_rect, RunState.phone_box(Fixtures.WIDE_SKY), map_id)
		if run.current != null:
			assert_eq(run.current.frame, run.frame_rect, "%s: the drain keeps to the box" % map_id)
	for map_id: String in FULL_SKY_MAPS:
		var run: RunState = _stage(StarMap.by_id(map_id))
		assert_false(run.plays_in_box(), map_id)
		assert_eq(run.frame_rect, Rect2i(0, 38, 180, 212), "%s: the full-height frame, as built" % map_id)


func test_on_every_180_wide_sky_the_frame_is_the_sky() -> void:
	for sky: Rect2i in [Fixtures.SKY, ScreenZones.play_sky(102), ScreenZones.play_sky(40)]:
		for map_id: String in BOX_MAPS + FULL_SKY_MAPS:
			assert_eq(_stage(StarMap.by_id(map_id), sky).frame_rect, sky, "%s on %s" % [map_id, sky])


func test_a_drain_loses_a_star_above_or_below_the_box() -> void:
	var run: RunState = _stage(StarMap.aquarius_jar())
	var above: Star = run.add_star(Star.Size.SMALL, Vector2i(90, 45))
	var below: Star = run.add_star(Star.Size.SMALL, Vector2i(90, 240))
	var kept: Star = run.add_star(Star.Size.SMALL, Vector2i(90, 150))
	assert_true(run.current.stranded(above.position), "in the shade above the box")
	assert_true(run.current.stranded(below.position), "in the shade below the box")
	assert_false(run.current.stranded(kept.position))
	var drains: Array[int] = run.launch_drains()
	assert_true(drains.has(above.id) and drains.has(below.id))
	assert_false(drains.has(kept.id))


func test_a_flow_carrying_a_star_down_past_the_box_drains_it() -> void:
	var box: Rect2i = RunState.phone_box(Fixtures.WIDE_SKY)
	var flow := StarCurrent.new(Rect2i(0, 38, 180, 212), Vector2i(0, 24), true)
	flow.frame = box
	var star := Star.new(1, Star.Size.SMALL, Vector2i(90, box.end.y - 6))
	var to: Dictionary[int, Vector2i] = flow.preview([star] as Array[Star], Fixtures.WIDE_SKY, [] as Array[Vector2i])
	assert_true(Fixtures.WIDE_SKY.has_point(to[1]), "still over the sky")
	assert_true(flow.leaves(star.position, to[1]), "past the box's bottom row: lost")


func test_a_splash_pushing_a_star_past_the_box_rows_loses_it() -> void:
	var run: RunState = _stage(StarMap.pisces_knot())
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 70))
	var kept: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 120))
	run._splash(Vector2i(60, 90))
	assert_null(run.find_star(star.id), "pushed above y 58: over the wide sky, past the box's rows")
	assert_not_null(run.find_star(kept.id), "pushed down, still in the box")


func test_the_down_ram_loses_a_star_past_the_box_bottom_and_leaves_one_above_it() -> void:
	var run: RunState = _stage(StarMap.aries_fleece())
	run.ram.turn()
	assert_true(run.ram.is_down(), "the Fleece's second ram charges down")
	var column: int = run.ram.column
	var near: Star = run.add_star(Star.Size.SMALL, Vector2i(column, run.frame_rect.end.y - 10))
	var above: Star = run.add_star(Star.Size.SMALL, Vector2i(column, run.frame_rect.position.y - 10))
	var preview: StarCharge.Charge = run.charge_preview()
	assert_true(preview.lost().has(near.id), "butted past the box's bottom row, though the sky goes on")
	assert_false(preview.destinations().has(above.id), "above the box: behind the ram, out of its way")


func test_the_hunt_never_circles_a_star_above_or_below_the_box() -> void:
	var box: Rect2i = RunState.phone_box(Fixtures.WIDE_SKY)
	var above := Star.new(1, Star.Size.SMALL, Vector2i(90, box.position.y - 6))
	var below := Star.new(2, Star.Size.SMALL, Vector2i(90, box.end.y + 6))
	for seed_value: int in range(1, 21):
		var run: RunState = _stage(StarMap.heart(), Fixtures.WIDE_SKY, seed_value)
		var centre: Vector2i = run.hunt.mark(run.frame_rect, [above, below] as Array[Star])
		assert_true(box.grow(-run.hunt.radius).has_point(centre), "seed %d: %s wholly inside the box" % [seed_value, centre])
		assert_false(run.hunt.contains(above.position), "seed %d: never prey above the box" % seed_value)
		assert_false(run.hunt.contains(below.position), "seed %d: never prey below the box" % seed_value)


# --- Launches burst, split and scatter in the phone box -----------------------------------------

## One stage per box mechanic: hunt, drain, splash (with the seam's reflection), ram.
const BOX_MECHANIC_MAPS: Array[String] = ["heart", "aquarius_final", "pisces_knot", "aries_head"]
## A trace entry that is a flag, not a position (never shifted).
const TRACE_FLAG := -99999


func _load_any(run: RunState) -> bool:
	if run.loaded_pack == "":
		for kind: String in run.owned_packs:
			if run.load_pack(kind):
				break
	return run.loaded_pack != ""


func test_box_stages_launch_in_the_box_and_others_in_the_sky() -> void:
	for map_id: String in BOX_MAPS:
		var run: RunState = _stage(StarMap.by_id(map_id))
		assert_eq(run.launch_rect(), run.frame_rect, map_id)
	for map_id: String in ["tail", "aquarius_hand", "pisces_circlet", "leo_mane"]:
		assert_eq(_stage(StarMap.by_id(map_id)).launch_rect(), Fixtures.WIDE_SKY, "%s: the whole wide sky, as before" % map_id)
	for sky: Rect2i in [Fixtures.SKY, ScreenZones.play_sky(102)]:
		for map_id: String in ["heart", "aquarius_body", "pisces_knot", "aries_horns", "tail"]:
			assert_eq(_stage(StarMap.by_id(map_id), sky).launch_rect(), sky, "%s on a phone: the sky" % map_id)


func test_throws_into_the_shade_burst_and_scatter_in_the_box() -> void:
	# Into the side sky, the top and bottom strips, the corners, and on the box's own edge.
	var aims: Array[Vector2i] = [Vector2i(-200, 150), Vector2i(380, 150), Vector2i(90, 40), Vector2i(90, 249),
		Vector2i(-230, 38), Vector2i(409, 249), Vector2i(0, 58), Vector2i(179, 229)]
	var box: Rect2i = RunState.phone_box(Fixtures.WIDE_SKY)
	var inner: Rect2i = StarScatter.inner_rect(box)
	for map_id: String in BOX_MECHANIC_MAPS:
		for seed_value: int in range(1, 11):
			var run: RunState = _stage(StarMap.by_id(map_id), Fixtures.WIDE_SKY, seed_value)
			var born: Array[Vector2i] = []
			var twins: Array[Vector2i] = []
			run.pack_burst.connect(func(_kind: String, _at: Vector2i, placed: Array[Star]) -> void:
				for star: Star in placed:
					born.append(star.position))
			run.pack_split.connect(func(_kind: String, _at: Vector2i, points: Array[Vector2i]) -> void: twins.append_array(points))
			for i: int in aims.size():
				if run.is_over():
					break
				if i % 3 == 0 and run.loaded_pack == "":
					run.owned_packs["red"] = run.owned_packs.get("red", 0) + 1
					run.load_pack("red")
				if not _load_any(run):
					break
				assert_true(inner.has_point(run.burst_centre(aims[i])), "%s: %s bursts in the box" % [map_id, aims[i]])
				run.launch(aims[i])
			assert_false(born.is_empty(), map_id)
			assert_false(twins.is_empty(), "%s: a red was thrown" % map_id)
			for at: Vector2i in born:
				assert_true(box.has_point(at), "%s seed %d: star at %s in the box" % [map_id, seed_value, at])
			for at: Vector2i in twins:
				assert_true(inner.has_point(at), "%s seed %d: twin at %s in the box" % [map_id, seed_value, at])


func test_a_red_by_the_boxs_corner_splits_inside_it_as_by_a_phones() -> void:
	var run: RunState = _stage(StarMap.aquarius_final())
	var box: Rect2i = run.frame_rect
	var shift: Vector2i = Scorpio.shift_in(Fixtures.WIDE_SKY)
	var phone: RunState = _stage(StarMap.aquarius_final(), Fixtures.SKY)
	for corner: Vector2i in [box.position, box.end - Vector2i.ONE, Vector2i(box.position.x, box.end.y - 1), Vector2i(box.end.x - 1, box.position.y)]:
		var points: Array[Vector2i] = run.splash_points("red", corner)
		var home: Array[Vector2i] = phone.splash_points("red", corner - shift)
		assert_eq(points.size(), 2)
		for i: int in points.size():
			assert_true(StarScatter.inner_rect(box).has_point(points[i]), "%s: twin %s in the box" % [corner, points[i]])
			assert_eq(points[i] - shift, home[i], "%s: as on the phone, moved by the shift" % corner)


func test_the_circlets_red_still_splits_across_the_frames_side() -> void:
	var red: Balance.PackDef = Balance.load_file().packs["red"]
	var circlet: RunState = _stage(StarMap.pisces_circlet())
	var aim := Vector2i(10, 120)
	var expected: Array[Vector2i] = StarScatter.split_points(circlet.burst_centre(aim), red.burst_spread, red.bursts, Fixtures.WIDE_SKY)
	assert_eq(circlet.splash_points("red", aim), expected, "no splash: split in the whole sky, as before")
	assert_true(expected.any(func(p: Vector2i) -> bool: return not circlet.frame_rect.has_point(p)), "a twin across the frame's side")


func test_a_wide_box_run_plays_as_the_9x16_run_moved_by_the_shift() -> void:
	var shift: Vector2i = Scorpio.shift_in(Fixtures.WIDE_SKY)
	for map_id: String in ["heart", "final", "aquarius_body", "aquarius_final", "pisces_north_fish", "pisces_final", "aries_head"]:
		for seed_value: int in range(1, 6):
			var home: Array[Vector2i] = _box_trace(map_id, Fixtures.SKY, seed_value)
			var wide: Array[Vector2i] = _box_trace(map_id, Fixtures.WIDE_SKY, seed_value)
			assert_gt(home.size(), 10, "%s seed %d: the trace saw the run" % [map_id, seed_value])
			assert_eq(wide.size(), home.size(), "%s seed %d" % [map_id, seed_value])
			for i: int in mini(wide.size(), home.size()):
				if home[i].y == TRACE_FLAG:
					assert_eq(wide[i], home[i], "%s seed %d: event %d" % [map_id, seed_value, i])
				else:
					assert_eq(wide[i] - shift, home[i], "%s seed %d: event %d" % [map_id, seed_value, i])


## Every positional event of a few launches (some aimed out past the 9:16 edge), in order: circles,
## splits, bursts, flows, splashes and charges; each move's start, whether it is lost (a flag entry),
## and its end unless it is lost.
func _box_trace(map_id: String, sky: Rect2i, seed_value: int) -> Array[Vector2i]:
	var run := _stage(StarMap.by_id(map_id), sky, seed_value)
	var shift: Vector2i = Scorpio.shift_in(sky)
	var trace: Array[Vector2i] = []
	var record_moves: Callable = func(moves: Array[StarCurrent.Move]) -> void:
		for move: StarCurrent.Move in moves:
			trace.append(move.from)
			trace.append(Vector2i(1 if move.drained else 0, TRACE_FLAG))
			if not move.drained:
				trace.append(move.to)
	run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: trace.append(at))
	run.pack_split.connect(func(_kind: String, _at: Vector2i, points: Array[Vector2i]) -> void: trace.append_array(points))
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, placed: Array[Star]) -> void:
		for star: Star in placed:
			trace.append(star.position))
	run.stars_shifted.connect(record_moves)
	run.stars_splashed.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		trace.append(at)
		record_moves.call(moves))
	run.ram_charged.connect(func(_row: int, moves: Array[StarCurrent.Move], _way: Vector2i) -> void: record_moves.call(moves))
	# Home-layout aims moved by the sky's shift: some into the figure, some past the 9:16 edge.
	var aims: Array[Vector2i] = [Vector2i(90, 140), Vector2i(-40, 100), Vector2i(220, 200), Vector2i(60, 60), Vector2i(130, 300)]
	for i: int in 10:
		if run.is_over():
			break
		var links: Array[Array] = run.valid_links()
		if not links.is_empty() and i % 2 == 1:
			var ids: Array[int] = []
			ids.assign(links[0])
			run.link(ids)
			continue
		if not _load_any(run):
			break
		var index: int = run.rekindle_target()
		var aim: Vector2i = aims[i % aims.size()] + shift
		if i % 4 == 0 and index >= 0:
			aim = run.scorpio.landmark_position(index)
		run.launch(aim)
	return trace


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


func _wide_frame() -> Rect2i:
	return RunState.new(Fixtures.balance(), Fixtures.rng(), Fixtures.WIDE_SKY).frame_rect


func test_the_hunt_passes_over_a_star_in_the_wide_skys_corner() -> void:
	var frame: Rect2i = _wide_frame()
	var prey := Star.new(1, Star.Size.SMALL, Fixtures.WIDE_SKY.position + Vector2i(15, 15))
	for seed_value: int in range(1, 11):
		var hunt := Hunt.new(38, seed_value)
		var centre: Vector2i = hunt.mark(frame, [prey] as Array[Star])
		assert_true(frame.grow(-38).has_point(centre), "%s: the circle stays in the frame" % centre)
		assert_false(hunt.contains(prey.position), "outside the frame, so never under its circle")


func test_the_hunt_keeps_off_orion_in_the_frames_corner() -> void:
	var frame: Rect2i = _wide_frame()
	var hugging := Star.new(1, Star.Size.SMALL, frame.position + Vector2i(20, 22))
	for seed_value: int in range(1, 11):
		var hunt := Hunt.new(38, seed_value)
		var centre: Vector2i = hunt.mark(frame, [hugging] as Array[Star])
		assert_false(_figure(frame.position, 38).has_point(centre), "never over his figure")


func test_the_hunting_circle_stays_within_the_frame_across_seeds() -> void:
	var frame: Rect2i = _wide_frame()
	for seed_value: int in range(1, 201):
		var hunt := Hunt.new(38, seed_value)
		var layout := Fixtures.rng(seed_value)
		var loose: Array[Star] = []
		for i: int in layout.randi_range(0, 12):
			var at := Vector2i(layout.randi_range(Fixtures.WIDE_SKY.position.x, Fixtures.WIDE_SKY.end.x - 1),
				layout.randi_range(Fixtures.WIDE_SKY.position.y, Fixtures.WIDE_SKY.end.y - 1))
			loose.append(Star.new(i + 1, Star.Size.SMALL, at))
		var centre: Vector2i = hunt.mark(frame, loose)
		assert_true(frame.grow(-38).has_point(centre), "seed %d: %s wholly inside the frame %s" % [seed_value, centre, frame])


func test_a_wide_heart_runs_circles_all_stand_in_the_frame() -> void:
	for seed_value: int in range(1, 21):
		var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), Fixtures.WIDE_SKY, StarMap.heart())
		var circles: Array[Vector2i] = []
		run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: circles.append(at))
		for i: int in 8:
			if run.is_over():
				break
			if run.loaded_pack == "":
				for kind: String in run.owned_packs:
					if run.load_pack(kind):
						break
			if run.loaded_pack == "":
				break
			# Launch out in the outer columns, so loose stars lie outside the frame.
			var side: int = Fixtures.WIDE_SKY.position.x + 40 if i % 2 == 0 else Fixtures.WIDE_SKY.end.x - 40
			run.launch(Vector2i(side, run.figure_middle().y))
		assert_false(circles.is_empty())
		for at: Vector2i in circles:
			assert_true(run.frame_rect.grow(-run.hunt.radius).has_point(at), "seed %d: %s wholly inside the frame" % [seed_value, at])


func test_on_the_portrait_sky_the_hunts_frame_is_the_sky() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(3), Fixtures.SKY, StarMap.heart())
	assert_eq(run.frame_rect, run.sky_rect)
	var prey := Star.new(1, Star.Size.SMALL, Fixtures.SKY.position + Vector2i(15, 15))
	var by_frame := Hunt.new(38, 7)
	var by_sky := Hunt.new(38, 7)
	assert_eq(by_frame.mark(run.frame_rect, [prey] as Array[Star]), by_sky.mark(Fixtures.SKY, [prey] as Array[Star]))


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
	run.hunt.mark(run.frame_rect)
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
	var kept: Star = run.add_star(Star.Size.MEDIUM, Vector2i(150, 220))
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


func test_a_ring_dot_in_the_shade_reads_where_its_star_lands() -> void:
	var run: RunState = _stage(StarMap.aquarius_body())
	var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
	for dot: Vector2i in [Vector2i(-100, 150), Vector2i(300, 150), Vector2i(120, 40), Vector2i(120, 245)]:
		assert_eq(run.burst_drains_at(dot), run.burst_drains_at(StarScatter.clamp_to_sky(dot, run.frame_rect)), "%s: read at the box's edge, where it lands" % dot)
	assert_false(run.burst_drains_at(Vector2i(-100, 150)), "upstream of the Body's drain: the star lands by the box's side and stays")
	assert_false(run.burst_drains_at(Vector2i(120, 150)), "inside the box only the drain itself counts")
	assert_true(run.burst_drains_at(Vector2i(run.current.region.position.x + 2, 150)), "just inside the drain line")
	var jar: RunState = _stage(StarMap.aquarius_jar())
	var past := Vector2i(jar.frame_rect.end.x + 4, 150)
	assert_eq(jar.burst_drains_at(past), jar.burst_drains_at(Vector2i(StarScatter.inner_rect(jar.frame_rect).end.x - 1, 150)), "past the Jar's side: read at the box's edge")
	assert_true(inner.has_point(StarScatter.clamp_to_sky(Vector2i(-100, 150), run.launch_rect())))


func test_on_the_portrait_sky_a_ring_dot_past_its_edge_reads_where_it_lands() -> void:
	var run: RunState = _stage(StarMap.aquarius_body(), Fixtures.SKY)
	var y: int = 150
	var x: int = run.current.region.position.x + 30
	assert_false(run.burst_drains_at(Vector2i(x, Fixtures.SKY.position.y - 6)), "above the sky the star lands in it, in the flow, and stays")
	assert_false(run.burst_drains_at(Vector2i(x, Fixtures.SKY.end.y + 6)), "below the sky too")
	assert_eq(run.burst_drains_at(Vector2i(x, Fixtures.SKY.position.y - 6)), run.burst_drains_at(Vector2i(x, y)))


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
