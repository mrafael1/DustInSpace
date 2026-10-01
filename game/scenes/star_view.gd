class_name StarView
extends Node2D
## One star in the sky, drawn from the star art in assets/art/ (#12).
## Flies from its pack's burst point to the position the core gave it, then twinkles.
## Owns no rules: Sky tells it when to fly, dissolve, collapse or show as selected.
## The halo isn't drawn here: Sky paints every halo on a layer under all stars, so a newer
## star's halo can never cover an older star's rays. See `halo_dots()`.
## Every drawn pixel is a palette colour at an integer offset; the node sits on whole pixels.

signal settled(view: StarView)
signal dissolved(view: StarView)
## explode()'s wait is over: the star bursts now (flare, then gone). For sparks and sound.
signal exploded(view: StarView)
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
## The link hint: a star that could come next in the link being traced shows four corner brackets
## (the unlit landmarks' "you can pick this" cue) pulsing warm, C1 then C3, this long each, in step
## with every other hinted star and landmark (they all start together).
const HINT_PULSE: float = 0.3
const EASE_BACK: float = 1.70158
## Collapse: stars dim from here, and are swallowed from here to the end.
const REDSHIFT_AT: float = 0.5
const SWALLOW_AT: float = 0.85
## Share of the flight at which the ease-out-back overshoot peaks (about 0.58). Past it a star
## only drifts back by at most 10% of its flight, so linking it no longer feels wrong.
const OVERSHOOT_PEAK: float = 1.0 - 2.0 * EASE_BACK / (3.0 * (EASE_BACK + 1.0))

## The star art (assets/art/, built by tools/art/build_stars.py): one horizontal strip per
## Star.Size of square frames, in FRAMES order (the JSON sidecars name them), and a 2-frame
## dashed selection ring strip per size. Drawn at whole-pixel offsets, never scaled.
const SHEETS: Array[Texture2D] = [
	preload("res://assets/art/stars_small.png"),
	preload("res://assets/art/stars_medium.png"),
	preload("res://assets/art/stars_big.png"),
]
const RING_SHEETS: Array[Texture2D] = [
	preload("res://assets/art/selection_ring_small.png"),
	preload("res://assets/art/selection_ring_medium.png"),
	preload("res://assets/art/selection_ring_big.png"),
]
## Scorpio's landmarks (ConstellationView) use "idle" unlit, so they look like sky stars, and the
## gold "lit" and "lit_glint" frames once lit.
const FRAMES: Array[StringName] = [&"idle", &"glint", &"spark", &"flare", &"flare_core", &"fade_core", &"fade_dot", &"dim", &"dim_core", &"lit", &"lit_glint"]
## Which dissolve and collapse frames play, in order.
const DISSOLVE_SEQUENCE: Array[StringName] = [&"flare", &"flare_core", &"fade_core", &"fade_dot"]
const COLLAPSE_SEQUENCE: Array[StringName] = [&"glint", &"dim", &"dim_core"]
const HALO_RADIUS: Array[int] = [4, 8, 11]
## Halo colours per size, near then far: warm around the orange star, mauve around the mauve one,
## cool around the blue-white big star, so each star's colour stays clean.
const HALO_COLOURS: Array = [[Palette.C4, Palette.C5], [Palette.C5, Palette.N6], [Palette.M4, Palette.M3]]
## Ordered-dither thresholds (0-15) for the halo.
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var star_id: int = 0
var size: Star.Size = Star.Size.SMALL
var state: State = State.IDLE
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## The link hint: this star could come next in the link being traced (Sky sets it).
var hinted: bool = false:
	set(value):
		if value != hinted:
			_hint_time = 0.0
		hinted = value
		queue_redraw()

var _from: Vector2i = Vector2i.ZERO
var _to: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
## Seconds in the current state. Negative while a staggered flight waits to start.
var _time: float = 0.0
var _twinkle_phase: float = 0.0
## Seconds since the link hint started on this star.
var _hint_time: float = 0.0
var _frame_key: int = -1
## A pending collapse: where to, how long, and seconds until it starts (-1 for none).
var _collapse_point: Vector2i = Vector2i.ZERO
var _collapse_duration: float = 0.0
var _collapse_wait: float = -1.0
static var _masks: Dictionary = {}
## Turns the star swirls around the point while it falls in, and how far out it hangs.
var _collapse_swirl: float = 0.0
var _collapse_hover: int = 0
## Seconds left before explode() bursts the star, or -1 when it isn't waiting to.
var _explode_wait: float = -1.0
## explode() was called: waiting to burst, or bursting.
var _exploding: bool = false


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


## After `delay` seconds, bursts: emits exploded, then flares and vanishes like a dissolve.
## Scorpio's completion clears the sky this way.
func explode(delay: float = 0.0) -> void:
	selected = false
	_exploding = true
	if delay > 0.0:
		_explode_wait = delay
	else:
		_burst()


func is_exploding() -> bool:
	return _exploding


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
	if _explode_wait >= 0.0:
		_explode_wait -= delta
		if _explode_wait <= 0.0:
			# The part of this tick past the wait already counts toward the burst.
			var overshoot: float = -_explode_wait
			_explode_wait = -1.0
			_burst()
			delta = overshoot
	if _collapse_wait >= 0.0:
		_collapse_wait -= delta
		if _collapse_wait <= 0.0:
			# The part of this tick past the wait already counts toward the collapse.
			var overshoot: float = -_collapse_wait
			_collapse_wait = -1.0
			_start_collapse()
			delta = overshoot
	_time += delta
	_hint_time += delta
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
## Glow without blur: the size's near colour at 50% dither near the star, its far colour at about
## 20% further out (HALO_COLOURS).
func halo_dots() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var shows_halo: bool = state == State.IDLE or (state == State.DISSOLVING and _dissolve_frame() == 0)
	if not shows_halo:
		return dots
	var center := Vector2i(position)
	var halo: Dictionary[Vector2i, Color] = halo_pixels(size)
	for offset: Vector2i in halo:
		dots[center + offset] = halo[offset]
	return dots


## A settled star's halo of `star_size`, as offsets from its centre: HALO_COLOURS' near colour at
## 50% dither inside half the radius, the far one at about 20% out to HALO_RADIUS, never on the
## star's own pixels. Lit constellation stars wear it too, in their own `colours` (ConstellationView).
static func halo_pixels(star_size: Star.Size, colours: Array = []) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var radius: int = HALO_RADIUS[star_size]
	var near_far: Array = colours if not colours.is_empty() else HALO_COLOURS[star_size]
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var offset := Vector2i(dx, dy)
			var dist_sq: int = dx * dx + dy * dy
			if dist_sq > radius * radius or _is_star_pixel(star_size, offset):
				continue
			var threshold: int = BAYER[posmod(dy, 4) * 4 + posmod(dx, 4)]
			if dist_sq * 4 <= radius * radius:
				if threshold < 8:
					dots[offset] = near_far[0]
			elif threshold < 3:
				dots[offset] = near_far[1]
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
	return SHEETS[star_size].get_height() >> 1


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


func _burst() -> void:
	dissolve()
	exploded.emit(self)


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
	return int(_is_glinting()) + 2 * (_ring_frame() if selected else 0) + 4 * (int(hint_on(_hint_time)) + 1 if shows_hint() else 0)


func _is_spark() -> bool:
	return _time < SETTLE_TIME * SPARK_PART


func _is_glinting() -> bool:
	return fposmod(_time + _twinkle_phase, TWINKLE_PERIOD) < GLINT_TIME


## Whether this star shows the link hint's brackets: hinted, and not picked yet.
func shows_hint() -> bool:
	return hinted and not selected


## The colour of the link hint's brackets now: C1 while its pulse is on, C3 while off.
func hint_colour() -> Color:
	return Palette.C1 if hint_on(_hint_time) else Palette.C3


## Whether the link hint's pulse is lit `t` seconds after it started: lit first, then off, in turn.
static func hint_on(t: float) -> bool:
	return int(t / HINT_PULSE) % 2 == 0


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
	_draw_frame(&"spark" if _is_spark() else &"idle")


func _draw_idle() -> void:
	# A glint lifts every step one notch brighter for a moment.
	_draw_frame(&"glint" if _is_glinting() else &"idle")
	if selected:
		_draw_ring()
	elif shows_hint():
		var colour: Color = hint_colour()
		for p: Vector2i in ConstellationView.cue_pixels(size):
			draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)


func _draw_dissolve() -> void:
	_draw_frame(DISSOLVE_SEQUENCE[_dissolve_frame()])


## Pulled in bright, a step darker as it slows near the hole, then only a dim core.
func _draw_collapse() -> void:
	_draw_frame(COLLAPSE_SEQUENCE[_redshift()])


## One frame of this star's strip, centred on the node.
func _draw_frame(frame: StringName) -> void:
	var sheet: Texture2D = SHEETS[size]
	var w: int = sheet.get_height()
	var i: int = FRAMES.find(frame)
	draw_texture_rect_region(sheet, Rect2(Vector2(-(w >> 1), -(w >> 1)), Vector2(w, w)), Rect2(i * w, 0, w, w))


## The dashed C1 selection ring; its dashes swap every RING_FRAME_TIME.
func _draw_ring() -> void:
	var sheet: Texture2D = RING_SHEETS[size]
	var cell: int = sheet.get_height()
	draw_texture_rect_region(sheet, Rect2(Vector2(-(cell >> 1), -(cell >> 1)), Vector2(cell, cell)), Rect2(_ring_frame() * cell, 0, cell, cell))


## Whether the idle sprite covers `offset` (from the centre): the halo leaves those pixels alone.
func _is_shape_pixel(offset: Vector2i) -> bool:
	return _is_star_pixel(size, offset)


static func _is_star_pixel(star_size: Star.Size, offset: Vector2i) -> bool:
	var mask: Image = _idle_mask(star_size)
	var half: int = half_extent(star_size)
	var cell: Vector2i = offset + Vector2i(half, half)
	if cell.x < 0 or cell.y < 0 or cell.x >= mask.get_width() or cell.y >= mask.get_height():
		return false
	return mask.get_pixelv(cell).a > 0.0


## The idle frame's pixels, read once per size from its sheet.
static func _idle_mask(star_size: Star.Size) -> Image:
	if not _masks.has(star_size):
		var sheet: Image = SHEETS[star_size].get_image()
		var w: int = sheet.get_height()
		_masks[star_size] = sheet.get_region(Rect2i(0, 0, w, w))
	return _masks[star_size]


func _refresh() -> void:
	queue_redraw()
	halo_changed.emit(self)


func _half_extent() -> int:
	return half_extent(size)
