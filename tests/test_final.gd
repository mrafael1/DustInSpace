extends GutTest
## The final (stage 6): the full Scorpio as Orion's boss stage. It opens once every part is won,
## brings all three of Orion's threats at once (the mark, the volley, the hunting area), opens with
## his entrance instead of the threats' intros, and its completion paints the Scorpio.

const Fixtures := preload("res://tests/fixtures.gd")

## Orion's corner: no landmark of the final sits in his reach.
const CORNER := Vector2i(24, 100)

var events: Array[StringName] = []


func before_each() -> void:
	events.clear()


func test_the_final_map_keeps_orions_corner_clear() -> void:
	var map: StarMap = StarMap.final()
	assert_eq(StarMap.by_id("final").id, "final")
	for i: int in map.count():
		assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(CORNER)), 56.0, "the corner is Orion's")
	assert_eq(map.painting, StarMap.FIGURE, "the whole painted Scorpio")


func test_a_final_run_brings_every_threat() -> void:
	var run: RunState = _final_run()
	assert_not_null(run.orion, "the single mark")
	assert_not_null(run.volley, "the volley")
	assert_not_null(run.hunt, "the hunting area")
	assert_eq(run.scorpio.unlit_sizes().size(), 11, "eleven stars to light")


func test_the_boss_appears_once_and_changes_nothing() -> void:
	var run: RunState = _final_run()
	_record(run)
	var dust: int = run.dust
	run.play_boss_intro()
	run.play_boss_intro()
	assert_eq(events, [&"boss_appeared"] as Array[StringName], "once")
	assert_eq(run.dust, dust)
	assert_true(run.stars.is_empty())
	assert_false(run.is_over())


func test_the_final_has_no_threat_intros() -> void:
	var run: RunState = _final_run()
	_record(run)
	run.play_boss_intro()
	run.play_volley_intro()
	run.play_hunt_intro()
	assert_eq(events, [&"boss_appeared"] as Array[StringName], "the entrance only")
	assert_true(run.stars.is_empty())


func test_no_entrance_on_other_stages_or_once_play_began() -> void:
	for map: StarMap in [StarMap.claws(), StarMap.scorpio(), StarMap.stinger()]:
		var run := RunState.new(Balance.from_dict(_balance_dict()), Fixtures.rng(), Fixtures.SKY, map)
		_record(run)
		run.play_boss_intro()
		assert_false(events.has(&"boss_appeared"), map.id)
	events.clear()
	var started: RunState = _final_run()
	assert_true(Fixtures.launch(started, Vector2i(100, 150)))
	_record(started)
	started.play_boss_intro()
	assert_false(events.has(&"boss_appeared"), "the sky has stars: play began")


func test_the_threats_run_as_on_the_claws() -> void:
	var run: RunState = _final_run()
	_record(run)
	assert_true(Fixtures.launch(run, Vector2i(100, 150)))
	assert_true(events.has(&"area_marked"), "the first launch marks a circle")
	assert_true(events.has(&"star_marked"), "and a star")


func _record(run: RunState) -> void:
	for info: Dictionary in run.get_script().get_script_signal_list():
		var signal_name: StringName = info["name"]
		run.connect(signal_name, func(...args: Array) -> void: events.append(signal_name))


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	data["hunt"] = {"radius": 40, "intro_stars": 3}
	return data


func _final_run(seed_value: int = 1) -> RunState:
	return RunState.new(Balance.from_dict(_balance_dict()), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.final())
