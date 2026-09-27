extends GutTest
## Scorpio (#40): landmarks with sizes, lighting them in combos, strings, the Sun's rekindle,
## and the constellation as the objective.

const Fixtures := preload("res://tests/fixtures.gd")

const SCORPIO := {"enabled": true, "sun_dust_per_star": 1}
## With a reach and the Sun's own target, as the shipped balance has them.
const REACH := 56
const SCORPIO_REACH := {"enabled": true, "sun_dust_per_star": 1, "max_link_distance": REACH, "sun_target": 50}
const SMALL := Star.Size.SMALL
const MEDIUM := Star.Size.MEDIUM
const BIG := Star.Size.BIG

var run: RunState


func before_each() -> void:
	run = _scorpio_run()


func test_the_map_is_off_without_a_scorpio_block_and_on_with_one() -> void:
	assert_null(Fixtures.run().scorpio, "the fixture's balance has no block")
	assert_not_null(run.scorpio)
	var off: Dictionary = SCORPIO.duplicate()
	off["enabled"] = false
	assert_null(_scorpio_run(off).scorpio)


func test_a_bad_scorpio_block_is_a_balance_error() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["scorpio"] = {"enabled": "yes"}
	var balance: Balance = Balance.from_dict(data)
	assert_eq(balance.errors.size(), 2, str(balance.errors))


func test_the_shipped_balance_turns_scorpio_on() -> void:
	var balance: Balance = Balance.load_file()
	assert_true(balance.is_valid(), str(balance.errors))
	assert_true(balance.scorpio_enabled, "on for the playtest; set scorpio.enabled false to play without")


func test_the_map_starts_with_the_head_string_and_six_to_build() -> void:
	assert_eq(Scorpio.LANDMARKS.size(), Scorpio.SIZES.size())
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for landmark: Vector2i in Scorpio.LANDMARKS:
		assert_true(inner.has_point(landmark))
	for size: int in [SMALL, MEDIUM, BIG]:
		assert_true(Scorpio.SIZES.has(size), "every size is on the map")
	assert_eq(run.scorpio.built_count(), 1)
	assert_true(run.scorpio.is_built(0))
	assert_eq(Scorpio.segment_count() - run.scorpio.built_count(), 6)


func test_an_unlit_landmark_stands_in_for_a_star_and_lights_up() -> void:
	# Landmark 2 is small: two sky smalls and it make a small triple.
	var a: Star = run.add_star(SMALL, Vector2i(40, 110))
	var b: Star = run.add_star(SMALL, Vector2i(60, 110))
	var lit: Array[int] = []
	var strings: Array[int] = []
	run.landmark_lit.connect(func(i: int) -> void: lit.append(i))
	run.string_built.connect(func(s: int) -> void: strings.append(s))
	assert_eq(run.link([a.id, Scorpio.landmark_id(2), b.id] as Array[int]), "small_triple")
	assert_eq(lit, [2] as Array[int])
	assert_eq(strings, [1] as Array[int], "landmark 1 was lit: the string 1-2 forms")
	assert_eq([run.dust, run.light], [3, 5], "the combo pays as usual")
	assert_eq(run.stars.size(), 0, "the sky stars are used up")
	assert_true(run.scorpio.is_lit(2), "the landmark stays, lit")


func test_one_landmark_per_combo() -> void:
	# Landmarks 3 (medium) and 4 (small) with a big sky star would be a sequence.
	var big: Star = run.add_star(BIG, Vector2i(40, 110))
	assert_eq(run.link([Scorpio.landmark_id(3), big.id, Scorpio.landmark_id(4)] as Array[int]), Combos.INVALID)
	assert_false(run.scorpio.is_lit(3) or run.scorpio.is_lit(4))
	assert_not_null(run.find_star(big.id), "nothing used up")


func test_a_link_with_no_sky_star_or_a_lit_landmark_is_refused() -> void:
	var rejected: Array[int] = []
	run.link_rejected.connect(func(ids: Array[int]) -> void: rejected.append(ids.size()))
	# Landmarks 2, 4, 6 are all small, but a link needs a sky star.
	assert_eq(run.link([Scorpio.landmark_id(2), Scorpio.landmark_id(4), Scorpio.landmark_id(6)] as Array[int]), Combos.INVALID)
	# Landmark 1 (big) is lit already.
	var b1: Star = run.add_star(BIG, Vector2i(40, 110))
	var b2: Star = run.add_star(BIG, Vector2i(60, 110))
	assert_eq(run.link([b1.id, Scorpio.landmark_id(1), b2.id] as Array[int]), Combos.INVALID)
	assert_eq(rejected, [3, 3])
	assert_eq(run.stars.size(), 2, "nothing used up")
	assert_false(run.scorpio.is_lit(2))


func test_sizes_must_make_a_combo() -> void:
	var s1: Star = run.add_star(SMALL, Vector2i(40, 110))
	var s2: Star = run.add_star(SMALL, Vector2i(60, 110))
	# Landmark 3 is medium: small, small, medium is no combo.
	assert_eq(run.link([s1.id, s2.id, Scorpio.landmark_id(3)] as Array[int]), Combos.INVALID)
	assert_false(run.scorpio.is_lit(3))


func test_lighting_every_landmark_wins() -> void:
	var completed: Array[bool] = []
	run.constellation_completed.connect(func() -> void: completed.append(true))
	for index: int in range(2, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	assert_eq(run.outcome, RunState.Outcome.PLAYING)
	_light(Scorpio.LANDMARKS.size() - 1)
	assert_true(run.scorpio.is_complete())
	assert_eq(run.scorpio.built_count(), Scorpio.segment_count())
	assert_eq(completed, [true])
	assert_eq(run.outcome, RunState.Outcome.WON, "the constellation is the objective")


func test_a_full_sun_rekindles_lights_a_landmark_and_pays_for_the_sky() -> void:
	run.light = 90
	var rekindled: Array = []
	run.sun_rekindled.connect(func(i: int, d: int, p: Array[Vector2i]) -> void: rekindled.append([i, d, p.size()]))
	for x: int in [120, 150]:
		run.add_star(SMALL, Vector2i(x, 240))
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(run.add_star(BIG, Vector2i(x, 100)).id)
	run.link(ids)
	assert_eq(rekindled, [[2, 2, 2]], "landmark 2 grows the lit head; 1 dust for each of the 2 sky stars")
	assert_eq(run.light, 0, "back at 0")
	assert_true(run.scorpio.is_lit(2))
	assert_eq(run.dust, 6 + 2)
	assert_eq(run.stars.size(), 2, "the stars stay in the sky")
	assert_eq(run.outcome, RunState.Outcome.PLAYING, "a full Sun doesn't win here")


func test_the_combo_that_completes_the_constellation_doesnt_rekindle_the_sun() -> void:
	for index: int in range(2, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	run.light = 95
	var rekindled: Array[int] = []
	run.sun_rekindled.connect(func(i: int, _d: int, _p: Array[Vector2i]) -> void: rekindled.append(i))
	_light(Scorpio.LANDMARKS.size() - 1)
	assert_eq(run.outcome, RunState.Outcome.WON)
	assert_eq(rekindled, [] as Array[int], "the win's tune plays, not the Sun")


func test_the_rekindle_lights_next_to_the_lit_chain_first() -> void:
	assert_eq(run.rekindle_target(), 2)
	_light(5)
	run.scorpio.lit[2] = true
	run.scorpio.lit[3] = true
	assert_eq(run.rekindle_target(), 4, "between lit neighbours")


func test_a_combo_takes_nothing_but_its_own_stars() -> void:
	var ids: Array[int] = []
	for x: int in [60, 80, 100]:
		ids.append(run.add_star(SMALL, Vector2i(x, 120)).id)
	var near: Star = run.add_star(BIG, Vector2i(110, 124))
	run.link(ids)
	assert_not_null(run.find_star(near.id), "no sting any more")
	assert_eq(run.dust, 3)


func test_a_normal_run_never_takes_landmarks() -> void:
	var normal: RunState = Fixtures.run()
	var a: Star = normal.add_star(SMALL, Vector2i(20, 100))
	var b: Star = normal.add_star(SMALL, Vector2i(40, 100))
	assert_eq(normal.link([a.id, Scorpio.landmark_id(2), b.id] as Array[int]), Combos.INVALID)


func test_unlit_landmarks_count_for_the_loss_check() -> void:
	for kind: String in run.owned_packs.keys():
		run.owned_packs[kind] = 0
	run.loaded_pack = ""
	run.add_star(SMALL, Vector2i(40, 110))
	run.add_star(SMALL, Vector2i(60, 110))
	assert_false(Combos.has_any(run.sky_sizes()), "the sky alone has no combo")
	assert_true(run.has_remaining_combo(), "but with small landmark 2 it does")


func test_three_unlit_landmarks_dont_count_as_a_remaining_combo() -> void:
	assert_eq(run.stars.size(), 0)
	assert_false(run.has_remaining_combo(), "a link needs a sky star")


func test_the_preview_queries_match_the_link() -> void:
	var a: Star = run.add_star(SMALL, Vector2i(40, 110))
	var b: Star = run.add_star(SMALL, Vector2i(60, 110))
	var ids: Array[int] = [a.id, Scorpio.landmark_id(2), b.id]
	assert_eq(run.combo_for(ids), "small_triple")
	assert_eq(run.strings_for(ids), [1] as Array[int])
	assert_eq(run.stars.size(), 2, "previews change nothing")


func test_a_big_bang_clears_the_sky_but_not_the_constellation() -> void:
	_light(2)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 160))
	assert_eq(run.stars.size(), 0)
	assert_true(run.scorpio.is_lit(2), "lit landmarks stay lit")


func test_bursts_keep_stars_off_the_landmarks() -> void:
	for landmark: Vector2i in Scorpio.LANDMARKS:
		var fresh: RunState = _scorpio_run()
		fresh.owned_packs["red"] = 1
		fresh.load_pack("red")
		fresh.launch(landmark)
		for star: Star in fresh.stars:
			for other: Vector2i in Scorpio.LANDMARKS:
				assert_gte(Vector2(star.position).distance_to(Vector2(other)), StarScatter.LANDMARK_SPACING - 1.0,
					"a burst on %s lands clear of %s" % [landmark, other])


func test_the_shipped_balance_sets_scorpios_reach_and_sun() -> void:
	var balance: Balance = Balance.load_file()
	assert_eq(balance.scorpio_max_link_distance, REACH, "each step of a link at most 56 px")
	assert_eq(balance.scorpio_sun_target, 50, "Scorpio's Sun fills at 50")
	assert_eq(balance.sun_target, 100, "the plain stage keeps its 100")


func test_reach_and_sun_target_must_be_positive_whole_numbers() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "max_link_distance": 0, "sun_target": 12.5}
	var balance: Balance = Balance.from_dict(data)
	assert_eq(balance.errors.size(), 2, str(balance.errors))


func test_without_them_there_is_no_reach_and_the_sun_fills_at_sun_target() -> void:
	assert_eq(run.link_reach(), 0)
	assert_eq(run.light_target(), 100)
	var normal: RunState = Fixtures.run()
	assert_eq(normal.link_reach(), 0, "the plain stage has no reach")
	assert_eq(normal.light_target(), normal.balance.sun_target)


func test_a_link_just_inside_the_reach_is_made() -> void:
	var near: RunState = _scorpio_run(SCORPIO_REACH)
	# Each step exactly 56 px; the whole link is 112 px: the reach is per step, not in total.
	var ids: Array[int] = _row(near, SMALL, [20, 20 + REACH, 20 + 2 * REACH], 100)
	assert_eq(near.link(ids), "small_triple")
	assert_eq(near.stars.size(), 0)


func test_a_link_just_outside_the_reach_uses_nothing() -> void:
	var far: RunState = _scorpio_run(SCORPIO_REACH)
	var rejected: Array = []
	far.link_rejected.connect(func(ids: Array[int]) -> void: rejected.append(ids))
	var ids: Array[int] = _row(far, SMALL, [20, 20 + REACH, 21 + 2 * REACH], 100)
	assert_eq(far.combo_for(ids), Combos.INVALID, "the preview says no combo")
	assert_eq(far.link(ids), Combos.INVALID, "the second step is 57 px")
	assert_eq(rejected, [ids])
	assert_eq(far.stars.size(), 3, "no star used up")
	assert_eq([far.dust, far.light], [0, 0], "no dust, no light")


func test_the_reach_follows_the_order_the_stars_were_picked() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	var ids: Array[int] = _row(r, SMALL, [20, 60, 100], 100)
	# 20 -> 100 is 80 px: out of reach, though 20 -> 60 -> 100 is fine.
	assert_eq(r.link([ids[0], ids[2], ids[1]] as Array[int]), Combos.INVALID)
	assert_eq(r.link(ids), "small_triple")


func test_a_landmark_across_the_map_is_out_of_reach() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	# Two bigs by the head; the stinger (big, landmark 7 at 24,206) is across the sky.
	var ids: Array[int] = _row(r, BIG, [150, 170], 90)
	var link: Array[int] = [ids[0], ids[1], Scorpio.landmark_id(7)]
	assert_eq(r.link(link), Combos.INVALID)
	assert_false(r.scorpio.is_lit(7), "nothing lit")
	assert_eq(r.stars.size(), 2, "nothing used up")
	# Bigs by the stinger reach it.
	var close: Array[int] = _row(r, BIG, [30, 50], 180)
	assert_eq(r.link([close[0], close[1], Scorpio.landmark_id(7)] as Array[int]), "big_triple")
	assert_true(r.scorpio.is_lit(7))


func test_the_loss_check_only_counts_combos_in_reach() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	for kind: String in r.owned_packs.keys():
		r.owned_packs[kind] = 0
	r.loaded_pack = ""
	# Three smalls, each 80 px from the next: a combo by size, but no step order reaches.
	_row(r, SMALL, [10, 90, 170], 90)
	assert_true(Combos.has_any(r.sky_sizes()))
	assert_false(r.has_remaining_combo(), "no link can be made")
	# One more small in the middle of the first two: 10 -> 50 -> 90 reaches.
	r.add_star(SMALL, Vector2i(50, 90))
	assert_true(r.has_remaining_combo())


func test_the_loss_check_counts_a_landmark_in_reach() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	for kind: String in r.owned_packs.keys():
		r.owned_packs[kind] = 0
	r.loaded_pack = ""
	# Two smalls far from every small landmark (2, 4, 6).
	_row(r, SMALL, [150, 170], 250)
	assert_false(r.has_remaining_combo(), "the small landmarks are out of reach")
	var fresh: RunState = _scorpio_run(SCORPIO_REACH)
	# Two smalls by landmark 2 (110, 154).
	_row(fresh, SMALL, [90, 130], 154)
	assert_true(fresh.has_remaining_combo())


func test_scorpios_sun_rekindles_at_its_own_target() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	assert_eq(r.light_target(), 50)
	var rekindled: Array[int] = []
	r.sun_rekindled.connect(func(i: int, _d: int, _p: Array[Vector2i]) -> void: rekindled.append(i))
	r.light = 44
	r.link(_row(r, SMALL, [20, 40, 60], 100))
	assert_eq(r.light, 49, "one short: no rekindle")
	assert_eq(rekindled, [] as Array[int])
	r.link(_row(r, SMALL, [20, 40, 60], 100))
	assert_eq(rekindled, [2], "full at 50: it rekindles and lights landmark 2")
	assert_eq(r.light, 0)


func test_scorpio_completes_with_the_suns_new_target() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	# Only small triples (5 light each), far from the landmarks: every 10 of them fill the Sun,
	# and each rekindle lights a landmark. 6 are unlit, so 60 small triples finish the map.
	var triples: int = 0
	while r.outcome == RunState.Outcome.PLAYING and triples < 100:
		r.link(_row(r, SMALL, [10, 30, 50], 90))
		triples += 1
	assert_eq(r.outcome, RunState.Outcome.WON)
	assert_true(r.scorpio.is_complete())
	assert_eq(triples, 60, "6 rekindles of 50 light each")


## Stars of `size` along row `y`, at the given x, in that order. Returns their ids.
func _row(r: RunState, size: int, xs: Array, y: int) -> Array[int]:
	var ids: Array[int] = []
	for x: int in xs:
		ids.append(r.add_star(size as Star.Size, Vector2i(x, y)).id)
	return ids


func _scorpio_run(scorpio: Dictionary = SCORPIO) -> RunState:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = scorpio
	var balance: Balance = Balance.from_dict(data)
	assert_true(balance.is_valid(), str(balance.errors))
	return RunState.new(balance, Fixtures.rng(), Fixtures.SKY)


## Lights landmark `index` with a triple of its size, far from everything so nothing is stung.
func _light(index: int) -> void:
	var size: int = Scorpio.SIZES[index]
	var a: Star = run.add_star(size as Star.Size, Vector2i(170, 90))
	var b: Star = run.add_star(size as Star.Size, Vector2i(10, 90))
	assert_ne(run.link([a.id, b.id, Scorpio.landmark_id(index)] as Array[int]), Combos.INVALID)
