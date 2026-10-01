class_name EndScreen
extends CanvasLayer
## The run's end: when run_won or run_lost has played, this waits for the sequencer to finish
## (so the Sun's ignition plays out) and for every payout particle to land (so the counters
## show what the plaque says), then shows a plaque over everything.
## Win: "SUN RESTORED" and the light. Loss: "THE SUN FADES" and the light reached.
## On the Scorpio map: "SCORPIO COMPLETE" or "SCORPIO UNFINISHED" and the strings formed.
## RESTART asks Main for a new run; in a chapter (#62), MAP beside it goes back to the chart.
## While it shows, it takes every pointer event, so nothing behind it can be touched.
## Owns no rules. Text is bitmap-font Labels (HudText); the plaque is drawn in code: N0 fill,
## N6 border with clipped corners, like the reward plaque. The button is warm: it's interactive.

signal restart_requested
## MAP was tapped (only shown in a chapter, map_enabled).
signal map_requested
## The plaque appeared. Feedback only (sound).
signal shown(won: bool)

const WIDTH: int = 140
const CENTRE_X: int = 90
const TOP: int = 104
const PADDING: int = 8
## Text rows: the 5x7 font's 7 px plus a 4 px gap.
const LINE_STEP: int = 11
## RESTART: 22 px tall, a 44 pt touch target at the phone's 2 pt per px.
const BUTTON_SIZE := Vector2i(64, 22)
const BUTTON_GAP: int = 6
## MAP, beside RESTART when in a chapter.
const MAP_SIZE := Vector2i(44, 22)

## In a chapter: show MAP beside RESTART (Main sets it).
var map_enabled: bool = false

var _run: RunState
var _sequencer: EventSequencer
## run_won or run_lost has played; show once the sequence finishes.
var _ending: bool = false
## The sequence finished but payouts are still flying: show when they land.
var _waiting_for_payouts: bool = false
var _payouts: CollectParticles
var _panel: Rect2i = Rect2i()
## The real screen in game coordinates (fit_screen): the panel centres on it.
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
var _button: Rect2i = Rect2i()
var _map_button: Rect2i = Rect2i()
## Which button a press started on: &"restart", &"map" or &"".
var _pressed_on: StringName = &""

@onready var _canvas: Node2D = $Canvas
@onready var _lines: Node2D = $Canvas/Lines
@onready var _restart: Label = $Canvas/Restart
@onready var _map: Label = $Canvas/Map


func _ready() -> void:
	_canvas.draw.connect(_draw_plaques)
	_restart.label_settings = HudText.primary(Palette.C1)
	_map.label_settings = HudText.primary(Palette.C1)
	visible = false


func _input(event: InputEvent) -> void:
	if handle_pointer(ScreenZones.to_game(event, Vector2i(offset))):
		get_viewport().set_input_as_handled()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
			_sequencer.sequence_finished.disconnect(_on_sequence_finished)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
		_sequencer.sequence_finished.connect(_on_sequence_finished)
	_ending = false
	_waiting_for_payouts = false
	_pressed_on = &""
	visible = false
	_clear_lines()


## The payout particles to wait for before showing (Main wires them).
func watch_payouts(payouts: CollectParticles) -> void:
	_payouts = payouts
	_payouts.all_landed.connect(_on_payouts_landed)


func is_showing() -> bool:
	return visible


## The text rows shown, top to bottom (not the button).
func lines() -> Array[String]:
	var texts: Array[String] = []
	for label: Node in _lines.get_children():
		texts.append((label as Label).text)
	return texts


func restart_rect() -> Rect2i:
	return _button


## MAP's tap target, or an empty rect when it isn't shown.
func map_rect() -> Rect2i:
	return _map_button


## Feeds one touch (in screen coordinates). While showing it takes every pointer event; a tap
## that starts and ends on RESTART asks for a new run. Returns true if the event was taken.
func handle_pointer(event: InputEvent) -> bool:
	if not visible:
		return false
	var touch := event as InputEventScreenTouch
	if touch == null:
		return event is InputEventScreenDrag or event is InputEventMouse
	var point := Vector2i(touch.position.floor())
	var on: StringName = &"restart" if _button.has_point(point) else (&"map" if _map_button.has_point(point) else &"")
	if touch.pressed:
		_pressed_on = on
	elif _pressed_on != &"" and on == _pressed_on and not touch.canceled:
		_pressed_on = &""
		if on == &"restart":
			restart_requested.emit()
		else:
			map_requested.emit()
	else:
		_pressed_on = &""
	return true


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	if event.type == &"run_won" or event.type == &"run_lost":
		_ending = true


func _on_sequence_finished() -> void:
	if not _ending:
		return
	_ending = false
	if _payouts != null and _payouts.particle_count() > 0:
		_waiting_for_payouts = true
	else:
		_show_end()


func _on_payouts_landed() -> void:
	if _waiting_for_payouts:
		_waiting_for_payouts = false
		_show_end()


func _show_end() -> void:
	_clear_lines()
	var light: String = "LIGHT %d/%d" % [_run.light, _run.light_target()]
	var won: bool = _run.outcome == RunState.Outcome.WON
	if _run.scorpio != null:
		# The Scorpio map's objective is the constellation (#40).
		var title: String = _run.scorpio.map.title
		_add_line(title + (" COMPLETE" if won else " UNFINISHED"), Palette.C1 if won else Palette.S4)
		_add_line("STRINGS %d/%d" % [_run.scorpio.built_count(), _run.scorpio.map.segment_count()], Palette.C1)
		if won and _run.scorpio.map.boss:
			_add_line("ORION DEFEATED", Palette.C1)
	elif won:
		_add_line("SUN RESTORED", Palette.C1)
		_add_line(light, Palette.C1)
	else:
		_add_line("THE SUN FADES", Palette.S4)
		_add_line(light, Palette.C1)
	var rows: int = _lines.get_child_count()
	var height: int = PADDING + rows * LINE_STEP + BUTTON_GAP + BUTTON_SIZE.y + PADDING
	var shift: Vector2i = _shift()
	var centre_x: int = CENTRE_X + shift.x
	_panel = Rect2i(centre_x - WIDTH / 2, TOP + shift.y, WIDTH, height)
	# The painted Scorpio stays in view: its panel sits on the bottom edge, over the land and HUD.
	if won and _run.scorpio != null and ConstellationView.paints_figure(_run.scorpio.map):
		var drop: int = _screen.end.y - height - _panel.position.y
		_panel.position.y += drop
		for line: Label in _lines.get_children():
			line.position.y += drop
	var row_y: int = _panel.end.y - PADDING - BUTTON_SIZE.y
	if map_enabled:
		var left: int = centre_x - (BUTTON_SIZE.x + BUTTON_GAP + MAP_SIZE.x) / 2
		_button = Rect2i(left, row_y, BUTTON_SIZE.x, BUTTON_SIZE.y)
		_map_button = Rect2i(_button.end.x + BUTTON_GAP, row_y, MAP_SIZE.x, MAP_SIZE.y)
	else:
		_button = Rect2i(centre_x - BUTTON_SIZE.x / 2, row_y, BUTTON_SIZE.x, BUTTON_SIZE.y)
		_map_button = Rect2i()
	_restart.text = "RESTART"
	_centre_in(_restart, _button)
	_map.visible = map_enabled
	if map_enabled:
		_centre_in(_map, _map_button)
	_pressed_on = &""
	visible = true
	_canvas.queue_redraw()
	shown.emit(_run.outcome == RunState.Outcome.WON)


## Detaches the last ending's rows before freeing them: queue_free alone leaves them counted as
## children until the frame ends, which would push the next ending's rows down.
func _clear_lines() -> void:
	for old: Node in _lines.get_children():
		_lines.remove_child(old)
		old.queue_free()


func _add_line(text: String, colour: Color) -> void:
	var label := Label.new()
	label.label_settings = HudText.primary(colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	_lines.add_child(label)
	_centre(label, TOP + _shift().y + PADDING + (_lines.get_child_count() - 1) * LINE_STEP)


## Sizes a label to its text and centres it in a button, on whole pixels.
func _centre_in(label: Label, button: Rect2i) -> void:
	label.size = label.get_minimum_size()
	label.position = Vector2(button.position.x + floori((button.size.x - label.size.x) / 2.0), button.position.y + (BUTTON_SIZE.y - 7) / 2)


## Sizes a label to its text and centres it on the screen at row `y`, on whole pixels.
func _centre(label: Label, y: int) -> void:
	label.size = label.get_minimum_size()
	label.position = Vector2(CENTRE_X + _shift().x - floori(label.size.x / 2.0), y)


## Centres the panel on the real screen, `screen` in game coordinates (on a 9:16 screen, the
## game's own 0,0 180x320).
func fit_screen(screen: Rect2i) -> void:
	_screen = screen
	if visible and _run != null and _run.is_over():
		_show_end()


## How far the panel moves from where it sits on a 9:16 screen: half the extra the real screen
## shows each way.
func _shift() -> Vector2i:
	return _screen.position + (_screen.size - ScreenZones.SCREEN) / 2


func _draw_plaques() -> void:
	_draw_plaque(_panel, Palette.N0, Palette.N6)
	_draw_plaque(_button, Palette.N0, Palette.C2)
	if map_enabled:
		_draw_plaque(_map_button, Palette.N0, Palette.C2)


## A filled rect with a 1 px border that skips its four corner pixels.
func _draw_plaque(rect: Rect2i, fill: Color, border: Color) -> void:
	var r := Rect2(rect)
	_canvas.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill)
	_canvas.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	_canvas.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	_canvas.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	_canvas.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)
