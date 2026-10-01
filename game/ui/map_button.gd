class_name MapButton
extends Node2D
## A small "MAP" plaque (#62): back to the chapter's chart. Drawn from this node's top-left like the
## buy buttons: M1 fill, a warm C2 border with clipped corners (it's interactive), a lighter fill
## while pressed. The text is a Label in the 5x7 font. Tapping it is the owner's call. The same
## plaque carries other words (`text`, e.g. the chart's TUTORIAL), sized to them.

const SIZE := Vector2i(25, 11)
## 44 pt at 2 pt per px around the plaque.
const TARGET := Rect2i(-4, -6, 33, 22)
## The text sits this far in from the plaque's left; as far again on the right.
const TEXT_INSET: int = 4

## The word on the plaque.
@export var text: String = "MAP":
	set(value):
		text = value
		if _text != null:
			_text.text = value
		queue_redraw()

var pressed: bool = false:
	set(value):
		pressed = value
		queue_redraw()

@onready var _text: Label = $Text


func _ready() -> void:
	_text.label_settings = HudText.primary(Palette.C1)
	_text.position = Vector2(TEXT_INSET, 2)
	_text.text = text


## The plaque's size: SIZE for MAP, wider for a longer word (6 px a letter in the 5x7 font).
func plaque_size() -> Vector2i:
	return Vector2i(maxi(SIZE.x, 2 * TEXT_INSET + text.length() * 6 - 1), SIZE.y)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(plaque_size()))
	draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Palette.M3 if pressed else Palette.M1)
	draw_rect(Rect2(1, 0, r.size.x - 2, 1), Palette.C2)
	draw_rect(Rect2(1, r.size.y - 1, r.size.x - 2, 1), Palette.C2)
	draw_rect(Rect2(0, 1, 1, r.size.y - 2), Palette.C2)
	draw_rect(Rect2(r.size.x - 1, 1, 1, r.size.y - 2), Palette.C2)


## The tap target in the parent's coordinates (44 pt tall, the plaque's width plus 4 px each side).
func target() -> Rect2i:
	var extra: int = plaque_size().x - SIZE.x
	return Rect2i(TARGET.position + Vector2i(position), TARGET.size + Vector2i(extra, 0))
