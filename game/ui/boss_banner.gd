class_name BossBanner
extends Node2D
## A final's title card: its name stamps onto the middle of the sky over an epithet, between two
## thin rules tipped with small stars, like the chart's stage label. The name shows C0 for a moment,
## then its own colour; the card cuts after its time. No box. Text is bitmap-font Labels; the rules
## are drawn in code. Scorpio's (play): as Orion roars on his entrance, "ORION" over "THE HUNTER",
## ember. Aquarius's (play_arrival): at once, "AQUARIUS" over "THE WATER BEARER", in cool water
## colours, as its box of drains comes alight.

const NAME: String = "ORION"
const EPITHET: String = "THE HUNTER"
## The card waits for the roar (OrionView.ROAR_AT), stamps C0 for STAMP_TIME, then shows ember until
## SHOW_TIME after it appeared.
const STAMP_TIME: float = 0.08
const SHOW_TIME: float = OrionView.ROAR_TIME + OrionView.ENTER_HOLD
## Rows of the name and the epithet from the card's centre, and the rules either side of the name.
const NAME_Y: int = -9
const EPITHET_Y: int = 3
const RULE: int = 16
const RULE_GAP: int = 5

## Seconds since the card was asked for (-1: hidden).
var _age: float = -1.0
## This card's wait before it shows, how long it shows, and its name's and rules' colours.
var _wait: float = OrionView.ROAR_AT
var _show: float = SHOW_TIME
var _colour: Color = Palette.S4
var _rule: Color = Palette.S3
var _name: Label
var _epithet: Label


func _ready() -> void:
	_name = _label(NAME, Palette.S4)
	_epithet = _label(EPITHET, Palette.N8)
	visible = false


func _process(delta: float) -> void:
	advance(delta)


## Orion is entering: the card shows once he roars.
func play() -> void:
	_set_card(NAME, EPITHET, OrionView.ROAR_AT, SHOW_TIME, Palette.S4, Palette.S3)
	_age = 0.0
	_refresh()


## Another final arrives (no threat, no roar): `title` over `epithet`, shown at once for `seconds`,
## its name in `colour` and its rules in `rule`.
func play_arrival(title: String, epithet: String, seconds: float, colour: Color, rule: Color) -> void:
	_set_card(title, epithet, 0.0, seconds, colour, rule)
	_age = 0.0
	_refresh()


func _set_card(title: String, epithet: String, wait: float, seconds: float, colour: Color, rule: Color) -> void:
	_wait = wait
	_show = seconds
	_colour = colour
	_rule = rule
	_place(_name, title, NAME_Y)
	_place(_epithet, epithet, EPITHET_Y)


func is_showing() -> bool:
	return _age >= _wait and _age < _wait + _show


## Whether the name shows C0 (just stamped).
func is_stamping() -> bool:
	return is_showing() and _age < _wait + STAMP_TIME


func hide_card() -> void:
	_age = -1.0
	_refresh()


## Moves the card on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _age < 0.0:
		return
	var was: bool = is_showing()
	var stamping: bool = is_stamping()
	_age += delta
	if _age >= _wait + _show:
		_age = -1.0
	if is_showing() != was or is_stamping() != stamping:
		_refresh()


func _refresh() -> void:
	visible = is_showing()
	if _name != null:
		_name.label_settings.font_color = Palette.C0 if is_stamping() else _colour
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var y: int = NAME_Y + 3
	var half: int = floori(_name.size.x / 2.0)
	for side: int in [-1, 1]:
		var start: int = side * (half + RULE_GAP)
		var end: int = start + side * RULE
		for x: int in range(mini(start, end), maxi(start, end) + 1):
			_dot(Vector2i(x, y), _rule)
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(Vector2i(end + side * 2, y) + n, _colour)
		_dot(Vector2i(end + side * 2, y), Palette.C0)


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = HudText.primary(colour)
	add_child(label)
	_place(label, text, NAME_Y if text == NAME else EPITHET_Y)
	return label


## Sets a label's text and centres it on the card at row `y`.
func _place(label: Label, text: String, y: int) -> void:
	if label == null:
		return
	label.text = text
	label.size = label.get_minimum_size()
	label.position = Vector2(-floori(label.size.x / 2.0), y)


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
