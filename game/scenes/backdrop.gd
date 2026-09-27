class_name Backdrop
extends Node2D
## Fills the margins around the game's 180x320 screen when the window shows more (a phone that
## isn't 9:16): the sky's top colour above, the ground's colour below, and each row's edge colour
## out to the sides, so the background just carries on. Drawn under everything; Main tells it
## where the game sits. Owns no rules.

const BACKGROUND := preload("res://assets/art/background.png")

## The margins' size around the game's screen: left/top, and the visible area's size.
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
	for y: int in screen.y:
		if _offset.x > 0:
			draw_rect(Rect2(left, y, -left, 1), edge_colour(_image, 0, y))
		if right > screen.x:
			draw_rect(Rect2(screen.x, y, right - screen.x, 1), edge_colour(_image, screen.x - 1, y))
	if top < 0:
		draw_rect(Rect2(left, top, right - left, -top), edge_colour(_image, 0, 0))
	if bottom > screen.y:
		draw_rect(Rect2(left, screen.y, right - left, bottom - screen.y), edge_colour(_image, 0, screen.y - 1))


## The game sits at `offset` in a visible area of `visible` px.
func fit(offset: Vector2i, visible: Vector2i) -> void:
	_offset = offset
	_visible = visible
	queue_redraw()


## The background's colour at (x, y), opaque.
static func edge_colour(image: Image, x: int, y: int) -> Color:
	var c: Color = image.get_pixel(x, y)
	return Color(c.r, c.g, c.b)
