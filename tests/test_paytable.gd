extends GutTest
## The table (#94): each link and what it pays, from balance.json; the one-of-each row cuts through
## every order; the TABLE button opens it, the game holds still behind it, and a tap closes it.

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
	assert_lt(PaytableView.LIGHT_X + 5 * 6, PaytableView.PLAQUE_W - PaytableView.PAD, "five marks fit")


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
