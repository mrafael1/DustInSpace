extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const HudScene := preload("res://game/ui/hud.tscn")

var run: RunState
var hud: Hud
var sequencer: EventSequencer


func before_each() -> void:
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.setup(run, sequencer)


func test_counters_show_the_run() -> void:
	assert_eq(_label("Dust").text, "0")
	assert_null(hud.get_node_or_null("Light"), "no light number: the Sun's fill shows it (#59)")
	assert_eq(_slot_label("blue", "Count").text, "×2")
	assert_eq(_slot_label("blue", "Cost").text, "4", "cost from balance.json")
	assert_eq(_slot_label("red", "Count").text, "×1")
	assert_eq(_slot_label("red", "Cost").text, "7")


func test_one_slot_per_pack_kind_in_balance_order() -> void:
	assert_lt(hud.slot("blue").position.x, hud.slot("red").position.x)
	for kind: String in ["blue", "red"]:
		var at: Vector2 = hud.slot(kind).position
		assert_eq(at, at.round(), "whole pixels")
		# The icon's 44 pt target reaches up into the land strip, whose only other target is the
		# launcher (kept clear below); never into the sky, where the stars are.
		assert_gte(at.y + PackSlot.ICON_TARGET.position.y, float(ScreenZones.SKY.end.y),
			"targets stay below the sky")


func test_the_loaded_pack_is_marked() -> void:
	assert_true(hud.slot("blue").is_loaded())
	assert_false(hud.slot("red").is_loaded())


func test_counters_wait_for_the_events() -> void:
	run.dust = 10
	_tap_part("blue", &"cost")
	assert_eq(_label("Dust").text, "0", "not yet: the buy's events haven't played")
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "6")
	assert_eq(_slot_label("blue", "Count").text, "×3")


func test_a_buy_shows_the_dust_it_left() -> void:
	run.dust = 10
	_tap_part("blue", &"cost")
	run.dust = 99
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "6", "from the event, not the run as it is now")


func test_a_flight_reveals_nothing_ahead_of_it() -> void:
	run.owned_packs["blue"] = 1
	hud.refresh()
	run.force_next_big_bang = true
	sequencer.event_played.connect(_hold_on_launch)
	assert_true(Fixtures.launch(run, Vector2i(90, 100)))
	assert_gt(run.dust, 7, "the Big Bang pays enough for a red pack")
	assert_eq(run.loaded_pack, "", "the run has already moved on: the slingshot is empty")
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "0", "no Big Bang payout mid-flight")
	assert_eq(_slot_label("blue", "Count").text, "×0")
	assert_false(hud.slot("red").is_loaded(), "red isn't loaded until its event plays")
	assert_eq(_slot_label("red", "Cost").label_settings.font_color, Palette.N7, "not affordable yet")
	sequencer.advance(1.0)
	assert_eq(_label("Dust").text, "0", "the Big Bang's dust streams in after the bang")
	assert_eq(_slot_label("red", "Cost").label_settings.font_color, Palette.N7, "red lights up as it lands, not before")
	hud.slot("red").set_process(false)
	hud.receive_dust(7)
	assert_eq(_slot_label("red", "Cost").label_settings.font_color, Palette.D0, "the Big Bang's dust made red affordable")
	assert_true(hud.slot("red").is_cueing(), "and it cues as the counter gets there")
	assert_false(hud.slot("red").is_loaded(), "a launch loads nothing")
	hud.receive_dust(run.dust - 7)
	assert_eq(_label("Dust").text, "%d" % run.dust)
	_assert_shows_the_run()


func test_a_combo_ticks_the_counters_up_as_its_particles_land() -> void:
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "0", "the combo played, but its dust is still flying")
	var rest: Vector2 = _label("Dust").position
	hud.receive_dust(1)
	assert_eq(_label("Dust").text, "1")
	assert_eq(_label("Dust").position, rest + Vector2.UP, "the counter hops a pixel")
	hud.advance(Hud.HOP_TIME)
	assert_eq(_label("Dust").position, rest, "and lands back")
	hud.receive_dust(2)
	assert_eq(_label("Dust").text, "3")
	_assert_shows_the_run()


func test_a_buy_while_dust_is_flying_lands_on_the_right_total() -> void:
	run.dust = 7
	hud.refresh()
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(run.dust, 10)
	_tap_part("blue", &"cost")
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "3", "6 left after the buy, 3 of them still flying")
	hud.receive_dust(3)
	assert_eq(_label("Dust").text, "6")
	assert_eq(_label("Dust").text, "%d" % run.dust)
	_assert_shows_the_run()


func test_a_cost_lights_up_as_the_dust_lands_on_the_counter() -> void:
	run.dust = 2
	hud.refresh()
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.N7, "4 costs more than 2")
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "2", "the reward's dust is still flying")
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.N7, "not lit before the counter shows it")
	hud.receive_dust(1)
	hud.receive_dust(1)
	assert_eq(_label("Dust").text, "4")
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.D0, "lit as it lands")


func test_a_grey_pack_still_buys_with_dust_that_is_flying() -> void:
	run.dust = 2
	hud.refresh()
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.N7, "the counter still reads 2")
	var owned: int = run.owned_packs["blue"]
	_tap_part("blue", &"cost")
	assert_eq(run.owned_packs["blue"], owned + 1, "the core owns the dust: buying is unchanged")


func test_a_pack_cues_once_when_the_counter_reaches_its_cost() -> void:
	run.dust = 2
	hud.refresh()
	var blue: PackSlot = _still_slot("blue")
	_link_small_triple()
	sequencer.advance(0.0)
	assert_false(blue.is_cueing(), "no cue while the dust is flying")
	hud.receive_dust(1)
	assert_false(blue.is_cueing(), "3 is still short of 4")
	hud.receive_dust(1)
	assert_true(blue.is_cueing(), "the counter reached 4")
	assert_true(blue.is_flashing())
	assert_false(sequencer.is_busy(), "the cue never holds the sequencer")
	assert_false(_still_slot("red").is_cueing(), "7 is out of reach")
	hud.receive_dust(1)
	assert_true(blue.is_cueing(), "a landing mid-cue doesn't restart it")
	blue.advance(PackSlot.SPARKLE_STEP * PackSlot.SPARKLE_ARMS.size())
	assert_false(blue.is_cueing())
	_link_small_triple()
	sequencer.advance(0.0)
	for i: int in 3:
		hud.receive_dust(1)
		assert_false(blue.is_cueing(), "still buyable: no repeat")


func test_the_cue_flashes_then_shrinks_a_sparkle_away() -> void:
	run.dust = 3
	hud.refresh()
	var blue: PackSlot = _still_slot("blue")
	_link_small_triple()
	sequencer.advance(0.0)
	hud.receive_dust(1)
	assert_true(blue.is_flashing())
	assert_eq(blue.sparkle_arm(), PackSlot.SPARKLE_ARMS[0])
	blue.advance(PackSlot.FLASH_TIME)
	assert_false(blue.is_flashing(), "two frames of flash, then the lit icon")
	var arms: Array[int] = [blue.sparkle_arm()]
	for i: int in PackSlot.SPARKLE_ARMS.size() - 1:
		blue.advance(PackSlot.SPARKLE_STEP)
		arms.append(blue.sparkle_arm())
	assert_eq(arms, PackSlot.SPARKLE_ARMS, "the sparkle shrinks a step at a time")
	blue.advance(PackSlot.SPARKLE_STEP)
	assert_eq(blue.sparkle_arm(), -1, "and is gone")
	var length: float = PackSlot.SPARKLE_STEP * PackSlot.SPARKLE_ARMS.size()
	assert_lt(length, 0.7, "short: players see it many times a run")


func test_setup_and_refresh_never_cue() -> void:
	run.dust = 10
	hud.refresh()
	assert_false(_still_slot("blue").is_cueing())
	assert_false(_still_slot("red").is_cueing())
	var next: RunState = Fixtures.run()
	next.dust = 10
	sequencer.bind(next)
	hud.setup(next, sequencer)
	assert_false(_still_slot("blue").is_cueing(), "a new run's slots start as they are")
	assert_false(_still_slot("red").is_cueing())


func test_a_cue_stops_when_the_pack_goes_grey() -> void:
	run.dust = 3
	hud.refresh()
	var blue: PackSlot = _still_slot("blue")
	_link_small_triple()
	sequencer.advance(0.0)
	hud.receive_dust(1)
	assert_true(blue.is_cueing())
	run.dust = 0
	hud.refresh()
	assert_false(blue.is_cueing())


func test_spending_below_the_cost_and_earning_it_again_cues_again() -> void:
	run.dust = 3
	hud.refresh()
	var blue: PackSlot = _still_slot("blue")
	_link_small_triple()
	sequencer.advance(0.0)
	for i: int in 3:
		hud.receive_dust(1)
	assert_true(blue.is_cueing())
	_tap_part("blue", &"cost")
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "2", "6 - 4")
	assert_false(blue.is_cueing(), "grey again")
	_link_small_triple()
	sequencer.advance(0.0)
	hud.receive_dust(1)
	assert_false(blue.is_cueing())
	hud.receive_dust(1)
	assert_true(blue.is_cueing(), "back to 4: a new crossing")


func test_blue_and_red_cue_on_their_own_costs() -> void:
	run.dust = 5
	hud.refresh()
	var blue: PackSlot = _still_slot("blue")
	var red: PackSlot = _still_slot("red")
	_link_small_triple()
	sequencer.advance(0.0)
	hud.receive_dust(1)
	assert_false(red.is_cueing(), "6 is short of 7")
	hud.receive_dust(1)
	assert_true(red.is_cueing(), "red crossed 7")
	assert_false(blue.is_cueing(), "blue was buyable all along")


func test_a_pack_icon_is_lit_while_owned_and_grey_at_zero() -> void:
	run.owned_packs["blue"] = 0
	run.owned_packs["red"] = 1
	run.dust = 5
	hud.refresh()
	assert_true(_icon("blue").greyed, "×0 is grey, even when 5 dust would buy a blue")
	assert_false(_icon("blue").bright)
	var blue: PackSlot = hud.slot("blue")
	blue.set_process(false)
	for i: int in 20:
		blue.advance(0.1)
		assert_false(blue.is_hopping(), "and still")
	run.dust = 0
	hud.refresh()
	assert_true(_icon("red").bright, "owned: lit even with no dust")
	assert_false(_icon("red").greyed)


func test_a_buyable_icon_spins_and_a_grey_one_stays_still() -> void:
	for spin: int in PackView.SPIN_FRAMES:
		assert_eq(PackView.frame_name(false, false, PackView.HUD_RADIUS, spin, true), "hud_grey")
		var frame: String = PackView.frame_name(false, true, PackView.HUD_RADIUS, spin)
		assert_eq(frame, "hud_bright_%d" % spin)
		if spin > 0:
			assert_ne(ArtStrip.named("pack_blue").pixels(frame),
				ArtStrip.named("pack_blue").pixels("hud_bright_%d" % (spin - 1)), "the bands move")


func test_a_buyable_icon_hops_a_pixel_now_and_then() -> void:
	run.dust = 5
	hud.refresh()
	var blue: PackSlot = hud.slot("blue")
	var red: PackSlot = hud.slot("red")
	blue.set_process(false)
	red.set_process(false)
	blue.advance(0.0)
	red.advance(0.0)
	assert_true(blue.is_hopping(), "the loaded icon hops as soon as it's buyable")
	assert_false(red.is_hopping(), "one that isn't loaded never does")
	blue.advance(PackSlot.HOP_TIME * 1.1)
	assert_false(blue.is_hopping())
	assert_eq(blue.get_node("Icon").position, Vector2.ZERO, "back on the grid")
	blue.advance(PackSlot.HOP_PERIOD - PackSlot.HOP_TIME * 1.05)
	assert_true(blue.is_hopping(), "and again each period")
	blue.nudge()
	blue.advance(0.01)
	assert_eq(blue.get_node("Icon").position.y, 0.0, "a nudge wins over the hop")
	run.dust = 0
	hud.refresh()
	for i: int in 20:
		blue.advance(0.1)
		assert_false(blue.is_hopping(), "no hop once it's grey")


func test_a_greyed_pack_is_drawn_on_the_land_ramp_only() -> void:
	for kind: String in ["blue", "red"]:
		var dots: Dictionary[Vector2i, Color] = PackView.pixels(kind, false, false, 6, true)
		assert_false(dots.is_empty())
		for colour: Color in dots.values():
			assert_true(colour in Palette.GREY_PACK, "%s greys out" % kind)
		assert_eq(dots.keys(), PackView.pixels(kind, false, false, 6).keys(), "same shape as the lit %s" % kind)


func test_spending_dust_still_in_flight_never_shows_a_negative_balance() -> void:
	var ids: Array[int] = []
	for x: int in [70, 90, 110]:
		ids.append(run.add_star(Star.Size.MEDIUM, Vector2i(x, 150)).id)
	assert_eq(run.link(ids), "medium_triple")
	sequencer.advance(0.0)
	_tap_part("blue", &"cost")
	assert_eq(run.dust, 1, "the core credited the 5 dust, so the buy worked")
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "0", "nothing landed yet and the buy spent it: 0, not -4")
	for i: int in 4:
		hud.receive_dust(1)
		assert_eq(_label("Dust").text, "0", "landings pay back what the buy spent first")
	hud.receive_dust(1)
	assert_eq(_label("Dust").text, "1", "then the counter meets the run")
	assert_false(hud.slot("blue").is_cueing(), "the landings only paid back the buy: no crossing")
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.N7, "1 dust can't buy a blue")
	_assert_shows_the_run()


func test_launching_the_last_pack_clears_the_marker() -> void:
	run.owned_packs["blue"] = 1
	run.owned_packs["red"] = 0
	hud.refresh()
	assert_true(Fixtures.launch(run, Vector2i(90, 100)))
	sequencer.advance(0.0)
	assert_eq(run.loaded_pack, "")
	assert_false(hud.slot("blue").is_loaded(), "no pack left to mark")
	assert_false(hud.slot("red").is_loaded())
	_assert_shows_the_run()


func test_tapping_an_owned_pack_loads_it() -> void:
	_tap_part("red", &"icon")
	assert_eq(run.loaded_pack, "red")
	assert_eq(run.dust, 0, "loading costs nothing")
	sequencer.advance(0.0)
	assert_true(hud.slot("red").is_loaded())
	assert_false(hud.slot("blue").is_loaded())


func test_tapping_a_pack_you_own_none_of_buys_it() -> void:
	run.owned_packs["red"] = 0
	run.dust = 7
	_tap_part("red", &"icon")
	assert_eq(run.owned_packs["red"], 1)
	assert_eq(run.dust, 0)
	assert_eq(run.loaded_pack, "red", "buying loads it")


func test_tapping_a_pack_you_cannot_have_nudges_and_changes_nothing() -> void:
	run.owned_packs["red"] = 0
	_tap_part("red", &"icon")
	assert_eq(run.owned_packs["red"], 0)
	assert_eq(run.loaded_pack, "blue")
	assert_true(hud.slot("red").is_nudging())
	for i: int in 20:
		hud.slot("red").advance(1.0 / 60.0)
	assert_false(hud.slot("red").is_nudging())
	assert_eq((hud.slot("red").get_node("Icon") as Node2D).position, Vector2.ZERO, "back in place")


func test_the_cost_buys_one_more_even_when_you_own_some() -> void:
	run.dust = 4
	_tap_part("blue", &"cost")
	assert_eq(run.owned_packs["blue"], 3)
	assert_eq(run.dust, 0)


func test_an_unaffordable_cost_nudges_and_is_shown_cool() -> void:
	_tap_part("blue", &"cost")
	assert_eq(run.owned_packs["blue"], 2)
	assert_true(hud.slot("blue").is_nudging())
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.N7)
	run.dust = 4
	hud.refresh()
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.D0)
	assert_eq(_slot_label("red", "Cost").label_settings.font_color, Palette.N7, "each slot has its own colour")


func test_a_tap_needs_press_and_release_on_the_same_target() -> void:
	run.dust = 20
	var blue: Vector2i = Vector2i(hud.slot("blue").position)
	_touch(blue, true)
	_touch(blue + Vector2i(0, 16), false)
	assert_eq(run.owned_packs["blue"], 2, "slid from the icon onto the cost: nothing")
	assert_eq(run.loaded_pack, "blue")


func test_taps_off_the_targets_are_left_for_others() -> void:
	assert_false(_touch(Vector2i(40, 300), true), "the dust counter isn't a button")
	assert_false(_touch(Vector2i(90, 270), true), "the launcher's pack")
	assert_false(_touch(Vector2i(90, 160), true), "the sky")


func test_tap_targets_are_44_pt_and_keep_clear_of_the_launcher() -> void:
	assert_gte(PackSlot.ICON_TARGET.size.x, 22)
	assert_gte(PackSlot.ICON_TARGET.size.y, 22)
	assert_eq(PackSlot.ICON_TARGET.end.y, PackSlot.COST_TARGET.position.y, "icon and cost targets meet without overlapping")
	var launcher_press := Rect2i(90 - Launcher.HIT_RADIUS, 270 - Launcher.HIT_RADIUS, 2 * Launcher.HIT_RADIUS + 1, 2 * Launcher.HIT_RADIUS + 1)
	for kind: String in ["blue", "red"]:
		var at := Vector2i(hud.slot(kind).position)
		assert_false(Rect2i(PackSlot.ICON_TARGET.position + at, PackSlot.ICON_TARGET.size).intersects(launcher_press))
		var cost := Rect2i(PackSlot.COST_TARGET.position + at, PackSlot.COST_TARGET.size)
		assert_lte(cost.end.y, 320, "on screen")


func test_nothing_is_bought_once_the_run_is_over() -> void:
	run.dust = 20
	run.outcome = RunState.Outcome.LOST
	_tap_part("blue", &"cost")
	assert_eq(run.owned_packs["blue"], 2)
	assert_true(hud.slot("blue").is_nudging())


func test_the_buy_button_buys_one_more_with_none_one_or_many_owned() -> void:
	for kind: String in ["blue", "red"]:
		var cost: int = run.balance.packs[kind].cost
		for owned: int in [0, 1, 3]:
			run.owned_packs[kind] = owned
			run.dust = cost * 2 + 1
			run.loaded_pack = ""
			hud.refresh()
			_tap_part(kind, &"cost")
			var case: String = "%s with %d owned" % [kind, owned]
			assert_eq(run.dust, cost + 1, "%s: the cost, exactly once" % case)
			assert_eq(run.owned_packs[kind], owned + 1, "%s: one more" % case)
			assert_eq(run.loaded_pack, kind, "%s: and it's loaded" % case)
			sequencer.advance(0.0)
			assert_eq(_slot_label(kind, "Count").text, "×%d" % (owned + 1))


func test_the_buy_button_takes_the_exact_cost_and_refuses_one_short() -> void:
	for kind: String in ["blue", "red"]:
		var cost: int = run.balance.packs[kind].cost
		var owned: int = run.owned_packs[kind]
		run.dust = cost - 1
		hud.refresh()
		_tap_part(kind, &"cost")
		assert_eq([run.dust, run.owned_packs[kind]], [cost - 1, owned], "%s: one short buys nothing" % kind)
		assert_true(hud.slot(kind).is_nudging(), "and says no")
		assert_eq(hud.slot(kind).buy_colours()[1], Palette.S4, "the button's border too")
		run.dust = cost
		hud.refresh()
		_tap_part(kind, &"cost")
		assert_eq([run.dust, run.owned_packs[kind]], [0, owned + 1], "%s: the exact cost buys" % kind)
		sequencer.advance(0.0)


func test_loading_an_owned_pack_never_buys_one() -> void:
	run.dust = 20
	run.owned_packs["red"] = 2
	hud.refresh()
	_tap_part("red", &"icon")
	assert_eq(run.dust, 20, "the icon loads for free")
	assert_eq(run.owned_packs["red"], 2)
	assert_eq(run.loaded_pack, "red")
	_tap_part("red", &"icon")
	assert_eq([run.dust, run.owned_packs["red"]], [20, 2], "tapping the loaded pack again changes nothing")


func test_nothing_is_bought_from_either_target_once_the_run_is_over() -> void:
	run.dust = 20
	run.owned_packs["red"] = 0
	run.outcome = RunState.Outcome.WON
	_tap_part("red", &"icon")
	_tap_part("red", &"cost")
	assert_eq([run.dust, run.owned_packs["red"]], [20, 0])


func test_the_buy_button_reads_as_a_button() -> void:
	run.dust = 5
	hud.refresh()
	var blue: PackSlot = hud.slot("blue")
	var red: PackSlot = hud.slot("red")
	assert_eq(blue.buy_colours(), [Palette.M1, Palette.C2, Palette.D0] as Array[Color], "warm border: you can buy")
	assert_eq(red.buy_colours(), [Palette.M1, Palette.M4, Palette.N7] as Array[Color], "cool: not yet")
	assert_true(PackSlot.COST_TARGET.encloses(PackSlot.BUY_PLATE), "the whole plate is tappable")
	for size: Vector2i in [PackSlot.ICON_TARGET.size, PackSlot.COST_TARGET.size]:
		assert_gte(size.x, 22)
		assert_gte(size.y, 22, "44 pt both")


func test_the_buy_row_is_centred_for_any_cost() -> void:
	for cost: int in [4, 7, 12]:
		var digits: int = str(cost).length()
		hud.slot("blue").show_pack(1, cost, true, false, false)
		var row: Array[Vector2i] = hud.slot("blue").buy_row()
		var left: int = row[0].x - 1
		var right: int = row[2].x + digits * PackSlot.DIGIT_ADVANCE - 2
		var plate: Rect2i = PackSlot.BUY_PLATE
		assert_lte(absi((left - plate.position.x) - (plate.end.x - 1 - right)), 1, "cost %d: centred" % cost)
		assert_eq(row[1].x - row[0].x, 5, "+ then the dust icon")
		assert_eq(row[2].x - row[1].x, 4, "then the cost")


func test_the_buy_button_shows_the_press_and_the_buy() -> void:
	run.dust = 5
	hud.refresh()
	var blue: PackSlot = hud.slot("blue")
	blue.set_process(false)
	var at: Vector2i = Vector2i(blue.position) + PackSlot.COST_TARGET.get_center()
	_touch(at, true)
	assert_true(blue.is_buy_pressed(), "held down at once")
	assert_eq(blue.buy_colours()[0], Palette.M3)
	_touch(at, false)
	assert_false(blue.is_buy_pressed())
	sequencer.advance(0.0)
	assert_eq(blue.buy_colours()[1], Palette.C0, "the buy flashes the border")
	blue.advance(PackSlot.BOUGHT_FLASH)
	assert_ne(blue.buy_colours()[1], Palette.C0)
	var icon_at: Vector2i = Vector2i(blue.position) + PackSlot.ICON_TARGET.get_center()
	_touch(icon_at, true)
	assert_false(blue.is_buy_pressed(), "pressing the icon doesn't press the button")
	_touch(icon_at, false)
	_touch(at, true)
	_touch(Vector2i(90, 150), false)
	assert_false(blue.is_buy_pressed(), "sliding off lets go without buying")


func test_labels_use_the_bitmap_fonts_with_a_shadow() -> void:
	var dust: LabelSettings = _label("Dust").label_settings
	assert_eq(dust.font, HudText.PRIMARY_FONT)
	assert_eq(dust.font_size, HudText.PRIMARY_FONT.fixed_size, "never scaled")
	assert_eq(dust.shadow_color, Palette.N0)
	assert_eq(dust.shadow_offset, Vector2(1, 1))
	var count: LabelSettings = _slot_label("blue", "Count").label_settings
	assert_eq(count.font, HudText.SECONDARY_FONT)
	assert_eq(count.font_size, HudText.SECONDARY_FONT.fixed_size)


func test_glyphs_start_on_the_label_top_pixel() -> void:
	# The image-font importer centres glyphs on the baseline (offset -h/2). With the automatic
	# ascent of h/2 those halves cancel, so a glyph's top row is the Label's top row.
	for font: FontFile in [HudText.PRIMARY_FONT, HudText.SECONDARY_FONT]:
		var size: int = font.fixed_size
		assert_eq(font.get_ascent(size), size / 2.0, font.resource_path)
		assert_eq(font.get_height(size), float(size), "whole-pixel line height")


func test_fonts_have_every_glyph_the_hud_writes() -> void:
	for font: FontFile in [HudText.PRIMARY_FONT, HudText.SECONDARY_FONT]:
		for c: String in "0123456789/×+- ":
			assert_true(font.has_char(c.unicode_at(0)), "%s in %s" % [c, font.resource_path])


func test_dust_icons_are_faceted_diamonds_on_the_dust_ramp() -> void:
	for small: bool in [false, true]:
		var dots: Dictionary[Vector2i, Color] = DustIcon.pixels(small)
		var r: int = 2 if small else 4
		assert_true(dots.has(Vector2i(0, -r)) and dots.has(Vector2i(r, 0)), "%d px wide" % (2 * r + 1))
		assert_false(dots.has(Vector2i(r, r)), "a diamond, not a square")
		for dot: Vector2i in dots:
			assert_true(dots[dot] in [Palette.D0, Palette.N8, Palette.N7])


## Links three small stars: a small triple, worth 3 dust and 5 light in the fixtures.
func test_only_the_loaded_pack_icon_moves() -> void:
	for loaded: String in ["blue", "red", ""]:
		run.owned_packs["blue"] = 2
		run.owned_packs["red"] = 0 if loaded == "" else 2
		run.loaded_pack = loaded
		if loaded == "":
			run.owned_packs["blue"] = 0
		run.dust = 50
		hud.refresh()
		for kind: String in ["blue", "red"]:
			var slot: PackSlot = hud.slot(kind)
			slot.set_process(false)
			var icon: PackView = _icon(kind)
			icon.set_process(false)
			var moved: bool = false
			for i: int in 12:
				slot.advance(0.13)
				icon.advance(0.13)
				moved = moved or slot.is_hopping() or icon.spin_frame() != 0
			assert_eq(moved, kind == loaded, "%s loaded: %s %s" % [loaded if loaded != "" else "nothing", kind, "moves" if kind == loaded else "stays still"])


func test_the_buy_button_also_picks_the_planet() -> void:
	run.dust = 50
	watch_signals(hud)
	_tap_part("red", &"cost")
	assert_signal_emitted_with_parameters(hud, "planet_chosen", ["red"])
	assert_eq(run.loaded_pack, "red")


func test_a_refused_buy_picks_nothing() -> void:
	run.dust = 0
	watch_signals(hud)
	_tap_part("red", &"cost")
	assert_signal_not_emitted(hud, "planet_chosen")


func _link_small_triple() -> void:
	var ids: Array[int] = []
	for x: int in [70, 90, 110]:
		ids.append(run.add_star(Star.Size.SMALL, Vector2i(x, 150)).id)
	assert_eq(run.link(ids), "small_triple")


## Stands in for the launcher: keeps the pack flying for a second.
func _hold_on_launch(event: EventSequencer.RunEvent) -> void:
	if event.type == &"pack_launched":
		sequencer.hold(1.0)


## Once every event has played, the HUD shows exactly what RunState holds.
func _assert_shows_the_run() -> void:
	var shown: Array[String] = _texts()
	var loaded: Array[bool] = [hud.slot("blue").is_loaded(), hud.slot("red").is_loaded()]
	hud.refresh()
	assert_eq(shown, _texts(), "counters caught up with the run")
	assert_eq(loaded, [hud.slot("blue").is_loaded(), hud.slot("red").is_loaded()] as Array[bool])


func _texts() -> Array[String]:
	var texts: Array[String] = [_label("Dust").text]
	for kind: String in ["blue", "red"]:
		texts.append(_slot_label(kind, "Count").text)
		texts.append("%s" % _slot_label(kind, "Cost").label_settings.font_color)
	return texts


func _tap_part(kind: String, part: StringName) -> void:
	var target: Rect2i = PackSlot.ICON_TARGET if part == &"icon" else PackSlot.COST_TARGET
	var point: Vector2i = Vector2i(hud.slot(kind).position) + target.get_center()
	assert_eq(hud.target_at(point), [kind, part])
	_touch(point, true)
	_touch(point, false)


func _touch(point: Vector2i, pressed: bool) -> bool:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(point)
	e.pressed = pressed
	return hud.handle_pointer(e)


func _label(name: String) -> Label:
	return hud.get_node(name)


## A slot the test moves on by hand.
func _still_slot(kind: String) -> PackSlot:
	var pack_slot: PackSlot = hud.slot(kind)
	pack_slot.set_process(false)
	return pack_slot


func _icon(kind: String) -> PackView:
	return hud.slot(kind).get_node("Icon")


func _slot_label(kind: String, name: String) -> Label:
	return hud.slot(kind).get_node(name)


## On a wide screen the dust counter and the pack slots stay close to the stage.
func test_the_hud_stays_near_the_stage_on_a_wide_screen() -> void:
	var wide := Rect2i(-60, -80, 300, 400)
	var blue_before: Vector2i = Vector2i(hud.slot("blue").position)
	hud.fit_screen(wide)
	assert_eq(Vector2i((hud.get_node("Dust") as Label).position), Hud.DUST_AT + Vector2i(-Hud.HUD_REACH, 0), "12 px out, not in the far corner")
	var blue_at: Vector2i = blue_before + Vector2i(Hud.HUD_REACH, 0)
	assert_eq(hud.target_at(blue_at + PackSlot.COST_TARGET.get_center()), ["blue", &"cost"], "taps follow the slots")


func test_the_hud_anchors_to_a_taller_phone_screens_corners() -> void:
	# A 1170x2532 phone: 195x422 game pixels, the game's 180x320 on the bottom, centred across.
	var phone := Rect2i(-7, -102, 195, 422)
	var blue_before: Vector2i = Vector2i(hud.slot("blue").position)
	hud.fit_screen(phone)
	assert_eq(hud.sound_target(), Rect2i(SoundToggle.TARGET.position + phone.position, SoundToggle.TARGET.size), "the speaker's corner of the screen, as on 9:16")
	assert_eq(Vector2i((hud.get_node("Dust") as Label).position), Hud.DUST_AT + Vector2i(-7, 0), "dust on its left edge")
	assert_eq(Vector2i((hud.get_node("DustIcon") as Node2D).position), Hud.DUST_ICON_AT + Vector2i(-7, 0))
	var blue_at: Vector2i = blue_before + Vector2i(phone.end.x - ScreenZones.SCREEN.x, 0)
	assert_eq(hud.target_at(blue_at + PackSlot.COST_TARGET.get_center()), ["blue", &"cost"], "the slots on its right edge, taps follow")
