extends GutTest
## Commit 19 (docs/wide_sky_design.md): project.godot's window setup per platform, and the
## fullscreen key. Phones keep exactly today's settings; a desktop (`pc`) opens fullscreen and
## leaves it for a 1280x720 window.

const SIZE := "display/window/size/"
const ORIENTATION := "display/window/handheld/orientation"
const STORE := "user://test_desktop_window_progress.json"
const SETTINGS := "user://test_desktop_window_settings.json"


func _key(keycode: Key, alt: bool = false, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.alt_pressed = alt
	key.pressed = pressed
	key.echo = echo
	return key


func test_phones_keep_todays_window_and_portrait_lock() -> void:
	assert_eq(ProjectSettings.get_setting(SIZE + "mode"), Window.MODE_WINDOWED)
	assert_eq(ProjectSettings.get_setting(SIZE + "window_width_override"), 540)
	assert_eq(ProjectSettings.get_setting(SIZE + "window_height_override"), 960)
	assert_eq(ProjectSettings.get_setting(ORIENTATION), DisplayServer.SCREEN_PORTRAIT, "every handheld starts portrait")
	for tag: String in ["mobile", "android", "ios", "web", "web_android", "web_ios"]:
		assert_false(ProjectSettings.has_setting(ORIENTATION + "." + tag), "no %s orientation override" % tag)
		assert_false(ProjectSettings.has_setting(SIZE + "mode." + tag), "no %s window mode override" % tag)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 180)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 320)


func test_a_desktop_opens_fullscreen_with_a_1280x720_window_to_leave_for() -> void:
	assert_eq(ProjectSettings.get_setting(SIZE + "mode.pc"), Window.MODE_FULLSCREEN, "borderless fullscreen, not exclusive")
	assert_eq(Vector2i(ProjectSettings.get_setting(SIZE + "window_width_override.pc"),
			ProjectSettings.get_setting(SIZE + "window_height_override.pc")), ScreenZones.WINDOWED_SIZE)
	if OS.has_feature("pc") and not OS.has_feature("editor"):
		assert_eq(ProjectSettings.get_setting_with_override(SIZE + "mode"), Window.MODE_FULLSCREEN, "the override applies here")
	if OS.has_feature("pc"):
		assert_eq(ProjectSettings.get_setting_with_override(SIZE + "window_width_override"), ScreenZones.WINDOWED_SIZE.x)
		assert_eq(ProjectSettings.get_setting_with_override(ORIENTATION), DisplayServer.SCREEN_PORTRAIT)


func test_the_editor_runs_the_game_windowed() -> void:
	# Godot won't embed a game that starts fullscreen in the editor's Game tab, and the user playtests
	# from the editor. The `.editor` key comes before `.pc`, so it wins on an editor build (both apply);
	# exported games are templates, without `editor`, and open fullscreen.
	assert_eq(ProjectSettings.get_setting(SIZE + "mode.editor"), Window.MODE_WINDOWED)
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	assert_lt(text.find("window/size/mode.editor="), text.find("window/size/mode.pc="), "the first matching override wins")
	if OS.has_feature("editor"):
		assert_eq(ProjectSettings.get_setting_with_override(SIZE + "mode"), Window.MODE_WINDOWED, "this editor build runs windowed")


func test_f11_and_alt_enter_toggle_fullscreen() -> void:
	assert_true(FullscreenKey.is_toggle(_key(KEY_F11)))
	assert_true(FullscreenKey.is_toggle(_key(KEY_F11, true)))
	assert_true(FullscreenKey.is_toggle(_key(KEY_ENTER, true)))
	assert_true(FullscreenKey.is_toggle(_key(KEY_KP_ENTER, true)))
	assert_false(FullscreenKey.is_toggle(_key(KEY_ENTER)), "Enter alone")
	assert_false(FullscreenKey.is_toggle(_key(KEY_F, true)))
	assert_false(FullscreenKey.is_toggle(_key(KEY_F11, false, false)), "released")
	assert_false(FullscreenKey.is_toggle(_key(KEY_F11, false, true, true)), "held down (a repeat)")
	assert_false(FullscreenKey.is_toggle(null))


func test_the_toggle_goes_to_a_window_and_back() -> void:
	assert_eq(FullscreenKey.next_mode(Window.MODE_FULLSCREEN), Window.MODE_WINDOWED)
	assert_eq(FullscreenKey.next_mode(Window.MODE_EXCLUSIVE_FULLSCREEN), Window.MODE_WINDOWED)
	assert_eq(FullscreenKey.next_mode(Window.MODE_WINDOWED), Window.MODE_FULLSCREEN)
	assert_eq(FullscreenKey.next_mode(Window.MODE_MAXIMIZED), Window.MODE_FULLSCREEN)


func test_the_key_works_while_the_game_holds_still() -> void:
	var key: FullscreenKey = autofree(FullscreenKey.new())
	assert_eq(key.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_the_app_adds_no_key_under_the_headless_display() -> void:
	var app: App = load("res://game/scenes/app.tscn").instantiate()
	app.progress_path = STORE
	app.settings_path = SETTINGS
	app.opens_on_title = false
	add_child_autofree(app)
	for child: Node in app.get_children():
		assert_false(child is FullscreenKey, "tests and bots have no real window")


func after_each() -> void:
	for path: String in [STORE, SETTINGS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
