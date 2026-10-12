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

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
var _time: float = 0.0
## Swallows playing: the way each star came in from (a unit vector from the hole) and the seconds since.
var _swallows: Array[Vector3] = []


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_swallows.clear()
	set_process(run.gravity != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## The hole swallowed a star that fell in from `from`: plays its swallow.
func flash_swallow(from: Vector2i) -> void:
	var way: Vector2 = Vector2(from - _run.gravity.center).normalized()
	_swallows.append(Vector3(way.x, way.y, 0.0))
	queue_redraw()


## Whether a swallow is playing.
func is_swallowing() -> bool:
	return not _swallows.is_empty()


## Turns the ring and the swallows on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	for i: int in range(_swallows.size() - 1, -1, -1):
		_swallows[i].z += delta
		if _swallows[i].z >= SWALLOW_TIME:
			_swallows.remove_at(i)


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
	var flare: float = -1.0
	for swallow: Vector3 in _swallows:
		flare = swallow.z if flare < 0.0 else minf(flare, swallow.z)
	result.merge(infall_pixels(hole.center, hole.horizon, _time))
	result.merge(mote_pixels(hole.center, hole.horizon, _time, false), true)
	result.merge(hole_pixels(hole.center, hole.horizon, _time, flare), true)
	result.merge(mote_pixels(hole.center, hole.horizon, _time, true), true)
	for swallow: Vector3 in _swallows:
		result.merge(swallow_pixels(hole.center, hole.horizon, Vector2(swallow.x, swallow.y), swallow.z), true)
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
