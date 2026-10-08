extends GutTest
## The title, the options and the pause menu: a menu chooses, dismisses and holds; the title waits
## for a tap and leads down to the chart; the options replay the tutorial and reset the progress;
## the pause menu holds the stage still, resumes, restarts and goes back to the map.

const AppScene := preload("res://game/scenes/app.tscn")
const MainScene := preload("res://game/scenes/main.tscn")
const STORE := "user://test_menus_progress.json"
const SETTINGS := "user://test_menus_settings.cfg"
const STEP: float = 1.0 / 30.0


func after_each() -> void:
	for path: String in [STORE, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _touch(target: Object, at: Vector2i, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(at)
	touch.pressed = pressed
	target.handle_pointer(touch)


func _tap(target: Object, at: Vector2i) -> void:
	_touch(target, at, true)
	_touch(target, at, false)


func _panel() -> MenuPanel:
	var panel := MenuPanel.new()
	panel.heading = "TEST"
	add_child_autofree(panel)
	panel.set_items([{"id": &"a", "text": "ONE"}, {"id": &"reset", "text": "RESET", "hold": true}])
	panel.open()
	return panel


func _app(title: bool = false) -> App:
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
	return main


func test_progress_store_clear_forgets_every_chapter() -> void:
	var store := ProgressStore.new(STORE)
	store.save_chapter("scorpio", {"completed": [0]})
	assert_true(store.clear())
	assert_false(FileAccess.file_exists(STORE))
	assert_eq(store.load_chapter("scorpio"), {})
	assert_true(store.clear(), "nothing to clear is fine")


func test_a_menu_button_is_chosen_on_release_over_it() -> void:
	var panel: MenuPanel = _panel()
	watch_signals(panel)
	var at: Vector2i = panel.item_rect(&"a").get_center()
	_touch(panel, at, true)
	assert_signal_not_emitted(panel, "chosen", "not on the press")
	_touch(panel, at, false)
	assert_signal_emitted_with_parameters(panel, "chosen", [&"a"])


func test_a_tap_off_the_plaque_dismisses_and_one_on_it_does_nothing() -> void:
	var panel: MenuPanel = _panel()
	watch_signals(panel)
	_tap(panel, panel.plaque_rect().position + Vector2i(3, 3))
	assert_signal_not_emitted(panel, "dismissed", "on the plaque, between buttons")
	assert_signal_not_emitted(panel, "chosen")
	_tap(panel, Vector2i(2, 2))
	assert_signal_emitted(panel, "dismissed")
	assert_true(panel.handle_pointer(InputEventScreenTouch.new()), "it takes every touch while open")
	panel.close()
	assert_false(panel.handle_pointer(InputEventScreenTouch.new()), "and none when closed")


func test_a_hold_button_needs_holding_and_a_short_tap_says_how() -> void:
	var panel: MenuPanel = _panel()
	watch_signals(panel)
	var at: Vector2i = panel.item_rect(&"reset").get_center()
	_touch(panel, at, true)
	assert_signal_emitted(panel, "hold_started")
	panel.advance(MenuPanel.HOLD_TIME / 2.0)
	assert_almost_eq(panel.hold_progress(), 0.5, 0.01)
	_touch(panel, at, false)
	assert_signal_not_emitted(panel, "chosen", "let go too early")
	assert_eq(panel.hold_progress(), -1.0)
	assert_eq(panel.note(), MenuPanel.HOLD_TEXT)


func test_a_held_button_is_chosen_once_when_full() -> void:
	var panel: MenuPanel = _panel()
	watch_signals(panel)
	var at: Vector2i = panel.item_rect(&"reset").get_center()
	_touch(panel, at, true)
	for i: int in ceili(MenuPanel.HOLD_TIME / STEP) + 1:
		panel.advance(STEP)
	assert_signal_emit_count(panel, "chosen", 1)
	assert_signal_emitted_with_parameters(panel, "chosen", [&"reset"])
	panel.advance(1.0)
	_touch(panel, at, false)
	assert_signal_emit_count(panel, "chosen", 1, "the release doesn't choose it again")


func test_sliding_off_a_held_button_lets_it_go() -> void:
	var panel: MenuPanel = _panel()
	watch_signals(panel)
	_touch(panel, panel.item_rect(&"reset").get_center(), true)
	panel.advance(0.3)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(panel.item_rect(&"a").get_center())
	panel.handle_pointer(drag)
	panel.advance(MenuPanel.HOLD_TIME)
	assert_signal_not_emitted(panel, "chosen")


func test_glyph_buttons_are_narrow_plaques_with_a_full_tap_target() -> void:
	var button: MapButton = preload("res://game/ui/map_button.tscn").instantiate()
	add_child_autofree(button)
	button.glyph = MapButton.Glyph.GEAR
	assert_eq(button.plaque_size(), MapButton.GLYPH_SIZE)
	assert_gte(button.target().size.x, 22, "44 pt wide")
	assert_eq(button.target().size.y, 22, "44 pt tall")
	assert_false(MapButton.glyph_pixels(MapButton.Glyph.GEAR).is_empty())
	for dot: Vector2i in MapButton.glyph_pixels(MapButton.Glyph.PAUSE):
		assert_true(Rect2i(0, 0, 7, 7).has_point(dot))


func test_the_game_opens_on_the_title_and_the_chart_waits() -> void:
	var app: App = _app(true)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	chart.set_process(false)
	assert_true(chart.is_on_title())
	assert_true(chart.title_view().visible)
	assert_eq(chart.camera_y(), chart.get("_screen").size.y, "a screen above the chart")
	assert_eq(chart.offset.y, float(chart.camera_y()), "the chart sits below the screen")
	watch_signals(chart)
	_tap(chart, ChapterSelect.play_rect().get_center())
	assert_signal_not_emitted(chart, "stage_chosen", "PLAY is still below")
	assert_signal_emitted(chart, "title_left", "a tap anywhere leads down")
	assert_true(chart.is_descending())
	assert_false(chart.title_view().is_tap_shown())


func test_the_way_down_eases_to_the_chart_and_the_star_lands_on_the_stage() -> void:
	var app: App = _app(true)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	chart.set_process(false)
	var height: int = chart.camera_y()
	var lift_off: Vector2i = chart.title_view().star_at()
	chart.start_descent()
	assert_eq(chart.descent_star(), lift_off, "the light star lifts off under the title")
	watch_signals(chart)
	var last: int = height
	var speeds: Array[float] = []
	while chart.is_descending():
		chart.advance(STEP)
		assert_lte(chart.camera_y(), last, "always down")
		last = chart.camera_y()
		speeds.append(chart.descent_speed())
	assert_lt(speeds[0], speeds[speeds.size() / 2], "it speeds up")
	assert_lt(speeds[-2], speeds[speeds.size() / 2], "and slows down to land")
	assert_eq(chart.camera_y(), 0)
	assert_eq(chart.offset.y, float(chart.get("_base_offset").y), "the chart where it belongs")
	assert_signal_emitted(chart, "star_landed")
	assert_false(chart.title_view().visible)
	assert_false(chart.is_busy())
	assert_eq(chart.selected(), app.chapter.current(), "on the stage to play")


func test_the_title_sky_keeps_its_stars_off_the_letters() -> void:
	var app: App = _app(true)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	var screen: Rect2i = chart.get("_screen")
	var title: Rect2i = chart.title_view().title_rect()
	var stars: Array[Vector3i] = ChapterSelect.sky_stars(screen, app.chapter.def, 0, 0, roundi(screen.size.y * ChapterSelect.STAR_PARALLAX), screen.size.y, [title])
	assert_gt(stars.size(), 100, "the sky above has its stars")
	for star: Vector3i in stars:
		assert_false(title.has_point(Vector2i(star.x, star.y)))


func test_opening_a_stage_from_the_title_leaves_it() -> void:
	var app: App = _app(true)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	app.open_stage(0)
	assert_false(chart.is_on_title())
	app.back_to_chart()
	assert_eq(chart.camera_y(), 0, "back on the chart, not the title")


func test_the_gear_opens_the_options_over_the_title_and_holds_the_taps() -> void:
	var app: App = _app(true)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	var options: OptionsMenu = app.options()
	assert_true(options.visible)
	_tap(options, options.gear_target().get_center())
	assert_true(options.is_open())
	assert_true(options.handle_pointer(InputEventScreenTouch.new()), "the menu takes the taps, not the title")
	watch_signals(options)
	_tap(options, options.panel().item_rect(&"sound").get_center())
	assert_signal_emitted(options, "sound_cycle_requested")
	options.show_sound_level(Sfx.Level.MUTE)
	assert_eq(options.panel().item_text(&"sound"), "SOUND OFF")
	_tap(options, options.panel().item_rect(&"close").get_center())
	assert_false(options.is_open())
	assert_true(chart.is_on_title(), "still on the title")


func test_the_options_hide_in_a_stage() -> void:
	var app: App = _app()
	app.options().open()
	app.open_stage(0)
	assert_false(app.options().visible)
	assert_false(app.options().is_open())
	app.back_to_chart()
	assert_true(app.options().visible)


func test_a_held_reset_forgets_every_chapter_the_tutorial_and_the_encounters() -> void:
	var scorpio := Chapter.new()
	for stage: int in Chapter.stage_count():
		scorpio.set_built(stage, true)
		scorpio.complete(stage)
	var store := ProgressStore.new(STORE)
	store.save_chapter("scorpio", scorpio.to_save())
	store.save_chapter(App.TUTORIAL_ID, {"done": true})
	store.save_chapter(App.ENCOUNTERS_ID, {"mark": true})
	var app: App = _app()
	assert_eq(app.chapter.id, "aquarius", "Scorpio won: on Aquarius")
	var options: OptionsMenu = app.options()
	assert_true(options.panel().ids().has(&"tutorial"))
	options.open()
	var at: Vector2i = options.panel().item_rect(&"reset").get_center()
	_touch(options, at, true)
	for i: int in ceili(MenuPanel.HOLD_TIME / STEP) + 1:
		options.panel().advance(STEP)
	assert_eq(app.chapter.id, "scorpio", "back to the first chapter")
	assert_false(app.chapter.is_completed(0))
	assert_false(app.tutorial_done)
	assert_eq(app.encounters_met, {})
	assert_false(app.is_open(app.chapters[1]), "Aquarius locked again")
	assert_false(options.panel().ids().has(&"tutorial"), "the Stinger is guided again anyway")
	assert_eq(options.panel().note(), OptionsMenu.RESET_NOTE)
	assert_eq(ProgressStore.new(STORE).load_chapter("scorpio"), {}, "forgotten on the device")
	app.open_stage(0)
	assert_not_null(app.stage().run.tutorial, "the first run is guided again")


func test_the_pause_button_holds_the_stage_still_until_resume() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	var sky: Node = main.get_node("Sky")
	watch_signals(hud)
	_tap(hud, hud.pause_target().get_center())
	assert_true(hud.pause_menu().is_open())
	assert_signal_emitted(hud, "pause_opened")
	assert_eq(sky.process_mode, Node.PROCESS_MODE_DISABLED, "the world holds still")
	assert_eq(hud.pause_menu().ids(), [&"resume", &"restart", &"sound", &"map"] as Array[StringName])
	_tap(hud, hud.pause_menu().item_rect(&"resume").get_center())
	assert_false(hud.pause_menu().is_open())
	assert_ne(sky.process_mode, Node.PROCESS_MODE_DISABLED, "and goes on")


func test_a_tap_off_the_pause_menu_resumes() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	hud.open_pause()
	_tap(hud, Vector2i(4, 160))
	assert_false(hud.pause_menu().is_open())
	assert_ne((main.get_node("Sky") as Node).process_mode, Node.PROCESS_MODE_DISABLED)


func test_restart_from_the_pause_menu_starts_a_fresh_run() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	var first: RunState = main.run
	hud.open_pause()
	_tap(hud, hud.pause_menu().item_rect(&"restart").get_center())
	assert_ne(main.run, first, "a new run")
	assert_false(hud.pause_menu().is_open())
	assert_ne((main.get_node("Sky") as Node).process_mode, Node.PROCESS_MODE_DISABLED)


func test_the_pause_menus_sound_cycles_the_speaker() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	var sfx: Sfx = main.get_node("Sfx")
	var before: int = sfx.level
	hud.open_pause()
	_tap(hud, hud.pause_menu().item_rect(&"sound").get_center())
	assert_eq(sfx.level, (before + 1) % Sfx.Level.size())
	assert_eq(hud.sound_level(), sfx.level, "the speaker shows it")
	assert_eq(hud.pause_menu().item_text(&"sound"), OptionsMenu.SOUND_TEXT[sfx.level])
	assert_true(hud.pause_menu().is_open(), "the menu stays")


func test_map_from_the_pause_menu_asks_for_the_chart() -> void:
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	watch_signals(main)
	hud.open_pause()
	_tap(hud, hud.pause_menu().item_rect(&"map").get_center())
	assert_signal_emitted(main, "map_requested")
