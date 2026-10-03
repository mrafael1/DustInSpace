extends GutTest
## The debug overlay (#11): balance values edited in memory (BalanceEdit), re-validated through
## Balance.from_dict, and the run restarted with them; a Big Bang forced like key B. balance.json is
## never written.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var overlay: DebugOverlay


# --- BalanceEdit --------------------------------------------------------------------------

func test_every_tunable_leaf_in_the_files_order() -> void:
	var edit := BalanceEdit.new(Balance.load_file())
	var keys: Array[String] = edit.keys()
	assert_eq(keys[0], "sun_target")
	assert_true(keys.has("packs.blue.cost"))
	assert_true(keys.has("packs.red.weights.big"))
	assert_true(keys.has("scorpio.enabled"), "switches too")
	assert_true(keys.has("hints.idle_seconds"))
	assert_false(keys.has("_note"), "text isn't tuning")
	assert_lt(keys.find("packs.blue.cost"), keys.find("packs.red.cost"))


func test_whole_numbers_step_by_one_and_never_below_zero() -> void:
	var edit := BalanceEdit.new(Fixtures.balance())
	assert_eq(edit.value("packs.blue.cost"), 4)
	assert_true(edit.step("packs.blue.cost", 1))
	assert_eq(edit.value("packs.blue.cost"), 5)
	assert_eq(typeof(edit.value("packs.blue.cost")), TYPE_INT, "JSON's floats come in whole")
	for i: int in 10:
		edit.step("start_dust", -1)
	assert_eq(edit.value("start_dust"), 0)


func test_chances_step_by_hundredths_within_zero_and_one() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	var edit := BalanceEdit.new(Balance.from_dict(data))
	edit.step("packs.blue.big_bang_chance", 1)
	assert_almost_eq(float(edit.value("packs.blue.big_bang_chance")), 0.03, 0.0001)
	edit.step("volley.fraction", 1)
	assert_eq(edit.value("volley.fraction"), 1.0, "a fraction of 1 stays 1")
	edit.step("volley.fraction", -1)
	assert_almost_eq(float(edit.value("volley.fraction")), 0.99, 0.0001)


func test_seconds_step_by_halves_and_switches_flip() -> void:
	var edit := BalanceEdit.new(Balance.load_file())
	edit.step("hints.idle_seconds", 1)
	assert_eq(edit.value("hints.idle_seconds"), 4.5)
	assert_eq(BalanceEdit.show_value(4.5), "4.5")
	assert_eq(BalanceEdit.show_value(0.02), "0.02")
	assert_eq(BalanceEdit.show_value(4.0), "4")
	var on: bool = edit.value("scorpio.enabled")
	edit.step("scorpio.enabled", 1)
	assert_eq(edit.value("scorpio.enabled"), not on)
	assert_eq(BalanceEdit.show_value(true), "ON")
	assert_false(edit.step("nothing.here", 1), "an unknown key changes nothing")


func test_edits_build_a_validated_balance_and_leave_the_original_alone() -> void:
	var original: Balance = Fixtures.balance()
	var edit := BalanceEdit.new(original)
	edit.step("packs.red.cost", 1)
	var built: Balance = edit.build()
	assert_true(built.is_valid())
	assert_eq(built.packs["red"].cost, 8)
	assert_eq(original.packs["red"].cost, 7, "the run's balance is untouched")
	assert_eq(original.source["packs"]["red"]["cost"], 7)
	for i: int in 10:
		edit.step("sun_target", -100)
	var invalid: Balance = edit.build()
	assert_false(invalid.is_valid(), "a sun target of 0 is caught like in the file")
	assert_string_contains(invalid.errors[0], "sun_target")


func test_balance_json_is_never_written() -> void:
	var before: String = FileAccess.get_file_as_string(Balance.DEFAULT_PATH)
	_start_main()
	overlay.open()
	overlay.nudge(0, 1)
	overlay.press("APPLY")
	assert_eq(FileAccess.get_file_as_string(Balance.DEFAULT_PATH), before)


# --- The overlay in Main ------------------------------------------------------------------

func test_o_opens_it_and_the_world_holds_still() -> void:
	_start_main()
	assert_false(overlay.is_open())
	var key := InputEventKey.new()
	key.keycode = KEY_O
	key.pressed = true
	overlay._unhandled_key_input(key)
	assert_true(overlay.is_open())
	assert_true(overlay.visible)
	assert_eq(main.get_node("Sky").process_mode, Node.PROCESS_MODE_DISABLED, "the world holds still")
	overlay.press("CLOSE")
	assert_false(overlay.is_open())
	assert_ne(main.get_node("Sky").process_mode, Node.PROCESS_MODE_DISABLED)


func test_closing_it_over_the_open_table_keeps_the_world_held() -> void:
	_start_main()
	var hud: Hud = main.get_node("HUD")
	var sky: Node = main.get_node("Sky")
	hud.open_table()
	assert_eq(sky.process_mode, Node.PROCESS_MODE_DISABLED, "the table holds the world")
	overlay.open()
	overlay.press("CLOSE")
	assert_eq(sky.process_mode, Node.PROCESS_MODE_DISABLED, "the table still does")
	hud.close_table()
	assert_ne(sky.process_mode, Node.PROCESS_MODE_DISABLED, "the last to let go starts it again")
	overlay.open()
	hud.open_table()
	hud.close_table()
	assert_eq(sky.process_mode, Node.PROCESS_MODE_DISABLED, "and the other way round")
	overlay.press("CLOSE")
	assert_ne(sky.process_mode, Node.PROCESS_MODE_DISABLED)


func test_a_three_finger_tap_toggles_it() -> void:
	_start_main()
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	overlay._input(touch)
	assert_true(overlay.is_open())
	overlay._input(touch)
	assert_false(overlay.is_open())
	# _input marked the viewport's input handled: a key nobody takes clears it for the next tests.
	var neutral := InputEventKey.new()
	neutral.keycode = KEY_F24
	neutral.pressed = true
	get_viewport().push_input(neutral)
	assert_false(get_viewport().is_input_handled())


func test_plus_on_a_row_then_apply_restarts_the_run_with_it() -> void:
	_start_main()
	overlay.open()
	var row: int = overlay.edit().keys().find("start_dust")
	assert_lt(row, DebugOverlay.ROWS, "on the first page")
	overlay.tap(Vector2i(DebugOverlay.PLUS_X + 4, DebugOverlay.TOP + row * DebugOverlay.ROW_H + 4))
	overlay.tap(Vector2i(DebugOverlay.PLUS_X + 4, DebugOverlay.TOP + row * DebugOverlay.ROW_H + 4))
	assert_eq(overlay.edit().value("start_dust"), 2)
	var old: RunState = main.run
	overlay.tap(Vector2i(_button_centre("APPLY"), DebugOverlay.BUTTON_Y + 8))
	assert_ne(main.run, old, "a fresh run")
	assert_eq(main.run.dust, 2, "with the edited start")
	assert_false(overlay.is_open())
	overlay.open()
	assert_eq(overlay.edit().value("start_dust"), 2, "the edits carry over")


func test_an_invalid_edit_says_why_and_keeps_the_run() -> void:
	_start_main()
	overlay.open()
	for i: int in 200:
		overlay.nudge(overlay.edit().keys().find("sun_target"), -1)
	var old: RunState = main.run
	overlay.press("APPLY")
	assert_eq(main.run, old)
	assert_true(overlay.is_open(), "it stays open to fix it")
	assert_string_contains((overlay.get("_error") as Label).text, "sun_target")


func test_bang_forces_the_next_pack_like_key_b() -> void:
	_start_main()
	overlay.open()
	overlay.press("BANG")
	assert_true(main.run.force_next_big_bang)
	assert_eq((overlay.get("_button_labels") as Array)[1].text, "BANG ON")
	overlay.press("BANG")
	assert_false(main.run.force_next_big_bang, "a toggle")


func test_page_turns_through_every_value() -> void:
	_start_main()
	overlay.open()
	var seen: Array[String] = []
	for page: int in overlay.pages():
		for label: Label in overlay.get("_labels"):
			if label.text != "":
				seen.append(label.text)
		overlay.press("PAGE")
	assert_eq(seen, overlay.edit().keys())
	assert_eq(overlay.get("_page"), 0, "and back to the first")


func test_it_takes_every_touch_while_open() -> void:
	_start_main()
	overlay.open()
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(90, 150)
	touch.pressed = true
	assert_true(overlay.handle_pointer(touch))


func _start_main() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	assert_true(main.start_run(Fixtures.balance()))
	overlay = main.get_node("DebugLayer/DebugOverlay")


func _button_centre(button: String) -> int:
	var i: int = DebugOverlay.BUTTONS.find(button)
	return 1 + i * (DebugOverlay.BUTTON_W + 1) + DebugOverlay.BUTTON_W / 2
