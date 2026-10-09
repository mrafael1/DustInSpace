extends GutTest
## Reduced motion (game-feel principle 7, #150): no shake, no full-screen flash, half-length
## sequences; an OPTIONS toggle saved beside the sound level.

const Fixtures := preload("res://tests/fixtures.gd")
const AppScene := preload("res://game/scenes/app.tscn")
const MainScene := preload("res://game/scenes/main.tscn")
const BigBangScene := preload("res://game/fx/big_bang.tscn")
const SETTINGS := "user://test_reduced_motion_settings.cfg"
const STORE := "user://test_reduced_motion_progress.json"


func after_each() -> void:
	Motion.reduced = false
	Engine.time_scale = 1.0
	for path: String in [SETTINGS, STORE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_off_by_default_and_every_shake_passes() -> void:
	Motion.load_setting(SETTINGS)
	assert_false(Motion.reduced, "nothing saved: full motion")
	assert_eq(Motion.shake(Vector2i(2, -1)), Vector2i(2, -1))
	assert_eq(Motion.shake_x(-1), -1)


func test_reduced_nothing_shakes() -> void:
	Motion.reduced = true
	assert_eq(Motion.shake(Vector2i(3, 0)), Vector2i.ZERO)
	assert_eq(Motion.shake_x(1), 0)


func test_the_option_is_saved_beside_the_sound_level() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_level", 2)
	config.save(SETTINGS)
	Motion.set_reduced(true, SETTINGS)
	Motion.reduced = false
	Motion.load_setting(SETTINGS)
	assert_true(Motion.reduced, "remembered")
	config = ConfigFile.new()
	config.load(SETTINGS)
	assert_eq(config.get_value("audio", "sfx_level"), 2, "the sound level is kept")


func test_a_refused_planet_keeps_its_ember_border_but_doesnt_shake() -> void:
	var slot: PackSlot = preload("res://game/ui/pack_slot.tscn").instantiate()
	add_child_autofree(slot)
	slot.set_process(false)
	Motion.reduced = true
	slot.nudge()
	for i: int in 6:
		slot.advance(PackSlot.NUDGE_STEP)
		assert_eq((slot.get_node("Icon") as Node2D).position, Vector2.ZERO)
	slot.nudge()
	assert_eq(slot.buy_colours()[1], Palette.S4, "the refusal still reads")


func test_the_big_bang_has_no_shake_and_no_full_screen_flash() -> void:
	var run: RunState = Fixtures.run()
	var sequencer := EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	var big_bang: BigBangSequence = BigBangScene.instantiate()
	add_child_autofree(big_bang)
	big_bang.set_process(false)
	big_bang.setup(run, sequencer)
	Motion.reduced = true
	assert_eq(BigBangSequence.flash_core_radius(0.0), BigBangSequence.FLASH_CORE_RADIUS, "the core marks the bang at once")
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	sequencer.advance(0.0)
	while sequencer.is_busy() and not big_bang.is_playing():
		sequencer.advance(0.05)
	assert_true(big_bang.is_playing(), "the Big Bang plays")
	big_bang.advance(BigBangSequence.BANG_AT + 0.01)
	assert_true(big_bang.is_flashing(), "the bang's moment")
	assert_eq((big_bang.get_node("Shake") as Camera2D).offset, Vector2.ZERO, "the world holds still")


func test_sequences_play_at_double_speed_and_the_game_returns_to_normal() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	main.run.link_rejected.emit([] as Array[int])
	assert_true(sequencer.is_busy())
	assert_eq(Engine.time_scale, 1.0, "full motion: normal speed")
	sequencer.advance(5.0)
	Motion.reduced = true
	main.run.link_rejected.emit([] as Array[int])
	assert_eq(Engine.time_scale, Motion.SEQUENCE_SPEED, "half-length sequences")
	sequencer.advance(5.0)
	assert_false(sequencer.is_busy())
	assert_eq(Engine.time_scale, 1.0, "input time runs at normal speed")


func test_options_toggle_motion_and_remember_it() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	app.settings_path = SETTINGS
	add_child_autofree(app)
	var options: OptionsMenu = app.options()
	options.open()
	assert_eq(options.panel().item_text(&"motion"), "MOTION FULL")
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(options.panel().item_rect(&"motion").get_center())
	touch.pressed = true
	options.handle_pointer(touch)
	touch.pressed = false
	options.handle_pointer(touch)
	assert_true(Motion.reduced)
	assert_eq(options.panel().item_text(&"motion"), "MOTION REDUCED")
	Motion.reduced = false
	Motion.load_setting(SETTINGS)
	assert_true(Motion.reduced, "saved")
	for item: StringName in options.panel().ids():
		assert_true(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN).encloses(options.panel().item_rect(item)), "%s on screen" % item)
