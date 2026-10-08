class_name OptionsMenu
extends CanvasLayer
## The options, over the title and the chart: a gear button (the plaque style, C1 gear) in the
## screen's top-right corner opens a MenuPanel: SOUND (the speaker's on, low, mute, with the
## speaker drawn on it), TUTORIAL (the guided first run again, once it's been finished) and RESET
## PROGRESS (held, since it can't be undone). Tap off the panel or CLOSE to close it. Owns no
## rules: App acts on its signals. Works in game coordinates (App sets the screen like Main's UI).

signal sound_cycle_requested
signal tutorial_requested
signal reset_requested
## Feedback only (sound): the panel opened, closed, a button was tapped, a hold began.
signal opened
signal closed
signal tapped
signal hold_started

const MapButtonScene := preload("res://game/ui/map_button.tscn")
## The gear sits this far in from the screen's top-right corner (like the HUD's top-right button).
const INSET: int = 10
const HEADING: String = "OPTIONS"
const SOUND_TEXT: Array[String] = ["SOUND ON", "SOUND LOW", "SOUND OFF"]
const RESET_NOTE: String = "PROGRESS RESET"

var _gear: MapButton
var _panel := MenuPanel.new()
var _pressed_gear: bool = false
var _level: int = 0
var _tutorial_shown: bool = false
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)


func _ready() -> void:
	layer = 2
	_gear = MapButtonScene.instantiate()
	_gear.name = "Gear"
	_gear.glyph = MapButton.Glyph.GEAR
	add_child(_gear)
	_panel.name = "Panel"
	_panel.heading = HEADING
	add_child(_panel)
	_panel.chosen.connect(_on_chosen)
	_panel.dismissed.connect(close)
	_panel.hold_started.connect(hold_started.emit)
	_build()
	fit_screen(_screen)


func _unhandled_input(event: InputEvent) -> void:
	if visible and handle_pointer(ScreenZones.to_game(event, Vector2i(offset))):
		get_viewport().set_input_as_handled()


## Anchors the gear to the real screen's top-right corner and centres the panel on it (`screen`:
## the visible screen in game coordinates).
func fit_screen(screen: Rect2i) -> void:
	_screen = screen
	offset = Vector2(-screen.position)
	if _gear == null:
		return
	_gear.position = Vector2(Vector2i(screen.end.x - INSET - _gear.plaque_size().x, screen.position.y + INSET))
	_panel.fit_screen(screen)


## The sound level the SOUND button shows (Sfx.Level).
func show_sound_level(level: int) -> void:
	_level = level
	if _panel.ids().has(&"sound"):
		_panel.set_item_text(&"sound", SOUND_TEXT[level])
		_panel.set_item_level(&"sound", level)


## Whether TUTORIAL is offered (once the guided first run has been finished).
func show_tutorial(on: bool) -> void:
	if on == _tutorial_shown:
		return
	_tutorial_shown = on
	_build()


func is_open() -> bool:
	return _panel.is_open()


func open() -> void:
	if _panel.is_open():
		return
	_panel.set_note("")
	_panel.open()
	_gear.visible = false
	opened.emit()


func close() -> void:
	if not _panel.is_open():
		return
	_panel.close()
	_gear.visible = true
	closed.emit()


func panel() -> MenuPanel:
	return _panel


## The gear's tap target (game coordinates).
func gear_target() -> Rect2i:
	return _gear.target()


## Feeds one touch (game coordinates). Returns true if it was used: every touch while the panel is
## open, and the gear's.
func handle_pointer(event: InputEvent) -> bool:
	if _panel.is_open():
		return _panel.handle_pointer(event)
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return false
	var on: bool = gear_target().has_point(Vector2i(touch.position.floor()))
	if touch.pressed:
		_pressed_gear = on
		_gear.pressed = on
		return on
	var was: bool = _pressed_gear
	_pressed_gear = false
	_gear.pressed = false
	if was and on and not touch.canceled:
		tapped.emit()
		open()
	return was


func _build() -> void:
	var items: Array[Dictionary] = [{"id": &"sound", "text": SOUND_TEXT[_level], "level": _level}]
	if _tutorial_shown:
		items.append({"id": &"tutorial", "text": "TUTORIAL"})
	items.append({"id": &"reset", "text": "RESET PROGRESS", "hold": true})
	items.append({"id": &"close", "text": "CLOSE"})
	_panel.set_items(items)


func _on_chosen(id: StringName) -> void:
	tapped.emit()
	match id:
		&"sound":
			sound_cycle_requested.emit()
		&"tutorial":
			close()
			tutorial_requested.emit()
		&"reset":
			reset_requested.emit()
			_panel.set_note(RESET_NOTE)
		&"close":
			close()
