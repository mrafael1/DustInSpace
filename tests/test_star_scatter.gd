extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")


func _assert_all_inside(points: Array[Vector2i], sky: Rect2i, context: String) -> void:
	var inner: Rect2i = StarScatter.inner_rect(sky)
	for p: Vector2i in points:
		if not inner.has_point(p):
			fail_test("%s: %s outside %s" % [context, p, inner])
			return
	pass_test(context)


func test_bursts_near_edges_keep_every_star_inside_the_sky() -> void:
	var sky: Rect2i = Fixtures.SKY
	var targets: Array[Vector2i] = [
		sky.position, Vector2i(sky.end.x - 1, sky.position.y), sky.end - Vector2i.ONE,
		Vector2i(sky.position.x, sky.end.y - 1), Vector2i(0, 160), Vector2i(179, 160),
		Vector2i(90, sky.position.y), Vector2i(90, sky.end.y - 1),
		Vector2i(-50, -50), Vector2i(500, 900), Vector2i(90, 319),
	]
	for target: Vector2i in targets:
		for seed_value: int in 50:
			var points: Array[Vector2i] = StarScatter.place(4, target, sky, [], Fixtures.rng(seed_value))
			_assert_all_inside(points, sky, "burst at %s seed %d" % [target, seed_value])


func test_crowded_sky_still_keeps_stars_inside() -> void:
	var sky: Rect2i = Fixtures.SKY
	var rng: RandomNumberGenerator = Fixtures.rng(5)
	var occupied: Array[Vector2i] = []
	for i: int in 60:
		var placed: Array[Vector2i] = StarScatter.place(4, Vector2i(2, sky.position.y + 2), sky, occupied, rng)
		_assert_all_inside(placed, sky, "crowded corner, burst %d" % i)
		occupied.append_array(placed)


func test_returns_one_position_per_star() -> void:
	assert_eq(StarScatter.place(3, Vector2i(90, 160), Fixtures.SKY, [], Fixtures.rng()).size(), 3)


func test_burst_point_is_clamped_into_sky() -> void:
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	assert_true(inner.has_point(StarScatter.clamp_to_sky(Vector2i(-10, 999), Fixtures.SKY)))
	assert_eq(StarScatter.clamp_to_sky(Vector2i(90, 160), Fixtures.SKY), Vector2i(90, 160), "inside points unchanged")


func test_open_sky_spreads_stars_apart() -> void:
	var points: Array[Vector2i] = StarScatter.place(3, Vector2i(90, 160), Fixtures.SKY, [], Fixtures.rng(2))
	for i: int in points.size():
		for j: int in range(i + 1, points.size()):
			assert_gt(Vector2(points[i]).distance_to(Vector2(points[j])), float(StarScatter.MIN_SPACING) - 2.0)


func test_edge_and_corner_bursts_in_open_sky_keep_stars_apart() -> void:
	var sky: Rect2i = Fixtures.SKY
	var targets: Array[Vector2i] = [
		Vector2i(179, 249), sky.position, Vector2i(sky.end.x - 1, sky.position.y), sky.end - Vector2i.ONE,
		Vector2i(sky.position.x, sky.end.y - 1), Vector2i(0, 160), Vector2i(179, 160),
		Vector2i(90, sky.position.y), Vector2i(90, sky.end.y - 1),
	]
	for target: Vector2i in targets:
		for count: int in [3, 4]:
			for seed_value: int in 50:
				var points: Array[Vector2i] = StarScatter.place(count, target, sky, [], Fixtures.rng(seed_value))
				_assert_spaced(points, "burst at %s count %d seed %d" % [target, count, seed_value])


func _assert_spaced(points: Array[Vector2i], context: String) -> void:
	for i: int in points.size():
		for j: int in range(i + 1, points.size()):
			var d: float = Vector2(points[i]).distance_to(Vector2(points[j]))
			if d < float(StarScatter.MIN_SPACING) - 2.0:
				fail_test("%s: %s and %s only %.1f apart" % [context, points[i], points[j], d])
				return
	pass_test(context)
