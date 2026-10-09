extends GutTest
## Leo's final: the whole Leo, where the lion breathes (the heat acts after every link as well as
## every launch, from the link outward), its arrival (the lion catches fire star by star and roars,
## then its title card) and the breath's preview while a link is traced.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)


func _run(seed_value: int = 7) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, StarMap.leo_final())


func _unlit_sizes(run: RunState) -> Dictionary:
	var sizes: Dictionary = {}
	for i: int in run.scorpio.map.count():
		if not run.scorpio.is_lit(i):
			sizes[i] = run.scorpio.map.sizes[i]
	return sizes


func _grown(size: int) -> int:
	return Star.Size.SMALL if size == Star.Size.BIG else size + 1


## A triple of `size` stars round landmark `index`, linking it: their ids, the landmark last.
func _triple_on(run: RunState, index: int) -> Array[int]:
	var size: int = run.scorpio.map.sizes[index]
	var at: Vector2i = run.scorpio.landmark_position(index)
	var a: Star = run.add_star(size as Star.Size, at + Vector2i(14, 16))
	var b: Star = run.add_star(size as Star.Size, at + Vector2i(-14, 18))
	return [a.id, b.id, Scorpio.landmark_id(index)] as Array[int]


func test_the_final_is_the_whole_lion_and_it_breathes() -> void:
	var map: StarMap = StarMap.leo_final()
	assert_eq(map.count(), 13)
	assert_eq(map.starting_lit, [9] as Array[int], "the tail tuft lit: twelve to light")
	assert_true(map.heat_on_links and map.heat_landmarks and map.heat_burns)
	assert_eq(map.heat_change, 1)
	assert_eq(map.arrival_epithet, "THE LION OF SUMMER")
	assert_false(map.orion or map.hunt or map.volley != "", "Orion stays in chapter 1")
	assert_eq(Chapter.new(ChapterDef.leo()).map_id(Chapter.FINAL), "leo_final")
	assert_eq(StarMap.by_id("leo_final").title, "LEO")


func test_a_link_breathes_heat_on_every_star_it_leaves_and_on_the_lion() -> void:
	var run: RunState = _run()
	var loose_small: Star = run.add_star(Star.Size.SMALL, Vector2i(20, 240))
	var loose_big: Star = run.add_star(Star.Size.BIG, Vector2i(160, 240))
	var ids: Array[int] = _triple_on(run, 8)
	var before: Dictionary = _unlit_sizes(run)
	var preview: Array[StarHeat.Change] = run.breath_preview(ids)
	watch_signals(run)
	assert_ne(run.link(ids), Combos.INVALID)
	assert_true(run.scorpio.is_lit(8))
	assert_eq(loose_small.size, Star.Size.MEDIUM, "a loose star grows")
	assert_false(run.stars.has(loose_big), "a loose big burns out")
	for i: int in before:
		if i != 8:
			assert_eq(run.scorpio.map.sizes[i], _grown(before[i]), "landmark %d grows (a big comes back small)" % i)
	assert_eq(run.scorpio.map.sizes[8], before[8], "the one it lit doesn't")
	var params: Array = get_signal_parameters(run, "heat_breathed")
	var centre: Vector2i = run.scorpio.landmark_position(8) + Vector2i(0, 34) / 3
	assert_eq(params[0], centre, "from the link's centre")
	var key := func(list: Array) -> Array:
		var keys: Array = []
		for change: StarHeat.Change in list:
			keys.append([change.star_id, change.to, change.lost, change.rekindled])
		keys.sort()
		return keys
	assert_eq(key.call(params[1]), key.call(preview), "the trace's preview is what happens")


func test_no_breath_from_an_invalid_link_or_the_one_that_completes_the_lion() -> void:
	var run: RunState = _run()
	var lone: Star = run.add_star(Star.Size.SMALL, Vector2i(20, 240))
	watch_signals(run)
	assert_eq(run.link([lone.id] as Array[int]), Combos.INVALID)
	assert_signal_not_emitted(run, "heat_breathed", "an invalid link uses nothing up and breathes nothing")
	for i: int in run.scorpio.map.count():
		if i != 8:
			run.scorpio.lit[i] = true
	assert_true(run.breath_preview(_triple_on(run, 8)).is_empty(), "the last one previews no breath")
	assert_ne(run.link(_triple_on(run, 8)), Combos.INVALID)
	assert_eq(run.outcome, RunState.Outcome.WON)
	assert_signal_not_emitted(run, "heat_breathed", "the winning link doesn't breathe")


func test_a_link_that_fills_the_sun_clears_the_sky_then_breathes_on_the_lion_alone() -> void:
	var run: RunState = _run()
	run.light = run.light_target() - 1
	run.add_star(Star.Size.SMALL, Vector2i(20, 240))
	var ids: Array[int] = _triple_on(run, 8)
	for change: StarHeat.Change in run.breath_preview(ids):
		assert_lt(change.star_id, 0, "only the lion's stars in the preview")
	watch_signals(run)
	assert_ne(run.link(ids), Combos.INVALID)
	assert_true(run.stars.is_empty())
	for change: StarHeat.Change in get_signal_parameters(run, "heat_breathed")[1]:
		assert_lt(change.star_id, 0)


func test_a_launch_heats_too_as_on_the_head() -> void:
	var run: RunState = _run()
	run.owned_packs["blue"] = 1
	run.loaded_pack = "blue"
	var before: Dictionary = _unlit_sizes(run)
	watch_signals(run)
	assert_true(run.launch(Vector2i(90, 200)))
	assert_signal_emitted(run, "landmarks_resized")
	assert_signal_not_emitted(run, "heat_breathed", "a launch isn't a breath")
	for i: int in before:
		assert_eq(run.scorpio.map.sizes[i], _grown(before[i]))


func test_the_lion_arrives_then_a_demo_link_breathes_on_three_stars() -> void:
	# #149: the breath, the final's own rule, was the one Leo rule with no demo of its effect.
	var run: RunState = _run()
	var sizes_before: Array[int] = run.scorpio.map.sizes.duplicate()
	var packs: Dictionary = run.owned_packs.duplicate()
	var order: Array[String] = []
	var placed: Array[Star] = []
	var link: Array[int] = []
	var breath: Array[StarHeat.Change] = []
	run.lion_arrived.connect(func() -> void: order.append("arrived"))
	run.heat_intro_placed.connect(func(stars: Array[Star]) -> void:
		order.append("placed")
		placed.append_array(stars))
	run.heat_intro_linked.connect(func(ids: Array[int]) -> void:
		order.append("linked")
		link.append_array(ids))
	run.heat_breathed.connect(func(_at: Vector2i, changes: Array[StarHeat.Change]) -> void:
		order.append("breathed")
		breath.append_array(changes))
	run.heat_intro_cleared.connect(func(_stars: Array[Star]) -> void: order.append("cleared"))
	watch_signals(run)
	run.play_heat_intro()
	assert_eq(order, ["arrived", "placed", "linked", "breathed", "cleared"] as Array[String])
	assert_eq(placed.size(), 6, "a small triple and a small, a medium and a big")
	assert_eq(link.size(), 3)
	for id: int in link:
		assert_eq(placed.filter(func(star: Star) -> bool: return star.id == id)[0].size, Star.Size.SMALL, "the link is the small triple")
	assert_eq(breath.size(), 3, "its breath changes the other three")
	var lost: int = 0
	for change: StarHeat.Change in breath:
		assert_gte(change.star_id, 0, "never the lion's own stars")
		assert_false(link.has(change.star_id))
		lost += int(change.lost)
		if not change.lost:
			assert_eq(change.to, change.from + 1, "a star grows")
	assert_eq(lost, 1, "and the big burns out")
	assert_signal_not_emitted(run, "landmarks_resized", "the lion's stars keep their sizes")
	assert_eq(run.scorpio.map.sizes, sizes_before)
	assert_true(run.stars.is_empty(), "it leaves no star")
	assert_eq(run.dust, 0, "and pays nothing")
	assert_eq(run.owned_packs, packs, "and uses no pack")


func test_the_breath_demo_never_shifts_the_packs() -> void:
	var skies: Array[Array] = []
	for demo: bool in [true, false]:
		var run: RunState = _run()
		if demo:
			run.play_heat_intro()
		var sky: Array[String] = []
		run.pack_burst.connect(func(_k: String, _at: Vector2i, stars: Array[Star]) -> void:
			for star: Star in stars:
				sky.append("%d:%s" % [star.size, star.position]))
		run.launch(Vector2i(90, 200))
		skies.append(sky)
	assert_eq(skies[0], skies[1], "the same first burst with or without it")


# --- The show ----------------------------------------------------------------------------------

func _main() -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = "leo_final"
	main.in_chapter = true
	main.seed_override = 3
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var view: ConstellationView = main.get_node("Sky/ConstellationLayer")
	for i: int in 400:
		sequencer.advance(0.02)
		view.advance(0.02)
		if not sequencer.is_busy() and not view.is_blazing() and not view.is_resizing():
			return


func test_the_lion_catches_fire_from_its_tail_then_roars_and_its_card_shows() -> void:
	var main: Main = _main()
	var view: ConstellationView = main.get_node("Sky/ConstellationLayer")
	var banner: BossBanner = (main.get_node("HUD") as Hud).boss_banner()
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var map: StarMap = main.run.scorpio.map
	var order: Array[int] = ConstellationView.blaze_order(map)
	assert_eq(order[0], 9, "from the tail tuft")
	assert_eq(order.size(), map.count(), "every star")
	for k: int in range(1, order.size()):
		var touches: bool = false
		for j: int in k:
			touches = touches or map.neighbours(order[k]).has(order[j])
		assert_true(touches, "%d catches from one already alight" % order[k])
	var roars: Array[int] = []
	view.roared.connect(func() -> void: roars.append(1))
	assert_true(sequencer.is_busy(), "play waits for the lion")
	sequencer.advance(0.01)
	assert_true(view.is_blazing())
	assert_eq(view.blaze_stage(order[-1]), 0, "the mouth is still dark")
	assert_false(banner.is_showing(), "the card waits for the roar")
	banner.advance(ConstellationView.roar_at(map) + 0.05)
	assert_true(banner.is_showing())
	_settle(main)
	assert_eq(roars.size(), 1, "it roared once")
	assert_false(sequencer.is_busy())


func test_a_link_breathes_a_heatwave_that_reaches_the_near_stars_first() -> void:
	var main: Main = _main()
	_settle(main)
	var run: RunState = main.run
	var sky: SkyView = main.get_node("Sky")
	var heat: HeatView = main.get_node("Sky/HeatLayer")
	var ids: Array[int] = _triple_on(run, 8)
	var near: Star = run.add_star(Star.Size.SMALL, run.scorpio.landmark_position(8) + Vector2i(30, -6))
	var far: Star = run.add_star(Star.Size.SMALL, Vector2i(170, 245))
	sky.setup(run, main.get_node("EventSequencer"))
	assert_ne(run.link(ids), Combos.INVALID)
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var near_view: StarView = _view(sky, near.id)
	var far_view: StarView = _view(sky, far.id)
	var near_at: float = -1.0
	var far_at: float = -1.0
	var t: float = 0.0
	var waved: bool = false
	for i: int in 200:
		sequencer.advance(0.02)
		heat.advance(0.02)
		t += 0.02
		for view: StarView in [near_view, far_view]:
			view.advance(0.02)
		waved = waved or heat.is_breathing()
		if near_at < 0.0 and near_view.size == Star.Size.MEDIUM:
			near_at = t
		if far_at < 0.0 and far_view.size == Star.Size.MEDIUM:
			far_at = t
		if not sequencer.is_busy() and near_at >= 0.0 and far_at >= 0.0:
			break
	assert_true(waved, "a heatwave rolled out")
	assert_gt(near_at, 0.0)
	assert_gt(far_at, near_at + 0.1, "the far star grows after the near one")


func _view(sky: SkyView, id: int) -> StarView:
	for child: Node in sky.get_node("StarLayer").get_children():
		if (child as StarView).star_id == id:
			return child
	return null


func test_the_heatwave_is_a_ring_that_rolls_out() -> void:
	var at := Vector2i(90, 160)
	var early: Dictionary[Vector2i, Color] = HeatView.breath_pixels(at, 0.05, SKY)
	var late: Dictionary[Vector2i, Color] = HeatView.breath_pixels(at, 0.2, SKY)
	var reach := func(dots: Dictionary[Vector2i, Color]) -> int:
		var r: int = 0
		for p: Vector2i in dots:
			r = maxi(r, (p - at).length_squared())
		return r
	assert_gt(reach.call(late), reach.call(early))
	assert_true(early.values().has(Palette.C2))
	for p: Vector2i in late:
		assert_true(SKY.has_point(p), "inside the sky")
	assert_true(HeatView.breath_pixels(at, HeatView.BREATH_TIME, SKY).is_empty())


func test_tracing_a_full_link_previews_its_breath() -> void:
	var main: Main = _main()
	_settle(main)
	var run: RunState = main.run
	var heat: HeatView = main.get_node("Sky/HeatLayer")
	var ids: Array[int] = _triple_on(run, 8)
	var other: Star = run.add_star(Star.Size.SMALL, Vector2i(30, 240))
	var idle: Dictionary[Vector2i, Color] = heat.pixels()
	heat.tracing = ids
	var dots: Dictionary[Vector2i, Color] = heat.pixels()
	var ring: int = 0
	for offset: Vector2i in StarView.outline_pixels(Star.Size.MEDIUM):
		ring += int(dots.get(other.position + offset) == HeatView.NEXT_COLOURS[Star.Size.MEDIUM])
	assert_gt(ring, 2, "a star the breath grows shows the size it becomes")
	heat.tracing = []
	assert_eq(heat.pixels().size(), idle.size())


func test_the_final_says_every_link_feeds_the_heat() -> void:
	assert_eq(Hud.heat_rule(StarHeat.new(1, true), true, true), Hud.BREATH_MESSAGE)
	for line: String in Hud.BREATH_MESSAGE.split("\n"):
		assert_lte(line.length(), 22)
		for c: String in line:
			assert_true(c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 +-/", c)


func test_the_stage_opens_with_the_lion_then_its_breath_shown_and_said() -> void:
	var main: Main = _main()
	var sky: SkyView = main.get_node("Sky")
	var hud: Hud = main.get_node("HUD")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var said: Array[bool] = [false]
	var demo_stars: Array[int] = [0]
	for tick: int in 600:
		if not sequencer.is_busy():
			break
		sequencer.advance(0.02)
		said[0] = said[0] or hud.message() == Hud.BREATH_MESSAGE
		demo_stars[0] = maxi(demo_stars[0], sky.star_count())
	assert_false(sequencer.is_busy(), "the opening plays out")
	assert_eq(demo_stars[0], 6, "the demo's stars show")
	assert_true(said[0], "and the rule is said as the breath shows")
	assert_true(main.run.stars.is_empty(), "play starts on an empty sky")
