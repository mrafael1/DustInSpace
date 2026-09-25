class_name LinkLayer
extends Node2D
## Draws the link being traced and the short feedback after a link resolves.
## Sits under the StarLayer, so a line runs between stars without covering them.
## Link line (art-direction.md): 1 px C1 with a C0 pulse every 5 px and a C5 checker glow alongside.
## Owns no rules: Sky tells it which points to join and whether a link was collected or rejected.

## A travelling C0 pixel every PULSE_SPACING px along the line.
const PULSE_SPACING: int = 5
const PULSE_STEP_TIME: float = 0.08
## Valid link: the line flares white while the stars dissolve.
const COLLECT_TIME: float = StarView.DISSOLVE_TIME
## Invalid link: the line shakes and fades (game-feel skill). Nothing is used up.
const REJECT_TIME: float = 0.45
## Whole-pixel horizontal shake of a rejected line, one step per REJECT_SHAKE_STEP.
const REJECT_SHAKE: Array[int] = [2, -2, 2, -1, 1, -1, 1, 0]
const REJECT_SHAKE_STEP: float = 0.04
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## A resolved link's line, shown for a moment.
class Flash:
	extends RefCounted
	var points: Array[Vector2i]
	var color: Color
	var duration: float
	var shakes: bool
	var time: float = 0.0

	func _init(p_points: Array[Vector2i], p_color: Color, p_duration: float, p_shakes: bool) -> void:
		points = p_points
		color = p_color
		duration = p_duration
		shakes = p_shakes


var _path: Array[Vector2i] = []
var _flashes: Array[Flash] = []
var _time: float = 0.0
var _pulse_frame: int = -1


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	_draw_link(path_pixels(_path))
	for flash: Flash in _flashes:
		_draw_flash(flash)


## Shows the link being traced through `points` (star centres, then the finger while dragging).
func show_path(points: Array[Vector2i]) -> void:
	if points == _path:
		return
	_path = points.duplicate()
	queue_redraw()


func flash_collected(points: Array[Vector2i]) -> void:
	_flash(Flash.new(points, Palette.C0, COLLECT_TIME, false))


func flash_rejected(points: Array[Vector2i]) -> void:
	_flash(Flash.new(points, Palette.S4, REJECT_TIME, true))


func is_flashing() -> bool:
	return not _flashes.is_empty()


## Moves the pulse and the flashes forward. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	for flash: Flash in _flashes:
		flash.time += delta
	var before: int = _flashes.size()
	_flashes = _flashes.filter(func(flash: Flash) -> bool: return flash.time < flash.duration)
	var pulse_frame: int = int(_time / PULSE_STEP_TIME) % PULSE_SPACING
	if _flashes.size() != before or not _flashes.is_empty() or (pulse_frame != _pulse_frame and _path.size() > 1):
		queue_redraw()
	_pulse_frame = pulse_frame


## Every pixel of a line from `a` to `b`, both ends included (Bresenham).
static func line_pixels(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	var d := Vector2i(absi(b.x - a.x), -absi(b.y - a.y))
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var error: int = d.x + d.y
	var p: Vector2i = a
	while true:
		pixels.append(p)
		if p == b:
			break
		var twice: int = 2 * error
		if twice >= d.y:
			error += d.y
			p.x += step.x
		if twice <= d.x:
			error += d.x
			p.y += step.y
	return pixels


## The pixels of a path through `points`, in order, with each joint counted once.
static func path_pixels(points: Array[Vector2i]) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	for i: int in range(1, points.size()):
		var segment: Array[Vector2i] = line_pixels(points[i - 1], points[i])
		if not pixels.is_empty():
			segment.pop_front()
		pixels.append_array(segment)
	return pixels


func _flash(flash: Flash) -> void:
	if flash.points.size() > 1:
		_flashes.append(flash)
		queue_redraw()


func _draw_link(pixels: Array[Vector2i]) -> void:
	var on_line: Dictionary[Vector2i, bool] = {}
	for p: Vector2i in pixels:
		on_line[p] = true
	for p: Vector2i in pixels:
		for n: Vector2i in NEIGHBOURS:
			var glow: Vector2i = p + n
			if not on_line.has(glow) and posmod(glow.x + glow.y, 2) == 0:
				_dot(glow, Palette.C5)
	var pulse: int = int(_time / PULSE_STEP_TIME) % PULSE_SPACING
	for i: int in pixels.size():
		_dot(pixels[i], Palette.C0 if (i + PULSE_SPACING - pulse) % PULSE_SPACING == 0 else Palette.C1)


## Fades by ordered dither: fewer pixels each frame, never a blended colour.
func _draw_flash(flash: Flash) -> void:
	var left: float = 1.0 - flash.time / flash.duration
	var shake := Vector2i.ZERO
	if flash.shakes:
		shake.x = REJECT_SHAKE[mini(int(flash.time / REJECT_SHAKE_STEP), REJECT_SHAKE.size() - 1)]
	for p: Vector2i in path_pixels(flash.points):
		var q: Vector2i = p + shake
		if StarView.BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)] < ceili(left * 16.0):
			_dot(q, flash.color)


func _dot(p: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), color)
