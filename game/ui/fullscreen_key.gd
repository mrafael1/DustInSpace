class_name FullscreenKey
extends Node
## F11 or Alt+Enter on a desktop: fullscreen to a window and back (docs/wide_sky_design.md Q1). The
## game opens fullscreen there (project.godot's `.pc` overrides); leaving it gives a
## ScreenZones.WINDOWED_SIZE window centred on its screen, or a maximised one when that size (with
## its title bar) doesn't fit the screen's usable area, as on a 1366x768 laptop. It works while the
## game holds still for the sky (process mode ALWAYS), so a window too small for the run can go
## back to fullscreen. App adds it on the `pc` feature only. Owns no rules.


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if is_toggle(event as InputEventKey):
		toggle(get_window())
		get_viewport().set_input_as_handled()


## Whether `key` is the fullscreen key: F11, or Enter (either one) with Alt held; pressed, not a repeat.
static func is_toggle(key: InputEventKey) -> bool:
	if key == null or not key.pressed or key.echo:
		return false
	if key.keycode == KEY_F11:
		return true
	return key.alt_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)


## The mode the toggle takes `mode` to: a window from either fullscreen, fullscreen from anything else.
static func next_mode(mode: Window.Mode) -> Window.Mode:
	if mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return Window.MODE_WINDOWED
	return Window.MODE_FULLSCREEN


## Switches `window` between fullscreen and a window (next_mode). A window takes WINDOWED_SIZE,
## centred, unless that doesn't fit the screen's usable area with its decorations: then it's maximised.
func toggle(window: Window) -> void:
	var mode: Window.Mode = next_mode(window.mode)
	window.mode = mode
	if mode != Window.MODE_WINDOWED:
		return
	window.size = ScreenZones.WINDOWED_SIZE
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(window.current_screen).size
	var outer: Vector2i = window.get_size_with_decorations()
	if outer.x > usable.x or outer.y > usable.y:
		window.mode = Window.MODE_MAXIMIZED
	else:
		window.move_to_center()
