class_name ScreenZones
extends RefCounted
## Screen zones on the 180x320 grid, from docs/art-direction.md. Layout, not balance.
## Land overlaps the bottom of the sky on purpose: the horizon sits behind the lowest stars.

const SUN := Rect2i(0, 0, 180, 78)
const SKY := Rect2i(0, 78, 180, 172)
const LAND := Rect2i(0, 230, 180, 54)
const HUD := Rect2i(0, 284, 180, 36)
## The game's own screen. On a phone that isn't 9:16 the window shows more than this (the
## project's stretch aspect is "expand", at a whole-number scale): the game stays centred and
## the Backdrop fills the margins.
const SCREEN := Vector2i(180, 320)


## Where the game's screen sits in a visible area of `visible` px: centred, on whole pixels.
static func game_offset(visible: Vector2) -> Vector2i:
	return Vector2i(((visible - Vector2(SCREEN)) / 2.0).floor()).max(Vector2i.ZERO)


## A pointer event in the game's own 180x320 coordinates, from one in the visible area's.
static func to_game(event: InputEvent, offset: Vector2i) -> InputEvent:
	return event.xformed_by(Transform2D(0.0, Vector2(-offset)))
