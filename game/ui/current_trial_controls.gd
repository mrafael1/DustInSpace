class_name CurrentTrialControls
extends CanvasLayer
## Debug comparison control, ahead of the launchers' input. Main owns the restart.

signal current_switch_requested

const ButtonScene := preload("res://game/ui/map_button.tscn")
var _button: MapButton
var _caption: Label
var _pressed: bool = false


func _ready() -> void:
	_button = ButtonScene.instantiate()
	_button.position = Vector2(8, 72)
	add_child(_button)
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.label_settings = HudText.secondary(Palette.M5)
	_caption.position = Vector2(8, 88)
	add_child(_caption)
	visible = false
	set_process_input(OS.is_debug_build())


func setup(run: RunState, _sequencer: EventSequencer) -> void:
	visible = OS.is_debug_build() and run.scorpio != null and run.scorpio.map.id.begins_with("current_")
	_pressed = false
	_button.pressed = false
	_button.text = "FLOW ON" if run.current != null else "FLOW OFF"
	_caption.text = "LAUNCH MOVES STARS" if run.current != null else "STARS STAY STILL"


func fit_screen(screen: Rect2i) -> void:
	_button.position = Vector2(screen.position + Vector2i(8, 72))
	_caption.position = Vector2(screen.position + Vector2i(8, 88))


func _input(event: InputEvent) -> void:
	if visible and handle_pointer(ScreenZones.to_game(event, Vector2i(offset))):
		get_viewport().set_input_as_handled()


func handle_pointer(event: InputEvent) -> bool:
	if not visible:
		return false
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return false
	var on_target: bool = _button.target().has_point(Vector2i(touch.position.floor()))
	if touch.pressed:
		_pressed = on_target
		_button.pressed = _pressed
		return _pressed
	var used: bool = _pressed
	_pressed = false
	_button.pressed = false
	if used and on_target and not touch.canceled:
		current_switch_requested.emit()
	return used
