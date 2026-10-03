class_name DebugOverlay
extends Node2D
## The debug overlay (#11, debug builds only): edit the balance in memory and restart the run with
## it, and force the next pack to open as a Big Bang. O (or a three-finger tap) opens and closes it.
## Each tunable value of the run's balance (BalanceEdit, in the file's order) is a row with - and +;
## PAGE turns the rows, BANG toggles the forced Big Bang (as key B), APPLY re-validates the edits
## through Balance.from_dict and, if they hold, restarts the run with them (Main), and CLOSE closes.
## balance.json is never written: the edits last until the game quits.
## Like the balance errors' label (a debug tool, not shipped art), its text uses the default font at
## 8 px: the bitmap fonts have no lower case, dots or underscores to show keys and fractions. Its
## colours are palette colours, and it holds the input while open (Main holds the world still).

## APPLY: the edited balance is valid; Main restarts the run with it.
signal apply_requested(balance: Balance)
signal opened
signal closed

const FONT_SIZE: int = 8
const TOP: int = 14
const ROW_H: int = 12
const ROWS: int = 22
const KEY_X: int = 3
## The value's right edge, then the - and + buttons.
const VALUE_RIGHT: int = 134
const MINUS_X: int = 138
const PLUS_X: int = 160
const STEP_W: int = 18
const BUTTONS: Array[String] = ["PAGE", "BANG", "APPLY", "CLOSE"]
const BUTTON_Y: int = 296
const BUTTON_H: int = 20
const BUTTON_W: int = 44

var _run: RunState
var _edit: BalanceEdit
var _page: int = 0
var _keys: Array[String] = []
var _labels: Array[Label] = []
var _values: Array[Label] = []
var _button_labels: Array[Label] = []
var _header: Label
var _error: Label
var _open: bool = false


func _ready() -> void:
	visible = false
	_header = _label(Vector2(KEY_X, 1), Palette.C1)
	_error = _label(Vector2(KEY_X, BUTTON_Y - 12), Palette.C3)
	for i: int in ROWS:
		_labels.append(_label(Vector2(KEY_X, TOP + i * ROW_H), Palette.N8))
		var value: Label = _label(Vector2(VALUE_RIGHT - 40, TOP + i * ROW_H), Palette.C0)
		value.size = Vector2(40, ROW_H)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_values.append(value)
	for i: int in BUTTONS.size():
		var button: Label = _label(Vector2(_button_x(i), BUTTON_Y + 4), Palette.C1)
		button.size = Vector2(BUTTON_W, BUTTON_H - 4)
		button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button_labels.append(button)
	set_process_input(OS.is_debug_build())
	set_process_unhandled_key_input(OS.is_debug_build())


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null and touch.pressed and touch.index == 2:
		toggle()
		get_viewport().set_input_as_handled()
		return
	# It sits on Main's DebugLayer, which fit_screen offsets like the HUD.
	var layer := get_parent() as CanvasLayer
	var offset: Vector2i = Vector2i(layer.offset) if layer != null else Vector2i.ZERO
	if _open and handle_pointer(ScreenZones.to_game(event, offset)):
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_O:
		toggle()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(ScreenZones.SCREEN)), Palette.N0)
	for i: int in _rows_shown():
		var y: int = TOP + i * ROW_H
		for x: int in [MINUS_X, PLUS_X]:
			draw_rect(Rect2(x, y, STEP_W, ROW_H - 1), Palette.N2)
		_draw_sign(MINUS_X, y, false)
		_draw_sign(PLUS_X, y, true)
	for i: int in BUTTONS.size():
		draw_rect(Rect2(_button_x(i), BUTTON_Y, BUTTON_W, BUTTON_H), Palette.N2)


## Hands the overlay the run in play: its balance is what the rows edit (edits applied before carry
## over, since the new run's balance is built from them).
func watch(run: RunState) -> void:
	_run = run
	_edit = BalanceEdit.new(run.balance)
	_keys = _edit.keys()
	_page = mini(_page, pages() - 1)
	_error.text = ""
	_refresh()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open or _run == null or not OS.is_debug_build():
		return
	_open = true
	visible = true
	_refresh()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit()


func pages() -> int:
	return maxi(ceili(_keys.size() / float(ROWS)), 1)


## The edits so far.
func edit() -> BalanceEdit:
	return _edit


## Feeds one touch (on the game's 180x320 screen) while open. Returns true: it takes every touch.
func handle_pointer(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.pressed or touch.canceled:
		return event is InputEventScreenTouch or event is InputEventScreenDrag
	tap(Vector2i(touch.position.floor()))
	return true


## A tap at `at`: a row's - or +, or a button.
func tap(at: Vector2i) -> void:
	if at.y >= BUTTON_Y:
		for i: int in BUTTONS.size():
			if at.x >= _button_x(i) and at.x < _button_x(i) + BUTTON_W:
				press(BUTTONS[i])
		return
	var row: int = floori((at.y - TOP) / float(ROW_H))
	if row < 0 or row >= _rows_shown():
		return
	if at.x >= MINUS_X and at.x < MINUS_X + STEP_W:
		nudge(_page * ROWS + row, -1)
	elif at.x >= PLUS_X and at.x < PLUS_X + STEP_W:
		nudge(_page * ROWS + row, 1)


## Steps the value of row `index` (over every page) by `direction`.
func nudge(index: int, direction: int) -> void:
	if index >= 0 and index < _keys.size() and _edit.step(_keys[index], direction):
		_error.text = ""
		_refresh()


func press(button: String) -> void:
	match button:
		"PAGE":
			_page = (_page + 1) % pages()
		"BANG":
			if _run != null:
				_run.force_next_big_bang = not _run.force_next_big_bang
		"APPLY":
			_apply()
			return
		"CLOSE":
			close()
			return
	_refresh()


func _apply() -> void:
	var balance: Balance = _edit.build()
	if not balance.is_valid():
		_error.text = balance.errors[0]
		return
	close()
	apply_requested.emit(balance)


func _refresh() -> void:
	if _labels.is_empty():
		return
	_header.text = "BALANCE %d/%d  (memory only)" % [_page + 1, pages()]
	for i: int in ROWS:
		var index: int = _page * ROWS + i
		var shown: bool = index < _keys.size()
		_labels[i].text = _keys[index] if shown else ""
		_values[i].text = BalanceEdit.show_value(_edit.value(_keys[index])) if shown else ""
	var bang: bool = _run != null and _run.force_next_big_bang
	for i: int in BUTTONS.size():
		_button_labels[i].text = ("BANG ON" if bang else "BANG") if BUTTONS[i] == "BANG" else BUTTONS[i]
	queue_redraw()


func _rows_shown() -> int:
	return clampi(_keys.size() - _page * ROWS, 0, ROWS)


func _button_x(i: int) -> int:
	return 1 + i * (BUTTON_W + 1)


## A - or + in whole pixels on a step button at (x, y).
func _draw_sign(x: int, y: int, plus: bool) -> void:
	var cx: int = x + STEP_W / 2
	var cy: int = y + ROW_H / 2
	draw_rect(Rect2(cx - 3, cy - 1, 6, 1), Palette.C1)
	if plus:
		draw_rect(Rect2(cx - 1, cy - 3, 1, 5), Palette.C1)


func _label(at: Vector2, colour: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", colour)
	add_child(label)
	return label
