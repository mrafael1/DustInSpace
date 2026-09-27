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


func test_tracing_shows_the_landmark_lit_and_the_string_it_would_form() -> void:
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


func test_landmarks_are_the_star_shape_of_their_size_cool_tinted_until_lit() -> void:
	var tints: Array = []
	for size: int in 3:
		var shape: Array = ConstellationView.star_pixels(size).keys()
		var unlit: Dictionary[Vector2i, Color] = ConstellationView.landmark_pixels(size, false)
		assert_eq(unlit.keys(), shape, "same shape as the sky star")
		for c: Color in unlit.values():
			assert_false(c in [Palette.C0, Palette.C1, Palette.C2, Palette.C3], "no gold while unlit")
		tints.append(unlit[Vector2i.ZERO])
	assert_eq(tints, [Palette.N10, Palette.D0, Palette.M6], "small pink, medium lavender, big blue: sizes tell apart")
	assert_gt(ConstellationView.star_pixels(Star.Size.BIG).size(), ConstellationView.star_pixels(Star.Size.SMALL).size())


func test_every_lit_landmark_is_the_same_gold() -> void:
	for size: int in 3:
		var lit: Dictionary[Vector2i, Color] = ConstellationView.landmark_pixels(size, true)
		assert_eq(lit.keys(), ConstellationView.star_pixels(size).keys())
		assert_eq(lit[Vector2i.ZERO], Palette.C0, "a white-gold core on every size")
		for c: Color in lit.values():
			assert_true(c in [Palette.C0, Palette.C1, Palette.C2, Palette.C3], "gold only: lit reads the same on every size")


func test_a_full_sun_ignites_lights_its_landmark_then_bursts_the_stars_left_for_dust() -> void:
	run.light = 95
	var left: Star = _star(Star.Size.SMALL, Vector2i(150, 240))
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(_star(Star.Size.BIG, Vector2i(x, 100)).id)
	var target: int = run.rekindle_target()
	var burst: Array[Vector2i] = []
	sky.star_exploded.connect(func(at: Vector2i) -> void: burst.append(at))
	run.link(ids)
	var sun: SunView = main.get_node("Sun")
	var particles: CollectParticles = main.get_node("CollectParticles")
	var view: StarView = sky.star_view(left.id)
	view.set_process(false)
	var dust_before: int = run.dust
	sequencer.advance(0.0)
	for i: int in 60:
		_tick([sequencer, particles, sun, constellation, view], 1.0 / 30.0)
	assert_true(sun.is_igniting(), "the Sun plays its ignition")
	assert_eq(burst, [] as Array[Vector2i], "the stars wait for it")
	for i: int in 50:
		_tick([sequencer, particles, sun, constellation, view], 1.0 / 30.0)
	assert_false(sun.is_igniting())
	assert_gt(sun.progress(), 0.0, "still shining while its sunbeam flies")
	assert_eq(burst, [] as Array[Vector2i], "and for the sunbeam")
	for i: int in ceili(ConstellationView.BEAM_TIME * 30.0) + 2:
		_tick([sequencer, particles, sun, constellation], 1.0 / 30.0)
		if is_instance_valid(view):
			view.advance(1.0 / 30.0)
	assert_almost_eq(sun.progress(), 0.0, 0.001, "then starts again from 0")
	assert_eq((main.get_node("HUD/Light") as Label).text, "0/100")
	assert_true(constellation.shows_lit(target), "its landmark lit")
	assert_eq(burst, [left.position], "then the star left bursts")
	assert_eq(sky.star_count(), 0, "a clean sky")
	assert_eq(particles.in_flight(CollectParticles.Kind.DUST), 1, "its dust flies from where it burst")
	particles.advance(5.0)
	assert_eq(run.dust, dust_before, "the core paid it with the link: 1 dust")
	assert_eq((main.get_node("HUD/Dust") as Label).text, "%d" % run.dust, "and the counter meets the run once it lands")


func test_completion_bursts_every_star_left_lowest_first_before_the_tune() -> void:
	for index: int in range(2, Scorpio.LANDMARKS.size() - 1):
		run.scorpio.lit[index] = true
	var high: Star = run.add_star(Star.Size.MEDIUM, Vector2i(60, 100))
	var low: Star = run.add_star(Star.Size.BIG, Vector2i(150, 230))
	var mid: Star = run.add_star(Star.Size.SMALL, Vector2i(120, 170))
	var a: Star = run.add_star(Star.Size.BIG, Vector2i(20, 180))
	var b: Star = run.add_star(Star.Size.BIG, Vector2i(40, 190))
	sky.setup(run, sequencer)
	var burst_at: Array[Vector2i] = []
	sky.star_exploded.connect(func(at: Vector2i) -> void: burst_at.append(at))
	var sparks: BurstSparks = main.get_node("BurstSparks")
	sparks.set_process(false)
	var views: Array[StarView] = [sky.star_view(high.id), sky.star_view(low.id), sky.star_view(mid.id)]
	for view: StarView in views:
		view.set_process(false)
	run.link([a.id, b.id, Scorpio.landmark_id(Scorpio.LANDMARKS.size() - 1)] as Array[int])
	assert_eq(run.stars.size(), 0, "the core cleared the sky")
	var elapsed: float = 0.0
	while burst_at.size() < 3 and elapsed < 3.0:
		sequencer.advance(1.0 / 60.0)
		for view: StarView in views:
			if is_instance_valid(view):
				view.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if not burst_at.is_empty():
			assert_false(constellation.is_completing(), "the tune waits for the sky to clear")
	assert_eq(burst_at, [low.position, mid.position, high.position], "every star left bursts, lowest first")
	assert_true(sparks.is_sparking(), "with a burst's sparks")
	assert_eq(sky.star_count(), 0, "a clean sky")
	for i: int in 60:
		for view: StarView in views:
			if is_instance_valid(view):
				view.advance(1.0 / 60.0)
	for view: StarView in views:
		assert_true(not is_instance_valid(view) or view.is_queued_for_deletion(), "each one gone")


func test_a_cleared_star_blows_up_bigger_than_a_pack_burst() -> void:
	var sparks: BurstSparks = main.get_node("BurstSparks")
	sparks.set_process(false)
	sparks.explode_at(Vector2i(90, 150))
	assert_true(sparks.is_sparking())
	sparks.advance(BurstSparks.SPARK_TIME)
	assert_true(sparks.is_sparking(), "it outlasts a pack burst's sparks")
	sparks.advance(BurstSparks.EXPLODE_TIME - BurstSparks.SPARK_TIME)
	assert_false(sparks.is_sparking(), "then it's gone")
	assert_gt(BurstSparks.EXPLODE_SPARKS, BurstSparks.SPARKS)
	assert_gt(BurstSparks.EXPLODE_REACH_MAX, BurstSparks.REACH_MAX)


func test_an_exploding_star_waits_then_bursts_and_vanishes() -> void:
	var star: Star = _star(Star.Size.MEDIUM, Vector2i(90, 150))
	var view: StarView = sky.star_view(star.id)
	view.set_process(false)
	var burst: Array[bool] = []
	view.exploded.connect(func(_v: StarView) -> void: burst.append(true))
	view.explode(0.1)
	view.advance(0.05)
	assert_eq(burst, [] as Array[bool], "still waiting")
	assert_true(view.is_exploding())
	view.advance(0.06)
	assert_eq(burst, [true])
	view.advance(StarView.DISSOLVE_TIME - 0.005)
	assert_true(view.is_queued_for_deletion(), "the tick past the wait counts toward the burst")
	var other: StarView = sky.star_view(_star(Star.Size.SMALL, Vector2i(40, 120)).id)
	other.dissolve()
	assert_false(other.is_exploding(), "a plain dissolve isn't an explosion")


func test_a_landmark_the_sun_lights_shows_lit_only_after_the_ignition() -> void:
	var sun: SunView = main.get_node("Sun")
	sun.set_process(true)
	run.light = run.light_target() - 5
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(_star(Star.Size.SMALL, Vector2i(x, 100)).id)
	var target: int = run.rekindle_target()
	run.link(ids)
	assert_true(run.scorpio.is_lit(target), "the core lit it at once")
	assert_false(constellation.shows_lit(target), "the view waits")
	var ignited_first: bool = false
	for i: int in 400:
		sequencer.advance(1.0 / 60.0)
		sun.advance(1.0 / 60.0)
		main.get_node("CollectParticles").advance(1.0 / 60.0)
		if sun.is_igniting() and not constellation.shows_lit(target):
			ignited_first = true
		if constellation.shows_lit(target):
			break
	assert_true(ignited_first, "the Sun ignites while the landmark still shows unlit")
	assert_true(constellation.shows_lit(target), "then it lights")
	assert_false(sun.is_igniting(), "once the ignition is over")


func test_the_sun_sends_a_sunbeam_and_the_landmark_lights_as_it_lands() -> void:
	var sun: SunView = main.get_node("Sun")
	var particles: CollectParticles = main.get_node("CollectParticles")
	run.light = run.light_target() - 5
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(_star(Star.Size.SMALL, Vector2i(x, 100)).id)
	var target: int = run.rekindle_target()
	var launched: Array[bool] = []
	sky.sunbeam_launched.connect(func() -> void: launched.append(true))
	var landed: Array[Vector2i] = []
	sky.sunbeam_landed.connect(func(at: Vector2i) -> void: landed.append(at))
	run.link(ids)
	var beam_seen_at: float = -1.0
	var lit_at: float = -1.0
	var t: float = 0.0
	for i: int in 600:
		var dt: float = 1.0 / 60.0
		sequencer.advance(dt)
		sun.advance(dt)
		particles.advance(dt)
		constellation.advance(dt)
		t += dt
		if constellation.is_beaming() and beam_seen_at < 0.0:
			beam_seen_at = t
			assert_false(sun.is_igniting(), "the beam leaves once the ignition is over")
			assert_false(constellation.shows_lit(target), "the landmark waits for it")
		if constellation.shows_lit(target):
			lit_at = t
			break
	assert_eq(launched, [true], "with its sound")
	assert_gt(beam_seen_at, 0.0, "a sunbeam flew")
	assert_almost_eq(lit_at - beam_seen_at, ConstellationView.BEAM_TIME, 0.05, "the landmark lights as it lands")
	assert_eq(landed, [Scorpio.LANDMARKS[target]], "and it bursts there (sparks and sound)")


func test_the_sunbeam_runs_from_the_suns_rim_to_the_landmark() -> void:
	var sun_at := Vector2i(90, 39)
	constellation.launch_sunbeam(sun_at, 3)
	var start: Array[Vector2i] = ConstellationView.beam_pixels(constellation.get("_beam_from"), Scorpio.LANDMARKS[3], 0.0)
	assert_almost_eq(Vector2(start[0] - sun_at).length(), float(ConstellationView.SUN_RIM), 1.5, "from the rim")
	var end: Array[Vector2i] = ConstellationView.beam_pixels(constellation.get("_beam_from"), Scorpio.LANDMARKS[3], 1.0)
	assert_eq(end[0], Scorpio.LANDMARKS[3], "to the landmark")
	assert_eq(end.size(), ConstellationView.BEAM_TRAIL, "with its trail")
	constellation.launch_sunbeam(sun_at, -1)
	constellation.advance(ConstellationView.BEAM_TIME)
	assert_false(constellation.is_beaming(), "no target, no beam")


func test_a_lighting_landmark_throws_a_ring() -> void:
	var near: Array[Vector2i] = ConstellationView.lit_ring_pixels(Star.Size.MEDIUM, 0.0)
	var far: Array[Vector2i] = ConstellationView.lit_ring_pixels(Star.Size.MEDIUM, 1.0)
	assert_eq(roundi(Vector2(far[0]).length()) - roundi(Vector2(near[0]).length()), ConstellationView.LIT_RING_GROWTH)
	constellation.flash_landmark(3)
	assert_eq(constellation.get("_ring_landmark"), 3)
	constellation.advance(ConstellationView.LIT_RING_TIME)
	assert_eq(constellation.get("_ring_time"), -1.0, "gone once spread")


func test_the_sun_lighting_the_last_landmark_plays_the_completion() -> void:
	# Light all but one landmark; the Sun will light the last.
	var last: int = Scorpio.LANDMARKS.size() - 1
	for index: int in range(2, last):
		run.scorpio.lit[index] = true
	sky.setup(run, sequencer)
	var left: Star = _star(Star.Size.MEDIUM, Vector2i(150, 120))
	run.light = run.light_target() - 5
	var ids: Array[int] = []
	for x: int in [20, 40, 60]:
		ids.append(_star(Star.Size.SMALL, Vector2i(x, 100)).id)
	var types: Array[StringName] = []
	sequencer.event_played.connect(func(e: EventSequencer.RunEvent) -> void: types.append(e.type))
	run.link(ids)
	assert_eq(run.outcome, RunState.Outcome.WON)
	var sun: SunView = main.get_node("Sun")
	var particles: CollectParticles = main.get_node("CollectParticles")
	var views: Array = [sky.star_view(left.id)]
	for i: int in 600:
		sequencer.advance(1.0 / 60.0)
		sun.advance(1.0 / 60.0)
		particles.advance(1.0 / 60.0)
		constellation.advance(1.0 / 60.0)
		for view: Variant in views:
			if is_instance_valid(view):
				(view as StarView).advance(1.0 / 60.0)
		if constellation.is_completing():
			break
	var rekindled_at: int = types.find(&"sun_rekindled")
	assert_gt(rekindled_at, -1)
	assert_gt(types.find(&"landmark_lit"), rekindled_at, "the Sun lights the last landmark")
	assert_gt(types.find(&"sky_cleared"), types.find(&"landmark_lit"), "then the sky clears")
	assert_true(constellation.is_completing(), "and the constellation plays")
	assert_eq(sky.star_count(), 0, "on a clean sky")


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


func test_unlit_landmarks_show_the_selectable_cue_and_lit_ones_dont() -> void:
	assert_false(constellation.shows_cue(0), "the head is lit: its ring, no cue")
	assert_true(constellation.shows_cue(2), "unlit: it can be picked")
	var a: Star = _star(Star.Size.SMALL, Vector2i(90, 150))
	_tap(a.position)
	_tap(Scorpio.LANDMARKS[2])
	assert_false(constellation.shows_cue(2), "in the link it shows lit instead")
	_tap(Vector2i(170, 240))
	run.scorpio.lit[2] = true
	assert_true(constellation.shows_cue(2), "lit in the core only: not shown until its event plays")
	constellation.flash_landmark(2)
	assert_false(constellation.shows_cue(2), "lit: no cue")


func test_the_cue_is_four_quiet_brackets_off_the_star_art() -> void:
	for size: int in 3:
		var art: Dictionary = ConstellationView.star_pixels(size)
		var cue: Array[Vector2i] = ConstellationView.cue_pixels(size)
		assert_eq(cue.size(), 12, "an L of 3 px in each corner")
		for p: Vector2i in cue:
			assert_false(art.has(p), "clear of the star itself")
			assert_eq(maxi(absi(p.x), absi(p.y)), StarView.half_extent(size as Star.Size) + ConstellationView.CUE_GAP)
	var frame: int = constellation.cue_frame()
	constellation.advance(ConstellationView.CUE_STEP)
	assert_ne(constellation.cue_frame(), frame, "it swaps C5 and C4, slowly")


func test_the_reach_ring_shows_around_the_last_star_picked() -> void:
	_reach_run()
	var link_layer: LinkLayer = main.get_node("Sky/LinkLayer")
	var a: Star = _star(Star.Size.SMALL, Vector2i(40, 120))
	assert_eq(link_layer.reach_radius(), 0, "nothing picked: no ring")
	_tap(a.position)
	assert_eq(link_layer.reach_radius(), 56)
	assert_eq(link_layer.get("_reach_center"), a.position)
	for p: Vector2i in LinkLayer.reach_ring(a.position, 56):
		assert_almost_eq(Vector2(p - a.position).length(), 56.0, 1.0, "on the ring, whole pixels")
	_tap(Vector2i(170, 240))
	assert_eq(link_layer.reach_radius(), 0, "gone with the link")


func test_dragging_past_the_reach_loosens_the_line() -> void:
	_reach_run()
	var link_layer: LinkLayer = main.get_node("Sky/LinkLayer")
	var a: Star = _star(Star.Size.SMALL, Vector2i(40, 120))
	_touch(a.position, true)
	_drag(a.position + Vector2i(30, 0))
	assert_false(link_layer.is_loose_end(), "30 px: in reach")
	_drag(a.position + Vector2i(56, 0))
	assert_false(link_layer.is_loose_end(), "56 px: just in reach")
	_drag(a.position + Vector2i(57, 0))
	assert_true(link_layer.is_loose_end(), "57 px: out of reach, before any star is picked")


func test_a_star_out_of_reach_cant_join_and_nothing_is_used() -> void:
	_reach_run()
	var refused: Array[bool] = []
	sky.step_refused.connect(func() -> void: refused.append(true))
	var a: Star = _star(Star.Size.SMALL, Vector2i(20, 120))
	var b: Star = _star(Star.Size.SMALL, Vector2i(76, 120))
	var c: Star = _star(Star.Size.SMALL, Vector2i(133, 120))
	_tap(a.position)
	_tap(c.position)
	assert_eq(sky.selected_ids(), [a.id] as Array[int], "113 px away: it doesn't join")
	assert_eq(refused, [true], "the step shakes ember with a buzz")
	_tap(b.position)
	_tap(c.position)
	assert_eq(run.stars.size(), 3, "76 -> 133 is 57 px: still out of reach, nothing linked")
	assert_eq(sky.selected_ids(), [a.id, b.id] as Array[int], "the link so far stays")
	assert_eq([run.dust, run.light], [0, 0])


func test_a_link_in_reach_is_made_by_tap_and_by_drag() -> void:
	_reach_run()
	var a: Star = _star(Star.Size.SMALL, Vector2i(20, 120))
	var b: Star = _star(Star.Size.SMALL, Vector2i(76, 120))
	var c: Star = _star(Star.Size.SMALL, Vector2i(132, 120))
	for point: Vector2i in [a.position, b.position, c.position]:
		_tap(point)
	assert_eq(run.stars.size(), 0, "56 px steps: linked")
	var d: Star = _star(Star.Size.MEDIUM, Vector2i(20, 110))
	var e: Star = _star(Star.Size.MEDIUM, Vector2i(60, 110))
	var f: Star = _star(Star.Size.MEDIUM, Vector2i(100, 110))
	_touch(d.position, true)
	_drag(e.position)
	_drag(f.position)
	_touch(f.position, false)
	assert_eq(run.stars.size(), 0, "a drag through them links too")


func test_the_hud_shows_scorpios_sun_target() -> void:
	_reach_run()
	assert_eq((main.get_node("HUD/Light") as Label).text, "0/50")


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


## Restarts on the Scorpio map with the shipped reach and Sun target.
func _reach_run() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "max_link_distance": 56, "sun_target": 50}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run


func _drag(at: Vector2i) -> void:
	var e := InputEventScreenDrag.new()
	e.position = Vector2(at)
	sky.handle_pointer(e)


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
