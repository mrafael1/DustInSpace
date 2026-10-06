extends GutTest
## Big Bangs are off on constellation stages (scorpio.big_bang false): the roll is still made but
## never comes up. Packs open as they would with them on until a roll that would have come up; that
## pack draws its stars instead, so the stream moves on from there. The debug trigger still forces
## one, and the plain Sun stage keeps them.

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
		assert_true(Fixtures.launch(run, Vector2i(90, 150)))
	assert_eq(bangs.size(), 0, "a certain Big Bang never comes up")
	assert_eq(run.stars.size(), 2 * 3 + 1 * 4, "every pack opened into stars")


func test_the_debug_trigger_still_forces_one() -> void:
	var run := RunState.new(_balance(false), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	var bangs: Array = []
	run.big_bang_started.connect(func(...args: Array) -> void: bangs.append(args))
	run.force_next_big_bang = true
	Fixtures.launch(run, Vector2i(90, 150))
	assert_eq(bangs.size(), 1)


func test_the_plain_stage_keeps_them() -> void:
	var data: Dictionary = _data(false)
	data["scorpio"]["enabled"] = false
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY)
	var bangs: Array = []
	run.big_bang_started.connect(func(...args: Array) -> void: bangs.append(args))
	Fixtures.launch(run, Vector2i(90, 150))
	assert_eq(bangs.size(), 1, "a certain Big Bang comes up")


func test_switching_them_off_keeps_the_packs_whose_roll_fails() -> void:
	var data: Dictionary = _data(true)
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	var skies: Array = []
	for on: bool in [true, false]:
		data["scorpio"]["big_bang"] = on
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(3), Fixtures.SKY, StarMap.stinger())
		for i: int in 3:
			Fixtures.launch(run, Vector2i(90, 150))
		var sizes: Array[int] = []
		for star: Star in run.stars:
			sizes.append(star.size)
		skies.append(sizes)
	assert_eq(skies[0], skies[1], "the same RNG stream either way")


## A roll that would have come up: the pack draws its stars instead of opening empty, and those
## draws move the stream on, so the next pack differs from the one it follows with the switch on.
func test_a_stopped_big_bang_draws_its_stars_and_moves_the_stream_on() -> void:
	var pack: Balance.PackDef = _balance(true).packs["blue"]
	var calm: Balance.PackDef = _balance_with_chance(0.0).packs["blue"]
	var on_rng: RandomNumberGenerator = Fixtures.rng(3)
	var off_rng: RandomNumberGenerator = Fixtures.rng(3)
	var on: PackOpener.PackResult = PackOpener.open(pack, on_rng, false, true)
	var off: PackOpener.PackResult = PackOpener.open(pack, off_rng, false, false)
	assert_true(on.big_bang)
	assert_true(on.sizes.is_empty())
	assert_false(off.big_bang, "stopped")
	assert_eq(off.sizes.size(), pack.stars, "it opens into its stars instead")
	var next_on: PackOpener.PackResult = PackOpener.open(calm, on_rng, false, true)
	var next_off: PackOpener.PackResult = PackOpener.open(calm, off_rng, false, false)
	assert_eq(next_on.sizes.size(), next_off.sizes.size())
	assert_ne(next_on.sizes, next_off.sizes, "seed 3: the stopped pack's draws shifted the next one")


## Every pack opens as a Big Bang unless the switch stops it.
func _data(big_bang: bool) -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 1.0
	data["packs"]["red"]["big_bang_chance"] = 1.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56, "big_bang": big_bang}
	return data


func _balance(big_bang: bool) -> Balance:
	return Balance.from_dict(_data(big_bang))


func _balance_with_chance(chance: float) -> Balance:
	var data: Dictionary = _data(true)
	data["packs"]["blue"]["big_bang_chance"] = chance
	return Balance.from_dict(data)
