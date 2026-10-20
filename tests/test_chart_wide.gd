extends GutTest
## The chart and title on a wide (landscape) screen (docs/wide_sky_design.md §4, commit 20): the
## sky's steps bend down past the sign's span, the open charts beside the one shown are cool, named
## faintly and not tappable (Q6), the background stars keep off them, a voyage draws the chart shown
## alike on both sides of its swap, the opening's comet ends on the next crown when it's on screen,
## the reveal's sparkles stay round the chapter, and the space is built once per screen rect. A
## portrait screen, a phone with spare columns included, keeps the 9:16 chart.

const AppScene := preload("res://game/scenes/app.tscn")
const STORE := "user://test_chart_wide.json"
## 1280x720 (640x360 visible) as App hands it to the chart, and a 195x422 phone.
const WIDE := Rect2i(-230, -40, 640, 360)
const PHONE := Rect2i(-7, -102, 195, 422)


func after_each() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))


func _save(id: String, won: int) -> void:
	for def: ChapterDef in ChapterDef.all():
		if def.id != id:
			continue
		var chapter := Chapter.new(def)
		for stage: int in won:
			chapter.set_built(stage, true)
			chapter.complete(stage)
		ProgressStore.new(STORE).save_chapter(id, chapter.to_save())


## An App on Leo (Scorpio, Aquarius and Leo won; Virgo open, two parts won), its chart on `screen`.
func _leo(screen: Rect2i) -> ChapterSelect:
	_save("scorpio", Chapter.stage_count())
	_save("aquarius", Chapter.stage_count())
	_save("leo", Chapter.stage_count())
	_save("virgo", 2)
	var app: App = AppScene.instantiate()
	app.opens_on_title = false
	app.progress_path = STORE
	add_child_autofree(app)
	app.chapter = app.chapters[2]
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	chart.setup(app.chapter)
	chart.fit_screen(screen)
	return chart


func _local(screen: Rect2i) -> Rect2i:
	# fit_screen lifts the chart by half the extra rows.
	var extra: int = maxi(0, -screen.position.y)
	return Rect2i(screen.position + Vector2i(0, extra / 2), screen.size)


func _tap(chart: ChapterSelect, at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.pressed = pressed
		touch.position = Vector2(at)
		chart.handle_pointer(touch)


func _heading(chart: ChapterSelect, id: String) -> Array:
	return chart.get("_chapter_headings")[id]


func _name(chart: ChapterSelect, id: String) -> Label:
	return chart.get("_chapter_names")[id]


func test_only_a_landscape_screen_is_wide() -> void:
	assert_true(ChapterSelect.is_wide(WIDE))
	assert_true(ChapterSelect.is_wide(Rect2i(-251, -64, 683, 384)), "a 1366x768 laptop")
	assert_true(ChapterSelect.is_wide(Rect2i(-336, -40, 853, 360)), "ultrawide")
	assert_true(ChapterSelect.is_wide(Rect2i(-166, -64, 512, 384)), "an iPad on its side")
	assert_false(ChapterSelect.is_wide(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)))
	assert_false(ChapterSelect.is_wide(PHONE), "a phone with spare columns stays portrait")
	assert_false(ChapterSelect.is_wide(Rect2i(0, -40, 360, 360)), "a square one too")


func test_the_skys_steps_bend_only_past_the_signs_span() -> void:
	for x: int in ChapterSelect.SKY_SPAN:
		assert_eq(ChapterSelect.step_bend(x), 0)
	assert_eq(ChapterSelect.step_bend(-1), ChapterSelect.step_bend(ChapterSelect.SKY_SPAN), "symmetric round the span")
	assert_eq(ChapterSelect.step_bend(-100), ChapterSelect.step_bend(ChapterSelect.SKY_SPAN - 1 + 100))
	assert_gt(ChapterSelect.step_bend(-230), 80, "well down at a 640 screen's edge")
	assert_eq(ChapterSelect.step_bend(-2000), ChapterSelect.SKY_BEND_MAX, "capped")
	var last: int = 0
	for out: int in range(1, 400):
		assert_true(ChapterSelect.step_bend(-out) >= last, "never rises going out")
		last = ChapterSelect.step_bend(-out)


func test_the_wide_space_matches_the_portrait_one_over_the_signs_span() -> void:
	var portrait := Rect2i(0, -20, 180, 360)
	var wide := Rect2i(-230, -20, 640, 360)
	var a: Image = ChapterSelect.space_image(portrait, null, false)
	var b: Image = ChapterSelect.space_image(wide, null, false)
	for y: int in range(0, 360, 3):
		for x: int in range(0, 180, 3):
			assert_eq(b.get_pixel(x + 230, y), a.get_pixel(x, y))
	# Out at the edge the steps come lower: more of the column is the darkest step than unbent.
	var start := Vector2(ChapterSelect.MILKY_WAY[0])
	var along: Vector2 = (Vector2(ChapterSelect.MILKY_WAY[1]) - start).normalized()
	var bent: int = 0
	var flat: int = 0
	for y: int in 360:
		bent += 1 if b.get_pixel(0, y) == Palette.N0 else 0
		flat += 1 if ChapterSelect._space_colour(Vector2i(-230, y - 20), start, along) == Palette.N0 else 0
	assert_gt(bent, flat + 60, "the darkest step reaches well lower at the edge")
	for y: int in 360:
		for x: int in range(0, 640, 7):
			var c: Color = b.get_pixel(x, y)
			if not c in [Palette.N0, Palette.N1, Palette.N2, Palette.N3, Palette.N4, Palette.N5]:
				fail_test("not a cool palette colour at %d,%d" % [x, y])
				return


func test_the_portrait_space_is_flat() -> void:
	var image: Image = ChapterSelect.space_image(PHONE, null, false)
	var a := Vector2(ChapterSelect.MILKY_WAY[0])
	var along: Vector2 = (Vector2(ChapterSelect.MILKY_WAY[1]) - a).normalized()
	for y: int in range(0, PHONE.size.y, 5):
		for x: int in [0, 3, 6, 100, 190, 194]:
			assert_eq(image.get_pixel(x, y), ChapterSelect._space_colour(Vector2i(x, y) + PHONE.position, a, along))


func test_the_space_is_built_once_per_screen_rect() -> void:
	var one: ImageTexture = ChapterSelect.space_texture(WIDE)
	assert_same(ChapterSelect.space_texture(WIDE), one, "kept")
	var other: ImageTexture = ChapterSelect.space_texture(Rect2i(-251, -64, 683, 384))
	assert_ne(other, one, "another size, another image")
	assert_eq(other.get_size(), Vector2(683, 384))
	assert_ne(ChapterSelect.space_texture(Rect2i(-230, -20, 640, 360)), one, "another place, another image")
	for k: int in ChapterSelect.SPACE_CACHE:
		ChapterSelect.space_texture(Rect2i(0, -k, 180, 320 + k))
	assert_ne(ChapterSelect.space_texture(WIDE), one, "bounded: the oldest made way and is built again")
	var chart: ChapterSelect = _leo(WIDE)
	assert_same(chart.get("_space"), ChapterSelect.space_texture(_local(WIDE)), "the chart uses the kept one")


func test_on_a_wide_screen_only_the_signs_span_takes_a_tap() -> void:
	var portrait := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
	assert_eq(ChapterSelect.chart_span(portrait), portrait)
	assert_eq(ChapterSelect.chart_span(PHONE), PHONE, "a phone's spare columns still take taps")
	var local: Rect2i = _local(WIDE)
	assert_eq(ChapterSelect.chart_span(local), Rect2i(0, local.position.y, ChapterSelect.SKY_SPAN, local.size.y))


func test_a_neighbours_stars_are_not_tappable() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	watch_signals(chart)
	var virgo: ChapterDef = ChapterDef.virgo()
	var x: int = chart.call("_place_x", "virgo")
	assert_eq(x, ChapterSelect.SKY_SPAN, "Virgo is the next sign")
	var before: int = chart.selected()
	for landmark: int in virgo.figure.count():
		_tap(chart, virgo.figure.landmarks[landmark] + Vector2i(x, 0))
		_tap(chart, virgo.final_at + Vector2i(x, 0))
	assert_eq(chart.selected(), before, "nothing selected")
	assert_signal_not_emitted(chart, "stage_chosen")
	# The chart shown still takes its own.
	var leo: ChapterDef = ChapterDef.leo()
	var other: int = 0 if before != 0 else 1
	_tap(chart, ChapterSelect.stage_position(other, leo))
	assert_eq(chart.selected(), other)


func test_wide_neighbours_are_named_faintly_and_portrait_ones_keep_their_heading() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	var heading: Array = _heading(chart, "virgo")
	assert_false((heading[0] as Label).visible, "no heading beside the chart")
	assert_false((heading[1] as Label).visible)
	assert_true(_name(chart, "virgo").visible, "named faintly under it")
	assert_true(_name(chart, "virgo").position.x > ChapterSelect.SKY_SPAN)
	# On a 9:16 screen an open neighbour on screen (mid-voyage) shows its heading.
	var narrow: ChapterSelect = _leo(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN))
	narrow.set("_camera", float(ChapterSelect.sky_x("leo") + 90))
	narrow.call("_place_passing")
	assert_true((_heading(narrow, "virgo")[0] as Label).visible)
	assert_false(_name(narrow, "virgo").visible)


func test_the_background_stars_keep_off_the_neighbours() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	var points: Array[Vector2i] = chart.neighbour_points()
	var virgo: ChapterDef = ChapterDef.virgo()
	assert_eq(points.size(), virgo.figure.count() + 1, "Virgo's stars and crown")
	assert_true(points.has(virgo.final_at + Vector2i(ChapterSelect.SKY_SPAN, 0)))
	var local: Rect2i = _local(WIDE)
	var stars: Array[Vector3i] = ChapterSelect.sky_stars(local, ChapterDef.leo(), 0, 0, 0, 0, [], points)
	for star: Vector3i in stars:
		for p: Vector2i in points:
			assert_true((Vector2i(star.x, star.y) - p).length_squared() >= ChapterSelect.STAR_CLEAR * ChapterSelect.STAR_CLEAR)
	assert_lt(stars.size(), ChapterSelect.sky_stars(local, ChapterDef.leo()).size(), "some made way")
	assert_eq(_leo(PHONE).neighbour_points(), [] as Array[Vector2i], "none on a portrait screen")


func test_a_wide_voyage_names_the_chart_shown_faintly_until_the_star_lands() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	var app: App = chart.get_parent()
	app.step_chapter(1)
	chart.advance(0.05)
	var title: Label = chart.get("_title")
	assert_false(title.visible, "the heading waits for the landing")
	assert_true(_name(chart, "leo").visible, "Leo named faintly as it's left")
	assert_true(_name(chart, "virgo").visible)
	# Past the swap, still alike.
	while chart.voyage_progress() < 0.6:
		chart.advance(0.05)
	assert_false(title.visible)
	assert_true(_name(chart, "virgo").visible, "Virgo, now the chart shown, still named faintly")
	assert_true(_name(chart, "leo").visible)
	while chart.is_voyaging():
		chart.advance(0.05)
	assert_true(title.visible, "the heading is back as the star lands")
	assert_eq(title.text, "VIRGO")
	assert_false(_name(chart, "virgo").visible)


func test_the_opening_comet_ends_on_the_next_crown_when_its_on_screen() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	var crown: Vector2i = ChapterDef.virgo().final_at + Vector2i(ChapterSelect.SKY_SPAN, 0)
	assert_eq(chart.opening_end(), crown)
	assert_eq(chart.opening_path().back(), crown)
	assert_eq(chart.opening_path()[0], ChapterDef.leo().final_at, "from Leo's crown")
	var narrow: ChapterSelect = _leo(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN))
	assert_eq(narrow.opening_end(), Vector2i(ScreenZones.SCREEN.x + 12, narrow.nav_centre(1).y), "off the edge by the arrow")
	var phone: ChapterSelect = _leo(PHONE)
	assert_eq(phone.opening_end().x, PHONE.end.x + 12, "a phone too")
	# Scorpio's next (Aquarius) is three signs on: off a 640 screen, so off its edge.
	var scorpio: ChapterSelect = _leo(WIDE)
	var app: App = scorpio.get_parent()
	scorpio.setup(app.chapters[0])
	assert_eq(scorpio.opening_end(), Vector2i(_local(WIDE).end.x + 12, scorpio.nav_centre(1).y))


func test_the_reveal_lifts_off_where_the_comet_ended() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	var app: App = chart.get_parent()
	var end: Vector2i = chart.opening_end()
	chart.voyage_to(app.chapters[3], true)
	assert_eq(chart.lead_star(), end, "the star starts on Virgo's crown")


func test_the_reveal_sparkles_stay_round_the_chapter() -> void:
	var chart: ChapterSelect = _leo(WIDE)
	var local: Rect2i = _local(WIDE)
	for i: int in ChapterSelect.REVEAL_SPARKLES:
		var at: Vector2i = chart.sparkle_at(i)
		assert_true(at.x >= 0 and at.x < ChapterSelect.SKY_SPAN, "in the sign's span")
		assert_true(at.y >= local.position.y and at.y < local.end.y)
	var narrow: ChapterSelect = _leo(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN))
	var phone: ChapterSelect = _leo(PHONE)
	var wider: bool = false
	for i: int in ChapterSelect.REVEAL_SPARKLES:
		assert_true(narrow.sparkle_at(i).x >= 6 and narrow.sparkle_at(i).x < 174)
		wider = wider or phone.sparkle_at(i).x < 0 or phone.sparkle_at(i).x >= ChapterSelect.SKY_SPAN
	assert_true(wider, "a phone keeps its whole screen, as before")
