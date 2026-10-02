extends GutTest
## The table (#94): each link and what it pays, from balance.json; the one-of-each row cuts through
## every order; the COMBOS button opens it, the game holds still behind it, and a tap closes it.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var hud: Hud


func test_the_rows_read_balance_json() -> void:
	var balance: Balance = Balance.load_file(Balance.DEFAULT_PATH)
	var rows: Array[Dictionary] = PaytableView.rows_for(balance)
	var keys: Array[String] = []
	for row: Dictionary in rows:
		keys.append(row["key"])
		assert_eq(row["dust"], balance.combos[row["key"]].dust, row["key"])
	assert_eq(keys, ["small_triple", "medium_triple", "big_triple", Combos.SEQUENCE] as Array[String], "the triples, then one of each")
	assert_eq(rows[0]["sizes"], [Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL])
	assert_eq(rows[2]["sizes"], [Star.Size.BIG, Star.Size.BIG, Star.Size.BIG])


func test_one_mark_per_unit_of_the_smallest_light() -> void:
	var balance: Balance = Balance.load_file(Balance.DEFAULT_PATH)
	var unit: int = PaytableView.light_unit(balance)
	var smallest: int = balance.combos["small_triple"].light
	for key: String in balance.combos:
		smallest = mini(smallest, balance.combos[key].light)
	assert_eq(unit, smallest, "the unit is the smallest light a link gives")
	for row: Dictionary in PaytableView.rows_for(balance):
		assert_eq(row["marks"], roundi(float(balance.combos[row["key"]].light) / unit), row["key"])
	var marks: Array[int] = []
	for row: Dictionary in PaytableView.rows_for(balance):
		marks.append(row["marks"])
	assert_eq(marks, [1, 2, 3, 5] as Array[int], "shipped: + ++ +++ +++++")


func test_the_marks_follow_tuning() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["combos"]["small_triple"]["light"] = 7
	data["combos"]["sequence"]["light"] = 30
	var balance: Balance = Balance.from_dict(data)
	assert_eq(PaytableView.light_unit(balance), 7)
	assert_eq(PaytableView.light_marks(30, 7), 4, "rounded")
	assert_eq(PaytableView.light_marks(1, 7), 1, "any light shows at least one")
	assert_eq(PaytableView.light_marks(0, 7), 0)


func test_any_tuning_fits_the_plaque() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["combos"]["small_triple"]["light"] = 1
	data["combos"]["sequence"]["light"] = 25
	var balance: Balance = Balance.from_dict(data)
	assert_eq(PaytableView.light_unit(balance), 5, "the unit grows so the most light fits")
	for row: Dictionary in PaytableView.rows_for(balance):
		assert_lte(row["marks"], PaytableView.MAX_SUNS, row["key"])
		assert_gte(row["marks"], 1, "any light still shows")
	var suns: Array[Vector2i] = PaytableView.sun_centres(PaytableView.MAX_SUNS, PaytableView.LIGHT_X, 0)
	assert_lte(suns[-1].x + PaytableView.SUN_SIZE / 2, PaytableView.PLAQUE_W - PaytableView.PAD, "MAX_SUNS fit")


func test_the_one_of_each_row_cuts_through_every_order() -> void:
	var seen: Array = []
	for k: int in PaytableView.ORDERS.size():
		var order: Array = PaytableView.ORDERS[PaytableView.order_index(k * PaytableView.ORDER_TIME + 0.01)]
		var sorted: Array = order.duplicate()
		sorted.sort()
		assert_eq(sorted, [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG], "one of each size")
		assert_false(seen.has(order), "a new order")
		seen.append(order)
	assert_eq(seen.size(), 6, "all six")
	assert_eq(PaytableView.order_index(6 * PaytableView.ORDER_TIME + 0.01), 0, "then again")


func test_the_table_fits_the_screen() -> void:
	var plaque: Rect2i = PaytableView.plaque_rect(4)
	assert_true(Rect2i(Vector2i.ZERO, ScreenZones.SCREEN).encloses(plaque))
	assert_lt(plaque.end.y, ScreenZones.SKY.end.y, "in the sky, TAP TO CLOSE inside it")
	var stars: int = PaytableView.STARS_X + 3 * (StarView.half_extent(Star.Size.BIG) * 2 + 1) + 2 * PaytableView.STAR_GAP
	assert_lt(stars, PaytableView.DUST_X, "the stars clear the dust column")
	var suns: Array[Vector2i] = PaytableView.sun_centres(5, PaytableView.LIGHT_X, 0)
	assert_lte(suns[-1].x + PaytableView.SUN_SIZE / 2, PaytableView.PLAQUE_W - PaytableView.PAD, "five suns fit")
	assert_gt(PaytableView.LIGHT_X, PaytableView.DUST_X + PaytableView.DUST_ICON_DX + 4, "clear of the dust icons")


func test_the_table_button_opens_it_and_the_game_holds_still() -> void:
	_start()
	var sky: Node = main.get_node("Sky")
	var sequencer: Node = main.get_node("EventSequencer")
	var scope: Node = main.get_node("Telescope")
	var modes: Array = [sky.process_mode, sequencer.process_mode, scope.process_mode]
	_tap(hud.table_target().get_center())
	assert_true(hud.table().is_open())
	assert_eq(hud.table().rows().size(), 4)
	for node: Node in [sky, sequencer, scope, main.get_node("Sun"), main.get_node("CollectParticles")]:
		assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, "%s holds still" % node.name)
	assert_eq(hud.tutorial_guide().process_mode, Node.PROCESS_MODE_DISABLED, "the guide's timers too")
	hud.show_message("HELLO", 1.0)
	hud.advance(2.0)
	assert_eq(hud.message(), "HELLO", "the HUD's own timers hold too")
	_tap(Vector2i(90, 200))
	assert_false(hud.table().is_open(), "a tap closes it")
	assert_eq([sky.process_mode, sequencer.process_mode, scope.process_mode], modes, "back as they were")


func test_the_table_takes_every_touch_while_open() -> void:
	_start()
	hud.open_table()
	var press := InputEventScreenTouch.new()
	press.position = Vector2(hud.buy_button_at("blue") + Vector2i(2, 0))
	press.pressed = true
	assert_true(hud.handle_pointer(press), "a press goes to the table")
	assert_true(hud.table().is_open(), "only a release closes it")
	var dust: int = main.run.dust
	press.pressed = false
	hud.handle_pointer(press)
	assert_eq(main.run.dust, dust, "the buy button under it isn't pressed")


func test_the_one_of_each_row_moves_on_with_time() -> void:
	_start()
	hud.open_table()
	var first: Array = hud.table().sequence_sizes()
	hud.advance(PaytableView.ORDER_TIME + 0.01)
	assert_ne(hud.table().sequence_sizes(), first)


func test_the_table_button_sits_under_the_map_slot() -> void:
	_start()
	hud.show_map_button(true)
	assert_false(hud.table_target().intersects(hud.map_target()), "their targets don't meet")
	assert_eq(hud.target_at(hud.table_target().get_center()), ["", &"table"])
	assert_eq(hud.target_at(hud.map_target().get_center()), ["", &"map"])
	assert_lt(hud.table_target().end.y, ScreenZones.SKY.position.y + 1, "above the sky, clear of the stars")


func test_switching_launchers_under_the_table_holds_after_it_closes() -> void:
	_start()
	var slingshot: Node = main.get_node("Launcher")
	var scope: Node = main.get_node("Telescope")
	hud.open_table()
	main.switch_launcher(not main.use_telescope)
	var on: Node = scope if main.use_telescope else slingshot
	var off: Node = slingshot if main.use_telescope else scope
	assert_eq(on.process_mode, Node.PROCESS_MODE_DISABLED, "still held while the table shows")
	hud.close_table()
	assert_ne(on.process_mode, Node.PROCESS_MODE_DISABLED, "the chosen launcher plays")
	assert_eq(off.process_mode, Node.PROCESS_MODE_DISABLED, "the hidden one stays off")


func test_a_new_run_closes_the_table() -> void:
	_start()
	hud.open_table()
	main.restart()
	assert_false(hud.table().is_open())
	assert_ne(main.get_node("Sky").process_mode, Node.PROCESS_MODE_DISABLED, "the world plays again")


func _start() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	main.star_map = "stinger"
	add_child_autofree(main)
	hud = main.get_node("HUD")
	for node: Node in [main.get_node("EventSequencer"), main.get_node("Telescope"), hud]:
		node.set_process(false)


func _tap(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = Vector2(at)
		touch.pressed = pressed
		hud.handle_pointer(touch)


func test_the_light_shows_as_pale_gold_suns_and_the_line_stays_dim() -> void:
	assert_eq(PaytableView.DUST_COLOUR, Palette.D0, "dust's lavender")
	assert_eq(PaytableView.LIGHT_COLOUR, Palette.C1, "light's pale gold")
	assert_lt(PaytableView.LINE_COLOUR.get_luminance(), PaytableView.DUST_COLOUR.get_luminance(), "the line stays quieter than the rewards")
	var sun: Dictionary[Vector2i, Color] = ArtStrip.named("light_icon").pixels("sun")
	for d: Vector2i in sun:
		assert_eq(sun[d], Palette.C1, "every sun in the same pale gold")
	for d: Vector2i in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
		assert_true(sun.has(d), "diagonal rays: round, not a star's cross")
	var suns: Array[Vector2i] = PaytableView.sun_centres(3, 0, 0)
	assert_eq(suns[0].x - PaytableView.SUN_SIZE / 2, 0, "left-aligned")
	assert_eq(suns[2].x - suns[1].x, suns[1].x - suns[0].x, "evenly spaced")
	_start()
	hud.open_table()
	var labels: Array[Label] = hud.table().get("_labels")
	assert_true(labels.filter(func(l: Label) -> bool: return l.text.contains("+")).is_empty(), "no + marks left")


func test_the_column_heads_share_a_line_and_tap_to_close_is_small() -> void:
	_start()
	hud.open_table()
	var labels: Array[Label] = hud.table().get("_labels")
	var heads: Array = labels.filter(func(l: Label) -> bool: return l.text in [PaytableView.TITLE, PaytableView.DUST_TEXT, PaytableView.LIGHT_TEXT])
	assert_eq(heads.size(), 3)
	for head: Label in heads:
		assert_eq(head.position.y, heads[0].position.y, "%s on the heads' line" % head.text)
	var title: Label = heads.filter(func(l: Label) -> bool: return l.text == PaytableView.TITLE)[0]
	var stars_mid: float = PaytableView.PLAQUE_AT.x + PaytableView.STARS_X + PaytableView.stars_width() / 2.0
	assert_almost_eq(title.position.x + title.get_minimum_size().x / 2.0, stars_mid, 1.0, "COMBOS centred over the stars")
	var tap: Array = labels.filter(func(l: Label) -> bool: return l.text == PaytableView.TAP_TEXT)
	assert_eq(tap[0].label_settings.font_size, HudText.SECONDARY_SIZE, "the small font")


func test_the_table_hides_the_tutorial_line_while_open() -> void:
	_start()
	hud.tutorial_guide().show_step(Tutorial.Step.LINK)
	hud.open_table()
	assert_eq(hud.tutorial_guide().modulate.a, 0.0, "the line doesn't crowd the plaque")
	assert_eq(hud.tutorial_guide().text(), TutorialView.TEXTS[Tutorial.Step.LINK], "it keeps its step")
	hud.close_table()
	assert_eq(hud.tutorial_guide().modulate.a, 1.0, "back once it's closed")
