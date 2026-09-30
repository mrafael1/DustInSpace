extends GutTest
## The Heart (#71), stage 4: Orion hunts an area. The first launch's burst gets a circle; each later
## launch, once its pack has burst, has his arrow strike the circle and destroy every loose star
## inside (the new ones too), for nothing; then he marks a new circle.

const Fixtures := preload("res://tests/fixtures.gd")

## Orion's corner: stars here only link with each other (out of reach of the Heart's landmarks).
const CORNER := Vector2i(24, 100)
const MID_SKY := Vector2i(100, 150)

var events: Array[StringName] = []


func before_each() -> void:
	events.clear()


func test_balance_reads_the_hunt_and_leaves_it_out_without_a_block() -> void:
	assert_eq(Fixtures.balance().hunt_radius, 0, "no block: no hunt")
	assert_eq(Balance.load_file().hunt_radius, 40, "shipped: a 40 px circle, about a fifth of the sky")
	var data: Dictionary = Fixtures.balance_dict()
	data["hunt"] = {"radius": 0}
	assert_false(Balance.from_dict(data).is_valid(), "a circle has a size")
	data["hunt"] = {}
	assert_false(Balance.from_dict(data).is_valid())


func test_only_the_heart_hunts_and_it_brings_no_other_threat() -> void:
	var run: RunState = _heart_run()
	assert_not_null(run.hunt)
	assert_null(run.orion, "no single marks on the Heart")
	assert_null(run.volley, "no volley")
	for map: StarMap in [StarMap.stinger(), StarMap.tail(), StarMap.body()]:
		assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, map).hunt, map.id)
	var data: Dictionary = _balance_dict()
	data.erase("hunt")
	assert_null(RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.heart()).hunt, "nor without its tuning")


func test_the_first_launch_only_marks_an_area() -> void:
	var run: RunState = _heart_run()
	var struck: Array[bool] = []
	run.area_struck.connect(func(_at: Vector2i, _stars: Array[Star]) -> void: struck.append(true))
	_record(run)
	run.launch(MID_SKY)
	assert_eq(events.slice(0, 3), [&"pack_launched", &"pack_burst", &"area_marked"] as Array[StringName], "marked after the burst")
	assert_true(struck.is_empty(), "nothing to strike yet")
	assert_true(run.hunt.has_area())
	assert_eq(run.stars.size(), 3, "every star kept")


func test_the_next_launch_bursts_then_strikes_then_marks_again() -> void:
	var run: RunState = _heart_run()
	run.launch(MID_SKY)
	_record(run)
	run.launch(Vector2i(60, 200))
	assert_eq(events.slice(0, 4), [&"pack_launched", &"pack_burst", &"area_struck", &"area_marked"] as Array[StringName])


func test_the_strike_takes_every_loose_star_inside_and_only_those() -> void:
	var run: RunState = _heart_run()
	run.launch(MID_SKY)
	_clear_sky(run)
	run.hunt.centre = MID_SKY
	var inside: Array[Star] = [run.add_star(Star.Size.SMALL, MID_SKY), run.add_star(Star.Size.BIG, MID_SKY + Vector2i(10, 5))]
	var edge: Star = run.add_star(Star.Size.MEDIUM, MID_SKY + Vector2i(run.hunt.radius, 0))
	var outside: Star = run.add_star(Star.Size.MEDIUM, MID_SKY + Vector2i(run.hunt.radius + 1, 0))
	var hit: Array[Star] = []
	run.area_struck.connect(func(at: Vector2i, stars: Array[Star]) -> void:
		assert_eq(at, MID_SKY, "the arrow flies to the circle's centre")
		hit.append_array(stars))
	var dust: int = run.dust
	run.launch(Vector2i(150, 230))
	for star: Star in inside + [edge] as Array[Star]:
		assert_true(hit.has(star), "star at %s hit" % star.position)
		assert_null(run.find_star(star.id))
	assert_false(hit.has(outside), "a pixel outside is safe")
	assert_not_null(run.find_star(outside.id))
	assert_eq(run.dust, dust, "for nothing")


func test_the_new_packs_stars_are_struck_too() -> void:
	var data: Dictionary = _balance_dict()
	data["hunt"] = {"radius": 60}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.heart())
	run.launch(Vector2i(40, 220))
	run.hunt.centre = MID_SKY
	var born: Array[Star] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void: born.append_array(stars))
	var hit: Array[Star] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append_array(stars))
	run.launch(MID_SKY)
	assert_eq(born.size(), 3)
	for star: Star in born:
		assert_true(hit.has(star), "a star burst into the circle is struck")
		assert_null(run.find_star(star.id))


func test_landmarks_are_never_hit() -> void:
	var run: RunState = _heart_run()
	run.launch(MID_SKY)
	run.hunt.centre = run.scorpio.landmark_position(2)
	var lit: Array[bool] = run.scorpio.lit.duplicate()
	var hit: Array[Star] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append_array(stars))
	run.launch(Vector2i(40, 220))
	for star: Star in hit:
		assert_false(run.scorpio.is_landmark(star.id))
	assert_eq(run.scorpio.lit, lit, "the constellation stands")


func test_links_invalid_links_and_failed_launches_never_strike_or_move_the_area() -> void:
	var run: RunState = _heart_run(1)
	run.launch(MID_SKY)
	var centre: Vector2i = run.hunt.centre
	var struck: Array[bool] = []
	run.area_struck.connect(func(_at: Vector2i, _stars: Array[Star]) -> void: struck.append(true))
	var trio: Array[int] = _corner_trio(run)
	assert_ne(run.link(trio), Combos.INVALID)
	var big: Star = run.add_star(Star.Size.BIG, CORNER)
	assert_eq(run.link([big.id, 999, 998] as Array[int]), Combos.INVALID)
	run.light = run.light_target() - 1
	assert_ne(run.link(_corner_trio(run)), Combos.INVALID, "a rekindle clears the sky")
	assert_false(run.launch(MID_SKY), "no pack left")
	assert_true(struck.is_empty())
	assert_true(run.hunt.has_area(), "the circle waits for the next launch")
	assert_eq(run.hunt.centre, centre)


func test_areas_stay_in_the_sky_and_clear_of_orion() -> void:
	var corner := Rect2i(Fixtures.SKY.position + Volley.ORION_CORNER.position, Volley.ORION_CORNER.size)
	for seed_value: int in range(1, 31):
		var data: Dictionary = _balance_dict()
		data["hunt"] = {"radius": 24 if seed_value % 2 == 0 else 40}
		data["start_packs"] = {"blue": 6, "red": 0}
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.heart())
		run.area_marked.connect(func(at: Vector2i, radius: int) -> void:
			assert_true(Fixtures.SKY.grow(-radius).has_point(at), "seed %d: the whole circle round %s in the sky" % [seed_value, at])
			assert_false(corner.grow(radius).has_point(at), "seed %d: the circle keeps off Orion's figure" % seed_value))
		for launch: int in 6:
			run.launch(Vector2i(40 + 20 * launch, 120 + 15 * launch))


func test_the_same_seed_marks_the_same_areas_and_packs_never_shift() -> void:
	var centres: Array[Array] = []
	var skies: Array[Array] = []
	for with_hunt: bool in [true, true, false]:
		var data: Dictionary = _balance_dict()
		if not with_hunt:
			data.erase("hunt")
		data["start_packs"] = {"blue": 6, "red": 0}
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(42), Fixtures.SKY, StarMap.heart())
		var marked: Array[Vector2i] = []
		run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: marked.append(at))
		var sky: Array[String] = []
		run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
			for star: Star in stars:
				sky.append("%d:%s" % [star.size, star.position]))
		for launch: int in 4:
			run.launch(Vector2i(50 + 25 * launch, 150))
		centres.append(marked)
		skies.append(sky)
	assert_eq(centres[0].size(), 4)
	assert_eq(centres[0], centres[1], "same seed, same circles")
	assert_eq(skies[0].slice(0, 3), skies[2].slice(0, 3), "the first burst is the same with or without the hunt")


func test_a_big_bang_launch_strikes_an_empty_sky_and_marks_again() -> void:
	var run: RunState = _heart_run()
	run.launch(MID_SKY)
	run.force_next_big_bang = true
	var hit: Array[Array] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append(stars))
	_record(run)
	run.launch(MID_SKY)
	assert_eq(hit.size(), 1)
	assert_true(hit[0].is_empty(), "the Big Bang took every star first")
	assert_lt(events.find(&"big_bang_started"), events.find(&"area_struck"))
	assert_true(run.hunt.has_area(), "a new circle")


func test_the_launchs_loss_check_sees_the_sky_after_the_strike() -> void:
	# The last pack, no dust, and a circle as big as the sky: the strike takes every star, the new
	# pack's too, and no combo is left.
	var data: Dictionary = _balance_dict()
	data["hunt"] = {"radius": 400}
	data["start_packs"] = {"blue": 2, "red": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.heart())
	run.launch(MID_SKY)
	_corner_trio(run)
	assert_true(run.has_remaining_combo())
	_record(run)
	run.launch(MID_SKY)
	assert_true(run.stars.is_empty())
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust, no combo after the strike")
	assert_eq(events[-1], &"run_lost")
	assert_lt(events.find(&"area_struck"), events.find(&"run_lost"))


func test_a_restart_has_no_area() -> void:
	var run: RunState = _heart_run()
	run.launch(MID_SKY)
	assert_true(run.hunt.has_area())
	assert_false(_heart_run().hunt.has_area())


func test_the_heart_map() -> void:
	var map: StarMap = StarMap.heart()
	assert_eq(StarMap.by_id("heart").id, "heart")
	assert_eq(map.title, "HEART")
	assert_true(map.hunt)
	assert_false(map.orion)
	assert_eq(map.volley, "")
	assert_eq(map.count(), 7)
	assert_eq(map.starting_lit, [0] as Array[int], "six to light")
	assert_eq(map.segment_count(), map.count() - 1, "a tree")
	assert_false(map.path(0, 4).is_empty(), "all connected")
	var antares: int = 2
	assert_eq(map.sizes[antares], Star.Size.BIG, "Antares is big")
	assert_eq(map.neighbours(antares).size(), 4, "four strings meet at the heart")
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(CORNER)), 56.0, "the corner is Orion's")
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 24.0, "stars apart")
	for segment: int in map.segment_count():
		var ends: Array[Vector2i] = map.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 24.0, 40.0)
	var drawing: Array[Vector2i] = ConstellationView.scorpion_drawing(map)
	assert_gt(drawing.size(), 60, "a heart and its vessels")
	for p: Vector2i in drawing:
		assert_true(Scorpio.HOME_SKY.has_point(p))
	var left: int = 0
	var right: int = 0
	for p: Vector2i in drawing:
		if absi(p.y - map.landmarks[antares].y) <= 14:
			if p.x < map.landmarks[antares].x - 8:
				left += 1
			elif p.x > map.landmarks[antares].x + 8:
				right += 1
	assert_gt(left, 4, "the heart wraps Antares' left")
	assert_gt(right, 4, "and its right")
	assert_eq(ConstellationView.song_order(map).size(), map.segment_count())


func test_the_heart_unlocks_after_the_body() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.map_id(3), "heart")
	assert_eq(Chapter.stage_name(3), "HEART")
	assert_eq(chapter.state(3), Chapter.PointState.LOCKED)
	for stage: int in 2:
		chapter.complete(stage)
	assert_eq(chapter.state(3), Chapter.PointState.LOCKED, "until the Body is won")
	assert_eq(chapter.complete(2), 3, "winning the Body opens the Heart")
	assert_eq(chapter.state(3), Chapter.PointState.AVAILABLE)
	chapter.complete(3)
	var saved := Chapter.new()
	saved.from_save(chapter.to_save())
	assert_true(saved.is_completed(3), "the win is saved")


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["hunt"] = {"radius": 24}
	return data


func _balance() -> Balance:
	return Balance.from_dict(_balance_dict())


func _heart_run(packs: int = 6, seed_value: int = 1) -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": packs, "red": 0}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.heart())


## Takes every star out of the run (test setup only).
func _clear_sky(run: RunState) -> void:
	run.stars.clear()


## Three small stars in Orion's corner, a small triple with nothing else in reach. Their ids.
func _corner_trio(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		ids.append(run.add_star(Star.Size.SMALL, CORNER + offset).id)
	return ids


func _record(run: RunState) -> void:
	for info: Dictionary in run.get_script().get_script_signal_list():
		var signal_name: StringName = info["name"]
		run.connect(signal_name, func(...args: Array) -> void: events.append(signal_name))
