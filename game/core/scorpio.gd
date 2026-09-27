class_name Scorpio
extends RefCounted
## The Scorpio constellation map (#40, a prototype). Fixed landmark stars trace Scorpio from its
## head to its stinger. Most of the outline is given; the GAPS are the segments the player builds,
## by linking the two landmarks with a sky star that sits in the gap between them. The star is
## used up and stays as the segment's bridge. A star is in the gap if it's within `reach` px of
## the segment line and its projection falls between the two landmarks, so placement is
## forgiving but still spatial.
## Pure geometry and state; RunState owns the rules and rewards. Landmark positions are map
## layout, not balance; the reach values come from balance.json.

## Landmarks, head to stinger, on the 180x320 grid, inside the play sky (y 86-242 once the edge
## margin is taken off). Neighbours are about 28-30 px apart, so a star fits in each gap.
const LANDMARKS: Array[Vector2i] = [
	Vector2i(146, 98), Vector2i(128, 122), Vector2i(110, 146), Vector2i(96, 172),
	Vector2i(88, 200), Vector2i(66, 220), Vector2i(38, 222), Vector2i(24, 198),
]

## The segments left to build (segment i joins landmarks i and i + 1). Four: a run has about
## 25-30 stars and most go into combos, so seven gaps were rarely finished (tools/balance/sim.py).
const GAPS: Array[int] = [1, 3, 5, 6]

## Per segment: the id of the star bridging it, or 0 while unbuilt (always 0 for a given one).
var bridges: Array[int] = []
## Where each bridge star sat when it was used, for drawing.
var bridge_positions: Array[Vector2i] = []


func _init() -> void:
	for i: int in segment_count():
		bridges.append(0)
		bridge_positions.append(Vector2i.ZERO)


static func segment_count() -> int:
	return LANDMARKS.size() - 1


static func is_gap(segment: int) -> bool:
	return GAPS.has(segment)


## Landmarks use negative ids in a link so they never collide with star ids: landmark i is -(i + 1).
static func landmark_id(index: int) -> int:
	return -(index + 1)


static func landmark_index(id: int) -> int:
	return -id - 1


static func is_landmark_id(id: int) -> bool:
	return id < 0 and landmark_index(id) < LANDMARKS.size()


## The segment joining two landmark indices, or -1 if they aren't neighbours.
static func segment_between(a: int, b: int) -> int:
	if absi(a - b) != 1:
		return -1
	return mini(a, b)


static func segment_ends(segment: int) -> Array[Vector2i]:
	return [LANDMARKS[segment], LANDMARKS[segment + 1]]


## How far `point` is from the segment's line, and whether its projection lands between the ends.
static func in_gap(segment: int, point: Vector2i, reach: int) -> bool:
	var ends: Array[Vector2i] = segment_ends(segment)
	var a := Vector2(ends[0])
	var ab: Vector2 = Vector2(ends[1]) - a
	var t: float = (Vector2(point) - a).dot(ab) / ab.length_squared()
	if t < 0.0 or t > 1.0:
		return false
	return (a + ab * t).distance_to(Vector2(point)) <= reach


func is_built(segment: int) -> bool:
	return bridges[segment] != 0


func built_count() -> int:
	var count: int = 0
	for id: int in bridges:
		if id != 0:
			count += 1
	return count


func is_complete() -> bool:
	return built_count() == GAPS.size()


## Unbuilt gaps that hold `point`.
func open_segments_for(point: Vector2i, reach: int) -> Array[int]:
	var found: Array[int] = []
	for segment: int in GAPS:
		if not is_built(segment) and in_gap(segment, point, reach):
			found.append(segment)
	return found


func build(segment: int, star: Star) -> void:
	bridges[segment] = star.id
	bridge_positions[segment] = star.position
