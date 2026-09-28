class_name OrionView
extends Node2D
## Orion the hunter (#64), on stages he hunts: his figure, dim in the sky's top-left corner (drawn
## on the FigureLayer, under the stars), the ember crosshair closing on the star he marked (a cue
## unlike the warm selection ring, the gold lit landmarks and the unlit landmarks' corner hints),
## and his arrow flying to it.
## Owns no rules: SkyView tells it what the events say.

## Orion bent his bow: the arrow is off. Feedback only (sound).
signal arrow_loosed

## The figure brightens and draws the bow, then the arrow flies; the star breaks as it lands.
const DRAW_TIME: float = 0.2
const FLIGHT_TIME: float = 0.35
## The arrow's shaft, behind its tip.
const SHAFT: int = 7
## A new mark's reticle closes in from this much further out, a pixel a step.
const LOCK_STEPS: int = 3
const LOCK_STEP_TIME: float = 0.06
## The reticle blinks off briefly once a period, so a marked star keeps catching the eye.
const BLINK_PERIOD: float = 1.2
const BLINK_OFF: float = 0.12
## Where the figure sits: this far into the play sky from its top-left corner.
const FIGURE_AT := Vector2i(8, 6)
## Orion's stars (figure coordinates): Meissa (head), Betelgeuse, Bellatrix, the belt, Saiph,
## Rigel; and his bow held up and right, towards the sky he hunts.
const HEAD := Vector2i(13, 0)
const BODY: Array[Vector2i] = [Vector2i(6, 5), Vector2i(20, 7), Vector2i(10, 19), Vector2i(13, 18), Vector2i(16, 17), Vector2i(19, 31), Vector2i(7, 33)]
const BOW: Array[Vector2i] = [Vector2i(25, 1), Vector2i(27, 4), Vector2i(28, 7), Vector2i(27, 10), Vector2i(25, 13)]
## The figure's lines, between BODY stars (by index) and to the bow hand.
const LINES: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 4), Vector2i(2, 5), Vector2i(4, 6), Vector2i(0, 3), Vector2i(1, 3)]
const BOW_HAND := Vector2i(24, 7)

var _figure_shown: bool = false
var _figure_at: Vector2i = Vector2i.ZERO
## The marked star's view, or null.
var _marked: StarView
var _mark_age: float = 0.0
## The arrow: where from, where to, and how long since the bow was drawn (-1: none).
var _arrow_from: Vector2i = Vector2i.ZERO
var _arrow_to: Vector2i = Vector2i.ZERO
var _arrow_age: float = -1.0
## The shot star's size: its crosshair stays on it until the arrow lands.
var _arrow_size: int = 0

@onready var _figure_layer: Node2D = get_node("../FigureLayer")


func _ready() -> void:
	_figure_layer.draw.connect(_draw_figure)


func _process(delta: float) -> void:
	advance(delta)


## Shows the figure for a run Orion hunts (in `sky`'s top-left), hides everything otherwise.
func setup(hunts: bool, sky: Rect2i) -> void:
	_figure_shown = hunts
	_figure_at = sky.position + FIGURE_AT
	_marked = null
	_arrow_age = -1.0
	queue_redraw()
	_figure_layer.queue_redraw()


func is_figure_shown() -> bool:
	return _figure_shown


## Where the arrow leaves from: the bow hand.
func bow_hand() -> Vector2i:
	return _figure_at + BOW_HAND


## Orion marked the star `view` shows.
func mark(view: StarView) -> void:
	_marked = view
	_mark_age = 0.0
	queue_redraw()


func marked() -> StarView:
	return _marked if is_instance_valid(_marked) else null


func clear_mark() -> void:
	_marked = null
	queue_redraw()


## Orion shoots the star of `size` at `at`: the bow draws, then the arrow flies there; the
## crosshair stays on it until it lands. Returns how long until it lands.
func shoot(at: Vector2i, size: int) -> float:
	_marked = null
	_arrow_from = bow_hand()
	_arrow_to = at
	_arrow_size = size
	_arrow_age = 0.0
	queue_redraw()
	_figure_layer.queue_redraw()
	return DRAW_TIME + FLIGHT_TIME


func is_shooting() -> bool:
	return _arrow_age >= 0.0


func advance(delta: float) -> void:
	if _marked != null:
		if not is_instance_valid(_marked) or _marked.is_queued_for_deletion():
			_marked = null
		_mark_age += delta
		queue_redraw()
	if _arrow_age >= 0.0:
		var drawn: bool = _arrow_age >= DRAW_TIME
		_arrow_age += delta
		if not drawn and _arrow_age >= DRAW_TIME:
			arrow_loosed.emit()
		if _arrow_age >= DRAW_TIME + FLIGHT_TIME:
			_arrow_age = -1.0
		queue_redraw()
		_figure_layer.queue_redraw()


## The crosshair around a star of `size`, `lock` px further out than at rest: a tick of two pixels
## pointing in from each side (up, down, left, right), clear of the star and its selection ring.
static func reticle_pixels(size: int, lock: int = 0) -> Array[Vector2i]:
	var d: int = StarView.half_extent(size as Star.Size) + 3 + lock
	var pixels: Array[Vector2i] = []
	for axis: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		pixels.append(axis * d)
		pixels.append(axis * (d + 1))
	return pixels


## The reticle's lock-in step now: LOCK_STEPS down to 0.
func lock_step() -> int:
	return maxi(LOCK_STEPS - int(_mark_age / LOCK_STEP_TIME), 0)


func shows_reticle() -> bool:
	if marked() == null:
		return false
	return lock_step() > 0 or fmod(_mark_age, BLINK_PERIOD) < BLINK_PERIOD - BLINK_OFF


## The arrow's pixels now, tip last, or none: its shaft trails SHAFT px behind the tip.
func arrow_pixels() -> Array[Vector2i]:
	if _arrow_age < DRAW_TIME:
		return []
	var k: float = minf((_arrow_age - DRAW_TIME) / FLIGHT_TIME, 1.0)
	var from := Vector2(_arrow_from)
	var tip: Vector2 = from.lerp(Vector2(_arrow_to), k)
	var back: Vector2 = (from - Vector2(_arrow_to)).normalized() * SHAFT
	var tail: Vector2 = tip + back if tip.distance_to(from) > SHAFT else from
	return LinkLayer.line_pixels(Vector2i(tail.round()), Vector2i(tip.round()))


## The figure's pixels and colours: dim cool dots and faint lines; bright while he shoots.
func figure_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if not _figure_shown:
		return dots
	var hunting: bool = is_shooting()
	var line_colour: Color = Palette.N5 if hunting else Palette.N3
	for pair: Vector2i in LINES:
		for p: Vector2i in LinkLayer.line_pixels(BODY[pair.x], BODY[pair.y]):
			dots[_figure_at + p] = line_colour
	for p: Vector2i in LinkLayer.line_pixels(BODY[1], BOW_HAND):
		dots[_figure_at + p] = line_colour
	for k: int in range(1, BOW.size()):
		for p: Vector2i in LinkLayer.line_pixels(BOW[k - 1], BOW[k]):
			dots[_figure_at + p] = Palette.N6 if hunting else Palette.N4
	for p: Vector2i in BODY:
		dots[_figure_at + p] = Palette.N10 if hunting else Palette.N7
	dots[_figure_at + HEAD] = Palette.N9 if hunting else Palette.N6
	return dots


func _draw() -> void:
	if shows_reticle():
		var at := Vector2i(_marked.position.round())
		var colour: Color = Palette.S3 if lock_step() > 0 else Palette.S4
		for p: Vector2i in reticle_pixels(_marked.size, lock_step()):
			_dot(at + p, colour)
	if is_shooting():
		for p: Vector2i in reticle_pixels(_arrow_size):
			_dot(_arrow_to + p, Palette.S4)
	var arrow: Array[Vector2i] = arrow_pixels()
	for i: int in arrow.size():
		_dot(arrow[i], Palette.M6 if i >= arrow.size() - 2 else Palette.M5)


func _draw_figure() -> void:
	var dots: Dictionary[Vector2i, Color] = figure_pixels()
	for p: Vector2i in dots:
		_figure_layer.draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
