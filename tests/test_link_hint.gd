extends GutTest
## The link hint (playtest feedback): while a link is traced, the stars and unlit landmarks that
## could come next and still make a valid combo pulse. Nothing before the first pick. After one
## pick, the stars in its reach that a third star could finish; after two, the stars that finish it.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var run: RunState
var sky: SkyView
var sequencer: EventSequencer
var constellation: ConstellationView


func test_nothing_is_hinted_before_the_first_pick_or_after_the_third() -> void:
	var r: RunState = Fixtures.run()
	var a: Star = r.add_star(Star.Size.SMALL, Vector2i(40, 120))
	var b: Star = r.add_star(Star.Size.SMALL, Vector2i(60, 120))
	var c: Star = r.add_star(Star.Size.SMALL, Vector2i(80, 120))
	assert_eq(r.link_candidates([] as Array[int]), [] as Array[int])
	assert_eq(r.link_candidates([a.id, b.id, c.id] as Array[int]), [] as Array[int])


func test_after_one_pick_every_star_that_can_still_make_a_combo() -> void:
	var r: RunState = Fixtures.run()
	var a: Star = r.add_star(Star.Size.SMALL, Vector2i(40, 120))
	var b: Star = r.add_star(Star.Size.SMALL, Vector2i(60, 120))
	var c: Star = r.add_star(Star.Size.SMALL, Vector2i(80, 120))
	var m: Star = r.add_star(Star.Size.MEDIUM, Vector2i(100, 150))
	var big: Star = r.add_star(Star.Size.BIG, Vector2i(120, 180))
	assert_eq(_sorted(r.link_candidates([a.id] as Array[int])), _sorted([b.id, c.id, m.id, big.id]), "a triple or a sequence")
	assert_eq(r.link_candidates([m.id] as Array[int]), [a.id, b.id, c.id, big.id] as Array[int], "a medium only makes a sequence here")


func test_after_two_picks_only_the_stars_that_finish_it() -> void:
	var r: RunState = Fixtures.run()
	var a: Star = r.add_star(Star.Size.SMALL, Vector2i(40, 120))
	var b: Star = r.add_star(Star.Size.SMALL, Vector2i(60, 120))
	var c: Star = r.add_star(Star.Size.SMALL, Vector2i(80, 120))
	var m: Star = r.add_star(Star.Size.MEDIUM, Vector2i(100, 150))
	var big: Star = r.add_star(Star.Size.BIG, Vector2i(120, 180))
	assert_eq(r.link_candidates([a.id, b.id] as Array[int]), [c.id] as Array[int], "the third small")
	assert_eq(r.link_candidates([a.id, m.id] as Array[int]), [big.id] as Array[int], "the missing size")
	var lone: RunState = Fixtures.run()
	var s: Star = lone.add_star(Star.Size.SMALL, Vector2i(40, 120))
	var t: Star = lone.add_star(Star.Size.SMALL, Vector2i(60, 120))
	lone.add_star(Star.Size.MEDIUM, Vector2i(80, 120))
	assert_eq(lone.link_candidates([s.id] as Array[int]), [] as Array[int], "no combo can come of it")
	assert_eq(lone.link_candidates([s.id, t.id] as Array[int]), [] as Array[int])


func test_the_hint_keeps_to_the_reach() -> void:
	var r: RunState = _scorpio_run()
	var a: Star = r.add_star(Star.Size.SMALL, Vector2i(20, 230))
	var near: Star = r.add_star(Star.Size.SMALL, Vector2i(40, 230))
	var far: Star = r.add_star(Star.Size.SMALL, Vector2i(20, 140))
	var third: Star = r.add_star(Star.Size.SMALL, Vector2i(60, 236))
	var next: Array[int] = r.link_candidates([a.id] as Array[int])
	assert_true(next.has(near.id))
	assert_true(next.has(third.id))
	assert_false(next.has(far.id), "out of reach of the first pick")
	assert_false(r.link_candidates([a.id, near.id] as Array[int]).has(far.id), "and of the second")


func test_unlit_landmarks_are_hinted_but_never_a_second_one() -> void:
	var r: RunState = _scorpio_run()
	var index: int = 3
	var at: Vector2i = r.scorpio.landmark_positions()[index]
	var size: Star.Size = r.scorpio.map.sizes[index] as Star.Size
	var a: Star = r.add_star(size, at + Vector2i(-14, 10))
	var b: Star = r.add_star(size, at + Vector2i(14, 10))
	var landmark: int = Scorpio.landmark_id(index)
	assert_true(r.link_candidates([a.id] as Array[int]).has(landmark), "an unlit landmark can come next")
	assert_true(r.link_candidates([a.id, b.id] as Array[int]).has(landmark), "and finish the triple")
	for id: int in r.link_candidates([landmark] as Array[int]):
		assert_false(r.scorpio.is_landmark(id), "one landmark a link")
	r.scorpio.light(index)
	assert_false(r.link_candidates([a.id, b.id] as Array[int]).has(landmark), "a lit landmark is no star to pick")


func test_unknown_ids_and_a_finished_run_hint_nothing() -> void:
	var r: RunState = Fixtures.run()
	var a: Star = r.add_star(Star.Size.SMALL, Vector2i(40, 120))
	r.add_star(Star.Size.SMALL, Vector2i(60, 120))
	r.add_star(Star.Size.SMALL, Vector2i(80, 120))
	assert_eq(r.link_candidates([999] as Array[int]), [] as Array[int])
	assert_false(r.link_candidates([a.id] as Array[int]).is_empty())
	r.outcome = RunState.Outcome.LOST
	assert_eq(r.link_candidates([a.id] as Array[int]), [] as Array[int])


func test_the_sky_pulses_the_hinted_stars_and_clears_after() -> void:
	_start_scene()
	# The lower right: no landmark in reach.
	var a: Star = _star(Star.Size.SMALL, Vector2i(150, 236))
	var b: Star = _star(Star.Size.SMALL, Vector2i(168, 236))
	var c: Star = _star(Star.Size.SMALL, Vector2i(159, 222))
	var off: Star = _star(Star.Size.MEDIUM, Vector2i(140, 210))
	_tap(a.position)
	assert_true(sky.star_view(b.id).hinted)
	assert_true(sky.star_view(c.id).hinted)
	assert_false(sky.star_view(off.id).hinted, "no combo with it")
	assert_false(sky.star_view(a.id).hinted, "the picked star shows its ring, not the hint")
	_tap(b.position)
	assert_true(sky.star_view(c.id).hinted, "the one that finishes it")
	_tap(b.position)
	_tap(Vector2i(150, 120))
	for star: Star in [a, b, c, off]:
		assert_false(sky.star_view(star.id).hinted, "a dropped link hints nothing")
	assert_eq(constellation.hinted(), [] as Array[int])


func test_hinted_stars_pulse_together() -> void:
	_start_scene()
	var a: Star = _star(Star.Size.SMALL, Vector2i(150, 236))
	var b: Star = _star(Star.Size.SMALL, Vector2i(168, 236))
	var c: Star = _star(Star.Size.SMALL, Vector2i(159, 222))
	_tap(a.position)
	var views: Array[StarView] = [sky.star_view(b.id), sky.star_view(c.id)]
	for t: int in 6:
		var keys: Array[bool] = []
		for view: StarView in views:
			view.advance(StarView.HINT_PULSE / 2.0 if t == 0 else StarView.HINT_PULSE)
			keys.append(view.hint_colour() == Palette.C1)
		assert_eq(keys[0], keys[1], "in step")
	for view: StarView in views:
		assert_true(view.shows_hint(), "brackets on every hinted star")
	assert_true(StarView.hint_on(0.0), "lit first")
	assert_false(StarView.hint_on(StarView.HINT_PULSE * 1.5))


func test_a_hinted_landmarks_brackets_pulse_warm() -> void:
	_start_scene()
	var index: int = 7
	var at: Vector2i = run.scorpio.landmark_positions()[index]
	var size: Star.Size = run.scorpio.map.sizes[index] as Star.Size
	var a: Star = _star(size, at + Vector2i(-16, 10))
	_star(size, at + Vector2i(16, 10))
	_tap(a.position)
	assert_true(constellation.hinted().has(index))
	assert_true(constellation.hint_colour() in [Palette.C1, Palette.C3], "warm: you can pick it")


func _start_scene() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	sequencer = main.get_node("EventSequencer")
	constellation = main.get_node("Sky/ConstellationLayer")


func _scorpio_run() -> RunState:
	var data: Dictionary = Fixtures.balance_dict()
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY)


func _star(size: Star.Size, at: Vector2i) -> Star:
	var star: Star = run.add_star(size, at)
	sky.setup(run, sequencer)
	return star


func _sorted(ids: Array[int]) -> Array[int]:
	var copy: Array[int] = ids.duplicate()
	copy.sort()
	return copy


func _tap(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventScreenTouch.new()
		e.position = Vector2(at)
		e.pressed = pressed
		sky.handle_pointer(e)
