class_name StarScatter
extends RefCounted
## Decides where a burst's stars settle. Pure layout on the 180x320 grid; never touches
## pack contents. Every returned position is inside `sky` shrunk by EDGE_MARGIN.
## These are layout constants, not balance, so they live here rather than in balance.json.

## Keeps a star's sprite fully inside the sky (half the big star's footprint, rounded up).
const EDGE_MARGIN: int = 6
const RING_MIN: int = 14
const RING_MAX: int = 26
## Vertical squash of the scatter ring, as in the prototype.
const RING_SQUASH: float = 0.85
const MIN_SPACING: int = 12
const RELAX_STEPS: int = 24


static func inner_rect(sky: Rect2i) -> Rect2i:
	return sky.grow(-EDGE_MARGIN)


## Clamps a point to the inner sky. Rect2i's end edge is exclusive, hence the -1.
static func clamp_to_sky(point: Vector2i, sky: Rect2i) -> Vector2i:
	var inner: Rect2i = inner_rect(sky)
	return Vector2i(
		clampi(point.x, inner.position.x, inner.end.x - 1),
		clampi(point.y, inner.position.y, inner.end.y - 1),
	)


static func place(
	count: int,
	burst: Vector2i,
	sky: Rect2i,
	occupied: Array[Vector2i],
	rng: RandomNumberGenerator,
) -> Array[Vector2i]:
	var inner: Rect2i = inner_rect(sky)
	var lo := Vector2(inner.position)
	var hi := Vector2(inner.end - Vector2i.ONE)
	var center := Vector2(clamp_to_sky(burst, sky))
	var points: Array[Vector2] = []
	var base_angle: float = rng.randf() * TAU
	for i: int in count:
		var angle: float = base_angle + i * TAU / count + rng.randf_range(-0.35, 0.35)
		var dist: float = rng.randf_range(RING_MIN, RING_MAX)
		var p := center + Vector2(cos(angle) * dist, sin(angle) * dist * RING_SQUASH)
		points.append(p.clamp(lo, hi))
	_relax(points, occupied, lo, hi)
	var result: Array[Vector2i] = []
	for p: Vector2 in points:
		result.append(clamp_to_sky(Vector2i(p.round()), sky))
	return result


## Pushes new stars apart from each other and from stars already in the sky.
## Best effort only: a crowded sky can still overlap; clamping always wins.
static func _relax(points: Array[Vector2], occupied: Array[Vector2i], lo: Vector2, hi: Vector2) -> void:
	for step: int in RELAX_STEPS:
		for i: int in points.size():
			var p: Vector2 = points[i]
			for o: Vector2i in occupied:
				p += _push(p, Vector2(o), 1.0)
			for j: int in points.size():
				if j != i:
					p += _push(p, points[j], 0.5)
			points[i] = p.clamp(lo, hi)


static func _push(p: Vector2, other: Vector2, share: float) -> Vector2:
	var delta: Vector2 = p - other
	var d: float = delta.length()
	if d >= MIN_SPACING:
		return Vector2.ZERO
	var dir: Vector2 = delta / d if d > 0.01 else Vector2.RIGHT
	return dir * (MIN_SPACING - d) * share
