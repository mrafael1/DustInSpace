class_name ConstellationView
extends Node2D
## Draws the Scorpio map (#40) under the stars: the landmarks, the given outline in solid cool
## M3, a faint dotted outline for each gap still to build, built gaps lit C1 with their bridge star, and the previews the Sky asks
## for while a link is traced. Owns no rules: RunState says what's built, what a link would
## build and what a combo would sting; this only shows it. Draws nothing without the map.
## Warm colours mean usable: a selected landmark, the stars that could bridge its gaps, a segment
## the link would build, and the sting's target. Cool colours are the guide.

## The outline stops this far short of each landmark, so the glyphs stay clear.
const LANDMARK_CLEAR: int = 5
## Unbuilt outline: one pixel in OUTLINE_STEP.
const OUTLINE_STEP: int = 3
## A just-built segment flashes C0 this long, then stays C1.
const BUILD_FLASH: float = 0.18
## Completion: a C0 head runs the whole outline, head to stinger, in COMPLETION_TIME.
const COMPLETION_TIME: float = 0.8
const COMPLETION_TAIL: int = 8
## Corner ticks around a candidate or target star, this far from its centre.
const TICK_OFFSET: int = 6
## Without a sting target, the reach shows as a dotted circle: one dot in REACH_DOT_STEP px.
const REACH_DOT_STEP: int = 6

var _run: RunState
var _selected_landmarks: Array[int] = []
var _candidates: Array[Vector2i] = []
var _preview_segment: int = -1
## Sting preview: from where, to where (or no target), active or not.
var _sting_from := Vector2i.ZERO
var _sting_to := Vector2i.ZERO
var _sting_shown: bool = false
var _sting_has_target: bool = false
var _flash_segment: int = -1
var _flash_left: float = 0.0
var _completion_time: float = -1.0


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _run == null or _run.scorpio == null:
		return
	for segment: int in Scorpio.segment_count():
		_draw_segment(segment)
	for i: int in Scorpio.LANDMARKS.size():
		_draw_landmark(i)
	for star: Star in _run.stars:
		if not _run.scorpio.open_segments_for(star.position, _run.balance.scorpio_segment_reach).is_empty():
			_draw_hint(star.position)
	for at: Vector2i in _candidates:
		_draw_ticks(at, Palette.C2)
	if _sting_shown:
		_draw_sting()
	if _completion_time >= 0.0:
		_draw_completion()


func setup(run: RunState) -> void:
	_run = run
	_selected_landmarks.clear()
	_candidates.clear()
	_preview_segment = -1
	_sting_shown = false
	_flash_left = 0.0
	_completion_time = -1.0
	queue_redraw()


## What the link being traced would do: the landmarks in it, the stars that could bridge their
## gaps, the segment it would build (-1: none), and nothing else.
func show_build_preview(landmarks: Array[int], candidates: Array[Vector2i], segment: int) -> void:
	_selected_landmarks = landmarks.duplicate()
	_candidates = candidates.duplicate()
	_preview_segment = segment
	_sting_shown = false
	queue_redraw()


## A valid combo's sting: a dashed line to its target, or the reach as a dotted circle if none.
func show_sting_preview(from: Vector2i, target: Vector2i, has_target: bool) -> void:
	clear_preview()
	_sting_from = from
	_sting_to = target
	_sting_has_target = has_target
	_sting_shown = true
	queue_redraw()


func clear_preview() -> void:
	_selected_landmarks.clear()
	_candidates.clear()
	_preview_segment = -1
	_sting_shown = false
	queue_redraw()


func flash_built(segment: int) -> void:
	_flash_segment = segment
	_flash_left = BUILD_FLASH
	queue_redraw()


func play_completion() -> void:
	_completion_time = 0.0
	queue_redraw()


func is_completing() -> bool:
	return _completion_time >= 0.0


## Moves the flashes on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		queue_redraw()
	if _completion_time >= 0.0:
		_completion_time += delta
		if _completion_time >= COMPLETION_TIME:
			_completion_time = -1.0
		queue_redraw()


## Every pixel of the outline, head to stinger, with the ends kept clear of the landmarks.
static func outline_pixels(segment: int) -> Array[Vector2i]:
	var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
	var line: Array[Vector2i] = LinkLayer.line_pixels(ends[0], ends[1])
	return line.slice(LANDMARK_CLEAR, line.size() - LANDMARK_CLEAR)


## A landmark's glyph, 7x7: a fat four-pointed star, bigger and brighter than any background
## star (those are 3 px at most). Cool, or warm while it's in the link being traced.
static func landmark_dots(selected: bool) -> Dictionary[Vector2i, Color]:
	var core: Color = Palette.C0 if selected else Palette.M6
	var inner: Color = Palette.C1 if selected else Palette.M5
	var tip: Color = Palette.C2 if selected else Palette.N8
	var dots: Dictionary[Vector2i, Color] = {Vector2i.ZERO: core}
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		dots[d] = core
		dots[d * 2] = inner
		dots[d * 3] = tip
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		dots[d] = inner
	return dots


func _draw_segment(segment: int) -> void:
	var pixels: Array[Vector2i] = outline_pixels(segment)
	if _run.scorpio.is_built(segment):
		var colour: Color = Palette.C0 if segment == _flash_segment and _flash_left > 0.0 else Palette.C1
		for p: Vector2i in pixels:
			_dot(p, colour)
		var bridge: Vector2i = _run.scorpio.bridge_positions[segment]
		for d: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_dot(bridge + d, Palette.C0 if d == Vector2i.ZERO else Palette.C1)
		return
	if not Scorpio.is_gap(segment):
		for p: Vector2i in pixels:
			_dot(p, Palette.M3)
		return
	var preview: bool = segment == _preview_segment
	for i: int in pixels.size():
		if preview and i % 2 == 0:
			_dot(pixels[i], Palette.C2)
		elif not preview and i % OUTLINE_STEP == 0:
			_dot(pixels[i], Palette.N6)


func _draw_landmark(index: int) -> void:
	var dots: Dictionary[Vector2i, Color] = landmark_dots(_selected_landmarks.has(index))
	for d: Vector2i in dots:
		_dot(Scorpio.LANDMARKS[index] + d, dots[d])


func _draw_ticks(at: Vector2i, colour: Color) -> void:
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var c: Vector2i = at + corner * TICK_OFFSET
		_dot(c, colour)
		_dot(c - Vector2i(corner.x, 0), colour)
		_dot(c - Vector2i(0, corner.y), colour)


## A star that could bridge a gap, before any landmark is picked: one N9 pixel at each corner.
func _draw_hint(at: Vector2i) -> void:
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		_dot(at + corner * TICK_OFFSET, Palette.N9)


func _draw_sting() -> void:
	if _sting_has_target:
		var line: Array[Vector2i] = LinkLayer.line_pixels(_sting_from, _sting_to)
		for i: int in line.size():
			if i % 3 != 2:
				_dot(line[i], Palette.C3)
		_draw_ticks(_sting_to, Palette.C2)
		return
	var reach: int = _run.balance.scorpio_sting_reach
	var dots: int = maxi(roundi(TAU * reach / REACH_DOT_STEP), 8)
	for k: int in dots:
		var angle: float = TAU * k / dots
		_dot(_sting_from + Vector2i((Vector2.from_angle(angle) * reach).round()), Palette.N6)


func _draw_completion() -> void:
	var path: Array[Vector2i] = []
	for segment: int in Scorpio.segment_count():
		path.append_array(outline_pixels(segment))
	var head: int = floori(_completion_time / COMPLETION_TIME * path.size())
	for i: int in range(maxi(head - COMPLETION_TAIL, 0), mini(head + 1, path.size())):
		_dot(path[i], Palette.C0)


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
