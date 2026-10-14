class_name StarCords
extends RefCounted
## Pisces's cords (chapter 6): every successful link leaves its string in the sky as a
## cord, its two segments in pick order, and a traced link can't step across one. Only a proper
## crossing blocks: a step that touches a cord (a shared end, an end lying on it, or running along
## it) passes. Bursts and stars cross cords freely. The tests are exact integer orientation tests, so
## every machine agrees on them, and cords draw no random numbers.
## A map may also bring fixed cords (the fish's cord, StarMap.fish_cord: tie_fixed): they block the
## same way but are never cleared. Every query (crosses, crossing, count, is_empty, segments) covers
## both kinds; fixed_count/link_count, fixed_segments/link_segments and is_fixed tell them apart.
## Nets (tie_net, with a knot reach): a link whose first or last star stands within `knot_reach` px
## of another cord knots into it there (a knot: a tie from the star to its nearest point on that
## cord). A link whose two ends both knot into cords already joined (through cords and earlier
## knots) closes a net: the loop round the new cord and the shortest way back along the cords. The
## links' cords in the loop snap (the fish's never does), and the loop is returned for RunState to
## catch the stars inside. Knots don't block a step.

## What crossing() answers when a step crosses no cord.
const NO_CROSSING := Vector2i(-1, -1)
## The owner of a fixed segment (the fish's cord), which never snaps.
const FIXED: int = -1

## The cords' segments as pairs of ends, flat: segment i runs from _ends[2i] to _ends[2i + 1]. The
## fixed segments come first.
var _ends: Array[Vector2i] = []
## How many segments at the front of _ends are fixed.
var _fixed: int = 0
## Which link tied each segment (FIXED for the fish's), in _ends' order, and the next link's number.
var _owners: Array[int] = []
var _next_owner: int = 0
## The knots, flat: knot i ties the star at _knot_ends[2i] (of link _knot_owners[2i]) to the point
## _knot_ends[2i + 1] on cord segment _knot_targets[i] ([from, to]) of link _knot_owners[2i + 1].
var _knot_ends: Array[Vector2i] = []
var _knot_owners: Array[int] = []
var _knot_targets: Array[Array] = []
## How far a link's end may stand from a cord and still knot into it (0: never).
var knot_reach: int = 0


## A net a link closed: the loop (its points in order, the closing link's first), and the cord
## segments that snapped (each as [from, to], the closing link's own among them).
class Net:
	extends RefCounted
	var loop: Array[Vector2i] = []
	var snapped: Array[Array] = []


func _init(p_knot_reach: int = 0) -> void:
	knot_reach = p_knot_reach


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
	var owner: int = _next_owner
	_next_owner += 1
	var added: Array[Array] = []
	for i: int in range(1, points.size()):
		if points[i - 1] == points[i]:
			continue
		_ends.append(points[i - 1])
		_ends.append(points[i])
		_owners.append(owner)
		added.append([points[i - 1], points[i]] as Array[Vector2i])
	return added


## Ties a link's string as cords (as tie) and knots its ends into the cords within knot_reach. If
## that closes a net, the cords in it snap and the net is returned; else null.
func tie_net(points: Array[Vector2i]) -> Net:
	var knots: Array[Array] = _knots_for(points)
	var net: Net = _net_through(points, knots)
	var owners: Array[int] = _net_owners(knots) if net != null else ([] as Array[int])
	var owner: int = _next_owner
	tie(points)
	for knot: Array in knots:
		_knot_ends.append_array([knot[0], knot[1]])
		_knot_owners.append_array([owner, knot[3]])
		_knot_targets.append(knot[2])
	if net != null:
		owners.append(owner)
		_snap(owners, net)
	return net


## The net a link through `points` (in pick order) would close, without tying it: null if its ends
## don't both knot into cords already joined.
func find_net(points: Array[Vector2i]) -> Net:
	return _net_through(points, _knots_for(points))


## Every knot, each as [the star's end, the point on the cord it's tied to].
func knots() -> Array[Array]:
	var found: Array[Array] = []
	for k: int in _knot_targets.size():
		found.append([_knot_ends[2 * k], _knot_ends[2 * k + 1]] as Array[Vector2i])
	return found


func _net_through(points: Array[Vector2i], knots: Array[Array]) -> Net:
	if knots.size() < 2:
		return null
	var path: Array[Vector2i] = _cord_path(knots[1][1], knots[0][1], knots)
	if path.is_empty():
		return null
	var net := Net.new()
	net.loop.assign(points)
	for point: Vector2i in path:
		if net.loop[-1] != point:
			net.loop.append(point)
	if net.loop.size() > 1 and net.loop[-1] == net.loop[0]:
		net.loop.pop_back()
	return net


## The knots `points` would make: its first end's, then its last's, each [end, point on the cord,
## that cord's segment as [from, to], its owner] (none for an end with no cord in reach).
func _knots_for(points: Array[Vector2i]) -> Array[Array]:
	var found: Array[Array] = []
	if knot_reach <= 0 or points.size() < 2:
		return found
	for end: Vector2i in [points[0], points[-1]]:
		var best: Array = []
		var best_distance: float = float(knot_reach) + 0.001
		for i: int in count():
			var a: Vector2i = _ends[2 * i]
			var b: Vector2i = _ends[2 * i + 1]
			var on: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(end), Vector2(a), Vector2(b))
			var distance: float = on.distance_to(Vector2(end))
			if distance < best_distance:
				best_distance = distance
				best = [end, Vector2i(on.round()), [a, b] as Array[Vector2i], _owners[i]]
		if not best.is_empty():
			found.append(best)
	return found


## The shortest way along the cords and knots from `from` to `to` (points on cords), as the points
## passed, both ends included ([from] alone when they're the same point); [] if they aren't joined.
## `extra`: knots not tied yet, whose points split their cords too (so the way can start and end on
## them). `owners`, when given, gets each step's link (keyed by _step_key), a knot's being the link
## it ties.
func _cord_path(from: Vector2i, to: Vector2i, extra: Array[Array], owners: Dictionary = {}) -> Array[Vector2i]:
	var edges: Dictionary[Vector2i, Array] = {}
	var splits: Array[Array] = []
	for k: int in _knot_targets.size():
		splits.append([_knot_ends[2 * k + 1], _knot_targets[k]])
		_join(edges, _knot_ends[2 * k], _knot_ends[2 * k + 1])
		owners[_step_key(_knot_ends[2 * k], _knot_ends[2 * k + 1])] = _knot_owners[2 * k]
	for knot: Array in extra:
		splits.append([knot[1], knot[2]])
	for i: int in count():
		var a: Vector2i = _ends[2 * i]
		var b: Vector2i = _ends[2 * i + 1]
		var on: Array[Vector2i] = [a, b]
		for split: Array in splits:
			if split[1][0] == a and split[1][1] == b and not on.has(split[0]):
				on.append(split[0])
		on.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return (p - a).length_squared() < (q - a).length_squared())
		for j: int in range(1, on.size()):
			_join(edges, on[j - 1], on[j])
			owners[_step_key(on[j - 1], on[j])] = _owners[i]
	if not edges.has(from) or not edges.has(to):
		return []
	if from == to:
		return [from]
	# Dijkstra over the few points there are.
	var best: Dictionary[Vector2i, float] = {from: 0.0}
	var back: Dictionary[Vector2i, Vector2i] = {}
	var open: Array[Vector2i] = [from]
	while not open.is_empty():
		var at: Vector2i = open[0]
		for p: Vector2i in open:
			if best[p] < best[at]:
				at = p
		open.erase(at)
		if at == to:
			break
		for next: Vector2i in edges[at]:
			var length: float = best[at] + Vector2(at).distance_to(Vector2(next))
			if not best.has(next) or length < best[next]:
				best[next] = length
				back[next] = at
				if not open.has(next):
					open.append(next)
	if not best.has(to):
		return []
	var path: Array[Vector2i] = [to]
	while path[-1] != from:
		path.append(back[path[-1]])
	path.reverse()
	return path


static func _join(edges: Dictionary[Vector2i, Array], a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	if not edges.has(a):
		edges[a] = []
	if not edges.has(b):
		edges[b] = []
	if not edges[a].has(b):
		edges[a].append(b)
		edges[b].append(a)


## The links (not the fish's) whose cords or knots the way back between two `knots` passes along.
func _net_owners(knots: Array[Array]) -> Array[int]:
	var owners: Array[int] = []
	var by_step: Dictionary = {}
	var path: Array[Vector2i] = _cord_path(knots[1][1], knots[0][1], knots, by_step)
	for j: int in range(1, path.size()):
		var owner: int = by_step.get(_step_key(path[j - 1], path[j]), FIXED)
		if owner != FIXED and not owners.has(owner):
			owners.append(owner)
	return owners


## The same key for a step from `a` to `b` either way round.
static func _step_key(a: Vector2i, b: Vector2i) -> Vector4i:
	return Vector4i(a.x, a.y, b.x, b.y) if a < b else Vector4i(b.x, b.y, a.x, a.y)


## Removes the cords of `owners` and every knot from or into them, listing them in `net.snapped`.
func _snap(owners: Array[int], net: Net) -> void:
	for i: int in range(count() - 1, _fixed - 1, -1):
		if owners.has(_owners[i]):
			net.snapped.push_front([_ends[2 * i], _ends[2 * i + 1]] as Array[Vector2i])
			_ends.remove_at(2 * i + 1)
			_ends.remove_at(2 * i)
			_owners.remove_at(i)
	for k: int in range(_knot_targets.size() - 1, -1, -1):
		if owners.has(_knot_owners[2 * k]) or owners.has(_knot_owners[2 * k + 1]):
			_knot_ends.remove_at(2 * k + 1)
			_knot_ends.remove_at(2 * k)
			_knot_owners.remove_at(2 * k + 1)
			_knot_owners.remove_at(2 * k)
			_knot_targets.remove_at(k)


## Ties a fixed cord (the fish's): a segment between each pair of consecutive `points`, kept through
## clear(). Fixed segments stay ahead of the link cords. Returns the segments added, each as [from, to].
func tie_fixed(points: Array[Vector2i]) -> Array[Array]:
	var added: Array[Array] = []
	for i: int in range(1, points.size()):
		if points[i - 1] == points[i]:
			continue
		_ends.insert(2 * _fixed, points[i])
		_ends.insert(2 * _fixed, points[i - 1])
		_owners.insert(_fixed, FIXED)
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
	_owners.resize(_fixed)
	_knot_ends.clear()
	_knot_owners.clear()
	_knot_targets.clear()


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
