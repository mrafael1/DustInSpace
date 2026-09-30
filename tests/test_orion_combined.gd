extends GutTest
## Orion's mark (#64) and volley (#70) on one map, as the Claws (stage 5) are planned to bring them
## (with the hunting area, #71). Tested on the Body with the mark switched on. After a link: the
## combo pays, any Sun clear, then the single arrow, then the volley, then the loss check, then a
## new mark.

const Fixtures := preload("res://tests/fixtures.gd")

## Orion's corner: stars here only link with each other (out of reach of the Body's landmarks).
const CORNER := Vector2i(24, 100)

var events: Array[StringName] = []


func before_each() -> void:
	events.clear()


func test_a_link_that_triggers_both_shoots_first_then_volleys_then_marks() -> void:
	var run: RunState = _combined_run()
	_launch_until_marked(run)
	_add_loose(run, 4)
	run.volley.counted = 2
	var target: Star = run.marked_star()
	var trio: Array[int] = _corner_trio(run)
	assert_true(run.link_shoots(trio))
	assert_true(run.link_fires_volley(trio))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	var marks: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marks.append(star))
	var loose: int = run.stars.size() - 3
	var dust: int = run.dust
	_record(run)
	var combo: String = run.link(trio)
	assert_eq(events, [&"combo_collected", &"star_shot", &"volley_fired", &"volley_counted", &"star_marked"] as Array[StringName])
	assert_eq(shot, [target] as Array[Star], "the arrow takes the mark")
	assert_false(victims.has(target), "the volley never takes the shot star again")
	assert_eq(victims.size(), ceili((loose - 1) / 2.0), "half of what the arrow left")
	assert_eq(run.stars.size(), loose - 1 - victims.size())
	assert_eq(run.dust, dust + run.balance.combos[combo].dust, "only the combo pays")
	assert_eq(marks.size(), 1)
	assert_true(run.stars.has(marks[0]), "the new mark survived both")
	assert_false(victims.has(marks[0]))


func test_rescuing_the_mark_on_a_volley_link() -> void:
	var run: RunState = _combined_run()
	_launch_until_marked(run)
	_add_loose(run, 4)
	run.volley.counted = 2
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	var link: Array[int] = [target.id, a.id, b.id]
	assert_false(run.link_shoots(link), "a link with the mark saves it")
	assert_true(run.link_fires_volley(link), "but still looses the volley")
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	var dust: int = run.dust
	var combo: String = run.link(link)
	assert_ne(combo, Combos.INVALID)
	assert_eq(run.dust, dust + run.balance.combos[combo].dust, "the rescue pays as usual")
	assert_true(shot.is_empty(), "saved: no arrow")
	assert_false(victims.has(target), "a saved star is paid, not hit")
	assert_false(victims.is_empty(), "the volley comes anyway")


func test_saving_the_mark_doesnt_touch_the_countdown() -> void:
	for rescue: bool in [true, false]:
		var run: RunState = _combined_run()
		_launch_until_marked(run)
		var target: Star = run.marked_star()
		var link: Array[int] = _corner_trio(run)
		if rescue:
			link = [target.id, run.add_star(target.size, target.position + Vector2i(6, 0)).id, run.add_star(target.size, target.position + Vector2i(0, 6)).id]
		assert_ne(run.link(link), Combos.INVALID)
		assert_eq(run.volley.links_left(), 2, "rescue %s: one link counted" % rescue)


func test_the_countdown_resets_after_each_volley_and_the_mark_keeps_going() -> void:
	var run: RunState = _combined_run(10)
	_launch_until_marked(run)
	var fired: Array[int] = []
	var link_index: Array[int] = [0]
	run.volley_fired.connect(func(_stars: Array[Star]) -> void: fired.append(link_index[0]))
	var shot: Array[int] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star.id))
	for i: int in 6:
		link_index[0] = i + 1
		_add_loose(run, 2)
		if not run.orion.has_target():
			run.launch(Vector2i(120, 200))
		run.link(_corner_trio(run))
	assert_eq(fired, [3, 6] as Array[int])
	assert_eq(run.volley.links_left(), 3)
	for id: int in shot:
		assert_eq(shot.count(id), 1, "star %d shot once" % id)


func test_every_star_leaves_once_over_many_seeds() -> void:
	for seed_value: int in range(1, 21):
		var run: RunState = _combined_run(10, seed_value)
		var gone: Array[int] = []
		run.star_shot.connect(func(star: Star) -> void: gone.append(star.id))
		run.volley_fired.connect(func(stars: Array[Star]) -> void:
			for star: Star in stars:
				gone.append(star.id))
		run.combo_collected.connect(func(_combo: String, stars: Array[Star], _dust: int, _light: int) -> void:
			for star: Star in stars:
				gone.append(star.id))
		run.star_marked.connect(func(star: Star) -> void:
			assert_false(run.scorpio.is_landmark(star.id), "seed %d: never a landmark" % seed_value)
			assert_true(run.stars.has(star), "seed %d: a star still in the sky" % seed_value))
		for launch: int in 8:
			if run.is_over():
				break
			run.launch(Vector2i(40 + 15 * launch, 120 + 12 * launch))
			_link_any(run)
		for id: int in gone:
			assert_eq(gone.count(id), 1, "seed %d: star %d destroyed or paid once" % [seed_value, id])


func test_the_volley_and_the_arrow_never_hit_landmarks() -> void:
	for seed_value: int in range(1, 11):
		var run: RunState = _combined_run(6, seed_value)
		for launch: int in 3:
			run.launch(Vector2i(60 + 30 * launch, 150))
		run.volley.counted = 2
		var lit: Array[bool] = run.scorpio.lit.duplicate()
		var hit: Array[Star] = []
		run.volley_fired.connect(func(stars: Array[Star]) -> void: hit.append_array(stars))
		run.star_shot.connect(func(star: Star) -> void: hit.append(star))
		run.link(_corner_trio(run))
		assert_false(hit.is_empty(), "seed %d: something was hit" % seed_value)
		for star: Star in hit:
			assert_false(run.scorpio.is_landmark(star.id), "seed %d: never a landmark" % seed_value)
		assert_eq(run.scorpio.lit, lit, "seed %d: the constellation stands" % seed_value)


func test_a_sun_clear_takes_the_mark_and_the_volley_finds_an_empty_sky() -> void:
	var run: RunState = _combined_run()
	_launch_until_marked(run)
	_add_loose(run, 2)
	run.volley.counted = 2
	run.light = run.light_target() - 1
	var trio: Array[int] = _corner_trio(run)
	assert_false(run.link_shoots(trio), "the rekindle clears the sky first")
	assert_true(run.link_fires_volley(trio))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	_record(run)
	run.link(trio)
	assert_true(shot.is_empty(), "nothing to shoot")
	assert_true(victims.is_empty(), "nothing to hit")
	assert_lt(events.find(&"sky_cleared"), events.find(&"volley_fired"))
	assert_false(events.has(&"star_marked"), "nothing to mark")
	assert_eq(run.volley.links_left(), 3, "it still counted")
	run.launch(Vector2i(90, 150))
	assert_true(run.orion.has_target(), "the next burst gets a mark")


func test_a_big_bang_takes_the_mark_without_moving_the_countdown() -> void:
	var run: RunState = _combined_run()
	_launch_until_marked(run)
	run.link(_corner_trio(run))
	var left: int = run.volley.links_left()
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 150))
	assert_true(run.stars.is_empty())
	assert_false(run.orion.has_target(), "the mark went with the sky")
	assert_eq(run.volley.links_left(), left)
	assert_true(shot.is_empty())


func test_a_full_volley_leaves_nothing_to_mark_until_the_next_burst() -> void:
	var data: Dictionary = _balance_dict()
	data["volley"] = {"interval": 2, "fraction": 1.0}
	data["start_packs"] = {"blue": 6, "red": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, _combined_map())
	_launch_until_marked(run)
	run.link(_corner_trio(run))
	assert_false(run.stars.is_empty(), "the first link: only the arrow")
	assert_true(run.orion.has_target(), "and a new mark")
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	var target: Star = run.marked_star()
	run.link(_corner_trio(run))
	assert_eq(shot, [target] as Array[Star], "the second: the arrow takes the mark")
	assert_false(victims.has(target), "the volley doesn't take it again")
	assert_true(run.stars.is_empty(), "then the volley takes every other loose star")
	assert_false(run.orion.has_target())
	run.launch(Vector2i(90, 150))
	assert_true(run.orion.has_target())


func test_a_restart_resets_the_mark_and_the_countdown() -> void:
	var run: RunState = _combined_run()
	_launch_until_marked(run)
	run.link(_corner_trio(run))
	assert_eq(run.volley.links_left(), 2)
	var again: RunState = _combined_run()
	assert_false(again.orion.has_target())
	assert_eq(again.orion.launches, 0)
	assert_eq(again.volley.links_left(), 3)


func test_the_link_that_completes_the_map_skips_both() -> void:
	var run: RunState = _combined_run()
	_launch_until_marked(run)
	var won: Array[bool] = []
	run.run_won.connect(func() -> void: won.append(true))
	var last: int = run.scorpio.map.count() - 1
	for index: int in range(1, run.scorpio.map.count()):
		var size: int = run.scorpio.map.sizes[index]
		var at: Vector2i = run.scorpio.landmark_position(index)
		var a: Star = run.add_star(size as Star.Size, at + Vector2i(-8, 0))
		var b: Star = run.add_star(size as Star.Size, at + Vector2i(0, -8))
		var link: Array[int] = [a.id, b.id, Scorpio.landmark_id(index)]
		if index == last:
			run.volley.counted = run.volley.interval - 1
			run.orion.target = run.add_star(Star.Size.SMALL, CORNER).id
			assert_false(run.link_shoots(link), "the win clears the sky first")
			assert_false(run.link_fires_volley(link), "the last link wins instead")
			_record(run)
		assert_ne(run.link(link), Combos.INVALID, "star %d" % index)
	assert_eq(won, [true])
	assert_false(events.has(&"star_shot"))
	assert_false(events.has(&"volley_fired"))
	assert_false(events.has(&"star_marked"))
	assert_false(run.orion.has_target())


func test_the_loss_check_sees_the_sky_after_the_arrow_and_the_volley() -> void:
	# No pack, no dust. Two mediums and the marked big: linking the corner smalls fills the countdown;
	# the arrow takes the big, the volley one of the two mediums, and nothing can be linked.
	var run: RunState = _stuck_run()
	var mediums: Array[Star] = []
	for offset: Vector2i in [Vector2i(0, 30), Vector2i(10, 30)]:
		mediums.append(run.add_star(Star.Size.MEDIUM, CORNER + offset))
	var big: Star = run.add_star(Star.Size.BIG, CORNER + Vector2i(5, 38))
	var small: Star = run.add_star(Star.Size.SMALL, CORNER + Vector2i(-6, 38))
	run.orion.target = big.id
	run.volley.counted = 2
	var trio: Array[int] = _corner_trio(run)
	assert_true(run.has_remaining_combo())
	_record(run)
	run.link(trio)
	assert_eq(run.outcome, RunState.Outcome.LOST, "no pack, no dust, no combo after both")
	assert_eq(events, [&"combo_collected", &"star_shot", &"volley_fired", &"volley_counted", &"run_lost"] as Array[StringName], "no new mark once lost")
	assert_null(run.find_star(big.id), "the arrow broke the sequence the small, a medium and the big made")
	assert_eq(run.stars.size(), 1, "the volley took two of the three left")
	assert_true(run.stars.has(small) or run.stars.has(mediums[0]) or run.stars.has(mediums[1]))


func test_saving_the_mark_keeps_the_run_alive_between_volleys() -> void:
	# A stuck sky with a sequence that saves the mark, and no volley this link: the arrow has nothing
	# to hit, and the corner smalls are still a combo.
	var run: RunState = _stuck_run()
	var mark: Star = run.add_star(Star.Size.BIG, CORNER + Vector2i(5, 38))
	var medium: Star = run.add_star(Star.Size.MEDIUM, CORNER + Vector2i(10, 30))
	var small: Star = run.add_star(Star.Size.SMALL, CORNER + Vector2i(0, 30))
	run.orion.target = mark.id
	run.volley.counted = 0
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_corner_trio(run)
	run.link([mark.id, medium.id, small.id] as Array[int])
	assert_true(shot.is_empty())
	assert_eq(run.outcome, RunState.Outcome.PLAYING, "the corner smalls are still a combo")
	assert_true(run.orion.has_target(), "a new mark on one of them")


func test_the_same_seed_repeats_the_marks_and_victims_and_packs_never_shift() -> void:
	var picks: Array[Array] = []
	var skies: Array[Array] = []
	for with_threats: bool in [true, true, false]:
		var data: Dictionary = _balance_dict()
		if not with_threats:
			data.erase("volley")
			data.erase("orion")
		data["start_packs"] = {"blue": 6, "red": 0}
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(42), Fixtures.SKY, _combined_map())
		var seen: Array[String] = []
		run.star_marked.connect(func(star: Star) -> void: seen.append("m%d" % star.id))
		run.star_shot.connect(func(star: Star) -> void: seen.append("s%d" % star.id))
		run.volley_fired.connect(func(stars: Array[Star]) -> void:
			for star: Star in stars:
				seen.append("v%d" % star.id))
		var sky: Array[String] = []
		for launch: int in 4:
			run.launch(Vector2i(90, 150))
			for star: Star in run.stars:
				sky.append("%d:%d:%s" % [star.id, star.size, star.position])
			if with_threats:
				run.volley.counted = 2
				run.link(_corner_trio(run))
		picks.append(seen)
		skies.append(sky.slice(0, 3))
	assert_gt(picks[0].size(), 3)
	assert_eq(picks[0], picks[1], "same seed, same marks, shots and victims")
	assert_eq(skies[0], skies[2], "the first burst is the same with or without Orion")


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["volley"] = {"interval": 3, "fraction": 0.5}
	return data


## The Body's map with Orion's single mark switched on too.
func _combined_map() -> StarMap:
	var map: StarMap = StarMap.body()
	map.orion = true
	return map


func _combined_run(packs: int = 6, seed_value: int = 1) -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": packs, "red": 0}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, _combined_map())


## No pack and no dust, with Orion started (so he can mark after a link).
func _stuck_run() -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": 0, "red": 0}
	data["start_dust"] = 0
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, _combined_map())
	run.orion.launches = run.orion.first_mark_launch
	return run


func _launch_until_marked(run: RunState) -> void:
	while not run.orion.has_target():
		assert_true(run.launch(Vector2i(90, 150)))


## `count` loose big stars down the left edge, below Orion's corner and clear of the corner trios.
func _add_loose(run: RunState, count: int) -> void:
	for i: int in count:
		run.add_star(Star.Size.BIG, Vector2i(14 + 12 * (i % 2), 160 + 9 * (i / 2)))


## Three small stars in Orion's corner, a small triple with nothing else in reach. Their ids.
func _corner_trio(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		ids.append(run.add_star(Star.Size.SMALL, CORNER + offset).id)
	return ids


## Links the first valid combo of sky stars, if there is one.
func _link_any(run: RunState) -> void:
	var ids: Array[int] = []
	for star: Star in run.stars:
		ids.append(star.id)
	for a: int in ids.size():
		for b: int in range(a + 1, ids.size()):
			for c: int in range(b + 1, ids.size()):
				var trio: Array[int] = [ids[a], ids[b], ids[c]]
				if run.combo_for(trio) != Combos.INVALID:
					run.link(trio)
					return


func _record(run: RunState) -> void:
	for info: Dictionary in run.get_script().get_script_signal_list():
		var signal_name: StringName = info["name"]
		run.connect(signal_name, func(...args: Array) -> void: events.append(signal_name))
