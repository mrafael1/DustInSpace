extends GutTest
## Scorpio in the scenes: landmarks are pickable, links build and preview, stings and completion
## pay out through particles, and nothing shows without the map.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var run: RunState
var sky: SkyView
var sequencer: EventSequencer
var constellation: ConstellationView


func before_each() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "segment_reach": 10, "sting_reach": 28, "sting_dust": 2, "segment_dust": 2, "completion_light": 45}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	sequencer = main.get_node("EventSequencer")
	constellation = main.get_node("Sky/ConstellationLayer")
	for node: Node in [sequencer, main.get_node("CollectParticles"), main.get_node("Sfx"), constellation]:
		node.set_process(false)


func test_landmarks_are_picked_like_stars() -> void:
	for i: int in Scorpio.LANDMARKS.size():
		assert_eq(sky.star_at(Scorpio.LANDMARKS[i] + Vector2i(3, 2)), Scorpio.landmark_id(i))
	main.start_run(Fixtures.balance())
	assert_eq(sky.star_at(Scorpio.LANDMARKS[0]), 0, "no landmarks without the map")


func test_tapping_landmark_star_landmark_builds_the_segment() -> void:
	var star: Star = _star_in_gap(3)
	for point: Vector2i in [Scorpio.LANDMARKS[3], star.position, Scorpio.LANDMARKS[4]]:
		_tap(point)
	assert_true(run.scorpio.is_built(3))
	_play()
	assert_null(sky.star_view(star.id), "the bridge star's view dissolves into the outline")


func test_dragging_through_them_builds_it_too() -> void:
	var star: Star = _star_in_gap(5)
	_touch(Scorpio.LANDMARKS[5], true)
	for point: Vector2i in [star.position, Scorpio.LANDMARKS[6]]:
		_drag(point)
	_touch(Scorpio.LANDMARKS[6], false)
	assert_true(run.scorpio.is_built(5))


func test_picking_a_landmark_marks_the_stars_that_could_bridge_its_gaps() -> void:
	var star: Star = _star_in_gap(3)
	_star(Vector2i(30, 100))
	_tap(Scorpio.LANDMARKS[4])
	assert_eq(constellation.get("_candidates"), [star.position] as Array[Vector2i])
	assert_eq(constellation.get("_selected_landmarks"), [4] as Array[int])
	_tap(star.position)
	assert_eq(constellation.get("_preview_segment"), 3, "the segment it would build")


func test_three_picks_that_build_nothing_show_the_no_combo_cross() -> void:
	var star: Star = _star_in_gap(3)
	_tap(Scorpio.LANDMARKS[3])
	_tap(star.position)
	_touch(Scorpio.LANDMARKS[6], true)
	var plaque: RewardPlaque = main.get_node("Sky/UILayer/RewardPlaque")
	assert_true(plaque.visible, "shown while the third pick is held")
	_touch(Scorpio.LANDMARKS[5], false)
	assert_false(run.scorpio.is_built(3), "not neighbours: nothing built")
	assert_not_null(run.find_star(star.id), "and nothing used up")


func test_a_valid_combo_previews_its_sting() -> void:
	var ids: Array[int] = []
	for x: int in [40, 60, 80]:
		ids.append(_star(Vector2i(x, 110)).id)
	var target: Star = _star(Vector2i(96, 118))
	for id: int in ids:
		_tap_hold(run.find_star(id).position, id == ids[-1])
	assert_true(constellation.get("_sting_shown"))
	assert_true(constellation.get("_sting_has_target"))
	assert_eq(constellation.get("_sting_to"), target.position)


func test_a_sting_pays_dust_through_particles_and_the_counter_catches_up() -> void:
	var ids: Array[int] = []
	for x: int in [40, 60, 80]:
		ids.append(_star(Vector2i(x, 110)).id)
	_star(Vector2i(96, 118))
	run.link(ids)
	_play()
	var particles: CollectParticles = main.get_node("CollectParticles")
	assert_eq(particles.in_flight(CollectParticles.Kind.DUST), 3 + 2, "the combo's and the sting's")
	particles.advance(5.0)
	assert_eq((main.get_node("HUD/Dust") as Label).text, "%d" % run.dust)


func test_completion_runs_along_the_outline_and_pours_light_into_the_sun() -> void:
	for segment: int in Scorpio.GAPS:
		var star: Star = _star_in_gap(segment)
		run.link([Scorpio.landmark_id(segment), star.id, Scorpio.landmark_id(segment + 1)] as Array[int])
	sequencer.advance(0.0)
	var waited: float = 0.0
	while not constellation.is_completing() and waited < 5.0:
		sequencer.advance(1.0 / 30.0)
		waited += 1.0 / 30.0
	assert_true(constellation.is_completing(), "after the last build, a pulse runs head to stinger")
	var particles: CollectParticles = main.get_node("CollectParticles")
	assert_eq(particles.in_flight(CollectParticles.Kind.LIGHT), 45)
	particles.advance(5.0)
	assert_eq((main.get_node("HUD/Light") as Label).text, "45/100")
	assert_almost_eq((main.get_node("Sun") as SunView).progress(), 0.45, 0.001)
	constellation.advance(ConstellationView.COMPLETION_TIME)
	assert_false(constellation.is_completing())


func test_the_guide_uses_palette_colours_and_stays_off_the_landmarks() -> void:
	for selected: bool in [false, true]:
		var dots: Dictionary[Vector2i, Color] = ConstellationView.landmark_dots(selected)
		for d: Vector2i in dots:
			assert_true(Rect2i(-3, -3, 7, 7).has_point(d), "7x7")
		assert_eq(dots.size(), 17)
	for segment: int in Scorpio.segment_count():
		for p: Vector2i in ConstellationView.outline_pixels(segment):
			for landmark: Vector2i in Scorpio.LANDMARKS:
				assert_gt(maxi(absi(p.x - landmark.x), absi(p.y - landmark.y)), 3, "outline clear of the glyphs")


func test_a_normal_run_draws_no_constellation() -> void:
	main.start_run(Fixtures.balance())
	assert_null(main.run.scorpio)
	var ids: Array[int] = []
	for x: int in [40, 60, 80]:
		ids.append(main.run.add_star(Star.Size.SMALL, Vector2i(x, 110)).id)
	sky.setup(main.run, sequencer)
	for id: int in ids:
		_tap_hold(main.run.find_star(id).position, id == ids[-1])
	assert_false(constellation.get("_sting_shown"), "no sting without the map")


## A star in the sky with a view, as if it had burst there.
func _star(at: Vector2i) -> Star:
	var star: Star = run.add_star(Star.Size.SMALL, at)
	sky.setup(run, sequencer)
	return star


func _star_in_gap(segment: int) -> Star:
	var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
	return _star((ends[0] + ends[1]) / 2)


func _play() -> void:
	for i: int in 90:
		sequencer.advance(1.0 / 30.0)


func _tap(at: Vector2i) -> void:
	_touch(at, true)
	_touch(at, false)


## Taps, but holds the last press down so its preview stays up.
func _tap_hold(at: Vector2i, hold: bool) -> void:
	_touch(at, true)
	if not hold:
		_touch(at, false)


func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	sky.handle_pointer(e)


func _drag(at: Vector2i) -> void:
	var e := InputEventScreenDrag.new()
	e.position = Vector2(at)
	sky.handle_pointer(e)
