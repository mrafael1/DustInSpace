class_name BigBangSequence
extends Node2D
## The Big Bang, played when big_bang_started plays (game-feel skill, "Big Bang script"):
## 1. It opens exactly like a normal burst (the launcher's ring, sparks, and the Sky's decoy
##    stars flying out) to keep the surprise.
## 2. At FREEZE_AT the sky darkens and a black hole opens at the burst point: an N0 disc in a
##    bright photon ring, the far side of its accretion disc lensed into an arc over the top and
##    the near side crossing in front (never a ringed planet: that's the red pack). Every star
##    spirals into it (the Sky collapses them over COLLAPSE_TIME) and cool specks of sky dust
##    spiral in too: fast at first, then slowing and dimming as they near the hole, where they
##    hang, orbiting, until it swallows them.
## 3. The hole implodes into a 1-2 px white point that pulses until the bang. (Silence: no
##    audio exists yet.)
## 4. The bang: a hard 2-frame full-screen flash, then a solid white core shrinking away (no
##    dithered fade), 3 staggered shockwave rings and
##    about 200 multi-colour palette pixels that streak and twinkle; the world shakes (a Camera2D,
##    so the HUD and the banner stay still); newborn sparkles twinkle up across the sky; a
##    "BIG BANG" banner pops in, shimmers and rolls its dust up from 0, for BANNER_TIME.
## 5. The dust streams to the counter (CollectParticles).
## 6. The sequence holds input until INPUT_BACK_AFTER past the bang.
## Owns no rules: the dust comes from the event. Rare means different: none of these effects are
## used anywhere else. The flash, then the rings and debris over it, and the banner sit on their
## own CanvasLayer above the HUD, so the blast reads through the fading flash.

## Timeline, in seconds from the event.
const FREEZE_AT: float = 0.26
const COLLAPSE_TIME: float = 0.75
const PAUSE_TIME: float = 0.5
## How far stars and specks turn around the hole as they fall in.
const SWIRL: float = 0.6
## The black hole: grows to HOLE_RADIUS over the collapse, then implodes at the start of the pause.
const HOLE_RADIUS: int = 9
## Falling stars and specks slow down and hang this far from the centre, just outside the photon
## ring and the lensed arc, before they are swallowed.
const HOVER: int = HOLE_RADIUS + 3
const HOLE_IMPLODE: float = 0.15
## The accretion disc's near side: a flat ellipse this far past the hole, dashed, crossing in
## front of it. Its dashes, and the photon ring's highlights, move one step per DISC_SPIN_STEP.
const DISC_GAP: int = 5
const DISC_TILT: float = 0.3
const DISC_DASHES: int = 14
const DISC_SPIN_STEP: float = 0.05
## The photon ring's C0 highlights: one in this many steps of the ring.
const PHOTON_HIGHLIGHT: int = 4
## A faint C5 halo out to this far past the hole.
const HOLE_HALO: int = 6
## Sky dust drawn into the hole while it collapses. Cool colours: it isn't worth anything.
const SPECKS: int = 60
const SPECK_REACH_MIN: float = 40.0
const SPECK_REACH_MAX: float = 140.0
const SPECK_COLOURS: Array[Color] = [Palette.N6, Palette.N7, Palette.N8]
const BANG_AT: float = FREEZE_AT + COLLAPSE_TIME + PAUSE_TIME
const INPUT_BACK_AFTER: float = 1.1
const BANNER_TIME: float = 2.5
## The sky darkens to about 80%: N0 over a quarter of the pixels.
const DARKEN_DENSITY: float = 0.25
## The white point swaps between a pixel and a small plus.
const POINT_PULSE: float = 0.1
## The flash: solid C0 over the whole screen for about two frames, then cut. A solid C0 core
## with a C1 rim stays at the burst point, shrinking from FLASH_CORE_RADIUS to nothing.
const FLASH_HOLD: float = 0.07
const FLASH_CORE_RADIUS: int = 40
const FLASH_CORE_TIME: float = 0.25
const RINGS: int = 3
const RING_STAGGER: float = 0.12
const RING_TIME: float = 0.5
const RING_REACH: int = 120
const RING_COOLING: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
const DEBRIS: int = 200
const DEBRIS_SPEED_MIN: float = 40.0
const DEBRIS_SPEED_MAX: float = 160.0
const DEBRIS_LIFE_MIN: float = 0.6
const DEBRIS_LIFE_MAX: float = 1.2
const DEBRIS_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.N8, Palette.N9, Palette.N10, Palette.D0]
const SCREEN := Vector2i(180, 320)
## The bang's shake: whole-pixel world offsets, one per SHAKE_STEP, decaying to rest. Only the
## Big Bang shakes the screen (rare means different).
const SHAKE: Array[Vector2i] = [Vector2i(3, 0), Vector2i(-3, 1), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 0), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 0), Vector2i(0, 1)]
const SHAKE_STEP: float = 0.04
## Debris streaks while it's fast, and a third of it flashes C0 each twinkle step.
const DEBRIS_STREAK: float = 0.5
const DEBRIS_TWINKLE_STEP: float = 0.08
## Newborn sparkles: they pop up across the sky, staggered over SPARKLE_SPREAD after the bang,
## each growing from a dot to a plus and fading in SPARKLE_LIFE.
const SPARKLES: int = 28
const SPARKLE_SPREAD: float = 1.2
const SPARKLE_LIFE: float = 0.6
const SPARKLE_AREA := Rect2i(8, 16, 164, 232)
const SPARKLE_RAMPS: Array = [
	[Palette.C1, Palette.C0, Palette.C1, Palette.C2, Palette.C3],
	[Palette.D0, Palette.C0, Palette.D0, Palette.N8, Palette.N7],
]
## Banner: one frame at 3x before it settles at 2x, its letters shimmering C0/C1, and the dust
## rolling up from 0 like a slot machine's payout.
const BANNER_POP: float = 0.1
const SHIMMER_TIME: float = 0.6
const SHIMMER_STEP: float = 0.08
const COUNT_TIME: float = 0.6

var _sequencer: EventSequencer
## Seconds since the event, or -1 when no Big Bang is playing.
var _time: float = -1.0
var _burst: Vector2i = Vector2i.ZERO
## One entry per debris pixel: its full travel, life and colour.
var _debris_reach: Array[Vector2] = []
var _debris_life: Array[float] = []
var _debris_colour: Array[Color] = []
## One entry per speck: where it starts, as an offset from the burst point, and its colour.
var _speck_from: Array[Vector2] = []
var _speck_colour: Array[Color] = []
var _rng := RandomNumberGenerator.new()
## One entry per sparkle: where, when (seconds after the bang) and which ramp.
var _sparkle_at: Array[Vector2i] = []
var _sparkle_delay: Array[float] = []
var _sparkle_ramp: Array[int] = []
var _dust: int = 0
var _darken: ImageTexture

@onready var _front: Node2D = $Front/Flash
@onready var _banner: Node2D = $Front/Banner
@onready var _title: Label = $Front/Banner/Title
@onready var _amount: Label = $Front/Banner/Amount
@onready var _shake: Camera2D = $Shake


func _ready() -> void:
	_rng.randomize()
	_front.draw.connect(_draw_flash)
	_title.label_settings = HudText.primary(Palette.C1)
	_amount.label_settings = HudText.primary(Palette.D0)
	# Dithers are one 4x4 Bayer tile, repeated over the screen.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_front.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_darken = ImageTexture.create_from_image(dither_tile(DARKEN_DENSITY, Palette.N0))
	_banner.visible = false


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _time < 0.0:
		return
	if _time >= FREEZE_AT and _time < BANG_AT:
		draw_texture_rect(_darken, Rect2(Vector2.ZERO, Vector2(SCREEN)), true)
	var since_freeze: float = _time - FREEZE_AT
	if since_freeze >= 0.0 and since_freeze < COLLAPSE_TIME:
		var k: float = since_freeze / COLLAPSE_TIME
		for i: int in _speck_from.size():
			_dot(self, _burst + StarView.collapse_point(Vector2i(_speck_from[i]), Vector2i.ZERO, k, SWIRL, HOVER), _speck_colour[i])
	var radius: int = hole_radius(since_freeze)
	if radius > 0:
		var dots: Dictionary[Vector2i, Color] = hole_pixels(radius, floori(since_freeze / DISC_SPIN_STEP))
		for offset: Vector2i in dots:
			_dot(self, _burst + offset, dots[offset])
	if since_freeze >= COLLAPSE_TIME + HOLE_IMPLODE and _time < BANG_AT:
		for offset: Vector2i in point_pixels(since_freeze - COLLAPSE_TIME - HOLE_IMPLODE):
			_dot(self, _burst + offset, Palette.C0)


func setup(_run: RunState, sequencer: EventSequencer) -> void:
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_stop()


func is_playing() -> bool:
	return _time >= 0.0


func is_banner_shown() -> bool:
	return _banner.visible


func banner_text() -> String:
	return "%s %s" % [_title.text, _amount.text]


## True while the whole screen flashes white.
func is_flashing() -> bool:
	return _time >= BANG_AT and _time < BANG_AT + FLASH_HOLD


## The flash core's radius `t` seconds after the bang: FLASH_CORE_RADIUS once the full-screen
## flash cuts, easing in to nothing over FLASH_CORE_TIME. 0 means no core.
static func flash_core_radius(t: float) -> int:
	var u: float = (t - FLASH_HOLD) / FLASH_CORE_TIME
	if u < 0.0 or u >= 1.0:
		return 0
	return roundi(FLASH_CORE_RADIUS * (1.0 - u) * (1.0 - u))


## Moves the sequence on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if _time >= BANG_AT + maxf(BANNER_TIME, DEBRIS_LIFE_MAX):
		_stop()
		return
	_banner.visible = _time >= BANG_AT and _time < BANG_AT + BANNER_TIME
	_shake.offset = Vector2(shake_offset(_time - BANG_AT))
	_show_banner(_time - BANG_AT)
	queue_redraw()
	_front.queue_redraw()


## The black hole's radius `t` seconds after the freeze: easing out to HOLE_RADIUS over the
## collapse, then imploding to nothing over HOLE_IMPLODE. 0 means no hole.
static func hole_radius(t: float) -> int:
	if t < 0.0 or t >= COLLAPSE_TIME + HOLE_IMPLODE:
		return 0
	if t < COLLAPSE_TIME:
		var u: float = t / COLLAPSE_TIME
		return maxi(roundi(HOLE_RADIUS * (1.0 - (1.0 - u) * (1.0 - u))), 1)
	return maxi(roundi(HOLE_RADIUS * (1.0 - (t - COLLAPSE_TIME) / HOLE_IMPLODE)), 1)


## The hole's pixels, back to front: a faint dithered C5 halo, the lensed far side of the
## accretion disc as a C3 arc over the top, the N0 disc in a C2 photon ring with travelling C0
## highlights, then the disc's near side crossing in front, dashed C1/C2. `spin` moves the
## highlights and dashes one step, so it turns without rotating a sprite.
static func hole_pixels(radius: int, spin: int) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var reach: int = radius + HOLE_HALO
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var d: float = Vector2(dx, dy).length()
			if d > radius + 2.5 and d <= reach and StarView.BAYER[posmod(dy, 4) * 4 + posmod(dx, 4)] < 4:
				dots[Vector2i(dx, dy)] = Palette.C5
	var arc: int = radius + 2
	for k: int in ceili(PI * arc) + 1:
		var angle: float = PI + PI * k / ceili(PI * arc)
		dots[Vector2i((Vector2.from_angle(angle) * arc).round())] = Palette.C3
	var ring_steps: int = maxi(ceili(TAU * (radius + 1)), 8)
	for dy: int in range(-radius - 1, radius + 2):
		for dx: int in range(-radius - 1, radius + 2):
			var d: float = Vector2(dx, dy).length()
			if d <= radius:
				dots[Vector2i(dx, dy)] = Palette.N0
			elif d <= radius + 1.0:
				var step: int = floori(fposmod(atan2(dy, dx), TAU) / TAU * ring_steps)
				dots[Vector2i(dx, dy)] = Palette.C0 if posmod(step + spin, PHOTON_HIGHLIGHT) == 0 else Palette.C2
	var band := Vector2(radius + DISC_GAP, (radius + DISC_GAP) * DISC_TILT)
	var band_steps: int = maxi(ceili(TAU * band.x), 16)
	for k: int in band_steps:
		var angle: float = TAU * k / band_steps
		if sin(angle) < 0.0:
			continue
		var dash: int = floori(float(k) / band_steps * DISC_DASHES)
		dots[Vector2i((Vector2(cos(angle) * band.x, sin(angle) * band.y)).round())] = Palette.C1 if posmod(dash + spin, 2) == 0 else Palette.C2
	return dots


## The world's shake `t` seconds after the bang: whole pixels, decaying, then rest.
static func shake_offset(t: float) -> Vector2i:
	if t < 0.0:
		return Vector2i.ZERO
	var step: int = floori(t / SHAKE_STEP)
	return SHAKE[step] if step < SHAKE.size() else Vector2i.ZERO


## A newborn sparkle at `u` (0 to 1 of its life), on ramp 0 (starlight) or 1 (dust): a dot, a
## small plus, a big plus with a C0 heart, then shrinking and cooling away. Empty outside 0-1.
static func sparkle_pixels(u: float, ramp: int) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if u < 0.0 or u >= 1.0:
		return dots
	var colours: Array = SPARKLE_RAMPS[ramp]
	var arm: int = [0, 1, 2, 2, 1, 0][floori(u * 6)]
	var tint: Color = colours[[0, 0, 2, 2, 3, 4][floori(u * 6)]]
	dots[Vector2i.ZERO] = colours[1] if arm == 2 else tint
	for r: int in range(1, arm + 1):
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			dots[dir * r] = tint
	return dots


## The dust the banner shows `t` seconds after the bang: rolling up from 0 over COUNT_TIME.
static func banner_count(total: int, t: float) -> int:
	if t <= 0.0:
		return 0
	var u: float = minf(t / COUNT_TIME, 1.0)
	return roundi(total * (1.0 - (1.0 - u) * (1.0 - u)))


## The white point `t` seconds into the pause: one pixel, then a small plus, and so on.
static func point_pixels(t: float) -> Array[Vector2i]:
	if floori(t / POINT_PULSE) % 2 == 0:
		return [Vector2i.ZERO]
	return [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## A shockwave ring at `u` (0 to 1 of its life): a 1 px circle easing out to RING_REACH, dotted
## every other pixel and cooling C0 to C3. Nothing outside 0 <= u < 1.
static func ring_pixels(u: float) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if u < 0.0 or u >= 1.0:
		return dots
	var radius: int = maxi(roundi(RING_REACH * (1.0 - (1.0 - u) * (1.0 - u))), 1)
	var colour: Color = RING_COOLING[clampi(floori(u * RING_COOLING.size()), 0, RING_COOLING.size() - 1)]
	var steps: int = maxi(ceili(TAU * radius), 8)
	for k: int in steps:
		var at := Vector2i((Vector2.from_angle(TAU * k / steps) * radius).round())
		if posmod(at.x + at.y, 2) == 0:
			dots[at] = colour
	return dots


## A 4x4 ordered-dither tile of `colour` covering `density` of the pixels; tiled over the screen.
static func dither_tile(density: float, colour: Color) -> Image:
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	for y: int in 4:
		for x: int in 4:
			if StarView.BAYER[y * 4 + x] / 16.0 < density:
				image.set_pixel(x, y, colour)
	return image


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	if event.type != &"big_bang_started":
		return
	_burst = event.args[0]
	_time = 0.0
	_title.text = "BIG BANG"
	_dust = event.args[2]
	_show_banner(-1.0)
	_scatter_debris()
	_scatter_specks()
	_scatter_sparkles()
	_sequencer.hold(BANG_AT + INPUT_BACK_AFTER)
	queue_redraw()


func _scatter_specks() -> void:
	_speck_from.clear()
	_speck_colour.clear()
	for i: int in SPECKS:
		_speck_from.append(Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SPECK_REACH_MIN, SPECK_REACH_MAX))
		_speck_colour.append(SPECK_COLOURS[_rng.randi() % SPECK_COLOURS.size()])


func _scatter_sparkles() -> void:
	_sparkle_at.clear()
	_sparkle_delay.clear()
	_sparkle_ramp.clear()
	for i: int in SPARKLES:
		_sparkle_at.append(Vector2i(
			_rng.randi_range(SPARKLE_AREA.position.x, SPARKLE_AREA.end.x - 1),
			_rng.randi_range(SPARKLE_AREA.position.y, SPARKLE_AREA.end.y - 1)))
		_sparkle_delay.append(_rng.randf_range(0.1, SPARKLE_SPREAD))
		_sparkle_ramp.append(i % 2)


## The banner `t` seconds after the bang (negative: before it): the 3x pop, the shimmer and the
## rolling dust. The title is centred on the banner at every scale, by its own box: a Label's
## box can be wider than its text, which the centred alignment then pushes right.
func _show_banner(t: float) -> void:
	var scale_by: int = 3 if t >= 0.0 and t < BANNER_POP else 2
	_title.scale = Vector2(scale_by, scale_by)
	_title.position = Vector2(-floori(_title.size.x * scale_by / 2.0), -floori(_title.size.y * (scale_by - 2) / 2.0))
	var shimmering: bool = t >= 0.0 and t < SHIMMER_TIME and posmod(floori(t / SHIMMER_STEP), 2) == 0
	_title.label_settings.font_color = Palette.C0 if shimmering else Palette.C1
	_amount.text = "+%d" % banner_count(_dust, t)


func _scatter_debris() -> void:
	_debris_reach.clear()
	_debris_life.clear()
	_debris_colour.clear()
	for i: int in DEBRIS:
		var life: float = _rng.randf_range(DEBRIS_LIFE_MIN, DEBRIS_LIFE_MAX)
		var speed: float = _rng.randf_range(DEBRIS_SPEED_MIN, DEBRIS_SPEED_MAX)
		_debris_reach.append(Vector2.from_angle(_rng.randf() * TAU) * speed * life * 0.5)
		_debris_life.append(life)
		_debris_colour.append(DEBRIS_COLOURS[_rng.randi() % DEBRIS_COLOURS.size()])


func _stop() -> void:
	_time = -1.0
	_banner.visible = false
	if _shake != null:
		_shake.offset = Vector2.ZERO
	queue_redraw()
	_front.queue_redraw()


## The front layer: the flash, then the shockwave rings and debris over it.
func _draw_flash() -> void:
	if _time < BANG_AT:
		return
	var since: float = _time - BANG_AT
	if is_flashing():
		_front.draw_rect(Rect2(Vector2.ZERO, Vector2(SCREEN)), Palette.C0)
	var core: int = flash_core_radius(since)
	for dy: int in range(-core, core + 1):
		for dx: int in range(-core, core + 1):
			var d2: int = dx * dx + dy * dy
			if d2 <= core * core:
				_dot(_front, _burst + Vector2i(dx, dy), Palette.C1 if d2 > (core - 1) * (core - 1) else Palette.C0)
	for i: int in RINGS:
		var dots: Dictionary[Vector2i, Color] = ring_pixels((since - i * RING_STAGGER) / RING_TIME)
		for offset: Vector2i in dots:
			_dot(_front, _burst + offset, dots[offset])
	var twinkle: int = floori(since / DEBRIS_TWINKLE_STEP)
	for i: int in _debris_reach.size():
		var u: float = since / _debris_life[i]
		if u >= 1.0:
			continue
		var colour: Color = Palette.C0 if posmod(i + twinkle, 3) == 0 else _debris_colour[i]
		if u < DEBRIS_STREAK:
			var behind: float = maxf(u - 0.06, 0.0)
			_dot(_front, _burst + Vector2i((_debris_reach[i] * (1.0 - (1.0 - behind) * (1.0 - behind))).round()), _debris_colour[i])
		_dot(_front, _burst + Vector2i((_debris_reach[i] * (1.0 - (1.0 - u) * (1.0 - u))).round()), colour)
	for i: int in _sparkle_at.size():
		var dots: Dictionary[Vector2i, Color] = sparkle_pixels((since - _sparkle_delay[i]) / SPARKLE_LIFE, _sparkle_ramp[i])
		for offset: Vector2i in dots:
			_dot(_front, _sparkle_at[i] + offset, dots[offset])


func _dot(canvas: CanvasItem, at: Vector2i, colour: Color) -> void:
	canvas.draw_rect(Rect2(Vector2(at), Vector2.ONE), colour)
