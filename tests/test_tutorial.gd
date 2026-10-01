extends GutTest
## The guided first run (Tutorial): each step allows only its own action, the first two packs are
## scripted, and the steps move on as the player does what they say.

const Fixtures := preload("res://tests/fixtures.gd")

var steps: Array[int] = []


func before_each() -> void:
	steps.clear()


func test_no_tutorial_no_gates() -> void:
	var run: RunState = _run(false)
	assert_null(run.tutorial)
	assert_true(run.load_pack("red"), "loading is free")


func test_the_whole_tutorial() -> void:
	var run: RunState = _run()
	assert_eq(steps, [Tutorial.Step.LAUNCH] as Array[int], "it announces its first step")
	# Step 1: only a launch.
	assert_false(run.load_pack("red"), "no switching packs yet")
	assert_false(run.buy("blue"), "no buying yet")
	var dust: int = run.dust
	assert_true(run.launch(Vector2i(90, 160)))
	assert_eq(_sizes(run.stars), [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG] as Array[int], "a sequence")
	assert_eq(steps.back(), Tutorial.Step.LINK)
	# Step 2: only a link.
	assert_false(run.launch(Vector2i(90, 160)), "no launch while linking")
	assert_ne(run.link(_order(run, _ids(run.stars))), Combos.INVALID)
	assert_eq(steps.back(), Tutorial.Step.LAUNCH_NEAR)
	assert_eq(run.tutorial.landmark, run.rekindle_target(), "the next star to light")
	# Step 3: launch next to that star, only.
	var at: Vector2i = run.scorpio.landmark_position(run.tutorial.landmark)
	var packs: int = run.total_packs()
	assert_false(run.launch(at + Vector2i(60, -40)), "too far from it")
	assert_eq(run.total_packs(), packs, "a refused launch uses nothing")
	assert_true(run.launch(at + Vector2i(10, -10)))
	var size: int = run.scorpio.map.sizes[run.tutorial.landmark]
	assert_eq(_sizes(run.stars).count(size), 2, "two stars of its size")
	assert_eq(steps.back(), Tutorial.Step.LIGHT)
	# Step 4: link it with two of them.
	var pair: Array[int] = []
	for star: Star in run.stars:
		if star.size == size and pair.size() < 2:
			pair.append(star.id)
	var landmark: int = run.tutorial.landmark
	assert_ne(run.link(_order(run, [pair[0], pair[1], Scorpio.landmark_id(landmark)])), Combos.INVALID)
	assert_true(run.scorpio.is_lit(landmark))
	assert_eq(steps.back(), Tutorial.Step.BUY)
	assert_gt(run.dust, dust)
	# Step 5: buy a blue planet, only.
	assert_false(run.buy("red"))
	assert_false(run.launch(Vector2i(90, 160)))
	assert_true(run.buy("blue"))
	assert_eq(run.loaded_pack, "blue")
	assert_eq(steps.back(), Tutorial.Step.DONE)
	assert_true(run.tutorial.is_done())
	# Free play: anything goes, packs are drawn as usual.
	assert_true(run.load_pack("red"))
	assert_true(run.launch(Vector2i(90, 160)))


func test_a_buy_it_cant_afford_skips_to_free_play() -> void:
	var data: Dictionary = _data()
	data["packs"]["blue"]["cost"] = 99
	data["packs"]["red"]["cost"] = 99
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	run.start_tutorial()
	run.launch(Vector2i(90, 160))
	run.link(_order(run, _ids(run.stars)))
	var at: Vector2i = run.scorpio.landmark_position(run.tutorial.landmark)
	run.launch(at)
	var size: int = run.scorpio.map.sizes[run.tutorial.landmark]
	var pair: Array[int] = []
	for star: Star in run.stars:
		if star.size == size and pair.size() < 2:
			pair.append(star.id)
	run.link(_order(run, [pair[0], pair[1], Scorpio.landmark_id(run.tutorial.landmark)]))
	assert_true(run.tutorial.is_done(), "no stuck buy step")


func test_only_the_aiming_steps_aim() -> void:
	assert_true(Tutorial.aims(Tutorial.Step.LAUNCH))
	assert_true(Tutorial.aims(Tutorial.Step.LAUNCH_NEAR))
	assert_true(Tutorial.aims(Tutorial.Step.DONE))
	assert_false(Tutorial.aims(Tutorial.Step.LINK))
	assert_false(Tutorial.aims(Tutorial.Step.LIGHT))
	assert_false(Tutorial.aims(Tutorial.Step.BUY))


func test_the_scripted_packs_fit_any_pack_size() -> void:
	var tutorial := Tutorial.new()
	assert_eq(tutorial.pack_sizes(3, Star.Size.SMALL).size(), 3)
	assert_eq(tutorial.pack_sizes(6, Star.Size.SMALL).size(), 6, "a twin burst gets six")
	tutorial.step = Tutorial.Step.LINK
	assert_eq(tutorial.pack_sizes(3, Star.Size.SMALL), [] as Array[int], "no script outside the launch steps")


func _run(with_tutorial: bool = true) -> RunState:
	var run := RunState.new(Balance.from_dict(_data()), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	run.tutorial_step.connect(func(step: int) -> void: steps.append(step))
	if with_tutorial:
		run.start_tutorial()
	return run


func _data() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	return data


func _ids(stars: Array[Star]) -> Array[int]:
	var ids: Array[int] = []
	for star: Star in stars:
		ids.append(star.id)
	return ids


func _sizes(stars: Array[Star]) -> Array[int]:
	var sizes: Array[int] = []
	for star: Star in stars:
		sizes.append(star.size)
	return sizes


## An order of `ids` whose every step is in reach.
func _order(run: RunState, ids: Array[int]) -> Array[int]:
	for p: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var order: Array[int] = [ids[p[0]], ids[p[1]], ids[p[2]]]
		if run.link_in_reach(order):
			return order
	return ids
