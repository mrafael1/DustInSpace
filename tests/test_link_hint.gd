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


func test_the_sky_hints_the_next_stars_and_clears_after() -> void:
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
		assert_false(sky.star_view(star.id).dimmed, "nor dims anything")
	assert_eq(constellation.hinted(), [] as Array[int])


func test_tracing_dims_the_stars_that_cant_come_next_and_keeps_the_rest() -> void:
	_start_scene()
	var a: Star = _star(Star.Size.SMALL, Vector2i(150, 236))
	var b: Star = _star(Star.Size.SMALL, Vector2i(168, 236))
	_star(Star.Size.SMALL, Vector2i(159, 222))
	var off: Star = _star(Star.Size.MEDIUM, Vector2i(140, 210))
	assert_false(sky.star_view(off.id).dimmed, "nothing dims before the first pick")
	_tap(a.position)
	var next: StarView = sky.star_view(b.id)
	var dim: StarView = sky.star_view(off.id)
	assert_true(dim.dimmed)
	assert_eq(dim.halo_dots(), {} as Dictionary[Vector2i, Color], "a dimmed star loses its halo")
	assert_false(next.dimmed, "a star that can come next stays as it is")
	assert_false(next.halo_dots().is_empty(), "and keeps its halo")
	assert_false(sky.star_view(a.id).dimmed, "the picked star keeps its look")
	var dim_frame: Dictionary[Vector2i, Color] = ConstellationView.star_pixels(Star.Size.MEDIUM, &"dim")
	var idle: Dictionary[Vector2i, Color] = ConstellationView.star_pixels(Star.Size.MEDIUM)
	assert_eq(dim_frame.keys(), idle.keys(), "the same shape")
	assert_ne(dim_frame, idle, "a step darker on its own colours")


func test_hinted_stars_shine_together() -> void:
	_start_scene()
	var a: Star = _star(Star.Size.SMALL, Vector2i(150, 236))
	var b: Star = _star(Star.Size.SMALL, Vector2i(168, 236))
	var c: Star = _star(Star.Size.SMALL, Vector2i(159, 222))
	_tap(a.position)
	var views: Array[StarView] = [sky.star_view(b.id), sky.star_view(c.id)]
	var seen: Dictionary[int, bool] = {}
	for t: int in 12:
		for view: StarView in views:
			view.advance(StarView.SHINE_STEP / 2.0 if t == 0 else StarView.SHINE_STEP)
		assert_eq(views[0].shine(), views[1].shine(), "in step")
		seen[views[0].shine()] = true
	assert_eq(_sorted(seen.keys() as Array[int]), [-1, 0, 1] as Array[int], "shines, fades, rests")
	assert_eq(StarView.shine_stage(0.0), 0, "shines at once")
	assert_eq(StarView.shine_stage(StarView.HINT_PERIOD), 0, "and every period")
	assert_eq(sky.star_view(a.id).shine(), -1, "the picked star doesn't shine")


func test_the_shine_is_rays_from_the_star_tips() -> void:
	for size: Star.Size in [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG]:
		var tip: int = StarView.half_extent(size)
		var long: Dictionary[Vector2i, Color] = StarView.shine_pixels(size, 0)
		assert_eq(long.size(), 4 * StarView.SHINE_RAYS[0])
		assert_eq(long[Vector2i(0, -(tip + 1))], Palette.C0, "white next to the star")
		assert_eq(long[Vector2i(tip + 2, 0)], Palette.C1, "gold beyond")
		assert_eq(StarView.shine_pixels(size, 1).size(), 4 * StarView.SHINE_RAYS[1], "shorter as it fades")
		assert_true(StarView.shine_pixels(size, -1).is_empty())


func test_the_line_to_the_finger_strains_toward_the_reach() -> void:
	assert_eq(LinkLayer.strain_colour(0.5), Palette.C1)
	assert_eq(LinkLayer.strain_colour(LinkLayer.STRAIN_FROM), Palette.C2)
	assert_eq(LinkLayer.strain_colour(LinkLayer.STRAIN_HARD), Palette.C3, "ember at the limit")
	var a := Vector2i(40, 120)
	assert_eq(LinkLayer.reach_part(a, a + Vector2i(30, 0), 56).size(), 31, "all of it in reach")
	var cut: Array[Vector2i] = LinkLayer.reach_part(a, a + Vector2i(80, 0), 56)
	assert_eq(cut[-1], a + Vector2i(56, 0), "past the reach, it stops at the limit")


func test_the_sky_shows_the_reach_on_the_finger_step_only() -> void:
	_start_scene()
	var link_layer: LinkLayer = main.get_node("Sky/LinkLayer")
	var a: Star = _star(Star.Size.SMALL, Vector2i(150, 236))
	_touch(a.position, true)
	_drag(a.position + Vector2i(-50, 0))
	assert_eq(link_layer.get("_reach"), 56, "dragging: the step to the finger strains")
	assert_false(link_layer.is_loose_end())
	_drag(a.position + Vector2i(-70, 0))
	assert_true(link_layer.is_loose_end(), "past the reach: broken")
	_touch(a.position + Vector2i(-70, 0), false)
	assert_eq(link_layer.get("_reach"), 0, "no finger, no strain")


func test_tracing_hides_the_brackets_and_dims_the_landmarks_that_cant_come_next() -> void:
	_start_scene()
	var index: int = 7
	var at: Vector2i = run.scorpio.landmark_positions()[index]
	var size: Star.Size = run.scorpio.map.sizes[index] as Star.Size
	var a: Star = _star(size, at + Vector2i(-16, 10))
	_star(size, at + Vector2i(16, 10))
	var other: int = -1
	for i: int in run.scorpio.map.count():
		if i != index and not run.scorpio.is_lit(i):
			other = i
	assert_true(constellation.shows_cue(index), "brackets before tracing")
	_tap(a.position)
	assert_true(constellation.hinted().has(index))
	assert_false(constellation.hinted().has(other), "out of reach")
	assert_false(constellation.shows_cue(index), "no brackets while tracing")
	assert_false(constellation.shows_cue(other))
	assert_false(constellation.shows_dimmed(index), "it can come next")
	assert_true(constellation.shows_dimmed(other))
	for segment: int in run.scorpio.map.segment_count():
		assert_true(constellation.shows_thin(segment), "the strings thin so the trace reads")
	constellation.show_link_preview([] as Array[int], [0] as Array[int])
	assert_false(constellation.shows_thin(0), "a string the link would form stays bright")
	assert_true(constellation.shows_thin(1))
	_tap(Vector2i(150, 120))
	assert_true(constellation.shows_cue(other), "the brackets come back")
	assert_false(constellation.shows_dimmed(other))
	assert_false(constellation.shows_thin(0), "and the strings")


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


func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	sky.handle_pointer(e)


func _drag(at: Vector2i) -> void:
	var e := InputEventScreenDrag.new()
	e.position = Vector2(at)
	sky.handle_pointer(e)
