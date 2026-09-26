class_name StarView
extends Node2D
## One star in the sky, drawn from placeholder pixel maps until the star art lands (#12).
## Flies from its pack's burst point to the position the core gave it, then twinkles.
## Owns no rules: Sky tells it when to fly, dissolve, collapse or show as selected.
## The halo isn't drawn here: Sky paints every halo on a layer under all stars, so a newer
## star's halo can never cover an older star's rays. See `halo_dots()`.
## Every drawn pixel is a palette colour at an integer offset; the node sits on whole pixels.

signal settled(view: StarView)
signal dissolved(view: StarView)
## The halo appeared, changed or disappeared; whoever paints halos should redraw.
signal halo_changed(view: StarView)

enum State { SETTLING, IDLE, DISSOLVING, COLLAPSING }

## Burst timing from the game-feel skill: stars scatter with an ease-out-back.
const SETTLE_TIME: float = 0.65
## Share of the flight drawn as a bare core, so the star "grows" without scaling.
const SPARK_PART: float = 0.3
## Valid-link timing from the game-feel skill: flare white, hold, dissolve.
const DISSOLVE_TIME: float = 0.38
const DISSOLVE_FRAMES: int = 4
const TWINKLE_PERIOD: float = 2.4
const GLINT_TIME: float = 0.16
## Selection ring: 2-frame rotate.
const RING_FRAME_TIME: float = 0.2
const RING_GAP: int = 4
const RING_DASHES: int = 16
const EASE_BACK: float = 1.70158
## Collapse: stars dim from here, and are swallowed from here to the end.
const REDSHIFT_AT: float = 0.5
const SWALLOW_AT: float = 0.85
## Share of the flight at which the ease-out-back overshoot peaks (about 0.58). Past it a star
## only drifts back by at most 10% of its flight, so linking it no longer feels wrong.
const OVERSHOOT_PEAK: float = 1.0 - 2.0 * EASE_BACK / (3.0 * (EASE_BACK + 1.0))

## Pixel maps per Star.Size, centred. Digits are steps on STAR_STEPS (0 = C0 core), "." is empty.
const SHAPES: Array = [
	[
		"..2..",
		"..1..",
		"21012",
		"..1..",
		"..2..",
	],
	[
		".....3.....",
		".....2.....",
		".....1.....",
		"..3..1..3..",
		"...21012...",
		"32110001123",
		"...21012...",
		"..3..1..3..",
		".....1.....",
		".....2.....",
		".....3.....",
	],
	[
		".......3.......",
		".......2.......",
		".......2.......",
		"...3...1...3...",
		"....2..1..2....",
		"......111......",
		".....10001.....",
		"322111000111223",
		".....10001.....",
		"......111......",
		"....2..1..2....",
		"...3...1...3...",
		".......2.......",
		".......2.......",
		".......3.......",
	],
]
const HALO_RADIUS: Array[int] = [4, 8, 11]
const STAR_STEPS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
## Ordered-dither thresholds (0-15) for the halo.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var star_id: int = 0
var size: Star.Size = Star.Size.SMALL
var state: State = State.IDLE
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _from: Vector2i = Vector2i.ZERO
var _to: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
## Seconds in the current state. Negative while a staggered flight waits to start.
var _time: float = 0.0
var _twinkle_phase: float = 0.0
var _frame_key: int = -1
## A pending collapse: where to, how long, and seconds until it starts (-1 for none).
var _collapse_point: Vector2i = Vector2i.ZERO
var _collapse_duration: float = 0.0
var _collapse_wait: float = -1.0
## Turns the star swirls around the point while it falls in, and how far out it hangs.
var _collapse_swirl: float = 0.0
var _collapse_hover: int = 0


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	match state:
		State.SETTLING:
			_draw_settling()
		State.IDLE:
			_draw_idle()
		State.DISSOLVING:
			_draw_dissolve()
		State.COLLAPSING:
			_draw_collapse()


## Shows `star` settled at its position. `sky` is the run's sky rect; flights stay in its inner rect.
func setup(star: Star, sky: Rect2i) -> void:
	star_id = star.id
	size = star.size
	_to = star.position
	_bounds = StarScatter.inner_rect(sky)
	_twinkle_phase = fposmod(star.id * 0.618, 1.0) * TWINKLE_PERIOD
	_enter(State.IDLE)
	position = Vector2(_to)


## Flies from `start` to the star's position after `delay` seconds.
func fly_from(start: Vector2i, delay: float = 0.0) -> void:
	_from = start
	_enter(State.SETTLING)
	_time = -delay
	position = Vector2(flight_point(_from, _to, 0.0, _bounds))
	visible = delay <= 0.0


## Flares, then vanishes and frees itself.
func dissolve() -> void:
	selected = false
	_enter(State.DISSOLVING)
	visible = true


## After `delay` seconds (whatever it is doing then, even mid-flight), is pulled into `point`
## over `duration`, spiralling `swirl` turns on the way, then frees itself. It slows as it
## nears `hover` px from the point, hangs there dimming, and is swallowed at the very end
## (see collapse_point). The Big Bang's collapse into its black hole.
func collapse_to(point: Vector2i, delay: float, duration: float, swirl: float = 0.0, hover: int = 0) -> void:
	selected = false
	_collapse_point = point
	_collapse_duration = duration
	_collapse_swirl = swirl
	_collapse_hover = hover
	_collapse_wait = -1.0
	if delay > 0.0:
		_collapse_wait = delay
	else:
		_start_collapse()


func is_collapsing() -> bool:
	return state == State.COLLAPSING or _collapse_wait >= 0.0


## Moves the animation forward. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _collapse_wait >= 0.0:
		_collapse_wait -= delta
		if _collapse_wait <= 0.0:
			# The part of this tick past the wait already counts toward the collapse.
			var overshoot: float = -_collapse_wait
			_collapse_wait = -1.0
			_start_collapse()
			delta = overshoot
	_time += delta
	match state:
		State.SETTLING:
			_advance_flight()
		State.DISSOLVING:
			if _time >= DISSOLVE_TIME:
				dissolved.emit(self)
				queue_free()
				return
		State.COLLAPSING:
			var k: float = minf(_time / _collapse_duration, 1.0)
			position = Vector2(collapse_point(_from, _collapse_point, k, _collapse_swirl, _collapse_hover, _bounds))
			if k >= 1.0:
				dissolved.emit(self)
				queue_free()
				return
	_redraw_on_new_frame()


## Halo pixels in sky coordinates (the view's parent space), or none while the star flies.
## Glow without blur: C4 at 50% dither near the star, C5 at about 20% further out.
func halo_dots() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var shows_halo: bool = state == State.IDLE or (state == State.DISSOLVING and _dissolve_frame() == 0)
	if not shows_halo:
		return dots
	var center := Vector2i(position)
	var radius: int = HALO_RADIUS[size]
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var offset := Vector2i(dx, dy)
			var dist_sq: int = dx * dx + dy * dy
			if dist_sq > radius * radius or _is_shape_pixel(offset):
				continue
			var threshold: int = BAYER[posmod(dy, 4) * 4 + posmod(dx, 4)]
			if dist_sq * 4 <= radius * radius:
				if threshold < 8:
					dots[center + offset] = Palette.C4
			elif threshold < 3:
				dots[center + offset] = Palette.C5
	return dots


## Where a flying star is at progress `k` (0-1): eased out-back, rounded to a whole pixel,
## and clamped to `bounds` so the overshoot never carries a star out of the sky.
static func flight_point(from: Vector2i, to: Vector2i, k: float, bounds: Rect2i) -> Vector2i:
	var eased: float = _ease_out_back(clampf(k, 0.0, 1.0))
	var point := Vector2i(Vector2(from).lerp(Vector2(to), eased).round())
	return Vector2i(
		clampi(point.x, bounds.position.x, bounds.end.x - 1),
		clampi(point.y, bounds.position.y, bounds.end.y - 1),
	)


## How far a star's sprite reaches from its centre pixel, e.g. 7 for the 15x15 big star.
static func half_extent(star_size: Star.Size) -> int:
	return (SHAPES[star_size] as Array).size() >> 1


## Where a collapsing star is at progress `k` (0-1), on whole pixels. Like falling into a black
## hole: fast at first, then slower and slower as it nears `hover` px from `point` (an ease-out);
## from SWALLOW_AT it drops through to `point`. It orbits faster the closer it gets (the turn
## scales with hover / distance), so a far star falls nearly straight and swirls up to `swirl`
## turns near the hole. With `bounds`, the path is clamped inside them: a hole in a corner of
## the sky never swings a star off screen, and `point` itself must be inside them.
static func collapse_point(from: Vector2i, point: Vector2i, k: float, swirl: float, hover: int = 0, bounds: Rect2i = Rect2i()) -> Vector2i:
	var t: float = clampf(k, 0.0, 1.0)
	var start: float = Vector2(from - point).length()
	if start == 0.0:
		return point
	var edge: float = minf(float(hover), start)
	var dist: float = (edge + (start - edge) * (1.0 - t) * (1.0 - t)) * (1.0 - smoothstep(SWALLOW_AT, 1.0, t))
	var closeness: float = clampf(edge / maxf(dist, 1.0), 0.0, 1.0) if edge > 0.0 else 1.0
	var offset := Vector2(from - point).normalized().rotated(TAU * swirl * t * closeness) * dist
	var at: Vector2i = point + Vector2i(offset.round())
	if bounds.has_area():
		at = at.clamp(bounds.position, bounds.end - Vector2i.ONE)
	return at


static func _ease_out_back(k: float) -> float:
	var t: float = k - 1.0
	return 1.0 + (EASE_BACK + 1.0) * t * t * t + EASE_BACK * t * t


func _enter(next: State) -> void:
	state = next
	_time = 0.0
	_frame_key = -1
	_refresh()


func _advance_flight() -> void:
	if _time < 0.0:
		return
	visible = true
	var k: float = _time / SETTLE_TIME
	position = Vector2(flight_point(_from, _to, k, _bounds))
	if k >= 1.0:
		_enter(State.IDLE)
		settled.emit(self)


## Redraws only when the drawn frame changes, not every tick.
func _redraw_on_new_frame() -> void:
	var key: int = _current_frame_key()
	if key != _frame_key:
		_frame_key = key
		_refresh()


func _current_frame_key() -> int:
	match state:
		State.SETTLING:
			return 1 if _is_spark() else 2
		State.DISSOLVING:
			return _dissolve_frame()
		State.COLLAPSING:
			return _redshift()
	return int(_is_glinting()) + 2 * (_ring_frame() if selected else 0)


func _is_spark() -> bool:
	return _time < SETTLE_TIME * SPARK_PART


func _is_glinting() -> bool:
	return fposmod(_time + _twinkle_phase, TWINKLE_PERIOD) < GLINT_TIME


func _ring_frame() -> int:
	return int(_time / RING_FRAME_TIME) % 2


## How far a collapsing star has dimmed: 0 bright while it falls, 1 a step darker as it slows
## near the hole, 2 only a dim C3 core while it is swallowed. Light losing energy on its way out.
func _redshift() -> int:
	var k: float = _time / _collapse_duration
	if k >= SWALLOW_AT:
		return 2
	return 1 if k >= REDSHIFT_AT else 0


func _start_collapse() -> void:
	_from = Vector2i(position)
	_enter(State.COLLAPSING)
	visible = true


func _dissolve_frame() -> int:
	return mini(int(_time / DISSOLVE_TIME * DISSOLVE_FRAMES), DISSOLVE_FRAMES - 1)


func _draw_settling() -> void:
	if _is_spark():
		_draw_shape(0, 0)
	else:
		_draw_shape(STAR_STEPS.size() - 1, 0)


func _draw_idle() -> void:
	# A glint lifts every step one notch brighter for a moment.
	_draw_shape(STAR_STEPS.size() - 1, -1 if _is_glinting() else 0)
	if selected:
		_draw_ring()


## Flare white (the halo stays for this frame), shrink to the bright core, then to one pixel.
func _draw_dissolve() -> void:
	match _dissolve_frame():
		0:
			_draw_shape(STAR_STEPS.size() - 1, -STAR_STEPS.size())
		1:
			_draw_shape(1, -STAR_STEPS.size())
		2:
			_draw_shape(0, 1)
		_:
			_dot(Vector2i.ZERO, Palette.C1)


## Pulled in bright; crushed down to the C0 core near the end.
func _draw_collapse() -> void:
	match _redshift():
		0:
			_draw_shape(STAR_STEPS.size() - 1, -1)
		1:
			_draw_shape(STAR_STEPS.size() - 1, 1)
		_:
			_draw_shape(0, STAR_STEPS.size() - 1)


## Draws the pixels whose step is at most `max_step`, shifted by `shift` steps (negative = brighter).
func _draw_shape(max_step: int, shift: int) -> void:
	var rows: Array = SHAPES[size]
	var half: int = _half_extent()
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == ".":
				continue
			var step: int = int(row[x])
			if step <= max_step:
				_dot(Vector2i(x - half, y - half), STAR_STEPS[clampi(step + shift, 0, STAR_STEPS.size() - 1)])


## Dashed C1 circle at the star's radius + RING_GAP; the dashes swap every RING_FRAME_TIME.
func _draw_ring() -> void:
	var radius: int = _half_extent() + RING_GAP
	var frame: int = _ring_frame()
	for dy: int in range(-radius - 1, radius + 2):
		for dx: int in range(-radius - 1, radius + 2):
			if roundi(sqrt(float(dx * dx + dy * dy))) != radius:
				continue
			var dash: int = int((atan2(dy, dx) + PI) / TAU * RING_DASHES) % RING_DASHES
			if (dash + frame) % 2 == 0:
				_dot(Vector2i(dx, dy), Palette.C1)


func _is_shape_pixel(offset: Vector2i) -> bool:
	var rows: Array = SHAPES[size]
	var half: int = _half_extent()
	var cell: Vector2i = offset + Vector2i(half, half)
	if cell.x < 0 or cell.y < 0 or cell.y >= rows.size() or cell.x >= (rows[cell.y] as String).length():
		return false
	return (rows[cell.y] as String)[cell.x] != "."


func _refresh() -> void:
	queue_redraw()
	halo_changed.emit(self)


func _half_extent() -> int:
	return half_extent(size)


func _dot(offset: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(offset), Vector2.ONE), color)
