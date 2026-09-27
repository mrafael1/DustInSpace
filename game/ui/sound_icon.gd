class_name SoundIcon
extends Node2D
## The HUD's speaker, 9x7 from this node's top-left: two sound arcs when on, one when low, a
## cross when muted. Drawn in code on whole pixels, cool (M5): it shouldn't pull the eye.
## Tapping it is the HUD's call; this only shows the level (Sfx.Level: ON, LOW, MUTE).

## 44 pt at 2 pt per px, from the screen's top-left corner, clear of the Sun and its counter.
const TARGET := Rect2i(-4, -4, 22, 22)
const SPEAKER: Array[String] = [
	"...#",
	"..##",
	"####",
	"####",
	"####",
	"..##",
	"...#",
]
const SMALL_ARC: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
const BIG_ARC: Array[Vector2i] = [Vector2i(6, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(6, 5)]
const CROSS: Array[Vector2i] = [Vector2i(5, 2), Vector2i(7, 2), Vector2i(6, 3), Vector2i(5, 4), Vector2i(7, 4)]

var level: int = 0:
	set(value):
		level = value
		queue_redraw()


func _draw() -> void:
	for dot: Vector2i in pixels(level):
		draw_rect(Rect2(Vector2(dot), Vector2.ONE), Palette.M5)


## The icon's pixels for a level, from its top-left.
static func pixels(p_level: int) -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	for y: int in SPEAKER.size():
		for x: int in SPEAKER[y].length():
			if SPEAKER[y][x] == "#":
				dots.append(Vector2i(x, y))
	match p_level:
		Sfx.Level.ON:
			dots.append_array(SMALL_ARC)
			dots.append_array(BIG_ARC)
		Sfx.Level.LOW:
			dots.append_array(SMALL_ARC)
		_:
			dots.append_array(CROSS)
	return dots
