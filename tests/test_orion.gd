extends GutTest
## Orion (#64), the Tail stage's twist: he keeps a loose sky star marked; the next successful link
## saves it if it uses it, or has his arrow destroy it (for nothing) if it leaves it behind. Then he
## marks a new one. Launches never fire.

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
	assert_eq(Balance.load_file().orion_first_mark_launch, 1, "shipped: the intro marks on launch 1")


func test_only_the_tail_brings_orion() -> void:
	assert_not_null(_tail_run().orion)
	assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, StarMap.stinger()).orion)
	assert_null(RunState.new(_balance(), Fixtures.rng(), Fixtures.SKY, StarMap.scorpio()).orion)
	assert_null(RunState.new(Fixtures.balance(_scorpio_on()), Fixtures.rng(), Fixtures.SKY, StarMap.tail()).orion, "nor without his tuning")


func test_the_intro_marks_on_launch_two_and_launches_never_fire() -> void:
	var run: RunState = _tail_run()
	_record(run)
	var marked: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marked.append(star))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	run.launch(Vector2i(90, 150))
	assert_true(marked.is_empty(), "launch 1 is normal")
	run.launch(Vector2i(90, 150))
	assert_eq(marked.size(), 1, "launch 2: Orion marks one star")
	assert_true(run.stars.has(marked[0]), "a loose star in the sky")
	assert_eq(run.marked_star(), marked[0])
	assert_eq(events.slice(-3), [&"pack_launched", &"pack_burst", &"star_marked"] as Array[StringName], "marked after the burst")
	for launch: int in 2:
		run.launch(Vector2i(90, 150))
	assert_true(shot.is_empty(), "a launch never fires")
	assert_eq(marked.size(), 1, "and keeps the standing mark")
	assert_eq(run.marked_star(), marked[0])


func test_a_link_using_the_target_saves_it_and_orion_marks_again() -> void:
	var run: RunState = _tail_run()
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_launch_until_marked(run)
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	assert_false(run.link_shoots([target.id, a.id, b.id] as Array[int]), "no arrow for this link")
	var dust: int = run.dust
	_record(run)
	var combo: String = run.link([target.id, a.id, b.id] as Array[int])
	assert_ne(combo, Combos.INVALID)
	assert_eq(run.dust, dust + run.balance.combos[combo].dust, "it pays normally")
	assert_true(shot.is_empty(), "saved: nothing shot")
	assert_true(run.orion.has_target(), "a new mark")
	assert_ne(run.orion.target, target.id)
	assert_true(run.stars.has(run.marked_star()))
	assert_eq(events[-1], &"star_marked", "once the link resolves")


func test_a_link_leaving_the_target_behind_has_it_shot() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	var target: Star = run.marked_star()
	var trio: Array[int] = _corner_trio(run)
	assert_true(run.link_shoots(trio))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	var dust: int = run.dust
	var light: int = run.light
	var combo: String = run.link(trio)
	var reward: Balance.ComboReward = run.balance.combos[combo]
	assert_eq(shot, [target] as Array[Star], "the arrow takes the target")
	assert_false(run.stars.has(target))
	assert_eq([run.dust, run.light], [dust + reward.dust, light + reward.light], "the combo pays, the shot star nothing")
	assert_true(run.orion.has_target(), "then a new mark")
	assert_ne(run.orion.target, target.id)


func test_the_link_events_come_combo_then_shot_then_mark() -> void:
	var run: RunState = _tail_run()
	_launch_until_marked(run)
	var trio: Array[int] = _corner_trio(run)
	_record(run)
	run.link(trio)
	assert_eq(events, [&"combo_collected", &"star_shot", &"star_marked"] as Array[StringName])


func test_each_link_that_leaves_a_mark_shoots_it_once() -> void:
	var run: RunState = _tail_run(10)
	for launch: int in 4:
		run.launch(Vector2i(90, 150))
	var shot: Array[int] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star.id))
	var marks: Array[int] = [run.orion.target]
	run.star_marked.connect(func(star: Star) -> void: marks.append(star.id))
	for round_index: int in 3:
		run.link(_corner_trio(run))
	assert_eq(shot, marks.slice(0, 3), "each mark shot by the next link, in order")
	for id: int in shot:
		assert_eq(shot.count(id), 1, "star %d destroyed once" % id)
		assert_null(run.find_star(id))
	assert_eq(run.orion.target, marks[-1], "one target at a time: the last mark waits")


func test_an_invalid_link_or_a_failed_launch_doesnt_advance_orion() -> void:
	var run: RunState = _tail_run(2)
	_launch_until_marked(run)
	var target: int = run.orion.target
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	assert_eq(run.link([target, 999, 998] as Array[int]), Combos.INVALID)
	var big: Star = run.add_star(Star.Size.BIG, CORNER)
	var small: Star = run.add_star(Star.Size.SMALL, CORNER + Vector2i(10, 0))
	var other: Star = run.add_star(Star.Size.SMALL, CORNER + Vector2i(5, 8))
	assert_false(run.link_shoots([big.id, small.id, other.id] as Array[int]), "no arrow for a wrong combo")
	assert_eq(run.link([big.id, small.id, other.id] as Array[int]), Combos.INVALID)
	assert_eq([run.orion.launches, run.orion.target], [2, target], "an invalid link changes nothing")
	assert_true(shot.is_empty())
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
			_link_any(run)
		picks.append(marks)
	assert_gt(picks[0].size(), 2)
	assert_eq(picks[0], picks[1])


func test_orion_marks_loose_stars_only_never_landmarks() -> void:
	for seed_value: int in range(1, 21):
		var run: RunState = _tail_run(8, seed_value)
		run.star_marked.connect(func(star: Star) -> void:
			assert_false(run.scorpio.is_landmark(star.id), "seed %d: never a landmark" % seed_value)
			assert_true(run.stars.has(star), "seed %d: a star in the sky" % seed_value))
		for launch: int in 6:
			run.launch(Vector2i(40 + 20 * launch, 120 + 15 * launch))
			_link_any(run)


func test_a_link_before_the_intro_launch_marks_nothing() -> void:
	var run: RunState = _tail_run()
	run.launch(Vector2i(90, 150))
	run.add_star(Star.Size.BIG, CORNER + Vector2i(0, 30))
	run.link(_corner_trio(run))
	assert_false(run.orion.has_target(), "Orion starts on launch %d" % run.orion.first_mark_launch)


func test_a_sun_clear_takes_the_target_and_the_arrow_has_nothing_to_hit() -> void:
	var run: RunState = _tail_run()
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_launch_until_marked(run)
	var target: Star = run.marked_star()
	run.light = run.light_target() - 1
	var trio: Array[int] = _corner_trio(run)
	assert_false(run.link_shoots(trio), "the rekindle clears the sky first")
	run.link(trio)
	assert_false(run.stars.has(target), "the rekindled Sun cleared the sky")
	assert_true(shot.is_empty(), "nothing left to shoot")
	assert_false(run.orion.has_target(), "nor to mark")
	run.launch(Vector2i(90, 150))
	assert_true(run.orion.has_target(), "the next burst gets a mark")


func test_a_big_bang_takes_the_target_and_the_next_burst_is_marked() -> void:
	var run: RunState = _tail_run()
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_launch_until_marked(run)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	assert_true(run.stars.is_empty())
	assert_false(run.orion.has_target(), "no eligible star: no mark")
	run.launch(Vector2i(90, 150))
	assert_true(run.orion.has_target(), "the next burst gets one")
	assert_true(shot.is_empty())


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
	# No pack, no dust: three smalls in a corner and three mediums below, the target one of the
	# mediums. Linking the smalls leaves it behind: the arrow breaks the last combo.
	var run: RunState = _stuck_run()
	var mediums: Array[int] = _medium_trio(run)
	run.orion.target = mediums[2]
	var trio: Array[int] = _corner_trio(run)
	_record(run)
	run.link(trio)
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust, no combo after the shot")
	assert_eq(events, [&"combo_collected", &"star_shot", &"run_lost"] as Array[StringName], "decided after the arrow, no new mark")


func test_saving_the_target_keeps_the_run_alive() -> void:
	# The same sky, but the mediums with the target are linked: the smalls still make a combo.
	var run: RunState = _stuck_run()
	var mediums: Array[int] = _medium_trio(run)
	_corner_trio(run)
	run.orion.target = mediums[2]
	run.link(mediums)
	assert_eq(run.outcome, RunState.Outcome.PLAYING)
	assert_true(run.orion.has_target(), "a new mark on a small")


func test_link_shoots_only_for_a_valid_link_that_leaves_the_target() -> void:
	var run: RunState = _tail_run()
	var trio: Array[int] = _corner_trio(run)
	assert_false(run.link_shoots(trio), "no mark: no arrow")
	_launch_until_marked(run)
	assert_true(run.link_shoots(trio))
	assert_false(run.link_shoots([trio[0], trio[1]] as Array[int]), "not a whole link")
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	assert_false(run.link_shoots([a.id, target.id, b.id] as Array[int]), "a link with the target saves it")


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


## No pack and no dust, with Orion started (so he can mark after a link).
func _stuck_run() -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": 0, "red": 0}
	data["start_dust"] = 0
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.tail())
	run.orion.launches = run.orion.first_mark_launch
	return run


## Three mediums below Orion's corner, out of reach of the landmarks. Their ids.
func _medium_trio(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 30), Vector2i(10, 30), Vector2i(5, 38)]:
		ids.append(run.add_star(Star.Size.MEDIUM, CORNER + offset).id)
	return ids


## Links the first valid combo of sky stars, if there is one.
func _link_any(run: RunState) -> void:
	var ids: Array[int] = []
	for star: Star in run.stars:
		ids.append(star.id)
	for a: int in ids.size():
		for b: int in range(a + 1, ids.size()):
			for c: int in range(b + 1, ids.size()):
				var trio: Array[int] = [ids[a], ids[b], ids[c]]
				if run.combo_for(trio) != Combos.INVALID:
					run.link(trio)
					return
