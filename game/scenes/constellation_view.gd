class_name ConstellationView
extends Node2D
## Draws the Scorpio map (#40) under the stars. Each landmark is drawn with the star art of its
## size, so a small, medium or big landmark reads like the sky star it can stand in for: cool
## (unlit, usable in a combo) or gold (lit). Strings between two lit landmarks glow C1 with a C0
## glint running along them; strings still to form are dotted N8. An unlit landmark, which can be
## picked, also has four small corner brackets in the dim halo tones (C4/C5, swapping every
## CUE_STEP): a quiet "you can pick this" that background stars and lit landmarks never show. While a link is traced, the
## landmarks in it show gold and the strings it would form are dashed C2. Owns no rules:
## RunState says what's lit. Draws nothing without the map.
## Completion plays the constellation like an instrument once every payout has landed (the Sky
## waits): string by string from the bottom of the sky to the top, each flashing C0 and vibrating
## as its note sounds (string_sung). Then a drawing of the scorpion is traced around the lit
## stars, stroke by stroke, and stays.

## Completion: the `order`-th string (0 = the lowest) lit and its note should sound.
signal string_sung(segment: int, order: int)

## The outline stops this far short of each landmark, so the stars stay clear.
const LANDMARK_CLEAR: int = 5
## A string still to form: one pixel in OUTLINE_STEP.
const OUTLINE_STEP: int = 2
## Built strings' idle glow: a C0 glint every GLOW_SPACING px moves one pixel per GLOW_STEP.
const GLOW_SPACING: int = 6
const GLOW_STEP: float = 0.12
## The selectable cue: its brackets sit this far out from the star art's edge, and swap between
## C5 and C4 every CUE_STEP.
const CUE_GAP: int = 2
const CUE_STEP: float = 0.6
## A landmark or string that just lit shows C0 this long.
const LIT_FLASH: float = 0.25
## Completion: one string every STRING_STEP, bottom to top; then the drawing is traced over
## REVEAL_TIME; then CODA_TIME with everything shown.
const STRING_STEP: float = 0.24
const TUNE_TIME: float = STRING_STEP * 7
const REVEAL_TIME: float = 1.2
const CODA_TIME: float = 0.6
const COMPLETION_TIME: float = TUNE_TIME + REVEAL_TIME + CODA_TIME
## A sung string vibrates: a standing wave of VIBRATE_AMPLITUDE px, VIBRATE_CYCLES swings, dying
## out over VIBRATE_TIME. Whole pixels, across the string.
const VIBRATE_TIME: float = 0.5
const VIBRATE_AMPLITUDE: float = 2.0
const VIBRATE_CYCLES: float = 3.0
## Unlit landmarks: the star art's gold ramp mapped onto cool colours, step for step.
const COOL: Dictionary = {"fffbea": Palette.M6, "ffe59a": Palette.M5, "ffc062": Palette.N8, "e88a57": Palette.N7}

var _run: RunState
var _time: float = 0.0
var _selected: Array[int] = []
var _preview_strings: Array[int] = []
var _flash_landmark: int = -1
var _flash_string: int = -1
var _flash_left: float = 0.0
var _completion_time: float = -1.0
## The scorpion drawing is fully shown (after a completion, until the next run).
var _revealed: bool = false
var _drawing: Array[Vector2i] = []
## Idle-frame pixels per star size, from the star art.
var _art: Array = []


func _ready() -> void:
	for size: int in 3:
		_art.append(star_pixels(size))
	_drawing = scorpion_drawing()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _run == null or _run.scorpio == null:
		return
	_draw_scorpion()
	for segment: int in Scorpio.segment_count():
		_draw_string(segment)
	for i: int in Scorpio.LANDMARKS.size():
		_draw_landmark(i)
	if _completion_time >= 0.0:
		_draw_completion()


func setup(run: RunState) -> void:
	_run = run
	clear_preview()
	_flash_left = 0.0
	_completion_time = -1.0
	_revealed = false


## The link being traced: the landmarks in it and the strings it would form.
func show_link_preview(landmarks: Array[int], strings: Array[int]) -> void:
	_selected = landmarks.duplicate()
	_preview_strings = strings.duplicate()
	queue_redraw()


func clear_preview() -> void:
	_selected.clear()
	_preview_strings.clear()
	queue_redraw()


func flash_landmark(index: int) -> void:
	_flash_landmark = index
	_flash_string = -1
	_flash_left = LIT_FLASH
	queue_redraw()


func flash_string(segment: int) -> void:
	_flash_string = segment
	_flash_left = LIT_FLASH
	queue_redraw()


## The strings from the bottom of the sky to the top: lowest midpoint first.
static func song_order() -> Array[int]:
	var order: Array[int] = []
	for segment: int in Scorpio.segment_count():
		order.append(segment)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _mid_y(a) > _mid_y(b) or (_mid_y(a) == _mid_y(b) and a > b))
	return order


static func _mid_y(segment: int) -> int:
	var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
	return ends[0].y + ends[1].y


func play_completion() -> void:
	_completion_time = 0.0
	string_sung.emit(song_order()[0], 0)
	queue_redraw()


func is_completing() -> bool:
	return _completion_time >= 0.0


func is_revealed() -> bool:
	return _revealed


## How many of the drawing's pixels show now.
func drawing_shown() -> int:
	if _revealed:
		return _drawing.size()
	if _completion_time < TUNE_TIME:
		return 0
	return mini(floori((_completion_time - TUNE_TIME) / REVEAL_TIME * _drawing.size()), _drawing.size())


## How far string pixel `i` of `count` is pushed across the string `age` seconds after its note.
static func vibration(i: int, count: int, age: float) -> int:
	if age < 0.0 or age >= VIBRATE_TIME or count < 2:
		return 0
	var envelope: float = VIBRATE_AMPLITUDE * (1.0 - age / VIBRATE_TIME)
	var swing: float = cos(TAU * VIBRATE_CYCLES * age / VIBRATE_TIME)
	return roundi(envelope * swing * sin(PI * i / (count - 1)))


## The scorpion drawn around the landmarks, as the pen traces it: pincers, then the body's sides,
## the legs, the tail's bulbs and the stinger's hook. Whole pixels, in order, no repeats.
static func scorpion_drawing() -> Array[Vector2i]:
	var marks: Array[Vector2i] = Scorpio.LANDMARKS
	var strokes: Array = []
	var head := Vector2(marks[0])
	var forward: Vector2 = (head - Vector2(marks[1])).normalized()
	var across: Vector2 = forward.orthogonal()
	for side: float in [-1.0, 1.0]:
		# An arm swings out from the head and bends forward to a claw: an open C, gap to the front.
		var shoulder: Vector2 = head + across * side * 7.0 + forward * 2.0
		var elbow: Vector2 = shoulder + forward * 7.0 + across * side * 3.0
		var claw: Vector2 = elbow + forward * 5.0
		strokes.append([head, shoulder, elbow])
		var arc: Array = []
		for k: int in 9:
			var angle: float = forward.angle() + 0.7 + (TAU - 1.4) * k / 8.0
			arc.append(claw + Vector2.from_angle(angle) * 4.0)
		strokes.append(arc)
	var widths: Array[float] = [4.0, 7.0, 6.0, 5.0, 3.0]
	for side: float in [-1.0, 1.0]:
		var edge: Array = []
		for i: int in widths.size():
			edge.append(Vector2(marks[i]) + _body_normal(i) * widths[i] * side)
		strokes.append(edge)
	for i: int in [1, 2, 3]:
		for side: float in [-1.0, 1.0]:
			var root: Vector2 = Vector2(marks[i]) + _body_normal(i) * widths[i] * side
			var knee: Vector2 = root + _body_normal(i) * 6.0 * side
			var back: Vector2 = (Vector2(marks[i + 1]) - Vector2(marks[i])).normalized()
			strokes.append([root, knee, knee + back * 5.0 + _body_normal(i) * 3.0 * side])
	for i: int in range(4, marks.size() - 1):
		strokes.append(_circle((Vector2(marks[i]) + Vector2(marks[i + 1])) / 2.0, 4.0))
	var tail: Vector2 = (Vector2(marks[-1]) - Vector2(marks[-2])).normalized()
	var sting: Vector2 = Vector2(marks[-1]) + tail * 7.0
	var hook_side: Vector2 = tail.orthogonal()
	if hook_side.dot(head - Vector2(marks[-1])) < 0.0:
		hook_side = -hook_side
	strokes.append([Vector2(marks[-1]) + tail * 4.0, sting, sting + tail * 3.0 + hook_side * 4.0, sting + hook_side * 7.0])
	var pixels: Array[Vector2i] = []
	var seen: Dictionary = {}
	for stroke: Array in strokes:
		for k: int in range(1, stroke.size()):
			for p: Vector2i in LinkLayer.line_pixels(Vector2i((stroke[k - 1] as Vector2).round()), Vector2i((stroke[k] as Vector2).round())):
				if not seen.has(p) and not _near_landmark(p):
					seen[p] = true
					pixels.append(p)
	return pixels


## The body's sideways direction at landmark `i`, averaged over its neighbouring strings.
static func _body_normal(i: int) -> Vector2:
	var marks: Array[Vector2i] = Scorpio.LANDMARKS
	var a: Vector2 = Vector2(marks[maxi(i - 1, 0)])
	var b: Vector2 = Vector2(marks[mini(i + 1, marks.size() - 1)])
	return (b - a).normalized().orthogonal()


static func _circle(centre: Vector2, radius: float) -> Array:
	var points: Array = []
	for k: int in 13:
		points.append(centre + Vector2.from_angle(TAU * k / 12.0) * radius)
	return points


## The drawing leaves each landmark's star clear.
static func _near_landmark(p: Vector2i) -> bool:
	for landmark: Vector2i in Scorpio.LANDMARKS:
		if maxi(absi(p.x - landmark.x), absi(p.y - landmark.y)) <= 3:
			return true
	return false


## Where the built strings' glints are now, as a step 0 to GLOW_SPACING - 1.
func glow_step() -> int:
	return int(_time / GLOW_STEP) % GLOW_SPACING


## Moves the glow, flashes and completion on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	var step: int = glow_step()
	var cue: int = cue_frame()
	_time += delta
	var mapped: bool = _run != null and _run.scorpio != null
	var redraw: bool = mapped and ((glow_step() != step and _run.scorpio.built_count() > 0) \
		or (cue_frame() != cue and not _run.scorpio.is_complete()))
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		redraw = true
	if _completion_time >= 0.0:
		var before: int = floori(_completion_time / STRING_STEP)
		_completion_time += delta
		var now: int = floori(_completion_time / STRING_STEP)
		var order: Array[int] = song_order()
		for k: int in range(before + 1, mini(now, order.size() - 1) + 1):
			string_sung.emit(order[k], k)
		if _completion_time >= COMPLETION_TIME:
			_completion_time = -1.0
			_revealed = true
		redraw = true
	if redraw:
		queue_redraw()


## Every pixel of a string, head to stinger, with the ends kept clear of the landmarks.
static func outline_pixels(segment: int) -> Array[Vector2i]:
	var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
	var line: Array[Vector2i] = LinkLayer.line_pixels(ends[0], ends[1])
	return line.slice(LANDMARK_CLEAR, line.size() - LANDMARK_CLEAR)


## The idle frame of the star art for a size, as offsets from its centre.
static func star_pixels(size: int) -> Dictionary[Vector2i, Color]:
	var image: Image = StarView.SHEETS[size].get_image()
	var side: int = image.get_height()
	var half: int = side >> 1
	var dots: Dictionary[Vector2i, Color] = {}
	for y: int in side:
		for x: int in side:
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.5:
				dots[Vector2i(x - half, y - half)] = Color(c.r, c.g, c.b)
	return dots


## A landmark's pixels: gold when lit or in the link being traced, cool otherwise.
static func landmark_dots(art: Dictionary, gold: bool) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	for d: Vector2i in art:
		var c: Color = art[d]
		dots[d] = c if gold else COOL.get(c.to_html(false), Palette.N7)
	return dots


func _draw_string(segment: int) -> void:
	var pixels: Array[Vector2i] = outline_pixels(segment)
	var age: float = _sung_age(segment)
	if age >= 0.0 and age < VIBRATE_TIME:
		_draw_vibrating(segment, pixels, age)
		return
	if _run.scorpio.is_built(segment):
		var flash: bool = segment == _flash_string and _flash_left > 0.0
		var step: int = glow_step()
		for i: int in pixels.size():
			var glint: bool = (i + GLOW_SPACING - step) % GLOW_SPACING == 0
			_dot(pixels[i], Palette.C0 if flash or glint else Palette.C1)
		return
	var preview: bool = _preview_strings.has(segment)
	for i: int in pixels.size():
		if preview and i % 3 != 2:
			_dot(pixels[i], Palette.C2)
		elif not preview and i % OUTLINE_STEP == 0:
			_dot(pixels[i], Palette.N8)


## The selectable cue's pixels around a landmark of `size`: an L in each corner, pointing in.
static func cue_pixels(size: int) -> Array[Vector2i]:
	var o: int = StarView.half_extent(size as Star.Size) + CUE_GAP
	var dots: Array[Vector2i] = []
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var corner := Vector2i(sx * o, sy * o)
			dots.append_array([corner, corner - Vector2i(sx, 0), corner - Vector2i(0, sy)])
	return dots


## Which of the cue's two colours shows now: 0 (C5) or 1 (C4).
func cue_frame() -> int:
	return int(_time / CUE_STEP) % 2


## Whether landmark `index` shows the selectable cue: unlit, not in the link being traced, and
## not while the constellation plays.
func shows_cue(index: int) -> bool:
	return _run != null and _run.scorpio != null and not _run.scorpio.is_lit(index) \
		and not _selected.has(index) and _completion_time < 0.0


func _draw_landmark(index: int) -> void:
	if shows_cue(index):
		var colour: Color = Palette.C4 if cue_frame() == 1 else Palette.C5
		for d: Vector2i in cue_pixels(Scorpio.SIZES[index]):
			_dot(Scorpio.LANDMARKS[index] + d, colour)
	var gold: bool = _run.scorpio.is_lit(index) or _selected.has(index)
	var art: Dictionary = _art[Scorpio.SIZES[index]]
	var flash: bool = index == _flash_landmark and _flash_left > 0.0
	var dots: Dictionary[Vector2i, Color] = landmark_dots(art, gold)
	for d: Vector2i in dots:
		_dot(Scorpio.LANDMARKS[index] + d, Palette.C0 if flash else dots[d])


## Completion: the landmarks of the strings played so far flash C0.
func _draw_completion() -> void:
	var order: Array[int] = song_order()
	var played: int = mini(floori(_completion_time / STRING_STEP) + 1, order.size())
	for k: int in played:
		var segment: int = order[k]
		for index: int in [segment, segment + 1]:
			var dots: Dictionary[Vector2i, Color] = landmark_dots(_art[Scorpio.SIZES[index]], true)
			for d: Vector2i in dots:
				_dot(Scorpio.LANDMARKS[index] + d, Palette.C0 if dots[d] != Palette.C3 else Palette.C1)


## Seconds since `segment`'s note in the completion tune, or -1 if it hasn't sounded.
func _sung_age(segment: int) -> float:
	if _completion_time < 0.0:
		return -1.0
	var start: float = song_order().find(segment) * STRING_STEP
	return _completion_time - start if _completion_time >= start else -1.0


## A string just sung: C0, pushed across itself by the standing wave.
func _draw_vibrating(segment: int, pixels: Array[Vector2i], age: float) -> void:
	var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
	var along: Vector2i = ends[1] - ends[0]
	var across := Vector2i(1, 0) if absi(along.y) > absi(along.x) else Vector2i(0, 1)
	for i: int in pixels.size():
		_dot(pixels[i] + across * vibration(i, pixels.size(), age), Palette.C0)


## The scorpion drawing, as much of it as the pen has traced: soft N9 lines behind the stars.
func _draw_scorpion() -> void:
	var shown: int = drawing_shown()
	for i: int in shown:
		_dot(_drawing[i], Palette.N9)
	if shown > 0 and shown < _drawing.size():
		_dot(_drawing[shown - 1], Palette.C0)


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
