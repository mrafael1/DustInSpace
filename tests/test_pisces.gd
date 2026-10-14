extends GutTest
## Chapter 6, Pisces: its figure and chart, its first two stages (the Circlet, the West Cord), the
## reflection and its intro, and how they show.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)
const BUILT: Array[String] = ["pisces_circlet", "pisces_west_cord"]


func _run(map: StarMap, seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, map)
	run.dust = 100
	run.owned_packs["blue"] = 20
	return run


func _main(map_id: String) -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = map_id
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func test_pisces_is_chapter_6_after_sagittarius_on_the_ring() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.def.number, 6)
	assert_eq(chapter.def.unlocked_by, "sagittarius")
	assert_eq(chapter.stage_name(0), "CIRCLET")
	assert_eq(chapter.stage_name(1), "WEST CORD")
	for stage: int in BUILT.size():
		assert_eq(chapter.map_id(stage), BUILT[stage])
		assert_true(chapter.has_stage(stage))
	for stage: int in range(BUILT.size(), Chapter.stage_count()):
		assert_false(chapter.has_stage(stage), "stage %d isn't built yet" % stage)
	assert_eq(ChapterSelect.sky_x("pisces") - ChapterSelect.sky_x("sagittarius"), 3 * ChapterSelect.SKY_SPAN, "three signs on, round the ring")
	assert_eq(ChapterSelect.sky_x("pisces"), ChapterSelect.sign_x("pisces") + ChapterSelect.RING, "on the second lap")


func test_the_figure_is_a_pickable_tree_and_its_parts_share_it_out() -> void:
	var def: ChapterDef = ChapterDef.pisces()
	var figure: StarMap = def.figure
	assert_eq(figure.count(), 14)
	assert_eq(figure.segment_count(), 13, "the strings form a tree")
	var inner: Rect2i = StarScatter.inner_rect(Scorpio.HOME_SKY)
	for i: int in figure.count():
		assert_true(inner.has_point(figure.landmarks[i]), "star %d sits in the sky" % i)
		assert_gt(Vector2(figure.landmarks[i]).distance_to(Vector2(def.final_at)), 24.0, "the crown keeps clear")
		for j: int in range(i + 1, figure.count()):
			assert_gte(Vector2(figure.landmarks[i]).distance_to(Vector2(figure.landmarks[j])), 24.0, "%d and %d" % [i, j])
	var owned: Array[int] = []
	for stage: int in Chapter.FINAL:
		owned.append_array(def.stages[stage]["stars"])
	owned.sort()
	assert_eq(owned, range(14), "every star belongs to exactly one part")
	assert_eq(StarMap.by_id("pisces").title, "PISCES")
