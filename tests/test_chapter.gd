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
	assert_eq(Chapter.new().stage_name(0), "STINGER")
	assert_eq(Chapter.new().stage_name(Chapter.FINAL), "SCORPIO")
	assert_true(Chapter.new().stars(0).has(13), "the Stinger owns Shaula")
	assert_true(Chapter.new().stars(4).has(Scorpio.HEAD), "the Claws own the head")
	var owners: Dictionary = {}
	for stage: int in Chapter.FINAL:
		for star: int in Chapter.new().stars(stage):
			assert_false(owners.has(star), "star %d in one part only" % star)
			owners[star] = stage
	assert_eq(owners.size(), Scorpio.LANDMARKS.size(), "every star belongs to a part")
	assert_eq(Chapter.new().stage_of(13), 0)
	assert_eq(Chapter.new().stars(Chapter.FINAL), [] as Array[int], "the final is the whole figure")


func test_every_part_and_the_final_are_built() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.map_id(0), "stinger")
	assert_eq(chapter.map_id(1), "tail")
	assert_eq(chapter.map_id(2), "body")
	assert_eq(chapter.map_id(3), "heart")
	assert_eq(chapter.map_id(4), "claws")
	assert_eq(chapter.map_id(Chapter.FINAL), "final")
	assert_eq(chapter.state(1), Chapter.PointState.LOCKED, "until the Stinger is won")
	assert_eq(chapter.state(2), Chapter.PointState.LOCKED, "until the Tail is won")
	assert_eq(chapter.state(3), Chapter.PointState.LOCKED, "until the Body is won")
	assert_eq(chapter.state(4), Chapter.PointState.LOCKED, "until the Heart is won")
	assert_eq(chapter.state(0), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.current(), 0, "start at the stinger")


func test_the_final_stays_locked_until_every_part_is_won() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.state(Chapter.FINAL), Chapter.PointState.LOCKED)
	assert_eq(chapter.complete(Chapter.FINAL), -1, "a locked final can't be won")
	assert_false(chapter.is_completed(Chapter.FINAL))
	for stage: int in 4:
		chapter.complete(stage)
	assert_false(chapter.parts_done())
	assert_eq(chapter.state(Chapter.FINAL), Chapter.PointState.LOCKED, "four parts aren't enough")
	assert_eq(chapter.complete(4), Chapter.FINAL, "winning the fifth part unlocks the final")
	assert_true(chapter.parts_done())
	assert_eq(chapter.state(Chapter.FINAL), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.current(), Chapter.FINAL, "the final is next to play")
	assert_eq(chapter.complete(4), -1, "a replay of the Claws unlocks nothing new")


func test_the_final_is_the_boss_stage() -> void:
	var map: StarMap = StarMap.by_id(Chapter.new().map_id(Chapter.FINAL))
	assert_eq(map.id, "final")
	assert_eq(map.title, "SCORPIO")
	assert_true(map.boss)
	assert_eq(map.count(), Scorpio.LANDMARKS.size(), "the full figure")
	assert_eq(map.landmarks, Scorpio.LANDMARKS)
	assert_eq(map.starting_lit, Scorpio.STARTING_LIT)
	assert_true(map.orion, "the single mark")
	assert_eq(map.volley, "volley", "the volley")
	assert_true(map.hunt, "the hunting area")
	assert_false(map.intros, "each threat was introduced on its own stage")
	assert_eq(map.painting, StarMap.FIGURE, "completion paints the whole Scorpio")
	assert_false(StarMap.scorpio().boss, "the plain full Scorpio stays plain")
	assert_false(StarMap.scorpio().orion)


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
	assert_eq(chapter.current(), 0, "nothing new to play: the last won")
	assert_eq(chapter.state(Chapter.FINAL), Chapter.PointState.LOCKED)


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
	for stage: int in Chapter.FINAL:
		chapter.complete(stage)
	assert_eq(chapter.complete(Chapter.FINAL), -1)
	assert_true(chapter.is_completed(Chapter.FINAL))
	assert_true(chapter.is_available(Chapter.FINAL))


func test_progress_round_trips_through_a_save() -> void:
	var chapter := Chapter.new()
	for stage: int in Chapter.stage_count():
		chapter.complete(stage)
	var again := Chapter.new()
	again.from_save(chapter.to_save())
	assert_eq(again.completed_count(), Chapter.stage_count())
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
	chapter.set_built(4, true)
	chapter.from_save({"completed": [0, 1, 2, Chapter.FINAL]})
	assert_false(chapter.is_completed(Chapter.FINAL), "a final saved without every part doesn't count")


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
	# The shape, as the whole Scorpio's: in from the right along the bottom, up at the left, then
	# the telson runs right and the sting curls up.
	assert_lt(map.landmarks[2].x, map.landmarks[0].x - 50, "the tail runs left along the bottom")
	assert_lt(map.landmarks[3].y, map.landmarks[2].y - 20, "turns up at the left")
	assert_gt(map.landmarks[4].x, map.landmarks[3].x + 20, "the telson runs right")
	assert_lt(map.landmarks[5].y, map.landmarks[4].y - 20, "the sting curls up")
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


func test_the_stinger_paints_its_piece_of_the_scorpio() -> void:
	var map: StarMap = StarMap.stinger()
	assert_eq(map.painting, StarMap.PART_PAINTING % "stinger")
	assert_eq(ConstellationView.song_order(map).size(), 5, "its completion tune plays its five strings")
