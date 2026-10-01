extends GutTest
## Big Bangs are off on constellation stages (scorpio.big_bang false): the roll is still made, so
## every pack's contents stay the same, but it never comes up. The debug trigger still forces one,
## and the plain Sun stage keeps them.

const Fixtures := preload("res://tests/fixtures.gd")


func test_the_switch_is_read_and_checked() -> void:
	assert_true(_balance(true).scorpio_big_bang, "true when given")
	var data: Dictionary = _data(true)
	(data["scorpio"] as Dictionary).erase("big_bang")
	assert_true(Balance.from_dict(data).scorpio_big_bang, "optional: on by default")
	data["scorpio"]["big_bang"] = "no"
	assert_false(Balance.from_dict(data).is_valid(), "must be a bool")
	assert_false(Balance.load_file(Balance.DEFAULT_PATH).scorpio_big_bang, "shipped: off in the chapter")


func test_a_constellation_stage_never_rolls_one() -> void:
	var run := RunState.new(_balance(false), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	var bangs: Array = []
	run.big_bang_started.connect(func(...args: Array) -> void: bangs.append(args))
	for i: int in 3:
		assert_true(run.launch(Vector2i(90, 150)))
	assert_eq(bangs.size(), 0, "a certain Big Bang never comes up")
	assert_eq(run.stars.size(), 2 * 3 + 1 * 4, "every pack opened into stars")


func test_the_debug_trigger_still_forces_one() -> void:
	var run := RunState.new(_balance(false), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	var bangs: Array = []
	run.big_bang_started.connect(func(...args: Array) -> void: bangs.append(args))
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	assert_eq(bangs.size(), 1)


func test_the_plain_stage_keeps_them() -> void:
	var data: Dictionary = _data(false)
	data["scorpio"]["enabled"] = false
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY)
	var bangs: Array = []
	run.big_bang_started.connect(func(...args: Array) -> void: bangs.append(args))
	run.launch(Vector2i(90, 150))
	assert_eq(bangs.size(), 1, "a certain Big Bang comes up")


func test_switching_them_off_keeps_every_packs_stars() -> void:
	var data: Dictionary = _data(true)
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	var skies: Array = []
	for on: bool in [true, false]:
		data["scorpio"]["big_bang"] = on
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(3), Fixtures.SKY, StarMap.stinger())
		for i: int in 3:
			run.launch(Vector2i(90, 150))
		var sizes: Array[int] = []
		for star: Star in run.stars:
			sizes.append(star.size)
		skies.append(sizes)
	assert_eq(skies[0], skies[1], "the same RNG stream either way")


## Every pack opens as a Big Bang unless the switch stops it.
func _data(big_bang: bool) -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 1.0
	data["packs"]["red"]["big_bang_chance"] = 1.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56, "big_bang": big_bang}
	return data


func _balance(big_bang: bool) -> Balance:
	return Balance.from_dict(_data(big_bang))
