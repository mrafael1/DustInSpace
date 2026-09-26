extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const MainScene := preload("res://game/scenes/main.tscn")


class ViewStub:
	extends Node
	var run: RunState
	var sequencer: EventSequencer

	func setup(p_run: RunState, p_sequencer: EventSequencer) -> void:
		run = p_run
		sequencer = p_sequencer


var main: Main


func before_each() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)


func test_starts_a_run_from_balance_json() -> void:
	assert_not_null(main.run)
	assert_eq(main.run.sky_rect, Rect2i(0, 78, 180, 172), "the sky zone from art-direction.md")
	assert_true(main.run.balance.is_valid())


func test_sky_zone_matches_the_test_fixture() -> void:
	assert_eq(ScreenZones.SKY, Fixtures.SKY)


func test_seed_override_makes_runs_repeatable() -> void:
	main.start_run(Fixtures.balance())
	var first: Array[int] = _burst_sizes()
	main.start_run(Fixtures.balance())
	assert_eq(_burst_sizes(), first)


func test_every_view_gets_the_run_and_sequencer() -> void:
	var view := ViewStub.new()
	main.add_child(view)
	main.move_child(view, 0)
	main.start_run(Fixtures.balance())
	assert_eq(view.run, main.run)
	assert_eq(view.sequencer, main.get_node("EventSequencer"))


func test_sequencer_is_the_last_child_so_it_sees_input_first() -> void:
	assert_eq(main.get_child(main.get_child_count() - 1), main.get_node("EventSequencer"))


func test_invalid_balance_file_shows_errors_and_starts_no_run() -> void:
	var broken: Main = MainScene.instantiate()
	broken.balance_path = "res://tests/missing_balance.json"
	add_child_autofree(broken)
	assert_null(broken.run)
	var label: Label = broken.get_node("DebugLayer/BalanceErrors")
	assert_true(label.visible, "debug builds show the errors")
	assert_string_contains(label.text, "not found")
	assert_push_error("balance.json")
	await wait_process_frames(2, "views draw and process with no run")
	assert_push_error_count(1, "the balance error and nothing else")
	assert_engine_error_count(0, "no view reads a run it never got")


func test_invalid_restart_keeps_the_current_run_and_views_in_step() -> void:
	var view := ViewStub.new()
	main.add_child(view)
	main.move_child(view, 0)
	main.start_run(Fixtures.balance({"start_dust": 20}))
	var current: RunState = main.run
	var started: bool = main.start_run(_invalid_balance())
	assert_false(started)
	assert_push_error("balance.json")
	assert_eq(main.run, current, "the run in play survives a rejected restart")
	assert_eq(view.run, current, "views still hold the run Main holds")
	assert_true((main.get_node("DebugLayer/BalanceErrors") as Label).visible)
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	current.buy("red")
	assert_true(sequencer.is_busy(), "the kept run's events are still presented")


func test_a_valid_restart_hides_old_errors() -> void:
	main.start_run(_invalid_balance())
	assert_push_error("balance.json")
	assert_true(main.start_run(Fixtures.balance()))
	assert_false((main.get_node("DebugLayer/BalanceErrors") as Label).visible)


func test_the_sky_shows_the_run_in_play() -> void:
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	main.run.launch(Vector2i(90, 160))
	_play_until_idle(sequencer)
	assert_eq(sky.star_count(), main.run.stars.size())
	main.start_run(Fixtures.balance())
	assert_eq(sky.star_count(), 0, "a restart empties the sky")


func test_debug_launch_waits_for_the_sequence_and_stays_in_the_sky() -> void:
	var keys: DebugKeys = main.get_node("DebugKeys")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	assert_true(keys.launch_at_random())
	assert_false(keys.launch_at_random(), "no launch while the burst still plays")
	_play_until_idle(sequencer)
	assert_true(keys.launch_at_random(), "input is back once the stars settle")
	for star: Star in main.run.stars:
		assert_true(StarScatter.inner_rect(ScreenZones.SKY).has_point(star.position))


func test_same_seed_and_same_debug_launches_replay_the_same_sky() -> void:
	var keys: DebugKeys = main.get_node("DebugKeys")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var skies: Array[Array] = []
	for attempt: int in 2:
		main.start_run(Fixtures.balance())
		var sky: Array[Vector2i] = []
		for launch: int in 3:
			assert_true(keys.launch_at_random())
			_play_until_idle(sequencer)
		for star: Star in main.run.stars:
			sky.append(star.position)
		skies.append(sky)
	assert_eq(skies[0], skies[1])


func test_a_restart_mid_launch_leaves_no_pack_in_the_air() -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var flying: PackView = main.get_node("Launcher/FlyingPack")
	main.run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	assert_true(flying.visible)
	assert_true(main.start_run(Fixtures.balance()))
	sequencer.advance(5.0)
	(main.get_node("Launcher") as Launcher).advance(5.0)
	assert_false(flying.visible, "the old run's pack is gone")
	assert_eq((main.get_node("Launcher") as Launcher).shown_pack(), "blue", "only the new run's pack shows")


func _play_until_idle(sequencer: EventSequencer) -> void:
	var elapsed: float = 0.0
	sequencer.advance(0.0)
	while sequencer.is_busy() and elapsed < 10.0:
		sequencer.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	assert_false(sequencer.is_busy(), "the sequence ends")


func _invalid_balance() -> Balance:
	var data: Dictionary = Fixtures.balance_dict()
	data["sun_target"] = 0
	return Balance.from_dict(data)


func _burst_sizes() -> Array[int]:
	main.run.launch(Vector2i(90, 160))
	return main.run.sky_sizes()
