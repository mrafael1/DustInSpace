class_name StarWave
extends RefCounted
## Pisces's wave (chapter 6): from the `first_launch`-th launch on, every launch a wave rises off a
## water line and wipes the half of the sky on one side of it, taking every loose star there for
## nothing. A wave's way is where it rushes: up (the top half, past the line across), right, down or
## left (past the line up and down). On one line they take turns, up (or left) first; turning (the
## final, both lines), the way turns a quarter every wave: up, right, down, left. The next one is
## always known and shown. No randomness, nodes or rewards.

## A turning wave's ways, in turn.
const TURNS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

## Where the water lines cross (the sky's middle): a line across at its y, one up and down at its x.
var middle: Vector2i
## On one line: it runs up and down, else across. Ignored when turning.
var vertical: bool
## The way turns a quarter every wave (both lines).
var turns: bool
## The first launch a wave comes with (1: the first).
var first_launch: int
## Launches thrown since the run began (intros don't count).
var launches: int = 0
## Waves that have struck.
var waves: int = 0


func _init(p_middle: Vector2i, p_vertical: bool, p_first_launch: int, p_turns: bool = false) -> void:
	middle = p_middle
	vertical = p_vertical
	first_launch = p_first_launch
	turns = p_turns


## A wave comes with the next launch.
func strikes_next() -> bool:
	return launches + 1 >= first_launch


## The way the next wave rushes.
func next_way() -> Vector2i:
	return way_of(waves)


## The way the `n`-th wave (from 0) rushes.
func way_of(n: int) -> Vector2i:
	if turns:
		return TURNS[posmod(n, TURNS.size())]
	var low: Vector2i = Vector2i.LEFT if vertical else Vector2i.UP
	return low if n % 2 == 0 else -low


## Pure: whether `point` is in the half a wave rushing `way` wipes (on its line counts as in).
func in_reach(way: Vector2i, point: Vector2i) -> bool:
	if way.x != 0:
		return (point.x - middle.x) * way.x >= 0
	return (point.y - middle.y) * way.y >= 0


## Pure: the ids of `stars` a wave rushing `way` takes: every one in its half, or on its line.
func sweeps(way: Vector2i, stars: Array[Star]) -> Array[int]:
	var taken: Array[int] = []
	for star: Star in stars:
		if in_reach(way, star.position):
			taken.append(star.id)
	return taken


## A launch was thrown; `struck`: its wave came.
func count_launch(struck: bool) -> void:
	launches += 1
	if struck:
		waves += 1
