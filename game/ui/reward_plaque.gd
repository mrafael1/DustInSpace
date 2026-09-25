class_name RewardPlaque
extends Control
## The 46x11 plaque shown while linking: what the traced link would pay.
## N0 fill, N6 border with clipped corners (art-direction.md). Numbers are Labels, never art.
## Uses the default font until the bitmap fonts land (#14). Owns no rules: it shows what it's given.

const PLAQUE_SIZE := Vector2i(46, 11)
## Gap between the star's sprite and the plaque.
const GAP: int = 2

@onready var _dust: Label = $Dust
@onready var _light: Label = $Light
@onready var _no_combo: Label = $NoCombo


func _ready() -> void:
	size = Vector2(PLAQUE_SIZE)
	visible = false
	# Set here, not in the scene, so every colour comes from Palette (tested against the .gpl).
	_dust.add_theme_color_override("font_color", Palette.D0)
	_light.add_theme_color_override("font_color", Palette.C1)
	_no_combo.add_theme_color_override("font_color", Palette.N7)


func _draw() -> void:
	var w: int = PLAQUE_SIZE.x
	var h: int = PLAQUE_SIZE.y
	draw_rect(Rect2(1, 1, w - 2, h - 2), Palette.N0)
	# Border without its four corner pixels.
	draw_rect(Rect2(1, 0, w - 2, 1), Palette.N6)
	draw_rect(Rect2(1, h - 1, w - 2, 1), Palette.N6)
	draw_rect(Rect2(0, 1, 1, h - 2), Palette.N6)
	draw_rect(Rect2(w - 1, 1, 1, h - 2), Palette.N6)


## Shows the reward of a valid link above (or below) the star at `anchor`.
func show_reward(dust: int, light: int, anchor: Vector2i, star_half: int, sky: Rect2i) -> void:
	_dust.text = "+%d" % dust
	_light.text = "+%d" % light
	_set_valid(true)
	_show_at(anchor, star_half, sky)


## Shows that the traced stars are not a combination.
func show_no_combo(anchor: Vector2i, star_half: int, sky: Rect2i) -> void:
	_set_valid(false)
	_show_at(anchor, star_half, sky)


## Top-left corner for a plaque by the star at `anchor` whose sprite reaches `star_half` px
## from its centre: centred above it, or below it when above would leave the sky; never off screen.
static func place(anchor: Vector2i, star_half: int, sky: Rect2i) -> Vector2i:
	var x: int = clampi(anchor.x - (PLAQUE_SIZE.x >> 1), sky.position.x, sky.end.x - PLAQUE_SIZE.x)
	var y: int = anchor.y - star_half - GAP - PLAQUE_SIZE.y
	if y < sky.position.y:
		y = anchor.y + star_half + GAP + 1
	return Vector2i(x, y)


func _set_valid(valid: bool) -> void:
	_dust.visible = valid
	_light.visible = valid
	_no_combo.visible = not valid


func _show_at(anchor: Vector2i, star_half: int, sky: Rect2i) -> void:
	position = Vector2(place(anchor, star_half, sky))
	visible = true
