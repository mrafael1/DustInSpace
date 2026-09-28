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


func test_sequencer_sees_input_before_every_view() -> void:
	assert_eq(main.get_child(main.get_child_count() - 2), main.get_node("EventSequencer"))
	assert_eq(main.get_child(main.get_child_count() - 1), main.get_node("SoundToggle"),
		"only the speaker's own taps come first")


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


func test_landing_particles_tick_the_hud_and_the_sun() -> void:
	var fx: CollectParticles = main.get_node("CollectParticles")
	var sun: SunView = main.get_node("Sun")
	var hud: Hud = main.get_node("HUD")
	fx.dust_arrived.emit(2)
	fx.light_arrived.emit(10)
	assert_eq((hud.get_node("Dust") as Label).text, "%d" % (main.run.dust + 2))
	assert_string_starts_with((hud.get_node("Light") as Label).text, "10/")
	assert_eq(sun.progress(), 10.0 / main.run.light_target(), "the Sun fills toward the run's target")


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


func test_the_telescope_launches_by_default_and_t_switches_to_the_slingshot() -> void:
	var telescope: Telescope = main.get_node("Telescope")
	var slingshot: Launcher = main.get_node("Launcher")
	assert_true(main.use_telescope)
	assert_eq(main.launcher(), telescope)
	assert_true(telescope.visible and telescope.can_process())
	assert_false(slingshot.visible or slingshot.can_process(), "the slingshot takes no input")
	(main.get_node("DebugKeys") as DebugKeys).launcher_switch_requested.emit()
	assert_eq(main.launcher(), slingshot)
	assert_true(slingshot.visible and slingshot.can_process())
	assert_false(telescope.visible or telescope.can_process())


func test_a_run_starts_with_the_telescope_loaded_and_aiming() -> void:
	var telescope: Telescope = main.get_node("Telescope")
	assert_ne(telescope.seated_pack(), "")
	assert_true(telescope.is_aiming())
	assert_eq((main.get_node("HUD") as Hud).message(), Telescope.AIM_MESSAGE, "with the hint showing")
	assert_true(ScreenZones.HUD.grow(10).has_point(telescope.origin()), "in the HUD's row")


func test_the_telescope_message_shows_on_the_hud() -> void:
	var hud: Hud = main.get_node("HUD")
	(main.get_node("Telescope") as Telescope).message_shown.emit(Telescope.EMPTY_MESSAGE)
	assert_eq(hud.message(), Telescope.EMPTY_MESSAGE)
	hud.advance(Hud.MESSAGE_TIME + 0.01)
	assert_eq(hud.message(), "", "it fades after a moment")


func test_a_planet_picked_in_the_hud_aims_the_telescope() -> void:
	var telescope: Telescope = main.get_node("Telescope")
	(main.get_node("HUD") as Hud).planet_chosen.emit("blue")
	_play_until_idle(main.get_node("EventSequencer"))
	telescope.advance(0.0)
	assert_ne(telescope.loaded_pack(), "", "a run starts with a planet loaded")
	assert_true(telescope.is_aiming())


func test_both_launchers_follow_a_launch() -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	main.run.launch(Vector2i(90, 150))
	_play_until_idle(sequencer)
	var kind: String = main.run.loaded_pack
	assert_eq((main.get_node("Telescope") as Telescope).loaded_pack(), kind)
	assert_eq((main.get_node("Launcher") as Launcher).shown_pack(), kind, "the hidden slingshot keeps up")


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
