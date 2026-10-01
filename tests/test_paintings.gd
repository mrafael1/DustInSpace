extends GutTest
## The Scorpio's paintings (tools/art/build_scorpio_figure.py): each map's painting, shown when it's
## complete, and the chart's pieces of the whole, assembled as the parts are won.

const ChartScene := preload("res://game/scenes/chapter_select.tscn")
const PALETTE_PATH := "res://assets/palettes/stellar_sun.gpl"
const STEP: float = 1.0 / 60.0

const MAPS: Array[String] = ["stinger", "tail", "body", "heart", "claws", "final", "scorpio"]


func test_every_map_paints_under_its_own_stars() -> void:
	var allowed: Dictionary = _palette()
	for id: String in MAPS:
		var map: StarMap = StarMap.by_id(id)
		var image: Image = ConstellationView.painting(map.painting).get_image()
		assert_eq(image.get_size(), ScreenZones.SCREEN, "%s: the game's screen, home layout" % id)
		var bad: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				var c: Color = image.get_pixel(x, y)
				if c.a8 != 0 and (c.a8 != 255 or not allowed.has(c.to_html(false))):
					bad += 1
		assert_eq(bad, 0, "%s: opaque palette colours or nothing" % id)
		for landmark: Vector2i in map.landmarks:
			assert_eq(image.get_pixelv(landmark).a8, 255, "%s: every star sits on the body" % id)
		var span: Vector2i = ConstellationView.figure_span(map.painting)
		assert_true(span.x >= Scorpio.HOME_SKY.position.y - 8 and span.y < Scorpio.HOME_SKY.end.y, "%s: in the sky" % id)


func test_the_pieces_make_up_the_whole_scorpio_exactly() -> void:
	var whole: Image = ConstellationView.painting().get_image()
	var pieces: Array[Image] = []
	for stage: int in Chapter.FINAL:
		pieces.append(ConstellationView.painting(ChapterSelect.piece_path(stage)).get_image())
	for y: int in whole.get_height():
		for x: int in whole.get_width():
			var owners: int = 0
			for piece: Image in pieces:
				if piece.get_pixel(x, y).a8 == 255:
					owners += 1
					assert_eq(piece.get_pixel(x, y), whole.get_pixel(x, y))
			assert_eq(owners, 1 if whole.get_pixel(x, y).a8 == 255 else 0, "one piece per pixel at %d,%d" % [x, y])
			if owners != (1 if whole.get_pixel(x, y).a8 == 255 else 0):
				return


func test_each_piece_carries_its_parts_stars() -> void:
	for stage: int in Chapter.FINAL:
		var piece: Image = ConstellationView.painting(ChapterSelect.piece_path(stage)).get_image()
		for star: int in Chapter.stars(stage):
			assert_eq(piece.get_pixelv(Scorpio.LANDMARKS[star]).a8, 255, "%s holds landmark %d" % [Chapter.stage_name(stage), star])


func test_the_chart_assembles_dormant_pieces_then_the_final_brings_them_to_life() -> void:
	var chart: ChapterSelect = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set_process(false)
	var chapter := Chapter.new()
	chart.setup(chapter)
	for stage: int in Chapter.stage_count():
		assert_false(chart.shows_piece(stage), "nothing before a win")
	chapter.complete(0)
	chart.show_progress(0, 1)
	assert_true(chart.shows_piece(0))
	assert_false(chart.shows_piece(1))
	assert_true(chart.is_figure_rising(), "the Stinger's piece rises")
	for frame: int in ceili((ConstellationView.FIGURE_RISE + ConstellationView.FIGURE_FLASH) / STEP) + 2:
		chart.advance(STEP)
	assert_false(chart.is_figure_rising())
	assert_false(chart.shows_figure(), "dormant until the final")
	var dormant: Image = ChapterSelect.dormant_piece(0).get_image()
	var bright: Image = ConstellationView.painting(ChapterSelect.piece_path(0)).get_image()
	var darker: int = 0
	for y: int in bright.get_height():
		for x: int in bright.get_width():
			if bright.get_pixel(x, y).a8 == 255:
				assert_eq(dormant.get_pixel(x, y).a8, 255)
				if dormant.get_pixel(x, y).get_luminance() < bright.get_pixel(x, y).get_luminance():
					darker += 1
	assert_gt(darker, 100, "dormant: stepped down the ramp")
	for stage: int in Chapter.stage_count():
		chapter.complete(stage)
	chart.show_progress(Chapter.FINAL, -1)
	assert_true(chart.shows_figure())
	assert_true(ChapterSelect.life_flashing(0.05), "it flashes as it comes to life")
	assert_false(ChapterSelect.life_flashing(ChapterSelect.LIFE_TIME))
	for frame: int in ceili(ChapterSelect.LIFE_TIME / STEP) + 2:
		chart.advance(STEP)
	assert_false(chart.is_figure_rising())


func _palette() -> Dictionary:
	var allowed: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 4 and fields[0].is_valid_int():
			allowed[Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()).to_html(false)] = true
	return allowed
