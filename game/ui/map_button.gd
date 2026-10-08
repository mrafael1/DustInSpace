class_name MapButton
extends Node2D
## A small "MAP" plaque (#62): back to the chapter's chart. Drawn from this node's top-left like the
## buy buttons: M1 fill, a warm C2 border with clipped corners (it's interactive), a lighter fill
## while pressed. The text is a Label in the 5x7 font. Tapping it is the owner's call. The same
## plaque carries other words (`text`, e.g. the HUD's COMBOS), sized to them, or a glyph instead
## (`glyph`: the options' gear, the stage's pause), C1 like the text, on a narrower plaque.

enum Glyph { NONE, GEAR, PAUSE }

const SIZE := Vector2i(25, 11)
## A glyph's plaque.
const GLYPH_SIZE := Vector2i(15, 11)
## 44 pt at 2 pt per px around the plaque.
const TARGET := Rect2i(-4, -6, 33, 22)
## The text sits this far in from the plaque's left; as far again on the right.
const TEXT_INSET: int = 4
## The glyphs, 7x7, centred in their plaque.
const GLYPHS: Dictionary[Glyph, Array] = {
	Glyph.GEAR: [
		"..#.#..",
		".#####.",
		"##...##",
		".#...#.",
		"##...##",
		".#####.",
		"..#.#..",
	],
	Glyph.PAUSE: [
		".##.##.",
		".##.##.",
		".##.##.",
		".##.##.",
		".##.##.",
		".##.##.",
		".##.##.",
	],
}

## The word on the plaque.
@export var text: String = "MAP":
	set(value):
		text = value
		if _text != null:
			_text.text = value
		queue_redraw()
## A glyph instead of the word.
@export var glyph: Glyph = Glyph.NONE:
	set(value):
		glyph = value
		if _text != null:
			_text.visible = value == Glyph.NONE
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
	_text.visible = glyph == Glyph.NONE


## The plaque's size: SIZE for MAP, wider for a longer word (6 px a letter in the 5x7 font),
## GLYPH_SIZE for a glyph.
func plaque_size() -> Vector2i:
	if glyph != Glyph.NONE:
		return GLYPH_SIZE
	return Vector2i(maxi(SIZE.x, 2 * TEXT_INSET + text.length() * 6 - 1), SIZE.y)


## A glyph's pixels from its top-left.
static func glyph_pixels(which: Glyph) -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	var rows: Array = GLYPHS.get(which, [])
	for y: int in rows.size():
		for x: int in (rows[y] as String).length():
			if (rows[y] as String)[x] == "#":
				dots.append(Vector2i(x, y))
	return dots


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(plaque_size()))
	draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Palette.M3 if pressed else Palette.M1)
	draw_rect(Rect2(1, 0, r.size.x - 2, 1), Palette.C2)
	draw_rect(Rect2(1, r.size.y - 1, r.size.x - 2, 1), Palette.C2)
	draw_rect(Rect2(0, 1, 1, r.size.y - 2), Palette.C2)
	draw_rect(Rect2(r.size.x - 1, 1, 1, r.size.y - 2), Palette.C2)
	if glyph == Glyph.NONE:
		return
	var at := Vector2i((GLYPH_SIZE.x - 7) / 2, (GLYPH_SIZE.y - 7) / 2)
	for dot: Vector2i in glyph_pixels(glyph):
		draw_rect(Rect2(Vector2(at + dot + Vector2i.ONE), Vector2.ONE), Palette.N0)
	for dot: Vector2i in glyph_pixels(glyph):
		draw_rect(Rect2(Vector2(at + dot), Vector2.ONE), Palette.C0 if pressed else Palette.C1)


## The tap target in the parent's coordinates (44 pt tall, the plaque's width plus 4 px each side,
## never narrower than 44 pt).
func target() -> Rect2i:
	var width: int = maxi(plaque_size().x + 8, 22)
	return Rect2i(TARGET.position + Vector2i(position), Vector2i(width, TARGET.size.y))
