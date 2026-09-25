extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")


func _invalid_with(mutate: Callable) -> Balance:
	var data: Dictionary = Fixtures.balance_dict()
	mutate.call(data)
	return Balance.from_dict(data)


func test_shipped_balance_file_is_valid() -> void:
	var b: Balance = Balance.load_file()
	assert_true(b.is_valid(), str(b.errors))


func test_shipped_balance_matches_design_start() -> void:
	var b: Balance = Balance.load_file()
	assert_eq(b.start_packs["blue"], 2, "start with 2 blue packs")
	assert_eq(b.start_packs["red"], 1, "start with 1 red pack")
	assert_eq(b.start_dust, 0, "start with 0 dust")
	assert_eq(b.pack_kinds(), ["blue", "red"] as Array[String])


func test_parses_every_value() -> void:
	var b: Balance = Balance.from_dict(Fixtures.balance_dict())
	assert_true(b.is_valid(), str(b.errors))
	assert_eq(b.sun_target, 100)
	assert_eq(b.packs["red"].cost, 7)
	assert_eq(b.packs["red"].stars, 4)
	assert_eq(b.packs["blue"].weights, [60, 30, 10] as Array[int])
	assert_almost_eq(b.packs["red"].big_bang_chance, 0.04, 0.0001)
	assert_eq(b.combos["sequence"].light, 25)
	assert_eq(b.combos["big_triple"].dust, 6)
	assert_eq(b.big_bang_base_dust, 8)
	assert_eq(b.big_bang_dust_per_cleared_star, 2)
	assert_eq(b.cheapest_pack_cost(), 4)


func test_numbers_from_json_become_ints() -> void:
	# JSON numbers parse as floats in Godot; whole numbers must still load as ints.
	var b: Balance = Balance.from_dict(JSON.parse_string(JSON.stringify(Fixtures.balance_dict())))
	assert_true(b.is_valid(), str(b.errors))
	assert_typeof(b.packs["blue"].cost, TYPE_INT)


func test_missing_file_is_invalid() -> void:
	var b: Balance = Balance.load_file("res://does_not_exist.json")
	assert_false(b.is_valid())


func test_rejects_missing_key() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d.erase("sun_target"))
	assert_false(b.is_valid())
	assert_string_contains(str(b.errors), "sun_target")


func test_rejects_fractional_cost() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["packs"]["blue"]["cost"] = 4.5)
	assert_false(b.is_valid())


func test_rejects_non_positive_cost() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["packs"]["red"]["cost"] = 0)
	assert_false(b.is_valid())


func test_rejects_pack_with_no_stars() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["packs"]["blue"]["stars"] = 0)
	assert_false(b.is_valid())


func test_rejects_big_bang_chance_out_of_range() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["packs"]["red"]["big_bang_chance"] = 1.5)
	assert_false(b.is_valid())


func test_rejects_all_zero_weights() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void:
		d["packs"]["blue"]["weights"] = {"small": 0, "medium": 0, "big": 0})
	assert_false(b.is_valid())


func test_rejects_negative_weight() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["packs"]["blue"]["weights"]["big"] = -1)
	assert_false(b.is_valid())


func test_rejects_unknown_start_pack() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["start_packs"]["green"] = 1)
	assert_false(b.is_valid())
	assert_string_contains(str(b.errors), "green")


func test_rejects_missing_combo() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["combos"].erase("sequence"))
	assert_false(b.is_valid())


func test_rejects_string_number() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void: d["combos"]["sequence"]["light"] = "25")
	assert_false(b.is_valid())


func test_rejects_no_packs() -> void:
	var b: Balance = _invalid_with(func(d: Dictionary) -> void:
		d["packs"] = {}
		d["start_packs"] = {})
	assert_false(b.is_valid())
