extends GutTest
## Every line the game shows is drawn in the bitmap fonts, which have only the glyphs their import
## lists (letters, digits, space and + - / ×): no comma, no full stop, no apostrophe (#148). Checks
## every all-caps text constant in the game's scripts against them.

const FONTS: Array[String] = ["res://assets/fonts/font_5x7.png.import", "res://assets/fonts/font_3x5.png.import"]
const SCRIPT_DIRS: Array[String] = ["res://game/ui", "res://game/scenes", "res://game/fx", "res://game/core"]


func test_every_shown_line_has_its_glyphs() -> void:
	for font: String in FONTS:
		var glyphs: Dictionary = _glyphs(font)
		assert_false(glyphs.is_empty(), font)
		var checked: int = 0
		for path: String in _scripts():
			var constants: Dictionary = (load(path) as Script).get_script_constant_map()
			for name: String in constants:
				for line: String in _lines(constants[name]):
					checked += 1
					for c: String in line.replace("%d", "0").replace("%s", "A").replace("\n", " "):
						assert_true(glyphs.has(c.unicode_at(0)), "%s %s: %s has no glyph for '%s'" % [path.get_file(), name, font.get_file(), c])
		assert_gt(checked, 20, "the lines were found")


func test_the_flow_line_has_no_comma() -> void:
	assert_false(Hud.FLOW_MESSAGE.contains(","))


## The code points `import_path`'s font draws (its character_ranges, "a" or "a-b").
func _glyphs(import_path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(import_path) != OK:
		return {}
	var glyphs: Dictionary = {}
	for entry: String in config.get_value("params", "character_ranges", PackedStringArray()):
		var ends: PackedStringArray = entry.split("-")
		for code: int in range(ends[0].to_int(), ends[ends.size() - 1].to_int() + 1):
			glyphs[code] = true
	return glyphs


func _scripts() -> Array[String]:
	var paths: Array[String] = []
	for dir: String in SCRIPT_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				paths.append(dir.path_join(file))
	return paths


## The shown lines in a constant: its all-caps strings (ids, paths and keys are lower case), in it or
## in its arrays and dictionaries' values. Pixel art drawn from rows of characters (the hand) isn't
## text.
func _lines(value: Variant) -> Array[String]:
	var lines: Array[String] = []
	match typeof(value):
		TYPE_STRING:
			var text: String = value
			if text != text.to_lower() and text == text.to_upper() and not text.contains("://"):
				lines.append(text)
		TYPE_ARRAY:
			if _is_pixel_art(value):
				return lines
			for item: Variant in value:
				lines.append_array(_lines(item))
		TYPE_DICTIONARY:
			for item: Variant in (value as Dictionary).values():
				lines.append_array(_lines(item))
	return lines


## Whether `rows` is pixel art: several strings of one length, none with a space.
func _is_pixel_art(rows: Array) -> bool:
	if rows.size() < 2:
		return false
	for row: Variant in rows:
		if typeof(row) != TYPE_STRING or (row as String).contains(" ") or (row as String).length() != (rows[0] as String).length():
			return false
	return true
