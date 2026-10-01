extends GutTest
## The red pack's twin burst: one aim, the planet splits into two that burst bursts.burst_spread px
## apart across the aim, stars per burst each. Still one launch: one Big Bang roll (a Big Bang
## splits too, then collapses at the aim), one Orion count, one strike after both bursts.

const Fixtures := preload("res://tests/fixtures.gd")
const TelescopeScene := preload("res://game/scenes/telescope.tscn")
const ORIGIN := Vector2i(80, 300)
const STEP: float = 1.0 / 60.0

var events: Array[Array] = []


func before_each() -> void:
	events.clear()


func test_the_shipped_red_pack_bursts_twice() -> void:
	var red: Balance.PackDef = Balance.load_file(Balance.DEFAULT_PATH).packs["red"]
	assert_eq(red.bursts, 2)
	assert_eq(red.stars, 3, "3 + 3")
	assert_eq(red.cost, 7)
	assert_gt(red.burst_spread, 0)
	var blue: Balance.PackDef = Balance.load_file(Balance.DEFAULT_PATH).packs["blue"]
	assert_eq(blue.bursts, 1, "optional: one burst")


func test_split_points_sit_across_the_aim_and_inside_the_sky() -> void:
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	assert_eq(StarScatter.split_points(Vector2i(90, 150), 44, 2, Fixtures.SKY), [Vector2i(68, 150), Vector2i(112, 150)] as Array[Vector2i])
	for aim: Vector2i in [Vector2i(0, 150), Vector2i(179, 90), Vector2i(-40, 400)]:
		var points: Array[Vector2i] = StarScatter.split_points(aim, 44, 2, Fixtures.SKY)
		assert_eq(points[1].x - points[0].x, 44, "the spread holds at an edge")
		for p: Vector2i in points:
			assert_true(inner.has_point(p))


func test_a_red_launch_splits_then_bursts_twice() -> void:
	var run: RunState = _run()
	_record(run)
	assert_true(run.launch(Vector2i(90, 150)))
	var names: Array = events.map(func(e: Array) -> StringName: return e[0])
	assert_eq(names.slice(0, 4), [&"pack_launched", &"pack_split", &"pack_burst", &"pack_burst"])
	var points: Array = events[1][1][2]
	assert_eq(points.size(), 2)
	for k: int in 2:
		var burst: Array = events[2 + k][1]
		assert_eq(burst[1], points[k], "each burst at its point")
		assert_eq((burst[2] as Array).size(), 3, "3 stars each")
	assert_eq(run.stars.size(), 6)


func test_blue_still_bursts_once() -> void:
	var run: RunState = _run()
	run.load_pack("blue")
	_record(run)
	run.launch(Vector2i(90, 150))
	var names: Array = events.map(func(e: Array) -> StringName: return e[0])
	assert_false(names.has(&"pack_split"))
	assert_eq(names.count(&"pack_burst"), 1)


func test_a_red_big_bang_splits_then_collapses_at_the_aim() -> void:
	var run: RunState = _run()
	_record(run)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	var names: Array = events.map(func(e: Array) -> StringName: return e[0])
	assert_eq(names.slice(0, 3), [&"pack_launched", &"pack_split", &"big_bang_started"], "it opens like any red pack")
	assert_false(names.has(&"pack_burst"))
	assert_eq(events[2][1][0], Vector2i(90, 150), "at the aim")


func test_it_is_one_launch_for_orions_circle() -> void:
	var data: Dictionary = _data()
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["hunt"] = {"radius": 40, "intro_stars": 0}
	data["start_packs"] = {"blue": 0, "red": 3}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.heart())
	run.launch(Vector2i(90, 150))
	_record(run)
	run.launch(Vector2i(90, 150))
	var names: Array = events.map(func(e: Array) -> StringName: return e[0])
	assert_eq(names.count(&"area_struck"), 1, "one strike")
	assert_gt(names.find(&"area_struck"), names.rfind(&"pack_burst"), "after both bursts")


func test_the_twins_dart_apart_and_burst_where_they_land() -> void:
	var run: RunState = _run()
	var sequencer := EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	var scope: Telescope = TelescopeScene.instantiate()
	scope.position = Vector2(ORIGIN)
	add_child_autofree(scope)
	scope.set_process(false)
	scope.setup(run, sequencer)
	scope.aim_at(Vector2i(90, 150))
	assert_eq(scope.burst_points(), StarScatter.split_points(scope.burst_preview(), 44, 2, Fixtures.SKY), "the aim previews both bursts")
	run.launch(scope.burst_preview())
	var most: int = 0
	for frame: int in 240:
		sequencer.advance(STEP)
		scope.advance(STEP)
		most = maxi(most, scope.twins_shown())
	assert_eq(most, 2, "two planets after the split")
	assert_eq(scope.twins_shown(), 0, "both burst")
	assert_false(sequencer.is_busy())


func _record(run: RunState) -> void:
	for info: Dictionary in run.get_script().get_script_signal_list():
		var signal_name: StringName = info["name"]
		run.connect(signal_name, func(...args: Array) -> void: events.append([signal_name, args]))


func _data() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["stars"] = 3
	data["packs"]["red"]["bursts"] = 2
	data["packs"]["red"]["burst_spread"] = 44
	data["start_packs"] = {"blue": 1, "red": 2}
	data["sun_target"] = 100000
	return data


func _run() -> RunState:
	var run := RunState.new(Balance.from_dict(_data()), Fixtures.rng(), Fixtures.SKY)
	run.load_pack("red")
	return run
