class_name BossBanner
extends Node2D
## The boss stage's title card (the final): as Orion roars on his entrance, his name stamps onto the
## middle of the sky, "ORION" over "THE HUNTER", between two thin S3 rules tipped with small ember
## stars, like the chart's stage label. The name shows C0 for a moment, then ember (S4); the card
## cuts after SHOW_TIME. No box. Text is bitmap-font Labels; the rules are drawn in code.

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
	_age = 0.0
	_refresh()


func is_showing() -> bool:
	return _age >= OrionView.ROAR_AT and _age < OrionView.ROAR_AT + SHOW_TIME


## Whether the name shows C0 (just stamped).
func is_stamping() -> bool:
	return is_showing() and _age < OrionView.ROAR_AT + STAMP_TIME


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
	if _age >= OrionView.ROAR_AT + SHOW_TIME:
		_age = -1.0
	if is_showing() != was or is_stamping() != stamping:
		_refresh()


func _refresh() -> void:
	visible = is_showing()
	if _name != null:
		_name.label_settings.font_color = Palette.C0 if is_stamping() else Palette.S4
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
			_dot(Vector2i(x, y), Palette.S3)
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(Vector2i(end + side * 2, y) + n, Palette.S4)
		_dot(Vector2i(end + side * 2, y), Palette.C0)


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = HudText.primary(colour)
	label.text = text
	add_child(label)
	label.size = label.get_minimum_size()
	label.position = Vector2(-floori(label.size.x / 2.0), NAME_Y if text == NAME else EPITHET_Y)
	return label


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
