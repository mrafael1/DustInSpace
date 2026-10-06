extends GutTest

const MainScene := preload("res://game/scenes/main.tscn")
const AppScene := preload("res://game/scenes/app.tscn")
const STORE := "user://test_current_trial_progress.json"


func after_each() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))


func _main() -> Main:
	var main: Main = MainScene.instantiate()
	main.current_trial = true
	main.seed_override = 7
	add_child_autofree(main)
	return main


func test_trial_switch_replays_same_seed_without_orion() -> void:
	var main: Main = _main()
	assert_not_null(main.run.current)
	main.switch_current()
	assert_null(main.run.current)
	assert_null(main.run.orion)
	assert_eq(main.run.run_seed, 7)
	main.switch_current()
	assert_not_null(main.run.current)
	assert_eq(main.run.run_seed, 7)


func test_normal_run_cannot_switch_into_a_trial() -> void:
	var main: Main = MainScene.instantiate()
	add_child_autofree(main)
	var run: RunState = main.run
	main.switch_current()
	assert_eq(main.run, run)
	assert_null(main.run.current)


func test_trial_win_cannot_save_scorpio_or_tutorial_progress() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	add_child_autofree(app)
	var before: Dictionary = app.chapter.to_save().duplicate(true)
	app.open_current_trial(true, 7)
	assert_not_null(app.stage())
	assert_false(app.stage().tutorial)
	assert_false(app.stage().encounter)
	app.stage().run.run_won.emit()
	assert_eq(app.chapter.to_save(), before)
	assert_false(FileAccess.file_exists(STORE), "trial has no persistence callbacks")
	app.back_to_chart()
	assert_null(app.stage())
	assert_eq(app.chapter.to_save(), before)
	await wait_process_frames(2)


func test_busy_trial_cannot_be_restarted_by_c() -> void:
	var main: Main = _main()
	var run: RunState = main.run
	(main.get_node("EventSequencer") as EventSequencer).hold(1.0)
	# hold only extends an active sequence, so launch supplies that sequence.
	assert_true(main.run.launch(Vector2i(110, 158)))
	main.switch_current()
	assert_eq(main.run, run)


func test_table_pause_blocks_current_switch() -> void:
	var main: Main = _main()
	var run: RunState = main.run
	(main.get_node("HUD") as Hud).table_opened.emit()
	main.switch_current()
	assert_eq(main.run, run)
	(main.get_node("HUD") as Hud).table_closed.emit()


func test_mobile_control_switches_flow_without_launching_and_cancel_uses_nothing() -> void:
	var main: Main = _main()
	var controls: CurrentTrialControls = main.get_node("CurrentTrialControls")
	var packs: int = main.run.total_packs()
	var press := InputEventScreenTouch.new()
	press.position = Vector2(16, 77)
	press.pressed = true
	assert_true(controls.handle_pointer(press))
	var release := InputEventScreenTouch.new()
	release.position = press.position
	release.canceled = true
	assert_true(controls.handle_pointer(release))
	assert_not_null(main.run.current)
	assert_eq(main.run.total_packs(), packs)
	controls.handle_pointer(press)
	release.canceled = false
	controls.handle_pointer(release)
	assert_null(main.run.current)
	assert_eq(main.run.total_packs(), packs)


func test_chart_flow_button_opens_trial_without_starting_a_campaign_stage() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	add_child_autofree(app)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	var button: MapButton = chart.get_node("CurrentTrialButton")
	var press := InputEventScreenTouch.new()
	press.position = Vector2(button.target().get_center())
	press.pressed = true
	assert_true(chart.handle_pointer(press))
	var release := InputEventScreenTouch.new()
	release.position = press.position
	assert_true(chart.handle_pointer(release))
	assert_true(app.stage().current_trial)
	assert_false(app.stage().tutorial)
	assert_false(FileAccess.file_exists(STORE))
	app.back_to_chart()
	await wait_process_frames(2)


func test_trial_controls_stay_above_the_map_on_tall_screens() -> void:
	var main: Main = _main()
	var controls: CurrentTrialControls = main.get_node("CurrentTrialControls")
	controls.fit_screen(Rect2i(0, -70, 180, 390))
	assert_eq((controls.get_child(0) as MapButton).position, Vector2(8, 2))


func test_drifts_keep_pixel_positions_and_finish_at_core_destination() -> void:
	var view := StarView.new()
	add_child_autofree(view)
	view.setup(Star.new(1, Star.Size.BIG, Vector2i(118, 132)), Scorpio.HOME_SKY)
	view.drift_to(Vector2i(94, 132))
	for step: int in 10:
		view.advance(StarView.DRIFT_TIME / 10.0 + 0.0001)
		assert_eq(view.position, view.position.round())
	assert_eq(view.position, Vector2(94, 132))
	assert_eq(view.state, StarView.State.IDLE)


func test_preview_brackets_only_appear_while_aiming_and_use_palette_colours() -> void:
	var main: Main = _main()
	var star: Star = main.run.add_star(Star.Size.SMALL, Vector2i(118, 132))
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	view.aiming = false
	var idle: Dictionary[Vector2i, Color] = view.pixels()
	view.aiming = true
	var aim: Dictionary[Vector2i, Color] = view.pixels()
	var to: Vector2i = main.run.current_preview()[star.id]
	assert_true(aim.has(to + Vector2i(4, 0)), "brackets surround the actual destination")
	assert_false(idle.has(to + Vector2i(4, 0)))
	for colour: Color in aim.values():
		assert_has([Palette.M3, Palette.M4, Palette.M5], colour)


func test_shift_event_moves_views_after_burst_and_holds_input() -> void:
	var main: Main = _main()
	var star: Star = main.run.add_star(Star.Size.SMALL, Vector2i(118, 132))
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	sky.setup(main.run, sequencer)
	assert_true(main.run.launch(Vector2i(30, 100)))
	var view: StarView = sky.star_view(star.id)
	assert_eq(view.position, Vector2(118, 132), "core moves instantly; view waits for its event")
	for tick: int in 200:
		sequencer.advance(0.03)
		for child: Node in sky.get_node("StarLayer").get_children():
			(child as StarView).advance(0.03)
		if not sequencer.is_busy():
			break
	assert_false(sequencer.is_busy())
	assert_eq(Vector2i(view.position), star.position)
