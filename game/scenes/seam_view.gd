class_name SeamView
extends Node2D
## Pisces's reflection (chapter 6): the seam through the sky's middle, and the splash where a thrown
## planet goes into the mirror. Owns no rules: RunState.reflect says where; Sky plays
## planet_reflected here. Look: the seam is a still water line along the sky's middle, up and down or
## across, drawn under the figure: a solid M4 line with an M3 dither either side, short M5 glints
## (GLINT_LENGTH px, about every GLINT_PERIOD) drifting along it at GLINT_SPEED, its last FADE px at
## each end dithered out into the sky. Moonlight blues, so it reads as a surface on every band of
## the sky and isn't taken for the figure's lavender strings. The splash is a ring closing on the
## thrown point in hard steps (N8, N7, N6) over SPLASH_TIME, as the planet sinks into the mirror;
## the stars come out across the seam with the burst.

const LINE_COLOUR: Color = Palette.M4
const EDGE_COLOUR: Color = Palette.M3
const GLINT_COLOUR: Color = Palette.M5
const GLINT_LENGTH: int = 3
const GLINT_PERIOD: int = 23
## Pixels a second the glints drift along the seam.
const GLINT_SPEED: float = 4.0
const FADE: int = 12
## Within FADE_SPARSE of an end, only every fourth pixel is left; within FADE, every other.
const FADE_SPARSE: int = 6
const SPLASH_TIME: float = 0.3
const SPLASH_RADII: Array[int] = [7, 5, 3]
const SPLASH_COLOURS: Array[Color] = [Palette.N8, Palette.N7, Palette.N6]

var _run: RunState
## Seconds the seam has shimmered, for its glints' drift.
var _time: float = 0.0
## The splash playing: where, and the seconds since it began (-1: none).
var _splash_at: Vector2i = Vector2i.ZERO
var _splash_age: float = -1.0


func _ready() -> void:
	set_process(has_seam())


func setup(run: RunState) -> void:
	_run = run
	_splash_age = -1.0
	_time = 0.0
	visible = has_seam()
	set_process(visible)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## Whether this run's sky has a seam.
func has_seam() -> bool:
	return _run != null and _run.scorpio != null and _run.scorpio.map.seam != StarMap.Seam.NONE


## A planet thrown at `thrown` went into the mirror (it bursts at `burst`, across the seam).
func splash(thrown: Vector2i, _burst: Vector2i) -> void:
	_splash_at = thrown
	_splash_age = 0.0
	queue_redraw()


func is_splashing() -> bool:
	return _splash_age >= 0.0


## Drifts the glints and plays the splash. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	var drift: int = _drift()
	_time += delta
	if _drift() != drift:
		queue_redraw()
	if _splash_age < 0.0:
		return
	_splash_age += delta
	if _splash_age >= SPLASH_TIME:
		_splash_age = -1.0
	queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if not has_seam():
		return result
	# Halfway between any point and its reflection is on the seam.
	var p: Vector2i = _run.sky_rect.get_center()
	@warning_ignore("integer_division")
	var middle: Vector2i = (p + _run.reflect(p)) / 2
	result.merge(seam_pixels(_run.scorpio.map.seam, middle, _run.sky_rect, _drift()), true)
	if _splash_age >= 0.0:
		var step: int = mini(floori(_splash_age / SPLASH_TIME * SPLASH_RADII.size()), SPLASH_RADII.size() - 1)
		result.merge(ring_pixels(_splash_at, SPLASH_RADII[step], SPLASH_COLOURS[step]), true)
	return result


## The seam through `middle` (any point on it) across the sky, its glints moved `drift` px along.
static func seam_pixels(seam: StarMap.Seam, middle: Vector2i, sky: Rect2i, drift: int = 0) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if seam == StarMap.Seam.NONE:
		return result
	var vertical: bool = seam == StarMap.Seam.VERTICAL
	var along: Vector2i = Vector2i.DOWN if vertical else Vector2i.RIGHT
	var across: Vector2i = Vector2i.RIGHT if vertical else Vector2i.DOWN
	var start: Vector2i = Vector2i(middle.x, sky.position.y) if vertical else Vector2i(sky.position.x, middle.y)
	var length: int = sky.size.y if vertical else sky.size.x
	for t: int in length:
		var from_end: int = mini(t, length - 1 - t)
		# The ends dither out: every other pixel, then every fourth.
		if from_end < FADE and t % (2 if from_end >= FADE_SPARSE else 4) != 0:
			continue
		var p: Vector2i = start + along * t
		result[p] = GLINT_COLOUR if posmod((t - drift) * 7, GLINT_PERIOD) < GLINT_LENGTH else LINE_COLOUR
		if t % 2 == 0:
			result[p - across] = EDGE_COLOUR
			result[p + across] = EDGE_COLOUR
	return result


## A ring of `radius` round `at`, on whole pixels.
static func ring_pixels(at: Vector2i, radius: int, colour: Color) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in 24:
		var angle: float = TAU * i / 24.0
		result[at + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round())] = colour
	return result


func _drift() -> int:
	return floori(_time * GLINT_SPEED)
