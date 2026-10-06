extends GutTest
## Chapter 2 (Aquarius) beside Scorpio: its definition, its own progress, when it opens, and its
## chart.

const AppScene := preload("res://game/scenes/app.tscn")
const ChartScene := preload("res://game/scenes/chapter_select.tscn")
const STORE := "user://test_chapters_progress.json"


func after_each() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))


func _app() -> App:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	add_child_autofree(app)
	return app


func _scorpio_won() -> void:
	var scorpio := Chapter.new()
	for stage: int in Chapter.stage_count():
		scorpio.set_built(stage, true)
		scorpio.complete(stage)
	ProgressStore.new(STORE).save_chapter("scorpio", scorpio.to_save())


func test_every_chapter_has_five_parts_and_a_final_and_its_own_id() -> void:
	var ids: Array[String] = []
	for def: ChapterDef in ChapterDef.all():
		assert_eq(def.stages.size(), Chapter.stage_count(), def.id)
		assert_eq(def.stages[Chapter.FINAL]["stars"], [], "%s's final is the whole figure" % def.id)
		assert_false(ids.has(def.id))
		ids.append(def.id)
	assert_eq(ids, ["scorpio", "aquarius"] as Array[String], "campaign order")
	assert_eq(ChapterDef.aquarius().unlocked_by, "scorpio")
	assert_eq(ChapterDef.scorpio().unlocked_by, "", "the first is open from the start")


func test_the_aquarius_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.aquarius()
	var figure: StarMap = def.figure
	assert_eq(figure.count(), 14)
	assert_eq(figure.segment_count(), 13, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(Scorpio.HOME_SKY)
	for i: int in figure.count():
		assert_true(inner.has_point(figure.landmarks[i]), "star %d sits in the sky" % i)
		assert_gt(Vector2(figure.landmarks[i]).distance_to(Vector2(def.final_at)), 24.0, "the crown keeps clear")
		for j: int in range(i + 1, figure.count()):
			assert_gte(Vector2(figure.landmarks[i]).distance_to(Vector2(figure.landmarks[j])), 24.0, "%d and %d" % [i, j])
	for segment: int in figure.segment_count():
		var ends: Array[Vector2i] = figure.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 24.0, 32.0)
	var owned: Array[int] = []
	for stage: int in Chapter.FINAL:
		owned.append_array(def.stages[stage]["stars"])
	owned.sort()
	assert_eq(owned, range(14), "every star belongs to exactly one part")
	assert_eq(StarMap.by_id("aquarius").title, "AQUARIUS")


func test_aquarius_is_its_own_chapter_and_fully_built() -> void:
	var aquarius := Chapter.new(ChapterDef.aquarius())
	assert_eq(aquarius.id, "aquarius")
	assert_eq(aquarius.stage_name(4), "JAR", "the jar, where the water comes from, is the last part")
	assert_eq(aquarius.stage_of(5), 4, "eta is in the jar")
	assert_eq(aquarius.state(0), Chapter.PointState.AVAILABLE, "the Hand (tests/test_aquarius_stages.gd)")
	for stage: int in Chapter.stage_count():
		assert_ne(aquarius.map_id(stage), "", "every stage is built")
	assert_eq(aquarius.state(Chapter.FINAL), Chapter.PointState.LOCKED, "the final waits for every part")
	assert_eq(Chapter.new().id, "scorpio", "Scorpio by default")


func test_aquarius_opens_once_scorpios_final_is_won_and_the_chart_opens_on_it() -> void:
	var app: App = _app()
	assert_eq(app.chapter.id, "scorpio")
	assert_false(app.is_open(app.chapters[1]))
	app.queue_free()
	await get_tree().process_frame
	_scorpio_won()
	var again: App = _app()
	assert_true(again.is_open(again.chapters[1]))
	assert_eq(again.chapter.id, "aquarius", "the latest open chapter")


func test_the_chapter_plaque_switches_the_chart_and_each_keeps_its_progress() -> void:
	_scorpio_won()
	var app: App = _app()
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_true(chart.is_chapter_switch_shown())
	assert_eq(chart.get_node("ChapterButton").text, "SCORPIO")
	assert_false(chart.is_tutorial_button_shown(), "the guided run is Scorpio's")
	app.switch_chapter()
	assert_eq(app.chapter.id, "scorpio")
	assert_eq(chart.get_node("ChapterButton").text, "AQUARIUS")
	assert_true(app.chapter.is_completed(Chapter.FINAL), "Scorpio's progress is its own")
	assert_eq(ProgressStore.new(STORE).load_chapter("aquarius"), {}, "nothing saved for Aquarius")


func test_the_aquarius_chart_draws_its_own_figure_and_paintings() -> void:
	var chart: ChapterSelect = ChartScene.instantiate()
	add_child_autofree(chart)
	var def: ChapterDef = ChapterDef.aquarius()
	var aquarius := Chapter.new(def)
	for stage: int in Chapter.stage_count():
		aquarius.set_built(stage, true)
		aquarius.complete(stage)
	chart.setup(aquarius)
	assert_eq((chart.get_node("Title") as Label).text, "AQUARIUS")
	assert_eq((chart.get_node("Subtitle") as Label).text, "CHAPTER 2")
	assert_eq(ChapterSelect.stage_position(4, def), def.figure.landmarks[3], "the jar's point is Sadachbia")
	assert_eq(ChapterSelect.stage_position(Chapter.FINAL, def), def.final_at)
	assert_eq(ChapterSelect.stage_at(def.figure.landmarks[12] + Vector2i(2, 2), def), 3, "psi is in the stream")
	assert_true(chart.shows_piece(0), "the Hand's piece of the painting")
	assert_true(chart.shows_figure(), "the painted Aquarius, once the final is won")
	assert_eq(ChapterSelect.piece_path(0, def), "res://assets/art/aquarius_piece_hand.png", "pieces are named by part")
	var bare: ChapterDef = ChapterDef.aquarius()
	bare.piece = "res://assets/art/not_drawn_%s.png"
	assert_false(ChapterSelect.has_art(ChapterSelect.piece_path(0, bare)), "art that isn't there is left out")
	var background: Array[Vector2i] = ChapterSelect.space_stars(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN), def)
	for star: Vector2i in def.figure.landmarks:
		for p: Vector2i in background:
			assert_true((star - p).length_squared() >= ChapterSelect.STAR_CLEAR * ChapterSelect.STAR_CLEAR, "clear of the figure")
	var path: Array[Vector2i] = ChapterSelect.travel_pixels(3, 4, def)
	assert_eq(path[0], def.figure.landmarks[11], "the stream's comet leaves phi")
	assert_eq(path[-1], def.figure.landmarks[3], "and climbs to the jar, through the knee and the head")
	(chart.get_node("Chart") as CanvasItem).queue_redraw()
	await get_tree().process_frame
