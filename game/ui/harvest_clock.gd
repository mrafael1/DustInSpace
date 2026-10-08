class_name HarvestClock
extends Node2D
## Virgo's harvest clock, under the Sun: one ear of wheat per launch between two harvests, centred
## on this node. An ear still standing is a launch left; a cut one shows its stubble. Standing ears
## are cool (M5 grains on an M3 stalk); the last one, when the next launch brings the harvest, is
## ripe gold (C1 grains, C2 stalk) and sways a pixel. A launch cuts an ear with a small flare; the
## harvest grows them all back. A quickening clock grows one fewer back each harvest: the lost ear's
## place stays empty. Shown from the run's events (count), never ahead of them.

## An ear: grains either side of the stalk (x -1 and +1) on rows 0-4, the stalk down to row 8.
const EAR_ROWS: int = 9
const GRAIN_ROWS: Array[int] = [1, 3, 5]
const STUBBLE_ROWS: int = 3
const SPACING: int = 7
const COOL_GRAIN: Color = Palette.M5
const COOL_STALK: Color = Palette.M3
const RIPE_GRAIN: Color = Palette.C1
const RIPE_STALK: Color = Palette.C2
const STUBBLE: Color = Palette.M3
## The ripe ear sways a pixel each SWAY_STEP.
const SWAY_STEP: float = 0.4
## An ear just cut flashes C0 at its top for CUT_FLASH.
const CUT_FLASH: float = 0.15

var _every: int = 0
## Ears the clock grows back now (a quickening clock loses one each harvest); the rest are gone.
var _period: int = 0
var _left: int = 0
var _time: float = 0.0
var _cut: int = -1
var _cut_time: float = -1.0


## Shows a clock of `every` ears with `left` still standing (0: none, hidden).
func setup(every: int, left: int) -> void:
	_every = every
	_period = every
	_left = left
	_cut = -1
	_cut_time = -1.0
	visible = every > 0
	queue_redraw()


## The clock moved to `left` ears standing of `period`: one is cut, or (after a harvest) they grow
## back, `period` of them.
func count(left: int, period: int = -1) -> void:
	if left < _left:
		_cut = left
		_cut_time = 0.0
	_left = left
	if period > 0:
		_period = period
	queue_redraw()


## Jumps to `left` ears standing at once, with no cut (the scythe intro's demo clock).
func jump(left: int) -> void:
	_left = left
	_cut = -1
	_cut_time = -1.0
	queue_redraw()


## Ears the clock grows back now.
func period() -> int:
	return _period


func standing() -> int:
	return _left


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var sway: int = int(_time / SWAY_STEP)
	_time += delta
	if _cut_time >= 0.0:
		_cut_time += delta
		if _cut_time >= CUT_FLASH:
			_cut_time = -1.0
		queue_redraw()
	if int(_time / SWAY_STEP) != sway:
		queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])


## The clock's pixels, from this node (its centre top).
func pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	for i: int in _every:
		var x: int = roundi((i - (_every - 1) / 2.0) * SPACING)
		if i >= _period:
			continue
		if i >= _left:
			for y: int in range(EAR_ROWS - STUBBLE_ROWS, EAR_ROWS):
				dots[Vector2i(x, y)] = STUBBLE
			if i == _cut and _cut_time >= 0.0:
				dots[Vector2i(x, EAR_ROWS - STUBBLE_ROWS - 1)] = Palette.C0
			continue
		var ripe: bool = _left == 1
		var lean: int = (int(_time / SWAY_STEP) % 2) if ripe else 0
		for y: int in EAR_ROWS:
			dots[Vector2i(x + (lean if y < 5 else 0), y)] = RIPE_STALK if ripe else COOL_STALK
		for y: int in GRAIN_ROWS:
			for side: int in [-1, 1]:
				dots[Vector2i(x + side + lean, y)] = RIPE_GRAIN if ripe else COOL_GRAIN
		dots[Vector2i(x + lean, 0)] = RIPE_GRAIN if ripe else COOL_GRAIN
	return dots
