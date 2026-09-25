class_name PackView
extends Node2D
## One star pack, drawn in code from its ramp until the pack art lands (#13).
## Blue: a banded planet, r8. Red: a smaller planet with a ring. Lit from the top-left, no outline.
## Tremble frames are drawn, never scaled: `grown` draws the next radius up, `bright` shifts
## every pixel one step up its ramp.

const RADIUS: Dictionary[String, int] = {"blue": 8, "red": 6}
## Red pack ring: an ellipse this wide and tall around the planet.
const RING_RADII := Vector2(10.5, 3.5)

## "" draws nothing.
var kind: String = "":
	set(value):
		kind = value
		queue_redraw()
var grown: bool = false:
	set(value):
		grown = value
		queue_redraw()
var bright: bool = false:
	set(value):
		bright = value
		queue_redraw()
## Draws the planet at this radius instead of the kind's own (0 = the kind's). The HUD uses r6.
var radius_override: int = 0:
	set(value):
		radius_override = value
		queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels(kind, grown, bright, radius_override)
	for offset: Vector2i in dots:
		draw_rect(Rect2(Vector2(offset), Vector2.ONE), dots[offset])


## The pack's pixels as offsets from its centre. Empty for an unknown kind.
static func pixels(p_kind: String, p_grown: bool = false, p_bright: bool = false, p_radius: int = 0) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if not RADIUS.has(p_kind):
		return dots
	var ramp: Array[Color] = Palette.RED_PACK if p_kind == "red" else Palette.BLUE_PACK
	var radius: int = (p_radius if p_radius > 0 else RADIUS[p_kind]) + (1 if p_grown else 0)
	var lift: int = 1 if p_bright else 0
	if p_kind == "red":
		_add_ring(dots, ramp, lift, radius, false)
	_add_planet(dots, ramp, lift, radius)
	if p_kind == "red":
		_add_ring(dots, ramp, lift, radius, true)
	return dots


## A disc shaded in 5 steps from the top-left, with a wavy darker band every 4 rows.
static func _add_planet(dots: Dictionary[Vector2i, Color], ramp: Array[Color], lift: int, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + radius:
				continue
			var light: float = float(dx + dy + 2 * radius) / float(4 * radius)
			var step: int = ramp.size() - 1 - clampi(int(light * ramp.size()), 0, ramp.size() - 1)
			var wave: int = 1 if posmod(dx, 6) < 3 else 0
			if posmod(dy + wave, 4) == 0:
				step -= 1
			dots[Vector2i(dx, dy)] = ramp[clampi(step + lift, 0, ramp.size() - 1)]


## The ring's back half is drawn before the planet, its front half after, so it wraps around.
static func _add_ring(dots: Dictionary[Vector2i, Color], ramp: Array[Color], lift: int, radius: int, front: bool) -> void:
	var radii := RING_RADII + Vector2.ONE * (radius - RADIUS["red"])
	for dy: int in range(-ceili(radii.y), ceili(radii.y) + 1):
		for dx: int in range(-ceili(radii.x), ceili(radii.x) + 1):
			var e: float = pow(dx / radii.x, 2) + pow(dy / radii.y, 2)
			if e < 0.6 or e > 1.05:
				continue
			if (dy >= 0) != front:
				continue
			dots[Vector2i(dx, dy)] = ramp[clampi(3 + lift, 0, ramp.size() - 1) if dy >= 0 else 2]
