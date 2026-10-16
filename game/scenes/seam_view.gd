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
## The wave (the North Fish): while a wave comes with the next launch, the side it wipes shows
## (wave_cue_pixels): the water swells up off the line on that side (a dithered M3 body, an M5
## crest with M6 foam on its peaks, bobbing a pixel every BOB_STEP), and double ember chevrons
## (S4, S3) march out from it into that side; every loose star on it wears a crawling ember ring
## (HarvestView.lone_ring_pixels), so the stars it will take show the whole time. The cue follows
## the run only while `settled` (nothing playing), so it never shows the next side before this
## wave has played. The wave itself: a wall of water rushes from the line to the sky's edge on its
## side over SWEEP_TIME (an M6 foam crest, M5 under it, a dithered M4 wake), each star it takes
## cutting out in droplets as it reaches it.
## The splash (from the Knot): where the planet went in, a water ring spreads out to the splash's
## reach in hard steps (M5, M4, M3) over RIPPLE_TIME as the stars it pushes drift; a star pushed out
## of the sky, or onto the water line, cuts out there in a burst of droplets (M5, then M4) over
## LOSS_TIME. While aiming,
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
## The wave crosses its side of the sky in SWEEP_TIME.
const SWEEP_TIME: float = 0.5
## Its wake behind the foam, px (dithered).
const SWEEP_WAKE: int = 8
## The cue's swell: how high it stands off the line, round every SWELL.size() px along it.
const SWELL: Array[int] = [3, 4, 5, 6, 6, 5, 4, 3, 2, 2, 2, 3]
const RIPPLE_COLOURS: Array[Color] = [Palette.M5, Palette.M4, Palette.M3]
const LOSS_TIME: float = 0.3
## A star the aim would push out trails this many ember dots, a pixel apart, out from its edge.
const TRAIL_DOTS: int = 4
## The swell bobs a pixel up and back every BOB_STEP.
const BOB_STEP: float = 0.4
## The cue's chevrons: a pair every CHEVRON_PERIOD px along the line, from CHEVRON_GAP px off it,
## marching CHEVRON_MARCH px out and back to the start, a pixel every MARCH_STEP.
const CHEVRON_PERIOD: int = 36
const CHEVRON_GAP: int = 10
const CHEVRON_MARCH: int = 6
const MARCH_STEP: float = 0.12
## The wave's foam front, px ahead of its line, round every CREST_SHAPE.size() px along it.
const CREST_SHAPE: Array[int] = [0, 1, 1, 0, 0, -1, -1, 0]
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
## Nothing is playing (Main sets it each frame): the wave's cue follows the run.
var settled: bool = true:
	set(value):
		settled = value
		if settled:
			_follow_wave()
## The side the wave's cue shows (StarWave.LOW or HIGH; 0: none comes with the next launch).
var _cue_side: int = 0
## The wave playing: its side, and the seconds since it began (-1: none).
var _sweep_side: int = 0
var _sweep_age: float = -1.0
## The side cued once the wave playing is over.
var _next_cue: int = 0
## Stars lost to a splash cutting out: where each left the sky, and the seconds since.
var _losses: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	set_process(has_seam())


func setup(run: RunState) -> void:
	_run = run
	_splash_age = -1.0
	_ripple_age = -1.0
	_blocking_left = 0.0
	_sweep_age = -1.0
	_cue_side = 0
	_losses.clear()
	aiming = false
	_time = 0.0
	_follow_wave()
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


## The wave wipes `side` (StarWave.LOW or HIGH); the next one sweeps `next_side`, cued once it has played.
func sweep(side: int, next_side: int) -> void:
	_sweep_side = side
	_sweep_age = 0.0
	_cue_side = 0
	_next_cue = next_side
	queue_redraw()


func is_sweeping() -> bool:
	return _sweep_age >= 0.0


## The side the cue shows (0: none).
func cue_side() -> int:
	return _cue_side


## Seconds after the wave sets off that it reaches `point`, on its way from the line to the edge.
func sweep_delay(side: int, point: Vector2i) -> float:
	var wave: StarWave = _run.wave
	var across: int = point.x if wave.vertical else point.y
	return clampf(float(absi(across - wave.line)) / maxf(1.0, float(_sweep_span(side))), 0.0, 1.0) * SWEEP_TIME


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
	if _sweep_age >= 0.0:
		_sweep_age += delta
		if _sweep_age >= SWEEP_TIME:
			_sweep_age = -1.0
			_cue_side = _next_cue if _run.wave != null and _run.wave.strikes_next() and not _run.is_over() else 0
		queue_redraw()
	if _run != null and _run.wave != null and _cue_side != 0 and floori(_time / MARCH_STEP) != floori((_time - delta) / MARCH_STEP):
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
	if _run.wave != null:
		result.merge(_wave_pixels(), true)
	if _run.splash == null and _run.wave == null:
		return result
	if _ripple_age >= 0.0 and _run.splash != null:
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
## ember trail of each it pushes out; and, on a launch the wave comes with, the stars it would take,
## marked where the splash leaves them.
func _aim_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run.wave != null:
		# Where the splash leaves each star the wave would take, marked as it will be taken.
		var splashed: Dictionary[int, Vector2i] = _run.splash_preview(aim)
		for id: int in _run.launch_wipes(aim):
			var star: Star = _run.find_star(id)
			if star == null:
				continue
			result.merge(HarvestView.lone_ring_pixels(splashed.get(id, star.position), star.size, _time), true)
	if _run.splash == null:
		return result
	var kind: String = _run.loaded_pack if _run.loaded_pack != "" else _run.balance.pack_kinds()[0]
	for at: Vector2i in _run.splash_points(kind, aim):
		result.merge(ring_pixels(at, _run.splash.radius, Palette.M4, ceili(TAU * _run.splash.radius / REACH_GAP)), true)
	var destinations: Dictionary[int, Vector2i] = _run.splash_preview(aim)
	var lost: Array[int] = _run.launch_splashes(aim)
	for id: int in destinations:
		var star: Star = _run.find_star(id)
		if star == null:
			continue
		var to: Vector2i = destinations[id]
		var size: int = [4, 6, 8][star.size]
		if lost.has(id):
			# Ember dots trail out from it the way it's pushed: it's going.
			var way: Vector2 = Vector2(to - star.position).normalized()
			for dot: int in TRAIL_DOTS:
				result[star.position + Vector2i((way * (StarView.half_extent(star.size) + 3 + 2 * dot)).round())] = Palette.S4
			continue
		for side: int in [-1, 1]:
			for dy: int in [-1, 0, 1]:
				result[to + Vector2i(side * size, dy)] = Palette.M5
	return result


## The wave's part: its cue on the side it wipes next and the stars there marked (while nothing
## plays and no aim shows its own), or the wave sweeping.
func _wave_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var wave: StarWave = _run.wave
	if _sweep_age >= 0.0:
		return sweep_pixels(_sweep_side, wave.line, wave.vertical, _run.sky_rect, _sweep_age / SWEEP_TIME)
	if _cue_side == 0:
		return result
	result.merge(wave_cue_pixels(_cue_side, wave.line, wave.vertical, _run.sky_rect, _time), true)
	if settled and not aiming:
		for id: int in _run.wave_risk():
			var star: Star = _run.find_star(id)
			result.merge(HarvestView.lone_ring_pixels(star.position, star.size, _time), true)
	return result


## The cue for a wave on `side` of the line at `line` across `sky`, `time` seconds in: the water
## swelling up off the line on that side (a dithered M3 body, an M5 crest, M6 foam on its peaks),
## bobbing; and double ember chevrons marching out from it into that side.
static func wave_cue_pixels(side: int, line: int, vertical: bool, sky: Rect2i, time: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var start: int = sky.position.y if vertical else sky.position.x
	var length: int = sky.size.y if vertical else sky.size.x
	var bob: int = floori(time / BOB_STEP) % 2
	var peak: int = SWELL.max()
	for t: int in length:
		var high: int = SWELL[posmod(t, SWELL.size())] + bob
		for h: int in range(2, high):
			if (t + h) % 2 == 0:
				_put_across(result, vertical, start + t, line + side * h, Palette.M3)
		_put_across(result, vertical, start + t, line + side * high, Palette.M6 if high - bob == peak else Palette.M5)
	var march: int = floori(time / MARCH_STEP) % CHEVRON_MARCH
	@warning_ignore("integer_division")
	for t: int in range(CHEVRON_PERIOD / 2, length, CHEVRON_PERIOD):
		for pair: int in 2:
			var tip: int = line + side * (CHEVRON_GAP + march + pair * 4 + 3)
			var colour: Color = Palette.S4 if pair == 0 else Palette.S3
			_put_across(result, vertical, start + t, tip, colour)
			for w: int in [1, 2, 3]:
				_put_across(result, vertical, start + t - w, tip - side * w, colour)
				_put_across(result, vertical, start + t + w, tip - side * w, colour)
	return result


## The wave `k` (0 to 1) of the way from the line at `line` to `sky`'s edge on `side`: its foam front
## (M6) a little wavy, M5 behind it, and a dithered M4 wake back toward the line.
static func sweep_pixels(side: int, line: int, vertical: bool, sky: Rect2i, k: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var start: int = sky.position.y if vertical else sky.position.x
	var length: int = sky.size.y if vertical else sky.size.x
	var edge: int = ((sky.position.x if side < 0 else sky.end.x - 1) if vertical else (sky.position.y if side < 0 else sky.end.y - 1))
	var front: int = line + roundi(clampf(k, 0.0, 1.0) * (edge - line))
	for t: int in length:
		var crest: int = front + side * CREST_SHAPE[posmod(t, CREST_SHAPE.size())]
		_put_in(result, vertical, sky, start + t, crest, Palette.M6)
		_put_in(result, vertical, sky, start + t, crest - side, Palette.M5)
		_put_in(result, vertical, sky, start + t, crest - side * 2, Palette.M5)
		for w: int in range(3, 3 + SWEEP_WAKE):
			var p: int = crest - side * w
			if (p - line) * side > 0 and (t + w) % 2 == 0:
				_put_in(result, vertical, sky, start + t, p, Palette.M4)
	return result


static func _put_across(pixels: Dictionary[Vector2i, Color], vertical: bool, along: int, across: int, colour: Color) -> void:
	pixels[Vector2i(across, along) if vertical else Vector2i(along, across)] = colour


static func _put_in(pixels: Dictionary[Vector2i, Color], vertical: bool, sky: Rect2i, along: int, across: int, colour: Color) -> void:
	var p := Vector2i(across, along) if vertical else Vector2i(along, across)
	if sky.has_point(p):
		pixels[p] = colour


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


## The cue shows the side the next launch's wave wipes, as the run has it (none when no wave comes).
func _follow_wave() -> void:
	if _run == null or _run.wave == null or _sweep_age >= 0.0:
		return
	var side: int = _run.wave.next_side() if _run.wave.strikes_next() and not _run.is_over() else 0
	if side != _cue_side:
		_cue_side = side
		queue_redraw()


## From the line to the sky's edge on `side`, px.
func _sweep_span(side: int) -> int:
	var wave: StarWave = _run.wave
	var sky: Rect2i = _run.sky_rect
	if wave.vertical:
		return (wave.line - sky.position.x) if side < 0 else (sky.end.x - 1 - wave.line)
	return (wave.line - sky.position.y) if side < 0 else (sky.end.y - 1 - wave.line)
