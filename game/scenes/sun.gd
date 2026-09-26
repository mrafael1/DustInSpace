class_name SunView
extends Node2D
## The Sun, drawn in code until the Sun art lands (#13). Its frame follows light / sun_target:
## light pools up the disc from the bottom and the rays light clockwise from 12 o'clock, taking
## it from the dim S ramp to the lit C ramp. That change is the run's progress bar.
## It pulses as each light particle lands (receive_light, wired by Main), and ignites and lights
## up the sky when run_won plays, once the last of its light has landed.
## Until then its unlit part smoulders on the ripple's 2-frame tick: embers swap S3/S4 and the
## dim halo breathes, so even a dark Sun is alive. Once ignited it idles on the same tick:
## alternate rays shimmer and the core's glint moves, while the sky glow holds still.
## Whole-frame swaps, never rotation or scaling.
## Owns no rules: like the HUD it keeps a shown copy of the light, moved only by played events
## and the particles they send.
## Every pixel is a palette colour at an integer offset from the centre; the node sits on whole pixels.

## Sun art: an r17 disc and 12 rays (art-direction.md).
const RADIUS: int = 17
const DISC_ROWS: int = 2 * RADIUS + 1
const RAYS: int = 12
## Rays start this far outside the disc; lit rays are longer than dim ones.
const RAY_GAP: int = 3
const LIT_RAY_LENGTH: int = 7
const DIM_RAY_LENGTH: int = 3
## Game feel: a short pulse when light arrives; the ignition takes about 1.8 s before the win.
const PULSE_TIME: float = 0.3
const IGNITE_TIME: float = 1.8
## The ignition is drawn in this many frames: the halo turns warm, then the glow spreads.
const IGNITE_FRAMES: int = 6
## A won run holds this long past the particles' longest travel, so the last light always lands
## (and the ignition extends the hold) before the sequence can finish.
const ARRIVAL_MARGIN: float = 0.1
## The glow's reach on its last frame: past the farthest corner of the sky from the Sun.
const GLOW_REACH: int = 230
## The light pool's surface ripples between two frames; the smoulder and ignited idle use the same tick.
const RIPPLE_TIME: float = 0.5
## Craters on the unlit disc, as (x, y, radius) from the centre.
const CRATERS: Array[Vector3i] = [Vector3i(-6, -7, 3), Vector3i(5, -3, 2), Vector3i(-1, 3, 2), Vector3i(8, -10, 2), Vector3i(-9, 1, 2)]
## Smouldering embers on the unlit disc, clear of the craters. Even and odd ones swap S4/S3 each tick.
const EMBERS: Array[Vector2i] = [Vector2i(-12, -5), Vector2i(1, -13), Vector2i(11, -2), Vector2i(-4, 9), Vector2i(7, 6), Vector2i(-13, 5)]
## Ramps dark to light. A pulse lifts every pixel one step up its own ramp.
const DIM_RAMP: Array[Color] = [Palette.S0, Palette.S1, Palette.S2, Palette.S3, Palette.S4]
const LIT_RAMP: Array[Color] = [Palette.C5, Palette.C4, Palette.C3, Palette.C2, Palette.C1, Palette.C0]

var _run: RunState
var _sequencer: EventSequencer
## The light as the events played so far have shown it.
var _shown_light: int = 0
var _pulse_left: float = 0.0
## Light whose combo has played but whose particles haven't landed yet.
var _light_in_flight: int = 0
## run_won has played and the ignition waits for the light still in flight.
var _ignite_waiting: bool = false
## Seconds since the ignition started, or -1 before it.
var _ignite_time: float = -1.0
var _ripple: int = 0
var _ripple_time: float = 0.0
## Sky glow textures by ignition frame: at most IGNITE_FRAMES per run, each built once.
var _glow_textures: Dictionary[int, ImageTexture] = {}


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var frame: int = ignite_frame()
	if frame > 0:
		if not _glow_textures.has(frame):
			_glow_textures[frame] = ImageTexture.create_from_image(sky_glow(frame, Vector2i(global_position)))
		draw_texture(_glow_textures[frame], -global_position)
	var lit: bool = frame > 0
	var dots: Dictionary[Vector2i, Color] = pixels(
		DISC_ROWS if lit else fill_rows(), RAYS if lit else lit_rays(), lit, is_pulsing(), _ripple)
	for offset: Vector2i in dots:
		draw_rect(Rect2(Vector2(offset), Vector2.ONE), dots[offset])


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_shown_light = run.light
	_pulse_left = 0.0
	_light_in_flight = 0
	_ignite_waiting = false
	_glow_textures.clear()
	_ignite_time = IGNITE_TIME if run.outcome == RunState.Outcome.WON else -1.0
	queue_redraw()


## A light particle landed: the fill rises and the Sun pulses. The last one lets a won run ignite.
func receive_light(amount: int) -> void:
	_shown_light += amount
	_light_in_flight = maxi(_light_in_flight - amount, 0)
	_pulse_left = PULSE_TIME
	if _ignite_waiting and _light_in_flight == 0:
		_ignite()
	queue_redraw()


## The shown light over the Sun's target, from 0 to 1. Dark (0) until setup gives it a run:
## Main doesn't when balance.json is invalid, and the Sun still draws and processes.
func progress() -> float:
	if _run == null:
		return 0.0
	return clampf(float(_shown_light) / float(_run.balance.sun_target), 0.0, 1.0)


## Rows of the disc filled with light, from the bottom. All of them only at 100%.
func fill_rows() -> int:
	return floori(progress() * DISC_ROWS)


## Rays lit clockwise from 12 o'clock. The last one only at 100%.
func lit_rays() -> int:
	return floori(progress() * RAYS)


func is_pulsing() -> bool:
	return _pulse_left > 0.0


func is_igniting() -> bool:
	return _ignite_time >= 0.0 and _ignite_time < IGNITE_TIME


func is_ignited() -> bool:
	return _ignite_time >= IGNITE_TIME


## The ignition frame drawn now: 0 before it, then 1 to IGNITE_FRAMES.
func ignite_frame() -> int:
	if _ignite_time < 0.0:
		return 0
	return clampi(floori(_ignite_time / IGNITE_TIME * IGNITE_FRAMES) + 1, 1, IGNITE_FRAMES)


## Moves the pulse, ignition and ripple on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	var before: Array = _frame_key()
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	if is_igniting():
		_ignite_time = minf(_ignite_time + delta, IGNITE_TIME)
	_ripple_time += delta
	if _ripple_time >= RIPPLE_TIME:
		_ripple_time = fmod(_ripple_time, RIPPLE_TIME)
		_ripple = 1 - _ripple
	if _frame_key() != before:
		queue_redraw()


## The Sun's pixels as offsets from its centre: halo, rays, then the disc over them.
## `p_ripple` is the 2-frame tick: the pool's ripple, or the ignited idle's shimmer and glint.
static func pixels(p_fill_rows: int, p_lit_rays: int, p_ignited: bool, p_lifted: bool, p_ripple: int = 0) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	_add_halo(dots, float(p_fill_rows) / DISC_ROWS, p_ignited, 0 if p_ignited else p_ripple)
	_add_rays(dots, p_lit_rays, p_ripple if p_ignited else -1)
	_add_disc(dots, p_fill_rows, p_ripple, p_ignited)
	if p_lifted:
		for offset: Vector2i in dots:
			dots[offset] = _lift(dots[offset])
	return dots


## The warm glow over the sky while the Sun ignites, in screen pixels down to the sky's bottom
## edge: dithered C4 then C5 bands whose reach grows with the frame. Halo colours only.
static func sky_glow(frame: int, centre: Vector2i) -> Image:
	var size := Vector2i(ScreenZones.SKY.end.x, ScreenZones.SKY.end.y)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var reach: float = lerpf(RADIUS + 13, GLOW_REACH, float(frame) / IGNITE_FRAMES)
	for y: int in size.y:
		for x: int in size.x:
			var d: float = Vector2(x - centre.x, y - centre.y).length()
			if d <= RADIUS + 13 or d >= reach:
				continue
			var colour: Color = Palette.C4 if d < 60 else Palette.C5
			var density: float = 0.125 if d >= 120 else 0.25
			if _bayer(x, y) < density:
				image.set_pixel(x, y, colour)
	return image


func _frame_key() -> Array:
	return [fill_rows(), lit_rays(), ignite_frame(), is_pulsing(), _ripple]


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"combo_collected":
			_light_in_flight += event.args[3]
		&"run_won":
			if _light_in_flight > 0:
				# The win's light is still flying: hold until it can have landed, then ignite.
				_ignite_waiting = true
				_sequencer.hold(CollectParticles.LONGEST_TRAVEL + ARRIVAL_MARGIN)
			else:
				_ignite()


## Starts the ignition and keeps the sequence (the win) waiting until it's done.
func _ignite() -> void:
	_ignite_waiting = false
	_ignite_time = 0.0
	_pulse_left = PULSE_TIME
	_sequencer.hold(IGNITE_TIME)
	queue_redraw()


## Stepped, dithered rings: dim S1/S0 growing a little with the light, or warm C2-C4 once lit.
## `breath` (0 or 1) thins the inner S1 ring by one dither step: the dim Sun's smoulder.
static func _add_halo(dots: Dictionary[Vector2i, Color], p_progress: float, p_ignited: bool, breath: int) -> void:
	var grow: int = roundi(5 * p_progress)
	# [inner radius, outer radius, colour, dither density]
	var rings: Array = [
		[RADIUS + 2, RADIUS + 6, Palette.S1, 0.375 + 0.375 * p_progress - breath / 16.0],
		[RADIUS + 6, RADIUS + 11 + grow, Palette.S0, 0.25 + 0.25 * p_progress],
		[RADIUS + 11 + grow, RADIUS + 16 + grow, Palette.S0, 0.125],
	]
	if p_ignited:
		rings = [
			[RADIUS + 1, RADIUS + 5, Palette.C2, 0.5],
			[RADIUS + 5, RADIUS + 9, Palette.C3, 0.25],
			[RADIUS + 9, RADIUS + 13, Palette.C4, 0.125],
		]
	var reach: int = rings[-1][1]
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var d: float = Vector2(dx, dy).length()
			for ring: Array in rings:
				if d >= ring[0] and d < ring[1]:
					if _bayer(dx, dy) < ring[3]:
						dots[Vector2i(dx, dy)] = ring[2]
					break


## Rays from 12 o'clock clockwise. Lit ones run C0 to C3, two pixels thick at the root.
## `shimmer` (0 or 1, or -1 for none): every other ray loses its tip, alternating each tick.
static func _add_rays(dots: Dictionary[Vector2i, Color], p_lit_rays: int, shimmer: int) -> void:
	for k: int in RAYS:
		var direction := Vector2.from_angle(-PI / 2 + k * TAU / RAYS)
		var lit: bool = k < p_lit_rays
		var length: int = LIT_RAY_LENGTH if lit else DIM_RAY_LENGTH
		if lit and shimmer >= 0 and posmod(k + shimmer, 2) == 1:
			length -= 1
		for s: int in length:
			var at := Vector2i((direction * (RADIUS + RAY_GAP + s)).round())
			if not lit:
				dots[at] = Palette.S2 if s < 2 else Palette.S1
				continue
			dots[at] = [Palette.C0, Palette.C0, Palette.C1, Palette.C1, Palette.C2, Palette.C2, Palette.C3][s]
			if s < 4:
				var side := Vector2i((direction * (RADIUS + RAY_GAP + s) + direction.orthogonal() * 0.8).round())
				if side != at:
					dots[side] = Palette.C2


## The disc: dim, cratered and smouldering above the light pool, C1-C3 below it with a C0 surface.
## Ignited, the C0 glint in its core moves a pixel sideways on the ripple's tick. (A 2 px shift
## would map the 4x4 dither onto itself and show no change.)
static func _add_disc(dots: Dictionary[Vector2i, Color], p_fill_rows: int, p_ripple: int, p_ignited: bool) -> void:
	var level: int = RADIUS + 1 - p_fill_rows
	var rippling: bool = p_fill_rows > 0 and p_fill_rows < DISC_ROWS
	var glint: int = p_ripple if p_ignited else 0
	for dy: int in range(-RADIUS, RADIUS + 1):
		for dx: int in range(-RADIUS, RADIUS + 1):
			if dx * dx + dy * dy > RADIUS * RADIUS + RADIUS:
				continue
			var q: float = Vector2(dx, dy).length() / RADIUS
			var surface: int = level
			if rippling and posmod(dx + 3 * p_ripple, 6) < 3:
				surface -= 1
			var colour: Color
			if dy >= surface:
				colour = Palette.C3 if q > 0.9 else (Palette.C2 if q > 0.7 else Palette.C1)
				if dy == surface:
					colour = Palette.C0
				elif q < 0.45 and _bayer(dx + glint, dy) < 0.375:
					colour = Palette.C0
			else:
				colour = Palette.S1 if q > 0.88 else Palette.S2
				if dx + dy < -RADIUS * 0.6 and _bayer(dx, dy) < 0.5:
					colour = Palette.S3
				for crater: Vector3i in CRATERS:
					if (dx - crater.x) * (dx - crater.x) + (dy - crater.y) * (dy - crater.y) <= crater.z * crater.z:
						colour = Palette.S1
				if p_fill_rows > 0 and dy > surface - 3 and _bayer(dx, dy) < 0.25:
					colour = Palette.S4
				var ember: int = EMBERS.find(Vector2i(dx, dy))
				if ember >= 0:
					colour = Palette.S4 if posmod(ember + p_ripple, 2) == 0 else Palette.S3
			dots[Vector2i(dx, dy)] = colour


## One step lighter on the pixel's own ramp; the lightest step stays.
static func _lift(colour: Color) -> Color:
	var i: int = DIM_RAMP.find(colour)
	if i >= 0:
		return DIM_RAMP[mini(i + 1, DIM_RAMP.size() - 1)]
	i = LIT_RAMP.find(colour)
	return LIT_RAMP[mini(i + 1, LIT_RAMP.size() - 1)] if i >= 0 else colour


## Ordered-dither threshold for a pixel, from 0 to 15/16.
static func _bayer(x: int, y: int) -> float:
	return StarView.BAYER[posmod(y, 4) * 4 + posmod(x, 4)] / 16.0
