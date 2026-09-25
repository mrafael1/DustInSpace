class_name ScreenZones
extends RefCounted
## Screen zones on the 180x320 grid, from docs/art-direction.md. Layout, not balance.
## Land overlaps the bottom of the sky on purpose: the horizon sits behind the lowest stars.

const SUN := Rect2i(0, 0, 180, 78)
const SKY := Rect2i(0, 78, 180, 172)
const LAND := Rect2i(0, 230, 180, 54)
const HUD := Rect2i(0, 284, 180, 36)
