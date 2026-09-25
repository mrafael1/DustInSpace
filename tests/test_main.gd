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


func _invalid_balance() -> Balance:
	var data: Dictionary = Fixtures.balance_dict()
	data["sun_target"] = 0
	return Balance.from_dict(data)


func _burst_sizes() -> Array[int]:
	main.run.launch(Vector2i(90, 160))
	return main.run.sky_sizes()
