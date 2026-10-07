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
## A draining current carried it to the field's edge (drain_to): it's gone, and frees itself.
signal drained(view: StarView)

enum State { SETTLING, IDLE, DISSOLVING, COLLAPSING, DRIFTING }

const DRIFT_TIME: float = 0.3
## The heat (Leo) changes a star's size in hard steps, in two beats. Charging (until RESIZE_FLARE):
## at its old size it flickers and trembles a pixel side to side; growing, four ember sparks close
## in on it along the diagonals; shrinking, a frost ring tightens round it. The pop: its new size
## flares (RESIZE_POP) as it hops a pixel up (grows) or sinks a pixel (shrinks). Then, until
## RESIZE_TIME, a growing star glints while a dotted ring in its new size's colour bursts out and
## four sparks fly off its tips; a shrinking one settles dim while frost crumbs fall from where its
## old edge was.
const RESIZE_FLARE: float = 0.12
const RESIZE_POP: float = 0.05
const RESIZE_TIME: float = 0.42
## Steps of the tremble and of the rings, in seconds.
const RESIZE_STEP: float = 0.04
## The ring a growing star bursts with, in its new size's own tip colour (small, medium, big).
const RESIZE_RING_COLOURS: Array[Color] = [Palette.C3, Palette.N8, Palette.M5]

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
## The link hint: while a link is traced, a star that could come next keeps its normal sprite and
## halo and shines once every HINT_PERIOD, in step with every other hinted star and landmark (they
## all start together): its glint frame, with rays shooting out of its four tips, SHINE_RAYS px
## long for SHINE_STEP each, then gone. The other stars dim (`dimmed`), so no marker is needed and
## the still frame already reads.
const HINT_PERIOD: float = 0.8
const SHINE_STEP: float = 0.12
const SHINE_RAYS: Array[int] = [2, 1]
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
		_refresh()
## The link hint: a link is being traced and this star can't come next in it, so it shows its
## "dim" frame (a step darker on its own colour chain) and no halo (Sky sets it).
var dimmed: bool = false:
	set(value):
		dimmed = value
		_refresh()

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
## drain_to: the drift ends the star.
var _draining: bool = false
var _explode_wait: float = -1.0
## explode() was called: waiting to burst, or bursting.
var _exploding: bool = false
## The size resize_to() is changing it to (-1: none), and seconds since it began.
var _resize_to: int = -1
var _resize_time: float = -1.0
## The size it was before the resize, and whether it shrinks.
var _resize_from: int = -1
var _resize_shrinks: bool = false


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	match state:
		State.SETTLING:
			_draw_settling()
		State.IDLE, State.DRIFTING:
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


## A current moves the intact star, in whole-pixel steps, without another burst.
func drift_to(destination: Vector2i) -> void:
	_from = Vector2i(position)
	_to = destination
	_draining = false
	_enter(State.DRIFTING)


## A draining current: drifts like drift_to to `edge`, where the field ends, then cuts out at once
## (a hard cut, no flare: it's lost, not collected).
func drain_to(edge: Vector2i) -> void:
	drift_to(edge)
	selected = false
	_draining = true


## The heat changes its size where it stands: it charges at its old size, then pops to the new one
## (RESIZE_FLARE's timeline).
func resize_to(new_size: Star.Size) -> void:
	_resize_from = size
	_resize_shrinks = new_size < size
	_resize_to = new_size
	_resize_time = 0.0
	_refresh()


## A star the heat burns out (or the cold fades) charges as a resizing one does, then explode()
## takes it at RESIZE_FLARE: embers closing in, or frost (`cold`).
func charge(cold: bool) -> void:
	_resize_from = size
	_resize_shrinks = cold
	_resize_to = size
	_resize_time = 0.0
	_refresh()


func is_resizing() -> bool:
	return _resize_time >= 0.0


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
	_advance_resize(delta)
	match state:
		State.DRIFTING:
			var k: float = minf(_time / DRIFT_TIME, 1.0)
			position = Vector2(Vector2i(Vector2(_from).lerp(Vector2(_to), k * k * (3.0 - 2.0 * k)).round()))
			_refresh()
			if k >= 1.0 and _draining:
				visible = false
				drained.emit(self)
				queue_free()
			elif k >= 1.0:
				_enter(State.IDLE)
				settled.emit(self)
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
	var shows_halo: bool = state == State.IDLE or state == State.DRIFTING or (state == State.DISSOLVING and _dissolve_frame() == 0)
	if not shows_halo or (dimmed and state == State.IDLE):
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


func _advance_resize(delta: float) -> void:
	if _resize_time < 0.0:
		return
	_resize_time += delta
	if _resize_to >= 0 and _resize_time >= RESIZE_FLARE:
		size = _resize_to as Star.Size
		_resize_to = -1
		_refresh()
	elif _resize_time >= RESIZE_TIME:
		_resize_time = -1.0
		_refresh()


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
	# Every resize step redraws (the tremble, the rings and sparks move in RESIZE_STEPs).
	var resizing: int = 0 if _resize_time < 0.0 else 1 + floori(_resize_time / RESIZE_STEP * 2.0)
	return int(_is_glinting()) + 2 * (_ring_frame() if selected else 0) + 4 * (shine_stage(_hint_time) + 2 if shows_hint() else 0) + 64 * resizing


func _is_spark() -> bool:
	return _time < SETTLE_TIME * SPARK_PART


func _is_glinting() -> bool:
	return fposmod(_time + _twinkle_phase, TWINKLE_PERIOD) < GLINT_TIME


## Whether this star shows the link hint's shine: hinted, and not picked yet.
func shows_hint() -> bool:
	return hinted and not selected


## The step of the link hint's shine this star shows now (an index into SHINE_RAYS), or -1.
func shine() -> int:
	return shine_stage(_hint_time) if shows_hint() else -1


## The step of the link hint's shine `t` seconds after it started (an index into SHINE_RAYS), or
## -1 between shines. It shines at once, then every HINT_PERIOD.
static func shine_stage(t: float) -> int:
	var stage: int = int(fposmod(t, HINT_PERIOD) / SHINE_STEP)
	return stage if stage < SHINE_RAYS.size() else -1


## The shine's rays at `stage` for a star of `star_size`, as offsets from its centre: straight on
## from its four tips, C0 next to the star and C1 beyond.
static func shine_pixels(star_size: Star.Size, stage: int) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if stage < 0:
		return dots
	var tip: int = half_extent(star_size)
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for k: int in range(1, SHINE_RAYS[stage] + 1):
			dots[dir * (tip + k)] = Palette.C0 if k == 1 else Palette.C1
	return dots


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
	# A glint lifts every step one notch brighter for a moment; a dimmed star doesn't twinkle.
	if _resize_time >= 0.0:
		_draw_frame(resize_frame(_resize_time, _resize_shrinks), resize_offset(_resize_time, _resize_shrinks))
		var extra: Dictionary[Vector2i, Color] = resize_pixels(_resize_from as Star.Size, size if _resize_to < 0 else _resize_to as Star.Size, _resize_time, _resize_shrinks)
		for p: Vector2i in extra:
			draw_rect(Rect2(Vector2(p), Vector2.ONE), extra[p])
	elif dimmed:
		_draw_frame(&"dim")
	else:
		_draw_frame(&"glint" if _is_glinting() or shine() >= 0 else &"idle")
	var rays: Dictionary[Vector2i, Color] = shine_pixels(size, shine())
	for p: Vector2i in rays:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), rays[p])
	if selected:
		_draw_ring()


func _draw_dissolve() -> void:
	_draw_frame(DISSOLVE_SEQUENCE[_dissolve_frame()])


## Pulled in bright, a step darker as it slows near the hole, then only a dim core.
func _draw_collapse() -> void:
	_draw_frame(COLLAPSE_SEQUENCE[_redshift()])


## One frame of this star's strip, centred on the node (`offset` whole pixels away).
func _draw_frame(frame: StringName, offset: Vector2i = Vector2i.ZERO) -> void:
	var sheet: Texture2D = SHEETS[size]
	var w: int = sheet.get_height()
	var i: int = FRAMES.find(frame)
	draw_texture_rect_region(sheet, Rect2(Vector2(offset - Vector2i(w >> 1, w >> 1)), Vector2(w, w)), Rect2(i * w, 0, w, w))


## The frame a resizing star shows `t` seconds in: charging it flickers (flare and glint growing,
## flare and dim shrinking), it pops on a flare, then glints (grown) or settles dim (shrunk).
static func resize_frame(t: float, shrinks: bool) -> StringName:
	if t < RESIZE_FLARE:
		var lit: bool = floori(t / RESIZE_STEP) % 2 == 0
		return &"flare" if lit else (&"dim" if shrinks else &"glint")
	if t < RESIZE_FLARE + RESIZE_POP:
		return &"flare"
	return &"dim" if shrinks else &"glint"


## Where a resizing star is drawn `t` seconds in, from its place: it trembles a pixel side to side
## while charging, then hops a pixel up as it grows or sinks one as it shrinks, for RESIZE_POP * 2.
static func resize_offset(t: float, shrinks: bool) -> Vector2i:
	if t < RESIZE_FLARE:
		return [Vector2i.RIGHT, Vector2i.ZERO, Vector2i.LEFT, Vector2i.ZERO][floori(t / (RESIZE_STEP * 0.5)) % 4]
	if t < RESIZE_FLARE + RESIZE_POP * 2.0:
		return Vector2i.DOWN if shrinks else Vector2i.UP
	return Vector2i.ZERO


## What a star resizing from `from` to `to` (`shrinks`: in the cold) adds round itself `t` seconds in, as offsets from its
## centre: the charge's converging ember sparks (growing) or tightening frost ring (shrinking), then
## the burst ring and flying sparks (grown) or falling frost crumbs (shrunk). Hard steps only.
static func resize_pixels(from: Star.Size, to: Star.Size, t: float, shrinks: bool) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= RESIZE_TIME:
		return pixels
	var step: int = floori(t / RESIZE_STEP)
	if t < RESIZE_FLARE:
		var steps: int = maxi(1, ceili(RESIZE_FLARE / RESIZE_STEP))
		if shrinks:
			# Frost closing in: a dotted ring from 5 px out down to 1.
			var radius: int = half_extent(from) + 5 - roundi(4.0 * step / steps)
			for p: Vector2i in ConstellationView.circle_pixels(radius):
				if (p.x + p.y) % 2 == 0:
					pixels[p] = Palette.M6
		else:
			# Embers drawn in along the diagonals: a hot gold head, ember pixels trailing it.
			var k: int = half_extent(from) / 2 + 5 - roundi(3.0 * step / steps)
			for d: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				pixels[d * k] = Palette.C2
				pixels[d * (k + 1)] = Palette.S4
				pixels[d * (k + 2)] = Palette.S3
		return pixels
	var after: float = t - RESIZE_FLARE
	var k: float = after / (RESIZE_TIME - RESIZE_FLARE)
	if shrinks:
		# Crumbs fall from the old edge, drifting out a little, M6 then M5.
		var edge: int = half_extent(from)
		var crumbs: Array[Vector2i] = [Vector2i(-edge, 0), Vector2i(edge, 0), Vector2i(-edge / 2, edge / 2), Vector2i(edge / 2, edge / 2), Vector2i(-edge / 2, -edge / 2), Vector2i(edge / 2, -edge / 2)]
		for c: Vector2i in crumbs:
			var fall := Vector2i(signi(c.x) * roundi(2.0 * k), roundi(9.0 * k * k) + 1)
			pixels[c + fall] = Palette.M6 if k < 0.5 else Palette.M5
		return pixels
	# A dotted ring bursts out in three steps from just past the new size, in its colour.
	var ring_steps: int = floori(after / RESIZE_STEP)
	if ring_steps < 3:
		for p: Vector2i in ConstellationView.circle_pixels(half_extent(to) + 2 + ring_steps * 2):
			if (p.x + p.y) % 2 == 0:
				pixels[p] = RESIZE_RING_COLOURS[to]
	# Sparks fly off its four tips, white-gold, then its colour.
	var reach: int = half_extent(to) + 2 + roundi(7.0 * k)
	for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		pixels[d * reach] = Palette.C1 if k < 0.5 else RESIZE_RING_COLOURS[to]
	return pixels



## The dashed C1 selection ring; its dashes swap every RING_FRAME_TIME.
func _draw_ring() -> void:
	var sheet: Texture2D = RING_SHEETS[size]
	var cell: int = sheet.get_height()
	draw_texture_rect_region(sheet, Rect2(Vector2(-(cell >> 1), -(cell >> 1)), Vector2(cell, cell)), Rect2(_ring_frame() * cell, 0, cell, cell))


## The ring of pixels just outside a star of `star_size` (4-neighbours of its idle sprite), as
## offsets from its centre: the heat's preview of the size a star will become.
static func outline_pixels(star_size: Star.Size) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var half: int = half_extent(star_size)
	for y: int in range(-half - 1, half + 2):
		for x: int in range(-half - 1, half + 2):
			var offset := Vector2i(x, y)
			if _is_star_pixel(star_size, offset):
				continue
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if _is_star_pixel(star_size, offset + d):
					result.append(offset)
					break
	return result


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
