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


func test_the_map_starts_with_the_claw_arc_and_eleven_to_build() -> void:
	assert_eq(Scorpio.LANDMARKS.size(), Scorpio.SIZES.size())
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for landmark: Vector2i in Scorpio.LANDMARKS:
		assert_true(inner.has_point(landmark))
	for size: int in [SMALL, MEDIUM, BIG]:
		assert_true(Scorpio.SIZES.has(size), "every size is on the map")
	assert_eq(run.scorpio.built_count(), 2, "the claw arc's two strings")
	assert_true(run.scorpio.is_built(0) and run.scorpio.is_built(1))
	assert_eq(Scorpio.segment_count() - run.scorpio.built_count(), 11)


## #61: the map is Scorpius's usual 14-star figure and keeps its silhouette: the claw arc up on the
## right branching from the head, Antares to its left, a body falling steeply, and a tail that
## curls left along the bottom and hooks back up and to the right at the stinger.
func test_the_map_is_scorpius_with_its_claws_and_hooked_tail() -> void:
	var m: Array[Vector2i] = Scorpio.LANDMARKS
	assert_eq(m.size(), 14, "every star of the figure")
	assert_eq(Scorpio.segment_count(), 13, "joined as a tree: one string fewer than stars")
	assert_eq(Scorpio.neighbours(Scorpio.HEAD).size(), 3, "the head branches: two claws and the body")
	for claw: int in [0, 2]:
		assert_eq(Scorpio.neighbours(claw), [Scorpio.HEAD] as Array[int], "claw %d hangs off the head" % claw)
		assert_gt(m[claw].x, m[Scorpio.ANTARES].x + 30, "the claws are right of the heart")
	assert_lt(m[0].y, m[Scorpio.HEAD].y, "one claw above the head")
	assert_gt(m[2].y, m[Scorpio.HEAD].y, "one below")
	assert_lt(m[Scorpio.ANTARES].x, m[Scorpio.HEAD].x, "Antares left of the head")
	for i: int in range(Scorpio.ANTARES, 8):
		assert_gt(m[i + 1].y, m[i].y, "the body falls from the heart to the tail's bottom (%d)" % i)
	for i: int in range(5, 8):
		var step: Vector2i = m[i + 1] - m[i]
		assert_gt(float(step.y), 2.0 * absi(step.x), "the body falls steeply, near upright (%d)" % i)
	assert_lt(m[10].x, m[8].x - 40, "the tail runs left along the bottom")
	assert_lt(m[13].y, m[11].y - 20, "then hooks back up")
	assert_gt(m[13].x, m[11].x + 30, "and to the right, toward the body")
	assert_eq(Scorpio.SIZES[Scorpio.ANTARES], BIG, "Antares, the brightest, is big")
	assert_eq(Scorpio.SIZES[13], BIG, "so is Shaula, the stinger")
	for pair: Vector2i in Scorpio.SEGMENTS:
		var length: float = Vector2(m[pair.x]).distance_to(Vector2(m[pair.y]))
		assert_between(length, 24.0, 30.0, "string %s is short and even" % pair)
	assert_eq(ConstellationView.song_order().size(), Scorpio.segment_count(), "the completion tune plays every string")


## Each landmark can be picked on its own: no two hit circles overlap.
func test_landmarks_are_far_enough_apart_to_pick() -> void:
	var m: Array[Vector2i] = Scorpio.LANDMARKS
	for i: int in m.size():
		for j: int in range(i + 1, m.size()):
			assert_gt(Vector2(m[i]).distance_to(Vector2(m[j])), 2.0 * SkyView.HIT_RADIUS, "landmarks %d and %d" % [i, j])


## Every landmark still to light can be reached: there is room in the sky for two stars within
## the link reach of it (and of each other), where bursts may land (clear of every landmark).
func test_every_unlit_landmark_has_room_for_a_link_in_reach() -> void:
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for i: int in Scorpio.LANDMARKS.size():
		var room: Array[Vector2i] = []
		for y: int in range(inner.position.y, inner.end.y, 3):
			for x: int in range(inner.position.x, inner.end.x, 3):
				var p := Vector2i(x, y)
				if Vector2(p).distance_to(Vector2(Scorpio.LANDMARKS[i])) > REACH:
					continue
				var clear: bool = true
				for other: Vector2i in Scorpio.LANDMARKS:
					if Vector2(p).distance_to(Vector2(other)) < StarScatter.LANDMARK_SPACING:
						clear = false
				if clear:
					room.append(p)
		var pair: bool = false
		for a: Vector2i in room:
			for b: Vector2i in room:
				var d: float = Vector2(a).distance_to(Vector2(b))
				if d > 2.0 * SkyView.HIT_RADIUS and d <= REACH:
					pair = true
					break
			if pair:
				break
		assert_true(pair, "landmark %d has room for two stars in reach" % i)


## The finished painting stays inside the play sky (paintings: tests/test_paintings.gd).
func test_the_full_map_paints_the_whole_scorpio() -> void:
	assert_eq(StarMap.scorpio().painting, StarMap.FIGURE)


func test_an_unlit_landmark_stands_in_for_a_star_and_lights_up() -> void:
	# Landmark 3 (sigma) is small: two sky smalls and it make a small triple.
	var a: Star = run.add_star(SMALL, Vector2i(40, 110))
	var b: Star = run.add_star(SMALL, Vector2i(60, 110))
	var lit: Array[int] = []
	var strings: Array[int] = []
	run.landmark_lit.connect(func(i: int) -> void: lit.append(i))
	run.string_built.connect(func(s: int) -> void: strings.append(s))
	assert_eq(run.link([a.id, Scorpio.landmark_id(3), b.id] as Array[int]), "small_triple")
	assert_eq(lit, [3] as Array[int])
	assert_eq(strings, [2] as Array[int], "the head was lit: the string head-sigma forms")
	assert_eq([run.dust, run.light], [3, 5], "the combo pays as usual")
	assert_eq(run.stars.size(), 0, "the sky stars are used up")
	assert_true(run.scorpio.is_lit(3), "the landmark stays, lit")


func test_one_landmark_per_combo() -> void:
	# Landmarks 6 (epsilon, medium) and 5 (tau, small) with a big sky star would be a sequence.
	var big: Star = run.add_star(BIG, Vector2i(40, 110))
	assert_eq(run.link([Scorpio.landmark_id(6), big.id, Scorpio.landmark_id(5)] as Array[int]), Combos.INVALID)
	assert_false(run.scorpio.is_lit(6) or run.scorpio.is_lit(5))
	assert_not_null(run.find_star(big.id), "nothing used up")


func test_a_link_with_no_sky_star_or_a_lit_landmark_is_refused() -> void:
	var rejected: Array[int] = []
	run.link_rejected.connect(func(ids: Array[int]) -> void: rejected.append(ids.size()))
	# Landmarks 3, 5, 7 are all small, but a link needs a sky star.
	assert_eq(run.link([Scorpio.landmark_id(3), Scorpio.landmark_id(5), Scorpio.landmark_id(7)] as Array[int]), Combos.INVALID)
	# Landmark 1 (the head, medium) is lit already.
	var m1: Star = run.add_star(MEDIUM, Vector2i(40, 110))
	var m2: Star = run.add_star(MEDIUM, Vector2i(60, 110))
	assert_eq(run.link([m1.id, Scorpio.landmark_id(1), m2.id] as Array[int]), Combos.INVALID)
	assert_eq(rejected, [3, 3])
	assert_eq(run.stars.size(), 2, "nothing used up")
	assert_false(run.scorpio.is_lit(3))


func test_sizes_must_make_a_combo() -> void:
	var s1: Star = run.add_star(SMALL, Vector2i(40, 110))
	var s2: Star = run.add_star(SMALL, Vector2i(60, 110))
	# Landmark 6 (epsilon) is medium: small, small, medium is no combo.
	assert_eq(run.link([s1.id, s2.id, Scorpio.landmark_id(6)] as Array[int]), Combos.INVALID)
	assert_false(run.scorpio.is_lit(6))


func test_lighting_every_landmark_wins() -> void:
	var completed: Array[bool] = []
	run.constellation_completed.connect(func() -> void: completed.append(true))
	for index: int in range(3, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	assert_eq(run.outcome, RunState.Outcome.PLAYING)
	_light(Scorpio.LANDMARKS.size() - 1)
	assert_true(run.scorpio.is_complete())
	assert_eq(run.scorpio.built_count(), Scorpio.segment_count())
	assert_eq(completed, [true])
	assert_eq(run.outcome, RunState.Outcome.WON, "the constellation is the objective")


func test_completing_the_constellation_clears_the_sky_for_nothing() -> void:
	for index: int in range(3, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	var left: Array[int] = []
	for x: int in [40, 60, 80]:
		left.append(run.add_star(SMALL, Vector2i(x, 120)).id)
	var dust: int = run.dust
	var light: int = run.light
	var order: Array[String] = []
	var cleared: Array[int] = []
	run.sky_cleared.connect(func(stars: Array[Star], _d: int) -> void:
		order.append("cleared")
		for star: Star in stars:
			cleared.append(star.id))
	run.constellation_completed.connect(func() -> void: order.append("completed"))
	run.run_won.connect(func() -> void: order.append("won"))
	_light(Scorpio.LANDMARKS.size() - 1)
	assert_eq(cleared, left, "every star still in the sky goes")
	assert_eq(run.stars.size(), 0, "a clean sky")
	assert_eq(order, ["cleared", "completed", "won"] as Array[String])
	var reward: Balance.ComboReward = run.balance.combos["big_triple"]
	assert_eq([run.dust, run.light], [dust + reward.dust, light + reward.light], "only the last combo pays")


func test_a_sun_that_lights_the_last_landmark_completes_and_bursts_the_sky_for_dust() -> void:
	for index: int in range(3, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	var left: Star = run.add_star(MEDIUM, Vector2i(150, 120))
	run.light = run.light_target() - 5
	var order: Array[String] = []
	var rekindle: Array[int] = []
	run.sun_rekindled.connect(func(i: int) -> void:
		order.append("rekindled")
		rekindle.append(i))
	run.landmark_lit.connect(func(_i: int) -> void: order.append("lit"))
	run.sky_cleared.connect(func(_s: Array[Star], _d: int) -> void: order.append("cleared"))
	run.constellation_completed.connect(func() -> void: order.append("completed"))
	run.run_won.connect(func() -> void: order.append("won"))
	var dust: int = run.dust
	var ids: Array[int] = []
	for x: int in [10, 30, 50]:
		ids.append(run.add_star(SMALL, Vector2i(x, 90)).id)
	run.link(ids)
	assert_eq(order, ["rekindled", "lit", "cleared", "completed", "won"] as Array[String])
	assert_eq(rekindle, [Scorpio.LANDMARKS.size() - 1] as Array[int], "the Sun lights the last landmark")
	assert_eq(run.dust, dust + run.balance.combos["small_triple"].dust + 1, "the combo, and 1 for the star the Sun burst")
	assert_null(run.find_star(left.id))
	assert_eq(run.outcome, RunState.Outcome.WON)


func test_an_empty_sky_isnt_cleared() -> void:
	for index: int in range(3, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	var cleared: Array[bool] = []
	run.sky_cleared.connect(func(_s: Array[Star], _d: int) -> void: cleared.append(true))
	_light(Scorpio.LANDMARKS.size() - 1)
	assert_eq(cleared, [] as Array[bool], "nothing to clear, no event")
	assert_eq(run.outcome, RunState.Outcome.WON)


func test_lighting_a_landmark_short_of_the_end_keeps_the_sky() -> void:
	var near: Star = run.add_star(BIG, Vector2i(40, 120))
	var cleared: Array[bool] = []
	run.sky_cleared.connect(func(_s: Array[Star], _d: int) -> void: cleared.append(true))
	_light(3)
	assert_eq(cleared, [] as Array[bool])
	assert_not_null(run.find_star(near.id))


func test_a_full_sun_rekindles_lights_a_landmark_and_bursts_the_sky_for_dust() -> void:
	run.light = 90
	var order: Array[String] = []
	run.sun_rekindled.connect(func(i: int) -> void: order.append("rekindled %d" % i))
	run.landmark_lit.connect(func(i: int) -> void: order.append("lit %d" % i))
	var cleared: Array = []
	run.sky_cleared.connect(func(stars: Array[Star], d: int) -> void:
		order.append("cleared")
		cleared.append([stars.size(), d]))
	for x: int in [120, 150]:
		run.add_star(SMALL, Vector2i(x, 240))
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(run.add_star(BIG, Vector2i(x, 100)).id)
	run.link(ids)
	assert_eq(order, ["rekindled 3", "lit 3", "cleared"] as Array[String], "landmark 3 grows the lit head, then the sky clears")
	assert_eq(cleared, [[2, 2]], "both stars left in the sky, 1 dust each")
	assert_eq(run.light, 0, "back at 0")
	assert_eq(run.dust, 6 + 2, "the combo's dust, and 1 for each of the 2 stars the Sun burst")
	assert_eq(run.stars.size(), 0, "a clean sky")
	assert_eq(run.outcome, RunState.Outcome.PLAYING, "a full Sun doesn't win here")


func test_a_rekindle_on_an_empty_sky_clears_nothing() -> void:
	run.light = 90
	var cleared: Array[bool] = []
	run.sky_cleared.connect(func(_s: Array[Star], _d: int) -> void: cleared.append(true))
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(run.add_star(BIG, Vector2i(x, 100)).id)
	run.link(ids)
	assert_true(run.scorpio.is_lit(3), "it still lights its landmark")
	assert_eq(cleared, [] as Array[bool])


func test_the_combo_that_completes_the_constellation_doesnt_rekindle_the_sun() -> void:
	for index: int in range(3, Scorpio.LANDMARKS.size() - 1):
		_light(index)
	run.light = 95
	var rekindled: Array[int] = []
	run.sun_rekindled.connect(func(i: int) -> void: rekindled.append(i))
	_light(Scorpio.LANDMARKS.size() - 1)
	assert_eq(run.outcome, RunState.Outcome.WON)
	assert_eq(rekindled, [] as Array[int], "the win's tune plays, not the Sun")


func test_the_rekindle_lights_next_to_the_lit_chain_first() -> void:
	assert_eq(run.rekindle_target(), 3, "sigma, next to the lit head")
	_light(6)
	run.scorpio.lit[3] = true
	run.scorpio.lit[4] = true
	assert_eq(run.rekindle_target(), 5, "between lit neighbours")


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
	assert_true(run.has_remaining_combo(), "but with small landmark 3 it does")


func test_three_unlit_landmarks_dont_count_as_a_remaining_combo() -> void:
	assert_eq(run.stars.size(), 0)
	assert_false(run.has_remaining_combo(), "a link needs a sky star")


func test_the_preview_queries_match_the_link() -> void:
	var a: Star = run.add_star(SMALL, Vector2i(40, 110))
	var b: Star = run.add_star(SMALL, Vector2i(60, 110))
	var ids: Array[int] = [a.id, Scorpio.landmark_id(3), b.id]
	assert_eq(run.combo_for(ids), "small_triple")
	assert_eq(run.strings_for(ids), [2] as Array[int])
	assert_eq(run.stars.size(), 2, "previews change nothing")


func test_a_big_bang_clears_the_sky_but_not_the_constellation() -> void:
	_light(3)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 160))
	assert_eq(run.stars.size(), 0)
	assert_true(run.scorpio.is_lit(3), "lit landmarks stay lit")


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
	assert_eq(balance.scorpio_sun_target, 75, "Scorpio's Sun fills at 75")
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
	# Two bigs by the head; the stinger (big, landmark 13 at 52,184) is across the sky.
	var ids: Array[int] = _row(r, BIG, [150, 170], 90)
	var link: Array[int] = [ids[0], ids[1], Scorpio.landmark_id(13)]
	assert_eq(r.link(link), Combos.INVALID)
	assert_false(r.scorpio.is_lit(13), "nothing lit")
	assert_eq(r.stars.size(), 2, "nothing used up")
	# Bigs by the stinger reach it.
	var close: Array[int] = _row(r, BIG, [60, 80], 160)
	assert_eq(r.link([close[0], close[1], Scorpio.landmark_id(13)] as Array[int]), "big_triple")
	assert_true(r.scorpio.is_lit(13))


func test_the_loss_check_only_counts_combos_in_reach() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	for kind: String in r.owned_packs.keys():
		r.owned_packs[kind] = 0
	r.loaded_pack = ""
	# Three mediums, each 80 px from the next (and far from the unlit medium landmarks, epsilon
	# and kappa): a combo by size, but no step order reaches.
	_row(r, MEDIUM, [10, 90, 170], 90)
	assert_true(Combos.has_any(r.sky_sizes()))
	assert_false(r.has_remaining_combo(), "no link can be made")
	# One more medium in the middle of the first two: 10 -> 50 -> 90 reaches.
	r.add_star(MEDIUM, Vector2i(50, 90))
	assert_true(r.has_remaining_combo())


func test_the_loss_check_counts_a_landmark_in_reach() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	for kind: String in r.owned_packs.keys():
		r.owned_packs[kind] = 0
	r.loaded_pack = ""
	# Two smalls far from every unlit small landmark (3, 5, 7, 8, 9, 11).
	_row(r, SMALL, [150, 170], 250)
	assert_false(r.has_remaining_combo(), "the small landmarks are out of reach")
	var fresh: RunState = _scorpio_run(SCORPIO_REACH)
	# Two smalls by landmark 3 (sigma, 134, 122).
	_row(fresh, SMALL, [114, 154], 122)
	assert_true(fresh.has_remaining_combo())


func test_scorpios_sun_rekindles_at_its_own_target() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	assert_eq(r.light_target(), 50)
	var rekindled: Array[int] = []
	r.sun_rekindled.connect(func(i: int) -> void: rekindled.append(i))
	r.light = 44
	r.link(_row(r, SMALL, [20, 40, 60], 100))
	assert_eq(r.light, 49, "one short: no rekindle")
	assert_eq(rekindled, [] as Array[int])
	r.link(_row(r, SMALL, [20, 40, 60], 100))
	assert_eq(rekindled, [3], "full at 50: it rekindles and lights landmark 3")
	assert_eq(r.light, 0)


func test_scorpio_completes_with_the_suns_new_target() -> void:
	var r: RunState = _scorpio_run(SCORPIO_REACH)
	# Only small triples (5 light each), far from the landmarks: every 10 of them fill the Sun,
	# and each rekindle lights a landmark. 11 are unlit, so 110 small triples finish the map.
	var triples: int = 0
	while r.outcome == RunState.Outcome.PLAYING and triples < 200:
		r.link(_row(r, SMALL, [10, 30, 50], 90))
		triples += 1
	assert_eq(r.outcome, RunState.Outcome.WON)
	assert_true(r.scorpio.is_complete())
	assert_eq(triples, 110, "11 rekindles of 50 light each")


func test_a_taller_sky_moves_the_map_up_to_stay_centred() -> void:
	var tall: Rect2i = ScreenZones.play_sky(102)
	assert_eq(tall, Rect2i(0, -24, 180, 274), "the sky grows up by the extra rows")
	var map := Scorpio.new(tall)
	assert_eq(map.shift, Vector2i(0, -51), "half of it: centred")
	var inner: Rect2i = StarScatter.inner_rect(tall)
	for i: int in Scorpio.LANDMARKS.size():
		assert_eq(map.landmark_position(i), Scorpio.LANDMARKS[i] + Vector2i(0, -51))
		assert_true(inner.has_point(map.landmark_position(i)))
	assert_eq(Scorpio.new().shift, Vector2i.ZERO, "a 9:16 sky: the home layout")


func test_on_a_taller_sky_the_rules_use_the_moved_map() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = SCORPIO_REACH
	var r := RunState.new(Balance.from_dict(data), Fixtures.rng(), ScreenZones.play_sky(102))
	var at: Vector2i = r.scorpio.landmark_position(3)
	# Two smalls by where landmark 3 now is (51 px above its home), in reach.
	var ids: Array[int] = _row(r, SMALL, [at.x - 20, at.x + 20], at.y)
	assert_eq(r.link([ids[0], Scorpio.landmark_id(3), ids[1]] as Array[int]), "small_triple")
	assert_true(r.scorpio.is_lit(3))
	r.owned_packs["red"] = 1
	r.load_pack("red")
	r.launch(r.scorpio.landmark_position(4))
	for star: Star in r.stars:
		for p: Vector2i in r.scorpio.landmark_positions():
			assert_gte(Vector2(star.position).distance_to(Vector2(p)), StarScatter.LANDMARK_SPACING - 1.0, "bursts keep off the moved map")


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
