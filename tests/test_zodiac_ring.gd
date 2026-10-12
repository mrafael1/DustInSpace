extends GutTest
## The zodiac closes into a ring (docs/chapter_4_6_plan.md): Libra after Virgo, then Scorpio again;
## a chapter's place is its sign plus its lap, and the sky repeats round the ring.

const ChartScene := preload("res://game/scenes/chapter_select.tscn")


func test_libra_follows_virgo_and_the_ring_is_twelve_signs() -> void:
	assert_eq(ChapterSelect.ZODIAC.size(), 12)
	assert_eq(ChapterSelect.ZODIAC.back(), "libra")
	assert_eq(ChapterSelect.ZODIAC.find("libra"), ChapterSelect.ZODIAC.find("virgo") + 1)
	assert_true(ChapterSelect.PASSING.has("libra"), "Libra passes between Virgo and Scorpio")
	assert_eq(ChapterSelect.RING, 12 * ChapterSelect.SKY_SPAN)


func test_sagittarius_is_three_signs_on_from_virgo_on_the_second_lap() -> void:
	assert_eq(ChapterSelect.sky_x("sagittarius") - ChapterSelect.sky_x("virgo"), 3 * ChapterSelect.SKY_SPAN)
	assert_eq(ChapterSelect.sky_x("sagittarius"), ChapterSelect.sign_x("sagittarius") + ChapterSelect.RING)
	assert_eq(ChapterSelect.sky_x("scorpio"), 0, "the first chapters stay on the first lap")
	assert_eq(ChapterSelect.sky_x("virgo"), 10 * ChapterSelect.SKY_SPAN)


func test_the_background_stars_repeat_round_the_ring() -> void:
	var first: Array = ChapterSelect.sky_section(2)
	var again: Array = ChapterSelect.sky_section(2 + 12)
	assert_eq(first.size(), again.size())
	for i: int in first.size():
		var a: Vector3i = first[i]
		var b: Vector3i = again[i]
		assert_eq(b, Vector3i(a.x + ChapterSelect.RING, a.y, a.z))
	assert_eq(ChapterSelect.sky_section(-1).size(), ChapterSelect.sky_section(11).size(), "left of Scorpio is Libra")


func test_a_chapter_passed_on_another_lap_shows_faint_and_named() -> void:
	var chart: ChapterSelect = ChartScene.instantiate()
	add_child_autofree(chart)
	chart.set("_camera", float(ChapterSelect.RING))
	assert_eq(chart.call("_echo_x", "scorpio"), 0, "Scorpio again, a lap on")
	assert_eq(chart.call("_place_x", "scorpio"), -ChapterSelect.RING)
	chart.set("_camera", 0.0)
	assert_lt(chart.call("_echo_x", "scorpio"), -ChapterSelect.SKY_SPAN, "at its own place it's the chart, not an echo")
	chart.set("_camera", float(ChapterSelect.sign_x("cancer") + ChapterSelect.RING))
	assert_eq(chart.call("_passing_x", "cancer"), 0, "the constellations between repeat too")
