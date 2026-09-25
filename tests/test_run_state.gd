extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const S := Star.Size.SMALL
const M := Star.Size.MEDIUM
const B := Star.Size.BIG
const MID := Vector2i(90, 130)

var run: RunState


func before_each() -> void:
	run = Fixtures.run()
	watch_signals(run)


## Empties the launcher so loss conditions can be reached quickly.
func _no_packs(state: RunState) -> void:
	for kind: String in state.owned_packs.keys():
		state.owned_packs[kind] = 0
	state.loaded_pack = ""


func _add(sizes: Array) -> Array[Star]:
	var added: Array[Star] = []
	for size: int in sizes:
		added.append(run.add_star(size as Star.Size, MID))
	return added


# --- start of run -------------------------------------------------------------

func test_run_starts_from_balance() -> void:
	assert_eq(run.dust, 0)
	assert_eq(run.light, 0, "the Sun starts dark")
	assert_eq(run.owned_packs["blue"], 2)
	assert_eq(run.owned_packs["red"], 1)
	assert_eq(run.stars.size(), 0)
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_first_owned_pack_is_loaded_at_start() -> void:
	assert_eq(run.loaded_pack, "blue")


func test_start_dust_comes_from_balance() -> void:
	assert_eq(Fixtures.run({"start_dust": 9}).dust, 9)


# --- buying and loading -------------------------------------------------------

func test_buy_spends_dust_adds_pack_and_loads_it() -> void:
	run.dust = 10
	assert_true(run.buy("red"))
	assert_eq(run.dust, 3)
	assert_eq(run.owned_packs["red"], 2)
	assert_eq(run.loaded_pack, "red", "buying loads the pack into the launcher")
	assert_signal_emitted_with_parameters(run, "pack_bought", ["red"])
	assert_signal_emitted_with_parameters(run, "pack_loaded", ["red"])


func test_cannot_buy_without_enough_dust() -> void:
	run.dust = 6
	assert_false(run.buy("red"))
	assert_eq(run.dust, 6)
	assert_eq(run.owned_packs["red"], 1)
	assert_signal_not_emitted(run, "pack_bought")


func test_can_buy_with_exact_dust() -> void:
	run.dust = 4
	assert_true(run.buy("blue"))
	assert_eq(run.dust, 0)


func test_cannot_buy_unknown_pack() -> void:
	run.dust = 100
	assert_false(run.buy("green"))
	assert_eq(run.dust, 100)


func test_player_chooses_which_owned_pack_to_load() -> void:
	assert_true(run.load_pack("red"))
	assert_eq(run.loaded_pack, "red")


func test_cannot_load_pack_not_owned() -> void:
	run.owned_packs["red"] = 0
	assert_false(run.load_pack("red"))
	assert_eq(run.loaded_pack, "blue")


# --- launching ----------------------------------------------------------------

func test_launch_bursts_loaded_pack_into_the_sky() -> void:
	assert_true(run.launch(MID))
	assert_eq(run.owned_packs["blue"], 1)
	assert_eq(run.stars.size(), 3, "blue pack has 3 stars")
	assert_signal_emitted(run, "pack_launched")
	assert_signal_emitted(run, "pack_burst")
	var params: Array = get_signal_parameters(run, "pack_burst")
	assert_eq(params[0], "blue")
	assert_eq((params[2] as Array).size(), 3)


func test_red_pack_bursts_four_stars() -> void:
	run.load_pack("red")
	run.launch(MID)
	assert_eq(run.stars.size(), 4)


func test_unused_stars_stay_in_the_sky() -> void:
	run.launch(MID)
	var first: Array[int] = Fixtures.ids(run.stars)
	run.launch(MID)
	assert_eq(run.stars.size(), 6)
	for id: int in first:
		assert_not_null(run.find_star(id))


func test_launcher_keeps_kind_then_falls_back() -> void:
	run.launch(MID)
	assert_eq(run.loaded_pack, "blue", "still one blue left")
	run.launch(MID)
	assert_eq(run.loaded_pack, "red", "blue ran out, red is loaded")
	run.launch(MID)
	assert_eq(run.loaded_pack, "", "nothing left to load")


func test_cannot_launch_with_empty_launcher() -> void:
	run.dust = 100  # keeps the run alive
	_no_packs(run)
	assert_false(run.launch(MID))
	assert_signal_not_emitted(run, "pack_launched")


func test_launch_near_edges_keeps_stars_inside_sky() -> void:
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	var targets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(179, 319), Vector2i(0, 200), Vector2i(179, 30)]
	for target: Vector2i in targets:
		var state: RunState = Fixtures.run({"start_packs": {"blue": 0, "red": 6}})
		for i: int in 6:
			state.launch(target)
		for star: Star in state.stars:
			assert_true(inner.has_point(star.position), "%s from %s" % [star.position, target])


func test_launch_position_never_changes_pack_contents() -> void:
	var a: RunState = Fixtures.run({"start_packs": {"blue": 5, "red": 0}}, 99)
	var b: RunState = Fixtures.run({"start_packs": {"blue": 5, "red": 0}}, 99)
	var targets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(170, 200), Vector2i(90, 60), Vector2i(10, 230), MID]
	for i: int in 5:
		a.launch(MID)
		b.launch(targets[i])
	assert_eq(a.sky_sizes(), b.sky_sizes())


# --- linking ------------------------------------------------------------------

func test_valid_triple_pays_and_removes_stars() -> void:
	var linked: Array[Star] = _add([M, M, M])
	var other: Star = run.add_star(S, MID)
	assert_eq(run.link(Fixtures.ids(linked)), "medium_triple")
	assert_eq(run.dust, 5)
	assert_eq(run.light, 10)
	assert_eq(run.stars, [other] as Array[Star])
	assert_signal_emitted(run, "combo_collected")
	var params: Array = get_signal_parameters(run, "combo_collected")
	assert_eq(params[0], "medium_triple")
	assert_eq(params[2], 5)
	assert_eq(params[3], 10)


func test_each_triple_pays_its_balance_reward() -> void:
	var expected: Dictionary = {S: [3, 5], M: [5, 10], B: [6, 15]}
	for size: int in expected:
		var state: RunState = Fixtures.run()
		var ids: Array[int] = []
		for i: int in 3:
			ids.append(state.add_star(size as Star.Size, MID).id)
		state.link(ids)
		assert_eq([state.dust, state.light], expected[size])


func test_sequence_in_any_link_order_pays_light() -> void:
	var stars: Array[Star] = _add([B, S, M])
	var ids: Array[int] = [stars[2].id, stars[0].id, stars[1].id]
	assert_eq(run.link(ids), "sequence")
	assert_eq(run.light, 25)
	assert_eq(run.dust, 3)
	assert_eq(run.stars.size(), 0)


func _assert_rejected_and_nothing_used(ids: Array[int]) -> void:
	var before_ids: Array[int] = Fixtures.ids(run.stars)
	var dust: int = run.dust
	var light: int = run.light
	assert_eq(run.link(ids), Combos.INVALID)
	assert_eq(Fixtures.ids(run.stars), before_ids, "no star used up")
	assert_eq(run.dust, dust)
	assert_eq(run.light, light)
	assert_signal_emitted(run, "link_rejected")
	assert_signal_not_emitted(run, "combo_collected")


func test_invalid_combination_uses_nothing() -> void:
	var stars: Array[Star] = _add([S, S, M])
	_assert_rejected_and_nothing_used(Fixtures.ids(stars))


func test_link_of_two_stars_uses_nothing() -> void:
	var stars: Array[Star] = _add([S, S, S])
	_assert_rejected_and_nothing_used([stars[0].id, stars[1].id])


func test_link_of_four_stars_uses_nothing() -> void:
	var stars: Array[Star] = _add([S, S, S, S])
	_assert_rejected_and_nothing_used(Fixtures.ids(stars))


func test_same_star_twice_uses_nothing() -> void:
	var stars: Array[Star] = _add([S, S, S])
	_assert_rejected_and_nothing_used([stars[0].id, stars[0].id, stars[1].id])


func test_unknown_star_uses_nothing() -> void:
	var stars: Array[Star] = _add([S, S])
	_assert_rejected_and_nothing_used([stars[0].id, stars[1].id, 999])


# --- Big Bang -----------------------------------------------------------------

func test_big_bang_clears_sky_and_pays_dust_per_star() -> void:
	_add([S, M, M, B, B])
	run.light = 30
	run.force_next_big_bang = true
	run.launch(MID)
	assert_eq(run.stars.size(), 0, "every star cleared")
	assert_eq(run.dust, 8 + 2 * 5)
	assert_eq(run.light, 30, "no light gained, earned light kept")
	assert_signal_emitted(run, "big_bang_started")
	assert_signal_not_emitted(run, "pack_burst")
	var params: Array = get_signal_parameters(run, "big_bang_started")
	assert_eq((params[1] as Array).size(), 5)
	assert_eq(params[2], 18)


func test_big_bang_with_empty_sky_pays_base_dust() -> void:
	run.force_next_big_bang = true
	run.launch(MID)
	assert_eq(run.dust, 8)
	assert_eq(run.stars.size(), 0)


func test_big_bang_uses_up_the_pack() -> void:
	run.force_next_big_bang = true
	run.launch(MID)
	assert_eq(run.owned_packs["blue"], 1)


func test_forced_big_bang_only_applies_once() -> void:
	run.force_next_big_bang = true
	run.launch(MID)
	assert_false(run.force_next_big_bang)
	run.launch(MID)
	assert_eq(run.stars.size(), 3)


func test_big_bang_rolls_from_balance_chance() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 1.0
	var state := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY)
	state.launch(MID)
	assert_eq(state.stars.size(), 0)
	assert_eq(state.dust, 8)


# --- win ----------------------------------------------------------------------

func test_reaching_sun_target_wins() -> void:
	run.light = 75
	run.link(Fixtures.ids(_add([S, M, B])))
	assert_eq(run.light, 100)
	assert_eq(run.outcome, RunState.Outcome.WON)
	assert_signal_emit_count(run, "run_won", 1)


func test_overshooting_target_wins() -> void:
	run.light = 99
	run.link(Fixtures.ids(_add([S, S, S])))
	assert_eq(run.outcome, RunState.Outcome.WON)


func test_just_below_target_keeps_playing() -> void:
	run.light = 74
	run.link(Fixtures.ids(_add([S, M, B])))
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_no_actions_after_the_run_ends() -> void:
	run.light = 75
	run.link(Fixtures.ids(_add([S, M, B])))
	run.dust = 100
	var leftover: Array[Star] = _add([S, S, S])
	assert_false(run.buy("blue"))
	assert_false(run.launch(MID))
	assert_eq(run.link(Fixtures.ids(leftover)), Combos.INVALID)
	assert_signal_emit_count(run, "run_won", 1)


# --- loss ---------------------------------------------------------------------

func test_loses_with_no_packs_no_dust_and_no_combo() -> void:
	_no_packs(run)
	var stars: Array[Star] = _add([S, S, S, M])
	run.link(Fixtures.ids(stars.slice(0, 3)))  # 3 dust < 4, leaves one medium
	assert_eq(run.dust, 3)
	assert_eq(run.outcome, RunState.Outcome.LOST)
	assert_signal_emit_count(run, "run_lost", 1)


func test_no_loss_while_a_combo_remains_in_the_sky() -> void:
	# Last pack bursts into a sky that still holds a combo: the run must go on.
	var state: RunState = Fixtures.run({"start_packs": {"blue": 1, "red": 0}})
	watch_signals(state)
	state.add_star(S, MID)
	state.add_star(M, MID)
	state.add_star(B, MID)
	state.force_next_big_bang = false
	state.launch(MID)
	assert_eq(state.total_packs(), 0)
	assert_lt(state.dust, 4)
	assert_true(state.has_remaining_combo())
	assert_eq(state.outcome, RunState.Outcome.PLAYING)
	assert_signal_not_emitted(state, "run_lost")


func test_loss_check_runs_again_after_last_combo_is_used() -> void:
	_no_packs(run)
	var stars: Array[Star] = _add([S, S, S, S, S, S, M])
	run.link(Fixtures.ids(stars.slice(0, 3)))
	assert_eq(run.outcome, RunState.Outcome.PLAYING, "a small triple is still in the sky")
	run.link(Fixtures.ids(stars.slice(3, 6)))
	assert_eq(run.dust, 6, "6 dust buys a blue pack")
	assert_eq(run.outcome, RunState.Outcome.PLAYING, "can still afford a pack")


func test_no_loss_while_dust_buys_a_pack() -> void:
	_no_packs(run)
	run.dust = 1
	var stars: Array[Star] = _add([S, S, S])
	run.link(Fixtures.ids(stars))
	assert_eq(run.dust, 4)
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_no_loss_while_packs_remain() -> void:
	run.owned_packs["blue"] = 0
	run.owned_packs["red"] = 1
	run.loaded_pack = "red"
	var stars: Array[Star] = _add([S, S, S])
	run.link(Fixtures.ids(stars))
	assert_eq(run.outcome, RunState.Outcome.PLAYING)


func test_last_pack_without_combo_or_dust_loses() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["start_packs"] = {"blue": 1, "red": 0}
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["blue"]["stars"] = 2  # two stars can never form a combo
	var state := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY)
	watch_signals(state)
	state.launch(MID)
	assert_eq(state.outcome, RunState.Outcome.LOST)
	assert_signal_emitted(state, "run_lost")


func test_big_bang_on_last_pack_can_save_the_run() -> void:
	var state: RunState = Fixtures.run({"start_packs": {"blue": 1, "red": 0}})
	state.force_next_big_bang = true
	state.launch(MID)
	assert_eq(state.dust, 8, "base dust buys another pack")
	assert_eq(state.outcome, RunState.Outcome.PLAYING)


func test_full_seeded_run_reaches_an_outcome() -> void:
	# Plays a whole run with the simulator's bot policy (best link first, blue only).
	var state: RunState = Fixtures.run({}, 2024)
	var guard: int = 0
	while not state.is_over() and guard < 500:
		guard += 1
		if _link_best(state):
			continue
		if state.total_packs() == 0:
			assert_true(state.buy("blue"), "run should have ended if it can't buy")
		state.launch(MID)
	assert_true(state.is_over(), "run ended within %d steps" % guard)


func _link_best(state: RunState) -> bool:
	var by_size: Array = [[], [], []]
	for star: Star in state.stars:
		by_size[star.size].append(star.id)
	var ids: Array[int] = []
	if not by_size[S].is_empty() and not by_size[M].is_empty() and not by_size[B].is_empty():
		ids = [by_size[S][0], by_size[M][0], by_size[B][0]]
	else:
		for size: int in [B, M, S]:
			if by_size[size].size() >= 3:
				ids.assign(by_size[size].slice(0, 3))
				break
	return not ids.is_empty() and state.link(ids) != Combos.INVALID
