extends GutTest
## The chapter chart (#62) and the flow between it and a stage.

const ChartScene := preload("res://game/scenes/chapter_select.tscn")
const AppScene := preload("res://game/scenes/app.tscn")
const STEP: float = 1.0 / 30.0

var chart: ChapterSelect
var store_path: String = "user://test_chapter_app_%d.json" % randi()


func before_each() -> void:
	chart = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set_process(false)


func after_each() -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))


func test_it_opens_on_the_stinger_ready_to_play() -> void:
	chart.setup(Chapter.new())
	assert_eq(chart.selected(), 0)
	assert_eq(ChapterSelect.stage_position(0), Scorpio.LANDMARKS[13], "its point is Shaula, the tail's tip")
	assert_true(chart.can_play())
	assert_eq(_label("Info").text, "STINGER")
	assert_eq(_label("Play").text, "PLAY")


func test_tapping_any_star_picks_the_part_it_belongs_to() -> void:
	for landmark: int in Scorpio.LANDMARKS.size():
		assert_eq(ChapterSelect.stage_at(Scorpio.LANDMARKS[landmark] + Vector2i(3, -3)), Chapter.stage_of(landmark))
	assert_eq(ChapterSelect.stage_at(ChapterSelect.FINAL_AT), Chapter.FINAL, "the crown is the final")
	assert_eq(ChapterSelect.stage_at(Vector2i(90, 30)), -1, "the title isn't a stage")


func test_play_on_an_available_stage_opens_it() -> void:
	chart.setup(Chapter.new())
	watch_signals(chart)
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [0])


func test_an_unbuilt_part_can_be_looked_at_but_never_played() -> void:
	var chapter := Chapter.new()
	chapter.set_built(4, false)
	chart.setup(chapter)
	watch_signals(chart)
	_tap(Scorpio.LANDMARKS[1])
	assert_eq(chart.selected(), 4, "the Claws")
	assert_false(chart.can_play())
	assert_false(_label("Play").visible, "no PLAY")
	assert_eq(_label("Info").text, "COMING SOON")
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_not_emitted(chart, "stage_chosen")


func test_the_final_is_playable_from_its_crown_point() -> void:
	chart.setup(Chapter.new())
	_tap(ChapterSelect.FINAL_AT)
	assert_eq(chart.selected(), Chapter.FINAL)
	assert_eq(_label("Info").text, "SCORPIO")
	assert_true(chart.can_play(), "open for playtesting")
	watch_signals(chart)
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [Chapter.FINAL])


func test_a_won_stage_can_be_replayed() -> void:
	var chapter := Chapter.new()
	chapter.complete(0)
	chapter.complete(1)
	chapter.complete(2)
	chapter.complete(3)
	chapter.complete(4)
	chapter.complete(Chapter.FINAL)
	chart.setup(chapter)
	assert_eq(chart.selected(), Chapter.FINAL, "all built stages won: the last one")
	assert_eq(_label("Play").text, "REPLAY")
	watch_signals(chart)
	_tap(ChapterSelect.PLAY.get_center())
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [Chapter.FINAL])


func test_selecting_a_stage_sends_a_comet_there() -> void:
	chart.setup(Chapter.new())
	_tap(Scorpio.LANDMARKS[8])
	assert_eq(chart.selected(), 1, "the Tail")
	assert_true(chart.is_travelling())
	for pair: Array in [[0, 2], [0, Chapter.FINAL]]:
		var pixels: Array[Vector2i] = ChapterSelect.travel_pixels(pair[0], pair[1])
		assert_eq(pixels[0], ChapterSelect.stage_position(pair[0]))
		assert_eq(pixels[-1], ChapterSelect.stage_position(pair[1]))
		for i: int in range(1, pixels.size()):
			assert_lte(maxi(absi(pixels[i].x - pixels[i - 1].x), absi(pixels[i].y - pixels[i - 1].y)), 1, "a whole-pixel path, no gaps")
	for i: int in 120:
		chart.advance(STEP)
	assert_false(chart.is_travelling(), "it arrives")


func test_back_from_a_win_its_stars_light_then_the_comet_travels_to_the_next() -> void:
	var chapter := Chapter.new()
	chapter.set_built(1, true)
	chart.setup(chapter)
	var unlocked: int = chapter.complete(0)
	chart.show_progress(0, unlocked)
	assert_true(chart.is_lighting())
	assert_eq(chart.selected(), 0)
	chart.advance(ChapterSelect.LIGHT_TIME + 0.01)
	assert_false(chart.is_lighting())
	assert_true(chart.is_travelling(), "then travels on")
	assert_eq(chart.selected(), 1, "to the part it opened")
	assert_true(chart.can_play())


func test_back_without_a_new_win_it_just_selects_the_stage_to_play() -> void:
	var chapter := Chapter.new()
	chart.setup(chapter)
	chart.show_progress(-1, -1)
	assert_false(chart.is_lighting() or chart.is_travelling())
	assert_eq(chart.selected(), 0)


func test_the_chart_draws_only_palette_colours() -> void:
	chart.setup(Chapter.new())
	# Colours the chart uses are all Palette constants (checked against the .gpl elsewhere).
	for colour: Color in ChapterSelect.TRAIL + ChapterSelect.LIGHT_COLOURS:
		assert_true(colour in [Palette.C0, Palette.C1, Palette.C2, Palette.C3, Palette.C4])


## A won part lights its stars and the strings among them; the part to play next is warm; the
## rest is a solid cool guide.
func test_a_won_part_lights_its_strings_and_the_next_part_warms() -> void:
	var chapter := Chapter.new()
	chapter.set_built(1, true)
	chart.setup(chapter)
	var inside: int = _segment(13, 12)
	var joint: int = _segment(11, 10)
	var beyond: int = _segment(9, 8)
	assert_eq(chart.string_legs()[inside], ChapterSelect.Leg.NEXT, "the Stinger to play: warm")
	assert_eq(chart.string_legs()[beyond], ChapterSelect.Leg.GUIDE)
	chapter.complete(0)
	chart.setup(chapter)
	var legs: Array = chart.string_legs()
	assert_eq(legs[inside], ChapterSelect.Leg.LIT, "the Stinger won: its strings light")
	assert_eq(legs[joint], ChapterSelect.Leg.NEXT, "the way on into the Tail")
	assert_eq(legs[beyond], ChapterSelect.Leg.NEXT, "and through it")


func test_every_part_won_lights_the_whole_figure() -> void:
	var chapter := Chapter.new()
	for stage: int in Chapter.stage_count():
		chapter.set_built(stage, true)
		chapter.complete(stage)
	chart.setup(chapter)
	for leg: ChapterSelect.Leg in chart.string_legs():
		assert_eq(leg, ChapterSelect.Leg.LIT, "every string lights, the claws' through the head too")


func test_the_stage_label_holds_the_name_and_play() -> void:
	chart.setup(Chapter.new())
	assert_true(ChapterSelect.PANEL.encloses(ChapterSelect.PLAY))
	var info: Label = _label("Info")
	assert_true(ChapterSelect.PANEL.has_point(Vector2i(info.position)))
	assert_true(ChapterSelect.label_areas()[0].has_point(Vector2i(info.position)), "the name keeps its row clear of stars")
	assert_true(ChapterSelect.label_areas()[1].encloses(ChapterSelect.PLAY))


## On a taller phone the heading goes to the top of the screen, the label and PLAY stay at the
## bottom (PLAY a little further from the name), and the chart is lifted halfway, its pixels whole.
func test_a_taller_screen_spreads_the_heading_chart_and_label() -> void:
	chart.setup(Chapter.new())
	var home_info: float = _label("Info").position.y
	chart.fit_screen(Rect2i(0, -80, 180, 400))
	assert_eq(chart.offset, Vector2(0, 40), "the chart lifts by half the extra height")
	var on_screen := func(label: String) -> float: return _label(label).position.y + chart.offset.y
	assert_eq(on_screen.call("Title"), float(ChapterSelect.TITLE_Y), "the heading at the top")
	assert_eq(on_screen.call("Subtitle"), float(ChapterSelect.SUBTITLE_Y))
	assert_eq(on_screen.call("Info"), home_info + 80, "the name at the bottom")
	var play: Rect2i = ChapterSelect.play_rect(Rect2i(0, -40, 180, 400))
	assert_eq(play.position.y + 40, ChapterSelect.PLAY.position.y + 80 + ChapterSelect.PLAY_ROOM, "PLAY a little lower")
	watch_signals(chart)
	_tap(play.get_center())
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [0])


## The chart sits in space: opaque, cool night colours only (warm is for the route and stages),
## the same on every build, and its stars keep clear of the stage points, title and panel.
func test_the_space_background_is_cool_opaque_and_clear_of_the_chart() -> void:
	var screen := Rect2i(-7, -102, 195, 422)
	var image: Image = ChapterSelect.space_image(screen)
	assert_eq(image.get_size(), screen.size, "the whole visible screen")
	var cool: Array[String] = []
	for colour: Color in [Palette.N0, Palette.N1, Palette.N2, Palette.N3, Palette.N4, Palette.N5, Palette.N7, Palette.N8, Palette.M5]:
		cool.append(colour.to_html(false))
	var off: Dictionary = {}
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			var c: Color = image.get_pixel(x, y)
			if c.a < 1.0 or not cool.has(c.to_html(false)):
				off[c.to_html()] = true
	assert_eq(off.keys(), [], "opaque, cool palette colours only")
	assert_eq(ChapterSelect.space_image(screen).get_data(), image.get_data(), "the same every time")
	var stars: Array[Vector2i] = ChapterSelect.space_stars(screen)
	assert_gt(stars.size(), 100, "a starry sky")
	for star: Vector2i in stars:
		for area: Rect2i in ChapterSelect.label_areas(screen):
			assert_false(area.has_point(star), "off the stage label")
		for point: Vector2i in Scorpio.LANDMARKS + [ChapterSelect.FINAL_AT]:
			assert_gte((point - star).length(), float(ChapterSelect.STAR_CLEAR), "clear of %s" % point)


## Each part's point is its main star: bigger than the other chart stars (a 3x3 block) and in its
## own tone, the point to play next the biggest; locked ones are icy blue, unlike the purple chart.
func test_main_stars_are_bigger_and_the_one_to_play_the_biggest() -> void:
	var warm: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
	var cool: Array[Color] = [Palette.M4, Palette.M5, Palette.M6]
	var sizes: Dictionary = {}
	for state: Chapter.PointState in [Chapter.PointState.LOCKED, Chapter.PointState.COMPLETED, Chapter.PointState.AVAILABLE]:
		for step: int in 3:
			var dots: Dictionary[Vector2i, Color] = ChapterSelect.main_star_pixels(state, step)
			assert_gt(dots.size(), 9, "bigger than a plain chart star")
			for d: Vector2i in dots:
				assert_true(dots[d] in (cool if state == Chapter.PointState.LOCKED else warm), "%s %s" % [state, dots[d]])
				assert_lt(d.length(), float(ChapterSelect.RING_RADIUS), "inside the ring")
		sizes[state] = ChapterSelect.main_star_pixels(state, 0).size()
	assert_gt(sizes[Chapter.PointState.AVAILABLE], sizes[Chapter.PointState.COMPLETED], "the one to play is the biggest")
	assert_gt(sizes[Chapter.PointState.COMPLETED], sizes[Chapter.PointState.LOCKED])


func test_main_stars_twinkle_each_on_its_own_beat() -> void:
	var twinkled_at: Array[float] = []
	for stage: int in Chapter.stage_count():
		var first: float = -1.0
		var on: int = 0
		var t: float = 0.0
		while t < ChapterSelect.TWINKLE_PERIOD:
			if ChapterSelect.twinkle_step(stage, t) == 1:
				on += 1
				if first < 0.0:
					first = t
			t += 0.01
		assert_almost_eq(on * 0.01, ChapterSelect.TWINKLE_ON, 0.03, "stage %d twinkles briefly once a beat" % stage)
		assert_false(twinkled_at.has(first), "stage %d on a beat of its own" % stage)
		twinkled_at.append(first)


func test_the_point_to_play_flares_brighter_once_a_beat() -> void:
	var steps: Array[int] = []
	var t: float = 0.0
	while t < ChapterSelect.FLARE_PERIOD:
		var step: int = ChapterSelect.flare_step(t)
		if steps.is_empty() or steps[-1] != step:
			steps.append(step)
		t += 0.01
	assert_eq(steps, [1, 2, 1, 0] as Array[int], "rises, flares, falls, rests")
	var rest: Dictionary[Vector2i, Color] = ChapterSelect.main_star_pixels(Chapter.PointState.AVAILABLE, 0)
	var flare: Dictionary[Vector2i, Color] = ChapterSelect.main_star_pixels(Chapter.PointState.AVAILABLE, 2)
	assert_gt(flare.size(), rest.size(), "longer arms and glints")
	assert_eq(flare[Vector2i(0, -3)], Palette.C0, "whiter")


func test_some_background_stars_twinkle_at_their_own_times() -> void:
	var screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
	var stars: Array[Vector2i] = ChapterSelect.space_stars(screen)
	var twinklers: Array[Vector2i] = ChapterSelect.twinkling_stars(screen)
	assert_gt(twinklers.size(), 20)
	assert_lt(twinklers.size(), stars.size(), "only some")
	for p: Vector2i in twinklers:
		assert_true(stars.has(p))
	for t: float in [0.0, 0.7, 1.9]:
		var lit: int = twinklers.filter(func(p: Vector2i) -> bool: return ChapterSelect.sky_twinkles(p, t)).size()
		assert_between(lit, 1, twinklers.size() / 3, "a few at a time (%s s)" % t)


func test_dust_motes_drift_slowly_along_the_milky_way() -> void:
	var motes: Array[Vector3] = ChapterSelect.mote_layout()
	assert_eq(motes.size(), ChapterSelect.MOTE_COUNT)
	assert_eq(ChapterSelect.mote_layout(), motes, "the same layout every time")
	var a := Vector2(ChapterSelect.MILKY_WAY[0])
	var along: Vector2 = Vector2(ChapterSelect.MILKY_WAY[1] - ChapterSelect.MILKY_WAY[0]).normalized()
	var start: Dictionary[Vector2i, Color] = ChapterSelect.mote_pixels(motes, 0.0)
	var later: Dictionary[Vector2i, Color] = ChapterSelect.mote_pixels(motes, 2.0)
	assert_ne(start.keys(), later.keys(), "they move")
	for p: Vector2i in later:
		assert_true(later[p] in ChapterSelect.MOTE_COLOURS, "cool, a step above the band")
		assert_lte(absf((Vector2(p) - a).dot(along.orthogonal())), ChapterSelect.MOTE_SPREAD + 1.0, "in the band")
	var moved: Array[float] = []
	for i: int in motes.size():
		var m: Vector3 = motes[i]
		assert_between(m.z, ChapterSelect.MOTE_SPEED.x, ChapterSelect.MOTE_SPEED.y, "slow")
		moved.append(m.z * 2.0)
	assert_lt(moved.max(), 9.0, "a few pixels in two seconds")


func test_a_shooting_star_flies_now_and_then_behind_the_chart() -> void:
	chart.fit_screen(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN))
	chart.setup(Chapter.new())
	chart.meteor_rng.seed = 3
	var waited: float = 0.0
	while not chart.is_meteor_flying() and waited < ChapterSelect.METEOR_WAIT.y + 1.0:
		chart.advance(STEP)
		waited += STEP
	assert_true(chart.is_meteor_flying(), "one comes within the longest wait")
	chart.advance(STEP * 3)
	var dots: Dictionary[Vector2i, Color] = chart.meteor_pixels()
	assert_gt(dots.size(), 3)
	for p: Vector2i in dots:
		assert_true(dots[p] in ChapterSelect.METEOR_TRAIL or dots[p] == Palette.M5, "cool colours only")
	var flown: float = 0.0
	while chart.is_meteor_flying() and flown < 2.0:
		chart.advance(STEP)
		flown += STEP
	assert_false(chart.is_meteor_flying(), "it streaks past quickly")
	assert_lt(flown, 1.0)
	assert_true(chart.meteor_pixels().is_empty())
	chart.advance(ChapterSelect.METEOR_WAIT.x - STEP)
	assert_false(chart.is_meteor_flying(), "the next waits its turn")


func test_app_opens_on_the_chart_then_stage_1_then_back() -> void:
	var app: App = _app()
	var app_chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_true(app_chart.visible)
	assert_null(app.stage())
	app.open_stage(0)
	var stage: Main = app.stage()
	assert_not_null(stage, "the Stinger opens from the tail")
	assert_true(stage.in_chapter)
	assert_eq(stage.run.scorpio.map.id, "stinger", "playing its own map")
	assert_false(app_chart.visible)
	assert_true((stage.get_node("HUD") as Hud).is_map_button_shown(), "with a way back")
	stage.map_requested.emit()
	assert_null(app.stage())
	assert_true(app_chart.visible, "back on the chart")


func test_a_locked_stage_never_opens() -> void:
	var app: App = _app()
	app.open_stage(1)
	assert_null(app.stage())


func test_the_final_plays_the_full_scorpio() -> void:
	var app: App = _app()
	app.open_stage(Chapter.FINAL)
	assert_eq(app.stage().run.scorpio.map.id, "scorpio")
	assert_eq(app.stage().run.scorpio.map.count(), 14)


func test_a_win_lights_the_point_and_survives_a_restart() -> void:
	var app: App = _app()
	app.open_stage(0)
	app.stage().run.run_won.emit()
	app.back_to_chart()
	var app_chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_true(app.chapter.is_completed(0))
	assert_true(app_chart.is_lighting(), "its stars light as the chart comes back")
	app.queue_free()
	await get_tree().process_frame
	var again: App = _app()
	assert_true(again.chapter.is_completed(0), "the app restarted with the progress kept")
	assert_eq((again.get_node("ChapterSelect") as ChapterSelect).selected(), 1, "the Tail is next")


func test_the_tail_opens_after_the_stinger_and_plays_its_own_map_with_orion() -> void:
	var app: App = _app()
	app.open_stage(1)
	assert_null(app.stage(), "locked before the Stinger is won")
	app.open_stage(0)
	app.stage().run.run_won.emit()
	app.back_to_chart()
	assert_eq(app.chapter.state(1), Chapter.PointState.AVAILABLE)
	app.open_stage(1)
	assert_eq(app.stage().run.scorpio.map.id, "tail")
	assert_not_null(app.stage().run.orion, "Orion hunts the Tail")


func test_the_body_opens_after_the_tail_and_plays_its_own_map_with_the_volley() -> void:
	var app: App = _app()
	app.open_stage(0)
	app.stage().run.run_won.emit()
	app.back_to_chart()
	app.open_stage(2)
	assert_null(app.stage(), "locked before the Tail is won")
	app.open_stage(1)
	app.stage().run.run_won.emit()
	app.back_to_chart()
	assert_eq(app.chapter.state(2), Chapter.PointState.AVAILABLE)
	app.open_stage(2)
	assert_eq(app.stage().run.scorpio.map.id, "body")
	assert_not_null(app.stage().run.volley, "Orion's volley on the Body")
	assert_null(app.stage().run.orion, "no single marks there")
	app.stage().run.run_won.emit()
	app.back_to_chart()
	assert_true(app.chapter.is_completed(2), "its win is recorded")


func test_a_loss_changes_nothing() -> void:
	var app: App = _app()
	app.open_stage(0)
	app.stage().run.run_lost.emit()
	app.back_to_chart()
	assert_false(app.chapter.is_completed(0))
	assert_false((app.get_node("ChapterSelect") as ChapterSelect).is_lighting())


func test_the_hud_map_button_asks_for_the_chart() -> void:
	var app: App = _app()
	app.open_stage(0)
	var hud: Hud = app.stage().get_node("HUD")
	var backed: Array[bool] = []
	app.stage().map_requested.connect(func() -> void: backed.append(true))
	var at: Vector2i = hud.map_target().get_center()
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		hud.handle_pointer(touch)
	assert_eq(backed, [true])


func test_the_map_button_only_shows_in_a_chapter_and_clears_the_speaker() -> void:
	var main: Main = preload("res://game/scenes/main.tscn").instantiate()
	add_child_autofree(main)
	var hud: Hud = main.get_node("HUD")
	assert_false(hud.is_map_button_shown(), "a stage played on its own has no MAP")
	hud.show_map_button(true)
	assert_false(hud.map_target().intersects(hud.sound_target()))
	assert_true(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN).encloses(hud.map_target()), "on screen")


func test_the_end_screen_offers_the_map_in_a_chapter() -> void:
	var app: App = _app()
	app.open_stage(0)
	var end: EndScreen = app.stage().get_node("EndScreen")
	assert_true(end.map_enabled)
	var run: RunState = app.stage().run
	run.outcome = RunState.Outcome.WON
	end.call("_show_end")
	assert_ne(end.map_rect(), Rect2i(), "MAP beside RESTART")
	assert_false(end.map_rect().intersects(end.restart_rect()))
	var backed: Array[bool] = []
	end.map_requested.connect(func() -> void: backed.append(true))
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(end.map_rect().get_center())
		touch.pressed = pressed
		end.handle_pointer(touch)
	assert_eq(backed, [true])


func _segment(a: int, b: int) -> int:
	for segment: int in Scorpio.segment_count():
		var pair: Vector2i = Scorpio.SEGMENTS[segment]
		if (pair.x == a and pair.y == b) or (pair.x == b and pair.y == a):
			return segment
	return -1


func _app() -> App:
	var app: App = AppScene.instantiate()
	app.progress_path = store_path
	add_child_autofree(app)
	return app


func _label(name: String) -> Label:
	return chart.get_node(name)


func _tap(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		chart.handle_pointer(touch)
