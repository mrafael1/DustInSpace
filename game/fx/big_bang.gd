class_name BigBangSequence
extends Node2D
## The Big Bang, played when big_bang_started plays (game-feel skill, "Big Bang script"):
## 1. It opens exactly like a normal burst (the launcher's ring, sparks, and the Sky's decoy
##    stars flying out) to keep the surprise.
## 2. At FREEZE_AT the sky darkens and every star is pulled into the burst point (the Sky
##    collapses them, ease-in over COLLAPSE_TIME).
## 3. Only a 1-2 px white point pulses for PAUSE_TIME. (Silence: no audio exists yet.)
## 4. The bang: a full-screen flash fading in dithered steps, 3 staggered shockwave rings and
##    about 200 multi-colour palette pixels; a "BIG BANG" banner with the dust for BANNER_TIME.
## 5. The dust streams to the counter (CollectParticles).
## 6. The sequence holds input until INPUT_BACK_AFTER past the bang.
## Owns no rules: the dust comes from the event. Rare means different: none of these effects are
## used anywhere else. The flash, then the rings and debris over it, and the banner sit on their
## own CanvasLayer above the HUD, so the blast reads through the fading flash.

## Timeline, in seconds from the event.
const FREEZE_AT: float = 0.26
const COLLAPSE_TIME: float = 0.75
const PAUSE_TIME: float = 0.5
const BANG_AT: float = FREEZE_AT + COLLAPSE_TIME + PAUSE_TIME
const INPUT_BACK_AFTER: float = 1.1
const BANNER_TIME: float = 2.5
## The sky darkens to about 80%: N0 over a quarter of the pixels.
const DARKEN_DENSITY: float = 0.25
## The white point swaps between a pixel and a small plus.
const POINT_PULSE: float = 0.1
## The flash fades from full C0 in dithered steps.
const FLASH_TIME: float = 0.7
const FLASH_DENSITIES: Array[float] = [1.0, 0.75, 0.5, 0.25]
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

var _sequencer: EventSequencer
## Seconds since the event, or -1 when no Big Bang is playing.
var _time: float = -1.0
var _burst: Vector2i = Vector2i.ZERO
## One entry per debris pixel: its full travel, life and colour.
var _debris_reach: Array[Vector2] = []
var _debris_life: Array[float] = []
var _debris_colour: Array[Color] = []
var _rng := RandomNumberGenerator.new()
var _darken: ImageTexture
var _flashes: Array[ImageTexture] = []

@onready var _front: Node2D = $Front/Flash
@onready var _banner: Node2D = $Front/Banner
@onready var _title: Label = $Front/Banner/Title
@onready var _amount: Label = $Front/Banner/Amount


func _ready() -> void:
	_rng.randomize()
	_front.draw.connect(_draw_flash)
	_title.label_settings = HudText.primary(Palette.C1)
	_amount.label_settings = HudText.primary(Palette.D0)
	# Dithers are one 4x4 Bayer tile, repeated over the screen.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_front.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_darken = ImageTexture.create_from_image(dither_tile(DARKEN_DENSITY, Palette.N0))
	for density: float in FLASH_DENSITIES:
		_flashes.append(ImageTexture.create_from_image(dither_tile(density, Palette.C0)))
	_banner.visible = false


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _time < 0.0:
		return
	if _time >= FREEZE_AT and _time < BANG_AT:
		draw_texture_rect(_darken, Rect2(Vector2.ZERO, Vector2(SCREEN)), true)
	if _time >= FREEZE_AT + COLLAPSE_TIME and _time < BANG_AT:
		for offset: Vector2i in point_pixels(_time - FREEZE_AT - COLLAPSE_TIME):
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


## Which flash frame shows now (0 = full white), or -1 for none.
func flash_frame() -> int:
	if _time < BANG_AT or _time >= BANG_AT + FLASH_TIME:
		return -1
	return floori((_time - BANG_AT) / FLASH_TIME * FLASH_DENSITIES.size())


## Moves the sequence on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if _time >= BANG_AT + maxf(BANNER_TIME, DEBRIS_LIFE_MAX):
		_stop()
		return
	_banner.visible = _time >= BANG_AT and _time < BANG_AT + BANNER_TIME
	queue_redraw()
	_front.queue_redraw()


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
	_amount.text = "+%d" % event.args[2]
	_scatter_debris()
	_sequencer.hold(BANG_AT + INPUT_BACK_AFTER)
	queue_redraw()


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
	queue_redraw()
	_front.queue_redraw()


## The front layer: the flash, then the shockwave rings and debris over it.
func _draw_flash() -> void:
	if _time < BANG_AT:
		return
	var frame: int = flash_frame()
	if frame >= 0:
		_front.draw_texture_rect(_flashes[frame], Rect2(Vector2.ZERO, Vector2(SCREEN)), true)
	var since: float = _time - BANG_AT
	for i: int in RINGS:
		var dots: Dictionary[Vector2i, Color] = ring_pixels((since - i * RING_STAGGER) / RING_TIME)
		for offset: Vector2i in dots:
			_dot(_front, _burst + offset, dots[offset])
	for i: int in _debris_reach.size():
		var u: float = since / _debris_life[i]
		if u < 1.0:
			_dot(_front, _burst + Vector2i((_debris_reach[i] * (1.0 - (1.0 - u) * (1.0 - u))).round()), _debris_colour[i])


func _dot(canvas: CanvasItem, at: Vector2i, colour: Color) -> void:
	canvas.draw_rect(Rect2(Vector2(at), Vector2.ONE), colour)
