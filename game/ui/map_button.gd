class_name MapButton
extends Node2D
## A small "MAP" plaque (#62): back to the chapter's chart. Drawn from this node's top-left like the
## buy buttons: M1 fill, a warm C2 border with clipped corners (it's interactive), a lighter fill
## while pressed. The text is a Label in the 5x7 font. Tapping it is the owner's call.

const SIZE := Vector2i(25, 11)
## 44 pt at 2 pt per px around the plaque.
const TARGET := Rect2i(-4, -6, 33, 22)

var pressed: bool = false:
	set(value):
		pressed = value
		queue_redraw()

@onready var _text: Label = $Text


func _ready() -> void:
	_text.label_settings = HudText.primary(Palette.C1)
	_text.position = Vector2(4, 2)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIZE))
	draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Palette.M3 if pressed else Palette.M1)
	draw_rect(Rect2(1, 0, r.size.x - 2, 1), Palette.C2)
	draw_rect(Rect2(1, r.size.y - 1, r.size.x - 2, 1), Palette.C2)
	draw_rect(Rect2(0, 1, 1, r.size.y - 2), Palette.C2)
	draw_rect(Rect2(r.size.x - 1, 1, 1, r.size.y - 2), Palette.C2)


## The tap target in the parent's coordinates.
func target() -> Rect2i:
	return Rect2i(TARGET.position + Vector2i(position), TARGET.size)
