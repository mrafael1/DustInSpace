class_name SoundToggle
extends Node
## Takes taps on the HUD's speaker ahead of every gameplay gate: Main's last child, so its
## `_input` runs before the EventSequencer's (which swallows pointers while a sequence plays)
## and the EndScreen's (which takes them while it shows). The sound can be turned down during a
## Big Bang or over the win jingle; everything else stays blocked, since only taps on TARGET are
## taken. A tap is a press and a release both on TARGET. The HUD draws the speaker.

signal toggled

## The speaker's tap target on the 180x320 screen: the HUD's SoundIcon position + SoundIcon.TARGET.
const TARGET := Rect2i(0, 0, 22, 22)

var _pressed: bool = false


func _input(event: InputEvent) -> void:
	if handle_pointer(event):
		get_viewport().set_input_as_handled()


## Feeds one pointer event (screen coordinates). True if it was the speaker's, and so taken.
func handle_pointer(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return false
	var on_target: bool = TARGET.has_point(Vector2i(touch.position.floor()))
	if touch.pressed:
		_pressed = on_target
		return on_target
	var was_pressed: bool = _pressed
	_pressed = false
	if was_pressed and on_target and not touch.canceled:
		toggled.emit()
	return was_pressed or on_target
