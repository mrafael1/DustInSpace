extends GutTest
## MAP must finish consuming the touch before App detaches the stage and its viewport.

const AppScene := preload("res://game/scenes/app.tscn")
const STORE: String = "user://test_map_return_progress.json"
const SETTINGS: String = "user://test_map_return_settings.cfg"


func after_each() -> void:
	for path: String in [STORE, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _app() -> App:
	ProgressStore.new(STORE).save_chapter(App.TUTORIAL_ID, {"done": true})
	var app: App = AppScene.instantiate()
	app.opens_on_title = false
	app.progress_path = STORE
	app.settings_path = SETTINGS
	add_child_autofree(app)
	return app


func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = pressed
	return touch


func test_pause_map_keeps_the_viewport_until_input_finishes() -> void:
	var app: App = _app()
	app.open_stage(0)
	var stage: Main = app.stage()
	var hud: Hud = stage.get_node("HUD")
	hud.open_pause()
	var at: Vector2 = Vector2(hud.pause_menu().item_rect(&"map").get_center()) + hud.offset
	hud._unhandled_input(_touch(at, true))
	hud._unhandled_input(_touch(at, false))
	assert_eq(app.stage(), stage, "MAP waits until the input callback returns")
	assert_true(stage.is_inside_tree())
	assert_not_null(hud.get_viewport(), "the touch handler still has its viewport")
	await get_tree().process_frame
	assert_null(app.stage())
	assert_true((app.get_node("ChapterSelect") as ChapterSelect).visible)


func test_end_map_keeps_the_viewport_until_input_finishes() -> void:
	for outcome: RunState.Outcome in [RunState.Outcome.WON, RunState.Outcome.LOST]:
		var app: App = _app()
		app.open_stage(0)
		var stage: Main = app.stage()
		var end: EndScreen = stage.get_node("EndScreen")
		stage.run.outcome = outcome
		end.call("_show_end")
		var at: Vector2 = Vector2(end.map_rect().get_center()) + end.offset
		end._input(_touch(at, true))
		end._input(_touch(at, false))
		assert_eq(app.stage(), stage, "MAP waits until the input callback returns")
		assert_true(stage.is_inside_tree())
		assert_not_null(end.get_viewport(), "the touch handler still has its viewport")
		await get_tree().process_frame
		assert_null(app.stage())
		assert_true((app.get_node("ChapterSelect") as ChapterSelect).visible)
		app.queue_free()
		await get_tree().process_frame


func test_duplicate_map_requests_return_only_once() -> void:
	var app: App = _app()
	app.open_stage(0)
	var stage: Main = app.stage()
	stage.map_requested.emit()
	stage.map_requested.emit()
	assert_eq(app.stage(), stage)
	await get_tree().process_frame
	assert_null(app.stage())
	app.open_stage(0)
	assert_not_null(app.stage(), "another stage can open normally")
