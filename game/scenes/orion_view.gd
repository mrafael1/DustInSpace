class_name OrionView
extends Node2D
## Orion the hunter (#64), on stages he hunts: his figure, dim in the sky's top-left corner (drawn
## on the FigureLayer, under the stars); when he marks a star his figure flashes bright and a dotted
## ember sight line runs from his bow to it, then the ember crosshair closes on it and stays (a cue
## unlike the warm selection ring, the gold lit landmarks and the unlit landmarks' corner hints),
## his bow held drawn while it stands. While the player traces a link that would leave the marked
## star behind, his bow readies: the figure lights up and the sight line holds on the star. Then his
## arrow flying to it.
## Owns no rules: SkyView tells it what the events say.

## Orion bent his bow: the arrow is off. Feedback only (sound).
signal arrow_loosed

## The figure brightens and draws the bow, then the arrow flies; the star breaks as it lands.
const DRAW_TIME: float = 0.2
const FLIGHT_TIME: float = 0.35
## The arrow's shaft, behind its tip.
const SHAFT: int = 7
## A new mark: the figure flashes bright and the sight line runs from the bow hand to the star in
## TRACE_TIME; then the reticle closes in from LOCK_STEPS px further out, a pixel a step. The sight
## line and the flash cut together once the reticle has locked (MARK_TIME).
const TRACE_TIME: float = 0.18
const LOCK_STEPS: int = 3
const LOCK_STEP_TIME: float = 0.06
const MARK_TIME: float = TRACE_TIME + LOCK_STEPS * LOCK_STEP_TIME
## The sight line: a dot every SIGHT_GAP px, stopping short of the reticle.
const SIGHT_GAP: int = 2
## A locked reticle jumps a pixel out and back once a period, so a marked star keeps catching the eye.
const PULSE_PERIOD: float = 1.0
const PULSE_OUT: float = 0.12
## Each reticle tick's length, pointing in at the star.
const TICK: int = 3
## Where the figure sits: this far into the play sky from its top-left corner.
const FIGURE_AT := Vector2i(6, 6)
## Orion's stars (figure coordinates), laid out as in the sky (RA/Dec at about 1.7 px a degree):
## Meissa (head); Betelgeuse, Bellatrix; the belt Alnitak, Alnilam, Mintaka; Saiph, Rigel. His bow is
## the arc of Pi Orionis (the classic shield), held out right, towards the sky he hunts.
const HEAD := Vector2i(12, 0)
const BODY: Array[Vector2i] = [Vector2i(4, 4), Vector2i(17, 6), Vector2i(10, 20), Vector2i(12, 19), Vector2i(14, 17), Vector2i(7, 33), Vector2i(21, 31)]
const BOW: Array[Vector2i] = [Vector2i(30, 0), Vector2i(31, 2), Vector2i(32, 5), Vector2i(31, 7), Vector2i(30, 13), Vector2i(28, 14)]
## The figure's lines, between BODY stars (by index): shoulders to belt, the belt, belt to feet.
const LINES: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 4), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 5), Vector2i(4, 6)]
## The arm from Bellatrix to the bow hand, gripping the bow's middle.
const BOW_HAND := Vector2i(29, 8)

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
## The traced link would leave the marked star behind.
var _bow_ready: bool = false

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
	_bow_ready = false
	queue_redraw()
	_figure_layer.queue_redraw()


func is_figure_shown() -> bool:
	return _figure_shown


## Where the arrow leaves from: the bow hand.
func bow_hand() -> Vector2i:
	return _figure_at + BOW_HAND


## Orion marked the star `view` shows: the flash and sight line, then the reticle locks on.
func mark(view: StarView) -> void:
	_marked = view
	_mark_age = 0.0
	queue_redraw()
	_figure_layer.queue_redraw()


func marked() -> StarView:
	return _marked if is_instance_valid(_marked) else null


func clear_mark() -> void:
	_marked = null
	_bow_ready = false
	queue_redraw()
	_figure_layer.queue_redraw()


## The link being traced would (`on`) or wouldn't leave the marked star to his arrow.
func ready_bow(on: bool) -> void:
	if on == _bow_ready:
		return
	_bow_ready = on
	queue_redraw()
	_figure_layer.queue_redraw()


func is_bow_ready() -> bool:
	return _bow_ready and marked() != null


## A new mark is being acquired: the figure flashes and the sight line shows.
func is_aiming() -> bool:
	return marked() != null and _mark_age < MARK_TIME


## Orion shoots the star of `size` at `at`: the bow draws, then the arrow flies there; the
## crosshair stays on it until it lands. Returns how long until it lands.
func shoot(at: Vector2i, size: int) -> float:
	_marked = null
	_bow_ready = false
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
		_figure_layer.queue_redraw()
	if _arrow_age >= 0.0:
		var drawn: bool = _arrow_age >= DRAW_TIME
		_arrow_age += delta
		if not drawn and _arrow_age >= DRAW_TIME:
			arrow_loosed.emit()
		if _arrow_age >= DRAW_TIME + FLIGHT_TIME:
			_arrow_age = -1.0
		queue_redraw()
		_figure_layer.queue_redraw()


## The crosshair around a star of `size`, `lock` px further out than at rest: a tick of TICK pixels
## pointing in from each side (up, down, left, right), clear of the star and its selection ring.
static func reticle_pixels(size: int, lock: int = 0) -> Array[Vector2i]:
	var d: int = StarView.half_extent(size as Star.Size) + 3 + lock
	var pixels: Array[Vector2i] = []
	for axis: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for k: int in TICK:
			pixels.append(axis * (d + k))
	return pixels


## The reticle's offset now: LOCK_STEPS down to 0 while it locks on, then 1 during each pulse.
func lock_step() -> int:
	var step: int = maxi(LOCK_STEPS - int((_mark_age - TRACE_TIME) / LOCK_STEP_TIME), 0)
	if step > 0:
		return step
	return 1 if fmod(_mark_age - MARK_TIME, PULSE_PERIOD) >= PULSE_PERIOD - PULSE_OUT else 0


## The reticle shows once the sight line reaches the star, and stays until the mark goes.
func shows_reticle() -> bool:
	return marked() != null and _mark_age >= TRACE_TIME


## The sight line's dots now, from the bow hand towards the marked star, the leading dot last: it
## runs out while a mark locks on and holds while the bow is ready; none otherwise. It stops short
## of where the reticle closes in from.
func sight_pixels() -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	if not is_aiming() and not is_bow_ready():
		return dots
	var line: Array[Vector2i] = LinkLayer.line_pixels(bow_hand(), Vector2i(_marked.position.round()))
	var short: int = StarView.half_extent(_marked.size as Star.Size) + 3 + LOCK_STEPS + TICK
	var reach: int = maxi(line.size() - short, 0)
	var shown: int = reach if is_bow_ready() else ceili(reach * minf(_mark_age / TRACE_TIME, 1.0))
	for i: int in range(0, shown, SIGHT_GAP):
		dots.append(line[i])
	return dots


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


## The figure's pixels and colours: dim cool dots and faint lines; bright while he marks, readies
## his bow or shoots. While a mark stands his bow stays drawn: a step brighter than at rest.
func figure_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if not _figure_shown:
		return dots
	var hunting: bool = is_shooting() or is_aiming() or is_bow_ready()
	var line_colour: Color = Palette.N5 if hunting else Palette.N3
	for pair: Vector2i in LINES:
		for p: Vector2i in LinkLayer.line_pixels(BODY[pair.x], BODY[pair.y]):
			dots[_figure_at + p] = line_colour
	for p: Vector2i in LinkLayer.line_pixels(HEAD, BODY[0]) + LinkLayer.line_pixels(HEAD, BODY[1]):
		dots[_figure_at + p] = line_colour
	for p: Vector2i in LinkLayer.line_pixels(BODY[1], BOW_HAND):
		dots[_figure_at + p] = line_colour
	var bow_colour: Color = Palette.N10 if hunting else (Palette.N6 if marked() != null else Palette.N4)
	for k: int in range(1, BOW.size()):
		for p: Vector2i in LinkLayer.line_pixels(BOW[k - 1], BOW[k]):
			dots[_figure_at + p] = bow_colour
	for p: Vector2i in BODY:
		dots[_figure_at + p] = Palette.N10 if hunting else Palette.N7
	dots[_figure_at + HEAD] = Palette.N9 if hunting else Palette.N6
	return dots


func _draw() -> void:
	var sight: Array[Vector2i] = sight_pixels()
	for i: int in sight.size():
		_dot(sight[i], Palette.S4 if i == sight.size() - 1 else Palette.S3)
	if shows_reticle():
		var at := Vector2i(_marked.position.round())
		for p: Vector2i in reticle_pixels(_marked.size, lock_step()):
			_dot(at + p, Palette.S4)
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
