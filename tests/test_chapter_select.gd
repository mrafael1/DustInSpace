extends GutTest
## The chapter chart (#62) and the flow between it and a stage.

const ChartScene := preload("res://game/scenes/chapter_select.tscn")
const AppScene := preload("res://game/scenes/app.tscn")
const STEP: float = 1.0 / 30.0

var chart: ChapterSelect
var store_path: String = "user://test_chapter_app_%d.json" % randi()


func before_each() -> void:
	chart = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set_process(false)


func after_each() -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))


func test_it_opens_on_the_tail_with_stage_1_ready_to_play() -> void:
	chart.setup(Chapter.new())
	assert_eq(chart.selected(), 0)
	assert_eq(ChapterSelect.point_position(0), Scorpio.LANDMARKS[13], "at the stinger")
	assert_true(chart.can_play())
	assert_eq(_label("Info").text, "STAGE 1")
	assert_eq(_label("Play").text, "PLAY")


func test_each_point_can_be_tapped_on_its_own() -> void:
	for point: int in Chapter.point_count():
		assert_eq(ChapterSelect.point_at(ChapterSelect.point_position(point) + Vector2i(4, -4)), point)
	assert_eq(ChapterSelect.point_at(Vector2i(90, 40)), -1, "the title isn't a point")


func test_play_on_an_available_point_opens_its_stage() -> void:
	chart.setup(Chapter.new())
	watch_signals(chart)
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [0])


func test_a_locked_point_can_be_looked_at_but_never_played() -> void:
	chart.setup(Chapter.new())
	watch_signals(chart)
	_tap(ChapterSelect.point_position(3))
	assert_eq(chart.selected(), 3)
	assert_false(chart.can_play())
	assert_false(_label("Play").visible, "no PLAY")
	assert_eq(_label("Info").text, "COMING SOON")
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_not_emitted(chart, "stage_chosen")


func test_a_completed_point_can_be_replayed() -> void:
	var chapter := Chapter.new()
	chapter.complete(0)
	chart.setup(chapter)
	assert_eq(chart.selected(), 0)
	assert_eq(_label("Play").text, "REPLAY")
	watch_signals(chart)
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [0])


func test_selecting_a_point_sends_a_comet_along_the_strings() -> void:
	chart.setup(Chapter.new())
	_tap(ChapterSelect.point_position(2))
	assert_true(chart.is_travelling())
	var pixels: Array[Vector2i] = ChapterSelect.travel_pixels(0, 2)
	assert_eq(pixels[0], ChapterSelect.point_position(0))
	assert_eq(pixels[-1], ChapterSelect.point_position(2))
	for i: int in range(1, pixels.size()):
		assert_lte(maxi(absi(pixels[i].x - pixels[i - 1].x), absi(pixels[i].y - pixels[i - 1].y)), 1, "a whole-pixel path, no gaps")
	for i: int in 120:
		chart.advance(STEP)
	assert_false(chart.is_travelling(), "it arrives")


func test_back_from_a_win_the_point_lights_then_the_comet_travels_to_the_next() -> void:
	var chapter := Chapter.new(2)
	chart.setup(chapter)
	var unlocked: int = chapter.complete(0)
	chart.show_progress(0, unlocked)
	assert_true(chart.is_lighting())
	assert_eq(chart.selected(), 0)
	chart.advance(ChapterSelect.LIGHT_TIME + 0.01)
	assert_false(chart.is_lighting())
	assert_true(chart.is_travelling(), "then travels on")
	assert_eq(chart.selected(), 1, "to the stage it unlocked")
	assert_true(chart.can_play())


func test_back_without_a_new_win_it_just_selects_the_point_to_play() -> void:
	var chapter := Chapter.new()
	chart.setup(chapter)
	chart.show_progress(-1, -1)
	assert_false(chart.is_lighting() or chart.is_travelling())
	assert_eq(chart.selected(), 0)


func test_the_chart_draws_only_palette_colours() -> void:
	chart.setup(Chapter.new())
	# Colours the chart uses are all Palette constants (checked against the .gpl elsewhere).
	for colour: Color in ChapterSelect.TRAIL + ChapterSelect.LIGHT_COLOURS:
		assert_true(colour in [Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.C4])


func test_app_opens_on_the_chart_then_stage_1_then_back() -> void:
	var app: App = _app()
	var app_chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_true(app_chart.visible)
	assert_null(app.stage())
	app.open_stage(0)
	var stage: Main = app.stage()
	assert_not_null(stage, "stage 1 opens from the tail point")
	assert_true(stage.in_chapter)
	assert_false(app_chart.visible)
	assert_true((stage.get_node("HUD") as Hud).is_map_button_shown(), "with a way back")
	stage.map_requested.emit()
	assert_null(app.stage())
	assert_true(app_chart.visible, "back on the chart")


func test_a_locked_point_never_opens_a_stage() -> void:
	var app: App = _app()
	app.open_stage(1)
	assert_null(app.stage())


func test_a_win_lights_the_point_and_survives_a_restart() -> void:
	var app: App = _app()
	app.open_stage(0)
	app.stage().run.run_won.emit()
	app.back_to_chart()
	var app_chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_true(app.chapter.is_completed(0))
	assert_true(app_chart.is_lighting(), "the point lights as the chart comes back")
	app.queue_free()
	await get_tree().process_frame
	var again: App = _app()
	assert_true(again.chapter.is_completed(0), "the app restarted with the progress kept")
	assert_eq((again.get_node("ChapterSelect") as ChapterSelect).selected(), 0, "all built stages done: the last one")


func test_a_loss_changes_nothing() -> void:
	var app: App = _app()
	app.open_stage(0)
	app.stage().run.run_lost.emit()
	app.back_to_chart()
	assert_false(app.chapter.is_completed(0))
	assert_false((app.get_node("ChapterSelect") as ChapterSelect).is_lighting())


func test_the_hud_map_button_asks_for_the_chart() -> void:
	var app: App = _app()
	app.open_stage(0)
	var hud: Hud = app.stage().get_node("HUD")
	var backed: Array[bool] = []
	app.stage().map_requested.connect(func() -> void: backed.append(true))
	var at: Vector2i = hud.map_target().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		hud.handle_pointer(touch)
	assert_eq(backed, [true])


func test_the_map_button_only_shows_in_a_chapter_and_clears_the_speaker() -> void:
	var main: Main = preload("res://game/scenes/main.tscn").instantiate()
	add_child_autofree(main)
	var hud: Hud = main.get_node("HUD")
	assert_false(hud.is_map_button_shown(), "a stage played on its own has no MAP")
	hud.show_map_button(true)
	assert_false(hud.map_target().intersects(hud.sound_target()))
	assert_true(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN).encloses(hud.map_target()), "on screen")


func test_the_end_screen_offers_the_map_in_a_chapter() -> void:
	var app: App = _app()
	app.open_stage(0)
	var end: EndScreen = app.stage().get_node("EndScreen")
	assert_true(end.map_enabled)
	var run: RunState = app.stage().run
	run.outcome = RunState.Outcome.WON
	end.call("_show_end")
	assert_ne(end.map_rect(), Rect2i(), "MAP beside RESTART")
	assert_false(end.map_rect().intersects(end.restart_rect()))
	var backed: Array[bool] = []
	end.map_requested.connect(func() -> void: backed.append(true))
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(end.map_rect().get_center())
		touch.pressed = pressed
		end.handle_pointer(touch)
	assert_eq(backed, [true])


func _app() -> App:
	var app: App = AppScene.instantiate()
	app.progress_path = store_path
	add_child_autofree(app)
	return app


func _label(name: String) -> Label:
	return chart.get_node(name)


func _tap(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		chart.handle_pointer(touch)
