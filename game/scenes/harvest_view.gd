class_name HarvestView
extends Node2D
## Virgo's harvest, over the sky. While the player aims the launch that brings the harvest, each
## loose star the scythe will reap wears its own outline dotted in ember (S4), and each constellation
## star the harvest will put out (bound sheaves) a dotted ember ring. The harvest itself: a scythe's
## blade sweeps the sky left to right over SWEEP_TIME, a crescent bowed toward where it's going
## (C0 edge, then C1, C2, and a dotted C3 wake), cutting each star as it passes; chaff falls from
## where a cut star stood (C2, then C3, then S4). A constellation star put out flares ember and
## drops its sparks. Drawn above the stars. The core supplies every reap and put-out.

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

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
var _sweep_time: float = -1.0
var _chaff: Dictionary[Vector2i, float] = {}
var _put_outs: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_sweep_time = -1.0
	_chaff.clear()
	_put_outs.clear()
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


## A constellation star put out at `at`.
func flash_put_out(at: Vector2i) -> void:
	_put_outs[at] = 0.0
	queue_redraw()


## Moves the blade, the chaff and the put-outs on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _sweep_time >= 0.0:
		_sweep_time += delta
		if _sweep_time >= SWEEP_TIME:
			_sweep_time = -1.0
	for flashes: Dictionary[Vector2i, float] in [_chaff, _put_outs]:
		var lasts: float = CHAFF_TIME if flashes == _chaff else PUT_OUT_TIME
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
	if aiming and (_sequencer == null or not _sequencer.is_busy()):
		result.merge(preview_pixels(_run))
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
		var at: Vector2i = run.scorpio.landmark_position(index)
		var radius: int = StarView.half_extent(run.scorpio.map.sizes[index] as Star.Size) + 3
		for offset: Vector2i in ConstellationView.circle_pixels(radius):
			if (offset.x + offset.y) % 2 == 0:
				result[at + offset] = Palette.S4
	return result


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
