extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")


func _pack(stars: int, weights: Array[int], chance: float) -> Balance.PackDef:
	var p := Balance.PackDef.new()
	p.kind = "test"
	p.stars = stars
	p.cost = 1
	p.weights = weights
	p.big_bang_chance = chance
	return p


func test_normal_pack_draws_its_star_count() -> void:
	var b: Balance = Fixtures.balance()
	var rng: RandomNumberGenerator = Fixtures.rng()
	assert_eq(PackOpener.open(b.packs["blue"], rng).sizes.size(), 3)
	assert_eq(PackOpener.open(b.packs["red"], rng).sizes.size(), 4)


func test_zero_chance_never_big_bangs() -> void:
	var rng: RandomNumberGenerator = Fixtures.rng()
	var pack: Balance.PackDef = _pack(3, [1, 1, 1], 0.0)
	for i: int in 2000:
		assert_false(PackOpener.open(pack, rng).big_bang)


func test_big_bang_draws_no_stars() -> void:
	var result: PackOpener.PackResult = PackOpener.open(_pack(4, [1, 1, 1], 1.0), Fixtures.rng())
	assert_true(result.big_bang)
	assert_eq(result.sizes.size(), 0)


func test_force_big_bang() -> void:
	var result: PackOpener.PackResult = PackOpener.open(_pack(3, [1, 1, 1], 0.0), Fixtures.rng(), true)
	assert_true(result.big_bang)
	assert_eq(result.sizes.size(), 0)


func test_big_bang_is_the_first_roll() -> void:
	# Rolled before any stars are drawn: the pack's first random number decides it.
	var pack: Balance.PackDef = _pack(4, [1, 1, 1], 0.3)
	for seed_value: int in 200:
		var expected: bool = Fixtures.rng(seed_value).randf() < 0.3
		assert_eq(PackOpener.open(pack, Fixtures.rng(seed_value)).big_bang, expected)


func test_big_bang_rolled_once_per_pack_not_per_star() -> void:
	# With 4 stars, a per-star roll would give 1 - 0.75^4 = 68%. Once per pack gives 25%.
	var rng: RandomNumberGenerator = Fixtures.rng(7)
	var pack: Balance.PackDef = _pack(4, [1, 1, 1], 0.25)
	var n: int = 20000
	var hits: int = 0
	for i: int in n:
		if PackOpener.open(pack, rng).big_bang:
			hits += 1
	assert_almost_eq(float(hits) / n, 0.25, 0.015)


func test_zero_weight_size_is_never_drawn() -> void:
	var rng: RandomNumberGenerator = Fixtures.rng()
	var pack: Balance.PackDef = _pack(3, [0, 5, 0], 0.0)
	for i: int in 500:
		for size: int in PackOpener.open(pack, rng).sizes:
			assert_eq(size, Star.Size.MEDIUM)


func test_draws_follow_blue_weights() -> void:
	var rng: RandomNumberGenerator = Fixtures.rng(3)
	var counts: Array[int] = [0, 0, 0]
	var n: int = 30000
	for i: int in n:
		counts[PackOpener.draw_size([60, 30, 10], rng)] += 1
	assert_almost_eq(counts[0] / float(n), 0.60, 0.015)
	assert_almost_eq(counts[1] / float(n), 0.30, 0.015)
	assert_almost_eq(counts[2] / float(n), 0.10, 0.015)


func test_each_star_drawn_independently() -> void:
	# Every slot has the same distribution, and the joint odds multiply.
	var rng: RandomNumberGenerator = Fixtures.rng(11)
	var pack: Balance.PackDef = _pack(3, [60, 30, 10], 0.0)
	var n: int = 30000
	var small_by_slot: Array[int] = [0, 0, 0]
	var all_small: int = 0
	for i: int in n:
		var sizes: Array[int] = PackOpener.open(pack, rng).sizes
		for slot: int in 3:
			if sizes[slot] == Star.Size.SMALL:
				small_by_slot[slot] += 1
		if sizes.count(Star.Size.SMALL) == 3:
			all_small += 1
	for slot: int in 3:
		assert_almost_eq(small_by_slot[slot] / float(n), 0.6, 0.015, "slot %d" % slot)
	assert_almost_eq(all_small / float(n), 0.216, 0.015, "P(3 small) = 0.6^3")


func test_same_seed_same_contents() -> void:
	var pack: Balance.PackDef = Fixtures.balance().packs["red"]
	var a: RandomNumberGenerator = Fixtures.rng(42)
	var b: RandomNumberGenerator = Fixtures.rng(42)
	for i: int in 50:
		assert_eq(PackOpener.open(pack, a).sizes, PackOpener.open(pack, b).sizes)
