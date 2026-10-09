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
	assert_eq(guide.text(), "LIGHT EVERY STAR OF THE
CONSTELLATION TO WIN", "the goal first")
	assert_true(guide.shows_tap_hint())
	assert_true(guide.waits_for_tap())
	var landmark: int = run.rekindle_target()
	assert_eq(guide.target().x, run.scorpio.landmark_position(landmark).x, "the hand on the next constellation star")
	var pause: Vector2i = hud.pause_target().get_center()
	var press := InputEventScreenTouch.new()
	press.position = Vector2(pause)
	press.pressed = true
	hud.handle_pointer(press)
	assert_true(guide.waits_for_tap(), "the pause button isn't a tap on")
	press.pressed = false
	hud.handle_pointer(press)
	assert_true(hud.pause_menu().is_open())
	hud.close_pause()
	_tap_hud(Vector2i(90, 150))
	_settle()
	assert_eq(guide.text(), "TAP THE SKY TO LAUNCH\nA CHEAP BLUE PLANET")
	assert_false(guide.shows_tap_hint())
	assert_true(guide.has_hand())
	# Where the finger under the hand aims: open sky, clear of the figure.
	var aim: Vector2i = guide.target() - Vector2i(0, scope.finger_lift())
	for at: Vector2i in run.scorpio.landmark_positions():
		assert_gte(Vector2(aim).distance_to(Vector2(at)), float(RunState.OPEN_CLEARANCE), "the hand at open sky, clear of the figure")
	assert_true(scope.is_aiming(), "the launch step aims")
	assert_true(Fixtures.launch(run, Vector2i(90, 170)))
	_settle()
	assert_true(hud.table().is_open(), "the table teaches the links first")
	_tap_hud(Vector2i(90, 150))
	assert_false(hud.table().is_open(), "a tap closes it")
	assert_eq(guide.text(), "LINK THE 3 NEW STARS\nTAP OR DRAG THROUGH THEM")
	assert_false(scope.is_aiming(), "touches reach the stars")
	assert_false(scope.start_aim(), "the telescope waits for the next launch step")
	var path: Array[int] = guide.get("_path")
	assert_eq(path.size(), 3, "a path through the pack's three stars")
	assert_true(run.link_in_reach(path), "in an order that stays in reach")
	assert_eq(guide.target().x, run.find_star(path[0]).position.x, "the hand on the first")
	hud.follow_link([path[0]])
	assert_eq(guide.text(), "FOLLOW THE SHINING STARS", "once one is picked: the shine")
	assert_eq(guide.target().x, run.find_star(path[1]).position.x, "the hand moves on to the second")
	hud.follow_link([path[0], path[1]])
	assert_eq(guide.target().x, run.find_star(path[2]).position.x, "then the third")
	hud.follow_link([])
	assert_eq(guide.text(), "LINK THE 3 NEW STARS\nTAP OR DRAG THROUGH THEM", "a dropped link starts over")
	assert_eq(guide.target().x, run.find_star(path[0]).position.x)
	run.link(path)
	_settle()
	# The payout, as it lands: the hand on the dust counter, then on the Sun, each going on by itself.
	assert_eq(guide.text(), "DUST BUYS PLANETS")
	assert_false(guide.shows_tap_hint(), "it goes on by itself")
	assert_eq(guide.fingertip().x, hud.dust_icon_top().x, "the hand over the dust counter")
	assert_lt(guide.fingertip().y, hud.dust_icon_top().y)
	guide.advance(TutorialView.SHOW_TIME - 0.1)
	_settle()
	assert_eq(guide.text(), "DUST BUYS PLANETS", "not yet")
	guide.advance(0.2)
	_settle()
	assert_eq(guide.text(), "LIGHT FILLS THE SUN")
	assert_lt(guide.fingertip().x, hud.sun_at.x, "the hand at the Sun, from the left")
	_tap_hud(Vector2i(90, 150))
	_settle()
	assert_eq(guide.text(), "LAUNCH NEXT TO THIS STAR")
	assert_eq(guide.fingertip().x, run.scorpio.landmark_position(run.tutorial.landmark).x, "the hand over the star")
	assert_true(scope.is_aiming(), "aiming again")
	scope.aim_at(Vector2i(170, 100))
	watch_signals(scope)
	scope.call("_fire")
	assert_signal_emitted(scope, "launch_refused", "too far: refused")
	assert_true(scope.is_aiming(), "and still aiming")


func test_with_a_finger_the_launch_hands_point_where_the_finger_goes() -> void:
	_start()
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	_tap_hud(Vector2i(90, 150))
	_settle()
	var lift: int = Telescope.TOUCH_LIFT
	# A finger playing the first launch: the hand is under the spot by the lift.
	_finger_tap(guide.target())
	assert_eq(run.stars.size(), 3, "the finger at the hand launched")
	_settle()
	_tap_hud(Vector2i(90, 150))
	var path: Array[int] = guide.get("_path")
	run.link(path)
	_settle()
	guide.advance(TutorialView.SHOW_TIME + 0.1)
	_settle()
	_tap_hud(Vector2i(90, 150))
	_settle()
	assert_eq(guide.text(), "LAUNCH NEXT TO THIS STAR")
	var at: Vector2i = run.scorpio.landmark_position(run.tutorial.landmark)
	var size: int = run.scorpio.map.sizes[run.tutorial.landmark]
	assert_eq(guide.target(), at - Vector2i(0, StarView.half_extent(size as Star.Size) - lift), "the hand points where the finger goes")
	var packs: int = run.total_packs()
	_finger_tap(guide.target())
	assert_eq(run.total_packs(), packs - 1, "the finger at the hand launches next to the star")
	assert_eq(run.tutorial.step, Tutorial.Step.LIGHT)


func _finger_tap(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at - scope.origin())
		touch.pressed = pressed
		assert_true(scope.handle_pointer(touch), "the aiming telescope takes the finger")


func test_the_buy_step_points_at_the_buy_button() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.BUY
	run.tutorial_step.emit(run.tutorial.step)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "SPEND DUST ON A PLANET")
	var button: Vector2i = hud.buy_button_at("blue")
	assert_eq(guide.fingertip().y, button.y)
	assert_lt(guide.fingertip().x, button.x, "from the left, pointing right")


func test_the_red_step_aims_at_the_sky_with_the_red_planet_loaded() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.RED
	run.tutorial_step.emit(Tutorial.Step.RED)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LAUNCH THE RED PLANET\nIT SPLITS IN TWO\nWITH MORE BIG STARS")
	assert_true(run.sky_rect.has_point(guide.target()), "the hand on the sky")
	assert_false(guide.waits_for_tap())
	assert_true(scope.is_aiming(), "a launch step aims")


func test_the_first_link_acts_a_drag_out_until_a_star_is_picked() -> void:
	_start()
	_settle()
	_tap_hud(Vector2i(90, 150))
	_settle()
	assert_true(Fixtures.launch(run, Vector2i(90, 170)))
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(run.tutorial.step, Tutorial.Step.LINK)
	assert_true(guide.is_demoing_drag())
	var path: Array[int] = guide.get("_path")
	var first: Vector2i = _centre(path[0])
	var second: Vector2i = _centre(path[1])
	guide.set("_time", 0.0)
	assert_eq(guide.fingertip(), first, "resting on the first star")
	guide.set("_time", TutorialView.DRAG_REST + TutorialView.DRAG_STEP * 0.5)
	var halfway: Vector2i = guide.fingertip()
	assert_almost_eq(Vector2(halfway).distance_to((Vector2(first) + Vector2(second)) / 2.0), 0.0, 1.0, "sliding to the second")
	guide.set("_time", TutorialView.DRAG_REST + TutorialView.DRAG_STEP * 2.0 + 0.1)
	assert_eq(guide.fingertip(), _centre(path[2]), "resting on the last")
	hud.follow_link([path[0]])
	assert_false(guide.is_demoing_drag(), "once a star is picked, it points at the next")
	assert_eq(guide.text(), "FOLLOW THE SHINING STARS")


func test_the_demo_point_loops_through_the_path() -> void:
	var points: Array[Vector2i] = [Vector2i(10, 10), Vector2i(40, 10), Vector2i(40, 50)]
	var loop: float = TutorialView.DRAG_REST * 2.0 + TutorialView.DRAG_STEP * 2.0
	assert_eq(TutorialView.demo_point(points, 0.0), points[0])
	assert_eq(TutorialView.demo_point(points, TutorialView.DRAG_REST + TutorialView.DRAG_STEP), points[1])
	assert_eq(TutorialView.demo_point(points, loop - 0.01), points[2])
	assert_eq(TutorialView.demo_point(points, loop + 0.01), points[0], "then again")


func test_the_loaded_planet_is_shown_on_the_telescope_then_its_icon() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.SCOPE
	run.loaded_pack = "red"
	run.pack_loaded.emit("red")
	run.tutorial_step.emit(Tutorial.Step.SCOPE)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "THE TELESCOPE SHOWS\nTHE LOADED PLANET")
	assert_false(guide.shows_tap_hint(), "it goes on by itself")
	var window: Vector2i = scope.origin() + scope.window()
	assert_eq(guide.fingertip().y, window.y, "the hand at the telescope's window")
	assert_lt(guide.fingertip().x, window.x, "from the left")
	assert_eq(scope.loaded_pack(), "red", "the window shows the red planet")
	guide.advance(TutorialView.SHOW_TIME + 0.1)
	_settle()
	assert_eq(guide.text(), "THE LOADED PLANET SPINS")
	assert_eq(guide.fingertip().x, hud.pack_icon_top("red").x, "the hand over the red planet's icon")
	guide.advance(TutorialView.SHOW_TIME + 0.1)
	_settle()
	assert_eq(guide.text(), "LAUNCH THE RED PLANET\nIT SPLITS IN TWO\nWITH MORE BIG STARS")


func test_the_full_sun_points_at_the_star_it_lit() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.SUN_FULL
	run.tutorial.landmark = 2
	run.tutorial_step.emit(Tutorial.Step.SUN_FULL)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "A FULL SUN LIGHTS A STAR")
	assert_eq(guide.target().x, run.scorpio.landmark_position(2).x, "the hand on the star it lit")
	assert_true(guide.waits_for_tap(), "a showing step")
	assert_false(guide.shows_tap_hint())


func test_the_red_link_points_through_three_big_stars() -> void:
	_start()
	_settle()
	for at: Vector2i in [Vector2i(60, 120), Vector2i(90, 125), Vector2i(120, 120)]:
		run.add_star(Star.Size.BIG, at)
	run.tutorial.step = Tutorial.Step.RED_LINK
	run.tutorial_step.emit(Tutorial.Step.RED_LINK)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LINK THEM TO FILL THE SUN")
	var path: Array[int] = guide.get("_path")
	assert_eq(path.size(), 3)
	for id: int in path:
		assert_eq(run.find_star(id).size, Star.Size.BIG)
	assert_true(guide.has_hand())


func test_a_made_link_drops_the_hand_and_a_full_sun_takes_it_to_the_star_it_lights() -> void:
	_start()
	_settle()
	var bigs: Array[Star] = []
	for at: Vector2i in [Vector2i(60, 120), Vector2i(90, 125), Vector2i(120, 120)]:
		bigs.append(run.add_star(Star.Size.BIG, at))
	run.tutorial.step = Tutorial.Step.RED_LINK
	run.tutorial_step.emit(Tutorial.Step.RED_LINK)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_true(guide.has_hand(), "the hand on the guided link")
	# Playtest: another link than the guided one; its stars were linked, the guided ones stay.
	run.combo_collected.emit("small_triple", [] as Array[Star], 3, 5)
	_settle()
	assert_false(guide.has_hand(), "the link is made: no hand on stars it no longer teaches")
	run.sun_rekindled.emit(2)
	_settle()
	assert_eq(guide.text(), "A FULL SUN LIGHTS A STAR", "as the Sun ignites")
	assert_true(guide.has_hand())
	assert_eq(guide.target().x, run.scorpio.landmark_position(2).x, "on the star it lights")


func test_the_sun_fills_towards_the_target_its_fill_began_with() -> void:
	_start()
	_settle()
	var sun: SunView = main.get_node("Sun")
	assert_eq(run.light_target(), 40, "the guided run's first fill")
	sun.receive_light(30)
	assert_almost_eq(sun.progress(), 0.75, 0.001, "the Sun was bound before the tutorial began: it fills to 40 too")
	# The core fills the Sun with the next link and moves on to the stage's own target at once,
	# while that link's light is still flying: the Sun keeps filling towards 40.
	run.set("_tutorial_rekindled", true)
	assert_eq(run.light_target(), 75)
	assert_almost_eq(sun.progress(), 0.75, 0.001, "not 30/75")
	sun.receive_light(10)
	assert_eq(sun.progress(), 1.0, "full")
	sun.call("_rekindle_done")
	sun.receive_light(15)
	assert_almost_eq(sun.progress(), 0.2, 0.001, "the next fill counts to 75")


func test_every_line_fits_the_screen() -> void:
	_start()
	var label: Label = hud.tutorial_guide().get("_label")
	for step: int in TutorialView.TEXTS:
		label.text = TutorialView.TEXTS[step]
		assert_lte(label.get_minimum_size().x, float(ScreenZones.SCREEN.x - 4), "step %d" % step)


func test_free_play_shows_its_line_then_clears() -> void:
	_start()
	run.tutorial.step = Tutorial.Step.DONE
	run.tutorial_step.emit(Tutorial.Step.DONE)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LIGHT EVERY STAR TO WIN\nCOMBOS SHOWS EVERY LINK")
	assert_true(guide.has_hand())
	assert_eq(guide.fingertip().y, hud.table_button_at().y, "the hand on the COMBOS button")
	assert_lt(guide.fingertip().x, hud.table_button_at().x, "from the left")
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
	app.opens_on_title = false
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
	again.opens_on_title = false
	again.progress_path = store_path
	add_child_autofree(again)
	assert_true(again.tutorial_done, "saved")
	again.open_stage(0)
	assert_null(again.stage().run.tutorial, "not guided again")


func test_a_restart_before_the_end_guides_again() -> void:
	_start()
	main.restart()
	assert_not_null(main.run.tutorial)


## The light step, with two stars of the constellation star's size beside it.
func _light_step() -> void:
	run.tutorial.step = Tutorial.Step.LIGHT
	run.tutorial.landmark = 1
	run.add_star(run.scorpio.map.sizes[1] as Star.Size, run.scorpio.landmark_position(1) + Vector2i(16, -10))
	run.add_star(run.scorpio.map.sizes[1] as Star.Size, run.scorpio.landmark_position(1) + Vector2i(-16, -12))
	run.tutorial_step.emit(Tutorial.Step.LIGHT)
	_settle()


func _centre(id: int) -> Vector2i:
	if run.scorpio.is_landmark(id):
		return run.scorpio.landmark_position(Scorpio.landmark_index(id))
	return run.find_star(id).position


func _order(ids: Array[int]) -> Array[int]:
	for p: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var order: Array[int] = [ids[p[0]], ids[p[1]], ids[p[2]]]
		if run.link_in_reach(order):
			return order
	return ids


func test_the_constellation_stars_link_points_star_by_star() -> void:
	_start()
	_settle()
	_light_step()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LINK THIS STAR WITH\n2 OF ITS SIZE TO LIGHT IT")
	assert_true(guide.has_hand())
	assert_false(guide.is_demoing_drag(), "the drag was acted out on the first link")


func test_a_showing_step_lets_a_planets_button_through() -> void:
	_start()
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_true(guide.waits_for_tap(), "the goal")
	run.dust = run.balance.packs["blue"].cost
	var blue: int = run.owned_packs["blue"]
	_tap_button(hud.buy_button_at("blue") + Vector2i(2, 0))
	assert_eq(run.owned_packs["blue"], blue + 1, "the buy went through")
	assert_eq(run.tutorial.step, Tutorial.Step.LAUNCH, "and the tap went on")


func test_a_refused_load_doesnt_buy_another() -> void:
	_start()
	_settle()
	_tap_hud(Vector2i(90, 150))
	_settle()
	assert_eq(run.loaded_pack, "blue")
	run.dust = run.balance.packs["red"].cost
	_tap_button(hud.pack_icon_top("red") + Vector2i(0, PackSlot.ICON_RADIUS))
	assert_eq(run.owned_packs["red"], 1, "the red icon doesn't buy a second one")
	assert_eq(run.dust, run.balance.packs["red"].cost)
	assert_eq(run.loaded_pack, "blue", "switching waits for free play")


func test_lighting_the_star_teaches_three_of_its_size() -> void:
	_start()
	_settle()
	run.tutorial.step = Tutorial.Step.LIGHT
	run.tutorial.landmark = 1
	run.add_star(run.scorpio.map.sizes[1] as Star.Size, run.scorpio.landmark_position(1) + Vector2i(16, -10))
	run.add_star(run.scorpio.map.sizes[1] as Star.Size, run.scorpio.landmark_position(1) + Vector2i(-16, -12))
	run.tutorial_step.emit(Tutorial.Step.LIGHT)
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), "LINK THIS STAR WITH\n2 OF ITS SIZE TO LIGHT IT")
	var path: Array[int] = guide.get("_path")
	assert_eq(path.size(), 3)
	assert_eq(path[0], Scorpio.landmark_id(1), "the hand starts on the constellation star")
	assert_true(run.link_in_reach(path))


func test_the_options_offer_the_tutorial_again_once_finished() -> void:
	var app: App = AppScene.instantiate()
	app.opens_on_title = false
	app.progress_path = store_path
	add_child_autofree(app)
	var options: OptionsMenu = app.options()
	assert_false(options.panel().ids().has(&"tutorial"), "the first Stinger run is guided anyway")
	app.open_stage(0)
	app.stage().run.tutorial_step.emit(Tutorial.Step.DONE)
	app.back_to_chart()
	assert_true(options.panel().ids().has(&"tutorial"), "finished once: it can be played again")
	watch_signals(options)
	_tap_chart(options, options.gear_target().get_center())
	_tap_chart(options, options.panel().item_rect(&"tutorial").get_center())
	assert_signal_emitted(options, "tutorial_requested")
	assert_false(options.is_open(), "the menu closes")
	assert_not_null(app.stage(), "the Stinger opens")
	assert_eq(app.stage().star_map, "stinger")
	assert_not_null(app.stage().run.tutorial, "guided again")
	app.stage().stage_won.emit()
	assert_true(app.chapter.is_completed(0), "a guided win counts as usual")


func test_a_saved_tutorial_shows_the_button_and_a_plain_stinger_isnt_guided() -> void:
	ProgressStore.new(store_path).save_chapter(App.TUTORIAL_ID, {"done": true})
	var app: App = AppScene.instantiate()
	app.opens_on_title = false
	app.progress_path = store_path
	add_child_autofree(app)
	assert_true(app.options().panel().ids().has(&"tutorial"))
	app.open_stage(0)
	assert_null(app.stage().run.tutorial, "PLAY isn't guided")
	app.back_to_chart()
	app.replay_tutorial()
	assert_not_null(app.stage().run.tutorial, "TUTORIAL is")


func test_the_tutorial_waits_for_the_finals_unlock() -> void:
	ProgressStore.new(store_path).save_chapter(App.TUTORIAL_ID, {"done": true})
	var app: App = AppScene.instantiate()
	app.opens_on_title = false
	app.progress_path = store_path
	add_child_autofree(app)
	var chart: ChapterSelect = app.get_node("ChapterSelect")
	chart.set_process(false)
	for stage: int in Chapter.FINAL:
		app.chapter.complete(stage)
	chart.show_progress(4, Chapter.FINAL)
	app.replay_tutorial()
	assert_null(app.stage(), "not while the final unlocks")


func test_the_tutorial_from_another_chapter_plays_scorpios_stinger() -> void:
	ProgressStore.new(store_path).save_chapter(App.TUTORIAL_ID, {"done": true})
	var app: App = AppScene.instantiate()
	app.opens_on_title = false
	app.progress_path = store_path
	add_child_autofree(app)
	app.chapter = app.chapters[2]
	app.replay_tutorial()
	assert_eq(app.chapter, app.chapters[0], "back on Scorpio")
	assert_eq(app.stage().star_map, "stinger")
	assert_not_null(app.stage().run.tutorial, "guided")


func _tap_chart(chart: Object, at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		chart.handle_pointer(touch)


func _tap_button(at: Vector2i) -> void:
	assert_false(hud.target_at(at).is_empty(), "a button at %s" % at)
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		hud.handle_pointer(touch)


func _tap_hud(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		assert_true(hud.handle_pointer(touch), "the explaining step takes the tap")


func test_the_text_sits_under_the_sun() -> void:
	_start()
	_settle()
	var guide: TutorialView = hud.tutorial_guide()
	var label: Label = guide.get("_label")
	var tap: Label = guide.get("_tap")
	var top: int = run.sky_rect.position.y + TutorialView.TOP
	assert_eq(int(label.position.y), top, "at the top of the sky, under the Sun")
	assert_gt(top, hud.sun_at.y + SunView.RADIUS, "below the Sun's disc")
	assert_eq(int(tap.position.y), top + 2 * TutorialView.LINE_STEP, "TAP TO CONTINUE under the goal's two lines")
