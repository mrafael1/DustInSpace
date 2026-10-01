extends GutTest
## The final in the scenes: Orion's entrance and title card, his health breaking as landmarks
## light, his fall before the constellation plays, the painted Scorpio rising, the end screen
## keeping it in view; and on the chart, the final's unlock and the painting once it's won.

const MainScene := preload("res://game/scenes/main.tscn")
const ChartScene := preload("res://game/scenes/chapter_select.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const PALETTE_PATH := "res://assets/palettes/stellar_sun.gpl"

const STEP: float = 1.0 / 60.0

var main: Main
var run: RunState
var hud: Hud
var sequencer: EventSequencer
var orion: OrionView
var constellation: ConstellationView
var collect: CollectParticles


func _start_final() -> void:
	main = MainScene.instantiate()
	main.seed_override = 5
	main.star_map = "final"
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	data["hunt"] = {"radius": 40, "intro_stars": 3}
	# The first run (from balance.json) already played; this one is the one under test.
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	hud = main.get_node("HUD")
	sequencer = main.get_node("EventSequencer")
	orion = main.get_node("Sky/OrionLayer")
	constellation = main.get_node("Sky/ConstellationLayer")
	collect = main.get_node("CollectParticles")
	for node: Node in [sequencer, orion, constellation, hud.boss_banner(), collect, main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)


func _tick(seconds: float) -> void:
	for frame: int in ceili(seconds / STEP):
		sequencer.advance(STEP)
		orion.advance(STEP)
		constellation.advance(STEP)
		hud.boss_banner().advance(STEP)
		collect.advance(STEP)


func test_the_entrance_order_is_his_figure() -> void:
	assert_eq(OrionView.ENTRANCE.size(), 14, "ROAR_AT counts 14 stars")
	var figure: Array[Vector2i] = []
	figure.append_array(OrionView.BODY)
	figure.append(OrionView.HEAD)
	figure.append_array(OrionView.BOW)
	for p: Vector2i in OrionView.ENTRANCE:
		assert_true(figure.has(p))
	assert_eq(OrionView.ENTRANCE.size(), figure.size(), "every star once")


func test_orion_enters_star_by_star_then_roars_and_the_card_names_him() -> void:
	_start_final()
	assert_true(orion.is_boss())
	assert_eq(orion.health(), 11, "a pip per landmark to light")
	sequencer.advance(0.0)
	assert_true(orion.is_entering())
	assert_true(sequencer.is_busy(), "the entrance holds the input")
	assert_eq(orion.stars_shown(), 1, "his feet first")
	assert_true(orion.health_pixels().is_empty(), "no health before the roar")
	watch_signals(orion)
	_tick(OrionView.ROAR_AT + STEP)
	assert_signal_emitted(orion, "roared")
	assert_eq(orion.stars_shown(), 14)
	assert_true(orion.is_flashing())
	assert_true(hud.boss_banner().is_showing(), "ORION / THE HUNTER")
	_tick(OrionView.ENTER_TIME)
	assert_false(orion.is_entering())
	assert_false(hud.boss_banner().is_showing())
	assert_false(sequencer.is_busy())
	assert_eq(orion.health_pixels().size(), 11 * OrionView.HEALTH_PIP * OrionView.HEALTH_PIP, "all eleven pips")
	for colour: Color in orion.figure_pixels().values():
		assert_true(colour in [Palette.S2, Palette.S3, Palette.S4, Palette.N3], "ember at rest")


func test_a_landmark_lit_hurts_him() -> void:
	_start_final()
	_tick(OrionView.ENTER_TIME + 0.1)
	watch_signals(orion)
	run.call("_light_landmark", 3)
	_tick(0.05)
	assert_eq(orion.health(), 10)
	assert_signal_emitted(orion, "hurt_taken")
	assert_true(orion.is_flashing())
	assert_ne(orion.shake(), Vector2i.ZERO, "he flinches")
	assert_true(orion.health_pixels().values().has(Palette.C0), "the pip breaks")
	_tick(OrionView.HURT_TIME)
	assert_false(orion.is_flashing())
	assert_true(orion.health_pixels().values().has(OrionView.HEALTH_EMPTY), "an empty slot")


func test_the_completion_fells_orion_then_paints_the_scorpio() -> void:
	_start_final()
	_tick(OrionView.ENTER_TIME + 0.1)
	var left: Array[int] = []
	for i: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(i):
			left.append(i)
	while left.size() > 1:
		run.call("_light_landmark", left.pop_front())
	_tick(3.0)
	var last: int = left[0]
	var at: Vector2i = run.scorpio.landmark_position(last)
	var size: Star.Size = run.scorpio.map.sizes[last] as Star.Size
	var a: Star = run.add_star(size, at + Vector2i(14, 10))
	var b: Star = run.add_star(size, at + Vector2i(-14, 12))
	watch_signals(orion)
	assert_ne(run.link([a.id, b.id, Scorpio.landmark_id(last)]), Combos.INVALID)
	assert_eq(run.outcome, RunState.Outcome.WON)
	var fell: bool = false
	var painted: bool = false
	for frame: int in 900:
		_tick(STEP)
		if orion.is_falling():
			fell = true
			assert_false(constellation.is_completing(), "the constellation waits for his fall")
		if constellation.figure_stage() >= 0.0 and constellation.figure_stage() <= 1.0:
			painted = true
	assert_true(fell)
	assert_signal_emit_count(orion, "star_fell", 14, "each of his stars bursts")
	assert_signal_emitted(orion, "fallen")
	assert_false(orion.is_figure_shown(), "he is gone")
	assert_true(painted, "the Scorpio rose")
	assert_eq(constellation.figure_stage(), 3.0, "and stays")
	assert_true(constellation.is_revealed())
	var end: EndScreen = main.get_node("EndScreen")
	end.call("_show_end")
	assert_true(end.lines().has("ORION DEFEATED"))


func test_the_end_panel_leaves_the_painting_in_view() -> void:
	_start_final()
	run.outcome = RunState.Outcome.WON
	var end: EndScreen = main.get_node("EndScreen")
	end.call("_show_end")
	var panel: Rect2i = end.get("_panel")
	assert_eq(panel.end.y, ScreenZones.SCREEN.y, "on the bottom edge")
	assert_gt(panel.position.y, ConstellationView.figure_span().y, "below the Scorpio's tail")


func test_the_painting_is_palette_locked_and_crisp() -> void:
	var allowed: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 4 and fields[0].is_valid_int():
			allowed[Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()).to_html(false)] = true
	var image: Image = ConstellationView.FIGURE.get_image()
	assert_eq(image.get_size(), ScreenZones.SCREEN, "the game's screen, in home layout")
	var bad: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a8 != 0 and (c.a8 != 255 or not allowed.has(c.to_html(false))):
				bad += 1
	assert_eq(bad, 0, "opaque palette colours or nothing")
	var span: Vector2i = ConstellationView.figure_span()
	assert_true(Scorpio.HOME_SKY.grow(6).has_point(Vector2i(90, span.x)), "inside the sky")
	assert_true(Scorpio.HOME_SKY.grow(6).has_point(Vector2i(90, span.y)))
	for landmark: Vector2i in Scorpio.LANDMARKS:
		assert_true(image.get_pixelv(landmark).a8 == 255, "every star sits on the body")


func test_the_figure_rises_from_its_tail() -> void:
	var span: Vector2i = ConstellationView.figure_span()
	assert_eq(ConstellationView.figure_front(0.0), span.y + 1, "nothing yet")
	assert_eq(ConstellationView.figure_front(1.0), span.x, "all of it")
	assert_lt(ConstellationView.figure_front(0.5), ConstellationView.figure_front(0.25), "rising")
	assert_gt(ConstellationView.completion_time(StarMap.final()), ConstellationView.completion_time(StarMap.claws()))


func test_the_chart_plays_the_finals_unlock() -> void:
	var chart: ChapterSelect = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set_process(false)
	var chapter := Chapter.new()
	for stage: int in Chapter.FINAL:
		chapter.complete(stage)
	chart.setup(chapter)
	chart.show_progress(4, Chapter.FINAL)
	assert_true(chart.is_lighting(), "the Claws light first")
	assert_true(chart.is_unlocking())
	var flew: bool = false
	var phases: Dictionary = {}
	for frame: int in ceili((ChapterSelect.LIGHT_TIME + ChapterSelect.UNLOCK_TIME) / STEP) + 2:
		chart.advance(STEP)
		flew = flew or chart.is_travelling()
	assert_false(flew, "no comet along the strings: the unlock brings the final in")
	assert_false(chart.is_unlocking())
	assert_eq(chart.selected(), Chapter.FINAL)
	assert_true(chart.can_play())
	for t: float in [0.1, ChapterSelect.UNLOCK_TIME - ChapterSelect.UNLOCK_BURST - 0.1, ChapterSelect.UNLOCK_TIME - 0.1]:
		phases[ChapterSelect.unlock_phase(t)] = true
	assert_eq(phases.keys(), [0, 1, 2], "comets, charge, burst")
	var heads: Array[int] = ChapterSelect.unlock_comet_heads(0.0)
	assert_eq(heads[0], 0, "the Stinger's comet leaves first")
	assert_eq(heads[4], -1, "the Claws' a little later")
	assert_false(chart.shows_figure(), "the painting waits for the final's win")


func test_the_chart_paints_the_scorpio_once_the_final_is_won() -> void:
	var chart: ChapterSelect = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set_process(false)
	var chapter := Chapter.new()
	for stage: int in Chapter.stage_count():
		chapter.complete(stage)
	chart.setup(chapter)
	assert_true(chart.shows_figure())
	chart.show_progress(Chapter.FINAL, -1)
	assert_true(chart.is_figure_rising())
	assert_false(chart.is_unlocking())
	for frame: int in ceili(ConstellationView.FIGURE_RISE / STEP) + 20:
		chart.advance(STEP)
	assert_false(chart.is_figure_rising())
	assert_true(chart.shows_figure())


func test_play_waits_for_the_finals_unlock() -> void:
	var chart: ChapterSelect = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set_process(false)
	var chapter := Chapter.new()
	for stage: int in Chapter.FINAL:
		chapter.complete(stage)
	chart.setup(chapter)
	chart.show_progress(4, Chapter.FINAL)
	watch_signals(chart)
	var play: Vector2i = ChapterSelect.play_rect().get_center()
	# While the Claws light, then while the comets fly and the crown charges.
	for wait: float in [0.1, ChapterSelect.LIGHT_TIME + 0.1, ChapterSelect.LIGHT_TIME + ChapterSelect.UNLOCK_TIME - 0.2]:
		while chart.get("_time") < wait:
			chart.advance(STEP)
		assert_true(chart.is_unlocking())
		assert_false(chart.can_play(), "no PLAY while the unlock plays")
		assert_false((chart.get_node("Play") as Label).visible)
		_tap(chart, play)
	assert_signal_not_emitted(chart, "stage_chosen", "the Claws never reopen mid-unlock")
	for frame: int in 30:
		chart.advance(STEP)
	assert_false(chart.is_unlocking())
	assert_eq(chart.selected(), Chapter.FINAL)
	assert_true((chart.get_node("Play") as Label).visible)
	_tap(chart, play)
	assert_signal_emitted_with_parameters(chart, "stage_chosen", [Chapter.FINAL])


func test_debug_previews_never_reach_the_save() -> void:
	var path: String = "user://test_final_preview_%d.json" % randi()
	var app: App = (load("res://game/scenes/app.tscn") as PackedScene).instantiate()
	app.progress_path = path
	add_child_autofree(app)
	app.debug_win_final()
	assert_true(app.is_previewing())
	assert_false(app.chapter.is_completed(0), "the chapter itself is untouched")
	app.open_stage(Chapter.FINAL)
	assert_null(app.stage(), "a preview never opens the final")
	assert_false(app.is_previewing(), "opening a stage drops the preview")
	app.debug_win_parts()
	app.open_stage(0)
	assert_not_null(app.stage())
	app.stage().stage_won.emit()
	var again := Chapter.new()
	again.from_save(ProgressStore.new(path).load_chapter(Chapter.ID))
	assert_eq(again.completed_count(), 1, "only the stage really won")
	assert_true(again.is_completed(0))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _tap(chart: ChapterSelect, at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		chart.handle_pointer(touch)
