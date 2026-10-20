extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const MainScene := preload("res://game/scenes/main.tscn")


class ViewStub:
	extends Node
	var run: RunState
	var sequencer: EventSequencer

	func setup(p_run: RunState, p_sequencer: EventSequencer) -> void:
		run = p_run
		sequencer = p_sequencer


var main: Main


func before_each() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)


func after_each() -> void:
	# A test that ends while the game holds for its sky must not leave the tree paused.
	get_tree().paused = false


func test_starts_a_run_from_balance_json() -> void:
	assert_not_null(main.run)
	assert_eq(main.run.sky_rect, Rect2i(0, 78, 180, 172), "the sky zone from art-direction.md")
	assert_true(main.run.balance.is_valid())


func test_sky_zone_matches_the_test_fixture() -> void:
	assert_eq(ScreenZones.SKY, Fixtures.SKY)


func test_seed_override_makes_runs_repeatable() -> void:
	main.start_run(Fixtures.balance())
	var first: Array[int] = _burst_sizes()
	main.start_run(Fixtures.balance())
	assert_eq(_burst_sizes(), first)


func test_every_view_gets_the_run_and_sequencer() -> void:
	var view := ViewStub.new()
	main.add_child(view)
	main.move_child(view, 0)
	main.start_run(Fixtures.balance())
	assert_eq(view.run, main.run)
	assert_eq(view.sequencer, main.get_node("EventSequencer"))


func test_sequencer_sees_input_before_every_view() -> void:
	assert_eq(main.get_child(main.get_child_count() - 3), main.get_node("EventSequencer"))
	assert_eq(main.get_child(main.get_child_count() - 2), main.get_node("SoundToggle"),
		"only the speaker's own taps come first")
	assert_eq(main.get_child(main.get_child_count() - 1), main.get_node("IdleHint"),
		"and the idle hint, which watches every touch and takes none")


func test_invalid_balance_file_shows_errors_and_starts_no_run() -> void:
	var broken: Main = MainScene.instantiate()
	broken.balance_path = "res://tests/missing_balance.json"
	add_child_autofree(broken)
	assert_null(broken.run)
	var label: Label = broken.get_node("DebugLayer/BalanceErrors")
	assert_true(label.visible, "debug builds show the errors")
	assert_string_contains(label.text, "not found")
	assert_push_error("balance.json")
	await wait_process_frames(2, "views draw and process with no run")
	assert_push_error_count(1, "the balance error and nothing else")
	assert_engine_error_count(0, "no view reads a run it never got")


func test_invalid_restart_keeps_the_current_run_and_views_in_step() -> void:
	var view := ViewStub.new()
	main.add_child(view)
	main.move_child(view, 0)
	main.start_run(Fixtures.balance({"start_dust": 20}))
	var current: RunState = main.run
	var started: bool = main.start_run(_invalid_balance())
	assert_false(started)
	assert_push_error("balance.json")
	assert_eq(main.run, current, "the run in play survives a rejected restart")
	assert_eq(view.run, current, "views still hold the run Main holds")
	assert_true((main.get_node("DebugLayer/BalanceErrors") as Label).visible)
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	current.buy("red")
	assert_true(sequencer.is_busy(), "the kept run's events are still presented")


func test_a_valid_restart_hides_old_errors() -> void:
	main.start_run(_invalid_balance())
	assert_push_error("balance.json")
	assert_true(main.start_run(Fixtures.balance()))
	assert_false((main.get_node("DebugLayer/BalanceErrors") as Label).visible)


func test_landing_particles_tick_the_hud_and_the_sun() -> void:
	var fx: CollectParticles = main.get_node("CollectParticles")
	var sun: SunView = main.get_node("Sun")
	var hud: Hud = main.get_node("HUD")
	fx.dust_arrived.emit(2)
	fx.light_arrived.emit(10)
	assert_eq((hud.get_node("Dust") as Label).text, "%d" % (main.run.dust + 2))
	assert_eq(sun.progress(), 10.0 / main.run.light_target(), "the Sun fills toward the run's target")


func test_the_sky_shows_the_run_in_play() -> void:
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	Fixtures.launch(main.run, Vector2i(90, 160))
	_play_until_idle(sequencer)
	assert_eq(sky.star_count(), main.run.stars.size())
	main.start_run(Fixtures.balance())
	assert_eq(sky.star_count(), 0, "a restart empties the sky")


func test_debug_launch_waits_for_the_sequence_and_stays_in_the_sky() -> void:
	var keys: DebugKeys = main.get_node("DebugKeys")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	assert_true(keys.launch_at_random())
	assert_false(keys.launch_at_random(), "no launch while the burst still plays")
	_play_until_idle(sequencer)
	assert_true(keys.launch_at_random(), "input is back once the stars settle")
	for star: Star in main.run.stars:
		assert_true(StarScatter.inner_rect(ScreenZones.SKY).has_point(star.position))


func test_same_seed_and_same_debug_launches_replay_the_same_sky() -> void:
	var keys: DebugKeys = main.get_node("DebugKeys")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var skies: Array[Array] = []
	for attempt: int in 2:
		main.start_run(Fixtures.balance())
		var sky: Array[Vector2i] = []
		for launch: int in 3:
			assert_true(keys.launch_at_random())
			_play_until_idle(sequencer)
		for star: Star in main.run.stars:
			sky.append(star.position)
		skies.append(sky)
	assert_eq(skies[0], skies[1])


func test_a_restart_mid_launch_leaves_no_pack_in_the_air() -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var flying: PackView = main.get_node("Launcher/FlyingPack")
	Fixtures.launch(main.run, Vector2i(90, 160))
	sequencer.advance(0.0)
	assert_true(flying.visible)
	assert_true(main.start_run(Fixtures.balance()))
	sequencer.advance(5.0)
	(main.get_node("Launcher") as Launcher).advance(5.0)
	assert_false(flying.visible, "the old run's pack is gone")
	assert_eq((main.get_node("Launcher") as Launcher).shown_pack(), "blue", "only the new run's pack shows")


func test_the_telescope_launches_by_default_and_t_switches_to_the_slingshot() -> void:
	var telescope: Telescope = main.get_node("Telescope")
	var slingshot: Launcher = main.get_node("Launcher")
	assert_true(main.use_telescope)
	assert_eq(main.launcher(), telescope)
	assert_true(telescope.visible and telescope.can_process())
	assert_false(slingshot.visible or slingshot.can_process(), "the slingshot takes no input")
	(main.get_node("DebugKeys") as DebugKeys).launcher_switch_requested.emit()
	assert_eq(main.launcher(), slingshot)
	assert_true(slingshot.visible and slingshot.can_process())
	assert_false(telescope.visible or telescope.can_process())


func test_a_run_starts_with_the_telescope_loaded_and_aiming() -> void:
	var telescope: Telescope = main.get_node("Telescope")
	assert_ne(telescope.seated_pack(), "")
	assert_true(telescope.is_aiming())
	assert_eq((main.get_node("HUD") as Hud).message(), "", "no hint text: the reticle says it")
	assert_true(ScreenZones.HUD.grow(10).has_point(telescope.origin()), "in the HUD's row")


func test_the_telescope_message_shows_on_the_hud() -> void:
	var hud: Hud = main.get_node("HUD")
	(main.get_node("Telescope") as Telescope).message_shown.emit(Telescope.EMPTY_MESSAGE)
	assert_eq(hud.message(), Telescope.EMPTY_MESSAGE)
	hud.advance(Hud.MESSAGE_TIME + 0.01)
	assert_eq(hud.message(), "", "it fades after a moment")


func test_a_planet_picked_in_the_hud_aims_the_telescope() -> void:
	var telescope: Telescope = main.get_node("Telescope")
	(main.get_node("HUD") as Hud).planet_chosen.emit("blue")
	_play_until_idle(main.get_node("EventSequencer"))
	telescope.advance(0.0)
	assert_ne(telescope.loaded_pack(), "", "a run starts with a planet loaded")
	assert_true(telescope.is_aiming())


func test_both_launchers_follow_a_launch() -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	Fixtures.launch(main.run, Vector2i(90, 150))
	_play_until_idle(sequencer)
	var kind: String = main.run.loaded_pack
	assert_eq((main.get_node("Telescope") as Telescope).loaded_pack(), kind)
	assert_eq((main.get_node("Launcher") as Launcher).shown_pack(), kind, "the hidden slingshot keeps up")


## Commit 17, the switch (docs/wide_sky_design.md §7): a landscape screen's next run takes the wide
## play sky, and everything that reads the sky from the run gets it.
func test_a_landscape_screen_gives_the_next_run_the_wide_sky() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_eq(main.run.sky_rect, ScreenZones.SKY, "the run in play keeps its sky")
	var view := ViewStub.new()
	main.add_child(view)
	main.move_child(view, 0)
	assert_true(main.restart())
	assert_eq(main.run.sky_rect, Fixtures.WIDE_SKY, "640x360: 230 columns each side, 40 rows above")
	assert_eq(main.run.frame_rect, Rect2i(0, 38, 180, 212), "the frame: the figure's 180 columns")
	assert_eq(view.run, main.run, "every view gets the wide run")
	assert_eq((main.get_node("Backdrop") as Backdrop).get("_sky"), Fixtures.WIDE_SKY, "the Backdrop frames it")
	var slingshot: Launcher = main.get_node("Launcher")
	assert_eq(slingshot.aim_gain(), Launcher.gain_for(slingshot.origin(), Fixtures.WIDE_SKY), "the slingshot reaches its corners")
	assert_eq((main.get_node("Sun") as Node2D).position, Vector2(ScreenZones.sun_centre(40)), "the Sun rises by the rows only")
	var keys: DebugKeys = main.get_node("DebugKeys")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	_play_until_idle(sequencer)
	var outside: int = 0
	for launch: int in 3:
		assert_true(keys.launch_at_random())
		_play_until_idle(sequencer)
	for star: Star in main.run.stars:
		assert_true(StarScatter.inner_rect(Fixtures.WIDE_SKY).has_point(star.position), "stars stay in the wide sky")
		if not main.run.frame_rect.has_point(star.position):
			outside += 1
	assert_gt(outside, 0, "and reach out past the frame")


## A mid-run resize keeps the run's sky (holding still while it doesn't fit, commit 18); the next run
## takes the new screen's.
func test_a_resize_mid_run_keeps_the_wide_sky_until_a_restart() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	main.fit_visible(Vector2(195, 422))
	assert_eq(main.run.sky_rect, Fixtures.WIDE_SKY, "a portrait resize keeps the wide run's sky")
	assert_eq((main.get_node("Backdrop") as Backdrop).get("_sky"), Fixtures.WIDE_SKY, "and the Backdrop keeps framing it")
	main.fit_visible(Vector2(853, 360))
	assert_eq(main.run.sky_rect, Fixtures.WIDE_SKY)
	assert_true(main.restart())
	assert_eq(main.run.sky_rect, Fixtures.WIDE_SKY, "ultrawide: the 640 cap")
	main.fit_visible(Vector2(195, 422))
	assert_true(main.restart())
	assert_eq(main.run.sky_rect, ScreenZones.play_sky(102), "back on a phone: today's tall sky")


## With no run yet (here a balance error keeps the first one from starting), the Backdrop frames the
## sky the first run will take: the wide one on a landscape screen, today's tall one on a phone.
func test_before_a_run_the_backdrop_frames_the_screens_sky() -> void:
	var broken: Main = MainScene.instantiate()
	broken.balance_path = "res://tests/missing_balance.json"
	add_child_autofree(broken)
	assert_push_error("balance.json")
	assert_null(broken.run)
	var backdrop: Backdrop = broken.get_node("Backdrop")
	broken.fit_visible(Vector2(640, 360))
	assert_eq(backdrop.get("_sky"), Fixtures.WIDE_SKY, "640x360: the wide sky")
	broken.fit_visible(Vector2(195, 422))
	assert_eq(backdrop.get("_sky"), ScreenZones.play_sky(102), "a phone: no side columns")


## A portrait screen builds exactly today's sky, its spare columns staying backdrop.
func test_a_portrait_screen_keeps_todays_sky() -> void:
	for case: Array in [[Vector2(195, 422), 102], [Vector2(256, 341), 21], [Vector2(240, 320), 0], [Vector2(180, 320), 0]]:
		main.fit_visible(case[0])
		assert_true(main.restart())
		assert_eq(main.run.sky_rect, ScreenZones.play_sky(case[1]), "%s: rows only" % case[0])
		assert_eq(main.run.frame_rect, main.run.sky_rect, "%s: the frame is the sky" % case[0])


## Commit 18 (Q1): while the screen can't show the wide run's whole sky the game holds still (the tree
## pauses) under the cover, which says what to do; once it fits again it goes on with the same run.
func test_a_wide_run_holds_still_until_its_sky_fits_again() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	var run: RunState = main.run
	var cover: SkyHoldCover = main.get_node("SkyHoldCover")
	assert_false(main.is_held_for_sky(), "its own screen")
	assert_false(cover.is_showing())
	main.fit_visible(Vector2(300, 333))
	assert_true(main.is_held_for_sky(), "a 900x1000 window can't show it")
	assert_true(get_tree().paused, "the whole game holds still")
	assert_true(cover.is_showing(), "the cover says why")
	assert_eq(cover.action_text(), SkyHoldCover.WIDEN_TEXT, "cut at the sides: widen")
	assert_true(Rect2i(Vector2i(-60, -13), Vector2i(300, 333)).encloses(cover.plaque_rect()), "the plaque is on the visible screen")
	assert_eq(cover.offset, Vector2(60, 13), "drawn in game coordinates, like the other UI layers")
	var plaque: Rect2i = cover.plaque_rect()
	assert_lte(absi(plaque.get_center().x - (-60 + 150)), 1, "centred across the visible screen, not the game's")
	assert_lte(absi(plaque.get_center().y - (-13 + 166)), 1, "and down it")
	main.fit_visible(Vector2(640, 359))
	assert_true(main.is_held_for_sky(), "a row short")
	assert_eq(cover.action_text(), SkyHoldCover.GROW_TEXT, "only the height: grow")
	assert_false(main.go_back(), "back does nothing while it holds")
	assert_false((main.get_node("HUD") as Hud).pause_menu().is_open())
	main.fit_visible(Vector2(640, 360))
	assert_false(main.is_held_for_sky(), "it fits again")
	assert_false(get_tree().paused, "and goes on")
	assert_false(cover.is_showing())
	assert_eq(main.run, run, "the same run")
	assert_eq(main.run.sky_rect, Fixtures.WIDE_SKY, "on the same sky")
	main.fit_visible(Vector2(300, 333))
	assert_true(main.restart(), "a restart while held (tests only: nothing can be tapped)")
	assert_eq(main.run.sky_rect, ScreenZones.play_sky(13), "takes the screen's sky")
	assert_false(main.is_held_for_sky(), "and lets go")
	assert_false(get_tree().paused)


## The hold leaves the player's own pause alone: a pause menu open before stays open (and the world
## held) after the sky fits again, and nothing the player paused is let go.
func test_the_sky_hold_leaves_the_players_pause_menu_as_it_was() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	var hud: Hud = main.get_node("HUD")
	var sky: Node = main.get_node("Sky")
	hud.open_pause()
	assert_eq(sky.process_mode, Node.PROCESS_MODE_DISABLED, "the pause menu holds the world")
	main.fit_visible(Vector2(300, 333))
	assert_true(main.is_held_for_sky())
	assert_true(hud.pause_menu().is_open())
	main.fit_visible(Vector2(640, 360))
	assert_false(main.is_held_for_sky())
	assert_false(get_tree().paused)
	assert_true(hud.pause_menu().is_open(), "the player's pause is still on")
	assert_eq(sky.process_mode, Node.PROCESS_MODE_DISABLED, "and still holds the world")
	hud.close_pause()
	assert_eq(sky.process_mode, Node.PROCESS_MODE_INHERIT, "until the player resumes")
	# The other way round: held first, then the app goes to the background.
	main.fit_visible(Vector2(300, 333))
	main.pause_for_background()
	assert_true(hud.pause_menu().is_open(), "the background still opens PAUSED")
	main.fit_visible(Vector2(640, 360))
	assert_false(get_tree().paused)
	assert_true(hud.pause_menu().is_open(), "which waits for the player on return")
	hud.close_pause()
	assert_eq(sky.process_mode, Node.PROCESS_MODE_INHERIT)


## A portrait run never holds on a portrait screen with at least its rows, or on its own.
func test_a_portrait_run_never_holds_on_a_portrait_screen() -> void:
	for case: Array in [[Vector2(195, 422), [Vector2(196, 422), Vector2(195, 500), Vector2(256, 600)]],
			[Vector2(180, 320), [Vector2(195, 422), Vector2(240, 320), Vector2(180, 400)]],
			[Vector2(256, 341), [Vector2(256, 341), Vector2(300, 400)]]]:
		main.fit_visible(case[0])
		assert_true(main.restart())
		assert_false(main.is_held_for_sky(), "%s: its own screen" % case[0])
		for visible: Vector2 in case[1]:
			main.fit_visible(visible)
			assert_false(main.is_held_for_sky(), "%s run on %s" % [case[0], visible])
			assert_false(get_tree().paused)


## The Sun keeps its place over the run's sky through a resize mid-run (commit 17 moved it with the
## screen's rows); the next run's Sun takes the new screen's.
func test_the_sun_keeps_its_place_through_a_resize_mid_run() -> void:
	var sun: Node2D = main.get_node("Sun")
	var hud: Hud = main.get_node("HUD")
	var collect: CollectParticles = main.get_node("CollectParticles")
	main.fit_visible(Vector2(640, 400))
	assert_true(main.restart())
	var place: Vector2i = ScreenZones.sun_centre(80)
	assert_eq(sun.position, Vector2(place), "1280x800: 80 rows up")
	for visible: Vector2 in [Vector2(640, 500), Vector2(853, 450), Vector2(640, 360)]:
		main.fit_visible(visible)
		assert_eq(sun.position, Vector2(place), "%s: the Sun stays over the run's sky" % visible)
		assert_eq(hud.sun_at, place, "%s: its counter too" % visible)
		assert_eq(collect.light_target, place, "%s: and its light" % visible)
	main.fit_visible(Vector2(640, 500))
	assert_true(main.restart())
	assert_eq(sun.position, Vector2(ScreenZones.sun_centre(180)), "the next run: the new screen's top")
	assert_eq(hud.sun_at, ScreenZones.sun_centre(180))
	main.fit_visible(Vector2(195, 422))
	assert_true(main.restart())
	main.fit_visible(Vector2(195, 500))
	assert_eq(sun.position, Vector2(ScreenZones.sun_centre(102)), "a portrait run's Sun stays too")


## A hold mid-sequence freezes it where it is; after it lets go the sequence plays out once.
func test_a_sequence_held_mid_way_plays_out_once() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	_play_until_idle(sequencer)
	var finished: Array[int] = [0]
	sequencer.sequence_finished.connect(func() -> void: finished[0] += 1)
	assert_true((main.get_node("DebugKeys") as DebugKeys).launch_at_random())
	sequencer.advance(0.1)
	assert_true(sequencer.is_busy(), "the launch is playing")
	var stars: int = main.run.stars.size()
	main.fit_visible(Vector2(300, 333))
	assert_true(main.is_held_for_sky())
	assert_false(sequencer.can_process(), "the sequencer holds still")
	assert_true(sequencer.is_busy(), "mid-way")
	main.fit_visible(Vector2(640, 360))
	assert_true(sequencer.can_process())
	_play_until_idle(sequencer)
	assert_eq(finished[0], 1, "it finished once")
	assert_eq(main.run.stars.size(), stars, "the run went on from where it was")


## A touch down on the sky can't end while the game holds still, so the hold drops it (as a sequence
## starting does); with no touch down, nothing is dropped.
func test_the_hold_drops_a_touch_in_progress() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	_play_until_idle(sequencer)
	assert_true((main.get_node("DebugKeys") as DebugKeys).launch_at_random())
	_play_until_idle(sequencer)
	var sky: SkyView = main.get_node("Sky")
	var gesture: LinkGesture = sky.get("_gesture")
	var star: Star = main.run.stars[0]
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(star.position)
	sky.handle_pointer(touch)
	assert_true(gesture.is_pressed(), "a finger is down")
	main.fit_visible(Vector2(300, 333))
	assert_false(gesture.is_pressed(), "the hold lets it go")
	assert_eq(sky.selected_ids(), [] as Array[int])
	main.fit_visible(Vector2(640, 360))
	assert_false(main.is_held_for_sky())


## The hold also drops a pull on the slingshot and a press on the telescope: neither release can
## arrive while the tree is paused.
func test_the_hold_drops_a_pull_or_a_scope_press() -> void:
	main.fit_visible(Vector2(640, 360))
	main.switch_launcher(false)
	assert_true(main.restart())
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	_play_until_idle(sequencer)
	var slingshot: Launcher = main.launcher()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2.ZERO
	assert_true(slingshot.handle_pointer(touch), "a pull starts")
	assert_true(slingshot.has_press())
	main.fit_visible(Vector2(300, 333))
	assert_false(slingshot.has_press(), "the hold drops the pull")
	assert_false(slingshot.is_pulling())
	main.fit_visible(Vector2(640, 360))
	main.switch_launcher(true)
	var telescope: Telescope = main.launcher()
	touch.position = Vector2(Telescope.PIVOT)
	assert_true(telescope.handle_pointer(touch), "a press on the scope")
	assert_true(telescope.has_press())
	main.fit_visible(Vector2(300, 333))
	assert_true(main.is_held_for_sky())
	assert_false(telescope.has_press(), "the hold drops it")


## A run that's over never holds (its end screen follows the screen, RESTART fits it).
func test_a_run_thats_over_never_holds() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	main.run.outcome = RunState.Outcome.LOST
	main.fit_visible(Vector2(300, 333))
	assert_false(main.is_held_for_sky())
	assert_false(get_tree().paused)
	assert_false((main.get_node("SkyHoldCover") as SkyHoldCover).is_showing())


## A stage left while it holds (back to the chart) doesn't leave the app paused behind it.
func test_leaving_the_stage_mid_hold_lets_the_tree_go() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	main.fit_visible(Vector2(300, 333))
	assert_true(get_tree().paused)
	remove_child(main)
	assert_false(get_tree().paused, "the chart isn't left paused")


## The cover's action follows the cause: turn the screen back only when a wide run's phone or tablet
## is now upright (portrait-shaped); a window made smaller, on a desktop or a phone (split-screen,
## freeform), widens when the sides are cut and grows when only the height is short.
func test_the_cover_says_what_to_do() -> void:
	assert_eq(SkyHoldCover.action_line(Vector2(300, 333), Fixtures.WIDE_SKY, true), SkyHoldCover.TURN_TEXT, "a wide run's tablet turned upright")
	assert_eq(SkyHoldCover.action_line(Vector2(195, 422), Fixtures.WIDE_SKY, true), SkyHoldCover.TURN_TEXT, "a phone-shaped screen")
	assert_eq(SkyHoldCover.action_line(Vector2(300, 333), Fixtures.WIDE_SKY, false), SkyHoldCover.WIDEN_TEXT, "a desktop window narrowed")
	assert_eq(SkyHoldCover.action_line(Vector2(640, 359), Fixtures.WIDE_SKY, false), SkyHoldCover.GROW_TEXT)
	assert_eq(SkyHoldCover.action_line(Vector2(639, 400), Fixtures.WIDE_SKY, false), SkyHoldCover.WIDEN_TEXT, "a column short, rows to spare")


## On a phone or tablet, turning only helps a wide run whose screen became portrait-shaped.
func test_the_cover_says_turn_only_when_turning_helps() -> void:
	var phone: Rect2i = ScreenZones.play_sky(102)
	assert_eq(SkyHoldCover.action_line(Vector2(195, 400), phone, true), SkyHoldCover.GROW_TEXT, "an upright phone losing rows (split-screen)")
	assert_eq(SkyHoldCover.action_line(Vector2(390, 300), phone, true), SkyHoldCover.GROW_TEXT, "a portrait run in a landscape-shaped window")
	assert_eq(SkyHoldCover.action_line(Vector2(500, 330), Fixtures.WIDE_SKY, true), SkyHoldCover.WIDEN_TEXT, "a wide run in a smaller landscape window")
	assert_eq(SkyHoldCover.action_line(Vector2(640, 359), Fixtures.WIDE_SKY, true), SkyHoldCover.GROW_TEXT, "still landscape, a row short")
	assert_eq(SkyHoldCover.action_line(Vector2(360, 360), Fixtures.WIDE_SKY, true), SkyHoldCover.WIDEN_TEXT, "a square window: turning changes nothing")
	assert_eq(SkyHoldCover.action_line(Vector2(360, 361), Fixtures.WIDE_SKY, true), SkyHoldCover.TURN_TEXT, "a row taller than wide is upright")


## Over the player's open pause menu (its own PAUSED heading), the cover drops its heading and sits
## below the menu, clear of it, so one PAUSED reads; with the menu closed it shows its own again.
func test_one_paused_heading_over_the_pause_menu() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	var hud: Hud = main.get_node("HUD")
	var cover: SkyHoldCover = main.get_node("SkyHoldCover")
	hud.open_pause()
	main.fit_visible(Vector2(300, 333))
	assert_true(main.is_held_for_sky())
	assert_true(cover.is_showing(), "the cover still says why")
	assert_false(cover.shows_heading(), "the menu's PAUSED is the only one")
	var menu: Rect2i = hud.pause_menu().plaque_rect()
	var plaque: Rect2i = cover.plaque_rect()
	assert_false(plaque.intersects(menu), "clear of the menu")
	assert_eq(plaque.position.y, menu.end.y + SkyHoldCover.BELOW_GAP, "just below it")
	assert_lte(absi(plaque.get_center().x - menu.get_center().x), 1, "centred under it")
	assert_true(Rect2i(Vector2i(-60, -13), Vector2i(300, 333)).encloses(plaque), "on the visible screen")
	assert_eq(cover.action_text(), SkyHoldCover.WIDEN_TEXT)
	hud.close_pause()
	assert_true(main.is_held_for_sky(), "still held")
	assert_true(cover.shows_heading(), "the menu closed: the cover's own PAUSED")
	assert_lte(absi(cover.plaque_rect().get_center().y - (-13 + 166)), 1, "back in the screen's middle")
	hud.open_pause()
	assert_false(cover.shows_heading(), "opened during the hold (a background pause): one heading")
	main.fit_visible(Vector2(640, 360))
	assert_false(cover.is_showing())


## While held the pause and COMBOS buttons can't be tapped, so they don't show; they come back.
func test_the_hold_hides_the_pause_and_combos_buttons() -> void:
	main.fit_visible(Vector2(640, 360))
	assert_true(main.restart())
	var hud: Hud = main.get_node("HUD")
	var pause_at: Vector2i = hud.pause_target().get_center()
	var table_at: Vector2i = hud.table_target().get_center()
	assert_eq(hud.target_at(pause_at), ["", &"pause"])
	main.fit_visible(Vector2(300, 333))
	pause_at = hud.pause_target().get_center()
	table_at = hud.table_target().get_center()
	assert_false((hud.get_node("PauseButton") as Node2D).visible, "pause hidden")
	assert_false((hud.get_node("TableButton") as Node2D).visible, "COMBOS hidden")
	assert_eq(hud.target_at(pause_at), [])
	assert_eq(hud.target_at(table_at), [])
	main.fit_visible(Vector2(640, 360))
	assert_true((hud.get_node("PauseButton") as Node2D).visible, "back")
	assert_true((hud.get_node("TableButton") as Node2D).visible)
	main.fit_visible(Vector2(300, 333))
	assert_true(main.restart(), "a restart (or a new stage) lets go of the hold")
	assert_true((hud.get_node("PauseButton") as Node2D).visible, "back after a restart")
	assert_true((hud.get_node("TableButton") as Node2D).visible)


func _play_until_idle(sequencer: EventSequencer) -> void:
	var elapsed: float = 0.0
	sequencer.advance(0.0)
	while sequencer.is_busy() and elapsed < 10.0:
		sequencer.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
	assert_false(sequencer.is_busy(), "the sequence ends")


func _invalid_balance() -> Balance:
	var data: Dictionary = Fixtures.balance_dict()
	data["sun_target"] = 0
	return Balance.from_dict(data)


func _burst_sizes() -> Array[int]:
	Fixtures.launch(main.run, Vector2i(90, 160))
	return main.run.sky_sizes()
