class_name HudText
extends RefCounted
## Label styles for the bitmap fonts (art-direction.md): 5x7 for primary counters and 3x5 for
## secondary numbers, each with a 1 px N0 drop shadow. Font sizes match the fonts' own pixel
## size, so glyphs are never scaled. Colours come from Palette.

const PRIMARY_FONT: FontFile = preload("res://assets/fonts/font_5x7.png")
const SECONDARY_FONT: FontFile = preload("res://assets/fonts/font_3x5.png")
const PRIMARY_SIZE: int = 7
const SECONDARY_SIZE: int = 5


static func primary(color: Color) -> LabelSettings:
	return _settings(PRIMARY_FONT, PRIMARY_SIZE, color)


static func secondary(color: Color) -> LabelSettings:
	return _settings(SECONDARY_FONT, SECONDARY_SIZE, color)


static func _settings(font: FontFile, size: int, color: Color) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = size
	settings.font_color = color
	settings.shadow_color = Palette.N0
	settings.shadow_offset = Vector2(1, 1)
	settings.shadow_size = 0
	return settings
