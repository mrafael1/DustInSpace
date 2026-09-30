class_name Backdrop
extends Node2D
## Fills the window around the game's 180x320 screen when it shows more (a phone that isn't 9:16):
## the game sits on the bottom edge, so this is mostly sky above it. The sky's top colour carries
## on for a band, then steps (a checker seam) into darker space.
## Out to the sides the landscape carries on: each sky row keeps the background's own dither (its
## most common colour in each column of 4, so no stripes), a sky step darker out beyond a curved
## vignette (through a checker seam) to keep the eye on the play area; below it, irregular mountains (M3,
## lit M4 on their left faces) and hills (M2) that start at the background's edge heights, with
## scattered trees (M1). The forest floor under the HUD repeats across (the background draws it
## to tile every 180 px). Sparse, dim cool stars sit in the margin sky on a fixed hash of their
## position, so they never move. Drawn under everything; Main tells it where the game sits. Owns
## no rules.

const BACKGROUND := preload("res://assets/art/background.png")
## Above the game: this many rows of the sky's top colour, then a checker seam into N0.
const SKY_BAND: int = 24
const SEAM: int = 4
## Background stars: about one in STAR_ODDS pixels of margin sky, one in GLINT_ODDS of them a
## 3 px glint. Cool, dim colours only: they mustn't compete with the stars in play.
const STAR_ODDS: int = 240
const GLINT_ODDS: int = 20
const STAR_COLOURS: Array[Color] = [Palette.N6, Palette.N7, Palette.N7, Palette.N8]
## Stars in the side margins only above the land.
const SKY_BOTTOM: int = 230
## From this row down, the side margins repeat the forest floor.
const GROUND_TOP: int = 284
## The side sky repeats the background's rows down to SKY_LAST (the haze behind the mountains).
const SKY_LAST: int = 245
## The outer sky is a step darker (SKY_RAMP) outside an ellipse round the play area (centre and
## radii in px, wide enough to hold the game's whole screen), through an OUTER_SEAM px checker: a
## curved vignette, so no straight edge outlines the game's screen.
const OUTER_CENTRE := Vector2(90, 170)
const OUTER_RADII := Vector2(120, 300)
const OUTER_SEAM: int = 6
const SKY_RAMP: Array[Color] = [Palette.N0, Palette.N1, Palette.N2, Palette.N3, Palette.N4, Palette.N5, Palette.N6, Palette.N7, Palette.N8]
## Side mountains: tops at MOUNTAIN_BASE raised by a big and a small wave (px, and px per wave).
const MOUNTAIN_BASE: int = 252
const MOUNTAIN_RISE := Vector2i(13, 4)
const MOUNTAIN_WAVE := Vector2(19.0, 7.0)
## Side hills: tops at HILL_TOP raised by up to HILL_RISE px, over HILL_WAVE px.
const HILL_TOP: int = 269
const HILL_RISE: int = 4
const HILL_WAVE: float = 11.0
## Next to the game the land starts at the background's own edge heights, reaching its own
## shapes over BLEND px.
const BLEND: int = 10
## Trees: one in TREE_ODDS columns (from TREE_CLEAR px out), standing on GROUND_TOP, their
## half-width per row from the top in TREE_SHAPE (the background's own stepped pines).
const TREE_ODDS: int = 6
const TREE_CLEAR: int = 3
const TREE_HEIGHT := Vector2i(7, 15)
const TREE_SHAPE: Array[int] = [0, 0, 1, 0, 1, 2, 1, 2, 3, 2, 3, 3]

## The game's screen sits at `_offset` in a visible area of `_visible` px.
var _offset: Vector2i = Vector2i.ZERO
var _visible: Vector2i = ScreenZones.SCREEN
var _image: Image
var _margin: ImageTexture


func _ready() -> void:
	_image = BACKGROUND.get_image()
	_rebuild()


func _draw() -> void:
	if _margin != null:
		draw_texture(_margin, Vector2(-_offset))


## The game sits at `offset` in a visible area of `visible` px.
func fit(offset: Vector2i, visible: Vector2i) -> void:
	_offset = offset
	_visible = visible
	_rebuild()
	queue_redraw()


## Everything around the game's screen in `area` (game coordinates), transparent over the screen.
static func margin_image(background: Image, area: Rect2i) -> Image:
	var image := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	var screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
	var sky: Array[PackedColorArray] = sky_pattern(background)
	var sky_top: Color = edge_colour(background, 0, 0)
	for x: int in range(area.position.x, area.end.x):
		var land: PackedColorArray = PackedColorArray()
		if x < 0 or x >= screen.size.x:
			land = land_column(background, x)
		for y: int in range(area.position.y, area.end.y):
			if screen.has_point(Vector2i(x, y)):
				continue
			var colour: Color
			if y >= screen.size.y:
				colour = edge_colour(background, 0, screen.size.y - 1)
			elif y >= GROUND_TOP:
				colour = ground_colour(background, x, y)
			elif y < 0:
				colour = outer_sky(space_colour(x, y, sky_top), x, y)
			elif land[y].a > 0.0:
				colour = land[y]
			else:
				colour = outer_sky(sky[mini(y, SKY_LAST)][posmod(x, 4)], x, y)
			image.set_pixel(x - area.position.x, y - area.position.y, colour)
	for p: Vector2i in margin_stars(area):
		var star: Dictionary[Vector2i, Color] = star_pixels(p)
		for q: Vector2i in star:
			if area.has_point(q) and not screen.has_point(q):
				image.set_pixelv(q - area.position, star[q])
	return image


## The background's colour at (x, y), opaque.
static func edge_colour(image: Image, x: int, y: int) -> Color:
	var c: Color = image.get_pixel(x, y)
	return Color(c.r, c.g, c.b)


## The forest floor at (x, y) for any x: the background's own, repeated every 180 px across.
static func ground_colour(image: Image, x: int, y: int) -> Color:
	return edge_colour(image, posmod(x, ScreenZones.SCREEN.x), y)


## The sky above the game at row `y` (negative), column `x`: the sky's top colour for SKY_BAND
## rows, a checker seam, then N0.
static func space_colour(x: int, y: int, sky_top: Color) -> Color:
	var up: int = -y - SKY_BAND
	if up <= 0:
		return sky_top
	if up > SEAM:
		return Palette.N0
	# Ordered checker: more N0 the further up the seam.
	return Palette.N0 if StarView.BAYER[posmod(y, 4) * 4 + posmod(x, 4)] < up * 16 / (SEAM + 1) else sky_top


## The background's sky dither, rows 0 to SKY_LAST: each row's most common colour in each column
## of 4 (the dither's period), leaving out its stars and clouds.
static func sky_pattern(background: Image) -> Array[PackedColorArray]:
	var rows: Array[PackedColorArray] = []
	for y: int in SKY_LAST + 1:
		var row := PackedColorArray()
		for k: int in 4:
			var counts: Dictionary[Color, int] = {}
			for x: int in range(k, ScreenZones.SCREEN.x, 4):
				var c: Color = edge_colour(background, x, y)
				counts[c] = counts.get(c, 0) + 1
			var best: Color = counts.keys()[0]
			for c: Color in counts:
				if counts[c] > counts[best]:
					best = c
			row.append(best)
		rows.append(row)
	return rows


## `colour` of the sky at (x, y), a step darker out beyond the vignette (OUTER_RADII, OUTER_SEAM).
static func outer_sky(colour: Color, x: int, y: int) -> Color:
	var out: float = ((Vector2(x, y) - OUTER_CENTRE) / OUTER_RADII).length() * OUTER_RADII.x - OUTER_RADII.x
	if out <= 0.0:
		return colour
	if out <= OUTER_SEAM and StarView.BAYER[posmod(y, 4) * 4 + posmod(x, 4)] >= floori(out) * 16 / (OUTER_SEAM + 1):
		return colour
	var step: int = SKY_RAMP.find(colour)
	return SKY_RAMP[step - 1] if step > 0 else colour


## Column `x` of the side landscape (outside the game's screen), rows 0 to GROUND_TOP: mountains,
## hills and trees, transparent where the sky shows.
static func land_column(background: Image, x: int) -> PackedColorArray:
	var column := PackedColorArray()
	column.resize(GROUND_TOP)
	column.fill(Color(0, 0, 0, 0))
	var peak: int = mountain_top(background, x)
	var hill: int = hill_top(background, x)
	var lit: bool = mountain_top(background, x - 1) > peak
	for y: int in range(peak, GROUND_TOP):
		column[y] = Palette.M4 if y == peak and lit else Palette.M3
		if y == hill:
			column[y] = Palette.M2 if posmod(x + y, 2) == 0 else Palette.M3
		elif y > hill:
			column[y] = Palette.M2
	for tree: int in range(x - 3, x + 4):
		if not is_tree(tree):
			continue
		var top: int = GROUND_TOP - tree_height(tree)
		for y: int in range(top, GROUND_TOP):
			if absi(x - tree) <= TREE_SHAPE[mini(y - top, TREE_SHAPE.size() - 1)]:
				column[y] = Palette.M1
	return column


## The first mountain row of column `x`: the background's own inside the game's screen; outside,
## waves that start from the background's edge height.
static func mountain_top(background: Image, x: int) -> int:
	var wild: float = MOUNTAIN_BASE - MOUNTAIN_RISE.x * _wave(_distance_out(x) / MOUNTAIN_WAVE.x, _side(x) * 3) - MOUNTAIN_RISE.y * _wave(_distance_out(x) / MOUNTAIN_WAVE.y, _side(x) * 5)
	return _from_edge(background, x, [Palette.M3, Palette.M4], 236, wild)


## The first hill row of column `x`, like mountain_top.
static func hill_top(background: Image, x: int) -> int:
	var wild: float = HILL_TOP - HILL_RISE * _wave(_distance_out(x) / HILL_WAVE, _side(x) * 7)
	return _from_edge(background, x, [Palette.M2], 255, wild)


## Whether a tree stands in column `x` (only out beside the game).
static func is_tree(x: int) -> bool:
	return _distance_out(x) >= TREE_CLEAR and _hash(Vector2i(x, 911)) % TREE_ODDS == 0


static func tree_height(x: int) -> int:
	return TREE_HEIGHT.x + _hash(Vector2i(x, 577)) % (TREE_HEIGHT.y - TREE_HEIGHT.x + 1)


## Where the background stars go in the margin sky inside `area` (game coordinates): a fixed
## hash per pixel, outside the game's screen, and above the land at the sides.
static func margin_stars(area: Rect2i) -> Array[Vector2i]:
	var stars: Array[Vector2i] = []
	var screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
	for y: int in range(area.position.y, mini(area.end.y, SKY_BOTTOM)):
		for x: int in range(area.position.x, area.end.x):
			var p := Vector2i(x, y)
			if screen.has_point(p) or _hash(p) % STAR_ODDS != 0:
				continue
			stars.append(p)
	return stars


## A margin star's pixels: 1 px, or a small glint (N6 arms round an N8 core).
static func star_pixels(p: Vector2i) -> Dictionary[Vector2i, Color]:
	var h: int = _hash(p) / STAR_ODDS
	var pixels: Dictionary[Vector2i, Color] = {}
	if h % GLINT_ODDS == 0:
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			pixels[p + n] = Palette.N6
		pixels[p] = Palette.N8
		return pixels
	pixels[p] = STAR_COLOURS[h % STAR_COLOURS.size()]
	return pixels


func _rebuild() -> void:
	if _image == null or _visible == ScreenZones.SCREEN:
		_margin = null
		return
	_margin = ImageTexture.create_from_image(margin_image(_image, Rect2i(-_offset, _visible)))


## A height for column `x`: the background's own (the first row from `from` in `colours`) inside
## the game's screen; outside, `wild`, reached from the nearest edge column's over BLEND px.
static func _from_edge(background: Image, x: int, colours: Array[Color], from: int, wild: float) -> int:
	if _distance_out(x) == 0:
		return _art_top(background, x, colours, from)
	var edge: int = _art_top(background, 0 if x < 0 else ScreenZones.SCREEN.x - 1, colours, from)
	return roundi(lerpf(float(edge), wild, minf(_distance_out(x) / float(BLEND), 1.0)))


static func _art_top(background: Image, x: int, colours: Array[Color], from: int) -> int:
	for y: int in range(from, GROUND_TOP):
		if colours.has(edge_colour(background, x, y)):
			return y
	return GROUND_TOP


## How many columns `x` lies out beside the game's screen (0 over it).
static func _distance_out(x: int) -> int:
	if x < 0:
		return -x
	return maxi(0, x - ScreenZones.SCREEN.x + 1)


## Which side `x` is on: 1 left, 2 right (a seed for its waves).
static func _side(x: int) -> int:
	return 1 if x < 0 else 2


## Smooth value noise from 0 to 1, fixed for each `seed`.
static func _wave(u: float, seed: int) -> float:
	var i: int = floori(u)
	var f: float = u - i
	f = f * f * (3.0 - 2.0 * f)
	var a: float = (_hash(Vector2i(i, seed)) % 1024) / 1023.0
	var b: float = (_hash(Vector2i(i + 1, seed)) % 1024) / 1023.0
	return lerpf(a, b, f)


## A fixed, well-mixed hash of a pixel (non-negative).
static func _hash(p: Vector2i) -> int:
	var h: int = p.x * 374761393 + p.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))
