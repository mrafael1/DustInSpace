extends GutTest
## Chapter 3, Leo: its chart figure, the Tail (the heat alone, which only helps) and the Haunch
## (burning arrives), and how the heat shows: the field, the aim's preview and the resize.

const MainScene := preload("res://game/scenes/main.tscn")
const SKY := Rect2i(0, 78, 180, 172)


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
	for stage: int in range(2, Chapter.stage_count()):
		assert_eq(leo.map_id(stage), "", "%s is still to come" % leo.stage_name(stage))


func test_the_tail_teaches_a_heat_that_only_helps() -> void:
	var map: StarMap = StarMap.leo_tail()
	_check_pickable(map)
	assert_eq(map.starting_lit, [0] as Array[int], "five to light")
	assert_eq(map.heat_change, 1)
	assert_false(map.heat_burns, "nothing burns yet")
	assert_eq(map.heat_region, Rect2i(0, SKY.position.y, 88, SKY.size.y))
	for index: int in [3, 4, 5]:
		assert_true(map.heat_region.has_point(map.landmarks[index]), "the tail's end is in the heat")
	for index: int in [0, 1, 2]:
		assert_false(map.heat_region.has_point(map.landmarks[index]))
	assert_eq(map.sizes[5], Star.Size.BIG, "the tuft is big: the heat ripens what it needs")
	assert_eq(StarMap.by_id("leo_tail").title, "TAIL")


func test_the_haunch_brings_burning() -> void:
	var map: StarMap = StarMap.leo_haunch()
	_check_pickable(map)
	assert_eq(map.starting_lit, [0] as Array[int], "six to light")
	assert_true(map.heat_burns)
	for index: int in [1, 2, 3, 4, 5]:
		assert_true(map.heat_region.has_point(map.landmarks[index]), "the leg is in the heat")
	for index: int in [0, 6]:
		assert_false(map.heat_region.has_point(map.landmarks[index]), "the back and belly are out of it")
	assert_eq(StarMap.by_id("leo_haunch").title, "HAUNCH")


func test_each_heat_says_its_rule() -> void:
	assert_eq(Hud.heat_rule(StarHeat.new(SKY, 1, false)), Hud.HEAT_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(SKY, 1, true)), Hud.BURN_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(SKY, -1, false)), Hud.COLD_MESSAGE)
	assert_eq(Hud.heat_rule(StarHeat.new(SKY, -1, true)), Hud.FADE_MESSAGE)
	for message: String in [Hud.HEAT_MESSAGE, Hud.BURN_MESSAGE, Hud.COLD_MESSAGE, Hud.FADE_MESSAGE]:
		for line: String in message.split("\n"):
			assert_lte(line.length(), 22, line)


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	add_child_autofree(main)
	return main


func test_the_field_draws_embers_and_its_edge_in_palette_colours() -> void:
	var main: Main = _main("leo_haunch")
	var view: HeatView = main.get_node("Sky/HeatLayer")
	assert_true(view.is_processing())
	var region: Rect2i = main.run.heat.region
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	assert_false(dots.is_empty())
	for point: Vector2i in dots:
		assert_true(region.has_point(point), "the embers stay in the heat")
		assert_true(dots[point] in [Palette.S2, Palette.S3], "embers, never the warm C ramp")
	assert_true(dots.has(Vector2i(region.position.x, region.position.y)), "its left edge is dotted")
	assert_true(dots.has(Vector2i(region.end.x - 1, region.position.y)), "and its right edge")
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
	var outside: Star = run.add_star(Star.Size.SMALL, Vector2i(160, 230))
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
	for offset: Vector2i in StarView.outline_pixels(Star.Size.MEDIUM):
		assert_eq(dots.get(outside.position + offset), idle.get(outside.position + offset), "nothing round a star out of the heat")


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
