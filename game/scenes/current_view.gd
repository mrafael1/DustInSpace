class_name CurrentView
extends Node2D
## Cool flow cues behind stars. Destination brackets appear only while aiming;
## random pack contents stay hidden. The core supplies every destination.

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
	if aiming and not _sequencer.is_busy():
		var destinations: Dictionary[int, Vector2i] = _run.current_preview()
		for star: Star in _run.stars:
			var to: Vector2i = destinations[star.id]
			if to == star.position:
				continue
			var radius: int = [4, 6, 8][star.size]
			for side: int in [-1, 1]:
				for dy: int in [-1, 0, 1]:
					result[to + Vector2i(side * radius, dy)] = Palette.M5
	return result
