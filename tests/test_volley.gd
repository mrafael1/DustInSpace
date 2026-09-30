extends GutTest
## Orion's volley (#70), the Body stage's twist: every third successful link, once it resolves, his
## arrows destroy half the loose sky stars (rounded up), for nothing. Landmarks are never hit.

const Fixtures := preload("res://tests/fixtures.gd")

## Orion's corner: stars here only link with each other (out of reach of the Body's landmarks).
const CORNER := Vector2i(24, 100)

var events: Array[StringName] = []


func before_each() -> void:
	events.clear()


func test_balance_reads_the_volley_and_leaves_it_out_without_a_block() -> void:
	assert_eq(Fixtures.balance().volley_interval, 0, "no block: no volley")
	var shipped: Balance = Balance.load_file()
	assert_eq([shipped.volley_interval, shipped.volley_fraction, shipped.volley_intro_stars], [2, 1.0, 6], "shipped: every second link, the whole sky, a 6-star intro")
	var data: Dictionary = Fixtures.balance_dict()
	data["volley"] = {"interval": 0, "fraction": 0.5}
	assert_false(Balance.from_dict(data).is_valid(), "at least one link between volleys")
	data["volley"] = {"interval": 3, "fraction": 0.0}
	assert_false(Balance.from_dict(data).is_valid(), "a volley takes something")
	data["volley"] = {"interval": 3, "fraction": 1.5}
	assert_false(Balance.from_dict(data).is_valid())
	data["volley"] = {"interval": 3}
	assert_false(Balance.from_dict(data).is_valid())
	data["volley"] = {"interval": 3, "fraction": 0.5}
	assert_eq(Balance.from_dict(data).volley_intro_stars, 0, "no intro unless asked")
	data["volley"] = {"interval": 3, "fraction": 0.5, "intro_stars": -1}
	assert_false(Balance.from_dict(data).is_valid())


func test_only_the_body_brings_the_volley_and_it_never_marks() -> void:
	var run: RunState = _body_run()
	assert_not_null(run.volley)
	assert_null(run.orion, "no single-target marks on the Body")
	assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, StarMap.tail()).volley)
	assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, StarMap.stinger()).volley)
	assert_null(RunState.new(Fixtures.balance(_scorpio_on()), Fixtures.rng(), Fixtures.SKY, StarMap.body()).volley, "nor without its tuning")
	var marked: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marked.append(star))
	for launch: int in 3:
		run.launch(Vector2i(90, 150))
	assert_true(marked.is_empty())


func test_the_third_successful_link_looses_the_volley() -> void:
	var run: RunState = _body_run()
	var counts: Array[int] = []
	run.volley_counted.connect(func(left: int) -> void: counts.append(left))
	var volleys: Array[Array] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: volleys.append(stars))
	_add_loose(run, 6)
	run.link(_corner_trio(run))
	run.link(_corner_trio(run))
	assert_eq(counts, [2, 1] as Array[int], "the countdown after each link")
	assert_true(volleys.is_empty())
	var loose: int = run.stars.size()
	_record(run)
	run.link(_corner_trio(run))
	assert_eq(volleys.size(), 1, "the third link fires")
	assert_eq(volleys[0].size(), 3, "half of 6 loose stars")
	assert_eq(run.stars.size(), loose - 3)
	assert_eq(counts[-1], 3, "and the countdown starts again")
	assert_eq(events, [&"combo_collected", &"volley_fired", &"volley_counted"] as Array[StringName], "after the combo resolves")


func test_the_countdown_resets_and_fires_again_three_links_later() -> void:
	var run: RunState = _body_run()
	var fired: Array[int] = []
	var link_index: Array[int] = [0]
	run.volley_fired.connect(func(_stars: Array[Star]) -> void: fired.append(link_index[0]))
	for i: int in 7:
		link_index[0] = i + 1
		_add_loose(run, 2)
		run.link(_corner_trio(run))
	assert_eq(fired, [3, 6] as Array[int])
	assert_eq(run.volley.links_left(), 2)


func test_invalid_links_launches_and_failed_launches_dont_count() -> void:
	var run: RunState = _body_run(1)
	var counts: Array[int] = []
	run.volley_counted.connect(func(left: int) -> void: counts.append(left))
	var big: Star = run.add_star(Star.Size.BIG, CORNER)
	var small: Star = run.add_star(Star.Size.SMALL, CORNER + Vector2i(10, 0))
	var other: Star = run.add_star(Star.Size.SMALL, CORNER + Vector2i(5, 8))
	assert_eq(run.link([big.id, small.id, other.id] as Array[int]), Combos.INVALID)
	assert_eq(run.link([big.id, 999, 998] as Array[int]), Combos.INVALID)
	assert_true(run.launch(Vector2i(90, 150)))
	assert_false(run.launch(Vector2i(90, 150)), "no pack left")
	assert_true(counts.is_empty())
	assert_eq(run.volley.links_left(), 3)


func test_victims_are_half_the_loose_stars_rounded_up() -> void:
	for loose: int in [1, 2, 3, 4, 5, 8, 9]:
		var run: RunState = _body_run()
		run.volley.counted = 2
		_add_loose(run, loose)
		var victims: Array[Star] = []
		run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
		run.link(_corner_trio(run))
		assert_eq(victims.size(), ceili(loose / 2.0), "%d loose: %d hit" % [loose, ceili(loose / 2.0)])
		for star: Star in victims:
			assert_false(run.stars.has(star), "destroyed")
		assert_eq(run.stars.size(), loose - victims.size())


func test_destroyed_stars_pay_nothing() -> void:
	var run: RunState = _body_run()
	run.volley.counted = 2
	_add_loose(run, 4)
	var trio: Array[int] = _corner_trio(run)
	var dust: int = run.dust
	var light: int = run.light
	var combo: String = run.link(trio)
	var reward: Balance.ComboReward = run.balance.combos[combo]
	assert_eq([run.dust, run.light], [dust + reward.dust, light + reward.light], "only the combo pays")


func test_an_empty_sky_loses_nothing_and_the_countdown_resets() -> void:
	var run: RunState = _body_run()
	run.volley.counted = 2
	var volleys: Array[Array] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: volleys.append(stars))
	run.link(_corner_trio(run))
	assert_eq(volleys.size(), 1)
	assert_true(volleys[0].is_empty(), "nothing to hit")
	assert_eq(run.volley.links_left(), 3)


func test_landmarks_and_the_constellation_are_never_hit() -> void:
	for seed_value: int in range(1, 11):
		var run: RunState = _body_run(6, seed_value)
		for launch: int in 3:
			run.launch(Vector2i(40 + 30 * launch, 140))
		run.volley.counted = 2
		var lit: Array[bool] = run.scorpio.lit.duplicate()
		var victims: Array[Star] = []
		run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
		run.link(_corner_trio(run))
		assert_false(victims.is_empty(), "seed %d: a volley" % seed_value)
		for star: Star in victims:
			assert_false(run.scorpio.is_landmark(star.id), "seed %d: never a landmark" % seed_value)
		assert_eq(run.scorpio.lit, lit, "seed %d: the constellation stands" % seed_value)


func test_the_same_seed_hits_the_same_stars_and_packs_never_shift() -> void:
	var picks: Array[Array] = []
	var skies: Array[Array] = []
	for with_volley: bool in [true, true, false]:
		var data: Dictionary = _balance_dict()
		if not with_volley:
			data.erase("volley")
		data["start_packs"] = {"blue": 6, "red": 0}
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(42), Fixtures.SKY, StarMap.body())
		var hit: Array[int] = []
		run.volley_fired.connect(func(stars: Array[Star]) -> void:
			for star: Star in stars:
				hit.append(star.id))
		var sky: Array[String] = []
		for launch: int in 4:
			run.launch(Vector2i(90, 150))
			for star: Star in run.stars:
				sky.append("%d:%d:%s" % [star.id, star.size, star.position])
			if with_volley:
				run.volley.counted = 2
				run.link(_corner_trio(run))
		picks.append(hit)
		skies.append(sky.slice(0, 3))
	assert_gt(picks[0].size(), 2)
	assert_eq(picks[0], picks[1], "same seed, same victims")
	assert_eq(skies[0], skies[2], "the first burst is the same with or without the volley")


func test_a_restart_starts_the_countdown_again() -> void:
	var run: RunState = _body_run()
	run.link(_corner_trio(run))
	assert_eq(run.volley.links_left(), 2)
	assert_eq(_body_run().volley.links_left(), 3)


func test_a_sun_clear_comes_first_so_nothing_is_hit_or_paid_twice() -> void:
	var run: RunState = _body_run()
	run.volley.counted = 2
	_add_loose(run, 4)
	run.light = run.light_target() - 1
	var cleared: Array[Star] = []
	run.sky_cleared.connect(func(stars: Array[Star], _dust: int) -> void: cleared.append_array(stars))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	_record(run)
	run.link(_corner_trio(run))
	assert_eq(cleared.size(), 4, "the rekindled Sun burst the loose stars for dust")
	assert_true(victims.is_empty(), "the volley found an empty sky")
	assert_lt(events.find(&"sky_cleared"), events.find(&"volley_fired"))
	assert_eq(run.volley.links_left(), 3, "it still counted")


func test_the_link_that_completes_the_body_skips_the_volley() -> void:
	var run: RunState = _body_run()
	var won: Array[bool] = []
	run.run_won.connect(func() -> void: won.append(true))
	var last: int = run.scorpio.map.count() - 1
	for index: int in range(1, run.scorpio.map.count()):
		var size: int = run.scorpio.map.sizes[index]
		var at: Vector2i = run.scorpio.landmark_position(index)
		var a: Star = run.add_star(size as Star.Size, at + Vector2i(-8, 0))
		var b: Star = run.add_star(size as Star.Size, at + Vector2i(0, -8))
		var link: Array[int] = [a.id, b.id, Scorpio.landmark_id(index)]
		if index == last:
			run.volley.counted = 2
			assert_false(run.link_fires_volley(link), "the last link wins instead")
			var volleys: Array[Array] = []
			run.volley_fired.connect(func(stars: Array[Star]) -> void: volleys.append(stars))
			assert_ne(run.link(link), Combos.INVALID)
			assert_true(volleys.is_empty(), "no volley on the winning link")
		else:
			assert_ne(run.link(link), Combos.INVALID, "body star %d" % index)
	assert_eq(won, [true])


func test_the_loss_check_sees_the_sky_after_the_volley() -> void:
	# No pack, no dust: the link fills the countdown and leaves three loose mediums; the volley takes
	# two of them, and no combo is left.
	var run: RunState = _stuck_run()
	run.volley.counted = 2
	for offset: Vector2i in [Vector2i(0, 30), Vector2i(10, 30), Vector2i(5, 38)]:
		run.add_star(Star.Size.MEDIUM, CORNER + offset)
	var trio: Array[int] = _corner_trio(run)
	assert_true(run.has_remaining_combo())
	_record(run)
	run.link(trio)
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust, no combo after the volley")
	assert_eq(events.slice(-2), [&"volley_counted", &"run_lost"] as Array[StringName])
	assert_lt(events.find(&"volley_fired"), events.find(&"run_lost"))


func test_link_fires_volley_only_for_the_valid_link_that_fills_the_countdown() -> void:
	var run: RunState = _body_run()
	var trio: Array[int] = _corner_trio(run)
	assert_false(run.link_fires_volley(trio), "two links still to go")
	run.volley.counted = 2
	assert_true(run.link_fires_volley(trio))
	assert_false(run.link_fires_volley([trio[0], trio[1]] as Array[int]), "not a whole link")
	var big: Star = run.add_star(Star.Size.BIG, CORNER + Vector2i(0, 16))
	assert_false(run.link_fires_volley([trio[0], trio[1], big.id] as Array[int]), "not a combo")


func test_a_full_volley_takes_every_loose_star() -> void:
	var data: Dictionary = _balance_dict()
	data["volley"] = {"interval": 2, "fraction": 1.0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.body())
	run.link(_corner_trio(run))
	_add_loose(run, 5)
	var lit: Array[bool] = run.scorpio.lit.duplicate()
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	run.link(_corner_trio(run))
	assert_eq(victims.size(), 5, "the second link clears the sky")
	assert_true(run.stars.is_empty())
	assert_eq(run.scorpio.lit, lit, "the constellation stands")


func test_the_intro_places_stars_then_a_volley_takes_them_all() -> void:
	var run: RunState = _intro_run()
	_record(run)
	var placed: Array[Star] = []
	run.volley_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append_array(stars))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	var dust: int = run.dust
	run.play_volley_intro()
	assert_eq(placed.size(), 6, "the intro's stars")
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for star: Star in placed:
		assert_true(inner.has_point(star.position), "in the sky")
		assert_false(Rect2i(Fixtures.SKY.position, Volley.ORION_CORNER.size).has_point(star.position), "off Orion's figure")
		for i: int in run.scorpio.map.count():
			assert_gt(Vector2(star.position).distance_to(Vector2(run.scorpio.landmark_position(i))), 0.0, "not on a landmark")
	assert_eq(victims, placed, "the intro volley takes them all")
	assert_true(run.stars.is_empty())
	assert_eq(run.dust, dust, "for nothing")
	assert_eq(run.volley.links_left(), run.volley.interval, "it doesn't count")
	assert_eq(events, [&"volley_intro_placed", &"volley_fired", &"volley_counted"] as Array[StringName])
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_the_intro_keeps_clear_of_orion_on_every_seed() -> void:
	var corner := Rect2i(Fixtures.SKY.position, Volley.ORION_CORNER.size)
	for seed_value: int in range(1, 41):
		var run: RunState = _intro_run(seed_value)
		var placed: Array[Star] = []
		run.volley_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append_array(stars))
		run.play_volley_intro()
		for star: Star in placed:
			assert_false(corner.has_point(star.position), "seed %d: %s off Orion's figure" % [seed_value, star.position])


func test_the_intro_plays_once_and_only_on_a_fresh_volley_stage() -> void:
	var run: RunState = _intro_run()
	run.play_volley_intro()
	var again: Array[bool] = []
	run.volley_intro_placed.connect(func(_stars: Array[Star]) -> void: again.append(true))
	run.launch(Vector2i(90, 150))
	run.play_volley_intro()
	assert_true(again.is_empty(), "not once stars are in the sky")
	var tail := RunState.new(Balance.from_dict(_intro_dict()), Fixtures.rng(), Fixtures.SKY, StarMap.tail())
	tail.volley_intro_placed.connect(func(_stars: Array[Star]) -> void: again.append(true))
	tail.play_volley_intro()
	assert_true(again.is_empty(), "no volley, no intro")


func test_the_intro_never_shifts_the_packs() -> void:
	var skies: Array[Array] = []
	for intro: bool in [true, false]:
		var run: RunState = _intro_run(42)
		if intro:
			run.play_volley_intro()
		run.launch(Vector2i(90, 150))
		var sky: Array[String] = []
		for star: Star in run.stars:
			sky.append("%d:%s" % [star.size, star.position])
		skies.append(sky)
	assert_eq(skies[0], skies[1], "the first burst is the same with or without the intro")


func test_the_body_map_is_more_connected_than_the_tail() -> void:
	var map: StarMap = StarMap.body()
	assert_eq(StarMap.by_id("body").id, "body")
	assert_eq(map.title, "BODY")
	assert_true(map.volley)
	assert_false(map.orion)
	assert_gt(map.count(), StarMap.tail().count(), "more stars")
	assert_gt(map.segment_count(), StarMap.tail().segment_count(), "more strings")
	var branching: int = 0
	for i: int in map.count():
		if map.neighbours(i).size() > 2:
			branching += 1
	assert_gte(branching, 2, "stars joining more than two strings")
	assert_eq(map.path(0, map.count() - 1).is_empty(), false, "all connected")
	assert_eq(map.segment_count(), map.count() - 1, "a tree")
	assert_eq(map.starting_lit, [0] as Array[int])
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(CORNER)), 56.0, "the corner is Orion's")
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 20.0, "stars apart")
	for segment: int in map.segment_count():
		var ends: Array[Vector2i] = map.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 24.0, 40.0)
	var drawing: Array[Vector2i] = ConstellationView.scorpion_drawing(map)
	assert_gt(drawing.size(), 60, "plated sides and legs")
	for p: Vector2i in drawing:
		assert_true(Scorpio.HOME_SKY.has_point(p))
	assert_eq(ConstellationView.song_order(map).size(), map.segment_count())


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data.merge(_scorpio_on(), true)
	data["volley"] = {"interval": 3, "fraction": 0.5}
	return data


func _scorpio_on() -> Dictionary:
	return {"scorpio": {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}}


func _intro_dict() -> Dictionary:
	var data: Dictionary = _balance_dict()
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	data["start_packs"] = {"blue": 6, "red": 0}
	return data


func _intro_run(seed_value: int = 1) -> RunState:
	return RunState.new(Balance.from_dict(_intro_dict()), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.body())


func _balance() -> Balance:
	return Balance.from_dict(_balance_dict())


func _body_run(packs: int = 6, seed_value: int = 1) -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": packs, "red": 0}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.body())


## No pack and no dust.
func _stuck_run() -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": 0, "red": 0}
	data["start_dust"] = 0
	return RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.body())


## `count` loose big stars down the left edge, below Orion's corner and clear of the corner trios.
func _add_loose(run: RunState, count: int) -> void:
	for i: int in count:
		run.add_star(Star.Size.BIG, Vector2i(14 + 12 * (i % 2), 160 + 9 * (i / 2)))


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
