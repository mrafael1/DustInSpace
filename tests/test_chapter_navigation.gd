extends GutTest
## Going between chapters on the chart: an arrow either side of the heading (a chevron to an open
## chapter, a padlock to a locked one, none at the ends), a swipe, the slide between charts, and
## the next chapter's opening after its final's win (the padlock bursts, the chart slides on and
## reveals it).

const AppScene := preload("res://game/scenes/app.tscn")
const ChartScene := preload("res://game/scenes/chapter_select.tscn")
const STORE := "user://test_chapter_navigation.json"


func after_each() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))


func _app() -> App:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	add_child_autofree(app)
	return app


func _save(id: String, won: int) -> void:
	var def: ChapterDef = ChapterDef.scorpio()
	for each: ChapterDef in ChapterDef.all():
		if each.id == id:
			def = each
	var chapter := Chapter.new(def)
	for stage: int in won:
		chapter.set_built(stage, true)
		chapter.complete(stage)
	ProgressStore.new(STORE).save_chapter(id, chapter.to_save())


func _tap(chart: ChapterSelect, at: Vector2i, to: Vector2i = Vector2i(-1, -1)) -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = Vector2(at)
	chart.handle_pointer(press)
	var release := InputEventScreenTouch.new()
	release.pressed = false
	release.position = Vector2(to if to.x >= 0 else at)
	chart.handle_pointer(release)


func _play(chart: ChapterSelect, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		chart.advance(0.02)
		t += 0.02


func test_the_arrows_lead_to_open_chapters_and_padlocks_to_locked_ones() -> void:
	var fresh: App = _app()
	var chart: ChapterSelect = fresh.get_node("ChapterSelect")
	assert_eq(chart.navigation(-1), ChapterSelect.Nav.NONE, "nothing before Scorpio")
	assert_eq(chart.navigation(1), ChapterSelect.Nav.LOCKED, "Aquarius is locked")
	fresh.queue_free()
	await get_tree().process_frame
	_save("scorpio", Chapter.stage_count())
	var app: App = _app()
	chart = app.get_node("ChapterSelect")
	assert_eq(app.chapter.id, "aquarius")
	assert_eq(chart.navigation(-1), ChapterSelect.Nav.OPEN, "back to Scorpio")
	assert_eq(chart.navigation(1), ChapterSelect.Nav.LOCKED, "Leo still locked")


func test_an_arrow_slides_the_chart_to_the_open_chapter() -> void:
	_save("scorpio", Chapter.stage_count())
	var app: App = _app()
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	var slid: Array[int] = []
	chart.slid.connect(func() -> void: slid.append(1))
	_tap(chart, chart.nav_centre(-1))
	assert_eq(app.chapter.id, "scorpio", "the app is on Scorpio at once")
	assert_true(chart.is_sliding())
	assert_true(chart.is_busy(), "taps wait for the slide")
	assert_eq(slid.size(), 1)
	chart.advance(ChapterSelect.SLIDE_OUT * 0.5)
	assert_gt(chart.slide_x(), 0, "going back, Aquarius leaves to the right")
	chart.advance(ChapterSelect.SLIDE_OUT * 0.6)
	assert_eq(chart.get_node("Title").text, "SCORPIO", "the new chart once the old one is out")
	assert_lt(chart.slide_x(), 0, "and Scorpio comes in from the left")
	_play(chart, ChapterSelect.SLIDE_IN)
	assert_false(chart.is_sliding())
	assert_eq(chart.slide_x(), 0)
	assert_eq(chart.navigation(1), ChapterSelect.Nav.OPEN, "and the way back to Aquarius")


func test_a_swipe_steps_chapter_and_a_short_drag_doesnt() -> void:
	_save("scorpio", Chapter.stage_count())
	var app: App = _app()
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	_tap(chart, Vector2i(100, 200), Vector2i(90, 202))
	assert_eq(app.chapter.id, "aquarius", "too short")
	_tap(chart, Vector2i(60, 200), Vector2i(120, 204))
	assert_eq(app.chapter.id, "scorpio", "a swipe right pulls in the chapter before")


func test_a_padlock_shakes_and_says_why() -> void:
	var app: App = _app()
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	var refused: Array[int] = []
	chart.nav_refused.connect(func() -> void: refused.append(1))
	_tap(chart, chart.nav_centre(1))
	assert_eq(app.chapter.id, "scorpio", "a locked chapter doesn't open")
	assert_false(chart.is_sliding())
	assert_eq(refused.size(), 1)
	assert_eq(chart.get_node("Subtitle").text, ChapterSelect.REFUSE_TEXT)
	_tap(chart, Vector2i(140, 200), Vector2i(80, 200))
	assert_eq(refused.size(), 2, "a swipe towards it is refused too")
	_play(chart, ChapterSelect.REFUSE_SAY + 0.1)
	assert_eq(chart.get_node("Subtitle").text, "CHAPTER 1", "then the heading comes back")


func test_winning_a_final_opens_the_next_chapter_on_the_chart() -> void:
	_save("scorpio", Chapter.FINAL)
	var app: App = _app()
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_eq(app.chapter.id, "scorpio")
	var heard: Array[String] = []
	chart.padlock_shaken.connect(func() -> void: heard.append("shake"))
	chart.padlock_broke.connect(func() -> void: heard.append("break"))
	chart.chapter_revealed.connect(func() -> void: heard.append("revealed"))
	var pops: Array[int] = []
	chart.star_revealed.connect(func(order: int) -> void: pops.append(order))
	app.open_stage(Chapter.FINAL)
	app.stage().stage_won.emit()
	app.back_to_chart()
	assert_true(chart.is_opening(), "the opening waits for the figure's life")
	assert_eq(app.chapter.id, "scorpio")
	_play(chart, ChapterSelect.LIFE_TIME + ChapterSelect.LIGHT_TIME + ChapterSelect.OPEN_TIME)
	assert_eq(heard.slice(0, 2), ["shake", "break"] as Array[String])
	assert_eq(app.chapter.id, "aquarius", "the comet left: the chart slides on")
	_play(chart, ChapterSelect.SLIDE_OUT + ChapterSelect.SLIDE_IN + 0.04)
	assert_true(chart.is_revealing())
	var card: BossBanner = chart.get_node("RevealCard")
	card.advance(0.05)
	assert_true(card.is_showing(), "AQUARIUS stamps over CHAPTER 2 IS OPEN")
	assert_false(chart.revealed(ChapterSelect.reveal_order(app.chapter.def)[-1]), "the last star isn't in yet")
	_play(chart, ChapterSelect.REVEAL_SAY + 0.1)
	assert_eq(pops.size(), ChapterSelect.reveal_order(app.chapter.def).size(), "every star popped in")
	assert_true(heard.has("revealed"))
	assert_false(chart.is_revealing())
	assert_eq(chart.get_node("Subtitle").text, "CHAPTER 2")
	assert_eq(chart.selected(), app.chapter.current(), "the stage to play is selected")
	assert_eq(chart.navigation(-1), ChapterSelect.Nav.OPEN)


func test_a_replayed_final_opens_nothing() -> void:
	_save("scorpio", Chapter.stage_count())
	var app: App = _app()
	app.switch_chapter()
	app.switch_chapter()
	assert_eq(app.chapter.id, "scorpio")
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	app.open_stage(Chapter.FINAL)
	app.stage().stage_won.emit()
	app.back_to_chart()
	assert_false(chart.is_opening())


func test_the_reveal_pops_every_part_star_once() -> void:
	for def: ChapterDef in ChapterDef.all():
		var order: Array[int] = ChapterSelect.reveal_order(def)
		var sorted: Array[int] = order.duplicate()
		sorted.sort()
		assert_eq(sorted, range(def.figure.count()), "%s: every star of the figure, once" % def.id)


func test_the_arrows_and_padlocks_are_palette_and_grid() -> void:
	for side: int in [-1, 1]:
		var chevron: Array[Vector2i] = ChapterSelect.chevron_pixels(side)
		assert_gt(chevron.size(), 10)
		for p: Vector2i in chevron:
			assert_eq(signi(p.x) * side >= -1, true)
	var lock: Dictionary[Vector2i, Color] = ChapterSelect.padlock_pixels(Palette.N7)
	assert_true(lock.values().has(Palette.N3), "a keyhole")
	assert_eq(ChapterSelect.shard_pixels(0.0).size(), ChapterSelect.OPEN_SHARDS)
