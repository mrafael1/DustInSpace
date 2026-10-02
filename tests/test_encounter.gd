extends GutTest
## Orion's guided encounters (#93): the stage that introduces a threat guides the player through it
## once, the first time (only guiding: nothing is held back). The mark (the Tail) after his first
## mark, until the next link; the volley (the Body) from the start, until the first real volley; the
## hunting circle (the Heart) from the first real circle, until the next launch.

const MainScene := preload("res://game/scenes/main.tscn")
const AppScene := preload("res://game/scenes/app.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var steps: Array[Array] = []
var store_path: String = "user://test_encounter_%d.json" % randi()


func before_each() -> void:
	steps.clear()


func after_each() -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))


# --- Which threat ---------------------------------------------------------------------------

func test_each_threat_is_met_on_the_stage_that_introduces_it() -> void:
	assert_eq(Encounter.threat_of(StarMap.tail()), Encounter.Threat.MARK)
	assert_eq(Encounter.threat_of(StarMap.body()), Encounter.Threat.VOLLEY)
	assert_eq(Encounter.threat_of(StarMap.heart()), Encounter.Threat.HUNT)
	for id: String in ["stinger", "claws", "final", "scorpio"]:
		assert_eq(Encounter.threat_of(StarMap.by_id(id)), -1, "%s: none to meet" % id)
	assert_eq(Encounter.threat_name(Encounter.Threat.HUNT), "hunt")


func test_the_steps_go_waiting_guiding_done_and_only_for_their_threat() -> void:
	var e := Encounter.new(Encounter.Threat.MARK)
	assert_false(e.linked(), "nothing to end before it guides")
	assert_false(e.opened(), "the volley's start isn't the mark's")
	assert_false(e.area_marked())
	assert_true(e.marked())
	assert_true(e.is_guiding())
	assert_false(e.marked(), "once")
	assert_false(e.launched(), "a launch doesn't end the mark's")
	assert_true(e.linked())
	assert_true(e.is_done())
	assert_false(e.linked(), "done stays done")


# --- The mark (the Tail) --------------------------------------------------------------------

func test_the_mark_guides_after_his_first_mark_until_the_next_link() -> void:
	var run: RunState = _run(StarMap.tail())
	assert_true(run.start_encounter())
	assert_eq(steps, [] as Array[Array], "it waits for the mark")
	run.launch(Vector2i(100, 190))
	assert_not_null(run.marked_star())
	assert_eq(steps, [[Encounter.Threat.MARK, Encounter.Step.GUIDING]] as Array[Array])
	var link: Array[int] = run.encounter_link()
	if not link.is_empty():
		assert_true(link.has(run.marked_star().id), "the guide's link saves the marked star")
		assert_ne(run.combo_for(link), Combos.INVALID)
		assert_true(run.link_in_reach(link))
	var trio: Array[int] = _corner_trio(run)
	run.link(trio)
	assert_eq(steps[-1], [Encounter.Threat.MARK, Encounter.Step.DONE], "linking elsewhere ends it: the arrow shows")
	assert_eq(steps.size(), 2)
	assert_false(run.start_encounter(), "one encounter a run")


func test_saving_the_mark_ends_it_too() -> void:
	var run: RunState = _run(StarMap.tail())
	run.start_encounter()
	run.launch(Vector2i(100, 190))
	var target: Star = run.marked_star()
	var link: Array[int] = [target.id, run.add_star(target.size, target.position + Vector2i(6, 0)).id, run.add_star(target.size, target.position + Vector2i(0, 6)).id]
	assert_eq(run.encounter_link().has(target.id), true)
	assert_ne(run.link(link), Combos.INVALID)
	assert_eq(steps[-1], [Encounter.Threat.MARK, Encounter.Step.DONE])


# --- The volley (the Body) ------------------------------------------------------------------

func test_the_volley_guides_from_the_start_until_the_first_real_volley() -> void:
	var run: RunState = _run(StarMap.body())
	run.play_volley_intro()
	assert_eq(steps, [] as Array[Array], "the intro volley isn't the encounter")
	assert_true(run.start_encounter())
	assert_eq(steps, [[Encounter.Threat.VOLLEY, Encounter.Step.GUIDING]] as Array[Array], "it guides at once")
	for i: int in run.volley.interval - 1:
		run.link(_corner_trio(run))
		assert_eq(steps.size(), 1, "counting, not yet")
	run.link(_corner_trio(run))
	assert_eq(steps[-1], [Encounter.Threat.VOLLEY, Encounter.Step.DONE], "the first real volley ends it")


# --- The hunting circle (the Heart) ---------------------------------------------------------

func test_the_circle_guides_from_the_first_real_circle_until_the_next_launch() -> void:
	var run: RunState = _run(StarMap.heart())
	run.play_hunt_intro()
	assert_true(run.start_encounter())
	assert_eq(steps, [] as Array[Array], "the intro's circle doesn't count")
	run.launch(Vector2i(100, 190))
	assert_true(run.hunt.has_area())
	assert_eq(steps, [[Encounter.Threat.HUNT, Encounter.Step.GUIDING]] as Array[Array], "the first real circle")
	var spot: Vector2i = run.safe_launch_spot()
	var clear: int = run.hunt.radius + RunState.ENCOUNTER_CLEARANCE
	assert_gt((spot - run.hunt.centre).length_squared(), clear * clear, "the spot keeps the burst out of the circle")
	assert_true(run.sky_rect.has_point(spot))
	run.launch(spot)
	assert_eq(steps[-1], [Encounter.Threat.HUNT, Encounter.Step.DONE], "the next launch ends it, wherever it lands")


func test_the_safe_spot_prefers_an_unlit_star_clear_of_the_circle() -> void:
	var run: RunState = _run(StarMap.heart())
	run.launch(Vector2i(100, 190))
	var spot: Vector2i = run.safe_launch_spot()
	var on_star: bool = false
	for i: int in run.scorpio.map.count():
		on_star = on_star or (run.scorpio.landmark_position(i) == spot and not run.scorpio.is_lit(i))
	var clear: int = run.hunt.radius + RunState.ENCOUNTER_CLEARANCE
	var any_clear: bool = false
	for i: int in run.scorpio.map.count():
		var at: Vector2i = run.scorpio.landmark_position(i)
		any_clear = any_clear or (not run.scorpio.is_lit(i) and (at - run.hunt.centre).length_squared() > clear * clear)
	assert_eq(on_star, any_clear, "an unlit star when one is clear, else a corner")


func test_no_encounter_where_there_is_no_threat_to_meet() -> void:
	for map: StarMap in [StarMap.stinger(), StarMap.claws()]:
		var run: RunState = _run(map)
		assert_false(run.start_encounter())
		assert_null(run.encounter)
		run.launch(Vector2i(100, 190))
		assert_eq(steps, [] as Array[Array])


# --- The scenes -----------------------------------------------------------------------------

func test_main_plays_it_only_when_asked_and_the_guide_shows_then_goes() -> void:
	var main: Main = _main("tail", true)
	var guide: TutorialView = (main.get_node("HUD") as Hud).tutorial_guide()
	var finished: Array[int] = []
	main.encounter_finished.connect(func(threat: int) -> void: finished.append(threat))
	main.run.launch(Vector2i(100, 190))
	_play(main)
	assert_eq(guide.text(), Hud.ENCOUNTER_LINES[Encounter.Threat.MARK], "the line")
	assert_true(guide.has_hand(), "the hand on the marked star or acting the link out")
	assert_false(guide.waits_for_tap(), "it only guides")
	main.run.link(_corner_trio(main.run))
	_play(main)
	assert_eq(guide.text(), "", "gone once done")
	assert_eq(finished, [Encounter.Threat.MARK] as Array[int])
	assert_false(main.encounter, "not again this session")
	var quiet: Main = _main("tail", false)
	quiet.run.launch(Vector2i(100, 190))
	_play(quiet)
	assert_eq((quiet.get_node("HUD") as Hud).tutorial_guide().text(), "", "no encounter unless asked")


func test_the_volley_guide_points_at_the_countdown_and_says_the_interval() -> void:
	var main: Main = _main("body", true)
	_play(main)
	var hud: Hud = main.get_node("HUD")
	var guide: TutorialView = hud.tutorial_guide()
	assert_eq(guide.text(), Hud.ENCOUNTER_LINES[Encounter.Threat.VOLLEY] % main.run.volley.interval)
	assert_eq(guide.target(), Vector2i(hud.get_node("VolleyCountdown").position))


func test_the_lines_fit_beside_orions_corner() -> void:
	var main: Main = _main("heart", true)
	var label := Label.new()
	label.label_settings = HudText.primary(Palette.C1)
	add_child_autofree(label)
	for threat: int in Hud.ENCOUNTER_LINES:
		label.text = (Hud.ENCOUNTER_LINES[threat] as String).replace("%d", "2")
		assert_lte(label.get_minimum_size().x, float(ScreenZones.SCREEN.x - Hud.ENCOUNTER_LINE_LEFT), "fits right of his corner")
		assert_eq(label.text.count("\n"), 1, "two lines")
	var figure_right: int = OrionView.FIGURE_AT.x + 33
	assert_gt(Hud.ENCOUNTER_LINE_LEFT, figure_right, "clear of the figure")
	assert_not_null(main)


func test_the_app_plays_each_encounter_once_and_saves_it() -> void:
	var chapter := Chapter.new()
	for stage: int in 3:
		chapter.complete(stage)
	ProgressStore.new(store_path).save_chapter(Chapter.ID, chapter.to_save())
	var app: App = AppScene.instantiate()
	app.progress_path = store_path
	add_child_autofree(app)
	app.open_stage(1)
	assert_true(app.stage().encounter, "the Tail's first play meets the mark")
	app.stage().run.encounter_step.emit(Encounter.Threat.MARK, Encounter.Step.DONE)
	assert_true(app.encounters_met.get("mark", false))
	app.back_to_chart()
	app.open_stage(1)
	assert_false(app.stage().encounter, "not on a replay")
	app.back_to_chart()
	app.open_stage(2)
	assert_true(app.stage().encounter, "the Body's volley is still to meet")
	app.back_to_chart()
	var again: App = AppScene.instantiate()
	again.progress_path = store_path
	add_child_autofree(again)
	assert_true(again.encounters_met.get("mark", false), "saved")
	again.open_stage(0)
	assert_false(again.stage().encounter, "the Stinger has none")


func _main(map: String, with_encounter: bool) -> Main:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	main.star_map = map
	main.encounter = with_encounter
	add_child_autofree(main)
	assert_true(main.start_run(Balance.from_dict(_balance_dict())))
	for node: Node in [main.get_node("EventSequencer"), main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)
	return main


func _play(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 200:
		if not sequencer.is_busy():
			return
		sequencer.advance(0.1)


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	data["hunt"] = {"radius": 38, "intro_stars": 3}
	return data


func _run(map: StarMap) -> RunState:
	var run := RunState.new(Balance.from_dict(_balance_dict()), Fixtures.rng(), Fixtures.SKY, map)
	run.encounter_step.connect(func(threat: int, step: int) -> void: steps.append([threat, step]))
	return run


## Three small stars in Orion's corner: a triple with nothing else in reach. Their ids.
func _corner_trio(run: RunState) -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		ids.append(run.add_star(Star.Size.SMALL, Vector2i(24, 100) + offset).id)
	return ids
