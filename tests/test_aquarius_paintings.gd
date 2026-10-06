extends GutTest
## The painted Aquarius (tools/art/build_aquarius_figure.py): the whole, its five pieces and each
## stage's own painting, every one anchored to its stars and drawn from the palette.

const PARTS: Array[String] = ["hand", "body", "legs", "stream", "jar"]


func _image(path: String) -> Image:
	return ConstellationView.painting(path).get_image()


func test_the_pieces_cut_the_whole_exactly_and_each_carries_its_stars() -> void:
	var def: ChapterDef = ChapterDef.aquarius()
	var whole: Image = _image(StarMap.AQUARIUS_FIGURE)
	var pieces: Array[Image] = []
	for stage: int in Chapter.FINAL:
		pieces.append(_image(def.piece_path(stage)))
	for y: int in range(0, whole.get_height(), 2):
		for x: int in range(0, whole.get_width(), 2):
			var owners: int = 0
			for piece: Image in pieces:
				if piece.get_pixel(x, y).a8 == 255:
					owners += 1
					assert_eq(piece.get_pixel(x, y), whole.get_pixel(x, y))
			assert_eq(owners, 1 if whole.get_pixel(x, y).a8 == 255 else 0, "(%d, %d)" % [x, y])
	var chapter := Chapter.new(def)
	for stage: int in Chapter.FINAL:
		for star: int in chapter.stars(stage):
			var at: Vector2i = def.figure.landmarks[star]
			assert_eq(pieces[stage].get_pixelv(at).a8, 255, "%s holds star %d" % [chapter.stage_name(stage), star])


func test_each_stage_painting_sits_under_its_own_stars() -> void:
	for part: String in PARTS:
		var map: StarMap = StarMap.by_id("aquarius_" + part)
		var painting: Image = _image(map.painting)
		for at: Vector2i in map.landmarks:
			assert_eq(painting.get_pixelv(at).a8, 255, "%s: star at %s" % [part, at])
	var final: StarMap = StarMap.aquarius_final()
	assert_eq(final.painting, StarMap.AQUARIUS_FIGURE, "the final rises the whole painting")


func test_the_paintings_are_palette_only_with_no_partial_alpha() -> void:
	var palette: Dictionary = {}
	for line: String in FileAccess.get_file_as_string("res://assets/palettes/stellar_sun.hex").split("\n", false):
		palette[line.strip_edges().to_lower()] = true
	var paths: Array[String] = [StarMap.AQUARIUS_FIGURE]
	for part: String in PARTS:
		paths.append("res://assets/art/aquarius_piece_%s.png" % part)
		paths.append(StarMap.AQUARIUS_PART % part)
	for path: String in paths:
		var image: Image = _image(path)
		assert_eq(image.get_size(), Vector2i(180, 320), path)
		for y: int in range(0, image.get_height(), 3):
			for x: int in image.get_width():
				var c: Color = image.get_pixel(x, y)
				assert_true(c.a8 == 0 or c.a8 == 255, "%s (%d, %d) alpha" % [path, x, y])
				if c.a8 == 255 and not palette.has(c.to_html(false)):
					fail_test("%s (%d, %d) off palette: %s" % [path, x, y, c.to_html(false)])
					return
