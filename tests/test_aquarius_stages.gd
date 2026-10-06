extends GutTest
## Aquarius stages 1 to 4: the Hand teaches the flow alone, the Body brings the drain, the Legs
## branch either side of it, the Stream pours down. Each reads its own current step from
## balance.json, ramping up.

const AppScene := preload("res://game/scenes/app.tscn")
const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const STORE := "user://test_aquarius_stages_progress.json"


func after_each() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))


func _check_pickable(map: StarMap) -> void:
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [map.id, i])
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	assert_false(map.orion or map.hunt or map.volley != "", "Orion stays in chapter 1")


func test_the_hand_teaches_the_flow_alone() -> void:
	var map: StarMap = StarMap.aquarius_hand()
	_check_pickable(map)
	assert_eq(map.count(), 5)
	assert_eq(map.starting_lit, [0] as Array[int], "the shoulder starts lit: four to light")
	assert_false(map.current_drains, "no drain yet")
	assert_eq(map.current_region, Rect2i(72, SKY.position.y, SKY.end.x - 72, SKY.size.y), "full height from x 72")
	for index: int in [1, 2]:
		assert_true(map.current_region.has_point(map.landmarks[index]), "the upper arm is in the flow")
	for index: int in [3, 4]:
		assert_false(map.current_region.has_point(map.landmarks[index]), "the forearm and hand catch what it brings")
	for segment: int in map.segment_count():
		var ends: Array[Vector2i] = map.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 33.0, 36.0)
	assert_eq(StarMap.by_id("aquarius_hand").title, "HAND")


func test_the_body_brings_the_drain_on_the_measured_layout() -> void:
	var map: StarMap = StarMap.aquarius_body()
	_check_pickable(map)
	assert_true(map.current_drains)
	assert_eq(map.current_region.position.x, 48)
	assert_eq(map.starting_lit, [0] as Array[int], "five to light")
	var trial: StarMap = StarMap.aquarius_flow()
	assert_eq(trial.landmarks, map.landmarks, "the trial plays the Body's layout")
	assert_eq(trial.current_region, map.current_region)
	assert_true(trial.current_drains)
	assert_false(StarMap.aquarius_flow(false).current_region.has_area())
	assert_eq(StarMap.by_id("aquarius_body").title, "BODY")


func test_each_stage_reads_its_own_step_from_the_balance_file() -> void:
	var file: Balance = Balance.load_file()
	assert_true(file.is_valid(), str(file.errors))
	assert_eq(file.current_step_for("aquarius_hand"), 24)
	assert_eq(file.current_step_for("aquarius_body"), 24)
	assert_eq(file.current_step_for("aquarius_legs"), 28, "the chapter ramps up")
	assert_eq(file.current_step_for("aquarius_stream"), 32)
	assert_eq(file.current_step_for("aquarius_jar"), 56, "the hardest part: a step as long as a link's reach")
	assert_eq(file.current_step_for("current_trial"), file.current_step, "anything else uses the default")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))
	data.currents = {"step": 24, "stages": {"aquarius_hand": 16}}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), SKY, StarMap.aquarius_hand())
	assert_eq(run.current.displacement, Vector2i(-16, 0), "the stage's own step")
	data.currents = {"step": 24, "stages": {"aquarius_hand": 0}}
	assert_false(Balance.from_dict(data).is_valid(), "a step must move stars")


func test_aquarius_opens_on_the_hand_and_winning_it_opens_the_body() -> void:
	var chapter := Chapter.new(ChapterDef.aquarius())
	assert_eq(chapter.map_id(0), "aquarius_hand")
	assert_eq(chapter.map_id(1), "aquarius_body")
	assert_eq(chapter.map_id(2), "aquarius_legs")
	assert_eq(chapter.map_id(3), "aquarius_stream")
	assert_eq(chapter.map_id(4), "aquarius_jar")
	assert_eq(chapter.map_id(Chapter.FINAL), "", "the final isn't built yet")
	assert_eq(chapter.state(0), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.complete(0), 1)
	assert_eq(chapter.state(1), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.complete(1), 2, "the Body opens the Legs")
	assert_eq(chapter.complete(2), 3, "the Legs open the Stream")
	assert_eq(chapter.complete(3), 4, "the Stream opens the Jar")
	assert_eq(chapter.complete(4), -1, "the final isn't built yet")


func test_playing_the_hand_from_the_chart_is_not_the_tutorial_and_saves_as_aquarius() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	add_child_autofree(app)
	app.switch_chapter()
	assert_eq(app.chapter.id, "aquarius")
	app.open_stage(0)
	var stage: Main = app.stage()
	assert_eq(stage.star_map, "aquarius_hand")
	assert_false(stage.tutorial, "the guided run is Scorpio's")
	assert_false(stage.encounter, "no Orion encounter")
	assert_not_null(stage.run.current)
	stage.stage_won.emit()
	app.back_to_chart()
	assert_true(app.chapter.is_completed(0))
	assert_eq(ProgressStore.new(STORE).load_chapter("aquarius").get("completed"), [0.0], "JSON keeps numbers as floats")
	assert_eq(ProgressStore.new(STORE).load_chapter("scorpio"), {}, "Scorpio's progress untouched")


func test_a_stage_without_a_painting_yet_completes_without_one() -> void:
	assert_lt(ConstellationView.completion_time(StarMap.aquarius_hand()), ConstellationView.completion_time(StarMap.stinger()) - 2.5, "no empty wait for a painting")
	assert_eq(ConstellationView.completion_time(StarMap.aquarius_hand()), ConstellationView.TUNE_TIME + ConstellationView.VIBRATE_TIME, "the song, then its last string rings out")
	assert_eq(ConstellationView.completion_time(StarMap.stinger()), ConstellationView.completion_time(), "painted stages keep their time")
	assert_false(ConstellationView.has_painting(StarMap.aquarius_hand()))
	assert_false(ConstellationView.has_painting(StarMap.aquarius_body()))
	assert_true(ConstellationView.has_painting(StarMap.stinger()))
	var main: Main = MainScene.instantiate()
	main.star_map = "aquarius_hand"
	main.in_chapter = true
	add_child_autofree(main)
	var view: ConstellationView = main.get_node("Sky/ConstellationLayer")
	for index: int in main.run.scorpio.map.count():
		main.run.scorpio.light(index)
	view.play_completion()
	var t: float = 0.0
	while t < ConstellationView.completion_time() + 0.5:
		view.advance(0.1)
		view.queue_redraw()
		await get_tree().process_frame
		t += 0.1
	assert_true(main.run.scorpio.is_complete(), "the song and the missing painting played through")


func test_the_first_move_of_a_run_says_what_the_current_does() -> void:
	for map_id: String in ["aquarius_hand", "aquarius_body"]:
		var main: Main = MainScene.instantiate()
		main.star_map = map_id
		main.in_chapter = true
		main.seed_override = 7
		add_child_autofree(main)
		var hud: Hud = main.get_node("HUD")
		var sequencer: EventSequencer = main.get_node("EventSequencer")
		main.run.add_star(Star.Size.SMALL, Vector2i(150, 220) + main.run.scorpio.shift)
		assert_true(main.run.launch(Vector2i(160, 230) + main.run.scorpio.shift))
		for tick: int in 100:
			sequencer.advance(0.03)
			if hud.message() != "":
				break
		var expected: String = Hud.DRAIN_MESSAGE if map_id == "aquarius_body" else Hud.FLOW_MESSAGE
		assert_eq(hud.message(), expected, map_id)


func test_the_legs_branch_either_side_of_the_knee_with_the_shin_near_the_drain() -> void:
	var map: StarMap = StarMap.aquarius_legs()
	_check_pickable(map)
	assert_eq(map.count(), 6)
	assert_eq(map.starting_lit, [0] as Array[int], "the hip starts lit: five to light")
	assert_true(map.current_drains)
	assert_eq(map.current_direction, Vector2i.LEFT)
	assert_eq(map.current_region.position.x, 48)
	assert_eq(map.neighbours(1).size(), 3, "the knee joins the hip and both legs")
	assert_false(map.current_region.has_point(map.landmarks[3]), "the foot lies past the drain")
	assert_lt(map.landmarks[2].x - map.current_region.position.x, 24, "the shin is a step from the drain")
	assert_eq(StarMap.by_id("aquarius_legs").title, "LEGS")


func test_the_stream_pours_down_into_a_drain_along_its_bottom() -> void:
	var map: StarMap = StarMap.aquarius_stream()
	_check_pickable(map)
	assert_eq(map.current_direction, Vector2i.DOWN, "a waterfall")
	assert_true(map.current_drains)
	assert_eq(map.current_region.end.y, 200)
	for index: int in 5:
		assert_true(map.current_region.has_point(map.landmarks[index]), "the stream runs through the flow")
	assert_gt(map.landmarks[5].y, map.current_region.end.y, "its last star lies below the drain")
	var run := RunState.new(Balance.load_file(), Fixtures.rng(), SKY, map)
	assert_eq(run.current.displacement, Vector2i(0, 32), "down, at the stream's own step")
	var doomed: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 190))
	var kept: Star = run.add_star(Star.Size.SMALL, Vector2i(150, 120))
	var preview: Dictionary[int, Vector2i] = run.current_preview()
	assert_true(run.current.leaves(doomed.position, preview[doomed.id]), "low stars fall into the drain")
	assert_eq(preview[kept.id], Vector2i(150, 152), "higher ones fall a step")
	assert_eq(StarMap.by_id("aquarius_stream").title, "STREAM")


func test_a_downward_drain_shows_along_the_bottom_and_splashes_back_up() -> void:
	var area := Rect2i(16, 78, 148, 122)
	var view := CurrentView.new()
	var water: Dictionary[Vector2i, Color] = CurrentView.water_pixels(area, Vector2i.DOWN * 32, 1.0)
	for p: Vector2i in water:
		assert_true(area.has_point(p))
	var at := Vector2i(100, area.end.y)
	var mid: Dictionary[Vector2i, Color] = CurrentView.extinction_pixels(at, Vector2i.DOWN * 32, 0.2, area)
	var up: int = 0
	for p: Vector2i in mid:
		if (mid[p] == Palette.M5 or mid[p] == Palette.M4) and p.y < at.y - 4:
			up += 1
	assert_gt(up, 2, "the splash goes back up the waterfall")
	view.free()


func test_the_jar_stands_in_a_tide_that_drains_at_both_sides() -> void:
	var map: StarMap = StarMap.aquarius_jar()
	_check_pickable(map)
	assert_eq(map.current_turns, [Vector2i.LEFT, Vector2i.RIGHT] as Array[Vector2i])
	assert_true(map.current_drains)
	assert_eq(map.neighbours(1).size(), 4, "zeta is the Y's centre")
	for index: int in map.count():
		assert_true(map.current_region.has_point(map.landmarks[index]), "the whole jar stands in the tide")
	assert_eq(StarMap.by_id("aquarius_jar").title, "JAR")


func test_the_tide_turns_after_each_launch_and_the_aim_previews_the_way_it_will_go() -> void:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(3), SKY, StarMap.aquarius_jar())
	assert_eq(run.current.displacement, Vector2i(-56, 0), "out to the left first")
	assert_eq(run.current.next_way(), Vector2i.RIGHT)
	var star: Star = run.add_star(Star.Size.SMALL, Vector2i(110, 120))
	assert_eq(run.current_preview()[star.id], Vector2i(54, 120))
	assert_true(run.launch(Vector2i(140, 230)))
	assert_eq(star.position, Vector2i(54, 120), "the launch went left")
	assert_eq(run.current.displacement, Vector2i(56, 0), "then the tide turned")
	assert_eq(run.current_preview()[star.id], Vector2i(110, 120), "and the aim shows it coming back")
	var leaving: Star = run.add_star(Star.Size.SMALL, Vector2i(130, 210))
	assert_true(run.current.leaves(leaving.position, run.current_preview()[leaving.id]), "the right side drains too")


func test_a_refused_launch_does_not_turn_the_tide() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))
	data.start_packs = {"blue": 0, "red": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), SKY, StarMap.aquarius_jar())
	assert_false(run.launch(Vector2i(90, 150)), "nothing to launch")
	assert_eq(run.current.displacement, Vector2i(-56, 0), "the tide waits for a launch")


func test_both_drains_show_and_the_next_launchs_is_brighter() -> void:
	var main: Main = MainScene.instantiate()
	main.star_map = "aquarius_jar"
	main.in_chapter = true
	add_child_autofree(main)
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var area: Rect2i = main.run.current.region
	var left := Vector2i(area.position.x, area.position.y)
	var right := Vector2i(area.end.x - 1, area.position.y)
	assert_eq(view.pixels().get(left), Palette.S3, "this launch drains left: its line in ember")
	assert_eq(view.pixels().get(right), Palette.S2, "the other side waits, dimmer")
	main.run.current.turn()
	assert_eq(view.pixels().get(right), Palette.S3)
	assert_eq(view.pixels().get(left), Palette.S2)


func test_a_star_lost_to_the_tide_splashes_back_the_way_it_came() -> void:
	var area := Rect2i(24, 78, 132, 172)
	var at := Vector2i(area.end.x, 150)
	var mid: Dictionary[Vector2i, Color] = CurrentView.extinction_pixels(at, Vector2i.RIGHT, 0.2, area)
	var back: int = 0
	for p: Vector2i in mid:
		if (mid[p] == Palette.M5 or mid[p] == Palette.M4) and p.x < at.x - 4:
			back += 1
	assert_gt(back, 2, "lost out to the right, it splashes back left")


func test_the_jars_first_launch_says_the_tide_turns() -> void:
	var main: Main = MainScene.instantiate()
	main.star_map = "aquarius_jar"
	main.in_chapter = true
	main.seed_override = 7
	add_child_autofree(main)
	var hud: Hud = main.get_node("HUD")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	main.run.add_star(Star.Size.SMALL, Vector2i(100, 220) + main.run.scorpio.shift)
	assert_true(main.run.launch(Vector2i(130, 230) + main.run.scorpio.shift))
	for tick: int in 100:
		sequencer.advance(0.03)
		if hud.message() != "":
			break
	assert_eq(hud.message(), Hud.TIDE_MESSAGE)
