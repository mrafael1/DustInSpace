class_name Apparition
extends RefCounted
## A painting forming from its constellation stars (#100): the stars are the source. Each opaque
## pixel of the painting appears once a radius growing from the stars reaches it (its distance to
## the nearest star, in whole pixels), so the figure spreads outward from every star at once,
## through the artwork around it, until it's whole. A bright edge leads: the pixels the radius is
## reaching now show C0, the ring just inside C1 (EDGE), and everything inside it its own colour.
## The art never moves: it stays anchored to its stars. Built once per painting and stars (cached);
## ConstellationView (a stage's painting) and ChapterSelect (a part's piece on the chart) draw it.

## The leading edge, from the front in.
const EDGE: Array[Color] = [Palette.C0, Palette.C1]

static var _cache: Dictionary = {}

## Pixels by their distance to the nearest star (distance -> Array[Vector2i]), and the furthest.
var _rings: Dictionary = {}
var _max_distance: int = 0
## How many opaque pixels the painting has.
var _total: int = 0
var _source: Image
## The painting as far as it has formed (inside the edge), and how far that is (-1: nothing).
var _formed: Image
var _formed_to: int = -1
var _texture: ImageTexture


func _init(art: Image, stars: Array[Vector2i]) -> void:
	_source = art
	_formed = Image.create(art.get_width(), art.get_height(), false, Image.FORMAT_RGBA8)
	var used: Rect2i = art.get_used_rect()
	for y: int in range(used.position.y, used.end.y):
		for x: int in range(used.position.x, used.end.x):
			if art.get_pixel(x, y).a < 0.5:
				continue
			var d: int = nearest(Vector2i(x, y), stars)
			if not _rings.has(d):
				_rings[d] = [] as Array[Vector2i]
			(_rings[d] as Array[Vector2i]).append(Vector2i(x, y))
			_total += 1
			_max_distance = maxi(_max_distance, d)
	_texture = ImageTexture.create_from_image(_formed)


## The apparition of the painting `art` (its texture) from `stars`, built once per `key`.
static func of(key: String, art: Texture2D, stars: Array[Vector2i]) -> Apparition:
	var full_key: String = "%s|%s" % [key, stars]
	if not _cache.has(full_key):
		_cache[full_key] = Apparition.new(art.get_image(), stars)
	return _cache[full_key]


## A point's distance to the nearest of `stars`, rounded to whole pixels (a big number with none).
static func nearest(p: Vector2i, stars: Array[Vector2i]) -> int:
	var best: int = 1 << 20
	for star: Vector2i in stars:
		best = mini(best, roundi(Vector2(p).distance_to(Vector2(star))))
	return best


## The radius `k` (0-1) of the way through, paced by the painting's area rather than its reach:
## most of a figure lies close to its stars, so a radius growing evenly would show it nearly whole
## at once, then trickle out to its tips. Here `k` of its pixels have formed (inside the edge) at
## `k`: 0 at the stars, past the furthest pixel (its edge too) at 1.
func radius_at(k: float) -> int:
	if k >= 1.0:
		return _max_distance + EDGE.size()
	var target: float = clampf(k, 0.0, 1.0) * _total
	var formed: int = 0
	for d: int in _max_distance + 1:
		if formed >= target:
			return d - 1 + EDGE.size() if d > 0 else 0
		formed += (_rings.get(d, []) as Array).size()
	return _max_distance + EDGE.size()


func max_distance() -> int:
	return _max_distance


## The painting as formed at `radius`: every pixel inside the edge, in its own colours.
func formed(radius: int) -> Texture2D:
	var inside: int = radius - EDGE.size()
	var changed: bool = false
	if inside < _formed_to:
		_formed.fill(Color(0, 0, 0, 0))
		_formed_to = -1
		changed = true
	if inside > _formed_to:
		for d: int in range(_formed_to + 1, inside + 1):
			for p: Vector2i in _rings.get(d, []):
				_formed.set_pixelv(p, _source.get_pixelv(p))
		_formed_to = inside
		changed = true
	if changed:
		_texture.update(_formed)
	return _texture


## The formed image itself, as of the last `formed` call (tests: a texture's pixels can't be read
## back without a renderer).
func formed_image() -> Image:
	return _formed


## The leading edge at `radius`: each pixel it lights, with its colour (C0 at the front).
func edge(radius: int) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	for k: int in EDGE.size():
		for p: Vector2i in _rings.get(radius - k, []):
			dots[p] = EDGE[k]
	return dots


## Every opaque pixel at `distance` from the nearest star.
func ring(distance: int) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	pixels.assign(_rings.get(distance, []))
	return pixels
