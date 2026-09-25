extends RefCounted
## Shared test data. Preload it: `const Fixtures := preload("res://tests/fixtures.gd")`.

## Play sky from docs/art-direction.md: y 78-250.
const SKY := Rect2i(0, 78, 180, 172)


## A copy of the shipped balance values as a dictionary, so tests can tweak one field.
static func balance_dict() -> Dictionary:
	return {
		"sun_target": 100,
		"start_dust": 0,
		"start_packs": {"blue": 2, "red": 1},
		"packs": {
			"blue": {"cost": 4, "stars": 3, "weights": {"small": 60, "medium": 30, "big": 10}, "big_bang_chance": 0.02},
			"red": {"cost": 7, "stars": 4, "weights": {"small": 20, "medium": 40, "big": 40}, "big_bang_chance": 0.04},
		},
		"combos": {
			"small_triple": {"dust": 3, "light": 5},
			"medium_triple": {"dust": 5, "light": 10},
			"big_triple": {"dust": 6, "light": 15},
			"sequence": {"dust": 3, "light": 25},
		},
		"big_bang": {"base_dust": 8, "dust_per_cleared_star": 2},
	}


## Balance with no random Big Bangs, so tests control them with force_next_big_bang.
static func balance(overrides: Dictionary = {}) -> Balance:
	var data: Dictionary = balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data.merge(overrides, true)
	var result: Balance = Balance.from_dict(data)
	assert(result.is_valid(), str(result.errors))
	return result


static func rng(seed_value: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func run(overrides: Dictionary = {}, seed_value: int = 1) -> RunState:
	return RunState.new(balance(overrides), rng(seed_value), SKY)


static func ids(stars: Array[Star]) -> Array[int]:
	var result: Array[int] = []
	for star: Star in stars:
		result.append(star.id)
	return result
