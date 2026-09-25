class_name DustIcon
extends Node2D
## The dust icon: a faceted diamond on the dust ramp, 9x9 (or 5x5 when `small`), centred on
## this node. Lit from the top-left like everything else. Drawn in code until #13's art.

@export var small: bool = false:
	set(value):
		small = value
		queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels(small)
	for offset: Vector2i in dots:
		draw_rect(Rect2(Vector2(offset), Vector2.ONE), dots[offset])


## Offsets from the centre. Facets: top-left D0, top-right and bottom-left N8, bottom-right N7.
static func pixels(p_small: bool) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var r: int = 2 if p_small else 4
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if absi(dx) + absi(dy) > r:
				continue
			var colour: Color = Palette.N8
			if dx <= 0 and dy <= 0:
				colour = Palette.D0
			elif dx > 0 and dy > 0:
				colour = Palette.N7
			dots[Vector2i(dx, dy)] = colour
	return dots
