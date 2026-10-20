class_name CurrentTrialControls
extends CanvasLayer
## Debug comparison control, ahead of the launchers' input. Main owns the restart.
## It sits by the run's frame (the portrait 180-column band holding the figure), a row of the screen's
## top down, so on a wide sky it stays by the constellation, not out at the visible screen's left edge.

signal current_switch_requested

const ButtonScene := preload("res://game/ui/map_button.tscn")
## The button's top-left from the frame's left edge and the visible screen's top; the caption below it.
const BUTTON_AT := Vector2i(8, 72)
const CAPTION_AT := Vector2i(8, 88)

var _button: MapButton
var _caption: Label
var _pressed: bool = false
## The run's frame's left edge (ScreenZones.SKY's before a run) and the visible screen's top.
var _frame_x: int = ScreenZones.SKY.position.x
var _screen_top: int = 0


func _ready() -> void:
	_button = ButtonScene.instantiate()
	_button.position = Vector2(8, 72)
	add_child(_button)
	_caption = Label.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.label_settings = HudText.secondary(Palette.M5)
	add_child(_caption)
	_place()
	visible = false
	set_process_input(OS.is_debug_build())


func setup(run: RunState, _sequencer: EventSequencer) -> void:
	_frame_x = run.frame_rect.position.x
	_place()
	var id: String = run.scorpio.map.id if run.scorpio != null else ""
	visible = OS.is_debug_build() and (id.begins_with("current_") or id.begins_with("black_hole") or id.begins_with("cord") or id.begins_with("ram"))
	_pressed = false
	_button.pressed = false
	if id.begins_with("ram"):
		_button.text = "RAM ON" if run.ram != null else "RAM OFF"
		_caption.text = "THE RAM BUTTS STARS" if run.ram != null else "STARS STAY STILL"
		return
	if id.begins_with("cord"):
		_button.text = "CORD ON" if run.cords != null else "CORD OFF"
		_caption.text = "LINKS LEAVE CORDS" if run.cords != null else "LINKS LEAVE NOTHING"
		return
	if run.scorpio != null and run.scorpio.map.id.begins_with("black_hole"):
		_button.text = "HOLE ON" if run.gravity != null else "HOLE OFF"
		_caption.text = "STARS FALL IN" if run.gravity != null else "STARS STAY STILL"
		return
	_button.text = "FLOW ON" if run.current != null else "FLOW OFF"
	if run.current == null:
		_caption.text = "STARS STAY STILL"
	else:
		_caption.text = "DRAIN TAKES STARS" if run.current.drains else "LAUNCH MOVES STARS"


## `screen`: the visible screen in game px. Only its top is used; the left comes from the frame.
func fit_screen(screen: Rect2i) -> void:
	_screen_top = screen.position.y
	_place()


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


func _place() -> void:
	var anchor := Vector2i(_frame_x, _screen_top)
	_button.position = Vector2(anchor + BUTTON_AT)
	_caption.position = Vector2(anchor + CAPTION_AT)
