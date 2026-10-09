class_name HarvestView
extends Node2D
## Virgo's harvest, over the sky. While the player aims the launch that brings the harvest, each
## loose star the scythe will reap wears its own outline dotted in ember (S4), and each constellation
## star the harvest will put out (bound sheaves) the lone ring. The harvest itself: a scythe's
## blade sweeps the sky left to right over SWEEP_TIME, a crescent bowed toward where it's going
## (C0 edge, then C1, C2, and a dotted C3 wake), cutting each star as it passes; chaff falls from
## where a cut star stood (C2, then C3, then S4). A constellation star put out is cropped (playtest:
## make it juicy, feel cut): the blade catches it (it trembles and flickers white), a white slash
## cuts across it, it splits along the slash, the top half
## sliding off up and right and the bottom half dropping away down and left as both cool from gold
## to ember in hard steps; ember sparks spray along the cut, and the strings that joined it snap,
## flaring ember and pulling back toward their other ends. Drawn above the stars. The core supplies
## every reap and put-out.
## Bound sheaves, always (playtest: the rule wasn't understood): a lit constellation star that is
## alone (not joined to the lit figure) wears an ember ring whose pixels crawl round it, from the
## moment it's lit until it's joined or put out, so the risk shows at once. The binding intro's
## kept star glints gold: a ring of C0, then C1, then C2 spreading out.

## The blade crosses the sky in SWEEP_TIME, bowed BOW px at the middle of its height.
const SWEEP_TIME: float = 0.6
const BOW: int = 14
const BLADE: Array[Color] = [Palette.C0, Palette.C1, Palette.C2]
const WAKE: Color = Palette.C3
const WAKE_LENGTH: int = 6
## A cut star's chaff: CHAFF bits falling and spreading for CHAFF_TIME.
const CHAFF: int = 6
const CHAFF_TIME: float = 0.5
const CHAFF_FALL := Vector2(10.0, 24.0)
const CHAFF_COLOURS: Array[Color] = [Palette.C2, Palette.C3, Palette.S4]
## A constellation star put out: an ember cross and a ring cooling outward for PUT_OUT_TIME.
const PUT_OUT_TIME: float = 0.45
const PUT_OUT_COLOURS: Array[Color] = [Palette.S4, Palette.S3, Palette.S2]
## A cropped constellation star: CROP_TIME in all; the slash shows for CROP_SLASH, the halves part
## CROP_PART px each, the lower one falling CROP_FALL px more; CROP_SPARKS sparks along the cut.
const CROP_TIME: float = 0.6
## First the blade catches it: the whole star trembles a pixel and flickers C0 for CROP_CHARGE.
const CROP_CHARGE: float = 0.12
const CROP_SLASH: float = 0.1
const CROP_PART: int = 4
const CROP_FALL: int = 7
const CROP_SPARKS: int = 8
## The halves cool through these, in hard steps (their own art first).
const CROP_COOL: Array[Color] = [Palette.C2, Palette.S4, Palette.S3]
## A snapped string keeps clear of the stars at its ends by this many px, as strings do.
const STRING_CLEAR: int = 4
## A lone lit star's ring crawls a dot every CRAWL_STEP.
const CRAWL_STEP: float = 0.25
## The lone ring sits LONE_GAP px clear of its star, at least LONE_MIN px out.
const LONE_GAP: int = 4
const LONE_MIN: int = 7
## The intro's kept star: a gold ring spreading for KEPT_TIME.
const KEPT_TIME: float = 0.45
const KEPT_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2]

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
## The constellation star the link being traced would light alone (RunState.link_lights_alone), which
## wears its lone ring before the link is made (#149), or -1.
var tracing_alone: int = -1:
	set(value):
		if tracing_alone != value:
			tracing_alone = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
var _sweep_time: float = -1.0
var _chaff: Dictionary[Vector2i, float] = {}
var _put_outs: Dictionary[Vector2i, float] = {}
var _kept: Dictionary[Vector2i, float] = {}
## Stars being cropped, by place: [seconds since, size, the far ends of the strings that snapped].
var _crops: Dictionary[Vector2i, Array] = {}
## The binding intro's star lit alone (presentation only: the run never lit it), by place, with the
## size it's drawn at.
var _alone_shown: Dictionary[Vector2i, int] = {}
## The lone stars' rings as they stood when the sky last went still, by place, with their size: they
## stay on through a launch until the scythe cuts each (#149: they vanished as the launch played).
var _lone_shown: Dictionary[Vector2i, int] = {}
var _time: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	tracing_alone = -1
	_sweep_time = -1.0
	_chaff.clear()
	_put_outs.clear()
	_kept.clear()
	_crops.clear()
	_alone_shown.clear()
	_lone_shown.clear()
	set_process(run.harvest != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## Starts the blade's sweep. Returns how long it takes.
func sweep() -> float:
	_sweep_time = 0.0
	queue_redraw()
	return SWEEP_TIME


func is_sweeping() -> bool:
	return _sweep_time >= 0.0


## Seconds after the sweep starts that the blade reaches column `x`.
func cut_delay(x: int) -> float:
	var sky: Rect2i = _run.sky_rect
	return clampf(float(x - sky.position.x) / maxi(1, sky.size.x), 0.0, 1.0) * SWEEP_TIME


## A star cut at `at`: its chaff falls.
func flash_chaff(at: Vector2i) -> void:
	_chaff[at] = 0.0
	queue_redraw()


## A constellation star put out at `at` (its lone ring goes with it).
func flash_put_out(at: Vector2i) -> void:
	_put_outs[at] = 0.0
	_alone_shown.erase(at)
	queue_redraw()


## A constellation star of `size` at `at` is cropped by the scythe, `delay` from now (the blade
## reaching it; its lone ring stays on until then); `ends`: the far ends of the lit strings that
## joined it, which snap.
func flash_crop(at: Vector2i, size: int, ends: Array[Vector2i], delay: float = 0.0) -> void:
	_crops[at] = [-delay, size, ends.duplicate()]
	queue_redraw()


func is_cropping() -> bool:
	return not _crops.is_empty()


## The binding intro: a star of `size` shown lit alone at `at` wears the lone ring until put out.
func show_alone(at: Vector2i, size: int) -> void:
	_alone_shown[at] = size
	queue_redraw()


## The star at `at`, joined to the figure, was kept by the harvest: it glints gold, `delay` from now
## (the blade passing it).
func flash_kept(at: Vector2i, delay: float = 0.0) -> void:
	_kept[at] = -delay
	queue_redraw()


## Moves the blade, the chaff and the put-outs on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	if _sweep_time >= 0.0:
		_sweep_time += delta
		if _sweep_time >= SWEEP_TIME:
			_sweep_time = -1.0
	if _run != null and _run.harvest != null and (_sequencer == null or not _sequencer.is_busy()):
		_lone_shown.clear()
		for index: int in _run.loose_landmarks():
			_lone_shown[_run.scorpio.landmark_position(index)] = _run.scorpio.map.sizes[index]
	for at: Vector2i in _crops.keys():
		_crops[at][0] += delta
		if _crops[at][0] >= 0.0:
			# Cut: its ring goes with it.
			_alone_shown.erase(at)
			_lone_shown.erase(at)
		if _crops[at][0] >= CROP_TIME:
			_crops.erase(at)
	for flashes: Dictionary[Vector2i, float] in [_chaff, _put_outs, _kept]:
		var lasts: float = CHAFF_TIME if flashes == _chaff else (KEPT_TIME if flashes == _kept else PUT_OUT_TIME)
		for at: Vector2i in flashes.keys():
			flashes[at] += delta
			if flashes[at] >= lasts:
				flashes.erase(at)


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point])


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.harvest == null:
		return result
	var idle: bool = _sequencer == null or not _sequencer.is_busy()
	# Still, the core's lone stars; while a sequence plays, those that stood alone as it began, until
	# the scythe cuts each.
	var rings: Dictionary[Vector2i, int] = {}
	if idle:
		for index: int in _run.loose_landmarks():
			rings[_run.scorpio.landmark_position(index)] = _run.scorpio.map.sizes[index]
	else:
		rings = _lone_shown.duplicate()
	rings.merge(_alone_shown)
	for at: Vector2i in rings:
		if not (_crops.has(at) and _crops[at][0] >= 0.0):
			result.merge(lone_ring_pixels(at, rings[at], _time), true)
	if tracing_alone >= 0:
		result.merge(lone_ring_pixels(_run.scorpio.landmark_position(tracing_alone), _run.scorpio.map.sizes[tracing_alone], _time), true)
	if aiming and idle:
		result.merge(preview_pixels(_run), true)
	for at: Vector2i in _kept:
		result.merge(kept_pixels(at, _kept[at]), true)
	for at: Vector2i in _crops:
		result.merge(crop_pixels(at, _crops[at][1], _crops[at][2], _crops[at][0]), true)
	for at: Vector2i in _chaff:
		result.merge(chaff_pixels(at, _chaff[at]), true)
	for at: Vector2i in _put_outs:
		result.merge(put_out_pixels(at, _put_outs[at]), true)
	if _sweep_time >= 0.0:
		result.merge(blade_pixels(_run.sky_rect, _sweep_time / SWEEP_TIME), true)
	return result


## What the next launch's harvest takes, drawn round each star: a loose star's outline dotted
## ember, a dotted ember ring round a constellation star it puts out. Nothing when the next launch
## doesn't bring the harvest.
static func preview_pixels(run: RunState) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for id: int in run.harvest_preview():
		var star: Star = run.find_star(id)
		for offset: Vector2i in StarView.outline_pixels(star.size):
			if (offset.x + offset.y) % 2 == 0:
				result[star.position + offset] = Palette.S4
	for index: int in run.unbound_preview():
		result.merge(lone_ring_pixels(run.scorpio.landmark_position(index), run.scorpio.map.sizes[index], 0.0), true)
	return result


## A constellation star of `size` at `at` cropped `t` seconds ago, its strings to `ends` snapping:
## the slash, the two halves of its lit art parting and cooling, the sparks, the snapped strings.
static func crop_pixels(at: Vector2i, size: int, ends: Array[Vector2i], t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= CROP_TIME:
		return pixels
	var art: Dictionary[Vector2i, Color] = ConstellationView.star_pixels(size, &"lit")
	if t < CROP_CHARGE:
		var shake := Vector2i([1, -1, 1, 0][int(t / 0.03) % 4], 0)
		for d: Vector2i in art:
			pixels[at + d + shake] = Palette.C0 if int(t / 0.04) % 2 == 0 else art[d]
		return pixels
	t -= CROP_CHARGE
	var k: float = t / (CROP_TIME - CROP_CHARGE)
	var reach: int = StarView.half_extent(size as Star.Size) + 5
	# The strings snap first, under the rest: each flares ember and pulls back toward its far end.
	for end: Vector2i in ends:
		var line: Array[Vector2i] = LinkLayer.line_pixels(at, end)
		var from: int = STRING_CLEAR + roundi(k * (line.size() - 2 * STRING_CLEAR))
		for i: int in range(from, line.size() - STRING_CLEAR):
			if k < 0.5 or i % 2 == 0:
				pixels[line[i]] = Palette.S4 if k < 0.5 else Palette.S3
	# The halves: the art either side of the slash (top left to bottom right), parting and cooling;
	# the pixels on the cut are gone.
	var cool: int = floori(k * (CROP_COOL.size() + 1)) - 1
	var part: int = roundi(minf(k * 3.0, 1.0) * CROP_PART)
	var fall: int = roundi(k * k * CROP_FALL)
	for d: Vector2i in art:
		if d.x == d.y:
			continue
		var colour: Color = art[d] if cool < 0 else CROP_COOL[mini(cool, CROP_COOL.size() - 1)]
		if t < CROP_SLASH * 0.5:
			colour = Palette.C0
		var shift: Vector2i = Vector2i(part, -part) if d.x > d.y else Vector2i(-part, part + fall)
		pixels[at + d + shift] = colour
	# Sparks spray out from the cut, either side, and fall.
	for i: int in CROP_SPARKS:
		var along: float = (float(i) / (CROP_SPARKS - 1) - 0.5) * 2.0
		var side: int = 1 if i % 2 == 0 else -1
		var spread: float = 10.0 + 8.0 * float((i * 3) % CROP_SPARKS) / CROP_SPARKS
		var p := Vector2(along * reach, along * reach) + Vector2(side, -side) * spread * k + Vector2(0, 14.0 * k * k)
		pixels[at + Vector2i(p.round())] = Palette.C2 if k < 0.4 else Palette.S4
	# The slash, over all: a white stroke across the star, thinning to C1.
	if t < CROP_SLASH:
		for i: int in range(-reach, reach + 1):
			pixels[at + Vector2i(i, i)] = Palette.C0 if t < CROP_SLASH * 0.5 or absi(i) < reach / 2 else Palette.C1
	return pixels


## A lone lit star's ring at `at` (a star of `size`) at `time`: a whole ring LONE_GAP px clear of the
## star (at least LONE_MIN px out), ember, its pixels S4 and S3 by turns round it, swapping every
## CRAWL_STEP so it crawls.
static func lone_ring_pixels(at: Vector2i, size: int, time: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	var phase: int = int(time / CRAWL_STEP) % 2
	var ring: Array[Vector2i] = ConstellationView.circle_pixels(maxi(StarView.half_extent(size as Star.Size) + LONE_GAP, LONE_MIN))
	ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).angle() < Vector2(b).angle())
	for i: int in ring.size():
		pixels[at + ring[i]] = Palette.S4 if (i / 2 + phase) % 2 == 0 else Palette.S3
	return pixels


## The binding intro's kept star `t` seconds after the scythe passed: a gold ring spreading as it
## cools, in hard steps.
static func kept_pixels(at: Vector2i, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= KEPT_TIME:
		return pixels
	var k: float = t / KEPT_TIME
	var colour: Color = KEPT_COLOURS[mini(floori(k * KEPT_COLOURS.size()), KEPT_COLOURS.size() - 1)]
	for offset: Vector2i in ConstellationView.circle_pixels(6 + roundi(k * 7.0)):
		pixels[at + offset] = colour
	return pixels


## The blade `k` (0-1) of the way across `sky`: a crescent over the sky's height, bowed toward
## the right at its middle, its edge C0 then C1 and C2 behind, a dotted C3 wake behind that.
static func blade_pixels(sky: Rect2i, k: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	var front: int = sky.position.x + roundi(clampf(k, 0.0, 1.0) * sky.size.x)
	var half: float = sky.size.y / 2.0
	for y: int in range(sky.position.y, sky.end.y):
		var u: float = (y - sky.position.y - half) / half
		var x: int = front + roundi(BOW * (1.0 - u * u)) - BOW
		for k_px: int in BLADE.size():
			_put(pixels, sky, Vector2i(x - k_px, y), BLADE[k_px])
		for w: int in range(BLADE.size(), BLADE.size() + WAKE_LENGTH):
			if (w + y) % 2 == 0:
				_put(pixels, sky, Vector2i(x - w, y), WAKE)
	return pixels


static func _put(pixels: Dictionary[Vector2i, Color], sky: Rect2i, p: Vector2i, colour: Color) -> void:
	if sky.has_point(p):
		pixels[p] = colour


## A cut star's chaff `t` seconds after it was cut at `at`: bits falling and spreading as they
## cool, in hard steps.
static func chaff_pixels(at: Vector2i, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= CHAFF_TIME:
		return pixels
	var k: float = t / CHAFF_TIME
	var colour: Color = CHAFF_COLOURS[mini(floori(k * CHAFF_COLOURS.size()), CHAFF_COLOURS.size() - 1)]
	for i: int in CHAFF:
		var spread: float = (float(i) / (CHAFF - 1) - 0.5) * 1.6
		var fall: float = lerpf(CHAFF_FALL.x, CHAFF_FALL.y, float((i * 5) % CHAFF) / (CHAFF - 1))
		pixels[at + Vector2i(Vector2(spread * fall * k, fall * k * k).round())] = colour
	return pixels


## A constellation star put out `t` seconds ago at `at`: an ember cross, then a dotted ring
## cooling as it spreads.
static func put_out_pixels(at: Vector2i, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= PUT_OUT_TIME:
		return pixels
	var k: float = t / PUT_OUT_TIME
	if t < 0.1:
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			for step: int in range(1, 4):
				pixels[at + d * step] = Palette.S4
	var colour: Color = PUT_OUT_COLOURS[mini(floori(k * PUT_OUT_COLOURS.size()), PUT_OUT_COLOURS.size() - 1)]
	for offset: Vector2i in ConstellationView.circle_pixels(5 + roundi(k * 8.0)):
		if (offset.x + offset.y) % 2 == 0:
			pixels[at + offset] = colour
	return pixels
