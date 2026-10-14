extends GutTest
## Pisces's nets: a link's ends knot into the cords in reach, and a loop of cords closed by a knot
## catches the loose stars inside for dust and snaps.

const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
## A column cord at x 20, and a link whose ends stand 8 px right of it, closing a net round (36, 120).
const POST: Array[Vector2i] = [Vector2i(20, 92), Vector2i(20, 120), Vector2i(20, 148)]
const HOOK: Array[Vector2i] = [Vector2i(28, 104), Vector2i(52, 120), Vector2i(28, 136)]
const INSIDE := Vector2i(36, 120)
const OUTSIDE := Vector2i(80, 100)


func test_no_reach_no_knots_and_no_net() -> void:
	var cords := StarCords.new()
	cords.tie(POST)
	assert_null(cords.find_net(HOOK))
	assert_null(cords.tie_net(HOOK))
	assert_true(cords.knots().is_empty())
	assert_eq(cords.link_count(), 4, "both cords stay")


func test_a_link_knotted_at_both_ends_closes_a_net_and_its_cords_snap() -> void:
	var cords := StarCords.new(10)
	cords.tie_net(POST)
	var preview: StarCords.Net = cords.find_net(HOOK)
	assert_not_null(preview)
	assert_eq(cords.link_count(), 2, "finding it changes nothing")
	var net: StarCords.Net = cords.tie_net(HOOK)
	assert_not_null(net)
	assert_eq(net.loop, preview.loop)
	assert_eq(net.loop.slice(0, 3), HOOK, "the loop runs round the new cord first")
	assert_true(net.loop.has(Vector2i(20, 136)) and net.loop.has(Vector2i(20, 104)), "and back along the post between its knots")
	assert_true(Geometry2D.is_point_in_polygon(Vector2(INSIDE), _polygon(net.loop)))
	assert_false(Geometry2D.is_point_in_polygon(Vector2(OUTSIDE), _polygon(net.loop)))
	assert_eq(net.snapped.size(), 4, "both links' cords snap")
	assert_eq(cords.link_count(), 0)
	assert_true(cords.knots().is_empty(), "and their knots")


func test_one_knot_ties_without_closing_and_a_later_link_closes_through_it() -> void:
	var cords := StarCords.new(10)
	cords.tie_net(POST)
	# Only its first end reaches the post: a knot, no net.
	var arm: Array[Vector2i] = [Vector2i(28, 100), Vector2i(60, 96), Vector2i(90, 100)]
	assert_null(cords.tie_net(arm))
	assert_eq(cords.knots().size(), 1)
	assert_eq(cords.link_count(), 4)
	# From under the arm's far end down and back to the post: joined through the arm's knot.
	var close: Array[Vector2i] = [Vector2i(90, 108), Vector2i(60, 150), Vector2i(28, 144)]
	var net: StarCords.Net = cords.tie_net(close)
	assert_not_null(net, "the three cords close a net")
	assert_eq(net.snapped.size(), 6, "all three snap")
	assert_eq(cords.count(), 0)


func test_the_fish_cord_is_a_free_edge_and_never_snaps() -> void:
	var cords := StarCords.new(10)
	cords.tie_fixed([Vector2i(0, 120), Vector2i(179, 120)] as Array[Vector2i])
	var cup: Array[Vector2i] = [Vector2i(60, 128), Vector2i(90, 160), Vector2i(120, 128)]
	var net: StarCords.Net = cords.tie_net(cup)
	assert_not_null(net, "both ends knot into the fish's cord")
	assert_eq(net.snapped.size(), 2, "only the link's own cord snaps")
	assert_eq(cords.fixed_count(), 1, "the fish's stays")
	assert_eq(cords.link_count(), 0)


func test_ends_knotted_into_cords_not_joined_close_nothing() -> void:
	var cords := StarCords.new(10)
	cords.tie_net(POST)
	cords.tie_net([Vector2i(120, 92), Vector2i(120, 120), Vector2i(120, 148)] as Array[Vector2i])
	var bridge: Array[Vector2i] = [Vector2i(28, 120), Vector2i(70, 110), Vector2i(112, 120)]
	assert_null(cords.tie_net(bridge), "two separate posts aren't a loop")
	assert_eq(cords.knots().size(), 2)


func test_a_clear_takes_the_knots_with_the_cords() -> void:
	var cords := StarCords.new(10)
	cords.tie_net(POST)
	cords.tie_net([Vector2i(28, 100), Vector2i(60, 96), Vector2i(90, 100)] as Array[Vector2i])
	cords.clear()
	assert_true(cords.knots().is_empty())
	assert_null(cords.find_net(HOOK))


func test_a_link_that_closes_a_net_catches_the_loose_stars_inside_for_dust() -> void:
	var run: RunState = _run()
	var dust_per_star: int = run.balance.cord_net_dust_per_star
	assert_gt(dust_per_star, 0)
	assert_gt(run.cords.knot_reach, 0, "the Circlet has nets")
	var post: Array[int] = _add(run, POST, Star.Size.SMALL)
	assert_eq(run.link(post), "small_triple")
	var inside: Star = run.add_star(Star.Size.SMALL, INSIDE)
	var outside: Star = run.add_star(Star.Size.SMALL, OUTSIDE)
	var hook: Array[int] = _add(run, HOOK, Star.Size.MEDIUM)
	var preview: StarCords.Net = run.link_net(hook)
	assert_not_null(preview, "the trace can show it")
	assert_eq(run.net_catch(preview.loop, hook), [inside] as Array[Star], "the stars inside, not the link's own")
	var closed: Array = []
	run.net_closed.connect(func(loop: Array[Vector2i], caught: Array[Star], dust: int, snapped: Array[Array]) -> void: closed.append([loop, caught, dust, snapped]))
	var dust: int = run.dust
	assert_eq(run.link(hook), "medium_triple")
	assert_eq(closed.size(), 1)
	assert_eq((closed[0][1] as Array).size(), 1)
	assert_eq(closed[0][2], dust_per_star)
	assert_eq(run.dust, dust + run.balance.combos["medium_triple"].dust + dust_per_star)
	assert_false(run.stars.has(inside), "caught")
	assert_true(run.stars.has(outside), "left")
	assert_eq(run.cords.link_count(), 0, "the net snapped")


func test_without_nets_a_stage_knots_nothing() -> void:
	var map: StarMap = StarMap.pisces_circlet()
	map.nets = false
	var run: RunState = _run(map)
	assert_eq(run.cords.knot_reach, 0)
	_add_link(run, POST, Star.Size.SMALL)
	run.add_star(Star.Size.SMALL, INSIDE)
	var hook: Array[int] = _add(run, HOOK, Star.Size.MEDIUM)
	assert_null(run.link_net(hook))
	run.link(hook)
	assert_eq(run.stars.size(), 1, "nothing caught")


func _run(map: StarMap = StarMap.pisces_circlet()) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(5), SKY, map)
	run.dust = 100
	return run


func _add(run: RunState, points: Array[Vector2i], size: Star.Size) -> Array[int]:
	var ids: Array[int] = []
	for point: Vector2i in points:
		ids.append(run.add_star(size, point).id)
	return ids


func _add_link(run: RunState, points: Array[Vector2i], size: Star.Size) -> void:
	run.link(_add(run, points, size))


func _polygon(loop: Array[Vector2i]) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point: Vector2i in loop:
		polygon.append(Vector2(point))
	return polygon


func test_a_cord_touching_the_way_back_but_off_the_loop_doesnt_snap() -> void:
	var cords := StarCords.new(18)
	cords.tie_fixed([Vector2i(0, 100), Vector2i(100, 100)] as Array[Vector2i])
	# Its middle star stands on the fish's cord (a touch), its ends too far to knot.
	var above: Array[Vector2i] = [Vector2i(40, 75), Vector2i(50, 100), Vector2i(60, 75)]
	assert_null(cords.tie_net(above))
	var net: StarCords.Net = cords.tie_net([Vector2i(30, 110), Vector2i(50, 140), Vector2i(70, 110)] as Array[Vector2i])
	assert_not_null(net)
	assert_eq(net.snapped.size(), 2, "only the closing link's cord")
	assert_eq(cords.link_segments().size(), 2, "the cord above stays")


func test_both_ends_knotted_at_one_point_close_a_net() -> void:
	var cords := StarCords.new(18)
	cords.tie_net([Vector2i(50, 50), Vector2i(100, 100), Vector2i(150, 50)] as Array[Vector2i])
	var net: StarCords.Net = cords.tie_net([Vector2i(90, 112), Vector2i(100, 140), Vector2i(110, 112)] as Array[Vector2i])
	assert_not_null(net, "the link and its two ties close round the corner")
	assert_eq(net.loop.size(), 4)
	assert_eq(net.snapped.size(), 2, "the corner's cord isn't on the loop")


func test_a_star_on_the_nets_edge_isnt_caught() -> void:
	var run: RunState = _run()
	run.link(_add(run, POST, Star.Size.SMALL))
	var on_edge: Star = run.add_star(Star.Size.SMALL, Vector2i(20, 120))
	var inside: Star = run.add_star(Star.Size.SMALL, INSIDE)
	var hook: Array[int] = _add(run, HOOK, Star.Size.MEDIUM)
	var net: StarCords.Net = run.link_net(hook)
	assert_not_null(net)
	assert_eq(run.net_catch(net.loop, hook), [inside] as Array[Star], "the one on the post is on the edge")
	assert_true(run.stars.has(on_edge))


func test_no_net_intro_when_the_hook_cant_knot_at_this_reach() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Balance.DEFAULT_PATH))
	data["cords"]["knot_reach"] = 5
	var balance: Balance = Balance.from_dict(data)
	var run := RunState.new(balance, Fixtures.rng(5), SKY, StarMap.pisces_circlet())
	var placed: Array = []
	run.cord_intro_placed.connect(func(stars: Array[Star]) -> void: placed.append(stars))
	run.play_cord_intro()
	assert_true(placed.is_empty(), "no demo stars left behind")
	assert_true(run.stars.is_empty())
