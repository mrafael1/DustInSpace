extends GutTest
## Haptics (#150): the cues that sell the slot machine by feel also vibrate, muted or not; never in
## the Big Bang's silence; an OPTIONS toggle on phones, saved beside the sound level.

const Fixtures := preload("res://tests/fixtures.gd")
const AppScene := preload("res://game/scenes/app.tscn")
const SETTINGS := "user://test_haptics_settings.cfg"
const STORE := "user://test_haptics_progress.json"

var pulses: Array[Array] = []
var sfx: Sfx


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))
	pulses = []
	sfx = Sfx.new()
	sfx.settings_path = SETTINGS
	add_child_autofree(sfx)
	sfx.set_process(false)
	sfx.haptics.vibrate = _record


func after_all() -> void:
	for path: String in [SETTINGS, STORE]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _record(ms: int, amplitude: float) -> void:
	pulses.append([ms, amplitude])


func test_on_by_default_and_every_pattern_is_short_and_gentle() -> void:
	assert_true(sfx.haptics.enabled)
	for cue: StringName in Haptics.PATTERNS:
		assert_has(Sfx.CUES, cue, "%s is a real cue" % cue)
		for pulse: Array in Haptics.PATTERNS[cue]:
			assert_between(pulse[1], 1, 400, "%s: a pulse, not a long buzz" % cue)
			assert_between(pulse[2], 0.0, 1.0)


func test_a_star_pick_ticks_and_a_link_taps_twice() -> void:
	sfx.play(&"star_select")
	assert_eq(pulses.size(), 1, "a tick at once")
	sfx.advance(0.5)
	pulses.clear()
	sfx.play(&"link_collect")
	assert_eq(pulses.size(), 1, "the first tap")
	sfx.advance(0.1)
	assert_eq(pulses.size(), 2, "then the second")


func test_muted_play_still_vibrates() -> void:
	sfx.set_level(Sfx.Level.MUTE)
	assert_false(sfx.play(&"link_reject"), "no sound")
	assert_eq(pulses.size(), 1, "but the refusal is felt")


func test_the_big_bang_silence_is_still() -> void:
	sfx.duck()
	sfx.play(&"burst")
	assert_eq(pulses, [] as Array[Array])


func test_a_stream_never_blurs_into_one_buzz() -> void:
	for i: int in 5:
		sfx.play(&"burst")
		sfx.advance(0.01)
	assert_eq(pulses.size(), 1)
	sfx.advance(Haptics.MIN_GAP)
	sfx.play(&"burst")
	assert_eq(pulses.size(), 2)


func test_cues_without_a_pattern_dont_vibrate() -> void:
	sfx.play(&"dust_land")
	sfx.play(&"pull_step")
	assert_eq(pulses, [] as Array[Array], "a payout's landings are heard, not felt")


func test_off_nothing_vibrates_and_it_is_remembered() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_level", 1)
	config.save(SETTINGS)
	sfx.haptics.set_enabled(false, SETTINGS)
	sfx.play(&"burst")
	assert_eq(pulses, [] as Array[Array])
	var again := Haptics.new()
	again.load_setting(SETTINGS)
	assert_false(again.enabled, "saved")
	config = ConfigFile.new()
	config.load(SETTINGS)
	assert_eq(config.get_value("audio", "sfx_level"), 1, "the sound level is kept")


func test_a_new_run_drops_pulses_still_to_come() -> void:
	sfx.play(&"win")
	sfx.reset()
	sfx.advance(1.0)
	assert_eq(pulses.size(), 1, "only the first, already felt")


func test_options_offer_haptics_on_a_phone_and_toggle_them() -> void:
	var app: App = AppScene.instantiate()
	app.progress_path = STORE
	app.settings_path = SETTINGS
	add_child_autofree(app)
	var options: OptionsMenu = app.options()
	assert_eq(options.panel().ids().has(&"haptics"), Haptics.is_supported(), "only where it can vibrate")
	options.offer_haptics(true)
	options.open()
	assert_eq(options.panel().item_text(&"haptics"), "HAPTICS ON")
	var chart_sfx: Sfx = app.get_node("ChartSfx")
	chart_sfx.haptics.vibrate = _record
	watch_signals(options)
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(options.panel().item_rect(&"haptics").get_center())
	touch.pressed = true
	options.handle_pointer(touch)
	touch.pressed = false
	options.handle_pointer(touch)
	assert_signal_emitted(options, "haptics_toggle_requested")
	assert_false(chart_sfx.haptics.enabled)
	assert_eq(options.panel().item_text(&"haptics"), "HAPTICS OFF")
	pulses.clear()
	app.toggle_haptics()
	assert_true(chart_sfx.haptics.enabled)
	assert_eq(pulses.size(), 1, "turned on, it ticks")
