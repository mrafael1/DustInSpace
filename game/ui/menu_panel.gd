class_name MenuPanel
extends Node2D
## A menu over the game: a plaque (N0 fill, N6 border, like the table's) with a heading (5x7, C1)
## and a column of buttons in the game's button style (M1 fill, C2 border, C1 text; M3 while
## pressed). Used by the options (title and chart) and the stage's pause menu. While it's open it
## takes every touch: a tap on a button chooses it, a tap off the plaque dismisses the menu.
## A button can carry the speaker (its sound level, drawn like the HUD's) at its left. A `hold`
## button (RESET PROGRESS) must be held for HOLD_TIME: an ember (S4) fill creeps across it while
## it's held, and the line under the buttons says HOLD_TEXT; let go early or slide off and nothing
## happens. Once full it flashes C0 and is chosen. Owns no rules: the owner acts on `chosen`.
## Positions are in the parent's coordinates; fit_screen centres it on the visible screen.

## A button was chosen: its id.
signal chosen(id: StringName)
## A tap off the plaque.
signal dismissed
## Feedback only (sound): a hold started.
signal hold_started

## The plaque: WIDTH wide, PAD px inside its border; the heading, then each button BUTTON_H tall,
## BUTTON_GAP apart, BUTTON_W wide, centred.
const WIDTH: int = 116
const PAD: int = 8
const HEADING_H: int = 7
const HEADING_GAP: int = 9
const BUTTON_W: int = 96
const BUTTON_H: int = 15
const BUTTON_GAP: int = 5
## The line under the buttons (3x5): NOTE_GAP px below them.
const NOTE_GAP: int = 5
const NOTE_H: int = 5
## A hold button fills over HOLD_TIME, then flashes C0 for HOLD_FLASH.
const HOLD_TIME: float = 1.2
const HOLD_FLASH: float = 0.12
const HOLD_TEXT: String = "HOLD TO CONFIRM"
## The speaker sits this far in from a button's left.
const ICON_INSET: int = 6

var heading: String = "":
	set(value):
		heading = value
		if _heading != null:
			_heading.text = value
		_layout()

var _open: bool = false
## The buttons: {"id": StringName, "text": String, "hold": bool, "level": int (-1: no speaker)}.
var _items: Array[Dictionary] = []
var _labels: Array[Label] = []
var _heading: Label
var _note: Label
## The plaque's top-left (parent coordinates); its size follows the buttons.
var _at := Vector2i.ZERO
## The visible screen (parent coordinates).
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
## The button pressed (-1: none; -2: a press off the plaque) and the hold's seconds (-1: none).
var _pressed: int = -1
var _hold: float = -1.0
var _flash: float = -1.0
var _flash_id: StringName = &""
## The note's own text (what the owner says), and the hold's for a while.
var _note_text: String = ""
var _note_left: float = 0.0


func _ready() -> void:
	visible = false
	_heading = Label.new()
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading.label_settings = HudText.primary(Palette.C1)
	_heading.text = heading
	add_child(_heading)
	_note = Label.new()
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.label_settings = HudText.secondary(Palette.N8)
	add_child(_note)
	_layout()


func _process(delta: float) -> void:
	advance(delta)


## Sets the buttons: each {"id": StringName, "text": String} with optional "hold": true and
## "level": a sound level for the speaker.
func set_items(items: Array[Dictionary]) -> void:
	_items.clear()
	for item: Dictionary in items:
		_items.append({"id": item["id"], "text": item["text"], "hold": item.get("hold", false), "level": item.get("level", -1)})
	for label: Label in _labels:
		label.queue_free()
	_labels.clear()
	for item: Dictionary in _items:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.label_settings = HudText.primary(Palette.C1)
		label.text = item["text"]
		add_child(label)
		_labels.append(label)
	_pressed = -1
	_hold = -1.0
	_layout()


func ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for item: Dictionary in _items:
		found.append(item["id"])
	return found


func item_text(id: StringName) -> String:
	var i: int = _index(id)
	return _items[i]["text"] if i >= 0 else ""


func set_item_text(id: StringName, text: String) -> void:
	var i: int = _index(id)
	if i < 0:
		return
	_items[i]["text"] = text
	_labels[i].text = text
	_layout()


## The speaker on button `id` shows `level` (Sfx.Level).
func set_item_level(id: StringName, level: int) -> void:
	var i: int = _index(id)
	if i >= 0:
		_items[i]["level"] = level
		queue_redraw()


## The line under the buttons says `text` (N8), unless a hold's note is showing.
func set_note(text: String) -> void:
	_note_text = text
	if _note_left <= 0.0:
		_show_note(text, Palette.N8)


func open() -> void:
	_open = true
	visible = true
	_pressed = -1
	_hold = -1.0
	_flash = -1.0
	_note_left = 0.0
	_show_note(_note_text, Palette.N8)
	queue_redraw()


func close() -> void:
	_open = false
	visible = false
	_pressed = -1
	_hold = -1.0


func is_open() -> bool:
	return _open


## Centres the plaque on `screen` (the visible screen, parent coordinates): across the game's own
## 180 columns, down the screen's middle.
func fit_screen(screen: Rect2i) -> void:
	_screen = screen
	_layout()


## The plaque, in the parent's coordinates.
func plaque_rect() -> Rect2i:
	var height: int = 2 * PAD + HEADING_H + HEADING_GAP + _items.size() * (BUTTON_H + BUTTON_GAP) - BUTTON_GAP
	if _has_note():
		height += NOTE_GAP + NOTE_H
	return Rect2i(_at, Vector2i(WIDTH, height))


## Button `id`'s plaque (its tap target too: 15 px tall, 30 pt), in the parent's coordinates.
func item_rect(id: StringName) -> Rect2i:
	var i: int = _index(id)
	return _button_rect(i) if i >= 0 else Rect2i()


## How far a hold has gone (0-1), or -1 when none is held.
func hold_progress() -> float:
	return clampf(_hold / HOLD_TIME, 0.0, 1.0) if _hold >= 0.0 else -1.0


func note() -> String:
	return _note.text if _note != null else ""


## Feeds one touch or drag (parent coordinates). Returns true while open: the menu takes them all.
func handle_pointer(event: InputEvent) -> bool:
	if not _open:
		return false
	var drag := event as InputEventScreenDrag
	if drag != null:
		# Sliding off a held button lets it go.
		if _pressed >= 0 and not _button_rect(_pressed).has_point(Vector2i(drag.position.floor())):
			_release_hold()
			_pressed = -1
			queue_redraw()
		return true
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0:
		return event is InputEventScreenTouch
	var at := Vector2i(touch.position.floor())
	if touch.pressed:
		_pressed = _item_at(at)
		if _pressed < 0 and not plaque_rect().has_point(at):
			_pressed = -2
		if _pressed >= 0 and _items[_pressed]["hold"]:
			_hold = 0.0
			hold_started.emit()
		queue_redraw()
		return true
	var was: int = _pressed
	_pressed = -1
	queue_redraw()
	if touch.canceled:
		_release_hold()
		return true
	if was == -2 and not plaque_rect().has_point(at):
		dismissed.emit()
	elif was >= 0 and _item_at(at) == was:
		if _items[was]["hold"]:
			_release_hold()
		else:
			chosen.emit(_items[was]["id"])
	return true


## Moves a hold, its flash and the note on. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0:
			_show_note(_note_text, Palette.N8)
	if _flash >= 0.0:
		_flash += delta
		if _flash >= HOLD_FLASH:
			_flash = -1.0
			_flash_id = &""
		queue_redraw()
	if _hold < 0.0 or _pressed < 0:
		return
	_hold += delta
	_show_note(HOLD_TEXT, Palette.S4)
	_note_left = 1.6
	if _hold >= HOLD_TIME:
		var item: int = _pressed
		_hold = -1.0
		# Chosen once: the press is used up.
		_pressed = -1
		_flash = 0.0
		_flash_id = _items[item]["id"]
		_note_left = 0.0
		_show_note(_note_text, Palette.N8)
		chosen.emit(_items[item]["id"])
	queue_redraw()


## A hold let go before it filled: it empties, and the note says how it's done.
func _release_hold() -> void:
	if _hold < 0.0:
		return
	_hold = -1.0
	_show_note(HOLD_TEXT, Palette.S4)
	_note_left = 1.6


func _show_note(text: String, colour: Color) -> void:
	if _note == null:
		return
	_note.text = text
	_note.label_settings.font_color = colour
	_note.size = _note.get_minimum_size()
	var plaque: Rect2i = plaque_rect()
	_note.position = Vector2(plaque.position.x + (WIDTH - floori(_note.size.x)) / 2, plaque.end.y - PAD - NOTE_H)


## The line under the buttons has room only in a menu with a hold button (whose note it carries).
func _has_note() -> bool:
	for item: Dictionary in _items:
		if item["hold"]:
			return true
	return false


func _index(id: StringName) -> int:
	for i: int in _items.size():
		if _items[i]["id"] == id:
			return i
	return -1


func _item_at(at: Vector2i) -> int:
	for i: int in _items.size():
		if _button_rect(i).has_point(at):
			return i
	return -1


func _button_rect(i: int) -> Rect2i:
	var top: int = _at.y + PAD + HEADING_H + HEADING_GAP + i * (BUTTON_H + BUTTON_GAP)
	return Rect2i(_at.x + (WIDTH - BUTTON_W) / 2, top, BUTTON_W, BUTTON_H)


func _layout() -> void:
	var height: int = plaque_rect().size.y
	_at = Vector2i((ScreenZones.SCREEN.x - WIDTH) / 2, _screen.position.y + (_screen.size.y - height) / 2)
	if _heading != null:
		_heading.size = _heading.get_minimum_size()
		_heading.position = Vector2(_at.x + (WIDTH - floori(_heading.size.x)) / 2, _at.y + PAD)
	for i: int in _labels.size():
		var label: Label = _labels[i]
		label.size = label.get_minimum_size()
		var button: Rect2i = _button_rect(i)
		label.position = Vector2(button.position.x + (BUTTON_W - floori(label.size.x)) / 2, button.position.y + 4)
	if _note != null:
		_show_note(_note.text, _note.label_settings.font_color)
	queue_redraw()


func _draw() -> void:
	if not _open:
		return
	_plaque(plaque_rect(), Palette.N0, Palette.N6)
	for i: int in _items.size():
		var button: Rect2i = _button_rect(i)
		var held: bool = i == _pressed
		_plaque(button, Palette.M3 if held and not _items[i]["hold"] else Palette.M1, Palette.C2)
		if i == _pressed and _hold >= 0.0:
			var width: int = floori((BUTTON_W - 2) * hold_progress())
			draw_rect(Rect2(button.position.x + 1, button.position.y + 1, width, BUTTON_H - 2), Palette.S4)
		if _flash >= 0.0 and _items[i]["id"] == _flash_id:
			_plaque(button, Palette.C0, Palette.C0)
		var level: int = _items[i]["level"]
		if level >= 0:
			for dot: Vector2i in SoundIcon.pixels(level):
				draw_rect(Rect2(Vector2(button.position + Vector2i(ICON_INSET, 4) + dot), Vector2.ONE), Palette.C1)


## A filled rect with a 1 px border that skips its four corner pixels.
func _plaque(rect: Rect2i, fill: Color, border: Color) -> void:
	var r := Rect2(rect)
	draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill)
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)
