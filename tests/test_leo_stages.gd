extends GutTest
## Chapter 3, Leo: its chart figure, the Tail (the heat alone, which only helps) and the Haunch
## (burning arrives), and how the heat shows: the field, the aim's preview and the resize.

const MainScene := preload("res://game/scenes/main.tscn")
const SKY := Rect2i(0, 78, 180, 172)
const Fixtures := preload("res://tests/fixtures.gd")


func _check_pickable(map: StarMap) -> void:
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]), "%s star %d in the sky" % [map.id, i])
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
	assert_eq(map.segment_count(), map.count() - 1, "the strings form a tree")
	assert_eq(map.sizes.size(), map.count())
	assert_false(map.orion or map.hunt or map.volley != "", "Orion stays in chapter 1")
	assert_false(map.current_region.has_area(), "Aquarius's current stays in chapter 2")


func test_the_leo_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.leo()
	var figure: StarMap = def.figure
	assert_eq(figure.count(), 13)
	assert_eq(figure.segment_count(), 12, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(Scorpio.HOME_SKY)
	for i: int in figure.count():
		assert_true(inner.has_point(figure.landmarks[i]), "star %d sits in the sky" % i)
		assert_gt(Vector2(figure.landmarks[i]).distance_to(Vector2(def.final_at)), 24.0, "the crown keeps clear")
		for j: int in range(i + 1, figure.count()):
			assert_gte(Vector2(figure.landmarks[i]).distance_to(Vector2(figure.landmarks[j])), 24.0, "%d and %d" % [i, j])
	assert_eq(figure.path(9, 0), [9, 8, 4, 3, 2, 1, 0] as Array[int], "the tail reaches the mouth along the back and the Sickle")
	var owned: Array[int] = []
	for stage: int in Chapter.FINAL:
		owned.append_array(def.stages[stage]["stars"])
	owned.sort()
	assert_eq(owned, range(13), "every star belongs to exactly one part")
	assert_eq(StarMap.by_id("leo").title, "LEO")


func test_leo_opens_once_aquarius_is_won_and_builds_its_first_stages() -> void:
	var leo := Chapter.new(ChapterDef.leo())
	assert_eq(leo.id, "leo")
	assert_eq(leo.def.number, 3)
	assert_eq(leo.stage_name(0), "TAIL")
	assert_eq(leo.map_id(0), "leo_tail")
	assert_eq(leo.map_id(1), "leo_haunch")
	assert_eq(leo.map_id(2), "leo_heart")
	assert_eq(leo.map_id(3), "leo_mane")
	for stage: int in range(4, Chapter.stage_count()):
		assert_eq(leo.map_id(stage), "", "%s is still to come" % leo.stage_name(stage))


func test_the_tail_teaches_a_heat_that_only_helps() -> void:
	var map: StarMap = StarMap.leo_tail()
	_check_pickable(map)
	assert_eq(map.starting_lit, [0] as Array[int], "five to light")
	assert_eq(map.heat_change, 1)
	assert_false(map.heat_burns, "nothing burns yet")
	assert_eq(map.sizes[5], Star.Size.BIG, "the tuft is big: the heat ripens what it needs")
	assert_eq(StarMap.by_id("leo_tail").title, "TAIL")


func test_the_haunch_brings_burning() -> void:
	var map: StarMap = StarMap.leo_haunch()
	_check_pickable(map)
	assert_eq(map.starting_lit, [0] as Array[int], "six to light")
	assert_eq(map.heat_change, 1)
	assert_true(map.heat_burns)
	assert_eq(StarMap.by_id("leo_haunch").title, "HAUNCH")


func test_the_heart_brings_the_cold() -> void:
	var map: StarMap = StarMap.leo_heart()
	_check_pickable(map)
	assert_eq(map.starting_lit, [0] as Array[int], "five to light")
	assert_eq(map.heat_change, -1, "the cold")
	assert_true(map.heat_burns, "a small one fades")
	assert_false(map.heat_turns)
	assert_eq(map.sizes[2], Star.Size.BIG, "Regulus is big: its big has one launch before it shrinks")
	assert_eq(StarMap.by_id("leo_heart").title, "HEART")


func test_the_mane_turns_day_and_night() -> void:
	var map: StarMap = StarMap.leo_mane()
	_check_pickable(map)
	assert_eq(map.starting_lit, [0] as Array[int], "six to light")
	assert_eq(map.heat_change, 1, "day first")
	assert_true(map.heat_burns)
	assert_true(map.heat_turns)
	assert_eq(map.sizes[2], Star.Size.BIG, "Algieba is big")
	assert_eq(StarMap.by_id("leo_mane").title, "MANE")


func test_each_heat_says_its_rule() -> void:
	assert_eq(Hud.heat_rule(StarHeat.new(1, false)), Hud.HEAT_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(1, true)), Hud.BURN_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(-1, false)), Hud.COLD_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(-1, true)), Hud.FADE_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(1, true, true)), Hud.DAY_NIGHT_MESSAGE)
	for message: String in [Hud.HEAT_MESSAGE, Hud.BURN_MESSAGE, Hud.COLD_MESSAGE, Hud.FADE_MESSAGE, Hud.DAY_NIGHT_MESSAGE]:
		for line: String in message.split("\n"):
			assert_lte(line.length(), 22, line)
			for c: String in line:
				assert_true(c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 +-/", "%s: the 5x7 font has '%s'" % [line, c])


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	add_child_autofree(main)
	return main


func test_embers_rise_over_the_whole_sky_with_no_edges() -> void:
	var main: Main = _main("leo_haunch")
	var view: HeatView = main.get_node("Sky/HeatLayer")
	assert_true(view.is_processing())
	var sky: Rect2i = main.run.sky_rect
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	assert_between(dots.size(), 40, 90, "about one ember (two pixels) per 900 px²")
	var left: bool = false
	var right: bool = false
	for point: Vector2i in dots:
		assert_true(sky.has_point(point), "the embers stay in the sky")
		assert_true(dots[point] in [Palette.S2, Palette.S3], "embers, never the warm C ramp")
		left = left or point.x < sky.position.x + sky.size.x / 3
		right = right or point.x > sky.end.x - sky.size.x / 3
	assert_true(left and right, "across the whole stage")
	var before: Dictionary[Vector2i, Color] = view.pixels()
	view.advance(1.0)
	assert_ne(view.pixels(), before, "the embers rise")


func test_no_heat_no_field() -> void:
	var main: Main = _main("aquarius_hand")
	var view: HeatView = main.get_node("Sky/HeatLayer")
	assert_false(view.is_processing())
	assert_true(view.pixels().is_empty())


func test_the_aim_previews_each_change_round_its_star() -> void:
	var main: Main = _main("leo_haunch")
	var run: RunState = main.run
	var view: HeatView = main.get_node("Sky/HeatLayer")
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(100, 120))
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(80, 230))
	var idle: Dictionary[Vector2i, Color] = view.pixels()
	view.aiming = true
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	var outline: int = 0
	for offset: Vector2i in StarView.outline_pixels(Star.Size.MEDIUM):
		if dots.get(small.position + offset) == HeatView.NEXT_COLOURS[Star.Size.MEDIUM]:
			outline += 1
	assert_gt(outline, 3, "the small one shows the medium it will become")
	var top: Vector2i = big.position + Vector2i(0, -StarView.half_extent(Star.Size.BIG) - 2)
	assert_eq(dots.get(top + Vector2i(0, -5)), Palette.S4, "the big one wears a crown of flames: it burns")
	var ember: int = 0
	for offset: Vector2i in StarView.outline_pixels(Star.Size.BIG):
		ember += int(dots.get(big.position + offset) == Palette.S4)
	assert_gt(ember, 3, "and an ember ring")
	view.aiming = false
	assert_eq(view.pixels().size(), idle.size(), "only while aiming")


func test_a_launch_resizes_and_burns_the_star_views() -> void:
	var main: Main = _main("leo_haunch")
	var run: RunState = main.run
	var sky: SkyView = main.get_node("Sky")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(100, 120))
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(80, 230))
	sky.setup(run, sequencer)
	var small_view: StarView = _view(sky, small.id)
	var big_view: StarView = _view(sky, big.id)
	watch_signals(sky)
	assert_true(run.launch(Vector2i(160, 200)))
	assert_eq(small_view.size, Star.Size.SMALL, "the view waits for its event")
	for i: int in 120:
		sequencer.advance(0.03)
		for child: Node in sky.get_node("StarLayer").get_children():
			if is_instance_valid(child) and not child.is_queued_for_deletion():
				(child as StarView).advance(0.03)
		if not sequencer.is_busy():
			break
	assert_eq(small_view.size, Star.Size.MEDIUM, "it grew where it stands")
	assert_false(small_view.is_resizing())
	assert_true(not is_instance_valid(big_view) or big_view.is_queued_for_deletion(), "the big one burned out")
	assert_signal_emitted(sky, "star_burned")


func _view(sky: SkyView, id: int) -> StarView:
	for child: Node in sky.get_node("StarLayer").get_children():
		if (child as StarView).star_id == id:
			return child
	return null


func test_a_resize_flares_then_glints_at_the_new_size() -> void:
	var view: StarView = preload("res://game/scenes/star_view.tscn").instantiate()
	add_child_autofree(view)
	view.setup(Star.new(1, Star.Size.SMALL, Vector2i(90, 160)), SKY)
	view.resize_to(Star.Size.MEDIUM)
	assert_true(view.is_resizing())
	view.advance(StarView.RESIZE_FLARE * 0.5)
	assert_eq(view.size, Star.Size.SMALL, "it flares at its old size first")
	view.advance(StarView.RESIZE_FLARE)
	assert_eq(view.size, Star.Size.MEDIUM)
	view.advance(StarView.RESIZE_TIME)
	assert_false(view.is_resizing())


func test_the_next_size_outline_rings_the_star() -> void:
	for size: int in [Star.Size.MEDIUM, Star.Size.BIG]:
		var ring: Array[Vector2i] = StarView.outline_pixels(size as Star.Size)
		assert_gt(ring.size(), 4)
		# (Where the smaller star it rings reaches past it, that star draws over it.)
		for offset: Vector2i in ring:
			assert_false(StarView._is_star_pixel(size as Star.Size, offset), "outside its own sprite")


func test_the_cold_previews_each_shrink_and_a_snowflake_on_a_star_that_fades() -> void:
	var main: Main = _main("leo_heart")
	var run: RunState = main.run
	var view: HeatView = main.get_node("Sky/HeatLayer")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	while sequencer.is_busy():
		sequencer.advance(0.1)
	var small: Star = run.add_star(Star.Size.SMALL, Vector2i(100, 120))
	var big: Star = run.add_star(Star.Size.BIG, Vector2i(80, 230))
	view.aiming = true
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	var ring: int = 0
	for offset: Vector2i in StarView.outline_pixels(Star.Size.BIG):
		ring += int(dots.get(big.position + offset) == HeatView.NEXT_COLOURS[Star.Size.MEDIUM])
	assert_gt(ring, 3, "the big one is ringed in the medium's colour: it shrinks to one")
	var frost: int = 0
	for offset: Vector2i in StarView.outline_pixels(Star.Size.SMALL):
		frost += int(dots.get(small.position + offset) == HeatView.FROST)
	assert_gt(frost, 2, "the small one wears frost")
	var top: Vector2i = small.position + Vector2i(0, -StarView.half_extent(Star.Size.SMALL) - 2)
	assert_eq(dots.get(top + Vector2i(0, -3)), Palette.M6, "the small one wears a snowflake: it fades")
	var over_big: Vector2i = big.position + Vector2i(0, -StarView.half_extent(Star.Size.BIG) - 5)
	assert_ne(dots.get(over_big), Palette.M6, "no snowflake on one that only shrinks")


func test_frost_falls_in_the_cold() -> void:
	var main: Main = _main("leo_heart")
	var view: HeatView = main.get_node("Sky/HeatLayer")
	assert_eq(view.shown_change(), -1)
	for colour: Color in view.pixels().values():
		assert_true(colour in HeatView.COLD_COLOURS, "frost, not embers")


func test_the_sky_turns_to_night_once_the_launch_has_played_out() -> void:
	var main: Main = _main("leo_mane")
	var run: RunState = main.run
	var view: HeatView = main.get_node("Sky/HeatLayer")
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	assert_eq(view.shown_change(), 1, "day: embers rise")
	run.owned_packs["blue"] = 1
	run.loaded_pack = "blue"
	assert_true(run.launch(Vector2i(60, 200)))
	assert_eq(run.heat.change, -1, "the core turned at once")
	view.advance(0.01)
	assert_eq(view.shown_change(), 1, "the sky waits while the launch plays")
	for i: int in 200:
		sequencer.advance(0.03)
		if not sequencer.is_busy():
			break
	view.advance(0.01)
	assert_eq(view.shown_change(), -1, "then night falls")
	for colour: Color in view.pixels().values():
		assert_true(colour in HeatView.COLD_COLOURS)


func test_a_faded_star_falls_as_frost() -> void:
	var at := Vector2i(90, 160)
	assert_false(HeatView.fade_pixels(at, 0.0).is_empty())
	var late: Dictionary[Vector2i, Color] = HeatView.fade_pixels(at, HeatView.BURN_TIME * 0.9)
	var lowest: int = at.y
	for point: Vector2i in late:
		assert_true(late[point] in [Palette.M5, Palette.M6], "frost colours")
		lowest = maxi(lowest, point.y)
	assert_gt(lowest, at.y + 8, "the flakes fall")
	assert_true(HeatView.fade_pixels(at, HeatView.BURN_TIME).is_empty())


# --- The heat's and the cold's intros: the effect shown as the stage opens --------------------

func _intro_run(map: StarMap, seed_value: int = 7) -> RunState:
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)


func test_the_tail_opens_by_showing_the_heat_grow_three_stars() -> void:
	var run: RunState = _intro_run(StarMap.leo_tail())
	var packs: Dictionary = run.owned_packs.duplicate()
	watch_signals(run)
	run.play_heat_intro()
	var placed: Array = get_signal_parameters(run, "heat_intro_placed")[0]
	var sizes: Array[int] = []
	for star: Star in placed:
		sizes.append(star.size)
		assert_false(run.scorpio.is_landmark(star.id))
	assert_eq(sizes, [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG] as Array[int], "one of each size")
	assert_signal_emit_count(run, "stars_resized", 2, "small to medium to big; medium to big")
	assert_signal_emit_count(run, "heat_intro_paused", 2, "a beat before the second change and before they go")
	var left: Array = get_signal_parameters(run, "heat_intro_cleared")[0]
	assert_eq(left.size(), 3, "three bigs: nothing burns on the Tail")
	for star: Star in left:
		assert_eq(star.size, Star.Size.BIG)
	assert_true(run.stars.is_empty(), "it leaves no star")
	assert_eq(run.dust, 0, "and pays nothing")
	assert_eq(run.owned_packs, packs, "and uses no pack")
	assert_eq(run.heat.change, 1)


func test_the_heart_opens_by_showing_the_cold_shrink_and_fade_them_all() -> void:
	var run: RunState = _intro_run(StarMap.leo_heart())
	watch_signals(run)
	run.play_heat_intro()
	assert_signal_emit_count(run, "stars_resized", 3, "big to medium to small to gone")
	var faded: int = 0
	for i: int in 3:
		for change: StarHeat.Change in get_signal_parameters(run, "stars_resized", i)[0]:
			assert_true(change.is_cold())
			faded += int(change.lost)
	assert_eq(faded, 3, "every one fades in the end")
	assert_signal_not_emitted(run, "heat_intro_cleared", "the cold empties the sky itself")
	assert_true(run.stars.is_empty())


func test_the_intro_never_shifts_the_packs() -> void:
	var sizes: Array = [[], []]
	for k: int in 2:
		var run: RunState = _intro_run(StarMap.leo_heart(), 11)
		if k == 1:
			run.play_heat_intro()
		watch_signals(run)
		for i: int in 2:
			Fixtures.launch(run, Vector2i(40 + 60 * i, 200))
			for star: Star in get_signal_parameters(run, "pack_burst")[2]:
				sizes[k].append(star.size)
	assert_eq(sizes[0], sizes[1], "the same packs open with or without it")


func test_only_the_stages_that_bring_the_heat_or_the_cold_show_it_once_as_they_open() -> void:
	for id: String in ["leo_haunch", "leo_mane", "aquarius_hand"]:
		var run: RunState = _intro_run(StarMap.by_id(id))
		watch_signals(run)
		run.play_heat_intro()
		assert_signal_not_emitted(run, "heat_intro_placed", id)
	var started: RunState = _intro_run(StarMap.leo_tail())
	started.add_star(Star.Size.SMALL, Vector2i(100, 120))
	watch_signals(started)
	started.play_heat_intro()
	assert_signal_not_emitted(started, "heat_intro_placed", "not once the run has begun")


func test_the_stage_opens_with_the_intro_and_play_starts_on_an_empty_sky() -> void:
	for id: String in ["leo_tail", "leo_heart"]:
		var main: Main = _main(id)
		var sky: SkyView = main.get_node("Sky")
		var sequencer: EventSequencer = main.get_node("EventSequencer")
		assert_true(sequencer.is_busy(), "%s: the intro plays first" % id)
		var seen: int = 0
		for i: int in 300:
			sequencer.advance(0.03)
			var shown: int = 0
			for child: Node in sky.get_node("StarLayer").get_children():
				if is_instance_valid(child) and not child.is_queued_for_deletion():
					(child as StarView).advance(0.03)
					shown += 1
			seen = maxi(seen, shown)
			if not sequencer.is_busy():
				break
		assert_false(sequencer.is_busy(), id)
		assert_gte(seen, 3, "%s: its stars were shown" % id)
		assert_true(main.run.stars.is_empty(), "%s: and are gone" % id)
