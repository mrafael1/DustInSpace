extends GutTest
## Orion (#64), the Tail stage's twist: after a pack bursts he marks a loose sky star, and on the
## next launch, before that pack opens, his arrow destroys it if it's still there. For nothing.

const Fixtures := preload("res://tests/fixtures.gd")
const LauncherScene := preload("res://game/scenes/launcher.tscn")

## Far from every Tail landmark (more than the link reach): stars here only link with each other.
const CORNER := Vector2i(24, 100)

var events: Array[StringName] = []


func before_each() -> void:
	events.clear()


func test_balance_reads_orion_and_leaves_him_out_without_a_block() -> void:
	assert_eq(Fixtures.balance().orion_first_mark_launch, 0, "no block: no Orion")
	assert_eq(_balance().orion_first_mark_launch, 2)
	var data: Dictionary = Fixtures.balance_dict()
	data["orion"] = {"first_mark_launch": 0}
	assert_false(Balance.from_dict(data).is_valid(), "he marks from launch 1 at the earliest")
	data["orion"] = {}
	assert_false(Balance.from_dict(data).is_valid())
	assert_eq(Balance.load_file().orion_first_mark_launch, 2, "shipped: the intro marks on launch 2")


func test_only_the_tail_brings_orion() -> void:
	assert_not_null(_tail_run().orion)
	assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, StarMap.stinger()).orion)
	assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, StarMap.scorpio()).orion)
	assert_null(RunState.new(Fixtures.balance(_scorpio_on()), Fixtures.rng(), Fixtures.SKY, StarMap.tail()).orion, "nor without his tuning")


func test_the_intro_marks_on_launch_two_and_shoots_before_launch_three_bursts() -> void:
	var run: RunState = _tail_run()
	_record(run)
	var marked: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marked.append(star))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	run.launch(Vector2i(90, 150))
	assert_true(marked.is_empty(), "launch 1 is normal")
	assert_false(events.has(&"star_marked"))
	run.launch(Vector2i(90, 150))
	assert_eq(marked.size(), 1, "launch 2: Orion marks one star")
	assert_true(run.stars.has(marked[0]), "a loose star in the sky")
	assert_eq(run.marked_star(), marked[0])
	assert_eq(events.slice(-3), [&"pack_launched", &"pack_burst", &"star_marked"] as Array[StringName], "marked after the burst")
	var dust: int = run.dust
	var light: int = run.light
	events.clear()
	run.launch(Vector2i(90, 150))
	assert_eq(shot, [marked[0]] as Array[Star], "launch 3: the arrow takes it")
	assert_false(run.stars.has(marked[0]))
	assert_eq([run.dust, run.light], [dust, light], "for nothing")
	assert_eq(events.slice(0, 3), [&"pack_launched", &"star_shot", &"pack_burst"] as Array[StringName], "before the new pack opens")
	assert_eq(marked.size(), 2, "then he marks the next one")
	assert_ne(marked[1], marked[0])


func test_a_target_collected_in_time_pays_and_is_safe() -> void:
	var run: RunState = _tail_run()
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_launch_until_marked(run)
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	var dust: int = run.dust
	var combo: String = run.link([target.id, a.id, b.id] as Array[int])
	assert_ne(combo, Combos.INVALID)
	assert_eq(run.dust, dust + run.balance.combos[combo].dust, "it pays normally")
	assert_false(run.stars.has(target))
	assert_ne(run.orion.target, target.id, "that mark is gone")
	run.launch(Vector2i(90, 150))
	assert_false(shot.has(target), "the saved star isn't shot")


func test_linking_the_target_is_a_move_orion_marks_again() -> void:
	var run: RunState = _tail_run()
	var marked: Array[Star] = []
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_launch_until_marked(run)
	run.star_marked.connect(func(star: Star) -> void: marked.append(star))
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	_record(run)
	run.link([target.id, a.id, b.id] as Array[int])
	assert_eq(marked.size(), 1, "the link was a move: a new mark")
	assert_true(run.stars.has(marked[0]), "on a loose star still in the sky")
	assert_eq(run.marked_star(), marked[0])
	assert_eq(events[-1], &"star_marked", "after the combo resolves")
	run.launch(Vector2i(90, 150))
	assert_eq(shot, [marked[0]] as Array[Star], "the next launch shoots the new mark")


func test_an_unrelated_link_keeps_the_mark() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	var target: int = run.orion.target
	var marks: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marks.append(star))
	var trio: Array[int] = _corner_trio(run)
	assert_false(trio.has(target))
	assert_ne(run.link(trio), Combos.INVALID)
	assert_eq(run.orion.target, target, "the threat doesn't jump")
	assert_true(marks.is_empty(), "no new mark")


func test_a_link_before_the_intro_launch_marks_nothing() -> void:
	var run: RunState = _tail_run()
	run.launch(Vector2i(90, 150))
	var marks: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marks.append(star))
	run.add_star(Star.Size.BIG, CORNER + Vector2i(0, 30))
	run.link(_corner_trio(run))
	assert_true(marks.is_empty(), "Orion starts on launch %d" % run.orion.first_mark_launch)
	assert_false(run.orion.has_target())


func test_a_link_that_empties_the_sky_leaves_nothing_to_mark() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	run.stars.clear()
	run.orion.forget([run.orion.target] as Array[int])
	run.link(_corner_trio(run))
	assert_true(run.stars.is_empty())
	assert_false(run.orion.has_target())


func test_an_uncollected_target_is_destroyed_once() -> void:
	var run: RunState = _tail_run(10)
	var shot: Array[int] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star.id))
	var marks: Array[int] = []
	run.star_marked.connect(func(star: Star) -> void: marks.append(star.id))
	for launch: int in 8:
		run.launch(Vector2i(90, 150))
	assert_eq(marks.size(), 7, "one mark after every burst from launch 2")
	assert_eq(shot, marks.slice(0, 6), "each mark shot on the next launch, in order")
	for id: int in shot:
		assert_eq(shot.count(id), 1, "star %d destroyed once" % id)
		assert_null(run.find_star(id))
	assert_eq(run.marked_star().id, marks[-1], "one target at a time: the last mark waits")


func test_an_invalid_link_or_a_failed_launch_doesnt_advance_orion() -> void:
	var run: RunState = _tail_run(2)
	_launch_until_marked(run)
	var target: int = run.orion.target
	assert_eq(run.link([target, 999, 998] as Array[int]), Combos.INVALID)
	assert_eq([run.orion.launches, run.orion.target], [2, target], "an invalid link changes nothing")
	assert_false(run.launch(Vector2i(90, 150)), "no pack left")
	assert_eq([run.orion.launches, run.orion.target], [2, target], "nor does a launch that can't happen")
	assert_not_null(run.find_star(target))


func test_a_cancelled_aim_doesnt_advance_orion() -> void:
	var run: RunState = _tail_run()
	var sequencer := EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	var launcher: Launcher = LauncherScene.instantiate()
	launcher.position = Vector2(90, 270)
	add_child_autofree(launcher)
	launcher.set_process(false)
	launcher.setup(run, sequencer)
	var press := InputEventScreenTouch.new()
	press.pressed = true
	launcher.handle_pointer(press)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(2, 2)
	launcher.handle_pointer(drag)
	launcher.handle_pointer(InputEventScreenTouch.new())
	assert_eq(run.orion.launches, 0, "a short pull launches nothing")
	launcher.handle_pointer(press)
	drag.position = Vector2(0, Launcher.MAX_PULL)
	launcher.handle_pointer(drag)
	launcher.handle_pointer(InputEventScreenTouch.new())
	assert_eq(run.orion.launches, 1, "a real launch does")


func test_a_restart_clears_the_mark() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	var again: RunState = _tail_run()
	assert_false(again.orion.has_target())
	assert_eq(again.orion.launches, 0)
	assert_null(again.marked_star())


func test_the_same_seed_marks_the_same_stars() -> void:
	var picks: Array[Array] = []
	for attempt: int in 2:
		var run: RunState = _tail_run(8, 42)
		var marks: Array[int] = []
		run.star_marked.connect(func(star: Star) -> void: marks.append(star.id))
		for launch: int in 6:
			run.launch(Vector2i(90, 150))
		picks.append(marks)
	assert_eq(picks[0], picks[1])


func test_orion_marks_loose_stars_only_never_landmarks() -> void:
	for seed_value: int in range(1, 21):
		var run: RunState = _tail_run(8, seed_value)
		run.star_marked.connect(func(star: Star) -> void:
			assert_false(run.scorpio.is_landmark(star.id), "seed %d: never a landmark" % seed_value)
			assert_true(run.stars.has(star), "seed %d: a star in the sky" % seed_value))
		for launch: int in 6:
			run.launch(Vector2i(40 + 20 * launch, 120 + 15 * launch))


func test_a_sun_clear_takes_the_target_and_the_arrow_has_nothing_to_hit() -> void:
	var run: RunState = _tail_run()
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_launch_until_marked(run)
	var target: Star = run.marked_star()
	run.light = run.light_target() - 1
	var trio: Array[int] = _corner_trio(run)
	run.link(trio)
	assert_false(run.stars.has(target), "the rekindled Sun cleared the sky")
	assert_false(run.orion.has_target(), "and the mark with it")
	run.launch(Vector2i(90, 150))
	assert_true(shot.is_empty())


func test_a_big_bang_leaves_nothing_to_mark() -> void:
	var run: RunState = _tail_run()
	var marked: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marked.append(star))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	run.launch(Vector2i(90, 150))
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	assert_true(run.stars.is_empty())
	assert_true(marked.is_empty(), "no eligible star: no mark")
	assert_false(run.orion.has_target())
	run.launch(Vector2i(90, 150))
	assert_true(shot.is_empty(), "so nothing to shoot")
	assert_eq(marked.size(), 1, "the next burst gets a mark")


func test_a_big_bang_on_the_arrow_launch_comes_after_the_shot() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	var target: Star = run.marked_star()
	var cleared: Array[Star] = []
	run.big_bang_started.connect(func(_at: Vector2i, stars: Array[Star], _dust: int) -> void: cleared.append_array(stars))
	_record(run)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	assert_eq(events.slice(0, 3), [&"pack_launched", &"star_shot", &"big_bang_started"] as Array[StringName])
	assert_false(cleared.has(target), "the arrow's star isn't paid by the Big Bang")


func test_completing_the_tail_clears_the_mark_and_wins() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	var won: Array[bool] = []
	run.run_won.connect(func() -> void: won.append(true))
	for index: int in range(1, run.scorpio.map.count()):
		var size: int = run.scorpio.map.sizes[index]
		var at: Vector2i = run.scorpio.landmark_position(index)
		var a: Star = run.add_star(size as Star.Size, at + Vector2i(-8, 0))
		var b: Star = run.add_star(size as Star.Size, at + Vector2i(0, -8))
		assert_ne(run.link([a.id, b.id, Scorpio.landmark_id(index)] as Array[int]), Combos.INVALID, "tail star %d" % index)
	assert_eq(won, [true])
	assert_false(run.orion.has_target(), "the completion cleared the sky, the mark with it")
	assert_false(run.launch(Vector2i(90, 150)), "the run is over")


func test_the_loss_check_sees_the_sky_after_the_arrow() -> void:
	# One pack left, no dust, three small stars in a corner: a combo, so the run goes on. Orion marks
	# one of them; the last launch opens a single big star: the arrow broke the only combo.
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": 1, "red": 0}
	data["packs"]["blue"] = {"cost": 4, "stars": 1, "weights": {"small": 0, "medium": 0, "big": 1}, "big_bang_chance": 0.0}
	data["orion"] = {"first_mark_launch": 1}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.tail())
	var trio: Array[int] = _corner_trio(run)
	run.orion.target = trio[2]
	assert_true(run.has_remaining_combo())
	_record(run)
	run.launch(CORNER + Vector2i(0, 30))
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust, no combo after the shot")
	assert_eq(events.find(&"star_shot"), 1)
	assert_eq(events[-1], &"run_lost", "decided once, at the end of the launch")
	assert_eq(events.count(&"run_lost"), 1)


func test_a_collected_target_keeps_the_run_alive() -> void:
	# The same corner, but the marked star is linked before the launch: nothing to shoot.
	var run: RunState = _tail_run(3)
	var trio: Array[int] = _corner_trio(run)
	run.orion.target = trio[2]
	run.link(trio)
	assert_false(run.orion.has_target())
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_the_tail_map_is_a_curling_tail_with_room_for_orion() -> void:
	var map: StarMap = StarMap.tail()
	assert_eq(StarMap.by_id("tail").id, "tail")
	assert_eq(map.title, "TAIL")
	assert_true(map.orion)
	assert_false(StarMap.stinger().orion)
	assert_eq(map.count(), 6)
	assert_eq(map.starting_lit, [0] as Array[int], "five to light")
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(CORNER)), 56.0, "the corner is Orion's")
	for segment: int in map.segment_count():
		var ends: Array[Vector2i] = map.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 24.0, 40.0)
	var drawing: Array[Vector2i] = ConstellationView.scorpion_drawing(map)
	assert_gt(drawing.size(), 40, "a bulb on each string")
	for p: Vector2i in drawing:
		assert_true(Scorpio.HOME_SKY.has_point(p))
	assert_eq(ConstellationView.song_order(map).size(), 5)


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data.merge(_scorpio_on(), true)
	data["orion"] = {"first_mark_launch": 2}
	return data


func _scorpio_on() -> Dictionary:
	return {"scorpio": {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}}


func _balance() -> Balance:
	return Balance.from_dict(_balance_dict())


func _tail_run(packs: int = 6, seed_value: int = 1) -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": packs, "red": 0}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.tail())


func _launch_until_marked(run: RunState) -> void:
	while not run.orion.has_target():
		assert_true(run.launch(Vector2i(90, 150)))


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
