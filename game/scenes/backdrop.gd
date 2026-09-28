class_name Backdrop
extends Node2D
## Fills the window around the game's 180x320 screen when it shows more (a phone that isn't 9:16):
## the game sits on the bottom edge, so this is mostly sky above it. The sky's top colour carries
## on for a band, then steps (a checker seam) into darker space, with sparse cool background
## stars and a few 3 px glints, like the background's own. Out to the sides, each row's edge
## colour carries on, with stars in the sky rows, except the forest floor under the HUD, which
## repeats across (the background draws it to tile every 180 px). Stars sit on a fixed hash of their position,
## so they never move. Drawn under everything; Main tells it where the game sits. Owns no rules.

const BACKGROUND := preload("res://assets/art/background.png")
## Above the game: this many rows of the sky's top colour, then a checker seam into N0.
const SKY_BAND: int = 24
const SEAM: int = 4
## Background stars: about one in STAR_ODDS pixels of margin sky, one in GLINT_ODDS of them a
## 3 px glint. Cool colours only (art-direction.md: background stars are 1 px and cool).
const STAR_ODDS: int = 110
const GLINT_ODDS: int = 14
const STAR_COLOURS: Array[Color] = [Palette.N7, Palette.N7, Palette.N8, Palette.M5]
## Stars in the side margins only above the land.
const SKY_BOTTOM: int = 230
## From this row down, the side margins repeat the forest floor instead of its edge colours.
const GROUND_TOP: int = 284

## The game's screen sits at `_offset` in a visible area of `_visible` px.
var _offset: Vector2i = Vector2i.ZERO
var _visible: Vector2i = ScreenZones.SCREEN
var _image: Image


func _ready() -> void:
	_image = BACKGROUND.get_image()


func _draw() -> void:
	if _image == null or _visible == ScreenZones.SCREEN:
		return
	var screen: Vector2i = ScreenZones.SCREEN
	var left: int = -_offset.x
	var right: int = _visible.x - _offset.x
	var top: int = -_offset.y
	var bottom: int = _visible.y - _offset.y
	for y: int in GROUND_TOP:
		if left < 0:
			draw_rect(Rect2(left, y, -left, 1), edge_colour(_image, 0, y))
		if right > screen.x:
			draw_rect(Rect2(screen.x, y, right - screen.x, 1), edge_colour(_image, screen.x - 1, y))
	for y: int in range(GROUND_TOP, screen.y):
		for x: int in range(left, 0):
			draw_rect(Rect2(x, y, 1, 1), ground_colour(_image, x, y))
		for x: int in range(screen.x, right):
			draw_rect(Rect2(x, y, 1, 1), ground_colour(_image, x, y))
	if top < 0:
		_draw_space(left, top, right)
	if bottom > screen.y:
		draw_rect(Rect2(left, screen.y, right - left, bottom - screen.y), edge_colour(_image, 0, screen.y - 1))
	for p: Vector2i in margin_stars(Rect2i(left, top, right - left, bottom - top)):
		_draw_star(p)


## The game sits at `offset` in a visible area of `visible` px.
func fit(offset: Vector2i, visible: Vector2i) -> void:
	_offset = offset
	_visible = visible
	queue_redraw()


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


func _draw_space(left: int, top: int, right: int) -> void:
	var sky_top: Color = edge_colour(_image, 0, 0)
	var solid: int = maxi(top, -SKY_BAND)
	draw_rect(Rect2(left, solid, right - left, -solid), sky_top)
	for y: int in range(top, solid):
		if -y - SKY_BAND > SEAM:
			draw_rect(Rect2(left, y, right - left, 1), Palette.N0)
			continue
		for x: int in range(left, right):
			draw_rect(Rect2(x, y, 1, 1), space_colour(x, y, sky_top))


func _draw_star(p: Vector2i) -> void:
	var h: int = _hash(p) / STAR_ODDS
	if h % GLINT_ODDS == 0:
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			draw_rect(Rect2(Vector2(p + n), Vector2.ONE), Palette.N7)
		draw_rect(Rect2(Vector2(p), Vector2.ONE), Palette.M5)
		return
	draw_rect(Rect2(Vector2(p), Vector2.ONE), STAR_COLOURS[h % STAR_COLOURS.size()])


## A fixed, well-mixed hash of a pixel (non-negative).
static func _hash(p: Vector2i) -> int:
	var h: int = p.x * 374761393 + p.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))
