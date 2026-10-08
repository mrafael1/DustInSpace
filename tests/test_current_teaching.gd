extends GutTest
## Issue #128: a current's rule is said before the first launch is committed (as the player first
## aims), names the loss on every draining stage, and a turning flow points at the edge its next
## launch drains to. Aquarius's final arrives with its box coming alight and its title card.

const MainScene := preload("res://game/scenes/main.tscn")


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 7
	add_child_autofree(main)
	return main


## Lets the stage settle until the telescope aims (it aims on its own once a planet is loaded).
func _settle_until_aiming(main: Main) -> void:
	var telescope: Telescope = main.get_node("Telescope")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for tick: int in 200:
		if telescope.is_aiming():
			return
		sequencer.advance(0.03)
		telescope.advance(0.03)


func test_the_rule_is_said_as_the_player_first_aims_before_any_launch() -> void:
	var main: Main = _main("aquarius_body")
	var hud: Hud = main.get_node("HUD")
	var telescope: Telescope = main.get_node("Telescope")
	_settle_until_aiming(main)
	assert_true(telescope.is_aiming())
	assert_eq(main.run.total_packs(), 3, "nothing launched yet")
	assert_eq(hud.message(), Hud.DRAIN_MESSAGE, "said before the first launch is committed")
	hud.clear_message()
	telescope.cancel_aim()
	assert_true(telescope.start_aim())
	assert_eq(hud.message(), "", "once a run: aiming again says nothing new")
	hud.clear_message()
	assert_true(main.restart())
	if not telescope.is_aiming():
		_settle_until_aiming(main)
		if not telescope.is_aiming():
			assert_true(telescope.start_aim())
	assert_eq(hud.message(), Hud.DRAIN_MESSAGE, "a retry hears it again, before its first launch")
	assert_eq(main.run.total_packs(), 3)


func test_a_quick_launch_keeps_the_rule_on_show() -> void:
	var main: Main = _main("aquarius_body")
	var hud: Hud = main.get_node("HUD")
	var telescope: Telescope = main.get_node("Telescope")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	_settle_until_aiming(main)
	assert_eq(hud.message(), Hud.DRAIN_MESSAGE)
	telescope.handle_pointer(_touch(Vector2i(0, -150), true))
	telescope.handle_pointer(_touch(Vector2i(0, -150), false))
	assert_eq(main.run.total_packs(), 2, "launched at once")
	assert_eq(hud.message(), Hud.DRAIN_MESSAGE, "the launch doesn't wipe the rule (#152)")
	for tick: int in int((Hud.TEACHING_HOLD - 0.1) / 0.05):
		sequencer.advance(0.05)
		telescope.advance(0.05)
		hud.advance(0.05)
	assert_eq(hud.message(), Hud.DRAIN_MESSAGE, "nor the burst and reload after it")


func _touch(point: Vector2i, pressed: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(point)
	touch.pressed = pressed
	return touch


func test_every_draining_stage_names_the_loss_and_every_line_fits() -> void:
	var rules: Dictionary[String, String] = {
		"aquarius_hand": Hud.FLOW_MESSAGE, "aquarius_body": Hud.DRAIN_MESSAGE, "aquarius_legs": Hud.DRAIN_MESSAGE,
		"aquarius_stream": Hud.DRAIN_MESSAGE, "aquarius_jar": Hud.TIDE_MESSAGE, "aquarius_final": Hud.BOX_MESSAGE,
	}
	for map_id: String in rules:
		var run := RunState.new(Balance.load_file(), RandomNumberGenerator.new(), Scorpio.HOME_SKY, StarMap.by_id(map_id))
		assert_eq(Hud.current_rule(run.current), rules[map_id], map_id)
		if run.current.drains:
			assert_true("DRAIN" in rules[map_id] or "LOST" in rules[map_id], "%s says stars are lost" % map_id)
	for text: String in rules.values():
		for line: String in text.split("\n"):
			assert_lte(line.length(), 22, "'%s' fits the 132 px message line" % line)


func test_a_turning_flow_points_at_the_edge_its_next_launch_drains_to() -> void:
	var main: Main = _main("aquarius_jar")
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var area: Rect2i = main.run.current.region
	var mid_y: int = area.position.y + area.size.y / 2
	var left_tip := Vector2i(area.position.x + CurrentView.CHEVRON_IN, mid_y)
	var right_tip := Vector2i(area.end.x - 1 - CurrentView.CHEVRON_IN, mid_y)
	assert_eq(view.pixels().get(left_tip), Palette.S4, "the tide runs left: chevrons at the left drain")
	assert_eq(view.pixels().get(left_tip + Vector2i(1, -1)), Palette.S4, "pointing at it")
	assert_ne(view.pixels().get(right_tip), Palette.S4)
	main.run.current.turn()
	view.advance(0.0)
	assert_eq(view.pixels().get(right_tip), Palette.S4, "after the turn, at the right")
	assert_ne(view.pixels().get(left_tip), Palette.S4)
	var body: CurrentView = _main("aquarius_body").get_node("Sky/CurrentLayer")
	var one_way: Rect2i = (body.get_parent().get_parent() as Main).run.current.region
	assert_ne(body.pixels().get(Vector2i(one_way.position.x + CurrentView.CHEVRON_IN, one_way.position.y + one_way.size.y / 2)), Palette.S4, "a flow that never turns needs no chevrons")


func test_the_final_arrives_with_its_box_coming_alight_and_its_title() -> void:
	var main: Main = _main("aquarius_final")
	var view: CurrentView = main.get_node("Sky/CurrentLayer")
	var hud: Hud = main.get_node("HUD")
	var banner: BossBanner = hud.boss_banner()
	assert_true(banner.is_showing(), "AQUARIUS / THE WATER BEARER, at once")
	assert_true(view.is_arriving())
	var area: Rect2i = main.run.current.region
	var bottom := Vector2i(area.position.x + area.size.x / 2, area.end.y - 1)
	var left := Vector2i(area.position.x, area.position.y + area.size.y / 2 + 1)
	assert_eq(view.pixels().get(left), Palette.S4, "the first side flares")
	assert_ne(view.pixels().get(bottom), Palette.S4, "the next waits its turn")
	view.advance(CurrentView.ARRIVAL_STEP * 1.5)
	assert_eq(view.pixels().get(bottom), Palette.S4, "then the next, in the flow's order")
	view.advance(CurrentView.ARRIVAL_STEP * 4)
	assert_false(view.is_arriving(), "then it settles")
	banner.advance(Hud.ARRIVAL_TIME + 0.1)
	assert_false(banner.is_showing())
	for map_id: String in ["aquarius_hand", "aquarius_jar"]:
		var stage: Main = _main(map_id)
		assert_false((stage.get_node("HUD") as Hud).boss_banner().is_showing(), "%s has no arrival" % map_id)
		assert_false((stage.get_node("Sky/CurrentLayer") as CurrentView).is_arriving())


func test_chevrons_slide_clear_of_crowding_stars() -> void:
	var area := Rect2i(24, 78, 132, 172)
	var plain: Dictionary[Vector2i, Color] = CurrentView.chevron_pixels(area, Vector2i.LEFT)
	var mid_tip := Vector2i(area.position.x + CurrentView.CHEVRON_IN, area.position.y + area.size.y / 2)
	assert_true(plain.has(mid_tip))
	var crowded: Dictionary[Vector2i, Color] = CurrentView.chevron_pixels(area, Vector2i.LEFT, [mid_tip] as Array[Vector2i])
	assert_eq(crowded.size(), plain.size(), "still three chevrons")
	assert_false(crowded.has(mid_tip), "the one under a star moved")
	for p: Vector2i in crowded:
		assert_gt(p.distance_to(Vector2(mid_tip)), 4.0, "clear of the star")


func test_a_finger_letting_the_launch_go_hides_the_drift_preview() -> void:
	var main: Main = _main("aquarius_body")
	var telescope: Telescope = main.get_node("Telescope")
	var current: CurrentView = main.get_node("Sky/CurrentLayer")
	_settle_until_aiming(main)
	var press := InputEventScreenTouch.new()
	press.device = 0
	press.pressed = true
	press.position = Vector2(Vector2i(60, 150) - telescope.origin())
	telescope.handle_pointer(press)
	main._process(0.0)
	assert_true(current.aiming, "a finger aiming shows the drift preview")
	var low := InputEventScreenDrag.new()
	low.device = 0
	low.position = Vector2(Vector2i(60, main.run.sky_rect.end.y + Telescope.TOUCH_LIFT) - telescope.origin())
	telescope.handle_pointer(low)
	assert_true(telescope.is_letting_go())
	main._process(0.0)
	assert_false(current.aiming, "let go: the preview goes with the scatter ring")
