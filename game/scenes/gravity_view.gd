class_name GravityView
extends Node2D
## Sagittarius's black hole (chapter 5 trial), minimal cues: an N0 disc the size of its horizon inside
## a cool accretion ring, its bright arc orbiting in whole steps, the ring flaring ember as it
## swallows a star. While aiming, each star's fall shows as a dotted trail to where it lands (M5
## brackets), or ember dots into the hole for a star it swallows; random pack contents stay hidden.
## While not aiming, each star the next launch swallows wears two ember dots on its side toward the
## hole. The core supplies every destination. Never on the Big Bang's look: no freeze or full black.

## The ring sits RING_GAP px outside the horizon; its bright arc spans ARC_DOTS dots of RING_DOTS and
## moves a dot on every ARC_STEP.
const RING_GAP: int = 2
const RING_DOTS: int = 32
const ARC_DOTS: int = 6
const ARC_STEP: float = 0.12
## A swallow flares the ring S4 until FLARE_HOT, then S3 until FLARE_TIME.
const FLARE_HOT: float = 0.12
const FLARE_TIME: float = 0.3

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
var _time: float = 0.0
## Seconds since the last swallow (-1: none flaring).
var _flare: float = -1.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_flare = -1.0
	set_process(run.gravity != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## The hole swallowed a star: its ring flares.
func flash_swallow() -> void:
	_flare = 0.0
	queue_redraw()


## Turns the ring and the flare on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	if _flare >= 0.0:
		_flare += delta
		if _flare >= FLARE_TIME:
			_flare = -1.0


## Where a swallowed star vanishes, on its way from `from`: the horizon's edge on its side.
func horizon_point(from: Vector2i) -> Vector2i:
	var hole: StarGravity = _run.gravity
	var way: Vector2 = Vector2(from - hole.center).normalized()
	return hole.center + Vector2i((way * hole.horizon).round())


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.gravity == null:
		return result
	var hole: StarGravity = _run.gravity
	result.merge(hole_pixels(hole.center, hole.horizon, _time, _flare))
	var busy: bool = _sequencer != null and _sequencer.is_busy()
	if busy:
		return result
	if not aiming:
		for id: int in _run.launch_swallows():
			var star: Star = _run.find_star(id)
			var way: Vector2 = Vector2(hole.center - star.position).normalized()
			var edge: int = StarView.half_extent(star.size)
			for dot: int in [3, 5]:
				result[star.position + Vector2i((way * (edge + dot)).round())] = Palette.S4
		return result
	var destinations: Dictionary[int, Vector2i] = _run.gravity_preview()
	for star: Star in _run.stars:
		var to: Vector2i = destinations[star.id]
		if to == star.position:
			continue
		var radius: int = [4, 6, 8][star.size]
		if hole.swallowed(to):
			for point: Vector2i in _trail(star.position, horizon_point(star.position), radius + 2):
				result[point] = Palette.S4
			continue
		for point: Vector2i in _trail(star.position, to, radius + 2):
			result[point] = Palette.M4
		for side: int in [-1, 1]:
			for dy: int in [-1, 0, 1]:
				result[to + Vector2i(side * radius, dy)] = Palette.M5
	return result


## The hole at `center`: an N0 disc of `horizon` px, then the ring RING_GAP px out in M4 with its
## M5/M6 arc orbiting `time` seconds in; a flare `flare` seconds in (-1: none) turns it ember.
static func hole_pixels(center: Vector2i, horizon: int, time: float, flare: float = -1.0) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for y: int in range(-horizon, horizon + 1):
		for x: int in range(-horizon, horizon + 1):
			if x * x + y * y <= horizon * horizon:
				result[center + Vector2i(x, y)] = Palette.N0
	var radius: int = horizon + RING_GAP
	var lead: int = int(time / ARC_STEP) % RING_DOTS
	for i: int in RING_DOTS:
		var angle: float = i * TAU / RING_DOTS
		var p: Vector2i = center + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round())
		var behind: int = (lead - i + RING_DOTS) % RING_DOTS
		var color: Color = Palette.M4
		if behind == 0:
			color = Palette.M6
		elif behind < ARC_DOTS:
			color = Palette.M5
		if flare >= 0.0:
			color = Palette.S4 if flare < FLARE_HOT else Palette.S3
		result[p] = color
	return result


func _trail(from: Vector2i, to: Vector2i, skip: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var length: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step: int in range(skip, length + 1, 2):
		points.append(Vector2i((Vector2(from).lerp(Vector2(to), float(step) / length)).round()))
	return points
