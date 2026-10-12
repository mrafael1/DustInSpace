class_name GravityView
extends Node2D
## Sagittarius's black hole (chapter 5 trial), minimal cues: an N0 disc the size of its horizon inside
## a cool accretion ring, its bright arc orbiting in whole steps, the ring flaring ember as it
## swallows a star. While aiming, each star's fall shows as a dotted trail to where it lands (M5
## brackets), or ember dots into the hole for a star it swallows; random pack contents stay hidden.
## While not aiming, each star the next launch swallows wears two ember dots on its side toward the
## hole. The core supplies every destination. Never on the Big Bang's look: no freeze, silence,
## spiral or warm photon ring (its hole is C2-ringed and pulls stars round; this one is cool and they
## fall straight).
## A swallow (swallow_pixels, SWALLOW_TIME): the star's core pinches at the horizon, its light
## stretches in as a streak, the disc gulps a pixel wider, the ring flashes ember and two sparks race
## round it from the entry, and specks of sky dust fall straight in, dimming as they near the hole.
## Idle (playtest: it needed one; the user picked motes and infall together from a mock): motes orbit
## in a disc seen at a tilt, the inner ones faster, the far half passing behind the hole; and specks
## of sky dust drift straight in from round it, speeding up and dimming as they near it.
## Twin holes (the Legs): each drawn as the hole is. While nothing plays, their path shows: a dotted M3
## line between them and a dotted ghost ring where each will be after the next launch; when that
## launch merges them, one ember ghost ring (S3, S4 by turns) the merged hole's size where they meet,
## and the line in S3 (the countdown's last step: link before it). After a launch they slide along
## the path (SLIDE_TIME); merging, they slide together and go, and the Big Bang plays there, then the
## merged hole shows. The intro's forecast: the ghost rings step out along the path a launch at a
## time (FORECAST_STEP), the meeting point's ember ring last.
## The light gauge (the Head): a dotted ring GAUGE_GAP px outside the hole's, GAUGE_DOTS dots filling
## clockwise from the top in light's gold (C1, every fourth C0) over N5 for what's empty. A link's
## drunk light streams from the link into the hole (STREAM_TIME, gold dots) and the gauge fills as it
## arrives; the filling stream holds it full until the Big Bang. While a link that would fill it is
## traced, the gauge blinks ember (its gold S4 by turns, its empty dots S3). The intro streams a demo
## link's light in, holds, then the gauge drains back.

## The ring sits RING_GAP px outside the horizon; its bright arc spans ARC_DOTS dots of RING_DOTS and
## moves a dot on every ARC_STEP.
const RING_GAP: int = 2
const RING_DOTS: int = 32
const ARC_DOTS: int = 6
const ARC_STEP: float = 0.12
## A swallow flares the ring S4 until FLARE_HOT, then S3 until FLARE_TIME.
## (Short: the sparks race round the cool ring after it, and must show against it.)
const FLARE_HOT: float = 0.04
const FLARE_TIME: float = 0.1
const SWALLOW_TIME: float = 0.45
## The stretched star: STREAK_LENGTH px into the disc, shrinking to nothing by STREAK_TIME.
const STREAK_LENGTH: int = 6
const STREAK_TIME: float = 0.16
## The disc gulps a pixel wider over this window.
const GULP: Vector2 = Vector2(0.06, 0.18)
## Two sparks race round the ring from the entry, SPARK_SPEED rad/s, until SPARK_TIME.
const SPARK_SPEED: float = 9.0
const SPARK_TIME: float = 0.3
## Specks of sky dust: their angle off the entry (rad) and how far out they start (px past the ring).
const SPECKS: Array[Vector2] = [Vector2(-0.9, 14), Vector2(-0.45, 9), Vector2(0.0, 16), Vector2(0.4, 11), Vector2(0.85, 15), Vector2(1.3, 8)]
const SPECK_TIME: float = 0.4
## Idle motes: x px out from the horizon, y the starting angle (rad), z 1 for a dimmer mote. Each
## orbits in a disc flattened to DISC_TILT of its width, at MOTE_SPEED rad/s at MOTE_SPEED_AT px out
## and slower further out (Keplerian), trailing MOTE_TRAIL pixels MOTE_TRAIL_GAP seconds apart.
const MOTES: Array[Vector3] = [Vector3(5, 0.0, 0), Vector3(6, 3.3, 1), Vector3(7, 2.1, 1), Vector3(9, 4.0, 0), Vector3(12, 1.0, 1)]
const DISC_TILT: float = 0.42
const MOTE_SPEED: float = 2.6
const MOTE_SPEED_AT: float = 13.0
const MOTE_TRAIL: int = 3
const MOTE_TRAIL_GAP: float = 0.05
## Idle infall: INFALL_SPECKS specks, each falling in over INFALL_PERIOD from INFALL_FROM (+0-6) px out
## to the ring, at a fresh angle each time (a fixed hash, so the pattern is stable).
const INFALL_SPECKS: int = 5
const INFALL_PERIOD: float = 1.8
const INFALL_FROM: float = 22.0
## Twins slide to where they drifted over SLIDE_TIME; the path's dots are PATH_GAP px apart; a ghost
## ring has a dot every GHOST_GAP of RING_DOTS. The forecast shows a step every FORECAST_STEP, then
## holds FORECAST_HOLD.
const SLIDE_TIME: float = 0.4
const PATH_GAP: int = 4
const GHOST_GAP: int = 2
const FORECAST_STEP: float = 0.3
const FORECAST_HOLD: float = 0.9
const GAUGE_DOTS: int = 24
const GAUGE_GAP: int = 4
const STREAM_TIME: float = 0.45
const STREAM_DOTS: int = 5
const GAUGE_INTRO_HOLD: float = 0.9
const BLINK_STEP: float = 0.15

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
## A traced link would fill the light gauge: it blinks ember.
var tracing_fills: bool = false:
	set(value):
		if tracing_fills != value:
			tracing_fills = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
var _time: float = 0.0
## Swallows playing: the way each star came in from (a unit vector from its hole) and the seconds
## since, and the hole it fell into (as the core had it).
var _swallows: Array[Vector3] = []
var _swallow_holes: Array[Vector2i] = []
## The holes shown: a hungry hole grows in the core the moment a launch resolves, but on screen only
## as each swallow plays, and twins drift in the core at once but slide on screen once their launch
## has played; both catch up with the core once nothing is playing.
var _shown_centers: Array[Vector2i] = []
var _shown_horizons: Array[int] = []
## A slide playing: from and to, seconds since (-1: none), and whether it ends in a merge (the holes
## then go until the Big Bang has played).
var _slide_from: Array[Vector2i] = []
var _slide_to: Array[Vector2i] = []
var _slide_time: float = -1.0
var _slide_merges: bool = false
## The intro's forecast: each twin's path and the seconds since it began (-1: none).
var _forecast: Array = []
var _forecast_time: float = -1.0
## The gauge as shown (it fills as each stream arrives), and the streams playing: where each came
## from, the seconds since, and what the gauge shows once it arrives.
var _shown_absorbed: int = 0
var _stream_from: Array[Vector2i] = []
var _stream_time: Array[float] = []
var _stream_after: Array[int] = []
## The intro's gauge: held (-1: not playing) for this long once its stream has arrived.
var _gauge_intro_hold: float = -1.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_swallows.clear()
	_swallow_holes.clear()
	_slide_time = -1.0
	_forecast_time = -1.0
	_stream_from.clear()
	_stream_time.clear()
	_stream_after.clear()
	_gauge_intro_hold = -1.0
	tracing_fills = false
	_sync()
	set_process(run.gravity != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## The hole at `hole` swallowed a star that fell in from `from`: plays its swallow.
func flash_swallow(from: Vector2i, hole: Vector2i) -> void:
	var at: int = _shown_index(hole)
	var way: Vector2 = Vector2(from - _shown_centers[at]).normalized()
	_swallows.append(Vector3(way.x, way.y, 0.0))
	_swallow_holes.append(_shown_centers[at])
	_shown_horizons[at] = mini(_shown_horizons[at] + _run.gravity.hunger, _run.gravity.max_horizon)
	queue_redraw()


## The first hole's horizon as shown now (a hungry hole grows on screen as each swallow plays).
func shown_horizon() -> int:
	return _shown_horizons[0] if not _shown_horizons.is_empty() else 0


## Where the holes show now.
func shown_centers() -> Array[Vector2i]:
	return _shown_centers.duplicate()


## Twins drifted from `from` to `to` (merged: to one hole): they slide there; merging, they go.
func slide_holes(from: Array[Vector2i], to: Array[Vector2i], merges: bool) -> void:
	_slide_from = from.duplicate()
	_slide_to = to.duplicate()
	if merges:
		_slide_to = [to[0], to[0]]
	_slide_merges = merges
	_slide_time = 0.0
	queue_redraw()


## The intro's forecast of the twins' `paths` (launch by launch); returns how long it plays.
func play_forecast(paths: Array) -> float:
	_forecast = paths
	_forecast_time = 0.0
	queue_redraw()
	return forecast_length()


## How long the forecast plays.
func forecast_length() -> float:
	var steps: int = (_forecast[0] as Array).size() if not _forecast.is_empty() else 0
	return FORECAST_STEP * steps + FORECAST_HOLD


func is_sliding() -> bool:
	return _slide_time >= 0.0


## A link's `amount` of light streams from `from` into the hole; the gauge shows `absorbed` of
## `capacity` once it arrives (0 after that filled it: it holds full until the Big Bang). Returns how
## long it plays.
func absorb_light(from: Vector2i, amount: int, absorbed: int, capacity: int) -> float:
	_stream_from.append(from)
	_stream_time.append(0.0)
	_stream_after.append(capacity if absorbed == 0 and amount > 0 else absorbed)
	queue_redraw()
	return STREAM_TIME


## The intro: a demo link's `amount` streams in from `from`, holds, and drains. Returns how long.
func play_gauge_intro(from: Vector2i, amount: int) -> float:
	absorb_light(from, amount, amount, _run.gravity.capacity)
	_gauge_intro_hold = GAUGE_INTRO_HOLD
	return STREAM_TIME + GAUGE_INTRO_HOLD


## The gauge as shown now.
func shown_absorbed() -> int:
	return _shown_absorbed


func is_streaming() -> bool:
	return not _stream_time.is_empty()


## Whether a swallow is playing.
func is_swallowing() -> bool:
	return not _swallows.is_empty()


## Turns the ring and the swallows on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	if _slide_time >= 0.0:
		_slide_time += delta
		var k: float = minf(_slide_time / SLIDE_TIME, 1.0)
		var eased: float = k * k * (3.0 - 2.0 * k)
		_shown_centers.clear()
		for i: int in _slide_from.size():
			_shown_centers.append(Vector2i(Vector2(_slide_from[i]).lerp(Vector2(_slide_to[i]), eased).round()))
		if k >= 1.0:
			_slide_time = -1.0
			if _slide_merges:
				# Gone into the Big Bang; the merged hole shows once it has played.
				_shown_centers.clear()
				_shown_horizons.clear()
	if _forecast_time >= 0.0:
		_forecast_time += delta
		if _forecast_time >= forecast_length():
			_forecast_time = -1.0
	for i: int in range(_stream_time.size() - 1, -1, -1):
		_stream_time[i] += delta
		if _stream_time[i] >= STREAM_TIME:
			_shown_absorbed = _stream_after[i]
			_stream_from.remove_at(i)
			_stream_time.remove_at(i)
			_stream_after.remove_at(i)
	if _gauge_intro_hold >= 0.0 and _stream_time.is_empty():
		_gauge_intro_hold -= delta
		if _gauge_intro_hold < 0.0:
			_shown_absorbed = 0
	if _run != null and _run.gravity != null and _swallows.is_empty() and _slide_time < 0.0 and _stream_time.is_empty() and _gauge_intro_hold < 0.0 and (_sequencer == null or not _sequencer.is_busy()):
		_sync()
	for i: int in range(_swallows.size() - 1, -1, -1):
		_swallows[i].z += delta
		if _swallows[i].z >= SWALLOW_TIME:
			_swallows.remove_at(i)
			_swallow_holes.remove_at(i)


func _sync() -> void:
	_shown_centers.clear()
	_shown_horizons.clear()
	if _run != null and _run.gravity != null:
		_shown_centers = _run.gravity.centers.duplicate()
		_shown_horizons = _run.gravity.horizons.duplicate()
		_shown_absorbed = _run.gravity.absorbed


## The shown hole nearest `point`.
func _shown_index(point: Vector2i) -> int:
	var best: int = 0
	for i: int in _shown_centers.size():
		if point.distance_squared_to(_shown_centers[i]) < point.distance_squared_to(_shown_centers[best]):
			best = i
	return best


## Where a star swallowed by the hole at `hole` vanishes, on its way from `from`: the horizon's edge
## on its side.
func horizon_point(from: Vector2i, hole: Vector2i) -> Vector2i:
	if _shown_centers.is_empty():
		return hole
	var at: int = _shown_index(hole)
	var way: Vector2 = Vector2(from - _shown_centers[at]).normalized()
	return _shown_centers[at] + Vector2i((way * _shown_horizons[at]).round())


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.gravity == null:
		return result
	var hole: StarGravity = _run.gravity
	var busy: bool = _sequencer != null and _sequencer.is_busy()
	if hole.has_twins() and _shown_centers.size() > 1 and (not busy or _forecast_time >= 0.0) and _slide_time < 0.0:
		result.merge(path_pixels(_shown_centers, hole.next_centers(), _shown_horizons[0], hole.merges_next(), hole.merge_horizon, _time))
	if _forecast_time >= 0.0:
		result.merge(forecast_pixels(_forecast, _forecast_time, _shown_horizons[0] if not _shown_horizons.is_empty() else hole.horizon, hole.merge_horizon, _time), true)
	for i: int in _shown_centers.size():
		var center: Vector2i = _shown_centers[i]
		var horizon: int = _shown_horizons[i]
		var flare: float = -1.0
		for k: int in _swallows.size():
			if _swallow_holes[k] == center:
				flare = _swallows[k].z if flare < 0.0 else minf(flare, _swallows[k].z)
		result.merge(infall_pixels(center, horizon, _time + i * 0.7), true)
		result.merge(mote_pixels(center, horizon, _time + i * 1.3, false), true)
		result.merge(hole_pixels(center, horizon, _time + i * 0.5, flare), true)
		result.merge(mote_pixels(center, horizon, _time + i * 1.3, true), true)
	for k: int in _swallows.size():
		var at: int = _shown_index(_swallow_holes[k])
		if at < _shown_centers.size():
			result.merge(swallow_pixels(_shown_centers[at], _shown_horizons[at], Vector2(_swallows[k].x, _swallows[k].y), _swallows[k].z), true)
	if hole.has_gauge() and not _shown_centers.is_empty():
		var radius: int = _shown_horizons[0] + RING_GAP + GAUGE_GAP
		result.merge(gauge_pixels(_shown_centers[0], radius, float(_shown_absorbed) / hole.capacity, tracing_fills and not busy, _time), true)
		for i: int in _stream_time.size():
			result.merge(stream_pixels(_stream_from[i], _shown_centers[0], _stream_time[i] / STREAM_TIME), true)
	if busy:
		return result
	if not aiming:
		for id: int in _run.launch_swallows():
			var star: Star = _run.find_star(id)
			var way: Vector2 = Vector2(hole.centers[hole.nearest(star.position)] - star.position).normalized()
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
			for point: Vector2i in _trail(star.position, horizon_point(star.position, to), radius + 2):
				result[point] = Palette.S4
			continue
		for point: Vector2i in _trail(star.position, to, radius + 2):
			result[point] = Palette.M4
		for side: int in [-1, 1]:
			for dy: int in [-1, 0, 1]:
				result[to + Vector2i(side * radius, dy)] = Palette.M5
	return result


## The hole at `center`: an N0 disc of `horizon` px, then the ring RING_GAP px out in M4 with its
## M5/M6 arc orbiting `time` seconds in; a swallow `flare` seconds in (-1: none) flashes it ember, and
## over GULP the disc is a pixel wider.
static func hole_pixels(center: Vector2i, horizon: int, time: float, flare: float = -1.0) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var disc: int = horizon + (1 if flare >= GULP.x and flare < GULP.y else 0)
	for y: int in range(-disc, disc + 1):
		for x: int in range(-disc, disc + 1):
			if x * x + y * y <= disc * disc:
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
		if flare >= 0.0 and flare < FLARE_TIME:
			color = Palette.S4 if flare < FLARE_HOT else Palette.S3
		result[p] = color
	return result


## The twins' path: a dotted M3 line between the holes at `centers` (PATH_GAP apart, clear of the
## holes' rings), and a dotted ghost ring (M4, a dot every GHOST_GAP) at each of `next`; when the next
## launch `merges`, one ember ghost ring of `merge_horizon` where they meet, its dots S3 and S4 by turns
## (swapping every half second), and the line S3.
static func path_pixels(centers: Array[Vector2i], next: Array[Vector2i], horizon: int, merges: bool, merge_horizon: int, time: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if centers.size() < 2:
		return pixels
	var a := Vector2(centers[0])
	var b := Vector2(centers[1])
	var length: float = a.distance_to(b)
	var clear: float = horizon + RING_GAP + 2
	var d: float = clear
	while d < length - clear:
		pixels[Vector2i(a.lerp(b, d / length).round())] = Palette.S3 if merges else Palette.M3
		d += PATH_GAP
	if merges:
		var swap: int = int(time / 0.5) % 2
		for p: Vector2i in ghost_ring(next[0], merge_horizon + RING_GAP):
			var index: int = (p.x + p.y) % 2
			pixels[p] = Palette.S4 if index == swap else Palette.S3
	else:
		for at: Vector2i in next:
			for p: Vector2i in ghost_ring(at, horizon + RING_GAP):
				pixels[p] = Palette.M4
	return pixels


## The light gauge round `center` at `radius`: GAUGE_DOTS dots clockwise from the top, the first
## `filled` of them gold (C1, every fourth C0), the rest N5; `blinking` (a traced link would fill it),
## the gold ones S4 every other BLINK_STEP and the empty ones S3.
static func gauge_pixels(center: Vector2i, radius: int, filled: float, blinking: bool, time: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	var full: int = clampi(roundi(filled * GAUGE_DOTS), 0, GAUGE_DOTS)
	var hot: bool = blinking and int(time / BLINK_STEP) % 2 == 0
	for i: int in GAUGE_DOTS:
		var angle: float = -PI / 2.0 + i * TAU / GAUGE_DOTS
		var p: Vector2i = center + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round())
		if i < full:
			pixels[p] = Palette.S4 if hot else (Palette.C0 if i % 4 == 0 else Palette.C1)
		else:
			pixels[p] = Palette.S3 if blinking else Palette.N5
	return pixels


## A link's light streaming from `from` into the hole at `to`, `k` (0 to 1) of the way: STREAM_DOTS
## gold dots following each other in, speeding up.
static func stream_pixels(from: Vector2i, to: Vector2i, k: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	for i: int in STREAM_DOTS:
		var u: float = clampf(k * 1.4 - i * 0.1, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		pixels[Vector2i(Vector2(from).lerp(Vector2(to), u * u).round())] = Palette.C1 if i == 0 else Palette.C2
	return pixels


## A dotted ring of `radius` round `center` (a dot every GHOST_GAP of RING_DOTS).
static func ghost_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	for i: int in range(0, RING_DOTS, GHOST_GAP):
		var angle: float = i * TAU / RING_DOTS
		dots.append(center + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round()))
	return dots


## The intro's forecast `t` seconds in: along each twin's `paths`, a ghost ring at each launch's
## spot, one more every FORECAST_STEP; the last (where they meet) ember, the merged hole's size.
static func forecast_pixels(paths: Array, t: float, horizon: int, merge_horizon: int, time: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if paths.is_empty():
		return pixels
	var steps: int = (paths[0] as Array).size()
	var shown: int = mini(floori(t / FORECAST_STEP) + 1, steps)
	for path: Array in paths:
		for k: int in shown:
			var last: bool = k == steps - 1
			for p: Vector2i in ghost_ring(path[k], (merge_horizon if last else horizon) + RING_GAP):
				pixels[p] = (Palette.S4 if int(time / 0.5) % 2 == (p.x + p.y) % 2 else Palette.S3) if last else Palette.M4
	return pixels


## The idle disc's motes `time` seconds in: the near half (`front`, drawn over the hole) or the far
## half (drawn under it, so the hole hides what passes behind it).
static func mote_pixels(center: Vector2i, horizon: int, time: float, front: bool) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	for mote: Vector3 in MOTES:
		var r: float = horizon + mote.x
		var speed: float = MOTE_SPEED * pow(MOTE_SPEED_AT / r, 1.5)
		for trail: int in range(MOTE_TRAIL - 1, -1, -1):
			var angle: float = mote.y + speed * (time - trail * MOTE_TRAIL_GAP)
			if (sin(angle) > 0.0) != front:
				continue
			var color: Color = Palette.M3 if trail == MOTE_TRAIL - 1 else Palette.M4
			if trail == 0:
				color = Palette.M5 if mote.z > 0 else Palette.M6
			pixels[center + Vector2i(Vector2(cos(angle) * r, sin(angle) * r * DISC_TILT).round())] = color
	return pixels


## The idle infall `time` seconds in: specks of sky dust drifting straight in to the ring, speeding up
## and dimming (M6, M5, M4) as they near it.
static func infall_pixels(center: Vector2i, horizon: int, time: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	for slot: int in INFALL_SPECKS:
		var phase: float = time / INFALL_PERIOD + float(slot) / INFALL_SPECKS
		var cycle: int = floori(phase)
		var k: float = phase - cycle
		var h: int = absi(hash(Vector2i(slot, cycle))) % 360
		var r: float = lerpf(INFALL_FROM + h % 7, horizon + RING_GAP, k * k)
		pixels[center + Vector2i((Vector2.from_angle(deg_to_rad(h)) * r).round())] = Palette.M6 if k < 0.35 else Palette.M5 if k < 0.7 else Palette.M4
	return pixels


## A star swallowed `t` seconds ago, having fallen in from `way` (a unit vector from the hole): the
## pixels drawn over the hole and its ring (the ring's flash and the gulp are hole_pixels').
static func swallow_pixels(center: Vector2i, horizon: int, way: Vector2, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= SWALLOW_TIME:
		return pixels
	var entry: Vector2i = center + Vector2i((way * horizon).round())
	# Specks of sky dust fall straight in, speeding up, and dim as they near the hole (redshift).
	if t < SPECK_TIME:
		var k: float = t / SPECK_TIME
		for speck: Vector2 in SPECKS:
			var start: float = horizon + RING_GAP + speck.y
			var r: float = lerpf(start, float(horizon), k * k)
			var p: Vector2i = center + Vector2i((way.rotated(speck.x) * r).round())
			pixels[p] = Palette.M6 if k < 0.4 else Palette.M5 if k < 0.75 else Palette.M4
	# Two sparks race round the ring from the entry, both ways, once its flash has passed.
	if t >= FLARE_HOT and t < SPARK_TIME:
		var ring: float = horizon + RING_GAP
		for side: int in [-1, 1]:
			for trail: int in range(3, -1, -1):
				var angle: float = side * SPARK_SPEED * maxf(t - FLARE_HOT - trail * 0.02, 0.0)
				var at: Vector2 = way.rotated(angle)
				pixels[center + Vector2i((at * ring).round())] = Palette.S4 if trail == 0 else Palette.S3
				if trail == 0:
					# A 2 px head: it flares a pixel outward as it runs.
					pixels[center + Vector2i((at * (ring + 1)).round())] = Palette.S4
	# The star's light stretches into the disc, shrinking away.
	if t < STREAK_TIME:
		var length: int = roundi(STREAK_LENGTH * (1.0 - t / STREAK_TIME))
		for d: int in length:
			pixels[center + Vector2i((way * (horizon - 1 - d)).round())] = Palette.M6 if d < 2 else Palette.M5
	# Its white-hot core pinches to a point at the horizon and is gone.
	if t < 0.05:
		for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP * 2, Vector2i.DOWN * 2, Vector2i.LEFT * 2, Vector2i.RIGHT * 2] as Array[Vector2i]:
			pixels[entry + d] = Palette.C0 if d.length_squared() <= 1 else Palette.C1
	elif t < 0.1:
		pixels[entry] = Palette.C0
	return pixels


func _trail(from: Vector2i, to: Vector2i, skip: int) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var length: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step: int in range(skip, length + 1, 2):
		points.append(Vector2i((Vector2(from).lerp(Vector2(to), float(step) / length)).round()))
	return points
