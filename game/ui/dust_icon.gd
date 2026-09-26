class_name DustIcon
extends Node2D
## The dust icon: a faceted diamond on the dust ramp, 9x9 (or 5x5 when `small`), centred on
## this node. Lit from the top-left like everything else. Art: assets/art/dust_icon.png.

@export var small: bool = false:
	set(value):
		small = value
		queue_redraw()


func _draw() -> void:
	ArtStrip.named("dust_icon").draw(self, "small" if small else "large")


## Offsets from the centre, read from the art. Facets: top-left D0, top-right and bottom-left N8,
## bottom-right N7.
static func pixels(p_small: bool) -> Dictionary[Vector2i, Color]:
	return ArtStrip.named("dust_icon").pixels("small" if p_small else "large")
