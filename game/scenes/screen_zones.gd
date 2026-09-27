class_name ScreenZones
extends RefCounted
## Screen zones on the 180x320 grid, from docs/art-direction.md. Layout, not balance.
## Land overlaps the bottom of the sky on purpose: the horizon sits behind the lowest stars.

const SUN := Rect2i(0, 0, 180, 78)
const SKY := Rect2i(0, 78, 180, 172)
const LAND := Rect2i(0, 230, 180, 54)
const HUD := Rect2i(0, 284, 180, 36)
## The game's own screen. On a phone that isn't 9:16 the window shows more than this (Main sizes
## the view to fill the window at a whole-number scale, fill_size): the game sits at the bottom,
## centred across, and the Backdrop fills the rest (mostly sky above).
const SCREEN := Vector2i(180, 320)


## The largest whole-number scale at which the game's screen fits in a window of `window` px.
static func fill_scale(window: Vector2i) -> int:
	return maxi(1, mini(window.x / SCREEN.x, window.y / SCREEN.y))


## The view that fills a window of `window` px at fill_scale: as many game pixels as fit, never
## fewer than the game's screen. What's left over is under one scale step (a few device pixels).
static func fill_size(window: Vector2i) -> Vector2i:
	var scale: int = fill_scale(window)
	return Vector2i(window.x / scale, window.y / scale).max(SCREEN)


## Where the game's screen sits in a visible area of `visible` px, on whole pixels: centred across
## and on the bottom edge, so the HUD sits at the bottom and the extra height is sky above.
static func game_offset(visible: Vector2) -> Vector2i:
	var extra := Vector2i((visible - Vector2(SCREEN)).floor()).max(Vector2i.ZERO)
	return Vector2i(extra.x / 2, extra.y)


## A pointer event in the game's own 180x320 coordinates, from one in the visible area's.
static func to_game(event: InputEvent, offset: Vector2i) -> InputEvent:
	return event.xformed_by(Transform2D(0.0, Vector2(-offset)))
