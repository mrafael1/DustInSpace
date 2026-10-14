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
## the stars come out across the seam with the burst. Both seams (a cross) draw both lines. No link
## can cross the seam: a step refused for it lights the line (M5) for the rejection's shake.
## The splash (from the Knot): where the planet went in, a water ring spreads out to the splash's
## reach in hard steps (M5, M4, M3) over RIPPLE_TIME as the stars it pushes drift; a star pushed out
## of the sky cuts out at the edge in a burst of droplets (M5, then M4) over LOSS_TIME. While aiming,
## the splash's reach rings where it will splash (the aim; a split planet's twins) (an M4 dot every REACH_GAP px), each star it would push shows where it goes
## (M5 brackets, as a current's), and each it would push out trails ember dots out the way it goes.

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
const RIPPLE_TIME: float = 0.3
const RIPPLE_COLOURS: Array[Color] = [Palette.M5, Palette.M4, Palette.M3]
const LOSS_TIME: float = 0.3
## A star the aim would push out trails this many ember dots, a pixel apart, out from its edge.
const TRAIL_DOTS: int = 4
## The aim's reach ring: a dot about every REACH_GAP px round it.
const REACH_GAP: float = 3.0

## The telescope aims (Main sets it each frame, with `aim`): the splash's preview shows.
var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var aim: Vector2i = Vector2i.ZERO:
	set(value):
		if aim != value:
			aim = value
			queue_redraw()

var _run: RunState
## Seconds the seam has shimmered, for its glints' drift.
var _time: float = 0.0
## A link step refused for crossing the seam: the line glows M5 for this many seconds more.
var _blocking_left: float = 0.0
## The splash playing: where, and the seconds since it began (-1: none).
var _splash_at: Vector2i = Vector2i.ZERO
var _splash_age: float = -1.0
## The splash's ripple playing: where, and the seconds since it began (-1: none).
var _ripple_at: Vector2i = Vector2i.ZERO
var _ripple_age: float = -1.0
## Stars lost to a splash cutting out: where each left the sky, and the seconds since.
var _losses: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	set_process(has_seam())


func setup(run: RunState) -> void:
	_run = run
	_splash_age = -1.0
	_ripple_age = -1.0
	_blocking_left = 0.0
	_losses.clear()
	aiming = false
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


## The planet splashed at `at`: the water ring spreads out to the splash's reach.
func ripple(at: Vector2i) -> void:
	_ripple_at = at
	_ripple_age = 0.0
	queue_redraw()


func is_rippling() -> bool:
	return _ripple_age >= 0.0


## A star the splash pushed out of the sky cuts out at `at`, the edge it left by.
func flash_loss(at: Vector2i) -> void:
	_losses[at] = 0.0
	queue_redraw()


## A link step was refused for crossing the seam: the whole line glows for `seconds`.
func flash_block(seconds: float) -> void:
	_blocking_left = seconds
	queue_redraw()


func is_blocking() -> bool:
	return _blocking_left > 0.0


## Where a star pushed toward `to` (past the edge) leaves the sky: the sky's edge, a pixel out.
func exit_point(to: Vector2i) -> Vector2i:
	var inner: Rect2i = StarScatter.inner_rect(_run.sky_rect)
	return Vector2i(clampi(to.x, inner.position.x - 1, inner.end.x), clampi(to.y, inner.position.y - 1, inner.end.y))


## Drifts the glints and plays the splash. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	var drift: int = _drift()
	_time += delta
	if _drift() != drift:
		queue_redraw()
	if _blocking_left > 0.0:
		_blocking_left -= delta
		queue_redraw()
	for at: Vector2i in _losses.keys():
		_losses[at] += delta
		if _losses[at] >= LOSS_TIME:
			_losses.erase(at)
		queue_redraw()
	if _ripple_age >= 0.0:
		_ripple_age += delta
		if _ripple_age >= RIPPLE_TIME:
			_ripple_age = -1.0
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
	var seam: Dictionary[Vector2i, Color] = seam_pixels(_run.scorpio.map.seam, middle, _run.sky_rect, _drift())
	if _blocking_left > 0.0:
		for point: Vector2i in seam:
			if seam[point] == LINE_COLOUR:
				seam[point] = GLINT_COLOUR
	result.merge(seam, true)
	if _splash_age >= 0.0:
		var step: int = mini(floori(_splash_age / SPLASH_TIME * SPLASH_RADII.size()), SPLASH_RADII.size() - 1)
		result.merge(ring_pixels(_splash_at, SPLASH_RADII[step], SPLASH_COLOURS[step]), true)
	if _run.splash == null:
		return result
	if _ripple_age >= 0.0:
		var k: int = mini(floori(_ripple_age / RIPPLE_TIME * RIPPLE_COLOURS.size()), RIPPLE_COLOURS.size() - 1)
		@warning_ignore("integer_division")
		var radius: int = _run.splash.radius * (k + 1) / RIPPLE_COLOURS.size()
		result.merge(ring_pixels(_ripple_at, radius, RIPPLE_COLOURS[k], maxi(24, radius * 2)), true)
	for at: Vector2i in _losses:
		result.merge(droplet_pixels(at, _losses[at]), true)
	if aiming:
		result.merge(_aim_pixels(), true)
	return result


## The splash's preview for a planet thrown at `aim`: its reach, where it pushes each star, and the
## ember trail of each it pushes out.
func _aim_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var kind: String = _run.loaded_pack if _run.loaded_pack != "" else _run.balance.pack_kinds()[0]
	for at: Vector2i in _run.splash_points(kind, aim):
		result.merge(ring_pixels(at, _run.splash.radius, Palette.M4, ceili(TAU * _run.splash.radius / REACH_GAP)), true)
	var destinations: Dictionary[int, Vector2i] = _run.splash_preview(aim)
	for id: int in destinations:
		var star: Star = _run.find_star(id)
		if star == null:
			continue
		var to: Vector2i = destinations[id]
		var size: int = [4, 6, 8][star.size]
		if StarSplash.leaves(to, _run.sky_rect):
			# Ember dots trail out from it the way it's pushed: it's going.
			var way: Vector2 = Vector2(to - star.position).normalized()
			for dot: int in TRAIL_DOTS:
				result[star.position + Vector2i((way * (StarView.half_extent(star.size) + 3 + 2 * dot)).round())] = Palette.S4
			continue
		for side: int in [-1, 1]:
			for dy: int in [-1, 0, 1]:
				result[to + Vector2i(side * size, dy)] = Palette.M5
	return result


## A star cutting out at `at`, `age` seconds in: droplets flying out from it, M5 then M4.
static func droplet_pixels(at: Vector2i, age: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var k: int = mini(floori(age / LOSS_TIME * 3.0), 2)
	var colour: Color = Palette.M5 if k < 2 else Palette.M4
	var out: int = 1 + k * 2
	for way: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var reach: int = out if way.x == 0 or way.y == 0 else maxi(1, out - 1)
		result[at + way * reach] = colour
	if k == 0:
		result[at] = Palette.M5
	return result


## The seam through `middle` (any point on it) across the sky, its glints moved `drift` px along.
static func seam_pixels(seam: StarMap.Seam, middle: Vector2i, sky: Rect2i, drift: int = 0) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if seam == StarMap.Seam.NONE:
		return result
	if seam == StarMap.Seam.CROSS:
		result.merge(seam_pixels(StarMap.Seam.HORIZONTAL, middle, sky, drift), true)
		result.merge(seam_pixels(StarMap.Seam.VERTICAL, middle, sky, drift), true)
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


## A ring of `radius` round `at` (`dots` of them), on whole pixels.
static func ring_pixels(at: Vector2i, radius: int, colour: Color, dots: int = 24) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in dots:
		var angle: float = TAU * i / float(dots)
		result[at + Vector2i((Vector2(cos(angle), sin(angle)) * radius).round())] = colour
	return result


func _drift() -> int:
	return floori(_time * GLINT_SPEED)
