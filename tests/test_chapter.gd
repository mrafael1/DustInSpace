extends GutTest
## The chapter (#62): Scorpio's route from the tail, stage states, unlocking, and saving progress.

var store_path: String = "user://test_progress_%d.json" % randi()


func after_each() -> void:
	if FileAccess.file_exists(store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_path))


func test_the_route_starts_at_the_stinger_and_visits_every_star_once() -> void:
	assert_eq(Chapter.point_count(), Scorpio.LANDMARKS.size())
	assert_eq(Chapter.landmark(0), 13, "Shaula, the stinger")
	var seen: Dictionary = {}
	for point: int in Chapter.point_count():
		assert_false(seen.has(Chapter.landmark(point)))
		seen[Chapter.landmark(point)] = true
	assert_eq(Chapter.landmark(11), Scorpio.HEAD, "up the tail and body to the head")
	for point: int in range(1, Chapter.point_count()):
		var path: Array[int] = Chapter.path(point - 1, point)
		assert_gte(path.size(), 2, "each step follows the strings (%d)" % point)
		assert_eq(path[0], Chapter.landmark(point - 1))
		assert_eq(path[-1], Chapter.landmark(point))
	assert_eq(Chapter.path(12, 13), [0, 1, 2] as Array[int], "beta to pi goes back through the head")


func test_only_the_first_stage_is_built_and_open() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.playable, 1, "the current map is stage 1; no empty stages")
	assert_eq(chapter.state(0), Chapter.PointState.AVAILABLE)
	for point: int in range(1, Chapter.point_count()):
		assert_eq(chapter.state(point), Chapter.PointState.LOCKED)
	assert_eq(chapter.current(), 0)
	assert_eq(Chapter.stage_name(0), "STAGE 1")


func test_winning_a_stage_completes_it_and_unlocks_the_next_built_one() -> void:
	var chapter := Chapter.new(3)
	assert_eq(chapter.complete(0), 1, "stage 2 opens")
	assert_eq(chapter.state(0), Chapter.PointState.COMPLETED)
	assert_eq(chapter.state(1), Chapter.PointState.AVAILABLE)
	assert_eq(chapter.state(2), Chapter.PointState.LOCKED)
	assert_eq(chapter.current(), 1)
	assert_eq(chapter.complete(1), 2)
	assert_eq(chapter.complete(2), -1, "nothing built after stage 3")
	assert_eq(chapter.state(3), Chapter.PointState.LOCKED)
	assert_eq(chapter.current(), 2, "everything built is done: the last one")


func test_a_locked_stage_cant_be_won_and_a_replay_unlocks_nothing_new() -> void:
	var chapter := Chapter.new(2)
	assert_eq(chapter.complete(1), -1, "locked: nothing happens")
	assert_false(chapter.is_completed(1))
	chapter.complete(0)
	assert_eq(chapter.complete(0), -1, "a replay")
	assert_true(chapter.is_available(0), "completed stages stay playable")
	assert_eq(chapter.completed_count(), 1)


func test_with_only_stage_1_built_winning_it_unlocks_nothing() -> void:
	var chapter := Chapter.new()
	assert_eq(chapter.complete(0), -1)
	assert_eq(chapter.state(1), Chapter.PointState.LOCKED, "stage 2 isn't built yet (#64)")


func test_progress_round_trips_through_a_save() -> void:
	var chapter := Chapter.new(3)
	chapter.complete(0)
	chapter.complete(1)
	var again := Chapter.new(3)
	again.from_save(chapter.to_save())
	assert_eq(again.completed_count(), 2)
	assert_eq(again.state(2), Chapter.PointState.AVAILABLE)


func test_a_bad_save_reads_as_what_it_can_prove() -> void:
	var chapter := Chapter.new(3)
	chapter.from_save({"completed": [1, 2]})
	assert_eq(chapter.completed_count(), 0, "a gap: stage 1 was never won")
	chapter.from_save({"completed": [0, "x", 1.5, 99]})
	assert_eq(chapter.completed_count(), 1)
	chapter.from_save({"completed": "all"})
	assert_eq(chapter.completed_count(), 0)
	chapter.from_save({"completed": [0, 1, 2, 3, 4]})
	assert_eq(chapter.completed_count(), 3, "not past the stages built")


func test_the_store_keeps_progress_across_instances() -> void:
	var store := ProgressStore.new(store_path)
	assert_eq(store.load_chapter("scorpio"), {}, "nothing saved yet")
	assert_true(store.save_chapter("scorpio", {"completed": [0]}))
	store.save_chapter("orion", {"completed": []})
	var later := ProgressStore.new(store_path)
	assert_eq(later.load_chapter("scorpio").get("completed", []).size(), 1)
	var chapter := Chapter.new()
	chapter.from_save(later.load_chapter("scorpio"))
	assert_true(chapter.is_completed(0), "read back as completed")
	assert_true(later.load_chapter("orion").has("completed"), "other chapters kept")


func test_a_broken_file_reads_as_no_progress() -> void:
	var file := FileAccess.open(store_path, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	assert_eq(ProgressStore.new(store_path).load_chapter("scorpio"), {})
