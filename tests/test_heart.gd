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
	assert_eq(Balance.load_file().hunt_radius, 38, "shipped: radius reduced by 5% (#99)")
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
	Fixtures.launch(run, MID_SKY)
	assert_eq(events.slice(0, 3), [&"pack_launched", &"pack_burst", &"area_marked"] as Array[StringName], "marked after the burst")
	assert_true(struck.is_empty(), "nothing to strike yet")
	assert_true(run.hunt.has_area())
	assert_eq(run.stars.size(), 3, "every star kept")


func test_the_next_launch_bursts_then_strikes_then_marks_again() -> void:
	var run: RunState = _heart_run()
	Fixtures.launch(run, MID_SKY)
	_record(run)
	Fixtures.launch(run, Vector2i(60, 200))
	assert_eq(events.slice(0, 4), [&"pack_launched", &"pack_burst", &"area_struck", &"area_marked"] as Array[StringName])


func test_the_strike_takes_every_loose_star_inside_and_only_those() -> void:
	var run: RunState = _heart_run()
	Fixtures.launch(run, MID_SKY)
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
	Fixtures.launch(run, Vector2i(150, 230))
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
	Fixtures.launch(run, Vector2i(40, 220))
	run.hunt.centre = MID_SKY
	var born: Array[Star] = []
	run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void: born.append_array(stars))
	var hit: Array[Star] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append_array(stars))
	Fixtures.launch(run, MID_SKY)
	assert_eq(born.size(), 3)
	for star: Star in born:
		assert_true(hit.has(star), "a star burst into the circle is struck")
		assert_null(run.find_star(star.id))


func test_landmarks_are_never_hit() -> void:
	var run: RunState = _heart_run()
	Fixtures.launch(run, MID_SKY)
	run.hunt.centre = run.scorpio.landmark_position(2)
	var lit: Array[bool] = run.scorpio.lit.duplicate()
	var hit: Array[Star] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append_array(stars))
	Fixtures.launch(run, Vector2i(40, 220))
	for star: Star in hit:
		assert_false(run.scorpio.is_landmark(star.id))
	assert_eq(run.scorpio.lit, lit, "the constellation stands")


func test_links_invalid_links_and_failed_launches_never_strike_or_move_the_area() -> void:
	var run: RunState = _heart_run(1)
	Fixtures.launch(run, MID_SKY)
	var centre: Vector2i = run.hunt.centre
	var struck: Array[bool] = []
	run.area_struck.connect(func(_at: Vector2i, _stars: Array[Star]) -> void: struck.append(true))
	var trio: Array[int] = _corner_trio(run)
	assert_ne(run.link(trio), Combos.INVALID)
	var big: Star = run.add_star(Star.Size.BIG, CORNER)
	assert_eq(run.link([big.id, 999, 998] as Array[int]), Combos.INVALID)
	run.light = run.light_target() - 1
	assert_ne(run.link(_corner_trio(run)), Combos.INVALID, "a rekindle clears the sky")
	assert_false(Fixtures.launch(run, MID_SKY), "no pack left")
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
			Fixtures.launch(run, Vector2i(40 + 20 * launch, 120 + 15 * launch))


func test_every_area_threatens_a_loose_star_on_every_seed() -> void:
	for seed_value: int in range(1, 31):
		var data: Dictionary = _balance_dict()
		data["hunt"] = {"radius": 24 if seed_value % 2 == 0 else 40}
		data["start_packs"] = {"blue": 6, "red": 0}
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.heart())
		var covered: Array[bool] = []
		run.area_marked.connect(func(_at: Vector2i, radius: int) -> void:
			# Only stars no circle can reach (in Orion's corner, or the sky's far corners) are ever left out.
			var reachable: bool = run.stars.any(func(star: Star) -> bool: return _reachable(star, radius))
			covered.append(not reachable or run.stars.any(func(star: Star) -> bool: return run.hunt.contains(star.position))))
		for launch: int in 6:
			Fixtures.launch(run, Vector2i(40 + 20 * launch, 120 + 15 * launch))
		assert_eq(covered.size(), 6)
		assert_does_not_have(covered, false, "seed %d: never a circle over empty sky while a star can be reached" % seed_value)


func test_a_circle_is_marked_round_a_star_even_at_the_skys_edge_or_by_orion() -> void:
	var corner := Rect2i(Fixtures.SKY.position + Volley.ORION_CORNER.position, Volley.ORION_CORNER.size)
	var edges: Array[Vector2i] = [
		Vector2i(90, Fixtures.SKY.end.y - StarScatter.EDGE_MARGIN - 1),
		Vector2i(Fixtures.SKY.end.x - StarScatter.EDGE_MARGIN - 1, 160),
		corner.end + Vector2i(1, 1),
		Vector2i(120, Fixtures.SKY.position.y + StarScatter.EDGE_MARGIN),
	]
	for at: Vector2i in edges:
		for seed_value: int in range(1, 11):
			var hunt := Hunt.new(40, seed_value)
			var star := Star.new(1, Star.Size.SMALL, at)
			var centre: Vector2i = hunt.mark(Fixtures.SKY, [star] as Array[Star])
			assert_true(hunt.contains(at), "%s, seed %d: the star is inside" % [at, seed_value])
			assert_true(Fixtures.SKY.grow(-40).has_point(centre), "the whole circle in the sky")
			assert_false(corner.grow(40).has_point(centre), "clear of Orion's figure")


func test_a_star_hugging_orion_is_passed_over_for_one_the_circle_can_reach() -> void:
	# Right beside his figure: no circle clear of it reaches this star; nor one in the sky's far corner.
	var hugging := Star.new(1, Star.Size.BIG, Vector2i(45, 80))
	var far := Star.new(3, Star.Size.MEDIUM, StarScatter.inner_rect(Fixtures.SKY).end - Vector2i.ONE)
	var open := Star.new(2, Star.Size.SMALL, MID_SKY)
	for seed_value: int in range(1, 21):
		var hunt := Hunt.new(40, seed_value)
		hunt.mark(Fixtures.SKY, [hugging, far, open] as Array[Star])
		assert_true(hunt.contains(open.position), "seed %d" % seed_value)


func test_an_empty_sky_still_gets_a_circle() -> void:
	var hunt := Hunt.new(40, 7)
	var centre: Vector2i = hunt.mark(Fixtures.SKY)
	assert_true(hunt.has_area())
	assert_true(Fixtures.SKY.grow(-40).has_point(centre))


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
			Fixtures.launch(run, Vector2i(50 + 25 * launch, 150))
		centres.append(marked)
		skies.append(sky)
	assert_eq(centres[0].size(), 4)
	assert_eq(centres[0], centres[1], "same seed, same circles")
	assert_eq(skies[0].slice(0, 3), skies[2].slice(0, 3), "the first burst is the same with or without the hunt")


func test_a_big_bang_launch_strikes_an_empty_sky_and_marks_again() -> void:
	var run: RunState = _heart_run()
	Fixtures.launch(run, MID_SKY)
	run.force_next_big_bang = true
	var hit: Array[Array] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append(stars))
	_record(run)
	Fixtures.launch(run, MID_SKY)
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
	Fixtures.launch(run, MID_SKY)
	_corner_trio(run)
	assert_true(run.has_remaining_combo())
	_record(run)
	Fixtures.launch(run, MID_SKY)
	assert_true(run.stars.is_empty())
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust, no combo after the strike")
	assert_eq(events[-1], &"run_lost")
	assert_lt(events.find(&"area_struck"), events.find(&"run_lost"))


func test_a_restart_has_no_area() -> void:
	var run: RunState = _heart_run()
	Fixtures.launch(run, MID_SKY)
	assert_true(run.hunt.has_area())
	assert_false(_heart_run().hunt.has_area())


func test_balance_reads_the_hunts_intro() -> void:
	assert_eq(Balance.load_file().hunt_intro_stars, 3, "shipped: three stars in the circle, then a demo launch")
	assert_eq(_balance().hunt_intro_stars, 0, "no intro unless asked")
	var data: Dictionary = _balance_dict()
	data["hunt"] = {"radius": 40, "intro_stars": -1}
	assert_false(Balance.from_dict(data).is_valid())


func test_the_intro_plays_the_whole_cycle_once_for_nothing() -> void:
	var run: RunState = _intro_run()
	_record(run)
	var placed: Array[Star] = []
	run.hunt_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append_array(stars))
	var born: Array[Star] = []
	run.hunt_intro_burst.connect(func(_at: Vector2i, stars: Array[Star]) -> void: born.append_array(stars))
	var launched: Array = []
	run.hunt_intro_launched.connect(func(kind: String, at: Vector2i) -> void: launched.append([kind, at]))
	var hit: Array[Star] = []
	var centres: Array[Vector2i] = []
	run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: centres.append(at))
	run.area_struck.connect(func(at: Vector2i, stars: Array[Star]) -> void:
		assert_eq(at, centres[0], "the arrow strikes the circle it marked")
		hit.append_array(stars))
	var dust: int = run.dust
	var packs: Dictionary = run.owned_packs.duplicate()
	run.play_hunt_intro()
	assert_eq(events, [&"hunt_intro_placed", &"area_marked", &"hunt_intro_launched", &"hunt_intro_burst", &"area_struck"] as Array[StringName])
	assert_eq(placed.size(), 3, "the stars already there")
	assert_eq(born.size(), run.balance.packs["blue"].stars, "the demo pack's stars")
	assert_eq(launched, [["blue", centres[0]]], "the demo pack flies into the circle")
	assert_eq(hit.size(), placed.size() + born.size(), "the strike takes them all, the new ones too")
	assert_true(run.stars.is_empty())
	assert_eq(run.dust, dust, "for nothing")
	assert_eq(run.owned_packs, packs, "no pack used")
	assert_eq(run.loaded_pack, "blue")
	assert_false(run.hunt.has_area(), "no circle left: the first real launch marks one")
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_the_intros_stars_are_all_inside_its_circle_on_every_seed() -> void:
	for seed_value: int in range(1, 41):
		var run: RunState = _intro_run(seed_value)
		var count: Array[int] = [0]
		run.hunt_intro_placed.connect(func(stars: Array[Star]) -> void: count[0] += stars.size())
		run.hunt_intro_burst.connect(func(_at: Vector2i, stars: Array[Star]) -> void: count[0] += stars.size())
		var hit: Array[int] = [0]
		run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void:
			hit[0] = stars.size()
			for star: Star in stars:
				assert_false(run.scorpio.is_landmark(star.id)))
		run.play_hunt_intro()
		assert_eq(count[0], 6, "seed %d: every intro star placed" % seed_value)
		assert_eq(hit[0], count[0], "seed %d: and struck" % seed_value)
		assert_true(run.stars.is_empty(), "seed %d" % seed_value)


func test_the_intro_plays_once_and_only_on_a_fresh_hunting_stage() -> void:
	var run: RunState = _intro_run()
	run.play_hunt_intro()
	var again: Array[bool] = []
	run.hunt_intro_placed.connect(func(_stars: Array[Star]) -> void: again.append(true))
	Fixtures.launch(run, MID_SKY)
	run.play_hunt_intro()
	assert_true(again.is_empty(), "not once stars are in the sky")
	var data: Dictionary = _intro_dict()
	var body := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.body())
	body.hunt_intro_placed.connect(func(_stars: Array[Star]) -> void: again.append(true))
	body.play_hunt_intro()
	assert_true(again.is_empty(), "no hunt, no intro")
	var plain: RunState = _heart_run()
	plain.hunt_intro_placed.connect(func(_stars: Array[Star]) -> void: again.append(true))
	plain.play_hunt_intro()
	assert_true(again.is_empty(), "no intro_stars, no intro")


func test_after_the_intro_the_first_launch_only_marks() -> void:
	var run: RunState = _intro_run()
	run.play_hunt_intro()
	var struck: Array[bool] = []
	run.area_struck.connect(func(_at: Vector2i, _stars: Array[Star]) -> void: struck.append(true))
	Fixtures.launch(run, MID_SKY)
	assert_true(struck.is_empty(), "the intro's circle is gone")
	assert_true(run.hunt.has_area())
	assert_eq(run.stars.size(), 3)


func test_the_intro_never_shifts_the_packs() -> void:
	var skies: Array[Array] = []
	for intro: bool in [true, false]:
		var run: RunState = _intro_run(42)
		if intro:
			run.play_hunt_intro()
		Fixtures.launch(run, MID_SKY)
		var sky: Array[String] = []
		for star: Star in run.stars:
			sky.append("%d:%s" % [star.size, star.position])
		skies.append(sky)
	assert_eq(skies[0], skies[1], "the first burst is the same with or without the intro")


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
	assert_eq(map.painting, StarMap.PART_PAINTING % "heart")
	assert_eq(ConstellationView.song_order(map).size(), map.segment_count())


func test_the_heart_unlocks_after_the_body() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.map_id(3), "heart")
	assert_eq(Chapter.new().stage_name(3), "HEART")
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


## Whether a circle of `radius` could be marked round `star` on its own.
func _reachable(star: Star, radius: int) -> bool:
	var hunt := Hunt.new(radius, 0)
	hunt.mark(Fixtures.SKY, [star] as Array[Star])
	return hunt.contains(star.position)


func _heart_run(packs: int = 6, seed_value: int = 1) -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": packs, "red": 0}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.heart())


func _intro_dict() -> Dictionary:
	var data: Dictionary = _balance_dict()
	data["hunt"] = {"radius": 40, "intro_stars": 3}
	data["start_packs"] = {"blue": 6, "red": 0}
	return data


func _intro_run(seed_value: int = 1) -> RunState:
	return RunState.new(Balance.from_dict(_intro_dict()), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.heart())


## Takes every star out of the run (test setup only).
func _clear_sky(run: RunState) -> void:
	run.stars.clear()


## Three small stars in Orion's corner, a small triple with nothing else in reach. Their ids.
func _corner_trio(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		ids.append(run.add_star(Star.Size.SMALL, CORNER + offset).id)
	return ids


## Records the run's signals in order, but not the slingshot loading and emptying between launches.
func _record(run: RunState) -> void:
	for info: Dictionary in run.get_script().get_script_signal_list():
		var signal_name: StringName = info["name"]
		if signal_name == &"pack_loaded":
			continue
		run.connect(signal_name, func(...args: Array) -> void: events.append(signal_name))
