class_name HeatView
extends Node2D
## Leo's heat, over the whole stage: embers rising slowly through the sky (the cold: frost motes
## drifting down). While aiming,
## each star the next launch changes shows it: a dotted outline of the size it will grow to, in
## that size's own colour, or a dotted ember outline crowned with flames on a star that will burn out. Drawn above the
## halos and below the links and stars. The core supplies every change; pack contents stay hidden.

## The motes: one per MOTE_AREA px² of the sky, rising MOTE_SPEED px/s (falling in the cold),
## each by a fixed hash so the pattern is stable. A head pixel and a dimmer one behind it.
const MOTE_AREA: int = 900
const MOTE_SPEED := Vector2i(4, 9)
## The motes' head and tail: embers in the heat (never C0-C3), frost in the cold.
const HEAT_COLOURS: Array[Color] = [Palette.S3, Palette.S2]
const COLD_COLOURS: Array[Color] = [Palette.M4, Palette.M3]
## The next size's outline, in that size's own tip colour (small, medium, big).
const NEXT_COLOURS: Array[Color] = [Palette.C3, Palette.N8, Palette.M5]
## The crown of flames over a star that will burn out, from just above its ember ring's top.
const FLAMES: Dictionary[Vector2i, Color] = {
	Vector2i(0, -5): Palette.S4, Vector2i(0, -4): Palette.S4, Vector2i(0, -3): Palette.S4, Vector2i(0, -2): Palette.S3, Vector2i(0, -1): Palette.S3,
	Vector2i(-2, -3): Palette.S4, Vector2i(-2, -2): Palette.S4, Vector2i(-2, -1): Palette.S3,
	Vector2i(2, -3): Palette.S4, Vector2i(2, -2): Palette.S4, Vector2i(2, -1): Palette.S3,
}
## A burnt star's embers: BURN_SPARKS rising and spreading from where it stood for BURN_TIME,
## S4 then S3, in hard steps.
const BURN_TIME: float = 0.5
const BURN_SPARKS: int = 7
const BURN_RISE := Vector2(26.0, 46.0)

var aiming: bool = false:
	set(value):
		if aiming != value:
			aiming = value
			queue_redraw()
var _run: RunState
var _sequencer: EventSequencer
## Seconds the motes have moved.
var _time: float = 0.0
## Burns playing: where, and the seconds since.
var _burns: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	set_process(false)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	aiming = false
	_burns.clear()
	set_process(run.heat != null)
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()


## Moves the motes and any burns on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_time += delta
	for at: Vector2i in _burns.keys():
		_burns[at] += delta
		if _burns[at] >= BURN_TIME:
			_burns.erase(at)


## Plays a star burning out at `at`.
func flash_burn(at: Vector2i) -> void:
	_burns[at] = 0.0
	queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if _run == null or _run.heat == null:
		return result
	if not _run.is_over() or not _burns.is_empty():
		var colours: Array[Color] = HEAT_COLOURS if _run.heat.change > 0 else COLD_COLOURS
		result.merge(mote_pixels(_run.sky_rect, _run.heat.change, _time, colours))
	for at: Vector2i in _burns:
		result.merge(burn_pixels(at, _burns[at]), true)
	if aiming and _sequencer != null and not _sequencer.is_busy():
		result.merge(preview_pixels(_run), true)
	return result


## What the next launch does, drawn round each star it changes.
static func preview_pixels(run: RunState) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for change: StarHeat.Change in run.heat_preview():
		var star: Star = run.find_star(change.star_id)
		if star == null:
			continue
		if change.lost:
			# Its own outline, dotted ember (it's going), crowned with flames.
			for offset: Vector2i in StarView.outline_pixels(star.size):
				if (offset.x + offset.y) % 2 == 0:
					result[star.position + offset] = Palette.S4
			var top := Vector2i(0, -StarView.half_extent(star.size) - 2)
			for offset: Vector2i in FLAMES:
				result[star.position + top + offset] = FLAMES[offset]
			continue
		if change.to < change.from:
			continue
		for offset: Vector2i in StarView.outline_pixels(change.to):
			# Dotted, one pixel in two, so it never reads as the selection ring.
			if (offset.x + offset.y) % 2 == 0:
				result[star.position + offset] = NEXT_COLOURS[change.to]
	return result


## The motes at `time` seconds: rising through `area` in the heat (`change` +1), falling in the
## cold, each wrapping round once it has left. Whole pixels only, no fades.
static func mote_pixels(area: Rect2i, change: int, time: float, colours: Array[Color]) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if not area.has_area():
		return pixels
	for i: int in maxi(1, area.get_area() / MOTE_AREA):
		var h: int = CurrentView._hash(i + 7919)
		var speed: int = MOTE_SPEED.x + (h / 7) % (MOTE_SPEED.y - MOTE_SPEED.x + 1)
		var travelled: int = (h / 13 + floori(time * speed)) % area.size.y
		# A rising ember wavers a pixel either side as it goes.
		var x: int = area.position.x + 1 + (h / 101) % maxi(1, area.size.x - 2) + ((travelled / 5) % 2)
		var y: int = area.end.y - 1 - travelled if change > 0 else area.position.y + travelled
		pixels[Vector2i(x, y)] = colours[0]
		var behind := Vector2i(x, y + change)
		if area.has_point(behind):
			pixels[behind] = colours[1]
	return pixels


## A burnt star's embers `t` seconds after it burned at `at`: a flare, then sparks rising and
## spreading as they cool.
static func burn_pixels(at: Vector2i, t: float) -> Dictionary[Vector2i, Color]:
	var pixels: Dictionary[Vector2i, Color] = {}
	if t < 0.0 or t >= BURN_TIME:
		return pixels
	if t < 0.08:
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			for k: int in range(1, 4):
				pixels[at + d * k] = Palette.S4
	for i: int in BURN_SPARKS:
		var spread: float = (float(i) / (BURN_SPARKS - 1) - 0.5) * 1.6
		var rise: float = lerpf(BURN_RISE.x, BURN_RISE.y, float((i * 3) % BURN_SPARKS) / (BURN_SPARKS - 1))
		var k: float = t / BURN_TIME
		var spark := Vector2(spread * rise * k, -rise * k * (2.0 - k))
		pixels[at + Vector2i(spark.round())] = Palette.S4 if k < 0.5 else Palette.S3
	return pixels
