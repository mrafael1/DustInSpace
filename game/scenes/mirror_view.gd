class_name MirrorView
extends Node2D
## Pisces's mirror (chapter 6): the seam down the sky's middle, and while a link is traced, where it
## echoes. Owns no rules: RunState.mirror and link_echo say where; Sky plays mirror_echoed here.
## Look: the seam is a dotted N4 line (a pixel every SEAM_GAP) over the sky's height, faint like the
## sky's own lines. While tracing, each picked star's mirror spot shows a small N7 cross (where its
## echo lands), and the stars the echo would take are bracketed: N8 while the link isn't whole, then
## C1 if the whole link's echo pays (three that match) or S4 ember if it would be lost. A lost echo
## flashes an S4 ring round each star it took for LOST_TIME, as they go.

const SEAM_GAP: int = 4
const LOST_TIME: float = 0.4
const LOST_RADIUS: int = 6
## The brackets' corners stand this far from a star's centre.
const MARK_OFFSET: int = 6
const CORNERS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]

## The mirror spots of the stars picked so far (empty: not tracing).
var ghosts: Array[Vector2i] = []:
	set(value):
		if ghosts != value:
			ghosts = value.duplicate()
			queue_redraw()
## The stars the traced link's echo would take, and what it would do: 0 not decided yet (the link
## isn't whole), 1 pays, -1 lost.
var echo_marks: Array[Vector2i] = []:
	set(value):
		if echo_marks != value:
			echo_marks = value.duplicate()
			queue_redraw()
var echo_outcome: int = 0:
	set(value):
		if echo_outcome != value:
			echo_outcome = value
			queue_redraw()
var _run: RunState
## A lost echo's rings: their centres, and the seconds left (-1: none).
var _lost: Array[Vector2i] = []
var _lost_left: float = -1.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState) -> void:
	_run = run
	ghosts = [] as Array[Vector2i]
	echo_marks = [] as Array[Vector2i]
	echo_outcome = 0
	_lost.clear()
	_lost_left = -1.0
	visible = run.mirror != null
	set_process(run.mirror != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## An echo was lost: a ring round each star it took, at `points`.
func flash_lost(points: Array[Vector2i]) -> void:
	_lost = points.duplicate()
	_lost_left = LOST_TIME
	queue_redraw()


func is_flashing() -> bool:
	return _lost_left >= 0.0


## Plays the lost rings. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _lost_left >= 0.0:
		_lost_left -= delta
		if _lost_left < 0.0:
			_lost.clear()
		queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.mirror == null:
		return result
	result.merge(seam_pixels(_run.mirror.axis, _run.sky_rect), true)
	for spot: Vector2i in ghosts:
		result.merge(ghost_pixels(spot), true)
	var colour: Color = Palette.N8 if echo_outcome == 0 else (Palette.C1 if echo_outcome > 0 else Palette.S4)
	for at: Vector2i in echo_marks:
		result.merge(mark_pixels(at, colour), true)
	for at: Vector2i in _lost:
		result.merge(ring_pixels(at, LOST_RADIUS, Palette.S4), true)
	return result


## The seam: an N4 pixel every SEAM_GAP down the sky at x = axis / 2.
static func seam_pixels(axis: int, sky: Rect2i) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	@warning_ignore("integer_division")
	var x: int = axis / 2
	for y: int in range(sky.position.y, sky.end.y, SEAM_GAP):
		result[Vector2i(x, y)] = Palette.N4
	return result


## A mirror spot while tracing: a small N7 cross.
static func ghost_pixels(at: Vector2i) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		result[at + d] = Palette.N7
	return result


## Four corner brackets round a star the echo takes, in `colour`.
static func mark_pixels(at: Vector2i, colour: Color) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for corner: Vector2i in CORNERS:
		var c: Vector2i = at + corner * MARK_OFFSET
		result[c] = colour
		result[c - Vector2i(corner.x, 0)] = colour
		result[c - Vector2i(0, corner.y)] = colour
	return result


## A ring of `radius` round `at`, on whole pixels.
static func ring_pixels(at: Vector2i, radius: int, colour: Color) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in 24:
		var angle: float = TAU * i / 24.0
		result[at + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round())] = colour
	return result
