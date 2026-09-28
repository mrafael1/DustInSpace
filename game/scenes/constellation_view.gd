class_name ConstellationView
extends Node2D
## Draws the Scorpio map (#40) under the stars. Each landmark is drawn with the star art of its
## size, so a small, medium or big landmark has the shape of the sky star it can stand in for.
## Unlit (usable in a combo), it uses the art's "unlit" frame, a cool tint per size (small pink,
## medium lavender, big blue), and four small corner brackets in the dim halo tones (C4/C5, swapping
## every CUE_STEP) say "you can pick this". Lit, it uses the "gold" frame: the same gold on every
## size, so gold only ever means lit. Strings between two lit landmarks glow C1 with a C0 glint
## running along them; strings still to form are dotted N8. While a link is traced, the landmarks
## in it show gold and the strings it would form are dashed C2. Like the HUD and the Sun it keeps
## a shown copy of what's lit, moved only by played landmark_lit events, so a landmark the Sun
## lights stays unlit until the Sun's ignition has played. Owns no rules:
## RunState says what's lit. Draws nothing without the map.
## Completion plays the constellation like an instrument once every payout has landed (the Sky
## waits): string by string from the bottom of the sky to the top, each flashing C0 and vibrating
## as its note sounds (string_sung). Then a drawing of the scorpion is traced around the lit
## stars, stroke by stroke, and stays.

## The sunbeam reached its landmark, at `at`. Feedback only.
signal sunbeam_landed(at: Vector2i)
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
## A landmark lighting throws a 1 px ring from its art's edge out LIT_RING_GROWTH px over
## LIT_RING_TIME, cooling C0 to C3.
const LIT_RING_TIME: float = 0.4
const LIT_RING_GROWTH: int = 14
const LIT_RING_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
## The Sun lights a landmark with a sunbeam: a comet from the Sun's rim to the landmark over
## BEAM_TIME, eased out: a small star for a head (C0 heart, C1 arms) and a 3 px wide trail of
## BEAM_TRAIL pixels cooling C0 to C3, its edges a step dimmer. The landmark lights as it lands
## (the Sun holds the sequence that long, still shining).
const BEAM_TIME: float = 0.5
const BEAM_TRAIL: int = 14
const BEAM_RAMP: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
const SUN_RIM: int = 20
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

var _run: RunState
var _time: float = 0.0
var _selected: Array[int] = []
## Which landmarks show lit: the run's as of setup, then each played landmark_lit.
var _shown_lit: Array[bool] = []
var _preview_strings: Array[int] = []
var _flash_landmark: int = -1
var _flash_string: int = -1
var _flash_left: float = 0.0
## The landmark whose lit ring is spreading, and for how long it has (-1: none).
var _ring_landmark: int = -1
var _ring_time: float = -1.0
## The sunbeam in flight: from, to, and its age (-1: none).
var _beam_from: Vector2i = Vector2i.ZERO
var _beam_to: Vector2i = Vector2i.ZERO
var _beam_time: float = -1.0
var _completion_time: float = -1.0
## The scorpion drawing is fully shown (after a completion, until the next run).
var _revealed: bool = false
var _drawing: Array[Vector2i] = []
## Landmark pixels per star size, from the star art: [unlit, lit].
var _art: Array = []


func _ready() -> void:
	for size: int in 3:
		_art.append([landmark_pixels(size, false), landmark_pixels(size, true)])
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
	if _ring_time >= 0.0:
		for p: Vector2i in lit_ring_pixels(Scorpio.SIZES[_ring_landmark], _ring_time / LIT_RING_TIME):
			_dot(Scorpio.LANDMARKS[_ring_landmark] + p, LIT_RING_COLOURS[mini(floori(_ring_time / LIT_RING_TIME * 4.0), 3)])
	if _beam_time >= 0.0:
		_draw_beam(beam_pixels(_beam_from, _beam_to, _beam_time / BEAM_TIME))
	if _completion_time >= 0.0:
		_draw_completion()


func setup(run: RunState) -> void:
	_run = run
	# The map sits where the run's sky puts it (a taller sky moves it up); everything here is drawn
	# in its home layout, so the whole view moves with it.
	position = Vector2(run.scorpio.shift) if run.scorpio != null else Vector2.ZERO
	_shown_lit.clear()
	if run.scorpio != null:
		_shown_lit.assign(run.scorpio.lit)
	clear_preview()
	_flash_left = 0.0
	_ring_time = -1.0
	_beam_time = -1.0
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


## A landmark_lit event played: it shows lit from now, with a C0 flash and a ring spreading out.
func flash_landmark(index: int) -> void:
	if index < _shown_lit.size():
		_shown_lit[index] = true
	_ring_landmark = index
	_ring_time = 0.0
	_flash_landmark = index
	_flash_string = -1
	_flash_left = LIT_FLASH
	queue_redraw()


## The Sun's ignition is over: a sunbeam flies from its rim (the Sun sits at `sun`) to landmark
## `index`, which lights when it lands (its landmark_lit event plays then). -1: no beam.
func launch_sunbeam(sun: Vector2i, index: int) -> void:
	if index < 0 or index >= Scorpio.LANDMARKS.size():
		return
	_beam_to = Scorpio.LANDMARKS[index]
	var sun_here: Vector2i = sun - Vector2i(position)
	var toward: Vector2 = Vector2(_beam_to - sun_here).normalized()
	_beam_from = sun_here + Vector2i((toward * SUN_RIM).round())
	_beam_time = 0.0
	queue_redraw()


func is_beaming() -> bool:
	return _beam_time >= 0.0


## The sunbeam's head and trail at `k` (0-1 of its flight), head first: whole pixels along the
## line, the head eased out, the trail the BEAM_TRAIL pixels behind it.
static func beam_pixels(from: Vector2i, to: Vector2i, k: float) -> Array[Vector2i]:
	var line: Array[Vector2i] = LinkLayer.line_pixels(from, to)
	var eased: float = 1.0 - (1.0 - clampf(k, 0.0, 1.0)) * (1.0 - clampf(k, 0.0, 1.0))
	var head: int = roundi(eased * (line.size() - 1))
	var pixels: Array[Vector2i] = []
	for i: int in range(head, maxi(head - BEAM_TRAIL, -1), -1):
		pixels.append(line[i])
	return pixels


## The sunbeam: its trail, 3 px wide and cooling, then its star-shaped head on top.
func _draw_beam(trail: Array[Vector2i]) -> void:
	var along: Vector2 = Vector2(_beam_to - _beam_from).normalized()
	var side := Vector2i(Vector2(-along.y, along.x).round())
	for i: int in range(trail.size() - 1, 0, -1):
		var step: int = mini(i * BEAM_RAMP.size() / trail.size(), BEAM_RAMP.size() - 1)
		var edge: Color = BEAM_RAMP[mini(step + 1, BEAM_RAMP.size() - 1)]
		if i < trail.size() - 3:
			_dot(trail[i] + side, edge)
			_dot(trail[i] - side, edge)
		_dot(trail[i], BEAM_RAMP[step])
	for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		_dot(trail[0] + n, Palette.C1)
		_dot(trail[0] + n * 2, Palette.C2)
	_dot(trail[0], Palette.C0)


## A lit ring around a landmark of `size`, `k` (0-1) of the way out: a 1 px circle.
static func lit_ring_pixels(size: int, k: float) -> Array[Vector2i]:
	var radius: int = StarView.half_extent(size as Star.Size) + 2 + roundi(clampf(k, 0.0, 1.0) * LIT_RING_GROWTH)
	var dots: Array[Vector2i] = []
	for dy: int in range(-radius - 1, radius + 2):
		for dx: int in range(-radius - 1, radius + 2):
			if roundi(sqrt(dx * dx + dy * dy)) == radius:
				dots.append(Vector2i(dx, dy))
	return dots


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


## The scorpion drawn around the landmarks, as the pen traces it: the claws (an arm to each of
## Scorpius's claw stars, Scorpio.CLAWS, and a pincer there), then the body's sides,
## the legs, the tail's bulbs and the stinger's hook. Whole pixels, in order, no repeats.
static func scorpion_drawing() -> Array[Vector2i]:
	var marks: Array[Vector2i] = Scorpio.LANDMARKS
	var strokes: Array = []
	var head := Vector2(marks[0])
	var forward: Vector2 = (head - Vector2(marks[1])).normalized()
	for claw: Vector2i in Scorpio.CLAWS:
		# An arm runs from the head out to a claw star (Scorpius's head arc), bowing forward, and
		# a pincer opens there: an open C, its gap to the front.
		var tip: Vector2 = head + Vector2(claw)
		var elbow: Vector2 = head + Vector2(claw) * 0.5 + forward * 4.0
		strokes.append([head, elbow, tip])
		var centre: Vector2 = tip + forward * 3.0
		var arc: Array = []
		for k: int in 9:
			var angle: float = forward.angle() + 0.7 + (TAU - 1.4) * k / 8.0
			arc.append(centre + Vector2.from_angle(angle) * 4.0)
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
	var redraw: bool = mapped and ((glow_step() != step and _shown_lit.count(true) > 1) \
		or (cue_frame() != cue and _shown_lit.has(false)))
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		redraw = true
	if _ring_time >= 0.0:
		_ring_time += delta
		if _ring_time >= LIT_RING_TIME:
			_ring_time = -1.0
		redraw = true
	if _beam_time >= 0.0:
		_beam_time += delta
		if _beam_time >= BEAM_TIME:
			_beam_time = -1.0
			sunbeam_landed.emit(_beam_to)
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


## A frame of the star art for a size, as offsets from its centre.
static func star_pixels(size: int, frame: StringName = &"idle") -> Dictionary[Vector2i, Color]:
	var image: Image = StarView.SHEETS[size].get_image()
	var side: int = image.get_height()
	var half: int = side >> 1
	var left: int = StarView.FRAMES.find(frame) * side
	var dots: Dictionary[Vector2i, Color] = {}
	for y: int in side:
		for x: int in side:
			var c: Color = image.get_pixel(left + x, y)
			if c.a > 0.5:
				dots[Vector2i(x - half, y - half)] = Color(c.r, c.g, c.b)
	return dots


## A landmark's pixels: gold when lit (or in the link being traced), its size's cool tint otherwise.
static func landmark_pixels(size: int, lit: bool) -> Dictionary[Vector2i, Color]:
	return star_pixels(size, &"gold" if lit else &"unlit")


func _draw_string(segment: int) -> void:
	var pixels: Array[Vector2i] = outline_pixels(segment)
	var age: float = _sung_age(segment)
	if age >= 0.0 and age < VIBRATE_TIME:
		_draw_vibrating(segment, pixels, age)
		return
	if shows_built(segment):
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


## Whether landmark `index` shows lit: its landmark_lit event has played (or it was lit at setup).
func shows_lit(index: int) -> bool:
	return index < _shown_lit.size() and _shown_lit[index]


## Whether string `segment` shows formed: both its landmarks show lit.
func shows_built(segment: int) -> bool:
	return shows_lit(segment) and shows_lit(segment + 1)


## Which of the cue's two colours shows now: 0 (C5) or 1 (C4).
func cue_frame() -> int:
	return int(_time / CUE_STEP) % 2


## Whether landmark `index` shows the selectable cue: unlit, not in the link being traced, and
## not while the constellation plays.
func shows_cue(index: int) -> bool:
	return _run != null and _run.scorpio != null and not shows_lit(index) \
		and not _selected.has(index) and _completion_time < 0.0


func _draw_landmark(index: int) -> void:
	if shows_cue(index):
		var colour: Color = Palette.C4 if cue_frame() == 1 else Palette.C5
		for d: Vector2i in cue_pixels(Scorpio.SIZES[index]):
			_dot(Scorpio.LANDMARKS[index] + d, colour)
	var lit: bool = shows_lit(index) or _selected.has(index)
	var flash: bool = index == _flash_landmark and _flash_left > 0.0
	var dots: Dictionary = _art[Scorpio.SIZES[index]][1 if lit else 0]
	for d: Vector2i in dots:
		_dot(Scorpio.LANDMARKS[index] + d, Palette.C0 if flash else dots[d])


## Completion: the landmarks of the strings played so far flash C0.
func _draw_completion() -> void:
	var order: Array[int] = song_order()
	var played: int = mini(floori(_completion_time / STRING_STEP) + 1, order.size())
	for k: int in played:
		var segment: int = order[k]
		for index: int in [segment, segment + 1]:
			var dots: Dictionary = _art[Scorpio.SIZES[index]][1]
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
