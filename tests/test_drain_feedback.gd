extends GutTest
## Issue #128: the field and its drain feedback stay on screen until the launch that ended the run
## has played out (the core ends a run the moment a losing launch resolves).

const MainScene := preload("res://game/scenes/main.tscn")


func _main(map_id: String, data: Dictionary = {}) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 1
	add_child_autofree(main)
	if not data.is_empty():
		assert_true(main.start_run(Balance.from_dict(data)))
	return main


func _last_blue_pack() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))
	data.start_packs = {"blue": 1, "red": 0}
	data.start_dust = 0
	return data


## Plays the queued events (and the stars' drifts) for up to `seconds`, stopping early once
## `until` holds.
func _play(main: Main, seconds: float, until: Callable = Callable()) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var sky: SkyView = main.get_node("Sky")
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var t: float = 0.0
	while t < seconds:
		sequencer.advance(0.03)
		for child: Node in sky.get_node("StarLayer").get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				(child as StarView).advance(0.03)
		view.advance(0.03)
		t += 0.03
		if until.is_valid() and until.call():
			return


func _flaring(view: CurrentView, run: RunState) -> bool:
	var x: int = run.current.region.position.x
	for y: int in range(run.current.region.position.y, run.current.region.end.y):
		var c: Variant = view.pixels().get(Vector2i(x, y))
		if c == Palette.C2 or c == Palette.C0:
			return true
		if c == Palette.S4 and view.pixels().get(Vector2i(x, y + 1)) == Palette.S4:
			return true
	return false


func test_the_last_losing_launch_still_shows_its_drains() -> void:
	# The issue's repro: Aquarius Body, seed 1, one blue pack left, no dust.
	var main: Main = _main("aquarius_body", _last_blue_pack())
	var run: RunState = main.run
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var sky: SkyView = main.get_node("Sky")
	run.add_star(Star.Size.SMALL, Vector2i(52, 100) + run.scorpio.shift)
	sky.setup(run, sequencer)
	assert_false(view.pixels().is_empty(), "the field before the launch")
	var drained: Array[Vector2i] = []
	sky.star_drained.connect(func(at: Vector2i) -> void: drained.append(at))
	run.load_pack("blue")
	assert_true(run.launch(Vector2i(56, 150) + run.scorpio.shift))
	assert_eq(run.outcome, RunState.Outcome.LOST, "the core has ended the run")
	assert_true(sequencer.is_busy())
	assert_false(view.pixels().is_empty(), "but the field stays while the launch plays")
	_play(main, 6.0, func() -> bool: return not drained.is_empty())
	assert_false(drained.is_empty(), "a star drains")
	assert_true(_flaring(view, run), "and its extinction flares on the drain")
	_play(main, 6.0, func() -> bool: return not sequencer.is_busy() and view.pixels().is_empty())
	assert_false(sequencer.is_busy())
	view.advance(CurrentView.DRAIN_TIME)
	assert_true(view.pixels().is_empty(), "then the field goes with the run")


func test_a_normal_drain_flares_and_the_field_stays() -> void:
	var main: Main = _main("aquarius_body")
	var run: RunState = main.run
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var sky: SkyView = main.get_node("Sky")
	run.add_star(Star.Size.SMALL, Vector2i(52, 100) + run.scorpio.shift)
	sky.setup(run, sequencer)
	var drained: Array[Vector2i] = []
	sky.star_drained.connect(func(at: Vector2i) -> void: drained.append(at))
	assert_true(run.launch(Vector2i(56, 150) + run.scorpio.shift))
	assert_eq(run.outcome, RunState.Outcome.PLAYING)
	_play(main, 6.0, func() -> bool: return not drained.is_empty())
	assert_true(_flaring(view, run))
	_play(main, 6.0, func() -> bool: return not sequencer.is_busy())
	view.advance(CurrentView.DRAIN_TIME)
	assert_false(view.pixels().is_empty(), "a run in play keeps its field")


func test_restarting_mid_sequence_shows_the_new_runs_field_and_no_old_flare() -> void:
	var main: Main = _main("aquarius_body", _last_blue_pack())
	var run: RunState = main.run
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	run.add_star(Star.Size.SMALL, Vector2i(52, 100) + run.scorpio.shift)
	run.load_pack("blue")
	assert_true(run.launch(Vector2i(56, 150) + run.scorpio.shift))
	view.flash_drain(Vector2i(run.current.region.position.x - 1, 120), Vector2i.LEFT)
	assert_true(main.restart())
	assert_ne(main.run, run, "a fresh run")
	assert_eq(main.run.outcome, RunState.Outcome.PLAYING)
	assert_false(view.pixels().is_empty(), "its field shows at once")
	assert_false(_flaring(view, main.run), "nothing left over from the old run")


func test_a_winning_completion_keeps_the_field_until_its_link_has_played() -> void:
	var main: Main = _main("aquarius_hand")
	var run: RunState = main.run
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var last: int = run.scorpio.map.count() - 1
	for index: int in last:
		run.scorpio.light(index)
	var at: Vector2i = run.scorpio.landmark_position(last)
	var a: Star = run.add_star(run.scorpio.map.sizes[last] as Star.Size, at + Vector2i(20, -10))
	var b: Star = run.add_star(run.scorpio.map.sizes[last] as Star.Size, at + Vector2i(30, 12))
	(main.get_node("Sky") as SkyView).setup(run, sequencer)
	run.link([a.id, Scorpio.landmark_id(last), b.id] as Array[int])
	assert_eq(run.outcome, RunState.Outcome.WON)
	assert_true(sequencer.is_busy())
	assert_false(view.pixels().is_empty(), "the field stays while the winning link plays")
	_play(main, 20.0, func() -> bool: return not sequencer.is_busy())
	assert_false(sequencer.is_busy())
	view.advance(CurrentView.DRAIN_TIME)
	assert_true(view.pixels().is_empty(), "then it clears for the painting")
