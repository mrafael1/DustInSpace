class_name VolleyCounter
extends Node2D
## Orion's volley countdown (#70), above his head: the number of links left (centred on the node's
## origin, its top there), with a row of pips
## under it that fill as links are counted. Each count hops the number up and flashes it white; on
## the last link it glows between two embers; when the volley fires it shakes and flashes, and the
## next number drops in from above. Solid colour steps and whole-pixel moves only.
## Owns no rules: the HUD tells it what the run's events say.

## A count hops the number HOP px up for HOP_TIME, and flashes it C0 for FLASH_TIME.
const HOP: int = 2
const HOP_TIME: float = 0.14
const FLASH_TIME: float = 0.1
## On the last link the number swaps S4 / C3 every GLOW_STEP.
const GLOW_STEP: float = 0.3
## A volley shakes the number a pixel side to side, SHAKE_STEP a step, flashing, for SHAKE_TIME.
const SHAKE_TIME: float = 0.36
const SHAKE_STEP: float = 0.06
## The next number drops in from DROP px above over DROP_TIME.
const DROP: int = 5
const DROP_TIME: float = 0.18
## The pips: PIP px squares, PIP_GAP apart, PIP_Y px below the number's top.
const PIP: int = 2
const PIP_GAP: int = 2
const PIP_Y: int = 9

var links_left: int = 0
var interval: int = 0

var _time: float = 0.0
var _hop_age: float = -1.0
var _shake_age: float = -1.0
var _drop_age: float = -1.0

@onready var _number: Label = $Number


func _process(delta: float) -> void:
	advance(delta)


## Shows `p_links_left` of `p_interval` at once, no animation (a new run).
func reset(p_links_left: int, p_interval: int) -> void:
	links_left = p_links_left
	interval = p_interval
	_hop_age = -1.0
	_shake_age = -1.0
	_drop_age = -1.0
	_refresh()


## A link was counted, or the volley reset the count: hops, or drops in after a volley.
func count(p_links_left: int) -> void:
	var after_volley: bool = p_links_left > links_left
	links_left = p_links_left
	_shake_age = -1.0
	if after_volley:
		_drop_age = 0.0
		_hop_age = -1.0
	else:
		_hop_age = 0.0
	_refresh()


## The volley fired: the number shakes and flashes.
func fire() -> void:
	_shake_age = 0.0
	_refresh()


func text() -> String:
	return _number.text


func is_shaking() -> bool:
	return _shake_age >= 0.0


## The number's offset from its rest now, in whole pixels.
func offset() -> Vector2i:
	if _shake_age >= 0.0:
		return Vector2i(1 if int(_shake_age / SHAKE_STEP) % 2 == 0 else -1, 0)
	if _drop_age >= 0.0:
		return Vector2i(0, -DROP + mini(int(_drop_age / DROP_TIME * DROP), DROP))
	if _hop_age >= 0.0:
		return Vector2i(0, -HOP if _hop_age < HOP_TIME / 2.0 else -1)
	return Vector2i.ZERO


## The number's colour now: C0 in a flash or on the shake's bright steps, glowing S4 / C3 on the
## last link, N8 before that.
func colour() -> Color:
	if _shake_age >= 0.0:
		return Palette.C0 if int(_shake_age / SHAKE_STEP) % 2 == 0 else Palette.S4
	if _hop_age >= 0.0 and _hop_age < FLASH_TIME:
		return Palette.C0
	if links_left <= 1:
		return Palette.S4 if int(_time / GLOW_STEP) % 2 == 0 else Palette.C3
	return Palette.N8


## The pips, centred under the counter's origin, filled ones first: how many links have counted.
func pip_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var width: int = interval * PIP + (interval - 1) * PIP_GAP
	var left: int = -floori(width / 2.0)
	var filled: int = interval - links_left
	for i: int in interval:
		var colour_i: Color = (Palette.S4 if links_left <= 1 else Palette.N8) if i < filled else Palette.N5
		for x: int in PIP:
			for y: int in PIP:
				dots[Vector2i(left + i * (PIP + PIP_GAP) + x, PIP_Y + y)] = colour_i
	return dots


func advance(delta: float) -> void:
	var before: Array = [offset(), colour()]
	_time += delta
	if _hop_age >= 0.0:
		_hop_age += delta
		if _hop_age >= HOP_TIME:
			_hop_age = -1.0
	if _shake_age >= 0.0:
		_shake_age += delta
		if _shake_age >= SHAKE_TIME:
			_shake_age = -1.0
	if _drop_age >= 0.0:
		_drop_age += delta
		if _drop_age >= DROP_TIME:
			_drop_age = -1.0
	if [offset(), colour()] != before:
		_refresh()


func _refresh() -> void:
	if _number == null:
		return
	_number.text = "%d" % links_left
	_number.label_settings = HudText.primary(colour())
	_number.size = _number.get_minimum_size()
	_number.position = Vector2(offset() - Vector2i(floori(_number.size.x / 2.0), 0))
	queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pip_pixels()
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])
