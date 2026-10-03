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
	assert_eq(sky.star_at(Scorpio.LANDMARKS[3] + Vector2i(3, 2)), Scorpio.landmark_id(3))
	assert_eq(sky.star_at(Scorpio.LANDMARKS[1]), 0, "landmark 1 starts lit: done")
	main.start_run(Fixtures.balance())
	assert_eq(sky.star_at(Scorpio.LANDMARKS[3]), 0, "no landmarks without the map")


func test_tapping_two_stars_and_a_landmark_lights_it() -> void:
	# Two smalls either side of sigma (landmark 3, small), in reach.
	var a: Star = _star(Star.Size.SMALL, Vector2i(116, 104))
	var b: Star = _star(Star.Size.SMALL, Vector2i(140, 150))
	for point: Vector2i in [a.position, Scorpio.LANDMARKS[3], b.position]:
		_tap(point)
	assert_true(run.scorpio.is_lit(3))
	assert_true(run.scorpio.is_built(2), "the head-sigma string")


func test_tracing_shows_the_landmark_lit_and_the_string_it_would_form() -> void:
	var a: Star = _star(Star.Size.SMALL, Vector2i(116, 104))
	var b: Star = _star(Star.Size.SMALL, Vector2i(140, 150))
	_tap(a.position)
	_tap(Scorpio.LANDMARKS[3])
	assert_eq(constellation.get("_selected"), [3] as Array[int])
	_touch(b.position, true)
	assert_eq(constellation.get("_preview_strings"), [2] as Array[int])


func test_a_bad_mix_shows_the_no_combo_cross_and_uses_nothing() -> void:
	var a: Star = _star(Star.Size.SMALL, Vector2i(30, 100))
	var b: Star = _star(Star.Size.SMALL, Vector2i(50, 100))
	_tap(a.position)
	_tap(b.position)
	_touch(Scorpio.LANDMARKS[6], true)
	assert_eq(constellation.get("_preview_strings"), [] as Array[int])
	_touch(Scorpio.LANDMARKS[6], false)
	assert_false(run.scorpio.is_lit(6), "small, small, medium (epsilon): no combo")
	assert_eq(run.stars.size(), 2)


func test_picking_a_second_landmark_is_refused_on_the_spot_and_the_line_says_why() -> void:
	var big: Star = _star(Star.Size.BIG, Vector2i(30, 100))
	var hud: Hud = main.get_node("HUD")
	var refused: Array[RunState.PickRefusal] = []
	sky.link_refused.connect(func(reason: RunState.PickRefusal) -> void: refused.append(reason))
	_tap(Scorpio.LANDMARKS[3])
	assert_eq(refused, [] as Array[RunState.PickRefusal], "one landmark is fine")
	assert_eq(hud.message(), "")
	_touch(Scorpio.LANDMARKS[4], true)
	assert_eq(refused, [RunState.PickRefusal.SECOND_LANDMARK] as Array[RunState.PickRefusal], "the second one is refused at once, no third pick needed")
	assert_eq(hud.message(), Hud.REFUSAL_MESSAGES[RunState.PickRefusal.SECOND_LANDMARK], "the line says why (#91)")
	assert_true((main.get_node("Sky/LinkLayer") as LinkLayer).is_flashing(), "with the red shake of a wrong link along the line")
	assert_eq(sky.selected_ids(), [] as Array[int], "and the link is dropped")
	_touch(Scorpio.LANDMARKS[4], false)
	_tap(big.position)
	assert_eq(sky.selected_ids(), [big.id] as Array[int], "a fresh link starts cleanly")
	assert_false(run.scorpio.is_lit(3) or run.scorpio.is_lit(4))


func test_dragging_across_two_landmarks_is_refused_too() -> void:
	var refused: Array[RunState.PickRefusal] = []
	sky.link_refused.connect(func(reason: RunState.PickRefusal) -> void: refused.append(reason))
	_touch(Scorpio.LANDMARKS[3], true)
	var e := InputEventScreenDrag.new()
	e.position = Vector2(Scorpio.LANDMARKS[4])
	sky.handle_pointer(e)
	assert_eq(refused, [RunState.PickRefusal.SECOND_LANDMARK] as Array[RunState.PickRefusal])
	assert_eq(sky.selected_ids(), [] as Array[int])
	assert_ne((main.get_node("HUD") as Hud).message(), "")


func test_the_rule_line_isnt_said_again_within_a_few_seconds() -> void:
	var hud: Hud = main.get_node("HUD")
	var line: String = Hud.REFUSAL_MESSAGES[RunState.PickRefusal.SECOND_LANDMARK]
	for i: int in 2:
		_tap(Scorpio.LANDMARKS[3])
		_tap(Scorpio.LANDMARKS[4])
		if i == 0:
			assert_eq(hud.message(), line)
			hud.show_message("")
	assert_eq(hud.message(), "", "the same refusal right after: quiet")
	hud.advance(Hud.RULE_QUIET)
	_tap(Scorpio.LANDMARKS[3])
	_tap(Scorpio.LANDMARKS[4])
	assert_eq(hud.message(), line, "said again once the quiet is over")


func test_the_rule_line_fits_the_screen_and_sits_above_the_message_line() -> void:
	var hud: Hud = main.get_node("HUD")
	var line: String = Hud.REFUSAL_MESSAGES[RunState.PickRefusal.SECOND_LANDMARK]
	assert_eq(line.replace("\n", " "), "ONE CONSTELLATION STAR PER LINK", "the issue's words")
	hud.explain_refusal(RunState.PickRefusal.SECOND_LANDMARK)
	var label: Label = hud.get_node("Message")
	assert_lte(label.get_minimum_size().x, float(ScreenZones.SCREEN.x), "fits the 180 px screen")
	assert_eq(int(label.position.y), Hud.MESSAGE_Y - Hud.MESSAGE_LINE_STEP, "its first line goes above")
	hud.show_message(Hud.ORION_MESSAGE)
	assert_eq(int(label.position.y), Hud.MESSAGE_Y, "a one-line message stays on the line")
	for c: String in line.replace("\n", "").replace(" ", ""):
		assert_true(c >= "A" and c <= "Z", "no punctuation")


func test_other_refused_picks_dont_say_it() -> void:
	_reach_run()
	var hud: Hud = main.get_node("HUD")
	var a: Star = _star(Star.Size.SMALL, Vector2i(150, 236))
	var far: Star = _star(Star.Size.SMALL, Vector2i(20, 120))
	_tap(a.position)
	_tap(far.position)
	assert_eq(sky.selected_ids(), [a.id] as Array[int], "out of reach: refused")
	assert_eq(hud.message(), "", "not the constellation rule")


func test_built_strings_glow_and_open_ones_dont() -> void:
	var step: int = constellation.glow_step()
	constellation.advance(ConstellationView.GLOW_STEP)
	assert_ne(constellation.glow_step(), step, "the glint moves along a built string")
	var pixels: Array[Vector2i] = ConstellationView.outline_pixels(0)
	assert_gt(pixels.size(), ConstellationView.GLOW_SPACING, "room for glints")


func test_an_unlit_landmark_looks_like_its_sky_star_and_a_lit_one_turns_gold() -> void:
	# Playtest: an unlit constellation star must read as the sky star it stands in for. Lit, it's
	# done: gold whatever its size, the colour of the lit strings, which no sky star uses.
	for size: int in 3:
		var unlit: Dictionary[Vector2i, Color] = ConstellationView.landmark_pixels(size)
		var lit: Dictionary[Vector2i, Color] = ConstellationView.landmark_pixels(size, true)
		assert_eq(unlit, ConstellationView.star_pixels(size, &"idle"), "unlit: the sky star's own frame")
		assert_eq(lit.keys(), unlit.keys(), "lit: the same shape")
		assert_true(lit.values().has(Palette.C1), "lit: gold")
		for colour: Color in lit.values():
			assert_true(colour in [Palette.C0, Palette.C1, Palette.C2], "lit: gold only, " + colour.to_html(false))
		assert_ne(ConstellationView.landmark_pixels(size, true, true), lit, "lit, it twinkles")
		var halo: Dictionary[Vector2i, Color] = ConstellationView.lit_halo_pixels(size)
		assert_false(halo.is_empty(), "lit, it wears a halo")
		for p: Vector2i in halo:
			assert_false(unlit.has(p), "the halo stays off the star")
			assert_true(halo[p] in [Palette.C4, Palette.C5], "a warm halo on every size")
	assert_gt(ConstellationView.star_pixels(Star.Size.BIG).size(), ConstellationView.star_pixels(Star.Size.SMALL).size())


func test_a_lit_landmark_twinkles_like_a_sky_star() -> void:
	var glints: int = 0
	var steps: int = 240
	for k: int in steps:
		if ConstellationView.twinkles(5, StarView.TWINKLE_PERIOD * k / steps):
			glints += 1
	assert_almost_eq(float(glints) / steps, StarView.GLINT_TIME / StarView.TWINKLE_PERIOD, 0.01, "a glint for GLINT_TIME every TWINKLE_PERIOD")
	var phases: Array[bool] = []
	for index: int in 4:
		phases.append(ConstellationView.twinkles(index, 0.0))
	assert_true(phases.has(false), "each at its own phase, not all at once")


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
	for index: int in range(3, Scorpio.LANDMARKS.size()):
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
	assert_eq(constellation.figure_stage(), -1.0, "the painting waits for the tune")
	for i: int in 150:
		constellation.advance(1.0 / 30.0)
	assert_eq(sung, ConstellationView.song_order(), "every string, once, bottom to top")
	var ys: Array[int] = []
	for segment: int in sung:
		var ends: Array[Vector2i] = Scorpio.segment_ends(segment)
		ys.append(ends[0].y + ends[1].y)
	for k: int in range(1, ys.size()):
		assert_lte(ys[k], ys[k - 1])
	assert_true(constellation.is_revealed(), "the scorpion is painted and stays")
	assert_eq(constellation.figure_stage(), 3.0)
	var sun: SunView = main.get_node("Sun")
	for i: int in 220:
		_tick([sequencer, sun], 1.0 / 30.0)
	assert_false(sun.is_igniting() or sun.is_ignited(), "no Sun ignition for this win")
	var end: EndScreen = main.get_node("EndScreen")
	assert_true(end.is_showing())
	assert_eq(end.lines(), ["SCORPIO COMPLETE", "STRINGS 13/13"] as Array[String])


func test_the_painting_forms_from_the_constellation_stars() -> void:
	var map: StarMap = StarMap.scorpio()
	var forming: Apparition = ConstellationView.apparition(map)
	assert_eq(forming.radius_at(0.0), 0)
	assert_gt(forming.radius_at(1.0), forming.max_distance(), "past the furthest pixel, edge and all")


func test_unlit_landmarks_show_the_selectable_cue_and_lit_ones_dont() -> void:
	assert_false(constellation.shows_cue(0), "the head is lit: its ring, no cue")
	assert_true(constellation.shows_cue(3), "unlit: it can be picked")
	var a: Star = _star(Star.Size.SMALL, Vector2i(116, 104))
	_tap(a.position)
	_tap(Scorpio.LANDMARKS[3])
	assert_false(constellation.shows_cue(3), "in the link it shows the selection ring instead")
	_tap(Vector2i(170, 240))
	run.scorpio.lit[3] = true
	assert_true(constellation.shows_cue(3), "lit in the core only: not shown until its event plays")
	constellation.flash_landmark(3)
	assert_false(constellation.shows_cue(3), "lit: no cue")


func test_the_cue_is_four_ember_brackets_off_the_star_art() -> void:
	for size: int in 3:
		var art: Dictionary = ConstellationView.star_pixels(size)
		var cue: Array[Vector2i] = ConstellationView.cue_pixels(size)
		assert_eq(cue.size(), 12, "an L of 3 px in each corner")
		for p: Vector2i in cue:
			assert_false(art.has(p), "clear of the star itself")
			assert_eq(maxi(absi(p.x), absi(p.y)), StarView.half_extent(size as Star.Size) + ConstellationView.CUE_GAP)
	var frame: int = constellation.cue_frame()
	constellation.advance(ConstellationView.CUE_STEP)
	assert_ne(constellation.cue_frame(), frame, "it swaps C3 and C4, slowly")
	assert_eq(ConstellationView.CUE_COLOURS, [Palette.C3, Palette.C4] as Array[Color], "ember, so it shows")


func test_a_selected_landmarks_ring_redraws_on_its_own_frame_change() -> void:
	constellation.show_link_preview([3] as Array[int], [] as Array[int])
	var t: float = _ring_only_flip()
	assert_gt(t, 0.0, "a ring flip with the glow, cue and twinkles still")
	constellation.set("_time", t - 0.01)
	await wait_process_frames(2)
	var redraws: Array[int] = [0]
	constellation.draw.connect(func() -> void: redraws[0] += 1)
	constellation.advance(0.02)
	await wait_process_frames(2)
	assert_gt(redraws[0], 0, "the ring's next dash frame is drawn")


func test_the_reach_shows_as_the_stars_out_of_it_dimming() -> void:
	_reach_run()
	var a: Star = _star(Star.Size.SMALL, Vector2i(40, 120))
	var b: Star = _star(Star.Size.SMALL, Vector2i(60, 120))
	_star(Star.Size.SMALL, Vector2i(50, 135))
	var far: Star = _star(Star.Size.SMALL, Vector2i(170, 240))
	_tap(a.position)
	assert_false(sky.star_view(b.id).dimmed, "in reach")
	assert_true(sky.star_view(far.id).dimmed, "the same size, out of reach")
	_tap(a.position)
	assert_false(sky.star_view(far.id).dimmed, "playable again once the pick is released")


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


func test_the_sun_fills_toward_scorpios_own_target() -> void:
	_reach_run()
	assert_eq(main.run.light_target(), 50, "Scorpio's sun_target, not the plain stage's")
	(main.get_node("Sun") as SunView).receive_light(25)
	assert_almost_eq((main.get_node("Sun") as SunView).progress(), 0.5, 0.001, "its fill shows it: no number (#59)")


func test_on_a_taller_sky_the_constellation_is_drawn_and_picked_where_it_moved() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1}
	var tall := RunState.new(Balance.from_dict(data), Fixtures.rng(), ScreenZones.play_sky(102))
	sky.setup(tall, sequencer)
	assert_eq(constellation.position, Vector2(0, -51), "the whole map view moves with it")
	assert_eq(sky.star_at(tall.scorpio.landmark_position(3)), Scorpio.landmark_id(3), "picked where it is now")
	assert_eq(sky.star_at(Scorpio.LANDMARKS[3]), 0, "not at its home spot")


func test_the_sun_glow_reaches_the_top_of_a_taller_screen() -> void:
	assert_eq(SunView.glow_area(Rect2i(0, 0, 180, 320)), Rect2i(0, 0, 180, ScreenZones.SKY.end.y), "9:16: from the game's top")
	var risen: Vector2i = ScreenZones.sun_centre(102)
	assert_eq(risen, Vector2i(90, -63))
	var area: Rect2i = SunView.glow_area(Rect2i(0, -102, 180, 422))
	assert_eq(area.position.y, -102)
	var glow: Image = SunView.sky_glow(SunView.IGNITE_FRAMES, risen, area)
	assert_eq(glow.get_size(), Vector2i(180, ScreenZones.SKY.end.y + 102), "down to the sky's bottom")


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


## A time where the selection ring changes frame and nothing else that redraws does (0 if none).
func _ring_only_flip() -> float:
	var lit: Array[bool] = constellation.get("_shown_lit")
	for k: int in range(1, 200):
		var t: float = k * StarView.RING_FRAME_TIME
		var before: float = t - 0.01
		var after: float = t + 0.01
		var still: bool = int(before / ConstellationView.GLOW_STEP) == int(after / ConstellationView.GLOW_STEP) 			and int(before / ConstellationView.CUE_STEP) == int(after / ConstellationView.CUE_STEP)
		for i: int in lit.size():
			still = still and ConstellationView.twinkles(i, before) == ConstellationView.twinkles(i, after)
		if still and int(before / StarView.RING_FRAME_TIME) != int(after / StarView.RING_FRAME_TIME):
			return t
	return 0.0
