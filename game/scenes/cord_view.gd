class_name CordView
extends Node2D
## Pisces's cords (chapter 6 trial): every link's string stays in the sky as a cord until the sky is
## cleared. Owns no rules: RunState.cords holds them; Sky plays cord_tied and cords_cleared here.
## Look: a dim rope, never the gold of the lit strings (C1 with C0 pulses over a C5 glow): 1 px of N5
## twisted with N6 every ROPE_PERIOD px, broken by a 1 px gap (dashed), with a small N6 knot where
## each of its stars stood. A cord is laid as its link's collect flash fades (TIE_DELAY): it runs out
## from the first star in pick order, solid N7 as it's drawn tight, then settles into the rope.
## While a traced step would cross a cord (`tracing_step`), that cord glows ember (S3 twisted with S4,
## no gaps), the colour of a refused link: the line can't pass it. A refused step (a tap as much as a
## drag) has the cords it crosses glow the same for the reject flash (flash_blocking). It's drawn
## under the map (the Sky's lowest layer), so a cord through a lit landmark or along a lit string
## never covers its gold. A clear (a rekindle, the
## completion) flashes the cords N7 for CLEAR_FLASH and they're gone; a Big Bang keeps them until
## its freeze, so its opening still looks like a normal burst.
## The fish's cord (RunState.cords' fixed segments, StarMap.fish_cord) is there as the stage opens and
## never goes: not with a clear, not with a Big Bang. It reads as part of the sky, a step stronger than
## a link's rope but as cool: unbroken, N7 twisted with N6 every other pixel (N5 vanished over the
## horizon haze), under the strings' dotted N8, with a 3x3 knot at Alrescha (each bend of the
## polyline: N8 heart, N7 arms, N6 corners) and no knots at its loose ends. It glows ember like a link's cord when a step would cross it (S4 twisted with S3, the knot
## S4 with S3 corners).

## The rope's pattern along its pixels: N6, N5, N5, then a gap.
const ROPE_PERIOD: int = 4
## A cord is laid once its link's collect flash is half gone, over TIE_TIME (its two segments one
## after the other).
const TIE_DELAY: float = LinkLayer.COLLECT_TIME * 0.5
const TIE_TIME: float = 0.16
## A laid cord shows solid N7 this long once it's tight, then the rope.
const TIE_FLASH: float = 0.08
const CLEAR_FLASH: float = 0.1
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const CORNERS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
## The fish's cord's pattern: N7, N6, over again, with no gap.
const FISH_PERIOD: int = 2

## The step being traced to the finger, [from, to] (empty: none): every cord it would cross glows.
var tracing_step: Array[Vector2i] = []:
	set(value):
		if tracing_step != value:
			tracing_step = value.duplicate()
			queue_redraw()
## A refused step, [from, to] (empty: none), whose crossed cords glow for `_blocking_left` seconds.
var _blocking_step: Array[Vector2i] = []
var _blocking_left: float = 0.0
var _run: RunState
var _sequencer: EventSequencer
## The cords shown, each segment as [from, to], and the seconds since each began to be laid
## (negative: still waiting for its link's flash).
var _segments: Array[Array] = []
var _ages: Array[float] = []
## How many of _segments, at the front, are the fish's cord (never laid, never cleared).
var _fixed: int = 0
## A clear playing: seconds until its flash starts (a Big Bang's freeze), then the flash's seconds
## left; -1 for none.
var _clear_wait: float = -1.0
var _clear_left: float = -1.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	tracing_step = [] as Array[Vector2i]
	_blocking_step.clear()
	_blocking_left = 0.0
	_clear_wait = -1.0
	_clear_left = -1.0
	_sync()
	set_process(run.cords != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## A link left its string through `points` (in pick order): laid once its collect flash fades.
func tie(points: Array[Vector2i]) -> void:
	for i: int in range(1, points.size()):
		if points[i - 1] == points[i]:
			continue
		_segments.append([points[i - 1], points[i]] as Array[Vector2i])
		_ages.append(-TIE_DELAY - (i - 1) * TIE_TIME * 0.5)
	queue_redraw()


## A step from `a` to `b` was refused: every cord it crosses glows ember for `seconds`.
func flash_blocking(a: Vector2i, b: Vector2i, seconds: float) -> void:
	_blocking_step = [a, b]
	_blocking_left = seconds
	queue_redraw()


## Whether a cord glows for a refused step now.
func is_flashing_blocking() -> bool:
	return _blocking_left > 0.0


## The sky was cleared: the cords flash and go.
func clear_cords() -> void:
	_clear_wait = 0.0
	_clear_left = CLEAR_FLASH
	queue_redraw()


## A Big Bang follows the clear: the cords stay until its freeze.
func hold_for_big_bang() -> void:
	if _clear_left >= 0.0:
		_clear_wait = maxf(_clear_wait, BigBangSequence.FREEZE_AT)


## How many cord segments show now, the fish's cord's included.
func shown_count() -> int:
	return _segments.size()


## How many of the segments shown are the fish's cord.
func fish_count() -> int:
	return _fixed


## Whether a cord is still being laid or cleared.
func is_playing() -> bool:
	return _clear_left >= 0.0 or _ages.any(func(age: float) -> bool: return age < TIE_TIME + TIE_FLASH)


## Lays and clears the cords. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	for i: int in _ages.size():
		_ages[i] += delta
	if _blocking_left > 0.0:
		_blocking_left -= delta
		if _blocking_left <= 0.0:
			_blocking_step.clear()
	if _clear_left >= 0.0:
		if _clear_wait > 0.0:
			_clear_wait -= delta
		else:
			_clear_left -= delta
			if _clear_left < 0.0:
				_segments.resize(_fixed)
				_ages.resize(_fixed)
				_clear_wait = -1.0
	if _run != null and _run.cords != null and not is_playing() and (_sequencer == null or not _sequencer.is_busy()):
		_sync()


func _sync() -> void:
	_segments.clear()
	_ages.clear()
	_fixed = 0
	if _run == null or _run.cords == null:
		return
	_segments = _run.cords.segments()
	_fixed = _run.cords.fixed_count()
	for i: int in _segments.size():
		_ages.append(TIE_TIME + TIE_FLASH)


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var flashing: bool = _clear_left >= 0.0 and _clear_wait <= 0.0
	result.merge(_fish_pixels(), true)
	for i: int in range(_fixed, _segments.size()):
		var a: Vector2i = _segments[i][0]
		var b: Vector2i = _segments[i][1]
		var age: float = _ages[i]
		if age < 0.0:
			continue
		var laid: float = minf(age / (TIE_TIME * 0.5), 1.0)
		if flashing or laid < 1.0 or age < TIE_TIME * 0.5 + TIE_FLASH:
			result.merge(laying_pixels(a, b, 1.0 if flashing else laid), true)
			continue
		var hot: bool = _crosses(tracing_step, a, b) or _crosses(_blocking_step, a, b)
		result.merge(rope_pixels(a, b, hot), true)
	return result


## The fish's cord: each fixed segment as its rope, then a knot at each bend (Alrescha), hot if a
## segment it ties is.
func _fish_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var ends: Dictionary[Vector2i, int] = {}
	var hot_ends: Dictionary[Vector2i, bool] = {}
	for i: int in _fixed:
		var a: Vector2i = _segments[i][0]
		var b: Vector2i = _segments[i][1]
		var hot: bool = _crosses(tracing_step, a, b) or _crosses(_blocking_step, a, b)
		result.merge(fish_rope_pixels(a, b, hot), true)
		for end: Vector2i in [a, b]:
			ends[end] = ends.get(end, 0) + 1
			if hot:
				hot_ends[end] = true
	for end: Vector2i in ends:
		if ends[end] > 1:
			result.merge(fish_knot_pixels(end, hot_ends.has(end)), true)
	return result


## A stretch of the fish's cord from `a` to `b`: unbroken, N7 and N6 by turns from `a`; `hot`, S4
## and S3. No knots at its ends (fish_knot_pixels ties its bends).
static func fish_rope_pixels(a: Vector2i, b: Vector2i, hot: bool) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var line: Array[Vector2i] = LinkLayer.line_pixels(a, b)
	for i: int in line.size():
		var twist: bool = i % FISH_PERIOD == 0
		if hot:
			result[line[i]] = Palette.S4 if twist else Palette.S3
		else:
			result[line[i]] = Palette.N7 if twist else Palette.N6
	return result


## The fish's knot at Alrescha: 3x3, an N8 heart with N7 arms and N6 corners (hot: S4, S4, S3).
static func fish_knot_pixels(at: Vector2i, hot: bool = false) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for corner: Vector2i in CORNERS:
		result[at + corner] = Palette.S3 if hot else Palette.N6
	for n: Vector2i in NEIGHBOURS:
		result[at + n] = Palette.S4 if hot else Palette.N7
	result[at] = Palette.S4 if hot else Palette.N8
	return result


## A cord from `a` to `b` as a rope: N6, N5, N5, a gap, over again, from `a`, with a knot at each
## end; `hot` (a traced step would cross it), S4, S3, S3, S3 and no gap.
static func rope_pixels(a: Vector2i, b: Vector2i, hot: bool) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var line: Array[Vector2i] = LinkLayer.line_pixels(a, b)
	for i: int in line.size():
		var phase: int = i % ROPE_PERIOD
		if hot:
			result[line[i]] = Palette.S4 if phase == 0 else Palette.S3
		elif phase == 0:
			result[line[i]] = Palette.N6
		elif phase < ROPE_PERIOD - 1:
			result[line[i]] = Palette.N5
	for end: Vector2i in [a, b]:
		result.merge(knot_pixels(end, hot), true)
	return result


## A knot where a linked star stood: an N6 point with N5 arms (hot: S4 with S3 arms).
static func knot_pixels(at: Vector2i, hot: bool = false) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for n: Vector2i in NEIGHBOURS:
		result[at + n] = Palette.S3 if hot else Palette.N5
	result[at] = Palette.S4 if hot else Palette.N6
	return result


## A cord being laid (or flashing as it's cleared): solid N7 from `a`, `share` (0 to 1) of the way.
static func laying_pixels(a: Vector2i, b: Vector2i, share: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var line: Array[Vector2i] = LinkLayer.line_pixels(a, b)
	var shown: int = ceili(line.size() * clampf(share, 0.0, 1.0))
	for i: int in shown:
		result[line[i]] = Palette.N7
	return result


## Whether `step` ([from, to], or empty) properly crosses the cord from `a` to `b`.
static func _crosses(step: Array[Vector2i], a: Vector2i, b: Vector2i) -> bool:
	return step.size() == 2 and StarCords.properly_cross(step[0], step[1], a, b)
