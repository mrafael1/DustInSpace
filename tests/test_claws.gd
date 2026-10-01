extends GutTest
## The Claws (#74), stage 5: Orion brings all three threats at once. The single mark (a link that
## leaves it behind has it shot), the volley (every few links) and the hunting area (each launch
## strikes the circle). After a link: the combo pays, any Sun clear, the single arrow, the volley,
## the loss check, a new mark. After a launch: the burst, the strike, a new circle, a new mark if
## none stands, the loss check. Links never strike; launches never shoot the mark nor volley.

const Fixtures := preload("res://tests/fixtures.gd")

## Orion's corner: stars here only link with each other, and no circle ever reaches them.
const CORNER := Vector2i(24, 100)
const MID_SKY := Vector2i(100, 150)

var events: Array[StringName] = []


func before_each() -> void:
	events.clear()


func test_the_claws_map() -> void:
	var map: StarMap = StarMap.claws()
	assert_eq(StarMap.by_id("claws").id, "claws")
	assert_eq(map.title, "CLAWS")
	assert_true(map.orion, "the single mark")
	assert_eq(map.volley, "volley", "the volley, with the Body's tuning")
	assert_true(map.hunt, "the hunting area")
	assert_false(map.intros, "each threat was introduced before")
	assert_eq(map.count(), 7)
	assert_eq(map.starting_lit, [0] as Array[int], "six to light")
	assert_eq(map.segment_count(), map.count() - 1, "a tree")
	var head: int = 2
	assert_eq(map.sizes[head], Star.Size.BIG, "Dschubba, the head")
	assert_eq(map.neighbours(head).size(), 3, "the neck and two arms meet at the head")
	assert_eq(map.path(0, 4), [0, 1, 2, 3, 4] as Array[int], "one arm up to beta")
	assert_eq(map.path(0, 6), [0, 1, 2, 5, 6] as Array[int], "the other down to pi")
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(CORNER)), 56.0, "the corner is Orion's")
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 24.0, "stars apart")
	for segment: int in map.segment_count():
		var ends: Array[Vector2i] = map.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 24.0, 40.0)
	assert_eq(ConstellationView.song_order(map).size(), map.segment_count())


func test_the_claws_drawing_opens_a_pincer_past_each_claw() -> void:
	var map: StarMap = StarMap.claws()
	var drawing: Array[Vector2i] = ConstellationView.scorpion_drawing(map)
	assert_gt(drawing.size(), 40, "two pincers and two bulbs")
	for p: Vector2i in drawing:
		assert_true(Scorpio.HOME_SKY.has_point(p))
	for claw: int in [4, 6]:
		var elbow: Vector2 = Vector2(map.landmarks[map.neighbours(claw)[0]])
		var tip := Vector2(map.landmarks[claw])
		var past: int = 0
		for p: Vector2i in drawing:
			if Vector2(p).distance_to(tip) <= 13.0 and (Vector2(p) - tip).dot(tip - elbow) > 0.0:
				past += 1
		assert_gt(past, 8, "a pincer out past landmark %d" % claw)
	var neck: Vector2 = Vector2(map.landmarks[0])
	assert_false(drawing.any(func(p: Vector2i) -> bool: return Vector2(p).distance_to(neck) < 10.0), "nothing past the neck: it joins the Heart")


func test_the_claws_bring_all_three_threats_and_open_without_an_intro() -> void:
	var run: RunState = _claws_run()
	assert_not_null(run.orion)
	assert_not_null(run.volley)
	assert_not_null(run.hunt)
	assert_eq(run.volley.links_left(), 2)
	assert_eq(run.hunt.radius, 40)
	_record(run)
	run.play_volley_intro()
	run.play_hunt_intro()
	assert_true(events.is_empty(), "no intro plays")
	assert_true(run.stars.is_empty())
	assert_false(run.hunt.has_area())
	assert_false(run.orion.has_target())


func test_the_first_launch_marks_a_circle_then_a_star() -> void:
	var run: RunState = _claws_run()
	_record(run)
	run.launch(MID_SKY)
	assert_eq(events.slice(0, 4), [&"pack_launched", &"pack_burst", &"area_marked", &"star_marked"] as Array[StringName])
	assert_true(run.hunt.has_area())
	assert_true(run.orion.has_target())
	assert_eq(run.volley.links_left(), 2, "a launch never counts for the volley")


func test_a_launch_strikes_the_circle_before_any_new_mark_and_never_shoots() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	var target: Star = run.marked_star()
	# Keep the mark out of the circle: this launch's strike can't take it.
	run.hunt.centre = _far_from(target.position)
	_record(run)
	run.launch(Vector2i(60, 200))
	assert_eq(events.slice(0, 4), [&"pack_launched", &"pack_burst", &"area_struck", &"area_marked"] as Array[StringName])
	assert_false(events.has(&"star_shot"), "a launch never fires the single arrow")
	assert_false(events.has(&"volley_fired"), "nor the volley")
	assert_false(events.has(&"star_marked"), "the standing mark stays")
	assert_eq(run.marked_star(), target)


func test_a_marked_star_inside_the_circle_is_struck_and_a_new_mark_follows() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	var target: Star = run.marked_star()
	run.hunt.centre = target.position
	var struck: Array[Star] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: struck.append_array(stars))
	var marks: Array[Star] = []
	run.star_marked.connect(func(star: Star) -> void: marks.append(star))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	_record(run)
	run.launch(_far_from(target.position))
	assert_true(struck.has(target), "the strike takes it")
	assert_false(run.stars.has(target))
	assert_eq(events.find(&"area_struck") < events.find(&"star_marked"), true, "the new mark comes after the strike")
	if run.stars.is_empty():
		assert_true(marks.is_empty(), "nothing left to mark")
	else:
		assert_eq(marks.size(), 1, "a new mark on the same launch")
		assert_ne(marks[0], target)
		assert_true(run.stars.has(marks[0]), "the new mark is a star the strike left")
	# The struck mark doesn't count as left behind: the next link shoots only the new one, if any.
	_corner_trio(run)
	run.link(_corner_ids(run))
	for star: Star in shot:
		assert_ne(star, target, "never shot after it was struck")


func test_links_never_strike_or_move_the_circle() -> void:
	var run: RunState = _claws_run(10)
	run.launch(MID_SKY)
	var centre: Vector2i = run.hunt.centre
	var struck: Array[bool] = []
	run.area_struck.connect(func(_at: Vector2i, _stars: Array[Star]) -> void: struck.append(true))
	for i: int in 3:
		run.link(_corner_trio(run))
		run.link([1, 2, 99] as Array[int])
	assert_true(struck.is_empty())
	assert_eq(run.hunt.centre, centre)
	assert_true(run.hunt.has_area())


func test_a_link_that_leaves_the_mark_and_looses_the_volley() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	run.volley.counted = 1
	var target: Star = run.marked_star()
	var centre: Vector2i = run.hunt.centre
	var trio: Array[int] = _corner_trio(run)
	assert_true(run.link_shoots(trio))
	assert_true(run.link_fires_volley(trio))
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	var loose: int = run.stars.size() - 3
	var dust: int = run.dust
	_record(run)
	var combo: String = run.link(trio)
	assert_eq(events, [&"combo_collected", &"star_shot", &"volley_fired", &"volley_counted"] as Array[StringName], "nothing left to mark")
	assert_eq(shot, [target] as Array[Star])
	assert_false(victims.has(target), "never hit twice")
	assert_eq(victims.size(), loose - 1, "the volley takes the rest of the sky")
	assert_true(run.stars.is_empty())
	assert_eq(run.dust, dust + run.balance.combos[combo].dust, "only the combo pays")
	assert_eq(run.hunt.centre, centre, "the circle waits for the next launch")
	assert_eq(run.volley.links_left(), 2, "the countdown starts again")


func test_rescuing_the_mark_still_counts_for_the_volley() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	var target: Star = run.marked_star()
	var link: Array[int] = [target.id, run.add_star(target.size, target.position + Vector2i(6, 0)).id, run.add_star(target.size, target.position + Vector2i(0, 6)).id]
	assert_false(run.link_shoots(link), "a link with the mark saves it")
	assert_false(run.link_fires_volley(link), "the first link only counts")
	var shot: Array[Star] = []
	run.star_shot.connect(func(star: Star) -> void: shot.append(star))
	assert_ne(run.link(link), Combos.INVALID)
	assert_true(shot.is_empty())
	assert_eq(run.volley.links_left(), 1)


func test_the_countdown_resets_after_each_volley_whatever_the_launches() -> void:
	var run: RunState = _claws_run(10)
	var fired: Array[int] = []
	var link_index: Array[int] = [0]
	run.volley_fired.connect(func(_stars: Array[Star]) -> void: fired.append(link_index[0]))
	for i: int in 6:
		link_index[0] = i + 1
		run.launch(MID_SKY)
		run.link(_corner_trio(run))
	assert_eq(fired, [2, 4, 6] as Array[int], "launches in between don't move it")
	assert_eq(run.volley.links_left(), 2)


func test_a_big_bang_launch_clears_the_mark_and_the_strike_finds_nothing() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	run.force_next_big_bang = true
	var struck: Array[Array] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: struck.append(stars))
	_record(run)
	run.launch(MID_SKY)
	assert_eq(struck.size(), 1)
	assert_true(struck[0].is_empty(), "the sky was cleared first")
	assert_true(events.has(&"area_marked"), "a new circle anyway")
	assert_false(events.has(&"star_marked"), "no star to mark")
	assert_false(run.orion.has_target())
	assert_false(events.has(&"star_shot"))


func test_landmarks_are_never_hit_and_every_star_leaves_once_over_many_seeds() -> void:
	for seed_value: int in range(1, 21):
		var run: RunState = _claws_run(10, seed_value)
		var gone: Array[int] = []
		var take: Callable = func(stars: Array[Star]) -> void:
			for star: Star in stars:
				assert_false(run.scorpio.is_landmark(star.id), "seed %d: never a landmark" % seed_value)
				gone.append(star.id)
		run.star_shot.connect(func(star: Star) -> void: take.call([star] as Array[Star]))
		run.volley_fired.connect(func(stars: Array[Star]) -> void: take.call(stars))
		run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: take.call(stars))
		run.combo_collected.connect(func(_combo: String, stars: Array[Star], _dust: int, _light: int) -> void:
			take.call(stars.filter(func(s: Star) -> bool: return not run.scorpio.is_landmark(s.id))))
		run.sky_cleared.connect(func(stars: Array[Star], _dust: int) -> void: take.call(stars))
		run.star_marked.connect(func(star: Star) -> void:
			assert_false(run.scorpio.is_landmark(star.id), "seed %d: marks a loose star" % seed_value)
			assert_true(run.stars.has(star), "seed %d: a star still in the sky" % seed_value))
		for turn: int in 10:
			if run.is_over():
				break
			run.launch(Vector2i(50 + 9 * turn, 130 + 8 * turn))
			_link_any(run)
			_link_any(run)
		for id: int in gone:
			assert_eq(gone.count(id), 1, "seed %d: star %d left once" % [seed_value, id])
		if run.orion.has_target():
			assert_not_null(run.marked_star(), "seed %d: the mark is always in the sky" % seed_value)


func test_completing_the_claws_skips_every_threat() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	run.volley.counted = 1
	for i: int in 6:
		run.scorpio.light(i)
	var claw := Vector2i(156, 200)
	var a: Star = run.add_star(Star.Size.MEDIUM, claw + Vector2i(-12, 14))
	var b: Star = run.add_star(Star.Size.MEDIUM, claw + Vector2i(4, 18))
	var link: Array[int] = [Scorpio.landmark_id(6), a.id, b.id]
	assert_false(run.link_shoots(link), "the completion clears the sky first")
	assert_false(run.link_fires_volley(link), "the winning link skips the volley")
	_record(run)
	assert_ne(run.link(link), Combos.INVALID)
	assert_true(run.scorpio.is_complete())
	assert_eq(run.outcome, RunState.Outcome.WON)
	for skipped: StringName in [&"star_shot", &"volley_fired", &"star_marked", &"area_struck"]:
		assert_false(events.has(skipped), "%s on the winning link" % skipped)


func test_a_launchs_strike_can_lose_the_run() -> void:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": 2, "red": 0}
	# Two small stars a pack: no combo of their own, and too far from the small landmarks.
	data["packs"]["blue"]["stars"] = 2
	data["packs"]["blue"]["weights"] = {"small": 100, "medium": 0, "big": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.claws())
	run.launch(CORNER)
	_forget_sky(run)
	# The only combo left sits in the circle.
	for offset: Vector2i in [Vector2i(-6, 0), Vector2i(6, 0), Vector2i(0, 6)]:
		run.add_star(Star.Size.MEDIUM, run.hunt.centre + offset)
	assert_true(run.has_remaining_combo())
	_record(run)
	run.launch(CORNER)
	assert_true(events.find(&"area_struck") < events.find(&"run_lost"), "the loss check sees the sky after the strike")
	assert_eq(run.outcome, RunState.Outcome.LOST)


func test_a_volley_can_lose_the_run_and_no_mark_follows() -> void:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": 0, "red": 0}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.claws())
	run.orion.launches = run.orion.first_mark_launch
	run.volley.counted = 1
	var trio: Array[int] = _corner_trio(run)
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		run.add_star(Star.Size.BIG, Vector2i(90, 230) + offset)
	_record(run)
	assert_ne(run.link(trio), Combos.INVALID)
	assert_true(events.has(&"volley_fired"))
	assert_eq(run.outcome, RunState.Outcome.LOST, "the volley took the last combo")
	assert_false(events.has(&"star_marked"), "no mark once the run is over")


func test_a_restart_has_no_mark_no_circle_and_a_full_countdown() -> void:
	var run: RunState = _claws_run()
	run.launch(MID_SKY)
	run.link(_corner_trio(run))
	assert_true(run.hunt.has_area())
	var fresh: RunState = _claws_run()
	assert_false(fresh.hunt.has_area())
	assert_false(fresh.orion.has_target())
	assert_eq(fresh.volley.links_left(), fresh.volley.interval)


func test_the_threats_draw_from_their_own_streams() -> void:
	var skies: Array[Array] = []
	var threats: Array[Array] = []
	for with_threats: bool in [true, true, false]:
		var data: Dictionary = _balance_dict()
		if not with_threats:
			for block: String in ["orion", "volley", "hunt"]:
				data.erase(block)
		data["start_packs"] = {"blue": 6, "red": 0}
		var run := RunState.new(Balance.from_dict(data), Fixtures.rng(42), Fixtures.SKY, StarMap.claws())
		var sky: Array[String] = []
		run.pack_burst.connect(func(_kind: String, _at: Vector2i, stars: Array[Star]) -> void:
			for star: Star in stars:
				sky.append("%d:%s" % [star.size, star.position]))
		var seen: Array[String] = []
		run.area_marked.connect(func(at: Vector2i, _radius: int) -> void: seen.append("area %s" % at))
		run.star_marked.connect(func(star: Star) -> void: seen.append("mark %d" % star.id))
		for launch: int in 4:
			run.launch(Vector2i(50 + 25 * launch, 150))
		skies.append(sky)
		threats.append(seen)
	assert_eq(threats[0], threats[1], "same seed, same circles and marks")
	assert_eq(skies[0].slice(0, 3), skies[2].slice(0, 3), "the first burst is the same with or without the threats")


func test_the_claws_unlock_after_the_heart() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.map_id(4), "claws")
	assert_eq(Chapter.stage_name(4), "CLAWS")
	for stage: int in 3:
		chapter.complete(stage)
	assert_eq(chapter.state(4), Chapter.PointState.LOCKED, "until the Heart is won")
	assert_eq(chapter.complete(3), 4, "winning the Heart opens the Claws")
	assert_eq(chapter.state(4), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.complete(4), Chapter.FINAL, "winning the Claws opens the final")
	var saved := Chapter.new()
	saved.from_save(chapter.to_save())
	assert_true(saved.is_completed(4), "the win is saved")


## The shipped tuning for each threat, without Big Bangs.
func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	data["hunt"] = {"radius": 40, "intro_stars": 3}
	return data


func _claws_run(packs: int = 6, seed_value: int = 1) -> RunState:
	var data: Dictionary = _balance_dict()
	data["start_packs"] = {"blue": packs, "red": 0}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(seed_value), Fixtures.SKY, StarMap.claws())


## A spot in the sky more than a circle's width from `at`.
func _far_from(at: Vector2i) -> Vector2i:
	return Vector2i(140, 210) if at.x < 90 else Vector2i(50, 210)


## Takes every star out of the sky (test setup), and out of Orion's mind.
func _forget_sky(run: RunState) -> void:
	var ids: Array[int] = []
	for star: Star in run.stars:
		ids.append(star.id)
	run.orion.forget(ids)
	run.stars.clear()


## Three small stars in Orion's corner, a small triple with nothing else in reach. Their ids.
func _corner_trio(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		ids.append(run.add_star(Star.Size.SMALL, CORNER + offset).id)
	return ids


## The ids of the sky stars in Orion's corner.
func _corner_ids(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for star: Star in run.stars:
		if Vector2(star.position).distance_to(Vector2(CORNER)) < 12.0:
			ids.append(star.id)
	return ids.slice(0, 3)


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
