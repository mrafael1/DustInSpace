extends GutTest
## The bots' play sky (tools/playtest_sky.gd, docs/wide_sky_design.md §6) and the fixture's wide sky.

const Fixtures := preload("res://tests/fixtures.gd")
const PlaytestSky := preload("res://tools/playtest_sky.gd")


func test_sky_reads_a_visible_size_as_main_would_build_its_sky() -> void:
	assert_eq(PlaytestSky.parse_sky("--sky=640x360"), Fixtures.WIDE_SKY, "a 1080p window")
	assert_eq(PlaytestSky.parse_sky("--sky=640x400"), ScreenZones.play_sky(80, 230), "a Steam Deck")
	assert_eq(PlaytestSky.parse_sky("--sky=683x384"), ScreenZones.play_sky(64, 230), "capped at 640 columns")
	assert_eq(PlaytestSky.parse_sky("--sky=180x320"), Scorpio.HOME_SKY, "9:16: the home sky")
	assert_eq(PlaytestSky.parse_sky("--sky=180x422"), ScreenZones.play_sky(102), "a tall phone")


func test_a_bad_sky_falls_back_to_the_home_sky() -> void:
	assert_eq(PlaytestSky.parse_sky("--sky=wide"), Scorpio.HOME_SKY)
	assert_eq(PlaytestSky.parse_sky("--sky=640"), Scorpio.HOME_SKY)


func test_results_files_name_only_a_sky_that_isnt_the_home_one() -> void:
	assert_eq(PlaytestSky.suffix(Scorpio.HOME_SKY), "", "the 9:16 results keep their names")
	assert_eq(PlaytestSky.suffix(Fixtures.WIDE_SKY), "-sky640x212")


func test_the_fixture_run_plays_on_the_sky_it_is_given() -> void:
	assert_eq(Fixtures.run().sky_rect, Fixtures.SKY)
	var wide: RunState = Fixtures.run({}, 1, Fixtures.WIDE_SKY)
	assert_eq(wide.sky_rect, Fixtures.WIDE_SKY)
	assert_eq(wide.frame_rect, Rect2i(0, 38, 180, 212))
	assert_eq(Fixtures.WIDE_SKY, ScreenZones.play_sky(40, 230))
