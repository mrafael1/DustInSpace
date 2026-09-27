extends GutTest
## Scorpio in the scenes: unlit landmarks are picked like stars, previews, strings glowing, the
## Sun rekindling, completion, and nothing shown without the map.

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
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	sequencer = main.get_node("EventSequencer")
	constellation = main.get_node("Sky/ConstellationLayer")
	for node: Node in [sequencer, main.get_node("CollectParticles"), main.get_node("Sfx"), constellation, main.get_node("Sun")]:
		node.set_process(false)


func test_unlit_landmarks_are_picked_like_stars_and_lit_ones_arent() -> void:
	assert_eq(sky.star_at(Scorpio.LANDMARKS[2] + Vector2i(3, 2)), Scorpio.landmark_id(2))
	assert_eq(sky.star_at(Scorpio.LANDMARKS[1]), 0, "landmark 1 starts lit: done")
	main.start_run(Fixtures.balance())
	assert_eq(sky.star_at(Scorpio.LANDMARKS[2]), 0, "no landmarks without the map")


func test_tapping_two_stars_and_a_landmark_lights_it() -> void:
	var a: Star = _star(Star.Size.SMALL, Vector2i(30, 100))
	var b: Star = _star(Star.Size.SMALL, Vector2i(50, 100))
	for point: Vector2i in [a.position, Scorpio.LANDMARKS[2], b.position]:
		_tap(point)
	assert_true(run.scorpio.is_lit(2))
	assert_true(run.scorpio.is_built(1))


func test_tracing_shows_the_landmark_gold_and_the_string_it_would_form() -> void:
	var a: Star = _star(Star.Size.SMALL, Vector2i(30, 100))
	var b: Star = _star(Star.Size.SMALL, Vector2i(50, 100))
	_tap(a.position)
	_tap(Scorpio.LANDMARKS[2])
	assert_eq(constellation.get("_selected"), [2] as Array[int])
	_touch(b.position, true)
	assert_eq(constellation.get("_preview_strings"), [1] as Array[int])
	var plaque: RewardPlaque = main.get_node("Sky/UILayer/RewardPlaque")
	assert_true(plaque.visible, "the combo's reward shows as usual")


func test_a_bad_mix_shows_the_no_combo_cross_and_uses_nothing() -> void:
	var a: Star = _star(Star.Size.SMALL, Vector2i(30, 100))
	var b: Star = _star(Star.Size.SMALL, Vector2i(50, 100))
	_tap(a.position)
	_tap(b.position)
	_touch(Scorpio.LANDMARKS[3], true)
	assert_eq(constellation.get("_preview_strings"), [] as Array[int])
	_touch(Scorpio.LANDMARKS[3], false)
	assert_false(run.scorpio.is_lit(3), "small, small, medium: no combo")
	assert_eq(run.stars.size(), 2)


func test_picking_a_second_landmark_is_refused_on_the_spot() -> void:
	var big: Star = _star(Star.Size.BIG, Vector2i(30, 100))
	var refused: Array[bool] = []
	sky.link_refused.connect(func() -> void: refused.append(true))
	_tap(Scorpio.LANDMARKS[3])
	assert_eq(refused, [] as Array[bool], "one landmark is fine")
	_touch(Scorpio.LANDMARKS[4], true)
	assert_eq(refused, [true], "the second one is refused at once, no third pick needed")
	assert_true((main.get_node("Sky/LinkLayer") as LinkLayer).is_flashing(), "with the red shake of a wrong link")
	assert_eq(sky.selected_ids(), [] as Array[int], "and the link is dropped")
	_touch(Scorpio.LANDMARKS[4], false)
	_tap(big.position)
	assert_eq(sky.selected_ids(), [big.id] as Array[int], "a fresh link starts cleanly")
	assert_false(run.scorpio.is_lit(3) or run.scorpio.is_lit(4))


func test_dragging_across_two_landmarks_is_refused_too() -> void:
	var refused: Array[bool] = []
	sky.link_refused.connect(func() -> void: refused.append(true))
	_touch(Scorpio.LANDMARKS[3], true)
	var e := InputEventScreenDrag.new()
	e.position = Vector2(Scorpio.LANDMARKS[4])
	sky.handle_pointer(e)
	assert_eq(refused, [true])
	assert_eq(sky.selected_ids(), [] as Array[int])


func test_built_strings_glow_and_open_ones_dont() -> void:
	var step: int = constellation.glow_step()
	constellation.advance(ConstellationView.GLOW_STEP)
	assert_ne(constellation.glow_step(), step, "the glint moves along a built string")
	var pixels: Array[Vector2i] = ConstellationView.outline_pixels(0)
	assert_gt(pixels.size(), ConstellationView.GLOW_SPACING, "room for glints")


func test_landmarks_are_the_star_art_of_their_size_cool_until_lit() -> void:
	for size: int in 3:
		var art: Dictionary[Vector2i, Color] = ConstellationView.star_pixels(size)
		var cool: Dictionary[Vector2i, Color] = ConstellationView.landmark_dots(art, false)
		assert_eq(cool.keys(), art.keys(), "same shape as the sky star")
		for c: Color in cool.values():
			assert_true(c in [Palette.M6, Palette.M5, Palette.N8, Palette.N7], "cool while unlit")
	assert_gt(ConstellationView.star_pixels(Star.Size.BIG).size(), ConstellationView.star_pixels(Star.Size.SMALL).size())


func test_a_full_sun_ignites_then_starts_again_and_its_stars_shine_their_dust() -> void:
	run.light = 95
	var payer: Star = _star(Star.Size.SMALL, Vector2i(150, 240))
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(_star(Star.Size.BIG, Vector2i(x, 100)).id)
	var shone: Array[int] = []
	sky.star_shone.connect(func(order: int) -> void: shone.append(order))
	run.link(ids)
	var sun: SunView = main.get_node("Sun")
	var particles: CollectParticles = main.get_node("CollectParticles")
	var view: StarView = sky.star_view(payer.id)
	view.set_process(false)
	sequencer.advance(0.0)
	for i: int in 60:
		_tick([sequencer, particles, sun], 1.0 / 30.0)
	assert_true(sun.is_igniting(), "the Sun plays its ignition")
	for i: int in 50:
		_tick([sequencer, particles, sun], 1.0 / 30.0)
	assert_false(sun.is_igniting())
	assert_almost_eq(sun.progress(), 0.0, 0.001, "and starts again from 0")
	assert_eq((main.get_node("HUD/Light") as Label).text, "0/100")
	assert_eq(shone, [0] as Array[int], "the star paying the dust shines")
	view.advance(StarView.SHINE_PEAK)
	assert_true(view.is_shining())
	assert_eq(particles.in_flight(CollectParticles.Kind.DUST), 1, "one dust from the one star")
	particles.advance(5.0)
	assert_eq((main.get_node("HUD/Dust") as Label).text, "%d" % run.dust)
	view.advance(1.0)
	assert_false(view.is_shining(), "and settles back")
	assert_not_null(sky.star_view(payer.id), "it stays in the sky")


func test_completion_waits_for_the_payouts_then_plays_bottom_to_top_and_draws_the_scorpion() -> void:
	var sung: Array[int] = []
	constellation.string_sung.connect(func(segment: int, _order: int) -> void: sung.append(segment))
	for index: int in range(2, Scorpio.LANDMARKS.size()):
		var size: int = Scorpio.SIZES[index]
		var a: Star = run.add_star(size as Star.Size, Vector2i(170, 90))
		var b: Star = run.add_star(size as Star.Size, Vector2i(10, 90))
		run.link([a.id, b.id, Scorpio.landmark_id(index)] as Array[int])
	assert_eq(run.outcome, RunState.Outcome.WON)
	var particles: CollectParticles = main.get_node("CollectParticles")
	for i: int in 180:
		sequencer.advance(1.0 / 30.0)
		if constellation.is_completing():
			break
	assert_false(constellation.is_completing(), "the tune waits while dust and light still fly")
	assert_gt(particles.particle_count(), 0)
	particles.advance(10.0)
	assert_true(constellation.is_completing(), "every payout landed: the tune starts")
	for i: int in 30:
		constellation.advance(1.0 / 30.0)
	assert_gt(sung.size(), 1)
	var moved: bool = false
	for age: float in [0.02, 0.05, 0.1]:
		for i: int in 10:
			moved = moved or ConstellationView.vibration(i, 10, age) != 0
	assert_true(moved, "a sung string vibrates")
	assert_eq(ConstellationView.vibration(5, 10, ConstellationView.VIBRATE_TIME), 0, "then rests")
	assert_eq(constellation.drawing_shown(), 0, "the drawing waits for the tune")
	for i: int in 120:
		constellation.advance(1.0 / 30.0)
	assert_eq(sung, ConstellationView.song_order(), "every string, once, bottom to top")
	var ys: Array[int] = []
	for segment: int in sung:
		var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
		ys.append(ends[0].y + ends[1].y)
	for k: int in range(1, ys.size()):
		assert_lte(ys[k], ys[k - 1])
	assert_true(constellation.is_revealed(), "the scorpion is drawn and stays")
	assert_eq(constellation.drawing_shown(), ConstellationView.scorpion_drawing().size())
	var sun: SunView = main.get_node("Sun")
	for i: int in 150:
		_tick([sequencer, sun], 1.0 / 30.0)
	assert_false(sun.is_igniting() or sun.is_ignited(), "no Sun ignition for this win")
	var end: EndScreen = main.get_node("EndScreen")
	assert_true(end.is_showing())
	assert_eq(end.lines(), ["SCORPIO COMPLETE", "STRINGS 7/7"] as Array[String])


func test_the_scorpion_drawing_stays_in_the_sky_and_off_the_stars() -> void:
	var drawing: Array[Vector2i] = ConstellationView.scorpion_drawing()
	assert_gt(drawing.size(), 150, "pincers, body, legs, tail and stinger")
	var seen: Dictionary = {}
	for p: Vector2i in drawing:
		assert_true(ScreenZones.SKY.has_point(p), "%s in the sky" % p)
		assert_false(seen.has(p), "each pixel once")
		seen[p] = true
		for landmark: Vector2i in Scorpio.LANDMARKS:
			assert_gt(maxi(absi(p.x - landmark.x), absi(p.y - landmark.y)), 3)


func test_a_normal_run_draws_no_constellation() -> void:
	main.start_run(Fixtures.balance())
	var ids: Array[int] = []
	for x: int in [30, 50, 70]:
		ids.append(main.run.add_star(Star.Size.SMALL, Vector2i(x, 100)).id)
	sky.setup(main.run, sequencer)
	for id: int in ids:
		var at: Vector2i = main.run.find_star(id).position
		_touch(at, true)
		if id != ids[-1]:
			_touch(at, false)
	assert_eq(constellation.get("_selected"), [] as Array[int], "no constellation without the map")


## A star in the sky with a view, as if it had burst there.
func _star(size: Star.Size, at: Vector2i) -> Star:
	var star: Star = run.add_star(size, at)
	sky.setup(run, sequencer)
	return star


func _tick(nodes: Array, delta: float) -> void:
	for node: Object in nodes:
		node.call("advance", delta)


func _tap(at: Vector2i) -> void:
	_touch(at, true)
	_touch(at, false)


func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	sky.handle_pointer(e)
