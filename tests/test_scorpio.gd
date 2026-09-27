extends GutTest
## Scorpio (#40): landmarks, building segments with a star in the gap, the sting, completion.

const Fixtures := preload("res://tests/fixtures.gd")

const SCORPIO := {"enabled": true, "segment_reach": 10, "sting_reach": 28, "sting_dust": 2, "segment_dust": 2, "completion_light": 45}

var run: RunState


func before_each() -> void:
	run = _scorpio_run()


func test_the_map_is_off_without_a_scorpio_block_and_on_with_one() -> void:
	assert_null(Fixtures.run().scorpio, "the fixture's balance has no block")
	assert_not_null(run.scorpio)
	assert_eq(run.balance.scorpio_sting_dust, 2)
	var off: Dictionary = SCORPIO.duplicate()
	off["enabled"] = false
	assert_null(_scorpio_run(off).scorpio)


func test_a_bad_scorpio_block_is_a_balance_error() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["scorpio"] = {"enabled": "yes", "segment_reach": 0, "sting_reach": 28, "sting_dust": 2}
	var balance: Balance = Balance.from_dict(data)
	assert_false(balance.is_valid())
	assert_eq(balance.errors.size(), 4, str(balance.errors))


func test_the_shipped_balance_turns_scorpio_on() -> void:
	var balance: Balance = Balance.load_file()
	assert_true(balance.is_valid(), str(balance.errors))
	assert_true(balance.scorpio_enabled, "on for the playtest; set scorpio.enabled false to play without")


func test_landmarks_sit_in_the_sky_with_a_star_sized_gap_between_neighbours() -> void:
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for landmark: Vector2i in Scorpio.LANDMARKS:
		assert_true(inner.has_point(landmark), "%s in the sky" % landmark)
	for segment: int in Scorpio.segment_count():
		var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
		var length: float = Vector2(ends[0]).distance_to(Vector2(ends[1]))
		assert_between(length, 2.0 * StarScatter.LANDMARK_SPACING + 4.0, 34.0, "segment %d" % segment)


func test_a_star_is_in_the_gap_near_the_line_between_the_ends() -> void:
	var ends: Array[Vector2i] = Scorpio.segment_ends(0)
	var mid: Vector2i = (ends[0] + ends[1]) / 2
	var normal: Vector2 = Vector2(ends[1] - ends[0]).orthogonal().normalized()
	assert_true(Scorpio.in_gap(0, mid, 10), "on the line")
	assert_true(Scorpio.in_gap(0, mid + Vector2i((normal * 9).round()), 10), "a near miss counts")
	assert_false(Scorpio.in_gap(0, mid + Vector2i((normal * 12).round()), 10), "too far off the line")
	var beyond: Vector2i = ends[0] + (ends[0] - ends[1]) / 3
	assert_false(Scorpio.in_gap(0, beyond, 10), "past the end is no gap")


func test_linking_two_neighbours_and_a_star_in_their_gap_builds_the_segment() -> void:
	var star: Star = _star_in_gap(3)
	var built: Array = []
	run.segment_built.connect(func(segment: int, s: Star, d: int) -> void: built.append([segment, s.id, d]))
	var ids: Array[int] = [Scorpio.landmark_id(4), star.id, Scorpio.landmark_id(3)]
	assert_eq(run.link(ids), RunState.SEGMENT, "any order")
	assert_eq(built, [[3, star.id, 2]])
	assert_true(run.scorpio.is_built(3))
	assert_null(run.find_star(star.id), "the star is used up: it's the bridge now")
	assert_eq(run.scorpio.bridge_positions[3], star.position)
	assert_eq([run.dust, run.light], [2, 0], "a little dust, no light until it's complete")


func test_a_given_segment_cant_be_built() -> void:
	assert_false(Scorpio.is_gap(2))
	var star: Star = _star_in_gap(2)
	assert_eq(run.link([Scorpio.landmark_id(2), star.id, Scorpio.landmark_id(3)] as Array[int]), Combos.INVALID)
	assert_eq(run.bridge_candidates(2), [] as Array[int], "no gap there to bridge")


func test_a_link_that_cant_build_uses_nothing_up() -> void:
	var star: Star = _star_in_gap(1)
	var far: Star = run.add_star(Star.Size.SMALL, Vector2i(20, 100))
	var other: Star = _star_in_gap(5)
	var rejected: Array[int] = []
	run.link_rejected.connect(func(ids: Array[int]) -> void: rejected.append(ids.size()))
	var cases: Array = [
		[Scorpio.landmark_id(1), star.id, Scorpio.landmark_id(3)],  # not neighbours
		[Scorpio.landmark_id(1), far.id, Scorpio.landmark_id(2)],  # star not in the gap
		[Scorpio.landmark_id(1), star.id, other.id],  # one landmark
		[Scorpio.landmark_id(1), Scorpio.landmark_id(2)],  # no star
		[Scorpio.landmark_id(1), star.id, star.id],  # same star twice
	]
	for ids: Array in cases:
		var typed: Array[int] = []
		typed.assign(ids)
		assert_eq(run.link(typed), Combos.INVALID, str(ids))
	assert_eq(rejected.size(), cases.size())
	assert_eq(run.stars.size(), 3, "nothing left the sky")
	assert_eq(run.scorpio.built_count(), 0)


func test_a_built_segment_cant_be_built_again() -> void:
	_build(1)
	var again: Star = _star_in_gap(1)
	assert_eq(run.link([Scorpio.landmark_id(1), again.id, Scorpio.landmark_id(2)] as Array[int]), Combos.INVALID)
	assert_not_null(run.find_star(again.id))


func test_the_last_segment_pours_light_into_the_sun_once() -> void:
	var poured: Array[int] = []
	run.constellation_completed.connect(func(l: int) -> void: poured.append(l))
	for segment: int in Scorpio.GAPS.slice(0, -1):
		_build(segment)
	assert_eq(poured, [] as Array[int])
	_build(Scorpio.GAPS[-1])
	assert_true(run.scorpio.is_complete())
	assert_eq(poured, [45])
	assert_eq(run.light, 45)
	assert_eq(run.dust, 2 * Scorpio.GAPS.size())


func test_completion_can_win_the_run() -> void:
	run.light = 60
	for segment: int in Scorpio.GAPS:
		_build(segment)
	assert_eq(run.outcome, RunState.Outcome.WON)


func test_a_combo_stings_the_nearest_star_in_reach_of_its_last_star() -> void:
	var a: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 120))
	var b: Star = run.add_star(Star.Size.SMALL, Vector2i(80, 120))
	var c: Star = run.add_star(Star.Size.SMALL, Vector2i(100, 120))
	var near: Star = run.add_star(Star.Size.BIG, Vector2i(120, 124))
	var farther: Star = run.add_star(Star.Size.BIG, Vector2i(100, 146))
	var stung: Array = []
	run.star_stung.connect(func(from: Vector2i, t: Star, d: int) -> void: stung.append([from, t.id, d]))
	assert_eq(run.link([a.id, b.id, c.id] as Array[int]), "small_triple")
	assert_eq(stung, [[c.position, near.id, 2]], "from the last star traced, to the nearest")
	assert_null(run.find_star(near.id))
	assert_not_null(run.find_star(farther.id))
	assert_eq(run.dust, 3 + 2, "the combo's dust plus the sting's")


func test_trace_order_picks_where_the_sting_starts() -> void:
	var a: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 120))
	var b: Star = run.add_star(Star.Size.SMALL, Vector2i(80, 120))
	var c: Star = run.add_star(Star.Size.SMALL, Vector2i(100, 120))
	var by_a: Star = run.add_star(Star.Size.BIG, Vector2i(40, 120))
	var by_c: Star = run.add_star(Star.Size.BIG, Vector2i(120, 120))
	assert_eq(run.sting_target(a.position, [a.id, b.id, c.id]), by_a)
	run.link([c.id, b.id, a.id] as Array[int])
	assert_null(run.find_star(by_a.id), "traced ending on a")
	assert_not_null(run.find_star(by_c.id))


func test_no_star_in_reach_no_sting() -> void:
	var a: Star = run.add_star(Star.Size.SMALL, Vector2i(60, 120))
	var b: Star = run.add_star(Star.Size.SMALL, Vector2i(80, 120))
	var c: Star = run.add_star(Star.Size.SMALL, Vector2i(100, 120))
	var out: Star = run.add_star(Star.Size.BIG, Vector2i(100, 150))
	var stung: Array = []
	run.star_stung.connect(func(_f: Vector2i, t: Star, _d: int) -> void: stung.append(t))
	run.link([a.id, b.id, c.id] as Array[int])
	assert_eq(stung, [], "30 px is out of a 28 px reach")
	assert_not_null(run.find_star(out.id))
	assert_eq(run.dust, 3)


func test_equally_near_targets_sting_the_oldest() -> void:
	var first: Star = run.add_star(Star.Size.BIG, Vector2i(100, 100))
	var second: Star = run.add_star(Star.Size.BIG, Vector2i(100, 140))
	assert_eq(run.sting_target(Vector2i(100, 120), []), first)
	assert_ne(first.id, second.id)


func test_a_normal_run_never_stings() -> void:
	var normal: RunState = Fixtures.run()
	var ids: Array[int] = []
	for x: int in [60, 80, 100]:
		ids.append(normal.add_star(Star.Size.SMALL, Vector2i(x, 120)).id)
	var near: Star = normal.add_star(Star.Size.BIG, Vector2i(110, 120))
	normal.link(ids)
	assert_not_null(normal.find_star(near.id))
	assert_eq(normal.dust, 3)


func test_landmarks_are_never_stung_or_part_of_a_combo() -> void:
	var star: Star = _star_in_gap(1)
	assert_null(run.sting_target(Scorpio.LANDMARKS[1], [star.id]), "only sky stars are targets")
	var normal: RunState = Fixtures.run()
	var s: Star = normal.add_star(Star.Size.SMALL, Vector2i(60, 120))
	assert_eq(normal.link([Scorpio.landmark_id(0), s.id, Scorpio.landmark_id(1)] as Array[int]), Combos.INVALID,
		"no landmarks without the map")


func test_bridge_candidates_are_stars_in_a_gap_next_to_the_landmark() -> void:
	var in_gap: Star = _star_in_gap(3)
	run.add_star(Star.Size.SMALL, Vector2i(20, 100))
	assert_eq(run.bridge_candidates(3), [in_gap.id] as Array[int], "segment 3 starts at landmark 3")
	assert_eq(run.bridge_candidates(4), [in_gap.id] as Array[int], "and ends at landmark 4")
	assert_eq(run.bridge_candidates(1), [] as Array[int])
	_build_with(3, in_gap)
	assert_eq(run.bridge_candidates(3), [] as Array[int], "a built segment takes no more")


func test_a_big_bang_clears_the_sky_but_not_the_constellation() -> void:
	_build(1)
	_star_in_gap(3)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 160))
	assert_eq(run.stars.size(), 0)
	assert_true(run.scorpio.is_built(1), "built segments stay lit")


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


func _scorpio_run(scorpio: Dictionary = SCORPIO) -> RunState:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = scorpio
	var balance: Balance = Balance.from_dict(data)
	assert_true(balance.is_valid(), str(balance.errors))
	return RunState.new(balance, Fixtures.rng(), Fixtures.SKY)


## A star at the middle of a segment.
func _star_in_gap(segment: int) -> Star:
	var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
	return run.add_star(Star.Size.SMALL, (ends[0] + ends[1]) / 2)


func _build(segment: int) -> void:
	_build_with(segment, _star_in_gap(segment))


func _build_with(segment: int, star: Star) -> void:
	var ids: Array[int] = [Scorpio.landmark_id(segment), star.id, Scorpio.landmark_id(segment + 1)]
	assert_eq(run.link(ids), RunState.SEGMENT)
