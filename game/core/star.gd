class_name Star
extends RefCounted
## One star in the sky. Size is the only thing that matters for combos.

enum Size { SMALL, MEDIUM, BIG }

const SIZE_KEYS: Array[String] = ["small", "medium", "big"]

var id: int = 0
var size: Size = Size.SMALL
## Integer position on the 180x320 grid.
var position: Vector2i = Vector2i.ZERO


func _init(p_id: int = 0, p_size: Size = Size.SMALL, p_position: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	size = p_size
	position = p_position


static func size_key(p_size: Size) -> String:
	return SIZE_KEYS[p_size]
