extends GutTest
## The guided first run in the scenes: the guide's line and hand follow the steps as they play, the
## telescope holds its aim while stars are linked, and the App plays it on the Stinger's first run
## only, saving it once finished.

const MainScene := preload("res://game/scenes/main.tscn")
const AppScene := preload("res://game/scenes/app.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const STEP: float = 1.0 / 60.0

var main: Main
var run: RunState
var hud: Hud
var sequencer: EventSequencer
var scope: Telescope
var store_path: String = "user://test_tutorial_%d.json" % randi()


func after_each() -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))


func _start() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	main.star_map = "stinger"
	main.tutorial = true
	add_child_autofree(main)
	run = main.run
	hud = main.get_node("HUD")
	sequencer = main.get_node("EventSequencer")
	scope = main.get_node("Telescope")
	for node: Node in [sequencer, scope, hud, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun"), main.get_node("Sky")]:
		node.set_process(false)


func _settle() -> void:
	for frame: int in 600:
		sequencer.advance(STEP)
		scope.advance(STEP)
		hud.advance(STEP)
		if not sequencer.is_busy():
			break
	scope.advance(STEP)


func test_the_guide_follows_each_step() -> void:
	_start()
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "TAP THE SKY TO LAUNCH")
	assert_true(guide.has_hand())
	assert_true(scope.is_aiming(), "the launch step aims")
	assert_true(run.launch(Vector2i(90, 170)))
	_settle()
	assert_eq(guide.text(), "LINK ONE OF EACH SIZE")
	assert_eq(guide.combos(), [[Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG]], "the card shows one of each size")
	assert_true(run.sky_rect.has_point(guide.card_rect().position), "at the top of the sky")
	assert_eq(guide.fingertip().x, run.stars[0].position.x, "the hand over a star to link")
	assert_false(scope.is_aiming(), "touches reach the stars")
	assert_false(scope.start_aim(), "the telescope waits for the next launch step")
	var ids: Array[int] = []
	for star: Star in run.stars:
		ids.append(star.id)
	run.link(_order(ids))
	_settle()
	assert_eq(guide.text(), "LAUNCH NEXT TO THIS STAR")
	assert_eq(guide.combos(), [], "no card while launching")
	assert_eq(guide.fingertip().x, run.scorpio.landmark_position(run.tutorial.landmark).x, "the hand over the star")
	assert_true(scope.is_aiming(), "aiming again")
	scope.aim_at(Vector2i(170, 100))
	watch_signals(scope)
	scope.call("_fire")
	assert_signal_emitted(scope, "launch_refused", "too far: refused")
	assert_true(scope.is_aiming(), "and still aiming")


func test_the_buy_step_points_at_the_buy_button() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.LIGHT
	run.tutorial.linked(true, -1, true)
	run.tutorial_step.emit(run.tutorial.step)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "BUY A PLANET")
	var button: Vector2i = hud.buy_button_at("blue")
	assert_eq(guide.fingertip().y, button.y)
	assert_lt(guide.fingertip().x, button.x, "from the left, pointing right")


func test_free_play_shows_its_line_then_clears() -> void:
	_start()
	run.tutorial.step = Tutorial.Step.DONE
	run.tutorial_step.emit(Tutorial.Step.DONE)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LIGHT EVERY STAR")
	assert_false(guide.has_hand())
	assert_eq(guide.combos().size(), 2, "both combos, OR between them")
	guide.advance(TutorialView.DONE_TIME + 0.1)
	assert_eq(guide.text(), "")


func test_the_hand_turns_to_point_right() -> void:
	var down: Dictionary[Vector2i, Color] = TutorialView.hand_pixels(Vector2i(50, 50), TutorialView.Point.DOWN)
	var right: Dictionary[Vector2i, Color] = TutorialView.hand_pixels(Vector2i(50, 50), TutorialView.Point.RIGHT)
	assert_true(down.has(Vector2i(50, 50)) and right.has(Vector2i(50, 50)), "the fingertip is the point")
	for p: Vector2i in down:
		assert_lte(p.y, 50, "pointing down: all above the tip")
	for p: Vector2i in right:
		assert_lte(p.x, 50, "pointing right: all left of the tip")


func test_the_app_plays_it_on_the_stingers_first_run_and_saves_it() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = store_path
	add_child_autofree(app)
	assert_false(app.tutorial_done)
	app.open_stage(0)
	assert_not_null(app.stage().run.tutorial, "the first Stinger run is guided")
	app.stage().run.tutorial.step = Tutorial.Step.BUY
	app.stage().run.tutorial.bought()
	app.stage().run.tutorial_step.emit(Tutorial.Step.DONE)
	assert_true(app.tutorial_done)
	app.back_to_chart()
	var again: App = AppScene.instantiate()
	again.progress_path = store_path
	add_child_autofree(again)
	assert_true(again.tutorial_done, "saved")
	again.open_stage(0)
	assert_null(again.stage().run.tutorial, "not guided again")


func test_a_restart_before_the_end_guides_again() -> void:
	_start()
	main.restart()
	assert_not_null(main.run.tutorial)


func _order(ids: Array[int]) -> Array[int]:
	for p: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var order: Array[int] = [ids[p[0]], ids[p[1]], ids[p[2]]]
		if run.link_in_reach(order):
			return order
	return ids


func test_lighting_the_star_teaches_three_of_its_size() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.LIGHT
	run.tutorial.landmark = 1
	run.tutorial_step.emit(Tutorial.Step.LIGHT)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LINK 3 OF THE SAME SIZE")
	var size: int = run.scorpio.map.sizes[1]
	assert_eq(guide.combos(), [[size, size, size]], "three stars of the constellation star's size")


func test_the_card_fits_the_screen() -> void:
	for step: int in [Tutorial.Step.LINK, Tutorial.Step.LIGHT, Tutorial.Step.DONE]:
		var width: int = 2 * TutorialView.CARD_PAD
		for combo: Array in TutorialView.card_combos(step, Star.Size.BIG):
			width += TutorialView.row_width(combo) + 30
		assert_lt(width, ScreenZones.SCREEN.x, "step %d" % step)


func test_the_chart_offers_the_tutorial_again_once_finished() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = store_path
	add_child_autofree(app)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	assert_false(chart.is_tutorial_button_shown(), "the first Stinger run is guided anyway")
	app.open_stage(0)
	app.stage().run.tutorial_step.emit(Tutorial.Step.DONE)
	app.back_to_chart()
	assert_true(chart.is_tutorial_button_shown(), "finished once: it can be played again")
	assert_lte(chart.tutorial_target().end.x - 4, chart.get("_screen").end.x, "in the top-right corner")
	watch_signals(chart)
	_tap_chart(chart, chart.tutorial_target().get_center())
	assert_signal_emitted(chart, "tutorial_requested")
	assert_not_null(app.stage(), "the Stinger opens")
	assert_eq(app.stage().star_map, "stinger")
	assert_not_null(app.stage().run.tutorial, "guided again")
	app.stage().stage_won.emit()
	assert_true(app.chapter.is_completed(0), "a guided win counts as usual")


func test_a_saved_tutorial_shows_the_button_and_a_plain_stinger_isnt_guided() -> void:
	ProgressStore.new(store_path).save_chapter(App.TUTORIAL_ID, {"done": true})
	var app: App = AppScene.instantiate()
	app.progress_path = store_path
	add_child_autofree(app)
	assert_true((app.get_node("ChapterSelect") as ChapterSelect).is_tutorial_button_shown())
	app.open_stage(0)
	assert_null(app.stage().run.tutorial, "PLAY isn't guided")
	app.back_to_chart()
	app.replay_tutorial()
	assert_not_null(app.stage().run.tutorial, "TUTORIAL is")


func test_the_button_waits_for_the_finals_unlock() -> void:
	var chart: ChapterSelect = (load("res://game/scenes/chapter_select.tscn") as PackedScene).instantiate()
	add_child_autofree(chart)
	chart.set_process(false)
	var chapter := Chapter.new()
	for stage: int in Chapter.FINAL:
		chapter.complete(stage)
	chart.setup(chapter)
	chart.show_tutorial_button(true)
	chart.show_progress(4, Chapter.FINAL)
	watch_signals(chart)
	_tap_chart(chart, chart.tutorial_target().get_center())
	assert_signal_not_emitted(chart, "tutorial_requested")


func _tap_chart(chart: ChapterSelect, at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		chart.handle_pointer(touch)
