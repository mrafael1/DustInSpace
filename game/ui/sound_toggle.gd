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

## Where the game's screen sits in the window (ScreenZones.game_offset; Main sets it).
var screen_offset: Vector2i = Vector2i.ZERO
## The speaker's tap target now, in game coordinates: TARGET on a 9:16 screen, the real screen's
## top-left corner otherwise (Main sets it from Hud.sound_target).
var target: Rect2i = TARGET

var _pressed: bool = false


func _input(event: InputEvent) -> void:
	if handle_pointer(ScreenZones.to_game(event, screen_offset)):
		get_viewport().set_input_as_handled()


## Feeds one pointer event (screen coordinates). True if it was the speaker's, and so taken.
func handle_pointer(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return false
	var on_target: bool = target.has_point(Vector2i(touch.position.floor()))
	if touch.pressed:
		_pressed = on_target
		return on_target
	var was_pressed: bool = _pressed
	_pressed = false
	if was_pressed and on_target and not touch.canceled:
		toggled.emit()
	return was_pressed or on_target
