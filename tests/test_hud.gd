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
	assert_eq(_label("Light").text, "0/100", "light over the Sun's target")
	assert_eq(_slot_label("blue", "Count").text, "×2")
	assert_eq(_slot_label("blue", "Cost").text, "4", "cost from balance.json")
	assert_eq(_slot_label("red", "Count").text, "×1")
	assert_eq(_slot_label("red", "Cost").text, "7")


func test_one_slot_per_pack_kind_in_balance_order() -> void:
	assert_lt(hud.slot("blue").position.x, hud.slot("red").position.x)
	for kind: String in ["blue", "red"]:
		var at: Vector2 = hud.slot(kind).position
		assert_eq(at, at.round(), "whole pixels")
		assert_gte(at.y + PackSlot.ICON_TARGET.position.y, float(ScreenZones.HUD.position.y) - 3,
			"targets sit in the HUD band")


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
	assert_true(run.launch(Vector2i(90, 100)))
	assert_gt(run.dust, 7, "the Big Bang pays enough for a red pack")
	assert_eq(run.loaded_pack, "red", "the run has already moved on")
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "0", "no Big Bang payout mid-flight")
	assert_eq(_slot_label("blue", "Count").text, "×0")
	assert_false(hud.slot("red").is_loaded(), "red isn't loaded until its event plays")
	assert_eq(_slot_label("red", "Cost").label_settings.font_color, Palette.N7, "not affordable yet")
	sequencer.advance(1.0)
	assert_eq(_label("Dust").text, "%d" % run.dust)
	assert_true(hud.slot("red").is_loaded())
	assert_eq(_slot_label("red", "Cost").label_settings.font_color, Palette.D0)
	_assert_shows_the_run()


func test_a_combo_ticks_the_counters_up_as_its_particles_land() -> void:
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(_label("Dust").text, "0", "the combo played, but its dust is still flying")
	assert_eq(_label("Light").text, "0/100")
	var rest: Vector2 = _label("Dust").position
	hud.receive_dust(1)
	assert_eq(_label("Dust").text, "1")
	assert_eq(_label("Dust").position, rest + Vector2.UP, "the counter hops a pixel")
	assert_eq(_label("Dust").label_settings.font_color, Palette.C0, "and flashes")
	assert_true((hud.get_node("DustIcon") as DustIcon).bright, "the dust icon pulses")
	hud.advance(Hud.HOP_TIME)
	assert_eq(_label("Dust").position, rest, "and lands back")
	assert_eq(_label("Dust").label_settings.font_color, Palette.D0)
	assert_false((hud.get_node("DustIcon") as DustIcon).bright)
	hud.receive_light(1)
	assert_eq(_label("Light").label_settings.font_color, Palette.C0)
	hud.advance(Hud.HOP_TIME)
	assert_eq(_label("Light").label_settings.font_color, Palette.C1, "back to its own colour")
	assert_false((hud.get_node("DustIcon") as DustIcon).bright, "light doesn't pulse the dust icon")
	hud.receive_dust(2)
	hud.receive_light(4)
	assert_eq(_label("Dust").text, "3")
	assert_eq(_label("Light").text, "5/100")
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
	hud.receive_light(5)
	_assert_shows_the_run()


func test_costs_light_up_only_when_the_dust_lands() -> void:
	run.dust = 2
	hud.refresh()
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.N7, "4 costs more than the 2 shown")
	hud.receive_dust(3)
	assert_eq(_slot_label("blue", "Cost").label_settings.font_color, Palette.D0)


func test_launching_the_last_pack_clears_the_marker() -> void:
	run.owned_packs["blue"] = 1
	run.owned_packs["red"] = 0
	hud.refresh()
	assert_true(run.launch(Vector2i(90, 100)))
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


func test_labels_use_the_bitmap_fonts_with_a_shadow() -> void:
	var dust: LabelSettings = _label("Dust").label_settings
	assert_eq(dust.font, HudText.PRIMARY_FONT)
	assert_eq(dust.font_size, HudText.PRIMARY_FONT.fixed_size, "never scaled")
	assert_eq(dust.shadow_color, Palette.N0)
	assert_eq(dust.shadow_offset, Vector2(1, 1))
	var light: LabelSettings = _label("Light").label_settings
	assert_eq(light.font, HudText.SECONDARY_FONT)
	assert_eq(light.font_size, HudText.SECONDARY_FONT.fixed_size)
	assert_eq(light.font_color, Palette.C1)


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


func test_the_dust_icon_pulse_lifts_each_facet_up_the_dust_ramp() -> void:
	var calm: Dictionary[Vector2i, Color] = DustIcon.pixels(false)
	var bright: Dictionary[Vector2i, Color] = DustIcon.pixels(false, true)
	assert_eq(calm.keys(), bright.keys(), "same shape, no scaling")
	assert_eq(bright[Vector2i(3, 1)], Palette.N8, "N7 lifts to N8")
	assert_eq(bright[Vector2i(3, -1)], Palette.D0, "N8 lifts to D0")
	for colour: Color in bright.values():
		assert_true(colour in [Palette.D0, Palette.N8, Palette.N7])


func test_dust_icons_are_faceted_diamonds_on_the_dust_ramp() -> void:
	for small: bool in [false, true]:
		var dots: Dictionary[Vector2i, Color] = DustIcon.pixels(small)
		var r: int = 2 if small else 4
		assert_true(dots.has(Vector2i(0, -r)) and dots.has(Vector2i(r, 0)), "%d px wide" % (2 * r + 1))
		assert_false(dots.has(Vector2i(r, r)), "a diamond, not a square")
		for dot: Vector2i in dots:
			assert_true(dots[dot] in [Palette.D0, Palette.N8, Palette.N7])


## Links three small stars: a small triple, worth 3 dust and 5 light in the fixtures.
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
	var texts: Array[String] = [_label("Dust").text, _label("Light").text]
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


func _slot_label(kind: String, name: String) -> Label:
	return hud.slot(kind).get_node(name)
