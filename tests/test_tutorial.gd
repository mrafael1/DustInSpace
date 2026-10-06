extends GutTest
## The guided first run (Tutorial): only the launches are gated (each launch step's own), the
## first packs are scripted, links and buys go through at any step, and the steps move on as the
## player does what they say.

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
	assert_eq(steps, [Tutorial.Step.GOAL] as Array[int], "it announces its first step: the goal")
	# The goal: nothing but a tap on.
	assert_false(run.launch(Vector2i(90, 160)), "the goal only explains")
	assert_eq(run.link([1, 2, 3]), Combos.INVALID)
	assert_true(run.tutorial_continue())
	assert_eq(steps.back(), Tutorial.Step.LAUNCH)
	assert_false(run.tutorial_continue(), "only the showing steps go on by a tap")
	# Step 1: only a launch, of a blue planet.
	assert_false(run.load_pack("red"), "no switching packs yet")
	assert_false(run.buy("blue"), "no dust yet")
	assert_eq(run.loaded_pack, "blue")
	var dust: int = run.dust
	assert_true(run.launch(Vector2i(90, 160)))
	assert_eq(_sizes(run.stars), [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG] as Array[int], "a sequence")
	assert_eq(steps.back(), Tutorial.Step.LINK)
	# Step 2: only a link.
	assert_false(run.launch(Vector2i(90, 160)), "no launch while linking")
	assert_ne(run.link(_order(run, _ids(run.stars))), Combos.INVALID)
	# The payout, shown as it lands: the dust, then the Sun. Each only shows; it goes on by itself.
	assert_eq(steps.back(), Tutorial.Step.DUST)
	assert_false(run.launch(Vector2i(90, 160)), "the payout steps only show")
	assert_true(run.tutorial_continue())
	assert_eq(steps.back(), Tutorial.Step.SUN)
	assert_true(run.tutorial_continue())
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
	var landmark: int = run.tutorial.landmark
	assert_ne(run.link(_order(run, _pair_and(run, size, landmark))), Combos.INVALID)
	assert_true(run.scorpio.is_lit(landmark))
	assert_gt(run.dust, dust)
	# The red planet the run started with drops in: where the loaded planet shows, then its launch.
	assert_eq(steps.back(), Tutorial.Step.SCOPE)
	assert_eq(run.loaded_pack, "red", "in the slingshot")
	assert_false(run.launch(Vector2i(90, 120)), "the showing steps only show")
	assert_true(run.tutorial_continue())
	assert_eq(steps.back(), Tutorial.Step.ICON)
	assert_true(run.tutorial_continue())
	assert_eq(steps.back(), Tutorial.Step.RED)
	assert_false(run.load_pack("blue"), "the red planet stays loaded")
	var before: int = run.stars.size()
	assert_true(run.launch(Vector2i(90, 120)))
	var red: Array[Star] = run.stars.slice(before)
	assert_eq(red.size(), run.balance.packs["red"].stars * run.balance.packs["red"].bursts)
	assert_gt(_sizes(red).count(Star.Size.BIG), _sizes(red).count(Star.Size.SMALL), "more big stars")
	# Its link fills the Sun (the guided run's own target the first time), and it lights a star.
	assert_eq(steps.back(), Tutorial.Step.RED_LINK)
	assert_eq(run.light_target(), 40, "the guided run's first Sun")
	var next: int = run.rekindle_target()
	assert_ne(run.link(_order(run, _three_of(run, Star.Size.BIG))), Combos.INVALID)
	assert_eq(steps.back(), Tutorial.Step.SUN_FULL)
	assert_eq(run.tutorial.landmark, next, "the star the full Sun lit")
	assert_true(run.scorpio.is_lit(next))
	assert_eq(run.light_target(), 75, "then the stage's own")
	assert_true(run.tutorial_continue())
	# Step 5: out of planets, buy a blue one, only.
	assert_eq(steps.back(), Tutorial.Step.BUY)
	assert_eq(run.total_packs(), 0)
	assert_false(run.launch(Vector2i(90, 160)))
	assert_true(run.buy("blue"))
	assert_eq(run.loaded_pack, "blue")
	assert_eq(steps.back(), Tutorial.Step.DONE)
	assert_true(run.tutorial.is_done())
	# Free play: anything goes, packs are drawn as usual.
	assert_true(run.launch(Vector2i(90, 160)))
	assert_eq(run.loaded_pack, "", "and a launch leaves the slingshot empty, like any run")


func test_a_buy_it_cant_afford_skips_to_free_play() -> void:
	var tutorial := Tutorial.new()
	tutorial.step = Tutorial.Step.RED_LINK
	assert_true(tutorial.linked(false, -1, false, false, 3))
	assert_eq(tutorial.step, Tutorial.Step.SUN_FULL, "the full Sun is still shown")
	assert_eq(tutorial.landmark, 3)
	assert_true(tutorial.continue_info())
	assert_true(tutorial.is_done(), "no stuck buy step")


func test_a_red_link_that_doesnt_fill_the_sun_goes_on_to_the_buy() -> void:
	var tutorial := Tutorial.new()
	tutorial.step = Tutorial.Step.RED_LINK
	assert_true(tutorial.linked(false, -1, false, true, -1))
	assert_eq(tutorial.step, Tutorial.Step.BUY, "no full Sun to show")


func test_the_guided_suns_own_target_is_optional() -> void:
	var data: Dictionary = _data()
	(data["scorpio"] as Dictionary).erase("tutorial_sun_target")
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	run.start_tutorial()
	assert_eq(run.light_target(), 75)
	data["scorpio"]["tutorial_sun_target"] = 0
	assert_false(Balance.from_dict(data).is_valid(), "at least 1 when given")
	assert_eq(Balance.load_file(Balance.DEFAULT_PATH).scorpio_tutorial_sun_target, 40, "shipped")
	assert_eq(_run(false).light_target(), 75, "an unguided run keeps the stage's")


func test_without_a_red_planet_the_red_launch_is_skipped() -> void:
	var data: Dictionary = _data()
	data["start_packs"] = {"blue": 2, "red": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	run.start_tutorial()
	_play_to_light(run)
	assert_eq(run.tutorial.step, Tutorial.Step.BUY)


func test_a_buy_goes_through_at_any_step_without_moving_it_on() -> void:
	var run: RunState = _run()
	_play_to_light(run)
	assert_eq(run.tutorial.step, Tutorial.Step.SCOPE)
	var blue: int = run.owned_packs["blue"]
	var dust: int = run.dust
	assert_true(run.buy("blue"), "a showing step lets a buy through")
	assert_eq(run.dust, dust - run.balance.packs["blue"].cost)
	assert_eq(run.owned_packs["blue"], blue + 1)
	assert_eq(run.tutorial.step, Tutorial.Step.SCOPE, "only the buy step moves on")
	assert_eq(run.loaded_pack, "red", "the scripted red launch keeps its planet")
	run.tutorial_continue()
	run.tutorial_continue()
	assert_eq(run.tutorial.step, Tutorial.Step.RED)
	assert_true(run.launch(Vector2i(90, 120)), "the red launch still goes")
	assert_eq(run.tutorial.step, Tutorial.Step.RED_LINK)


func test_a_sky_link_that_fills_the_sun_at_the_light_step_moves_on() -> void:
	# Review (PR #86): a sky-only sequence at the light step filled the Sun and cleared the sky, and
	# the step waited for a link that could no longer be made.
	var run: RunState = _run_to_light()
	var three: Array[int] = _add_sequence(run)
	run.light = run.light_target() - 1
	assert_ne(run.link(three), Combos.INVALID)
	assert_true(run.stars.is_empty(), "the full Sun cleared the sky")
	assert_eq(run.tutorial.step, Tutorial.Step.SCOPE, "a star was lit by the full Sun: on to the red planet")
	run.tutorial_continue()
	run.tutorial_continue()
	assert_true(run.launch(Vector2i(90, 120)), "and the red launch goes")


func test_the_reviewed_path_with_shipped_balance_reaches_the_red_planet() -> void:
	# Review (PR #86), as played: shipped balance, seed 0. The first link takes the small
	# constellation star and the medium and big sky stars, which leaves a small one; at the light
	# step a sky-only sequence then fills the Sun and clears the sky.
	var run := RunState.new(Balance.load_file(Balance.DEFAULT_PATH), Fixtures.rng(0), Fixtures.SKY, StarMap.stinger())
	run.tutorial_step.connect(func(step: int) -> void: steps.append(step))
	run.start_tutorial()
	run.tutorial_continue()
	var first: int = run.rekindle_target()
	assert_true(run.launch(run.scorpio.landmark_position(first)))
	var mb: Array[int] = []
	for star: Star in run.stars:
		if star.size != Star.Size.SMALL:
			mb.append(star.id)
	mb.append(Scorpio.landmark_id(first))
	assert_ne(run.link(_order(run, mb)), Combos.INVALID, "the constellation star with the medium and big")
	assert_eq(run.stars.size(), 1, "the small sky star is left")
	run.tutorial_continue()
	run.tutorial_continue()
	assert_true(run.launch(run.scorpio.landmark_position(run.tutorial.landmark)))
	assert_eq(run.tutorial.step, Tutorial.Step.LIGHT)
	var sequence: Array[int] = _sky_sequence(run)
	assert_eq(sequence.size(), 3, "a sky-only sequence in reach")
	assert_ne(run.link(sequence), Combos.INVALID)
	assert_true(run.stars.is_empty(), "its full Sun cleared the sky")
	assert_ne(run.tutorial.step, Tutorial.Step.LIGHT, "not stranded")
	while Tutorial.is_info(run.tutorial.step):
		run.tutorial_continue()
	assert_eq(run.tutorial.step, Tutorial.Step.RED)
	assert_true(run.launch(Vector2i(90, 160)), "the red launch goes")


func test_a_link_that_strands_the_light_step_moves_on() -> void:
	var run: RunState = _run_to_light()
	var size: int = run.scorpio.map.sizes[run.tutorial.landmark]
	var pair: Array[int] = []
	for star: Star in run.stars:
		if star.size == size:
			pair.append(star.id)
	var third: Star = run.add_star(size as Star.Size, run.find_star(pair[0]).position + Vector2i(6, 6))
	run.light = 0
	assert_ne(run.link(_order(run, [pair[0], pair[1], third.id])), Combos.INVALID, "a sky triple of its size")
	assert_false(run.has_remaining_combo())
	assert_eq(run.tutorial.step, Tutorial.Step.SCOPE, "nothing left to light it with: on")


func test_a_sky_link_that_leaves_the_lesson_keeps_the_light_step() -> void:
	var run: RunState = _run_to_light()
	var three: Array[int] = _add_sequence(run)
	run.light = 0
	assert_ne(run.link(three), Combos.INVALID, "links go through")
	assert_eq(run.tutorial.step, Tutorial.Step.LIGHT, "its pair and the star are still there")


func test_only_the_buy_step_moves_on_by_a_buy() -> void:
	var tutorial := Tutorial.new()
	for step: Tutorial.Step in [Tutorial.Step.GOAL, Tutorial.Step.LAUNCH, Tutorial.Step.LINK, Tutorial.Step.DUST, Tutorial.Step.SCOPE, Tutorial.Step.RED, Tutorial.Step.SUN_FULL]:
		tutorial.step = step
		assert_false(tutorial.bought(), "step %d" % step)
		assert_eq(tutorial.step, step)
	tutorial.step = Tutorial.Step.BUY
	assert_true(tutorial.bought())
	assert_true(tutorial.is_done())


func test_a_link_goes_through_at_a_showing_step_without_moving_it_on() -> void:
	var run: RunState = _run()
	run.tutorial_continue()
	run.launch(Vector2i(90, 160))
	# The sequence's stars stay in the sky while the payout steps show (as if linked another way).
	run.tutorial.step = Tutorial.Step.DUST
	assert_ne(run.link(_order(run, _ids(run.stars))), Combos.INVALID, "a showing step lets a link through")
	assert_eq(run.tutorial.step, Tutorial.Step.DUST)


func test_only_the_showing_steps_wait() -> void:
	for step: int in [Tutorial.Step.GOAL, Tutorial.Step.DUST, Tutorial.Step.SUN, Tutorial.Step.SCOPE, Tutorial.Step.ICON, Tutorial.Step.SUN_FULL]:
		assert_true(Tutorial.is_info(step))
		assert_false(Tutorial.aims(step), "no aiming while it shows")
	assert_false(Tutorial.is_timed(Tutorial.Step.GOAL), "the goal waits for a tap")
	assert_true(Tutorial.is_timed(Tutorial.Step.DUST), "the payout goes on by itself")
	for step: int in [Tutorial.Step.SUN, Tutorial.Step.SCOPE, Tutorial.Step.ICON, Tutorial.Step.SUN_FULL]:
		assert_true(Tutorial.is_timed(step))
	for step: int in [Tutorial.Step.LAUNCH, Tutorial.Step.LINK, Tutorial.Step.LIGHT, Tutorial.Step.RED, Tutorial.Step.RED_LINK, Tutorial.Step.BUY, Tutorial.Step.DONE]:
		assert_false(Tutorial.is_info(step))


func test_only_the_aiming_steps_aim() -> void:
	assert_true(Tutorial.aims(Tutorial.Step.LAUNCH))
	assert_true(Tutorial.aims(Tutorial.Step.LAUNCH_NEAR))
	assert_true(Tutorial.aims(Tutorial.Step.RED))
	assert_true(Tutorial.aims(Tutorial.Step.DONE))
	assert_false(Tutorial.aims(Tutorial.Step.LINK))
	assert_false(Tutorial.aims(Tutorial.Step.LIGHT))
	assert_false(Tutorial.aims(Tutorial.Step.BUY))


func test_the_scripted_packs_fit_any_pack_size() -> void:
	var tutorial := Tutorial.new()
	tutorial.step = Tutorial.Step.LAUNCH
	assert_eq(tutorial.pack_sizes(3, Star.Size.SMALL).size(), 3)
	assert_eq(tutorial.pack_sizes(6, Star.Size.SMALL).size(), 6, "a twin burst gets six")
	tutorial.step = Tutorial.Step.RED
	assert_eq(tutorial.pack_sizes(6, Star.Size.SMALL), Tutorial.RED_PACK, "the red one's twin bursts")
	assert_eq(tutorial.pack_sizes(4, Star.Size.SMALL).size(), 4)
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
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "tutorial_sun_target": 40, "max_link_distance": 56}
	return data


## Plays the guided run up to lighting the constellation star (the light step's link made).
func _play_to_light(run: RunState) -> void:
	run.tutorial_continue()
	run.launch(Vector2i(90, 160))
	run.link(_order(run, _ids(run.stars)))
	run.tutorial_continue()
	run.tutorial_continue()
	var landmark: int = run.tutorial.landmark
	run.launch(run.scorpio.landmark_position(landmark))
	run.link(_order(run, _pair_and(run, run.scorpio.map.sizes[landmark], landmark)))


## A small, a medium and a big sky star (no constellation star) in an order in reach, or [].
func _sky_sequence(run: RunState) -> Array[int]:
	for a: Star in run.stars:
		for b: Star in run.stars:
			for c: Star in run.stars:
				var order: Array[int] = [a.id, b.id, c.id]
				if [a.size, b.size, c.size].has(Star.Size.SMALL) and [a.size, b.size, c.size].has(Star.Size.MEDIUM) and [a.size, b.size, c.size].has(Star.Size.BIG) and run.link_in_reach(order):
					return order
	return []


## A guided run at the light step: the near pack launched by its constellation star.
func _run_to_light() -> RunState:
	var run: RunState = _run()
	run.tutorial_continue()
	run.launch(Vector2i(90, 160))
	run.link(_order(run, _ids(run.stars)))
	run.tutorial_continue()
	run.tutorial_continue()
	run.launch(run.scorpio.landmark_position(run.tutorial.landmark))
	assert_eq(run.tutorial.step, Tutorial.Step.LIGHT)
	return run


## Adds a small, a medium and a big star close together (a sequence in reach); returns their ids.
func _add_sequence(run: RunState) -> Array[int]:
	var at: Vector2i = run.sky_rect.position + Vector2i(20, 20)
	var ids: Array[int] = []
	for k: int in 3:
		ids.append(run.add_star(k as Star.Size, at + Vector2i(10 * k, 0)).id)
	return ids


## Three sky stars of `size`.
func _three_of(run: RunState, size: int) -> Array[int]:
	var ids: Array[int] = []
	for star: Star in run.stars:
		if star.size == size and ids.size() < 3:
			ids.append(star.id)
	return ids


## Two sky stars of `size` and the landmark: the light step's link.
func _pair_and(run: RunState, size: int, landmark: int) -> Array[int]:
	var ids: Array[int] = []
	for star: Star in run.stars:
		if star.size == size and ids.size() < 2:
			ids.append(star.id)
	ids.append(Scorpio.landmark_id(landmark))
	return ids


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
