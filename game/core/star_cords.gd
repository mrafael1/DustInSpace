class_name StarCords
extends RefCounted
## Pisces's cords (chapter 6, a debug trial): every successful link leaves its string in the sky as a
## cord, its two segments in pick order, and a traced link can't step across one. Only a proper
## crossing blocks: a step that touches a cord (a shared end, an end lying on it, or running along
## it) passes. Bursts and stars cross cords freely. The tests are exact integer orientation tests, so
## every machine agrees on them, and cords draw no random numbers.
## A map may also bring fixed cords (the fish's cord, StarMap.fish_cord: tie_fixed): they block the
## same way but are never cleared. Every query (crosses, crossing, count, is_empty, segments) covers
## both kinds; fixed_count/link_count, fixed_segments/link_segments and is_fixed tell them apart.

## What crossing() answers when a step crosses no cord.
const NO_CROSSING := Vector2i(-1, -1)

## The cords' segments as pairs of ends, flat: segment i runs from _ends[2i] to _ends[2i + 1]. The
## fixed segments come first.
var _ends: Array[Vector2i] = []
## How many segments at the front of _ends are fixed.
var _fixed: int = 0


## Whether segments `a`-`b` and `c`-`d` cross properly: each one's ends lie strictly on either side
## of the other's line. Touching, a shared end, collinear overlap and parallel lines don't count;
## neither does a segment of no length.
static func properly_cross(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	var ab_c: int = _orientation(a, b, c)
	var ab_d: int = _orientation(a, b, d)
	var cd_a: int = _orientation(c, d, a)
	var cd_b: int = _orientation(c, d, b)
	return ab_c * ab_d < 0 and cd_a * cd_b < 0


## Ties a link's string as cords: a segment between each pair of consecutive `points` (the stars'
## positions in pick order). Returns the segments added, each as [from, to].
func tie(points: Array[Vector2i]) -> Array[Array]:
	var added: Array[Array] = []
	for i: int in range(1, points.size()):
		if points[i - 1] == points[i]:
			continue
		_ends.append(points[i - 1])
		_ends.append(points[i])
		added.append([points[i - 1], points[i]] as Array[Vector2i])
	return added


## Ties a fixed cord (the fish's): a segment between each pair of consecutive `points`, kept through
## clear(). Fixed segments stay ahead of the link cords. Returns the segments added, each as [from, to].
func tie_fixed(points: Array[Vector2i]) -> Array[Array]:
	var added: Array[Array] = []
	for i: int in range(1, points.size()):
		if points[i - 1] == points[i]:
			continue
		_ends.insert(2 * _fixed, points[i])
		_ends.insert(2 * _fixed, points[i - 1])
		_fixed += 1
		added.append([points[i - 1], points[i]] as Array[Vector2i])
	return added


## Whether a link step from `a` to `b` properly crosses any cord (fixed or a link's).
func crosses(a: Vector2i, b: Vector2i) -> bool:
	for i: int in count():
		if properly_cross(a, b, _ends[2 * i], _ends[2 * i + 1]):
			return true
	return false


## Where a link step from `a` to `b` first meets a cord it crosses, going from `a` (rounded to the
## pixel), or NO_CROSSING. For the trace, which refuses at the crossing.
func crossing(a: Vector2i, b: Vector2i) -> Vector2i:
	var best: Vector2i = NO_CROSSING
	var best_distance: int = -1
	for i: int in count():
		var c: Vector2i = _ends[2 * i]
		var d: Vector2i = _ends[2 * i + 1]
		if not properly_cross(a, b, c, d):
			continue
		var point: Vector2i = _meeting(a, b, c, d)
		var distance: int = (point - a).length_squared()
		if best_distance < 0 or distance < best_distance:
			best = point
			best_distance = distance
	return best


## Removes every link's cord (the sky was cleared); the fixed cords stay.
func clear() -> void:
	_ends.resize(2 * _fixed)


## Whether no cord at all is in the sky (fixed or a link's).
func is_empty() -> bool:
	return _ends.is_empty()


## How many cord segments are in the sky, fixed and links' together.
func count() -> int:
	return _ends.size() / 2


## How many fixed segments there are (the fish's cord).
func fixed_count() -> int:
	return _fixed


## How many segments links have tied (what a clear removes).
func link_count() -> int:
	return count() - _fixed


## Whether segment `index` (of segments()) is fixed.
func is_fixed(index: int) -> bool:
	return index >= 0 and index < _fixed


## Every cord segment, the fixed ones first, then the links' oldest first, each as [from, to].
func segments() -> Array[Array]:
	return _segments_between(0, count())


## The fixed segments only, in order.
func fixed_segments() -> Array[Array]:
	return _segments_between(0, _fixed)


## The links' segments only, oldest first.
func link_segments() -> Array[Array]:
	return _segments_between(_fixed, count())


func _segments_between(from: int, to: int) -> Array[Array]:
	var found: Array[Array] = []
	for i: int in range(from, to):
		found.append([_ends[2 * i], _ends[2 * i + 1]] as Array[Vector2i])
	return found


## Which side of the line `from`-`to` the point `at` lies on: 1 left, -1 right, 0 on it.
static func _orientation(from: Vector2i, to: Vector2i, at: Vector2i) -> int:
	return signi((to.x - from.x) * (at.y - from.y) - (to.y - from.y) * (at.x - from.x))


## Where the lines through `a`-`b` and `c`-`d` meet, rounded (they must cross).
static func _meeting(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> Vector2i:
	var ab: Vector2i = b - a
	var cd: Vector2i = d - c
	var ac: Vector2i = c - a
	var t: float = float(ac.x * cd.y - ac.y * cd.x) / float(ab.x * cd.y - ab.y * cd.x)
	return Vector2i((Vector2(a) + Vector2(ab) * t).round())
