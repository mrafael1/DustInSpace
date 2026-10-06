class_name CurrentView
extends Node2D
## Flowing water behind stars (cool streaks gliding downstream), with an ember line where a draining flow loses stars (flashing
## solid where one goes). Destination brackets appear only while aiming, and an ember trail from a
## star that would drain; random pack contents stay hidden. The core supplies every destination.

## The water: streaks gliding downstream in whole pixels, one per STREAK_AREA px² of the field,
## each STREAK_LENGTH long at STREAK_SPEED px/s (both by a fixed hash, so the pattern is stable).
## Leading pixel M5, then M4, then the M3 tail.
const STREAK_AREA: int = 900
const STREAK_LENGTH := Vector2i(4, 9)
const STREAK_SPEED := Vector2i(10, 18)
## A drained star flashes the drain where it crossed: a solid ember stretch, cut after this long.
const FLASH_TIME: float = 0.25
const FLASH_HALF: int = 6

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
## Drain flashes: the edge point each lit up, and its seconds left.
var _flashes: Dictionary[Vector2i, float] = {}
## Seconds the water has flowed.
var _time: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_flashes.clear()
	set_process(run.current != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	# Core positions change instantly; hide the preview until their views catch up.
	queue_redraw()


## Lights the drain where a star crossed it, at `at` (the edge point it left by).
func flash_drain(at: Vector2i) -> void:
	_flashes[at] = FLASH_TIME
	queue_redraw()


## Counts the drain flashes down. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	for at: Vector2i in _flashes.keys():
		_flashes[at] -= delta
		if _flashes[at] <= 0.0:
			_flashes.erase(at)


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.current == null or _run.is_over():
		return result
	var area: Rect2i = _run.current.region
	result.merge(water_pixels(area, _run.current.displacement, _time))
	if _run.current.drains:
		for point: Vector2i in _drain_edge(area, _run.current.displacement):
			result[point] = Palette.S3
		for at: Vector2i in _flashes:
			for point: Vector2i in _flash(area, _run.current.displacement, at):
				result[point] = Palette.S4
	if aiming and not _sequencer.is_busy():
		var destinations: Dictionary[int, Vector2i] = _run.current_preview()
		for star: Star in _run.stars:
			var to: Vector2i = destinations[star.id]
			if to == star.position:
				continue
			var radius: int = [4, 6, 8][star.size]
			if _run.current.leaves(star.position, to):
				# A star this launch would drain trails ember dots out to its exit: it's going.
				# (Brackets would read as the landmarks' warm corner hints.)
				for point: Vector2i in _trail(star.position, to, radius + 2):
					result[point] = Palette.S4
				continue
			for side: int in [-1, 1]:
				for dy: int in [-1, 0, 1]:
					result[to + Vector2i(side * radius, dy)] = Palette.M5
	return result


## One dot in two along the straight line from `from` to `to`, starting `skip` px out.
func _trail(from: Vector2i, to: Vector2i, skip: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var length: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step: int in range(skip, length + 1, 2):
		points.append(Vector2i((Vector2(from).lerp(Vector2(to), float(step) / length)).round()))
	return points


## The water at `time` seconds: streaks gliding along `flow` through `area`, each wrapping round
## to its upstream edge once it has left the downstream one. Pixel positions only, no fades.
static func water_pixels(area: Rect2i, flow: Vector2i, time: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	var along := Vector2i(signi(flow.x), signi(flow.y))
	if along == Vector2i.ZERO or not area.has_area():
		return pixels
	var horizontal: bool = along.x != 0
	var run_length: int = area.size.x if horizontal else area.size.y
	var across_length: int = area.size.y if horizontal else area.size.x
	for i: int in maxi(1, area.get_area() / STREAK_AREA):
		var h: int = _hash(i)
		var length: int = STREAK_LENGTH.x + h % (STREAK_LENGTH.y - STREAK_LENGTH.x + 1)
		var speed: int = STREAK_SPEED.x + (h / 7) % (STREAK_SPEED.y - STREAK_SPEED.x + 1)
		var lane: int = 2 + (h / 101) % maxi(1, across_length - 4)
		var travelled: int = (h / 13 + floori(time * speed)) % (run_length + length)
		for k: int in length:
			var step: int = travelled - k
			if step < 0 or step >= run_length:
				continue
			var at_run: int = (area.end.x - 1 - step) if along.x < 0 else (area.position.x + step) if along.x > 0 else 0
			if not horizontal:
				at_run = (area.end.y - 1 - step) if along.y < 0 else (area.position.y + step)
			var p := Vector2i(at_run, area.position.y + lane) if horizontal else Vector2i(area.position.x + lane, at_run)
			pixels[p] = Palette.M5 if k == 0 else Palette.M4 if k < 3 else Palette.M3
	return pixels


static func _hash(i: int) -> int:
	return absi((i * 2654435761 + 0x9E37) ^ (i * 40503)) % 1000003


## A solid stretch of the drain line, FLASH_HALF px either side of where a star crossed it.
func _flash(area: Rect2i, flow: Vector2i, at: Vector2i) -> Array[Vector2i]:
	var edge: Array[Vector2i] = _drain_edge(area, flow)
	var points: Array[Vector2i] = []
	for offset: int in range(-FLASH_HALF, FLASH_HALF + 1):
		var along: Vector2i = Vector2i(0, offset) if flow.x != 0 else Vector2i(offset, 0)
		var point: Vector2i = Vector2i(edge[0].x, at.y) + along if flow.x != 0 else Vector2i(at.x, edge[0].y) + along
		if area.has_point(point):
			points.append(point)
	return points


## The field's downstream side, where the flow drains: an ember dotted line, one dot in two.
func _drain_edge(area: Rect2i, flow: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if flow.x != 0:
		var x: int = area.position.x if flow.x < 0 else area.end.x - 1
		for y: int in range(area.position.y, area.end.y, 2):
			points.append(Vector2i(x, y))
	if flow.y != 0:
		var y: int = area.position.y if flow.y < 0 else area.end.y - 1
		for x: int in range(area.position.x, area.end.x, 2):
			points.append(Vector2i(x, y))
	return points
