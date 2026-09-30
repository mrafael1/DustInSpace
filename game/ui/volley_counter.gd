class_name VolleyCounter
extends Node2D
## Orion's volley countdown (#70), above his head: a row of pips, one per link between volleys,
## centred on the node's origin (their top there). They fill as links are counted. Each count hops
## the row up and flashes the lit pips white; on the last link the lit pips glow between two embers;
## when the volley fires the whole row shakes and flashes, stays lit ember while the arrows fly, then
## drops back in, empty, from above.
## Solid colour steps and whole-pixel moves only. No number: the pips are the count.
## Owns no rules: the HUD tells it what the run's events say.

## A count hops the row HOP px up for HOP_TIME, and flashes the lit pips C0 for FLASH_TIME.
const HOP: int = 2
const HOP_TIME: float = 0.14
const FLASH_TIME: float = 0.1
## On the last link the lit pips swap S4 / C3 every GLOW_STEP.
const GLOW_STEP: float = 0.3
## A volley shakes the row a pixel side to side, SHAKE_STEP a step, flashing, for SHAKE_TIME.
const SHAKE_TIME: float = 0.36
const SHAKE_STEP: float = 0.06
## The emptied row drops in from DROP px above over DROP_TIME.
const DROP: int = 5
const DROP_TIME: float = 0.18
## The pips: PIP px squares, PIP_GAP apart. Unlit ones are N5.
const PIP: int = 3
const PIP_GAP: int = 2

var links_left: int = 0
var interval: int = 0

var _time: float = 0.0
var _hop_age: float = -1.0
var _shake_age: float = -1.0
var _drop_age: float = -1.0
## The volley fired and the count hasn't reset yet: every pip stays lit.
var _fired: bool = false


func _process(delta: float) -> void:
	advance(delta)


## Shows `p_links_left` of `p_interval` at once, no animation (a new run).
func reset(p_links_left: int, p_interval: int) -> void:
	links_left = p_links_left
	interval = p_interval
	_hop_age = -1.0
	_shake_age = -1.0
	_drop_age = -1.0
	_fired = false
	queue_redraw()


## A link was counted, or the volley reset the count: hops, or drops in after a volley.
func count(p_links_left: int) -> void:
	var after_volley: bool = p_links_left > links_left
	links_left = p_links_left
	_shake_age = -1.0
	_fired = false
	if after_volley:
		_drop_age = 0.0
		_hop_age = -1.0
	else:
		_hop_age = 0.0
	queue_redraw()


## The volley fired: the row shakes and flashes.
func fire() -> void:
	_shake_age = 0.0
	_fired = true
	queue_redraw()


## The count as text, for tests and the HUD: the links left.
func text() -> String:
	return "%d" % links_left


func lit_count() -> int:
	return interval - links_left


func is_shaking() -> bool:
	return _shake_age >= 0.0


## The row's offset from its rest now, in whole pixels.
func offset() -> Vector2i:
	if _shake_age >= 0.0:
		return Vector2i(1 if int(_shake_age / SHAKE_STEP) % 2 == 0 else -1, 0)
	if _drop_age >= 0.0:
		return Vector2i(0, -DROP + mini(int(_drop_age / DROP_TIME * DROP), DROP))
	if _hop_age >= 0.0:
		return Vector2i(0, -HOP if _hop_age < HOP_TIME / 2.0 else -1)
	return Vector2i.ZERO


## The lit pips' colour now: C0 in a flash, glowing S4 / C3 on the last link, N8 before that.
## While the volley shakes the row, every pip flashes C0 / S4.
func colour() -> Color:
	if _shake_age >= 0.0:
		return Palette.C0 if int(_shake_age / SHAKE_STEP) % 2 == 0 else Palette.S4
	if _fired:
		return Palette.S4
	if _hop_age >= 0.0 and _hop_age < FLASH_TIME:
		return Palette.C0
	if links_left <= 1:
		return Palette.S4 if int(_time / GLOW_STEP) % 2 == 0 else Palette.C3
	return Palette.N8


## The pips now (relative to the node, offset included), lit ones first from the left.
func pip_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var width: int = interval * PIP + (interval - 1) * PIP_GAP
	var left: int = -floori(width / 2.0)
	var lit: int = interval if _fired else lit_count()
	for i: int in interval:
		var colour_i: Color = colour() if i < lit else Palette.N5
		for x: int in PIP:
			for y: int in PIP:
				dots[offset() + Vector2i(left + i * (PIP + PIP_GAP) + x, y)] = colour_i
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
		queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pip_pixels()
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])
