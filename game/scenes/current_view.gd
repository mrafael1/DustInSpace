class_name CurrentView
extends Node2D
## Cool flow cues behind stars, with an ember line where a draining flow loses stars. Destination
## brackets appear only while aiming (ember round a star that would drain); random pack contents
## stay hidden. The core supplies every destination.

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	set_process(run.current != null)
	queue_redraw()


func _process(_delta: float) -> void:
	# Core positions change instantly; hide the preview until their views catch up.
	queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.current == null or _run.is_over():
		return result
	var area: Rect2i = _run.current.region
	for x: int in range(area.position.x, area.end.x, 8):
		result[Vector2i(x, area.position.y)] = Palette.M3
		result[Vector2i(x, area.end.y - 1)] = Palette.M3
	for y: int in range(area.position.y + 12, area.end.y - 4, 28):
		for x: int in range(area.position.x + 12, area.end.x - 4, 32):
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, -1), Vector2i(1, 1), Vector2i(2, -2), Vector2i(2, 2), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)] as Array[Vector2i]:
				result[Vector2i(x, y) + offset] = Palette.M4
	if _run.current.drains:
		for point: Vector2i in _drain_edge(area, _run.current.displacement):
			result[point] = Palette.S3
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
