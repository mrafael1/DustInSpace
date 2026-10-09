extends GutTest
## Aquarius's current intro (#148): a current stage that brings something new opens by showing the
## flow on a few demo stars (no pay, no pack, the run's own flow untouched), and a draining one loses
## one to its drain.

const MainScene := preload("res://game/scenes/main.tscn")
const INTRO_STAGES: Array[String] = ["aquarius_hand", "aquarius_body", "aquarius_stream", "aquarius_jar", "aquarius_final"]


func _run(map_id: String, seed_value: int = 3) -> RunState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return RunState.new(Balance.load_file(), rng, Scorpio.HOME_SKY, StarMap.by_id(map_id))


func test_each_stage_bringing_the_flow_shows_it_and_leaves_the_sky_as_it_was() -> void:
	for map_id: String in INTRO_STAGES:
		var run: RunState = _run(map_id)
		var flow: Vector2i = run.current.displacement
		var packs: Dictionary = run.owned_packs.duplicate()
		watch_signals(run)
		run.play_current_intro()
		var placed: Array = get_signal_parameters(run, "current_intro_placed")[0]
		assert_eq(placed.size(), 3, "%s: a small, a medium and a big star" % map_id)
		assert_gt(get_signal_emit_count(run, "stars_shifted"), 0, "%s: the flow moves them" % map_id)
		assert_lte(get_signal_emit_count(run, "current_intro_flowed"), RunState.CURRENT_INTRO_PULSES)
		assert_true(run.stars.is_empty(), "%s: the demo leaves the sky" % map_id)
		assert_eq(run.current.displacement, flow, "%s: the run's own flow hasn't turned" % map_id)
		assert_eq(run.owned_packs, packs, "%s: no pack used" % map_id)
		assert_eq(run.dust, 0, map_id)
		assert_eq(run.light, 0, map_id)
		for star: Star in placed:
			for at: Vector2i in run.scorpio.landmark_positions():
				assert_gt(Vector2(star.position).distance_to(Vector2(at)), float(StarScatter.LANDMARK_SPACING), "%s: away from the figure" % map_id)


func test_a_draining_flow_loses_a_demo_star_to_its_drain() -> void:
	for map_id: String in ["aquarius_body", "aquarius_stream", "aquarius_jar", "aquarius_final"]:
		var run: RunState = _run(map_id)
		var drained: Array[int] = []
		run.stars_shifted.connect(func(moves: Array[StarCurrent.Move]) -> void:
			for move: StarCurrent.Move in moves:
				if move.drained:
					drained.append(move.star_id))
		run.play_current_intro()
		assert_false(drained.is_empty(), "%s: one goes down the drain" % map_id)


func test_the_hand_only_carries_them() -> void:
	var run: RunState = _run("aquarius_hand")
	watch_signals(run)
	run.play_current_intro()
	assert_signal_emitted(run, "current_intro_cleared", "what's left leaves")
	for moves: Variant in [get_signal_parameters(run, "stars_shifted", 0)[0], get_signal_parameters(run, "stars_shifted", 1)[0]]:
		for move: StarCurrent.Move in moves:
			assert_false(move.drained, "no drain on the Hand")
			assert_lt(move.to.x, move.from.x, "down the flow")
			assert_gte(move.to.x, move.from.x - run.balance.current_step_for("aquarius_hand"), "a step at most")


func test_the_tide_turns_in_the_demo() -> void:
	var run: RunState = _run("aquarius_jar")
	watch_signals(run)
	run.play_current_intro()
	assert_eq(get_signal_emit_count(run, "current_intro_flowed"), 2)
	assert_eq(get_signal_parameters(run, "current_intro_flowed", 0)[0], Vector2i(-56, 0), "left first")
	assert_eq(get_signal_parameters(run, "current_intro_flowed", 1)[0], Vector2i(56, 0), "then the tide turns")
	assert_eq(run.current.displacement, Vector2i(-56, 0), "the first launch still flows left")


func test_the_demo_doesnt_shift_packs_or_layout() -> void:
	var shown: RunState = _run("aquarius_body", 11)
	var plain: RunState = _run("aquarius_body", 11)
	shown.play_current_intro()
	assert_true(shown.launch(Vector2i(120, 150)))
	assert_true(plain.launch(Vector2i(120, 150)))
	assert_eq(shown.stars.size(), plain.stars.size())
	for i: int in plain.stars.size():
		assert_eq(shown.stars[i].size, plain.stars[i].size, "the same pack")
		assert_eq(shown.stars[i].position, plain.stars[i].position, "landing the same way")


func test_no_intro_on_the_legs_on_a_started_run_or_without_a_current() -> void:
	for map_id: String in ["aquarius_legs", "stinger", "current_aquarius"]:
		var run: RunState = _run(map_id)
		watch_signals(run)
		run.play_current_intro()
		assert_signal_not_emitted(run, "current_intro_placed", map_id)
	var started: RunState = _run("aquarius_body")
	started.launch(Vector2i(120, 150))
	watch_signals(started)
	started.play_current_intro()
	assert_signal_not_emitted(started, "current_intro_placed", "not once the run has begun")


func test_the_stage_opens_with_the_demo_and_says_its_rule() -> void:
	var main: Main = MainScene.instantiate()
	main.star_map = "aquarius_jar"
	main.in_chapter = true
	main.seed_override = 7
	add_child_autofree(main)
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var hud: Hud = main.get_node("HUD")
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var sky: SkyView = main.get_node("Sky")
	assert_true(sequencer.is_busy(), "the demo plays as the stage opens")
	var flows: Array[Vector2i] = []
	var most: int = 0
	for tick: int in 2000:
		if not sequencer.is_busy():
			break
		sequencer.advance(1.0 / 60.0)
		most = maxi(most, sky.star_count())
		var shown: Vector2i = view.get("_shown_flow")
		if flows.is_empty() or flows.back() != shown:
			flows.append(shown)
	assert_eq(most, 3, "its stars show")
	assert_eq(flows, [Vector2i(-56, 0), Vector2i(56, 0)] as Array[Vector2i], "the water shows the tide turn")
	assert_eq(hud.message(), Hud.TIDE_MESSAGE, "the rule is said as the effect shows")
	assert_true(main.run.stars.is_empty())
