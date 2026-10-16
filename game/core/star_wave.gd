class_name StarWave
extends RefCounted
## Pisces's wave (chapter 6, the North Fish): from the `first_launch`-th launch on, every launch a wave
## rises off the water line and wipes one side of the sky (top or bottom; left or right on a line up
## and down), taking every loose star there for nothing. The sides take turns, the top (or left)
## first, so the next one is always known and shown. No randomness, nodes or rewards.

## The sides a wave sweeps: the top (or left) of the line, or the bottom (or right).
const LOW: int = -1
const HIGH: int = 1

## The water line: where it crosses the sky (y on a line across, x on one up and down).
var line: int
## The line runs up and down, else across.
var vertical: bool
## The first launch a wave comes with (1: the first).
var first_launch: int
## Launches thrown since the run began (intros don't count).
var launches: int = 0
## Waves that have struck.
var waves: int = 0


func _init(p_line: int, p_vertical: bool, p_first_launch: int) -> void:
	line = p_line
	vertical = p_vertical
	first_launch = p_first_launch


## A wave comes with the next launch.
func strikes_next() -> bool:
	return launches + 1 >= first_launch


## The side the next wave sweeps: they take turns, LOW first.
func next_side() -> int:
	return LOW if waves % 2 == 0 else HIGH


## Pure: which side of the line `point` is on (0: right on it, so on both).
func side_of(point: Vector2i) -> int:
	return signi((point.x if vertical else point.y) - line)


## Pure: the ids of `stars` a wave on `side` takes: every one on that side, or on the line.
func sweeps(side: int, stars: Array[Star]) -> Array[int]:
	var taken: Array[int] = []
	for star: Star in stars:
		var on: int = side_of(star.position)
		if on == 0 or on == side:
			taken.append(star.id)
	return taken


## A launch was thrown; `struck`: its wave came.
func count_launch(struck: bool) -> void:
	launches += 1
	if struck:
		waves += 1
