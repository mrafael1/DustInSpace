class_name HeatView
extends Node2D
## Leo's heat, over the whole stage: embers rising slowly through the sky (the cold: frost motes
## drifting down; day and night turn from one to the other once a launch has played out). While
## aiming, each star the next launch changes shows it: a dotted outline of the size it will grow
## to, in that size's own colour, or a dotted ember outline crowned with flames on a star that
## will burn out; in the cold, its own outline dotted in the colour of the size it shrinks to, or
## dotted frost crowned with a snowflake on a small one that will fade. Drawn above the halos and below the links and stars.
## The core supplies every change; pack contents stay hidden.

## The motes: one per MOTE_AREA px² of the sky, rising MOTE_SPEED px/s (falling in the cold),
## each by a fixed hash so the pattern is stable. A head pixel and a dimmer one behind it.
const MOTE_AREA: int = 900
const MOTE_SPEED := Vector2i(4, 9)
## The motes' head and tail: embers in the heat (never C0-C3), frost in the cold.
const HEAT_COLOURS: Array[Color] = [Palette.S3, Palette.S2]
const COLD_COLOURS: Array[Color] = [Palette.M5, Palette.M4]
## The next size's outline, in that size's own tip colour (small, medium, big).
const NEXT_COLOURS: Array[Color] = [Palette.C3, Palette.N8, Palette.M5]
## The crown of flames over a star that will burn out, from just above its ember ring's top.
const FLAMES: Dictionary[Vector2i, Color] = {
	Vector2i(0, -5): Palette.S4, Vector2i(0, -4): Palette.S4, Vector2i(0, -3): Palette.S4, Vector2i(0, -2): Palette.S3, Vector2i(0, -1): Palette.S3,
	Vector2i(-2, -3): Palette.S4, Vector2i(-2, -2): Palette.S4, Vector2i(-2, -1): Palette.S3,
	Vector2i(2, -3): Palette.S4, Vector2i(2, -2): Palette.S4, Vector2i(2, -1): Palette.S3,
}
## A burnt star's embers: BURN_SPARKS rising and spreading from where it stood for BURN_TIME,
## S4 then S3, in hard steps.
const BURN_TIME: float = 0.5
const BURN_SPARKS: int = 7
const BURN_RISE := Vector2(26.0, 46.0)
## The cold's mark on a small star that will fade: its own outline, dotted.
const FROST: Color = Palette.M6
## The snowflake over a small star that will fade, from just above its frost ring's top.
const SNOWFLAKE: Dictionary[Vector2i, Color] = {
	Vector2i(0, -5): Palette.M6, Vector2i(0, -4): Palette.M6, Vector2i(0, -3): Palette.M6, Vector2i(0, -2): Palette.M6, Vector2i(0, -1): Palette.M6,
	Vector2i(-2, -3): Palette.M6, Vector2i(-1, -3): Palette.M6, Vector2i(1, -3): Palette.M6, Vector2i(2, -3): Palette.M6,
	Vector2i(-2, -5): Palette.M5, Vector2i(2, -5): Palette.M5, Vector2i(-2, -1): Palette.M5, Vector2i(2, -1): Palette.M5,
}
## A faded star's frost: FADE_FLAKES falling and spreading from where it stood for BURN_TIME, M6
## then M5, slower and shorter than a burn's embers.
const FADE_FLAKES: int = 6
const FADE_FALL := Vector2(12.0, 22.0)
## The lion's breath (Leo's final): a heatwave rolls out from the link at BREATH_SPEED px/s for
## BREATH_TIME, a dotted ember ring (C2 at its front, S4 a pixel behind, S3 behind that), and the
## stars change as it reaches them. The embers rise BREATH_SURGE times faster meanwhile.
const BREATH_SPEED: float = 360.0
const BREATH_TIME: float = 0.55
const BREATH_SURGE: float = 3.0
const BREATH_RING: Array[Color] = [Palette.C2, Palette.S4, Palette.S3]

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
## A full, valid link being traced on Leo's final: its breath's preview shows round each star it
## would change. Empty: none.
var tracing: Array[int] = []:
	set(value):
		if tracing != value:
			tracing = value.duplicate()
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
## Seconds the motes have moved.
var _time: float = 0.0
## Burns playing: where, and the seconds since.
var _burns: Dictionary[Vector2i, float] = {}
## Fades playing: where, and the seconds since.
var _fades: Dictionary[Vector2i, float] = {}
## Heatwaves rolling out: from where, and the seconds since.
var _breaths: Dictionary[Vector2i, float] = {}
## The heat (+1) or cold (-1) the motes show. Day and night turn in the core the moment a launch
## resolves; the view turns only once that launch has played out (its burst and resizes).
var _shown_change: int = 0


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_burns.clear()
	_fades.clear()
	_breaths.clear()
	tracing = []
	_shown_change = run.heat.change if run.heat != null else 0
	set_process(run.heat != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## Moves the motes and any burns or fades on, and turns day and night once the launch has played
## out. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta * (BREATH_SURGE if not _breaths.is_empty() else 1.0)
	for flashes: Dictionary[Vector2i, float] in [_burns, _fades, _breaths]:
		var lasts: float = BREATH_TIME if flashes == _breaths else BURN_TIME
		for at: Vector2i in flashes.keys():
			flashes[at] += delta
			if flashes[at] >= lasts:
				flashes.erase(at)
	if _run != null and _run.heat != null and (_sequencer == null or not _sequencer.is_busy()):
		_shown_change = _run.heat.change


## Plays a star burning out at `at`.
func flash_burn(at: Vector2i) -> void:
	_burns[at] = 0.0
	queue_redraw()


## The lion breathed from a link at `at`: a heatwave rolls out from it.
func flash_breath(at: Vector2i) -> void:
	_breaths[at] = 0.0
	queue_redraw()


func is_breathing() -> bool:
	return not _breaths.is_empty()


## Seconds the heatwave from `from` takes to reach `to`.
static func breath_delay(from: Vector2i, to: Vector2i) -> float:
	return Vector2(from).distance_to(Vector2(to)) / BREATH_SPEED


## The heatwave from `at`, `t` seconds out: a dotted ring three pixels deep, inside `area`.
static func breath_pixels(at: Vector2i, t: float, area: Rect2i) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= BREATH_TIME:
		return pixels
	var front: int = roundi(t * BREATH_SPEED)
	for k: int in BREATH_RING.size():
		var radius: int = front - k
		if radius < 1:
			continue
		for p: Vector2i in ConstellationView.circle_pixels(radius):
			if (p.x + p.y + k) % 2 == 0 and area.has_point(at + p):
				pixels[at + p] = BREATH_RING[k]
	return pixels


## Plays a small star fading out in the cold at `at`.
func flash_fade(at: Vector2i) -> void:
	_fades[at] = 0.0
	queue_redraw()


## The heat (+1) or cold (-1) the sky shows now.
func shown_change() -> int:
	return _shown_change


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.heat == null:
		return result
	if not _run.is_over() or not _burns.is_empty() or not _fades.is_empty():
		var colours: Array[Color] = HEAT_COLOURS if _shown_change > 0 else COLD_COLOURS
		result.merge(mote_pixels(_run.sky_rect, _shown_change, _time, colours))
	for at: Vector2i in _burns:
		result.merge(burn_pixels(at, _burns[at]), true)
	for at: Vector2i in _fades:
		result.merge(fade_pixels(at, _fades[at]), true)
	for at: Vector2i in _breaths:
		result.merge(breath_pixels(at, _breaths[at], _run.sky_rect), true)
	var idle: bool = _sequencer == null or not _sequencer.is_busy()
	if not tracing.is_empty() and idle:
		result.merge(preview_pixels(_run, tracing), true)
	elif aiming and idle:
		result.merge(preview_pixels(_run), true)
	return result


## What the next launch does, drawn round each star it changes; or with `link`, what that link's
## breath would do (Leo's final).
static func preview_pixels(run: RunState, link: Array[int] = []) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var changes: Array[StarHeat.Change] = run.breath_preview(link) if not link.is_empty() else run.heat_preview()
	for change: StarHeat.Change in changes:
		# A constellation star (the Head) has a landmark id.
		var star: Star = run.find_star(change.star_id) if change.star_id >= 0 else run.scorpio.landmark_star(Scorpio.landmark_index(change.star_id))
		if star == null:
			continue
		if change.is_cold() or change.rekindled:
			# Its own outline (the smaller size would hide under the star), dotted in the colour
			# of the size it shrinks to (or a big constellation star burns back to); dotted frost
			# and a snowflake over a small one that fades.
			for offset: Vector2i in StarView.outline_pixels(star.size):
				if (offset.x + offset.y) % 2 == 0:
					result[star.position + offset] = FROST if change.lost else NEXT_COLOURS[change.to]
			if change.lost:
				var over := Vector2i(0, -StarView.half_extent(star.size) - 2)
				for offset: Vector2i in SNOWFLAKE:
					result[star.position + over + offset] = SNOWFLAKE[offset]
			continue
		if change.lost:
			# Its own outline, dotted ember (it's going), crowned with flames.
			for offset: Vector2i in StarView.outline_pixels(star.size):
				if (offset.x + offset.y) % 2 == 0:
					result[star.position + offset] = Palette.S4
			var top := Vector2i(0, -StarView.half_extent(star.size) - 2)
			for offset: Vector2i in FLAMES:
				result[star.position + top + offset] = FLAMES[offset]
			continue
		for offset: Vector2i in StarView.outline_pixels(change.to):
			# Dotted, one pixel in two, so it never reads as the selection ring.
			if (offset.x + offset.y) % 2 == 0:
				result[star.position + offset] = NEXT_COLOURS[change.to]
	return result


## The motes at `time` seconds: rising through `area` in the heat (`change` +1), falling in the
## cold, each wrapping round once it has left. Whole pixels only, no fades.
static func mote_pixels(area: Rect2i, change: int, time: float, colours: Array[Color]) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if not area.has_area():
		return pixels
	for i: int in maxi(1, area.get_area() / MOTE_AREA):
		var h: int = CurrentView._hash(i + 7919)
		var speed: int = MOTE_SPEED.x + (h / 7) % (MOTE_SPEED.y - MOTE_SPEED.x + 1)
		var travelled: int = (h / 13 + floori(time * speed)) % area.size.y
		# A rising ember wavers a pixel either side as it goes.
		var x: int = area.position.x + 1 + (h / 101) % maxi(1, area.size.x - 2) + ((travelled / 5) % 2)
		var y: int = area.end.y - 1 - travelled if change > 0 else area.position.y + travelled
		pixels[Vector2i(x, y)] = colours[0]
		var behind := Vector2i(x, y + change)
		if area.has_point(behind):
			pixels[behind] = colours[1]
	return pixels


## A burnt star's embers `t` seconds after it burned at `at`: a flare, then sparks rising and
## spreading as they cool.
static func burn_pixels(at: Vector2i, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= BURN_TIME:
		return pixels
	if t < 0.08:
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			for k: int in range(1, 4):
				pixels[at + d * k] = Palette.S4
	for i: int in BURN_SPARKS:
		var spread: float = (float(i) / (BURN_SPARKS - 1) - 0.5) * 1.6
		var rise: float = lerpf(BURN_RISE.x, BURN_RISE.y, float((i * 3) % BURN_SPARKS) / (BURN_SPARKS - 1))
		var k: float = t / BURN_TIME
		var spark := Vector2(spread * rise * k, -rise * k * (2.0 - k))
		pixels[at + Vector2i(spark.round())] = Palette.S4 if k < 0.5 else Palette.S3
	return pixels


## A faded star's frost `t` seconds after it faded at `at`: a pale flash, then flakes drifting
## down and apart as they dim.
static func fade_pixels(at: Vector2i, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= BURN_TIME:
		return pixels
	if t < 0.08:
		for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			for k: int in range(1, 3):
				pixels[at + d * k] = Palette.M6
	for i: int in FADE_FLAKES:
		var spread: float = (float(i) / (FADE_FLAKES - 1) - 0.5) * 1.4
		var fall: float = lerpf(FADE_FALL.x, FADE_FALL.y, float((i * 5) % FADE_FLAKES) / (FADE_FLAKES - 1))
		var k: float = t / BURN_TIME
		var flake := Vector2(spread * fall * k, fall * k)
		pixels[at + Vector2i(flake.round())] = Palette.M6 if k < 0.5 else Palette.M5
	return pixels
