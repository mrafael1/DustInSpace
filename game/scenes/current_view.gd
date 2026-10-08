class_name CurrentView
extends Node2D
## Flowing water behind stars (cool streaks gliding downstream), with an ember line where a
## draining flow loses stars, and each star's extinction where it goes (extinction_pixels).
## Destination brackets appear only while aiming, and an ember trail from a star that would drain;
## random pack contents stay hidden. The core supplies every destination.

## The water: streaks gliding downstream in whole pixels, one per STREAK_AREA px² of the field,
## each STREAK_LENGTH long at STREAK_SPEED px/s (both by a fixed hash, so the pattern is stable).
## Leading pixel M5, then M4, then the M3 tail.
const STREAK_AREA: int = 900
const STREAK_LENGTH := Vector2i(4, 9)
const STREAK_SPEED := Vector2i(10, 18)
## A drained star's extinction where it crossed the drain, DRAIN_TIME long, in hard steps: its
## white-hot core pinches to a point, the line flares (C2, then S4) and narrows, ember sparks race
## up and down the line, and water droplets splash back upstream and fall away.
const DRAIN_TIME: float = 0.42
## The line's flare: until x seconds, y px either side, in FLARE_COLOURS[z].
const FLARE_STEPS: Array[Vector3] = [Vector3(0.05, 10, 0), Vector3(0.15, 10, 1), Vector3(0.25, 6, 1), Vector3(0.32, 2, 2)]
const FLARE_COLOURS: Array[Color] = [Palette.C2, Palette.S4, Palette.S3]
const SPARKS: int = 6
const SPARK_SPEED := Vector2(70.0, 150.0)
const SPARK_TIME: float = 0.35
const DROPLET_SPREAD: Array[float] = [-0.9, -0.45, 0.0, 0.45, 0.9]
const DROPLET_SPEED := Vector2(40.0, 66.0)
const DROPLET_FALL: float = 160.0
const DROPLET_TIME: float = 0.4

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
## A turning flow points at the edge its next launch drains to: CHEVRONS ember chevrons along it,
## CHEVRON_IN px inside the field (#128: which way it goes must read before the launch).
const CHEVRONS: int = 3
const CHEVRON_IN: int = 3
## A chevron keeps this far from any loose star's centre (a big star's sprite reaches ~7 px).
const CHEVRON_CLEAR: int = 10
## A box of drains (four ways or more) comes alight as its stage opens: each side flares solid in
## the order the flow will take them, ARRIVAL_STEP apart, then settles.
const ARRIVAL_STEP: float = 0.22

## Extinctions playing: the edge point each star left by, and the seconds since.
var _flashes: Dictionary[Vector2i, float] = {}
## The way each of those stars was flowing when it went.
var _flash_ways: Dictionary[Vector2i, Vector2i] = {}
## Seconds the water has flowed.
var _time: float = 0.0
## Seconds since a box of drains began coming alight (-1: not, or done).
var _arrival: float = -1.0
## The flow the water and drains show. A turning flow turns in the core the moment a launch
## resolves; the view turns only once that launch has played out (its burst and drift), so the
## water never changes way under stars still moving the old way.
var _shown_flow: Vector2i = Vector2i.ZERO


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_flashes.clear()
	_flash_ways.clear()
	_shown_flow = run.current.displacement if run.current != null else Vector2i.ZERO
	_arrival = 0.0 if run.current != null and run.current.turns.size() >= 4 else -1.0
	set_process(run.current != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	# Core positions change instantly; hide the preview until their views catch up.
	queue_redraw()


## Plays a star's extinction where it crossed the drain, at `at` (the edge point it left by).
## `way`: the way it was flowing (a turning flow may already have turned; ZERO: the flow's now).
func flash_drain(at: Vector2i, way: Vector2i = Vector2i.ZERO) -> void:
	_flashes[at] = 0.0
	_flash_ways[at] = way
	queue_redraw()


## Moves the water and the extinctions on, and turns the shown flow once the launch has played
## out. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	if _arrival >= 0.0:
		_arrival += delta
		if _arrival >= ARRIVAL_STEP * (_run.current.turns.size() + 1):
			_arrival = -1.0
	if _run != null and _run.current != null and _sequencer != null and not _sequencer.is_busy():
		_shown_flow = _run.current.displacement
	for at: Vector2i in _flashes.keys():
		_flashes[at] += delta
		if _flashes[at] >= DRAIN_TIME:
			_flashes.erase(at)
			_flash_ways.erase(at)


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


## The run is over and everything it queued has been seen: the last launch's burst and drift, and
## any extinction still flaring. The core ends a run the moment a losing launch resolves; its drains
## still play out after that, so the field stays until then.
func _played_out() -> bool:
	return _run.is_over() and (_sequencer == null or not _sequencer.is_busy()) and _flashes.is_empty()


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.current == null or _played_out():
		return result
	var area: Rect2i = _run.current.region
	result.merge(water_pixels(area, _shown_flow, _time))
	if _run.current.drains:
		# Every side the flow can drain to: the next launch's in ember, any other dimmer.
		var now := Vector2i(signi(_shown_flow.x), signi(_shown_flow.y))
		for way: Vector2i in _run.current.ways():
			if way == now:
				continue
			for point: Vector2i in _drain_edge(area, way):
				result[point] = Palette.S2
		for point: Vector2i in _drain_edge(area, now):
			result[point] = Palette.S3
		if _run.current.turns.size() > 1:
			var stars: Array[Vector2i] = []
			for star: Star in _run.stars:
				stars.append(star.position)
			result.merge(chevron_pixels(area, now, stars), true)
		if is_arriving():
			for k: int in _run.current.turns.size():
				if _arrival >= ARRIVAL_STEP * k:
					for point: Vector2i in _solid_edge(area, _run.current.turns[k]):
						result[point] = Palette.S4 if _arrival < ARRIVAL_STEP * (k + 1) else Palette.S3
		for at: Vector2i in _flashes:
			var went: Vector2i = _flash_ways.get(at, Vector2i.ZERO)
			result.merge(extinction_pixels(at, went if went != Vector2i.ZERO else _shown_flow, _flashes[at], area), true)
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


## A drained star's extinction `t` seconds after it reached the drain at `at` (flowing along
## `flow`): the pixels to draw over the line, kept within a few px of `area` across the line.
static func extinction_pixels(at: Vector2i, flow: Vector2i, t: float, area: Rect2i) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= DRAIN_TIME:
		return pixels
	var along := Vector2i(signi(flow.x), signi(flow.y))
	var line := Vector2i(absi(along.y), absi(along.x))
	var edge: Vector2i = at - along
	# The line flares where it went, then narrows.
	for flare: Vector3 in FLARE_STEPS:
		if t < flare.x:
			for offset: int in range(-int(flare.y), int(flare.y) + 1):
				pixels[edge + line * offset] = FLARE_COLOURS[int(flare.z)]
			break
	# Ember sparks race both ways along the line, easing out.
	if t < SPARK_TIME:
		for i: int in SPARKS:
			var speed: float = lerpf(SPARK_SPEED.x, SPARK_SPEED.y, float(i) / (SPARKS - 1))
			var reach: float = speed * t * (1.0 - t / (2.0 * SPARK_TIME))
			var side: int = 1 if i % 2 == 0 else -1
			var spark: Vector2i = edge + line * side * roundi(reach) - along * (i % 3 - 1)
			pixels[spark] = Palette.S4 if t < SPARK_TIME * 0.6 else Palette.S3
	# Water splashes back upstream and falls.
	if t < DROPLET_TIME:
		for i: int in DROPLET_SPREAD.size():
			var speed: float = lerpf(DROPLET_SPEED.x, DROPLET_SPEED.y, float(i) / (DROPLET_SPREAD.size() - 1))
			var velocity: Vector2 = Vector2(-along) * speed + Vector2(line) * DROPLET_SPREAD[i] * speed
			var drop: Vector2 = Vector2(edge) + velocity * t + Vector2(0.0, DROPLET_FALL) * t * t * 0.5
			pixels[Vector2i(drop.round())] = Palette.M5 if t < DROPLET_TIME * 0.5 else Palette.M4
	# The star's white-hot core pinches to a point and is gone.
	if t < 0.05:
		for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP * 2, Vector2i.DOWN * 2, Vector2i.LEFT * 2, Vector2i.RIGHT * 2] as Array[Vector2i]:
			pixels[at + d] = Palette.C0 if d.length_squared() <= 1 else Palette.C1
	elif t < 0.1:
		pixels[at] = Palette.C0
	var kept: Dictionary[Vector2i, Color] = {}
	var span: Rect2i = area.grow_individual(4, 0, 4, 0) if line.y != 0 else area.grow_individual(0, 4, 0, 4)
	for p: Vector2i in pixels:
		if span.has_point(p):
			kept[p] = pixels[p]
	return kept


## A box of drains is coming alight (its sides flaring in turn).
func is_arriving() -> bool:
	return _arrival >= 0.0


## Ember chevrons just inside the edge a flow running `way` drains to, pointing at it. Each slides
## along the edge to the nearest spot clear of `stars` (#128: on a crowded board stars hid them).
static func chevron_pixels(area: Rect2i, way: Vector2i, stars: Array[Vector2i] = []) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	var line := Vector2i(absi(way.y), absi(way.x))
	var edge: Array[Vector2i] = _drain_edge(area, way)
	if edge.is_empty():
		return pixels
	var first: Vector2i = edge[0]
	var span: int = area.size.y if way.x != 0 else area.size.x
	for k: int in CHEVRONS:
		var along: int = span * (k + 1) / (CHEVRONS + 1)
		var tip: Vector2i = first + line * along - way * CHEVRON_IN
		for slide: int in [0, 4, -4, 8, -8, 12, -12, 16, -16, 20, -20, 24, -24]:
			var spot: Vector2i = tip + line * slide
			if stars.all(func(at: Vector2i) -> bool: return at.distance_squared_to(spot - way * 1) > CHEVRON_CLEAR * CHEVRON_CLEAR):
				tip = spot
				break
		for d: int in 3:
			pixels[tip - way * d + line * d] = Palette.S4
			pixels[tip - way * d - line * d] = Palette.S4
	return pixels


## Every pixel of the side a flow running `way` drains to.
static func _solid_edge(area: Rect2i, way: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	if way.x != 0:
		var x: int = area.position.x if way.x < 0 else area.end.x - 1
		for y: int in range(area.position.y, area.end.y):
			points.append(Vector2i(x, y))
	else:
		var y: int = area.position.y if way.y < 0 else area.end.y - 1
		for x: int in range(area.position.x, area.end.x):
			points.append(Vector2i(x, y))
	return points


## The field's downstream side, where the flow drains: an ember dotted line, one dot in two.
static func _drain_edge(area: Rect2i, flow: Vector2i) -> Array[Vector2i]:
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
