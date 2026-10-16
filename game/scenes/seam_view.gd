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
## (HarvestView.lone_ring_pixels), so the stars it will take show the whole time. The final's great
## wave cues both sides at once, every loose star ringed; it rushes both ways and crashes on both
## edges. The cue follows
## the run only while `settled` (nothing playing), so it never shows the next side before this
## wave has played. The wave itself plays in three beats (sweep_pixels):
## - wind-up (WINDUP_TIME): the swell rears up to twice its height, its foam lit, the chevrons
##   racing out, and the rings on the stars it will take crawl fast;
## - rush (SWEEP_TIME): a rolling wall slams out from the line, fast then slowing as it nears the
##   sky's edge: an M6 foam crest whose curls roll along it, spray flung ahead, a solid M5/M4 body
##   thickening as it goes and M3 streaks trailing behind; each star it takes flashes (an M6 ring)
##   as it reaches it, and is carried on to the edge, where it bursts in droplets;
## - crash (CRASH_TIME, not waited for): the wall breaks on the edge in a white flash, foam spray
##   thrown back into the sky falling as it cools (M6, M5, M4), and a dithered backwash running back
##   down to the line.
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
## The wave: it rears up for WINDUP_TIME, crosses its side of the sky in SWEEP_TIME and crashes on
## the edge for CRASH_TIME (only the first two are waited for).
const WINDUP_TIME: float = 0.18
const SWEEP_TIME: float = 0.42
const CRASH_TIME: float = 0.4
## The wall's solid body behind its foam, px: WALL_MIN as it sets off, WALL_MAX at the edge.
const WALL_MIN: int = 3
const WALL_MAX: int = 7
## Its dithered tail behind the body, px, and the M3 streaks trailing behind that.
const SWEEP_WAKE: int = 6
const STREAK_LENGTH: int = 22
## The curls roll along the crest CURL_SPEED px a second.
const CURL_SPEED: float = 40.0
## A star the wave reaches flashes an M6 ring for CATCH_FLASH.
const CATCH_FLASH: float = 0.1
## The crash's spray: SPRAY droplets thrown back off the edge at SPRAY_SPEED px a second (plus up
## to SPRAY_SPREAD), falling back at SPRAY_FALL px a second squared; every SPRAY_BIG-th is a 2x2 clump.
const SPRAY: int = 64
const SPRAY_SPEED: float = 70.0
const SPRAY_SPREAD: int = 110
const SPRAY_FALL: float = 520.0
const SPRAY_BIG: int = 3
## The crash's flash: FLASH_ROWS px of foam along the edge for the first FLASH_SHARE of it.
const FLASH_ROWS: int = 5
const FLASH_SHARE: float = 0.18
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
var _cue_way: Vector2i = Vector2i.ZERO
## The wave playing: its side, and the seconds since it began (-1: none).
var _sweep_way: Vector2i = Vector2i.ZERO
var _sweep_age: float = -1.0
## The side cued once the wave playing is over.
var _next_cue: Vector2i = Vector2i.ZERO
## The cued wave is the great one (both sides); the wave playing is.
var _cue_great: bool = false
var _sweep_great: bool = false
## Where the stars the wave playing takes stand, as it sets off.
var _caught: Array[Vector2i] = []
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
	_cue_way = Vector2i.ZERO
	_cue_great = false
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


## The wave wipes `side` (StarWave.LOW or HIGH), taking the stars at `caught`; the next one sweeps
## `next_way`, cued once it has played. `great`: the great wave, rushing both ways off the line
## `way` crosses.
func sweep(way: Vector2i, next_way: Vector2i, caught: Array[Vector2i] = [], great: bool = false) -> void:
	_sweep_way = way
	_sweep_great = great
	_sweep_age = 0.0
	_cue_way = Vector2i.ZERO
	_next_cue = next_way
	_caught = caught
	queue_redraw()


## The wave is playing (its crash too).
func is_sweeping() -> bool:
	return _sweep_age >= 0.0


## How long the wave is waited for: its wind-up and its rush.
static func sweep_hold() -> float:
	return WINDUP_TIME + SWEEP_TIME


## The way the cued wave will rush (ZERO: none comes).
func cue_way() -> Vector2i:
	return _cue_way


## Whether the cued wave is the great one (both sides).
func cue_great() -> bool:
	return _cue_great


## The way a great wave rushing off the line `way` crosses takes a star at `point`: toward the edge
## on its side of the line (on the line: `way` itself).
func way_for(way: Vector2i, point: Vector2i) -> Vector2i:
	var across: int = (point.x - _run.wave.middle.x) if way.x != 0 else (point.y - _run.wave.middle.y)
	return -way if across < 0 else way


## Seconds after the wave sets off (wind-up included) that it reaches `point`, on its way from the
## line to the edge.
func sweep_delay(way: Vector2i, point: Vector2i) -> float:
	var vertical: bool = way.x != 0
	var across: int = point.x if vertical else point.y
	var d: float = clampf(float(absi(across - line_of(way))) / maxf(1.0, float(_sweep_span(way))), 0.0, 1.0)
	return WINDUP_TIME + rush_time(d) * SWEEP_TIME


## Where the wall is `k` (0 to 1) of the way through its rush, as a share of the way to the edge:
## fast off the line, slowing as it nears the edge.
static func rush_reach(k: float) -> float:
	var c: float = clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - c) * (1.0 - c)


## The share of the rush (0 to 1) at which the wall has come `d` of the way to the edge.
static func rush_time(d: float) -> float:
	return 1.0 - sqrt(1.0 - clampf(d, 0.0, 1.0))


## Where a star the wave rushing `way` catches at `at` is carried to: the sky's edge that way, in
## line with it.
func carry_point(way: Vector2i, at: Vector2i) -> Vector2i:
	var inner: Rect2i = StarScatter.inner_rect(_run.sky_rect)
	if way.x != 0:
		return Vector2i(inner.position.x if way.x < 0 else inner.end.x - 1, at.y)
	return Vector2i(at.x, inner.position.y if way.y < 0 else inner.end.y - 1)


## The water line a wave rushing `way` rises off: x of the line up and down, else y of the line
## across.
func line_of(way: Vector2i) -> int:
	return _run.wave.middle.x if way.x != 0 else _run.wave.middle.y


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
		if _sweep_age >= WINDUP_TIME + SWEEP_TIME + CRASH_TIME:
			_sweep_age = -1.0
			_cue_way = _next_cue if _run.wave != null and _run.wave.strikes_next() and not _run.is_over() else Vector2i.ZERO
			_cue_great = _cue_way != Vector2i.ZERO and _run.wave.great_next()
		queue_redraw()
	if _run != null and _run.wave != null and _cue_way != Vector2i.ZERO and floori(_time / MARCH_STEP) != floori((_time - delta) / MARCH_STEP):
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
	var middle: Vector2i = Scorpio.HOME_SKY.get_center() + _run.scorpio.shift
	var seam: Dictionary[Vector2i, Color] = seam_pixels(_run.seam, middle, _run.sky_rect, _drift())
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
		result.merge(sweep_pixels(_sweep_way.x + _sweep_way.y, line_of(_sweep_way), _sweep_way.x != 0, _run.sky_rect, _sweep_age), true)
		if _sweep_great:
			result.merge(sweep_pixels(-(_sweep_way.x + _sweep_way.y), line_of(_sweep_way), _sweep_way.x != 0, _run.sky_rect, _sweep_age), true)
		for at: Vector2i in _caught:
			var reached: float = _sweep_age - sweep_delay(way_for(_sweep_way, at) if _sweep_great else _sweep_way, at)
			if reached < 0.0:
				# Still to come: its ring crawls fast.
				result.merge(HarvestView.lone_ring_pixels(at, Star.Size.MEDIUM, _sweep_age * 3.0), true)
			elif reached < CATCH_FLASH:
				result.merge(ring_pixels(at, 4 + roundi(reached / CATCH_FLASH * 3.0), Palette.M6, 20), true)
		return result
	if _cue_way == Vector2i.ZERO:
		return result
	result.merge(wave_cue_pixels(_cue_way.x + _cue_way.y, line_of(_cue_way), _cue_way.x != 0, _run.sky_rect, _time), true)
	if _cue_great:
		result.merge(wave_cue_pixels(-(_cue_way.x + _cue_way.y), line_of(_cue_way), _cue_way.x != 0, _run.sky_rect, _time), true)
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


## The wave on `side` of the line at `line` across `sky`, `age` seconds after it set off: rearing up
## (WINDUP_TIME), rushing out to the edge (SWEEP_TIME), then crashing on it (CRASH_TIME).
static func sweep_pixels(side: int, line: int, vertical: bool, sky: Rect2i, age: float) -> Dictionary[Vector2i, Color]:
	if age < WINDUP_TIME:
		return _windup_pixels(side, line, vertical, sky, age / WINDUP_TIME)
	if age < WINDUP_TIME + SWEEP_TIME:
		return _rush_pixels(side, line, vertical, sky, (age - WINDUP_TIME) / SWEEP_TIME, age)
	return _crash_pixels(side, line, vertical, sky, (age - WINDUP_TIME - SWEEP_TIME) / CRASH_TIME)


## The sky's edge on `side`, across the line.
static func sweep_edge(side: int, vertical: bool, sky: Rect2i) -> int:
	if vertical:
		return sky.position.x if side < 0 else sky.end.x - 1
	return sky.position.y if side < 0 else sky.end.y - 1


## The swell rearing up, `k` (0 to 1) of the way: up to twice its height, its crest all foam, and the
## chevrons racing out, flickering S4 and S3.
static func _windup_pixels(side: int, line: int, vertical: bool, sky: Rect2i, k: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var start: int = sky.position.y if vertical else sky.position.x
	var length: int = sky.size.y if vertical else sky.size.x
	var grow: float = 1.0 + clampf(k, 0.0, 1.0)
	for t: int in length:
		var high: int = roundi(SWELL[posmod(t, SWELL.size())] * grow)
		for h: int in range(2, high):
			if (t + h) % 2 == 0 or h >= high - 2:
				_put_in(result, vertical, sky, start + t, line + side * h, Palette.M4 if h >= high - 2 else Palette.M3)
		_put_in(result, vertical, sky, start + t, line + side * high, Palette.M6)
	var march: int = roundi(k * 14.0)
	var flicker: bool = floori(k * 6.0) % 2 == 0
	@warning_ignore("integer_division")
	for t: int in range(CHEVRON_PERIOD / 2, length, CHEVRON_PERIOD):
		for pair: int in 2:
			var tip: int = line + side * (CHEVRON_GAP + march + pair * 4 + 3)
			var colour: Color = Palette.S4 if (pair == 0) == flicker else Palette.S3
			_put_in(result, vertical, sky, start + t, tip, colour)
			for w: int in [1, 2, 3]:
				_put_in(result, vertical, sky, start + t - w, tip - side * w, colour)
				_put_in(result, vertical, sky, start + t + w, tip - side * w, colour)
	return result


## The wall `k` (0 to 1) through its rush (`age`: the wave's seconds, for its rolling curls and
## spray): its foam crest with curls rolling along it, spray flung ahead, a solid M5/M4 body
## thickening as it goes, a dithered M4 tail and M3 streaks trailing behind.
static func _rush_pixels(side: int, line: int, vertical: bool, sky: Rect2i, k: float, age: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var start: int = sky.position.y if vertical else sky.position.x
	var length: int = sky.size.y if vertical else sky.size.x
	var edge: int = sweep_edge(side, vertical, sky)
	var reach: float = rush_reach(k)
	var front: int = line + roundi(reach * (edge - line))
	var body: int = WALL_MIN + roundi(reach * (WALL_MAX - WALL_MIN))
	var roll: int = floori(age * CURL_SPEED)
	var frame: int = floori(age * 30.0)
	for t: int in length:
		var u: int = posmod(t + roll, CREST_SHAPE.size())
		var crest: int = front + side * CREST_SHAPE[u]
		# The curl: where the crest peaks, its lip leans a pixel further on.
		if CREST_SHAPE[u] == CREST_SHAPE.max():
			_put_in(result, vertical, sky, start + t, crest + side, Palette.M6)
		_put_in(result, vertical, sky, start + t, crest, Palette.M6)
		for w: int in range(1, body + 1):
			if (crest - side * w - line) * side > 0:
				_put_in(result, vertical, sky, start + t, crest - side * w, Palette.M5 if w <= 2 else Palette.M4)
		for w: int in range(body + 1, body + 1 + SWEEP_WAKE):
			var p: int = crest - side * w
			if (p - line) * side > 0 and (t + w) % 2 == 0:
				_put_in(result, vertical, sky, start + t, p, Palette.M4)
		# Streaks trailing behind, every third column, a pixel in two.
		if t % 3 == 0:
			for w: int in range(body + 1 + SWEEP_WAKE, body + 1 + SWEEP_WAKE + STREAK_LENGTH):
				var p: int = crest - side * w
				if (p - line) * side > 0 and (w + t / 3) % 2 == 0:
					_put_in(result, vertical, sky, start + t, p, Palette.M3)
		# Spray flung ahead of the crest, a few columns a frame.
		var h: int = _hash(t, frame)
		if h % 5 == 0:
			_put_in(result, vertical, sky, start + t, crest + side * (2 + h % 4), Palette.M6 if h % 2 == 0 else Palette.M5)
	return result


## The wall breaking on the edge, `k` (0 to 1) through its crash: a white flash along the edge at
## first, foam spray thrown back off it falling as it cools (M6, M5, M4), and a dithered backwash
## running back down to the line, thinning.
static func _crash_pixels(side: int, line: int, vertical: bool, sky: Rect2i, k: float) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var start: int = sky.position.y if vertical else sky.position.x
	var length: int = sky.size.y if vertical else sky.size.x
	var edge: int = sweep_edge(side, vertical, sky)
	var c: float = clampf(k, 0.0, 1.0)
	if c < FLASH_SHARE:
		for t: int in length:
			for w: int in FLASH_ROWS:
				if w < 3 or (t + w) % 2 == 0:
					_put_in(result, vertical, sky, start + t, edge - side * w, Palette.M6 if w < 2 else Palette.M5)
	var seconds: float = c * CRASH_TIME
	for i: int in SPRAY:
		var h: int = _hash(i, 7)
		var along: float = (i + 0.5) * length / float(SPRAY) + float(h % 7 - 3)
		# Thrown back into the sky, sideways a little, and falling back toward the edge; each cools as
		# it goes, the slow ones first.
		var speed: float = SPRAY_SPEED + float(h % SPRAY_SPREAD)
		var out: float = speed * seconds - SPRAY_FALL * 0.5 * seconds * seconds
		var sideways: float = float(h % 41 - 20) * seconds
		if out < 0.0:
			continue
		var cool: float = c * (1.4 - (speed - SPRAY_SPEED) / float(SPRAY_SPREAD) * 0.6)
		var colour: Color = Palette.M6 if cool < 0.35 else Palette.M5 if cool < 0.7 else Palette.M4
		var p: int = start + roundi(along + sideways)
		var q: int = edge - side * roundi(out)
		_put_in(result, vertical, sky, p, q, colour)
		if i % SPRAY_BIG == 0 and c < 0.6:
			_put_in(result, vertical, sky, p + 1, q, colour)
			_put_in(result, vertical, sky, p, q - side, colour)
			_put_in(result, vertical, sky, p + 1, q - side, colour)
	var back: int = edge + roundi(rush_reach(c) * (line - edge))
	var gap: int = 2 if c < 0.5 else 4
	for t: int in length:
		if t % gap == 0:
			_put_in(result, vertical, sky, start + t, back + side * CREST_SHAPE[posmod(t, CREST_SHAPE.size())], Palette.M5 if c < 0.5 else Palette.M4)
	return result


## A small deterministic scramble of `a` and `b` (no random numbers drawn), non-negative.
static func _hash(a: int, b: int) -> int:
	var x: int = (a * 374761393 + b * 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return x ^ (x >> 16)


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
	var way: Vector2i = _run.wave.next_way() if _run.wave.strikes_next() and not _run.is_over() else Vector2i.ZERO
	var great: bool = way != Vector2i.ZERO and _run.wave.great_next()
	if way != _cue_way or great != _cue_great:
		_cue_way = way
		_cue_great = great
		queue_redraw()


## From the line a wave rushing `way` rises off to the sky's edge that way, px.
func _sweep_span(way: Vector2i) -> int:
	var sky: Rect2i = _run.sky_rect
	var line: int = line_of(way)
	if way.x != 0:
		return (line - sky.position.x) if way.x < 0 else (sky.end.x - 1 - line)
	return (line - sky.position.y) if way.y < 0 else (sky.end.y - 1 - line)
