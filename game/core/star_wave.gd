class_name StarWave
extends RefCounted
## Pisces's wave (chapter 6): from the `first_launch`-th launch on, every launch a wave rises off the
## water line and wipes the half of the sky on one side of it, taking every loose star there for
## nothing. A wave's way is where it rushes: up or down off a line across, left or right off a line
## up and down; they take turns, up (or left) first, so the next one is always known and shown.
## With a great wave (the final), the `great_launch`-th launch brings it instead: it floods both
## halves at once (and the run wakes the fish), the waves then taking turns again, left (or up)
## first. No randomness, nodes or rewards.

## The water lines cross here (the sky's middle): a line across at its y, one up and down at its x.
var middle: Vector2i
## The line runs up and down, else across.
var vertical: bool
## The first launch a wave comes with (1: the first).
var first_launch: int
## The launch the great wave comes with (0: none).
var great_launch: int
## Launches thrown since the run began (intros don't count).
var launches: int = 0
## Waves that have struck on this line (the great wave starts the count again).
var waves: int = 0


func _init(p_middle: Vector2i, p_vertical: bool, p_first_launch: int, p_great_launch: int = 0) -> void:
	middle = p_middle
	vertical = p_vertical
	first_launch = p_first_launch
	great_launch = p_great_launch


## A wave comes with the next launch.
func strikes_next() -> bool:
	return launches + 1 >= first_launch or great_next()


## The great wave comes with the next launch.
func great_next() -> bool:
	return great_launch > 0 and launches + 1 == great_launch


## The way the next wave rushes (a great wave: across its line's axis, right or down; it floods both
## ways).
func next_way() -> Vector2i:
	if great_next():
		return Vector2i.RIGHT if vertical else Vector2i.DOWN
	var low: Vector2i = Vector2i.LEFT if vertical else Vector2i.UP
	return low if waves % 2 == 0 else -low


## Pure: whether a wave rushing `way` (`great`: both ways) takes a star at `point`: in its half, or
## on its line.
func in_reach(way: Vector2i, point: Vector2i, great: bool = false) -> bool:
	if great:
		return true
	if way.x != 0:
		return (point.x - middle.x) * way.x >= 0
	return (point.y - middle.y) * way.y >= 0


## Pure: the ids of `stars` the next wave takes.
func sweeps(stars: Array[Star]) -> Array[int]:
	var way: Vector2i = next_way()
	var great: bool = great_next()
	var taken: Array[int] = []
	for star: Star in stars:
		if in_reach(way, star.position, great):
			taken.append(star.id)
	return taken


## A launch was thrown; `struck`: its wave came (a great one starts the turns again).
func count_launch(struck: bool) -> void:
	var great: bool = great_next()
	launches += 1
	if not struck:
		return
	waves = 0 if great else waves + 1
