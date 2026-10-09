class_name LinkLayer
extends Node2D
## Draws the link being traced and the short feedback after a link resolves.
## Sits under the StarLayer, so a line runs between stars without covering them.
## Link line (art-direction.md): 1 px C1 with a C0 pulse every 5 px and a C5 checker glow alongside.
## Owns no rules: Sky tells it which points to join and whether a link was collected or rejected.
## Reach (Scorpio): the line to the finger strains as it nears the reach, warming C1 to C2 to C3
## over the last part of it, so the limit is felt before it's hit. Past the reach, the line stops
## at the limit with a flickering ember spark where it broke, and runs on to the finger as sparse
## M5 dots. (Which stars are in reach shows through the link hint: the others dim.)
## Let go: while a release would cancel the link (the drag left its last star), the whole line,
## out to the finger, is sparse M5 dots like the loose end: cold and broken, not a link.

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
## An out-of-reach line: one pixel every LOOSE_DOT_SPACING px.
const LOOSE_DOT_SPACING: int = 3
## Strain: the line to the finger turns C2 from this share of the reach, and C3 from STRAIN_HARD.
const STRAIN_FROM: float = 0.7
const STRAIN_HARD: float = 0.85


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
## The path's last step (to the finger) is out of reach.
var _loose_end: bool = false
## How long the last step (to the finger) may be, in px; 0 for no reach shown.
var _reach: int = 0
## A release now would let the link go: the line is drawn let go.
var _let_go: bool = false
var _flashes: Array[Flash] = []
var _time: float = 0.0
var _pulse_frame: int = -1


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _let_go:
		_draw_let_go(path_pixels(_path))
	elif (_loose_end or _reach > 0) and _path.size() > 1:
		_draw_link(path_pixels(_path.slice(0, -1)))
		_draw_finger_step(_path[-2], _path[-1])
	else:
		_draw_link(path_pixels(_path))
	for flash: Flash in _flashes:
		_draw_flash(flash)


## Shows the link being traced through `points` (star centres, then the finger while dragging).
## `loose_end`: the last step, to the finger, is out of reach. `reach`: how long that step may be,
## so the line can strain toward it (0: none). `let_go`: a release now would cancel the link.
func show_path(points: Array[Vector2i], loose_end: bool = false, reach: int = 0, let_go: bool = false) -> void:
	if points == _path and loose_end == _loose_end and reach == _reach and let_go == _let_go:
		return
	_path = points.duplicate()
	_loose_end = loose_end
	_reach = reach
	_let_go = let_go
	queue_redraw()


func is_loose_end() -> bool:
	return _loose_end


func is_let_go() -> bool:
	return _let_go


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


## The colour of the line to the finger at `share` of the reach from the last star: C1, then
## straining C2, then C3 near the limit.
static func strain_colour(share: float) -> Color:
	if share >= STRAIN_HARD:
		return Palette.C3
	return Palette.C2 if share >= STRAIN_FROM else Palette.C1


## The pixels of the line from `a` toward `b` that are within `reach` of `a` (all with no reach).
static func reach_part(a: Vector2i, b: Vector2i, reach: int) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = line_pixels(a, b)
	if reach <= 0:
		return pixels
	return pixels.filter(func(p: Vector2i) -> bool: return (p - a).length_squared() <= reach * reach)


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
	_draw_glow(pixels)
	for i: int in pixels.size():
		_dot(pixels[i], _pulse_colour(i))


## The step from the last star `a` to the finger `b`: it strains toward the reach, and past it
## breaks at the limit with an ember spark, then runs on as sparse dots.
func _draw_finger_step(a: Vector2i, b: Vector2i) -> void:
	var solid: Array[Vector2i] = reach_part(a, b, _reach)
	_draw_glow(solid)
	for i: int in solid.size():
		var share: float = (solid[i] - a).length() / _reach if _reach > 0 else 0.0
		_dot(solid[i], _pulse_colour(i) if share < STRAIN_FROM else strain_colour(share))
	if not _loose_end:
		return
	var loose: Array[Vector2i] = line_pixels(a, b).slice(solid.size())
	for i: int in range(LOOSE_DOT_SPACING - 1, loose.size(), LOOSE_DOT_SPACING):
		_dot(loose[i], Palette.M5)
	if not solid.is_empty():
		var spark: Color = Palette.C3 if _pulse_frame % 2 == 0 else Palette.C2
		for n: Vector2i in NEIGHBOURS:
			_dot(solid[-1] + n, spark)


func _draw_let_go(pixels: Array[Vector2i]) -> void:
	for i: int in range(LOOSE_DOT_SPACING - 1, pixels.size(), LOOSE_DOT_SPACING):
		_dot(pixels[i], Palette.M5)


func _draw_glow(pixels: Array[Vector2i]) -> void:
	var on_line: Dictionary[Vector2i, bool] = {}
	for p: Vector2i in pixels:
		on_line[p] = true
	for p: Vector2i in pixels:
		for n: Vector2i in NEIGHBOURS:
			var glow: Vector2i = p + n
			if not on_line.has(glow) and posmod(glow.x + glow.y, 2) == 0:
				_dot(glow, Palette.C5)


## The travelling pulse: C0 on every PULSE_SPACING-th pixel of the line, moving along; C1 elsewhere.
func _pulse_colour(i: int) -> Color:
	var pulse: int = int(_time / PULSE_STEP_TIME) % PULSE_SPACING
	return Palette.C0 if (i + PULSE_SPACING - pulse) % PULSE_SPACING == 0 else Palette.C1


## Fades by ordered dither: fewer pixels each frame, never a blended colour.
func _draw_flash(flash: Flash) -> void:
	var left: float = 1.0 - flash.time / flash.duration
	var shake := Vector2i.ZERO
	if flash.shakes:
		shake.x = Motion.shake_x(REJECT_SHAKE[mini(int(flash.time / REJECT_SHAKE_STEP), REJECT_SHAKE.size() - 1)])
	for p: Vector2i in path_pixels(flash.points):
		var q: Vector2i = p + shake
		if StarView.BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)] < ceili(left * 16.0):
			_dot(q, flash.color)


func _dot(p: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), color)
