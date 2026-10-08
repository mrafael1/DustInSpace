extends GutTest
## The back button (Android) and Escape go back one level at a time, and never quit the app: an open
## menu closes, a stage with nothing open pauses, the chart and the title stay. The app going to the
## background mid-stage pauses it.

const AppScene := preload("res://game/scenes/app.tscn")
const MainScene := preload("res://game/scenes/main.tscn")
const STORE := "user://test_back_progress.json"
const SETTINGS := "user://test_back_settings.cfg"
const STEP: float = 1.0 / 30.0


func after_each() -> void:
	for path: String in [STORE, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _app(title: bool = false) -> App:
	# The guided first run is done: the Stinger opens straight into free play.
	ProgressStore.new(STORE).save_chapter(App.TUTORIAL_ID, {"done": true})
	var app: App = AppScene.instantiate()
	app.opens_on_title = title
	app.progress_path = STORE
	app.settings_path = SETTINGS
	add_child_autofree(app)
	return app


func _main(in_chapter: bool = true) -> Main:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	main.star_map = "stinger"
	main.in_chapter = in_chapter
	(main.get_node("Sfx") as Sfx).settings_path = SETTINGS
	add_child_autofree(main)
	_finish_sequence(main)
	return main


func _finish_sequence(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 3000:
		if not sequencer.is_busy():
			return
		sequencer.advance(STEP)


## A harmless event (a rejected link of no stars) keeps the sequencer busy until it's advanced.
func _start_sequence(main: Main) -> void:
	main.run.link_rejected.emit([] as Array[int])
	assert_true((main.get_node("EventSequencer") as EventSequencer).is_busy())


func _end_run(main: Main) -> void:
	main.run.outcome = RunState.Outcome.LOST
	main.run.run_lost.emit()
	_finish_sequence(main)
	assert_true((main.get_node("EndScreen") as EndScreen).is_showing())


func test_the_back_button_never_quits_the_app() -> void:
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back", true))


func test_back_in_a_stage_with_nothing_open_pauses_then_resumes() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	assert_true(main.go_back())
	assert_true(hud.pause_menu().is_open(), "PAUSED opens")
	assert_eq((main.get_node("Sky") as Node).process_mode, Node.PROCESS_MODE_DISABLED, "the stage holds still")
	assert_true(main.go_back())
	assert_false(hud.pause_menu().is_open(), "back again resumes")
	assert_ne((main.get_node("Sky") as Node).process_mode, Node.PROCESS_MODE_DISABLED)


func test_back_closes_the_combos_table_first() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	hud.open_table()
	assert_true(main.go_back())
	assert_false(hud.table().is_open())
	assert_false(hud.pause_menu().is_open(), "one level at a time")


func test_back_is_ignored_while_a_sequence_plays() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	_start_sequence(main)
	assert_false(main.go_back())
	assert_false(hud.pause_menu().is_open())


func test_back_on_the_end_screen_goes_to_the_chart_in_a_chapter() -> void:
	var main: Main = _main()
	watch_signals(main)
	_end_run(main)
	assert_true(main.go_back())
	assert_signal_emitted(main, "map_requested")


func test_back_on_the_end_screen_outside_a_chapter_does_nothing() -> void:
	var main: Main = _main(false)
	watch_signals(main)
	_end_run(main)
	assert_false(main.go_back())
	assert_signal_not_emitted(main, "map_requested")
	assert_false((main.get_node("HUD") as Hud).pause_menu().is_open())


func test_the_background_pauses_the_stage() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	main.pause_for_background()
	assert_true(hud.pause_menu().is_open())
	main.pause_for_background()
	assert_true(hud.pause_menu().is_open(), "already paused: it stays paused")


func test_the_background_mid_sequence_pauses_once_it_ends() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	_start_sequence(main)
	main.pause_for_background()
	assert_false(hud.pause_menu().is_open(), "not mid-sequence")
	_finish_sequence(main)
	assert_true(hud.pause_menu().is_open(), "once it ends")


func test_the_background_leaves_the_table_and_the_end_screen_alone() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	hud.open_table()
	main.pause_for_background()
	assert_false(hud.pause_menu().is_open(), "the table already holds the stage")
	hud.close_table()
	_end_run(main)
	main.pause_for_background()
	assert_false(hud.pause_menu().is_open(), "the run is over")


func test_back_on_the_chart_closes_the_options_then_does_nothing() -> void:
	var app: App = _app()
	app.options().open()
	assert_true(app.go_back())
	assert_false(app.options().is_open())
	assert_false(app.go_back(), "nothing open: the chart stays")
	assert_null(app.stage())


func test_back_on_the_title_closes_the_options_then_does_nothing() -> void:
	var app: App = _app(true)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	app.options().open()
	assert_true(app.go_back())
	assert_false(app.options().is_open())
	assert_false(app.go_back())
	assert_true(chart.is_on_title(), "still on the title")


func test_app_back_in_a_stage_pauses_through_the_stage() -> void:
	var app: App = _app()
	app.open_stage(0)
	var stage: Main = app.stage()
	_finish_sequence(stage)
	var hud: Hud = stage.get_node("HUD")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(hud.pause_menu().is_open(), "the back button pauses")
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(hud.pause_menu().is_open(), "and resumes")
	assert_eq(app.stage(), stage, "still in the stage")


func test_escape_goes_back_like_the_back_button() -> void:
	var app: App = _app()
	app.open_stage(0)
	_finish_sequence(app.stage())
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	app._unhandled_input(escape)
	assert_true((app.stage().get_node("HUD") as Hud).pause_menu().is_open())


func test_app_paused_or_unfocused_pauses_the_stage() -> void:
	for what: int in [Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_FOCUS_OUT]:
		var app: App = _app()
		app.open_stage(0)
		_finish_sequence(app.stage())
		app.notification(what)
		assert_true((app.stage().get_node("HUD") as Hud).pause_menu().is_open())


func test_app_paused_on_the_chart_does_nothing() -> void:
	var app: App = _app()
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_null(app.stage())
	assert_false(app.options().is_open())
