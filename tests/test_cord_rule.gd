extends GutTest
## Pisces's cords (chapter 6, a debug trial on the Heart's layout): every successful link leaves its
## string as a cord until the sky is cleared, and a traced link can't cross one. The loss check
## counts only the combos that can still be traced. The fish's cord (StarMap.fish_cord) is in the sky
## from the start, blocks the same way and is never cleared. The link-cord tests run without it
## (_run's `fish`), so the fish's placement can change without moving them.

const Fixtures := preload("res://tests/fixtures.gd")

## A tall sky: the figure sits 114 px lower (Scorpio.shift), leaving the top of the sky out of its
## reach, where the stars below only link with each other.
const TALL_SKY := Rect2i(0, 78, 180, 400)
const SHIFT := Vector2i(0, 114)

## A small triple standing up the middle of the open sky: linked, it ties a cord x = 80, y 90-130.
const CORD_POINTS: Array[Vector2i] = [Vector2i(80, 90), Vector2i(80, 110), Vector2i(80, 130)]
## Two mediums either side of the cord (their step crosses it) and one below it that reaches both.
const LEFT := Vector2i(60, 100)
const RIGHT := Vector2i(100, 100)
const BELOW := Vector2i(84, 150)
## A test fish cord, in home layout: a V knotted at (90, 140), its arms up to the side edges. Shifted
## into TALL_SKY it runs (0, 214) - (90, 254) - (179, 214).
const FISH: Array[Vector2i] = [Vector2i(0, 100), Vector2i(90, 140), Vector2i(179, 100)]
## Three mediums in reach of each other in TALL_SKY: one over the fish's left arm, two under it (out
## of reach of any medium landmark).
const OVER := Vector2i(20, 205)
const UNDER := Vector2i(20, 240)
const UNDER_RIGHT := Vector2i(40, 240)

var tied: Array[Array] = []
var cleared: int = 0


func before_each() -> void:
	tied.clear()
	cleared = 0


func test_only_the_cord_trial_has_cords() -> void:
	var map: StarMap = StarMap.cord_trial()
	assert_eq(map.id, "cord_trial")
	assert_eq(map.title, "CORD")
	assert_true(map.cords)
	assert_false(map.hunt, "no Orion")
	assert_false(map.intros)
	assert_eq(map.landmarks, StarMap.heart().landmarks, "the Heart's layout")
	assert_eq(StarMap.current_layout("cord").id, "cord_trial")
	var off: StarMap = StarMap.current_layout("cord", false)
	assert_eq(off.id, "cord_off")
	assert_eq(off.title, "CORD OFF")
	assert_false(off.cords)
	assert_not_null(_run().cords)
	assert_true(_run().cords.is_empty(), "without the fish's cord, no cord until a link")
	assert_null(_run(false).cords)
	for other: StarMap in [StarMap.heart(), StarMap.black_hole_trial(), StarMap.sagittarius_head()]:
		assert_false(other.cords, other.id)


func test_a_link_crossing_a_cord_is_refused_and_uses_nothing_up() -> void:
	var run: RunState = _run()
	_tie_the_cord(run)
	var left: Star = run.add_star(Star.Size.MEDIUM, LEFT)
	var right: Star = run.add_star(Star.Size.MEDIUM, RIGHT)
	var below: Star = run.add_star(Star.Size.MEDIUM, BELOW)
	var rejected: Array[Array] = []
	run.link_rejected.connect(func(ids: Array[int]) -> void: rejected.append(ids))
	var dust: int = run.dust
	var light: int = run.light
	var ids: Array[int] = [below.id, left.id, right.id]
	assert_true(run.in_reach(left.position, right.position), "in reach: only the cord blocks it")
	assert_false(run.can_step(left.position, right.position))
	assert_eq(run.combo_for(ids), Combos.INVALID)
	assert_eq(run.link(ids), Combos.INVALID)
	assert_eq(rejected, [ids])
	assert_eq(run.stars.size(), 3, "every star kept")
	assert_eq(run.dust, dust)
	assert_eq(run.light, light)
	assert_eq(run.cords.count(), 2, "no cord tied")
	assert_eq(tied.size(), 1)


func test_a_link_ties_its_string_as_a_cord_through_a_shifted_landmark() -> void:
	var run: RunState = _run()
	var landmark: Vector2i = run.scorpio.landmark_position(1)
	assert_eq(landmark, StarMap.heart().landmarks[1] + SHIFT)
	var a: Star = run.add_star(Star.Size.MEDIUM, landmark + Vector2i(-20, -24))
	var b: Star = run.add_star(Star.Size.MEDIUM, landmark + Vector2i(24, -14))
	assert_eq(run.link([a.id, Scorpio.landmark_id(1), b.id] as Array[int]), "medium_triple")
	assert_eq(tied, [[a.position, landmark, b.position]])
	assert_eq(run.cords.segments(), [[a.position, landmark], [landmark, b.position]])


func test_a_trio_blocked_through_one_middle_can_link_through_another() -> void:
	var run: RunState = _run()
	_tie_the_cord(run)
	var left: Star = run.add_star(Star.Size.MEDIUM, LEFT)
	var right: Star = run.add_star(Star.Size.MEDIUM, RIGHT)
	var below: Star = run.add_star(Star.Size.MEDIUM, BELOW)
	assert_true(run.has_remaining_combo())
	assert_eq(run.valid_links(), [[left.id, below.id, right.id]])
	assert_eq(run.valid_links(true), [[left.id, below.id, right.id]], "the only middle that traces")
	assert_eq(run.traceable_orders([left.id, right.id, below.id] as Array[int]), [[left.id, below.id, right.id]])
	assert_eq(run.link_candidates([left.id] as Array[int]), [below.id] as Array[int], "the right one only after the one below")
	assert_eq(run.combo_for([left.id, right.id, below.id] as Array[int]), Combos.INVALID)
	assert_eq(run.link([left.id, below.id, right.id] as Array[int]), "medium_triple")
	assert_eq(run.cords.count(), 4)


func test_without_cords_every_middle_traces() -> void:
	var run: RunState = _run()
	var left: Star = run.add_star(Star.Size.MEDIUM, LEFT)
	var right: Star = run.add_star(Star.Size.MEDIUM, RIGHT)
	var below: Star = run.add_star(Star.Size.MEDIUM, BELOW)
	assert_eq(run.traceable_orders([left.id, right.id, below.id] as Array[int]).size(), 3)
	assert_eq(run.valid_links(true).size(), 3)
	assert_eq(run.valid_links().size(), 1, "once a trio by default")


func test_combos_walled_off_by_a_cord_lose_the_run() -> void:
	var run: RunState = _run(true, {"blue": 0, "red": 0})
	var lost: Array[bool] = []
	run.run_lost.connect(func() -> void: lost.append(true))
	run.add_star(Star.Size.MEDIUM, LEFT)
	run.add_star(Star.Size.MEDIUM, RIGHT)
	# Its step to the left one crosses the cord's lower half.
	run.add_star(Star.Size.MEDIUM, Vector2i(100, 124))
	_tie_the_cord(run)
	assert_false(run.has_remaining_combo(), "every middle crosses the cord")
	assert_eq(run.valid_links(), [])
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust for one, no combo that traces")
	assert_eq(lost.size(), 1)


func test_without_cords_the_same_sky_plays_on() -> void:
	var run: RunState = _run(false, {"blue": 0, "red": 0})
	run.add_star(Star.Size.MEDIUM, LEFT)
	run.add_star(Star.Size.MEDIUM, RIGHT)
	run.add_star(Star.Size.MEDIUM, Vector2i(100, 124))
	_tie_the_cord(run)
	assert_true(tied.is_empty(), "no cord")
	assert_true(run.has_remaining_combo())
	assert_eq(run.outcome, RunState.Outcome.PLAYING)
	assert_eq(run.valid_links(true).size(), 3, "every middle traces")


func test_cords_clear_with_the_sky_when_the_sun_rekindles() -> void:
	var run: RunState = _run()
	_tie_the_cord(run)
	var a: Star = run.add_star(Star.Size.MEDIUM, Vector2i(30, 100))
	var b: Star = run.add_star(Star.Size.MEDIUM, Vector2i(30, 130))
	var c: Star = run.add_star(Star.Size.MEDIUM, Vector2i(50, 150))
	run.add_star(Star.Size.BIG, Vector2i(150, 100))
	run.light = run.light_target() - 1
	var rekindled: Array[int] = []
	run.sun_rekindled.connect(func(index: int) -> void: rekindled.append(index))
	assert_eq(run.link([a.id, b.id, c.id] as Array[int]), "medium_triple")
	assert_eq(rekindled.size(), 1)
	assert_eq(tied.size(), 2, "the rekindling link tied its cord")
	assert_eq(cleared, 1, "then the clear took every cord")
	assert_true(run.cords.is_empty())
	assert_true(run.stars.is_empty())
	assert_true(run.can_step(Vector2i(60, 100), Vector2i(100, 100)))


func test_cords_clear_with_a_big_bang() -> void:
	var run: RunState = _run()
	_tie_the_cord(run)
	run.force_next_big_bang = true
	assert_true(Fixtures.launch(run, Vector2i(90, 200)))
	assert_eq(cleared, 1)
	assert_true(run.cords.is_empty())


func test_cords_clear_with_the_sky_when_the_figure_completes() -> void:
	var run: RunState = _run()
	_tie_the_cord(run)
	for index: int in run.scorpio.map.count():
		if index != 1:
			run.scorpio.light(index)
	var landmark: Vector2i = run.scorpio.landmark_position(1)
	var a: Star = run.add_star(Star.Size.MEDIUM, landmark + Vector2i(-20, -24))
	var b: Star = run.add_star(Star.Size.MEDIUM, landmark + Vector2i(24, -14))
	assert_eq(run.link([a.id, Scorpio.landmark_id(1), b.id] as Array[int]), "medium_triple")
	assert_true(run.scorpio.is_complete())
	assert_eq(tied.size(), 2, "the completing link tied its cord")
	assert_eq(cleared, 1, "then the completion's clear took every cord")
	assert_true(run.cords.is_empty())


func test_cords_clear_before_a_full_gauges_big_bang() -> void:
	var map: StarMap = StarMap.sagittarius_head()
	map.cords = true
	var run: RunState = _borrowed(map)
	var order: Array[String] = []
	run.cords_cleared.connect(func() -> void: order.append("cords_cleared"))
	run.big_bang_started.connect(func(_at: Vector2i, _cleared: Array[Star], _dust: int) -> void: order.append("big_bang_started"))
	_tie_the_cord(run)
	assert_eq(run.cords.count(), 2)
	assert_eq(cleared, 0, "a link that doesn't fill the gauge keeps the cords")
	run.gravity.absorbed = run.gravity.capacity - 10
	var ids: Array[int] = []
	for k: int in 3:
		ids.append(run.add_star(Star.Size.BIG, Vector2i(20 + k * 18, 230)).id)
	assert_true(run.link_fills_gauge(ids))
	assert_eq(run.link(ids), "big_triple")
	assert_eq(cleared, 1)
	assert_true(run.cords.is_empty())
	assert_eq(order, ["cords_cleared", "big_bang_started"] as Array[String], "the views see the clear before the bang")


func test_cords_clear_before_the_twin_holes_merge_bang() -> void:
	var map: StarMap = StarMap.sagittarius_legs()
	map.cords = true
	var run: RunState = _borrowed(map)
	var order: Array[String] = []
	run.cords_cleared.connect(func() -> void: order.append("cords_cleared"))
	run.big_bang_started.connect(func(_at: Vector2i, _cleared: Array[Star], _dust: int) -> void: order.append("big_bang_started"))
	_tie_the_cord(run)
	for launch: int in run.gravity.launches_to_merge():
		assert_eq(cleared, 0, "the cords stay until the holes meet")
		run.load_pack("blue")
		assert_true(run.launch(Vector2i(90, 240)))
	assert_eq(cleared, 1)
	assert_true(run.cords.is_empty())
	assert_eq(order, ["cords_cleared", "big_bang_started"] as Array[String])


func test_launches_and_failed_links_keep_the_cords() -> void:
	var run: RunState = _run()
	_tie_the_cord(run)
	assert_true(Fixtures.launch(run, Vector2i(90, 200)))
	assert_eq(run.cords.count(), 2)
	run.link([1, 2, 3] as Array[int])
	assert_eq(run.cords.count(), 2)
	assert_eq(cleared, 0)


func test_cords_draw_no_random_numbers() -> void:
	for seed_value: int in [1, 7, 42]:
		var on: RunState = _run(true, {"blue": 3, "red": 0}, seed_value)
		var fished: RunState = _run(true, {"blue": 3, "red": 0}, seed_value, true)
		var off: RunState = _run(false, {"blue": 3, "red": 0}, seed_value)
		for run: RunState in [on, fished, off]:
			for point: Vector2i in CORD_POINTS:
				run.add_star(Star.Size.SMALL, point)
			assert_eq(run.link(Fixtures.ids(run.stars)), "small_triple")
			Fixtures.launch(run, Vector2i(60, 200))
			Fixtures.launch(run, Vector2i(120, 260))
		assert_eq(on.cords.count(), 2)
		assert_eq(fished.cords.link_count(), 2)
		assert_gt(fished.cords.fixed_count(), 0, "the trial's fish cord")
		assert_eq(_layout(on), _layout(off), "seed %d: the same stars land" % seed_value)
		assert_eq(_layout(fished), _layout(off), "seed %d: the fish's cord draws nothing either" % seed_value)


func test_the_trial_brings_the_fish_cord_across_the_sky() -> void:
	var map: StarMap = StarMap.cord_trial()
	assert_gt(map.fish_cord.size(), 2, "a V: two arms meeting at Alrescha")
	var home: Rect2i = Scorpio.HOME_SKY
	for point: Vector2i in map.fish_cord:
		assert_true(home.has_point(point), "%s in the home sky" % point)
	for end: Vector2i in [map.fish_cord[0], map.fish_cord[-1]]:
		var on_edge: bool = end.x == home.position.x or end.x == home.end.x - 1 or end.y == home.position.y or end.y == home.end.y - 1
		assert_true(on_edge, "%s: its arms reach the sky's edges" % end)
	assert_true(StarMap.cord_trial(false).fish_cord.is_empty(), "cords off: no fish cord either")
	assert_null(_run(false, {"blue": 3, "red": 0}, 1, true).cords, "nor any cord at all")
	for other: StarMap in [StarMap.heart(), StarMap.black_hole_trial(), StarMap.scorpio()]:
		assert_true(other.fish_cord.is_empty(), other.id)


func test_the_fish_cord_is_in_place_before_any_link_with_the_shift() -> void:
	var run: RunState = _run(true, {"blue": 3, "red": 0}, 1, true)
	var expected: Array[Array] = []
	var home: Array[Vector2i] = StarMap.cord_trial().fish_cord
	for i: int in range(1, home.size()):
		expected.append([home[i - 1] + SHIFT, home[i] + SHIFT] as Array[Vector2i])
	assert_eq(run.scorpio.shift, SHIFT)
	assert_eq(run.cords.segments(), expected)
	assert_eq(run.cords.fixed_count(), expected.size())
	assert_eq(run.cords.link_count(), 0)
	assert_true(tied.is_empty(), "no link tied it")
	var custom: RunState = _run(true, {"blue": 3, "red": 0}, 1, false, FISH)
	assert_eq(custom.cords.fixed_segments(), [[Vector2i(0, 214), Vector2i(90, 254)], [Vector2i(90, 254), Vector2i(179, 214)]])


func test_a_link_step_across_the_fish_cord_is_refused_and_uses_nothing_up() -> void:
	var run: RunState = _run(true, {"blue": 3, "red": 0}, 1, false, FISH)
	var over: Star = run.add_star(Star.Size.MEDIUM, OVER)
	var under: Star = run.add_star(Star.Size.MEDIUM, UNDER)
	var under_right: Star = run.add_star(Star.Size.MEDIUM, UNDER_RIGHT)
	var rejected: Array[Array] = []
	run.link_rejected.connect(func(ids: Array[int]) -> void: rejected.append(ids))
	var dust: int = run.dust
	var light: int = run.light
	assert_true(run.in_reach(OVER, UNDER), "in reach: only the fish's cord blocks it")
	assert_false(run.can_step(OVER, UNDER))
	assert_false(run.can_step(UNDER_RIGHT, OVER))
	assert_true(run.can_step(UNDER, UNDER_RIGHT), "the same side")
	assert_true(run.can_step(Vector2i(90, 254), Vector2i(60, 215)), "from its knot, over the arm: touching")
	var ids: Array[int] = [over.id, under.id, under_right.id]
	assert_true(run.traceable_orders(ids).is_empty(), "every order steps across it")
	assert_false(run.has_remaining_combo())
	assert_eq(run.combo_for(ids), Combos.INVALID)
	assert_eq(run.link(ids), Combos.INVALID)
	assert_eq(rejected, [ids])
	assert_eq(run.stars.size(), 3, "every star kept")
	assert_eq(run.dust, dust)
	assert_eq(run.light, light)
	assert_eq(run.cords.link_count(), 0, "no cord tied")
	assert_true(tied.is_empty())
	var free: RunState = _run()
	var free_ids: Array[int] = []
	for point: Vector2i in [OVER, UNDER, UNDER_RIGHT]:
		free_ids.append(free.add_star(Star.Size.MEDIUM, point).id)
	assert_eq(free.link(free_ids), "medium_triple", "without the fish's cord the same trio links")


func test_combos_walled_off_by_the_fish_cord_lose_the_run() -> void:
	var run: RunState = _run(true, {"blue": 0, "red": 0}, 1, false, FISH)
	for point: Vector2i in [OVER, UNDER, UNDER_RIGHT]:
		run.add_star(Star.Size.MEDIUM, point)
	_tie_the_cord(run)
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust for one, every combo across the fish")
	var free: RunState = _run(true, {"blue": 0, "red": 0})
	for point: Vector2i in [OVER, UNDER, UNDER_RIGHT]:
		free.add_star(Star.Size.MEDIUM, point)
	_tie_the_cord(free)
	assert_eq(free.outcome, RunState.Outcome.PLAYING, "the fish's cord was what walled them")


func test_the_fish_cord_survives_a_rekindle_while_link_cords_clear() -> void:
	var run: RunState = _run(true, {"blue": 3, "red": 0}, 1, false, FISH)
	var fish: Array[Array] = run.cords.fixed_segments()
	_tie_the_cord(run)
	var a: Star = run.add_star(Star.Size.MEDIUM, Vector2i(30, 100))
	var b: Star = run.add_star(Star.Size.MEDIUM, Vector2i(30, 130))
	var c: Star = run.add_star(Star.Size.MEDIUM, Vector2i(50, 150))
	run.light = run.light_target() - 1
	assert_eq(run.link([a.id, b.id, c.id] as Array[int]), "medium_triple")
	assert_eq(cleared, 1, "the links' cords cleared")
	assert_eq(run.cords.link_count(), 0)
	assert_eq(run.cords.segments(), fish, "the fish's cord stays")
	assert_false(run.can_step(OVER, UNDER), "and still blocks")
	assert_true(run.can_step(LEFT, RIGHT), "the link's cord doesn't")


func test_the_fish_cord_survives_a_big_bang_while_link_cords_clear() -> void:
	var run: RunState = _run(true, {"blue": 3, "red": 0}, 1, false, FISH)
	var fish: Array[Array] = run.cords.fixed_segments()
	_tie_the_cord(run)
	run.force_next_big_bang = true
	assert_true(Fixtures.launch(run, Vector2i(90, 200)))
	assert_eq(cleared, 1)
	assert_eq(run.cords.segments(), fish)
	assert_false(run.can_step(OVER, UNDER))


func test_a_clear_with_only_the_fish_cord_left_says_nothing() -> void:
	var run: RunState = _run(true, {"blue": 3, "red": 0}, 1, false, FISH)
	var fish: Array[Array] = run.cords.fixed_segments()
	run.force_next_big_bang = true
	assert_true(Fixtures.launch(run, Vector2i(90, 200)))
	assert_eq(cleared, 0, "no link's cord to clear: no cords_cleared")
	assert_eq(run.cords.segments(), fish)


## The trial in TALL_SKY. `fish`: keep the trial's own fish cord (else none); `fish_cord`, when
## given, replaces it.
func _run(enabled: bool = true, packs: Dictionary = {"blue": 3, "red": 0}, seed_value: int = 1, fish: bool = false, fish_cord: Array[Vector2i] = []) -> RunState:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = packs
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	var map: StarMap = StarMap.cord_trial(enabled)
	if not fish:
		map.fish_cord = [] as Array[Vector2i]
	if not fish_cord.is_empty():
		map.fish_cord = fish_cord
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), TALL_SKY, map)
	run.cord_tied.connect(func(points: Array[Vector2i]) -> void: tied.append(points))
	run.cords_cleared.connect(func() -> void: cleared += 1)
	return run


## A borrowed stage `map` (cords set) on the shipped balance, as tests/test_sagittarius.gd plays it.
func _borrowed(map: StarMap) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(7), Rect2i(0, 78, 180, 172), map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.cord_tied.connect(func(points: Array[Vector2i]) -> void: tied.append(points))
	run.cords_cleared.connect(func() -> void: cleared += 1)
	return run


## Links a small triple up the open sky, tying the cord x = 80, y 90-130 (where cords are on).
func _tie_the_cord(run: RunState) -> void:
	var ids: Array[int] = []
	for point: Vector2i in CORD_POINTS:
		ids.append(run.add_star(Star.Size.SMALL, point).id)
	assert_eq(run.link(ids), "small_triple")


## Every star in the sky as [size, position], for comparing two runs.
func _layout(run: RunState) -> Array:
	var found: Array = []
	for star: Star in run.stars:
		found.append([star.size, star.position])
	return found
