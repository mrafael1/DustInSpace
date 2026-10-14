class_name SeamView
extends Node2D
## Pisces's reflection (chapter 6): the seam through the sky's middle, and the splash where a thrown
## planet goes into the mirror. Owns no rules: RunState.reflect says where; Sky plays
## planet_reflected here. Look: the seam is a dotted N4 line (a pixel every SEAM_GAP) along the
## sky's middle, up and down or across, faint like the sky's own lines, drawn under the figure. The
## splash is a ring closing on the thrown point in hard steps (N8, N7, N6) over SPLASH_TIME, as the
## planet sinks into the mirror; the stars come out across the seam with the burst.

const SEAM_GAP: int = 4
const SPLASH_TIME: float = 0.3
const SPLASH_RADII: Array[int] = [7, 5, 3]
const SPLASH_COLOURS: Array[Color] = [Palette.N8, Palette.N7, Palette.N6]

var _run: RunState
## The splash playing: where, and the seconds since it began (-1: none).
var _splash_at: Vector2i = Vector2i.ZERO
var _splash_age: float = -1.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState) -> void:
	_run = run
	_splash_age = -1.0
	visible = has_seam()
	set_process(false)
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
	set_process(true)
	queue_redraw()


func is_splashing() -> bool:
	return _splash_age >= 0.0


## Plays the splash. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _splash_age < 0.0:
		set_process(false)
		return
	_splash_age += delta
	if _splash_age >= SPLASH_TIME:
		_splash_age = -1.0
		set_process(false)
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
	result.merge(seam_pixels(_run.scorpio.map.seam, middle, _run.sky_rect), true)
	if _splash_age >= 0.0:
		var step: int = mini(floori(_splash_age / SPLASH_TIME * SPLASH_RADII.size()), SPLASH_RADII.size() - 1)
		result.merge(ring_pixels(_splash_at, SPLASH_RADII[step], SPLASH_COLOURS[step]), true)
	return result


## The seam through `middle` (any point on it), an N4 pixel every SEAM_GAP across the sky.
static func seam_pixels(seam: StarMap.Seam, middle: Vector2i, sky: Rect2i) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if seam == StarMap.Seam.VERTICAL:
		for y: int in range(sky.position.y, sky.end.y, SEAM_GAP):
			result[Vector2i(middle.x, y)] = Palette.N4
	elif seam == StarMap.Seam.HORIZONTAL:
		for x: int in range(sky.position.x, sky.end.x, SEAM_GAP):
			result[Vector2i(x, middle.y)] = Palette.N4
	return result


## A ring of `radius` round `at`, on whole pixels.
static func ring_pixels(at: Vector2i, radius: int, colour: Color) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in 24:
		var angle: float = TAU * i / 24.0
		result[at + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round())] = colour
	return result
