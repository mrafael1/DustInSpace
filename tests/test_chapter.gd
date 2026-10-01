extends GutTest
## The chapter (#62): Scorpio in part stages (each its own StarMap) and a final full Scorpio,
## travelled from the tail; unlocking; saving progress. And the Stinger map itself.

const Fixtures := preload("res://tests/fixtures.gd")

var store_path: String = "user://test_progress_%d.json" % randi()


func after_each() -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))


func test_the_parts_share_out_every_chart_star_from_the_tail() -> void:
	assert_eq(Chapter.stage_count(), 6, "five parts and the final")
	assert_eq(Chapter.stage_name(0), "STINGER")
	assert_eq(Chapter.stage_name(Chapter.FINAL), "SCORPIO")
	assert_true(Chapter.stars(0).has(13), "the Stinger owns Shaula")
	assert_true(Chapter.stars(4).has(Scorpio.HEAD), "the Claws own the head")
	var owners: Dictionary = {}
	for stage: int in Chapter.FINAL:
		for star: int in Chapter.stars(stage):
			assert_false(owners.has(star), "star %d in one part only" % star)
			owners[star] = stage
	assert_eq(owners.size(), Scorpio.LANDMARKS.size(), "every star belongs to a part")
	assert_eq(Chapter.stage_of(13), 0)
	assert_eq(Chapter.stars(Chapter.FINAL), [] as Array[int], "the final is the whole figure")


func test_every_part_and_the_final_are_built() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.map_id(0), "stinger")
	assert_eq(chapter.map_id(1), "tail")
	assert_eq(chapter.map_id(2), "body")
	assert_eq(chapter.map_id(3), "heart")
	assert_eq(chapter.map_id(4), "claws")
	assert_eq(chapter.map_id(Chapter.FINAL), "scorpio")
	assert_eq(chapter.state(1), Chapter.PointState.LOCKED, "until the Stinger is won")
	assert_eq(chapter.state(2), Chapter.PointState.LOCKED, "until the Tail is won")
	assert_eq(chapter.state(3), Chapter.PointState.LOCKED, "until the Body is won")
	assert_eq(chapter.state(4), Chapter.PointState.LOCKED, "until the Heart is won")
	assert_eq(chapter.state(0), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.current(), 0, "start at the stinger")


func test_the_final_is_open_for_playtesting_while_the_parts_are_built() -> void:
	var chapter := Chapter.new()
	assert_true(Chapter.FINAL_OPEN)
	assert_eq(chapter.state(Chapter.FINAL), Chapter.PointState.AVAILABLE)


func test_winning_a_part_unlocks_the_next_built_part() -> void:
	var chapter := Chapter.new()
	chapter.set_built(1, true)
	assert_eq(chapter.complete(0), 1, "the Tail opens")
	assert_eq(chapter.state(0), Chapter.PointState.COMPLETED)
	assert_eq(chapter.state(1), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.state(2), Chapter.PointState.LOCKED)
	assert_eq(chapter.current(), 1)


func test_with_only_the_stinger_built_winning_it_opens_no_part() -> void:
	var chapter := Chapter.new()
	chapter.set_built(1, false)
	assert_eq(chapter.complete(0), -1)
	assert_eq(chapter.current(), Chapter.FINAL, "the final is next to play")


func test_a_locked_stage_cant_be_won_and_a_replay_opens_nothing_new() -> void:
	var chapter := Chapter.new()
	chapter.set_built(1, true)
	assert_eq(chapter.complete(1), -1, "the Tail is locked until the Stinger is won")
	assert_false(chapter.is_completed(1))
	chapter.complete(0)
	assert_eq(chapter.complete(0), -1, "a replay")
	assert_true(chapter.is_available(0), "won stages stay playable")


func test_the_final_can_be_won_and_replayed() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.complete(Chapter.FINAL), -1)
	assert_true(chapter.is_completed(Chapter.FINAL))
	assert_true(chapter.is_available(Chapter.FINAL))


func test_progress_round_trips_through_a_save() -> void:
	var chapter := Chapter.new()
	chapter.complete(0)
	chapter.complete(Chapter.FINAL)
	var again := Chapter.new()
	again.from_save(chapter.to_save())
	assert_eq(again.completed_count(), 2)
	assert_true(again.is_completed(0) and again.is_completed(Chapter.FINAL))


func test_a_bad_save_reads_as_what_it_can_prove() -> void:
	var chapter := Chapter.new()
	chapter.set_built(1, true)
	chapter.from_save({"completed": [1]})
	assert_eq(chapter.completed_count(), 0, "a gap: the Stinger was never won")
	chapter.from_save({"completed": [0, "x", 1.5, 99]})
	assert_eq(chapter.completed_count(), 1)
	chapter.from_save({"completed": "all"})
	assert_eq(chapter.completed_count(), 0)
	chapter.set_built(4, false)
	chapter.from_save({"completed": [0, 1, 2, 3, 4]})
	assert_eq(chapter.completed_count(), 4, "not past the parts built")


func test_the_store_keeps_progress_across_instances() -> void:
	var store := ProgressStore.new(store_path)
	assert_eq(store.load_chapter("scorpio"), {}, "nothing saved yet")
	assert_true(store.save_chapter("scorpio", {"completed": [0]}))
	store.save_chapter("orion", {"completed": []})
	var later := ProgressStore.new(store_path)
	assert_eq(later.load_chapter("scorpio").get("completed", []).size(), 1)
	var chapter := Chapter.new()
	chapter.from_save(later.load_chapter("scorpio"))
	assert_true(chapter.is_completed(0), "read back as won")
	assert_true(later.load_chapter("orion").has("completed"), "other chapters kept")


func test_a_broken_file_reads_as_no_progress() -> void:
	var file := FileAccess.open(store_path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_eq(ProgressStore.new(store_path).load_chapter("scorpio"), {})


## The Stinger, stage 1: a false constellation shaped like a stinger.
func test_the_stinger_map_is_a_hooked_tail_with_room_to_pick_each_star() -> void:
	var map: StarMap = StarMap.stinger()
	assert_eq(map.count(), 6)
	assert_eq(map.segment_count(), 5, "one line of strings")
	assert_eq(map.starting_lit, [0] as Array[int], "the first joint starts lit: five to light")
	assert_eq(map.sizes[4], Star.Size.BIG, "the telson")
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for i: int in map.count():
		assert_true(inner.has_point(map.landmarks[i]))
		for j: int in range(i + 1, map.count()):
			assert_gt(Vector2(map.landmarks[i]).distance_to(Vector2(map.landmarks[j])), 2.0 * SkyView.HIT_RADIUS)
	for segment: int in map.segment_count():
		var ends: Array[Vector2i] = map.segment_ends(segment)
		assert_between(Vector2(ends[0]).distance_to(Vector2(ends[1])), 24.0, 40.0)
	# The shape: along the bottom, up to the telson, then the sting hooks back up and left.
	assert_gt(map.landmarks[3].x, map.landmarks[0].x + 60, "the tail runs right along the bottom")
	assert_lt(map.landmarks[4].y, map.landmarks[3].y - 20, "rises to the telson")
	assert_lt(map.landmarks[5].x, map.landmarks[4].x, "the sting hooks back")
	assert_lt(map.landmarks[5].y, map.landmarks[4].y)
	assert_eq(StarMap.by_id("stinger").title, "STINGER")
	assert_eq(StarMap.by_id("anything").id, "scorpio", "unknown ids play the full map")


func test_a_stinger_run_is_won_by_lighting_its_five_stars() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1}
	var run := RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY, StarMap.stinger())
	assert_eq(run.scorpio.map.id, "stinger")
	assert_eq(run.scorpio.built_count(), 0)
	var won: Array[bool] = []
	run.run_won.connect(func() -> void: won.append(true))
	for index: int in range(1, 6):
		var size: int = run.scorpio.map.sizes[index]
		var a: Star = run.add_star(size as Star.Size, Vector2i(170, 90))
		var b: Star = run.add_star(size as Star.Size, Vector2i(10, 90))
		assert_ne(run.link([a.id, b.id, Scorpio.landmark_id(index)] as Array[int]), Combos.INVALID, "star %d" % index)
	assert_true(run.scorpio.is_complete())
	assert_eq(run.scorpio.built_count(), 5)
	assert_eq(won, [true])
	# Ids past the stinger's six stars are no landmarks here.
	var s1: Star = run.add_star(Star.Size.SMALL, Vector2i(40, 110))
	assert_null(run.find_star(Scorpio.landmark_id(9)))
	assert_false(run.scorpio.is_landmark(Scorpio.landmark_id(9)))
	assert_not_null(s1)


func test_the_stinger_drawing_is_a_stinger_clear_of_its_stars() -> void:
	var map: StarMap = StarMap.stinger()
	var drawing: Array[Vector2i] = ConstellationView.scorpion_drawing(map)
	assert_gt(drawing.size(), 40, "tail bulbs, a telson and the hooked sting")
	assert_lt(drawing.size(), ConstellationView.scorpion_drawing().size(), "much less than the whole scorpion")
	for p: Vector2i in drawing:
		assert_true(Scorpio.HOME_SKY.has_point(p), "%s inside the sky" % p)
		for star: Vector2i in map.landmarks:
			assert_gt(maxi(absi(p.x - star.x), absi(p.y - star.y)), 3)
	assert_eq(ConstellationView.song_order(map).size(), 5, "its completion tune plays its five strings")
