extends GutTest
## The night background (assets/art/background.png, tools/art/build_background.py).

const Fixtures := preload("res://tests/fixtures.gd")
const MainScene := preload("res://game/scenes/main.tscn")
const BACKGROUND := "res://assets/art/background.png"
const PALETTE_PATH := "res://assets/palettes/stellar_sun.gpl"
## Only the sky (N) and land (M) ramps: no warm, Sun, dust or pack colours in the scenery.
const RAMP_NAMES: Array[String] = ["N", "M"]


func test_the_background_fills_the_screen_behind_everything() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var background: Sprite2D = main.get_node("Background")
	assert_eq(background.get_index(), 1, "drawn right after the Backdrop: behind the Sun's glow, the stars and the HUD")
	assert_false(background.centered)
	assert_eq(background.position, Vector2.ZERO)
	assert_eq(background.texture.get_size(), Vector2(180, 320), "the whole native canvas")


func test_the_background_is_opaque_sky_and_land_colours_only() -> void:
	var image: Image = (load(BACKGROUND) as Texture2D).get_image()
	var allowed: Dictionary[String, String] = _cool_colours()
	var off: Dictionary[String, bool] = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.a < 1.0 or not allowed.has(c.to_html(false)):
				off[c.to_html()] = true
	assert_eq(off.keys(), [], "every pixel opaque and on the N or M ramp")


## The forest floor under the HUD (#14): dark where the HUD's text and icons sit (M0 and M1 only
## behind the dust counter and each pack's count and cost), with a lit grass bank above.
func test_the_forest_floor_stays_dark_behind_the_hud_text() -> void:
	var image: Image = (load(BACKGROUND) as Texture2D).get_image()
	var dark: Array[String] = ["0a0c26", "121638"]
	var zones: Array[Rect2i] = [Rect2i(4, 294, 60, 14), Rect2i(112, 298, 68, 16)]
	for zone: Rect2i in zones:
		for y: int in range(zone.position.y, zone.end.y):
			for x: int in range(zone.position.x, zone.end.x):
				assert_true(image.get_pixel(x, y).to_html(false) in dark, "(%d, %d) is dark behind the HUD" % [x, y])


func test_the_forest_floor_has_a_grass_bank_stones_and_the_telescope_slab() -> void:
	var image: Image = (load(BACKGROUND) as Texture2D).get_image()
	var lit: int = 0
	for x: int in 180:
		for y: int in range(282, 290):
			if image.get_pixel(x, y).to_html(false) in ["2b3470", "4a5aa8"]:
				lit += 1
				break
	assert_eq(lit, 180, "a lit M3/M4 grass rim runs all the way across")
	# The telescope (Main: x 80, feet 10 px below it) stands on the slab's top row.
	var feet_row: int = 300 + 10 + 1
	for x: int in [71, 80, 89]:
		assert_true(image.get_pixel(x, feet_row).to_html(false) in ["2b3470", "4a5aa8"], "slab top under x %d" % x)


## Repeated across (Backdrop.ground_colour), the floor's last column meets its first no worse than
## any two neighbouring columns inside it: no seam in a wider screen's margins.
func test_the_forest_floor_tiles_across() -> void:
	var image: Image = (load(BACKGROUND) as Texture2D).get_image()
	var worst: int = 0
	for x: int in range(1, 180):
		worst = maxi(worst, _column_changes(image, x - 1, x))
	assert_lte(_column_changes(image, 179, 0), worst, "the seam is like any other column step")
	assert_eq(Backdrop.ground_colour(image, -1, 300), Backdrop.edge_colour(image, 179, 300), "the margin left of the game repeats its right edge")
	assert_eq(Backdrop.ground_colour(image, 185, 300), Backdrop.edge_colour(image, 5, 300))


## A wide screen's sides carry the landscape on: opaque sky and land colours only, the sky keeping
## the background's own dither next to the game (no stripes), a step darker further out, and
## mountains of varied heights with trees standing in front.
func test_a_wide_screens_sides_carry_the_landscape_on() -> void:
	var background: Image = (load(BACKGROUND) as Texture2D).get_image()
	var area := Rect2i(-60, -80, 300, 400)
	var image: Image = Backdrop.margin_image(background, area)
	var allowed: Dictionary[String, String] = _cool_colours()
	var off: Dictionary[String, bool] = {}
	for y: int in range(0, area.size.y, 2):
		for x: int in range(0, area.size.x, 2):
			var p := Vector2i(x, y) + area.position
			var c: Color = image.get_pixel(x, y)
			if Rect2i(Vector2i.ZERO, ScreenZones.SCREEN).has_point(p):
				assert_eq(c.a, 0.0, "clear over the game")
			elif c.a < 1.0 or not allowed.has(c.to_html(false)):
				off[c.to_html()] = true
	assert_eq(off.keys(), [], "opaque sky and land colours")
	# Row 120 dithers N2/N3 every other pixel: the margin next to the game carries the pattern.
	for x: int in range(-4, 0):
		assert_eq(image.get_pixel(x - area.position.x, 120 - area.position.y), Backdrop.edge_colour(background, x + 180, 120), "row 120 dithers on at x %d" % x)
	assert_eq(Backdrop.outer_sky(Palette.N3, -40, 140), Palette.N2, "further out, a step darker")
	assert_eq(Backdrop.outer_sky(Palette.N3, -2, 140), Palette.N3, "not next to the game")
	var tops: Dictionary[int, bool] = {}
	var trees: int = 0
	for x: int in range(-60, 0):
		tops[Backdrop.mountain_top(background, x)] = true
		if Backdrop.is_tree(x):
			trees += 1
	assert_gt(tops.size(), 6, "irregular mountains, not a flat band")
	assert_between(trees, 4, 20, "scattered trees")
	assert_lte(absi(Backdrop.mountain_top(background, -1) - Backdrop.mountain_top(background, 0)), 2, "starting at the background's edge height")


func _column_changes(image: Image, a: int, b: int) -> int:
	var changes: int = 0
	for y: int in range(Backdrop.GROUND_TOP, 320):
		if image.get_pixel(a, y) != image.get_pixel(b, y):
			changes += 1
	return changes


## The sky and land ramps from the .gpl, by hex.
func _cool_colours() -> Dictionary[String, String]:
	var colours: Dictionary[String, String] = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 4 and fields[0].is_valid_int() and fields[3].left(1) in RAMP_NAMES:
			colours[Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()).to_html(false)] = fields[3]
	return colours


func test_the_view_fills_a_phone_at_a_whole_number_scale() -> void:
	assert_eq(ScreenZones.fill_scale(Vector2i(1080, 1920)), 6, "9:16 at 6x")
	assert_eq(ScreenZones.fill_size(Vector2i(1080, 1920)), Vector2i(180, 320), "exactly the game's screen")
	# Godot's own expand left 45 px bars across and 99 px top and bottom here.
	assert_eq(ScreenZones.fill_scale(Vector2i(1170, 2532)), 6)
	assert_eq(ScreenZones.fill_size(Vector2i(1170, 2532)), Vector2i(195, 422), "fills: under 6 device px left over")
	assert_eq(ScreenZones.fill_size(Vector2i(412, 915)), Vector2i(206, 457), "a CSS-sized web canvas at 2x")
	assert_eq(ScreenZones.fill_size(Vector2i(64, 64)), Vector2i(180, 320), "never smaller than the game")


## Landscape and tablet windows (docs/wide_sky_design.md §1): the same whole-number scale that still
## shows 180x320, the extra width split evenly to both sides and the extra height above.
func test_the_view_fills_a_landscape_window_with_the_game_centred() -> void:
	var cases: Array[Array] = [
		# window, scale, visible game px, game_offset
		[Vector2i(1920, 1080), 3, Vector2i(640, 360), Vector2i(230, 40)],
		[Vector2i(1280, 800), 2, Vector2i(640, 400), Vector2i(230, 80)],
		[Vector2i(1536, 2048), 6, Vector2i(256, 341), Vector2i(38, 21)],
		[Vector2i(2048, 1536), 4, Vector2i(512, 384), Vector2i(166, 64)],
		[Vector2i(1366, 768), 2, Vector2i(683, 384), Vector2i(251, 64)],
	]
	for case: Array in cases:
		var window: Vector2i = case[0]
		assert_eq(ScreenZones.fill_scale(window), case[1], "%s scale" % window)
		assert_eq(ScreenZones.fill_size(window), case[2], "%s visible game px" % window)
		assert_eq(ScreenZones.game_offset(Vector2(ScreenZones.fill_size(window))), case[3], "%s game offset (an odd extra width leaves its last column on the right)" % window)


## The play sky on those windows (docs/wide_sky_design.md §1): on a landscape one, the same extra
## columns on both sides, capped at MAX_SKY_WIDTH; on any, every extra row above.
func test_the_play_sky_widens_to_both_sides_up_to_the_cap() -> void:
	var cases: Array[Array] = [
		# window, sky_margin, play sky
		[Vector2i(1920, 1080), Vector2i(230, 40), Rect2i(-230, 38, 640, 212)],
		[Vector2i(1280, 800), Vector2i(230, 80), Rect2i(-230, -2, 640, 252)],
		[Vector2i(1536, 2048), Vector2i(0, 21), Rect2i(0, 57, 180, 193)],
		[Vector2i(2048, 1536), Vector2i(166, 64), Rect2i(-166, 14, 512, 236)],
		[Vector2i(1366, 768), Vector2i(230, 64), Rect2i(-230, 14, 640, 236)],
		[Vector2i(2560, 1080), Vector2i(230, 40), Rect2i(-230, 38, 640, 212)],
		[Vector2i(1080, 1920), Vector2i(0, 0), ScreenZones.SKY],
		[Vector2i(1170, 2532), Vector2i(0, 102), Rect2i(0, -24, 180, 274)],
	]
	for case: Array in cases:
		var window: Vector2i = case[0]
		var margin: Vector2i = ScreenZones.sky_margin(Vector2(ScreenZones.fill_size(window)))
		assert_eq(margin, case[1], "%s sky margin" % window)
		var sky: Rect2i = ScreenZones.play_sky(margin.y, margin.x)
		assert_eq(sky, case[2], "%s play sky" % window)
		assert_lte(sky.size.x, ScreenZones.MAX_SKY_WIDTH, "%s within the cap" % window)
		assert_eq(sky.position.x + sky.end.x, 180, "%s centred on x 90" % window)
	# 1366x768 shows 683 columns: 503 extra, an odd number. The cap leaves 640 either way.
	assert_eq(ScreenZones.sky_margin(Vector2(401, 360)), Vector2i(110, 40), "an odd extra width splits evenly, the leftover is backdrop")
	assert_eq(ScreenZones.sky_margin(Vector2(361, 360)), Vector2i(90, 40), "the narrowest landscape area, its odd column backdrop")
	assert_eq(ScreenZones.play_sky(102), Rect2i(0, -24, 180, 274), "side 0 is today's tall sky")
	assert_eq(ScreenZones.play_sky(0), ScreenZones.SKY)


## Only a landscape window widens the sky (the user, 2026-10-20): a portrait one, every phone, a
## tablet held upright, a tall desktop window, keeps the game's own 180 columns, however many it has to
## spare, and only grows upward as today. A square one counts as portrait.
func test_only_a_landscape_window_widens_the_sky() -> void:
	var portrait: Array[Array] = [
		# window, rows above
		[Vector2i(1170, 2532), 102],
		[Vector2i(1080, 2400), 80],
		[Vector2i(1668, 2388), 21],
		[Vector2i(1536, 2048), 21],
		[Vector2i(1000, 1000), 13],
		[Vector2i(1080, 1920), 0],
	]
	for case: Array in portrait:
		var window: Vector2i = case[0]
		var visible := Vector2(ScreenZones.fill_size(window))
		assert_false(ScreenZones.widens_sky(visible), "%s (%s visible) is portrait" % [window, visible])
		assert_eq(ScreenZones.sky_margin(visible), Vector2i(0, case[1]), "%s: no side columns, every extra row" % window)
	for visible: Vector2 in [Vector2(195, 422), Vector2(238, 341), Vector2(256, 341), Vector2(240, 320), Vector2(320, 320), Vector2(333, 333)]:
		assert_eq(ScreenZones.sky_margin(visible).x, 0, "%s: spare columns stay backdrop" % visible)
	assert_eq(ScreenZones.game_offset(Vector2(195, 422)).x, 7, "the phone's 7 spare columns still centre the game")
	var landscape: Array[Array] = [
		# window, sky margin
		[Vector2i(1920, 1080), Vector2i(230, 40)],
		[Vector2i(1366, 768), Vector2i(230, 64)],
		[Vector2i(2388, 1668), Vector2i(148, 13)],
		[Vector2i(2048, 1536), Vector2i(166, 64)],
		[Vector2i(2560, 1080), Vector2i(230, 40)],
	]
	for case: Array in landscape:
		var window: Vector2i = case[0]
		var visible := Vector2(ScreenZones.fill_size(window))
		assert_true(ScreenZones.widens_sky(visible), "%s (%s visible) is landscape" % [window, visible])
		var margin: Vector2i = ScreenZones.sky_margin(visible)
		assert_eq(margin, case[1], "%s sky margin" % window)
		assert_gt(margin.x, 0, "%s: side columns" % window)
		assert_lte(ScreenZones.play_sky(margin.y, margin.x).size.x, ScreenZones.MAX_SKY_WIDTH, "%s within the 640 cap" % window)
	assert_false(ScreenZones.widens_sky(Vector2(360, 360)), "square: portrait")
	assert_eq(ScreenZones.sky_margin(Vector2(360, 360)), Vector2i(0, 40), "square: rows only")
	assert_eq(ScreenZones.sky_margin(Vector2(361, 360)).x, 90, "one column wider: landscape")


## Commit 18 (docs/wide_sky_design.md Q1): a run fits a visible area that shows its whole sky and the
## Sun's band above it; one pixel short either way doesn't, and more never hurts.
func test_a_screen_holds_a_runs_sky_only_when_it_shows_all_of_it() -> void:
	assert_eq(ScreenZones.sky_field(Fixtures.WIDE_SKY), Rect2i(-230, -40, 640, 360), "the wide sky, its Sun band and the land and HUD below")
	assert_eq(ScreenZones.sky_field(ScreenZones.SKY), Rect2i(Vector2i.ZERO, ScreenZones.SCREEN), "the portrait sky's: the game's screen")
	assert_true(ScreenZones.holds_sky(Vector2(640, 360), Fixtures.WIDE_SKY), "640x360: exactly")
	assert_false(ScreenZones.holds_sky(Vector2(639, 360), Fixtures.WIDE_SKY), "a column short: cut at the side")
	assert_false(ScreenZones.holds_sky(Vector2(638, 360), Fixtures.WIDE_SKY), "two columns short")
	assert_false(ScreenZones.holds_sky(Vector2(640, 359), Fixtures.WIDE_SKY), "a row short: the Sun's top cut")
	assert_true(ScreenZones.holds_sky(Vector2(641, 360), Fixtures.WIDE_SKY), "a column more")
	assert_true(ScreenZones.holds_sky(Vector2(640, 361), Fixtures.WIDE_SKY), "a row more")
	assert_true(ScreenZones.holds_sky(Vector2(853, 360), Fixtures.WIDE_SKY), "ultrawide")
	assert_true(ScreenZones.holds_sky(Vector2(640.6, 360.4), Fixtures.WIDE_SKY), "fractions of a px don't count")
	assert_false(ScreenZones.holds_sky(Vector2(ScreenZones.fill_size(Vector2i(900, 1000))), Fixtures.WIDE_SKY), "a 900x1000 window (300x333)")
	assert_false(ScreenZones.holds_sky(Vector2(195, 422), Fixtures.WIDE_SKY), "a phone-shaped one")
	var deck: Rect2i = ScreenZones.play_sky(80, 230)
	assert_true(ScreenZones.holds_sky(Vector2(640, 400), deck), "1280x800's own sky")
	assert_false(ScreenZones.holds_sky(Vector2(640, 360), deck), "the same sky at the minimum window: 40 rows short")
	# Portrait: a portrait run on a portrait screen with at least its rows always fits.
	var tall: Rect2i = ScreenZones.play_sky(102)
	assert_true(ScreenZones.holds_sky(Vector2(195, 422), tall), "the phone's own sky")
	assert_true(ScreenZones.holds_sky(Vector2(180, 422), tall), "no spare columns needed")
	assert_true(ScreenZones.holds_sky(Vector2(256, 500), tall), "taller and wider")
	assert_true(ScreenZones.holds_sky(Vector2(640, 422), tall), "landscape with as many rows")
	assert_false(ScreenZones.holds_sky(Vector2(195, 421), tall), "a row short")
	assert_true(ScreenZones.holds_sky(Vector2(180, 320), ScreenZones.SKY), "9:16")
	assert_false(ScreenZones.holds_sky(Vector2(179, 320), ScreenZones.SKY), "narrower than the game")


## A run built for a screen always fits it: the game never holds on the screen it opened on.
func test_every_screen_holds_the_sky_it_builds() -> void:
	var windows: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1366, 768),
		Vector2i(2560, 1080), Vector2i(2048, 1536), Vector2i(2388, 1668), Vector2i(1536, 2048), Vector2i(1170, 2532),
		Vector2i(1080, 2400), Vector2i(1080, 1920), Vector2i(540, 960), Vector2i(900, 1000), Vector2i(1000, 1000), Vector2i(64, 64)]
	for window: Vector2i in windows:
		var visible := Vector2(ScreenZones.fill_size(window))
		var margin: Vector2i = ScreenZones.sky_margin(visible)
		assert_true(ScreenZones.holds_sky(visible, ScreenZones.play_sky(margin.y, margin.x)), "%s holds its own sky" % window)
	for w: int in range(180, 700, 7):
		for h: int in range(320, 520, 11):
			var margin: Vector2i = ScreenZones.sky_margin(Vector2(w, h))
			if not ScreenZones.holds_sky(Vector2(w, h), ScreenZones.play_sky(margin.y, margin.x)):
				fail_test("%dx%d doesn't hold its own sky" % [w, h])
				return


## Q1 (the user, 2026-10-20): a desktop window can't go below 960x540, which shows 960x540 at 1x,
## more than the whole widest sky. Phones and tablets get no minimum.
func test_the_desktop_minimum_window_shows_the_widest_sky() -> void:
	assert_eq(ScreenZones.min_window(true), Vector2i(960, 540))
	assert_eq(ScreenZones.min_window(false), Vector2i.ZERO, "not on a phone or a tablet")
	var visible := Vector2(ScreenZones.fill_size(ScreenZones.MIN_WINDOW))
	assert_eq(visible, Vector2(960, 540), "at 1x")
	assert_true(ScreenZones.holds_sky(visible, Fixtures.WIDE_SKY), "the 1920x1080 run fits the smallest window")
	assert_eq(ScreenZones.sky_margin(visible), Vector2i(230, 220), "the 640 cap, and every row as sky")
	var laptop := Vector2(ScreenZones.fill_size(Vector2i(1366, 705)))
	assert_true(ScreenZones.MIN_WINDOW.x <= 1366 and ScreenZones.MIN_WINDOW.y <= 705,
			"a maximised window on a 1366x768 laptop is allowed")
	assert_eq(laptop, Vector2(683, 352), "at 2x")


## Leaving fullscreen gives a 1280x720 window: 640x360 at 2x, so a run built fullscreen on a 1080p,
## 1440p or 4K monitor (640x360 each) still fits. The window Godot restores by itself from a
## fullscreen start (1264x681 here, the 1280x720 outer rect less its borders) would not, hence
## FullscreenKey sizes it.
func test_the_windowed_size_holds_a_fullscreen_run() -> void:
	var visible := Vector2(ScreenZones.fill_size(ScreenZones.WINDOWED_SIZE))
	assert_eq(visible, Vector2(640, 360))
	assert_true(ScreenZones.widens_sky(visible))
	for monitor: Vector2i in [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)] as Array[Vector2i]:
		var margin: Vector2i = ScreenZones.sky_margin(Vector2(ScreenZones.fill_size(monitor)))
		assert_true(ScreenZones.holds_sky(visible, ScreenZones.play_sky(margin.y, margin.x)), "%s fullscreen" % monitor)
	assert_false(ScreenZones.holds_sky(Vector2(ScreenZones.fill_size(Vector2i(1264, 681))), Fixtures.WIDE_SKY))
	# Accepted (the user, 2026-10-20): a 1366x768 laptop's fullscreen run (683x384) holds in its
	# maximised window (683x352) until it goes back to fullscreen or the next run.
	var laptop: Vector2i = ScreenZones.sky_margin(Vector2(683, 384))
	assert_eq(laptop, Vector2i(230, 64))
	assert_false(ScreenZones.holds_sky(Vector2(683, 352), ScreenZones.play_sky(laptop.y, laptop.x)))


## Q9: tablets may turn, phones stay portrait-locked. An iPad by its model; Android by the shorter
## side in dp (sw600dp).
func test_tablets_are_told_from_phones() -> void:
	assert_true(ScreenZones.is_tablet("iPad13,4", Vector2i(2048, 2732), 264), "iPad Pro")
	assert_true(ScreenZones.is_tablet("iPad14,1", Vector2i(1488, 2266), 326), "iPad mini")
	assert_false(ScreenZones.is_tablet("iPhone15,3", Vector2i(1290, 2796), 460), "iPhone Pro Max")
	assert_false(ScreenZones.is_tablet("iPhone15,3", Vector2i(1290, 2796), 72), "an iPhone whatever dpi it reports")
	assert_false(ScreenZones.is_tablet("Pixel 8", Vector2i(1080, 2400), 420), "a phone: 411 dp")
	assert_false(ScreenZones.is_tablet("Pixel 8", Vector2i(2400, 1080), 420), "held sideways too")
	assert_true(ScreenZones.is_tablet("SM-X710", Vector2i(1600, 2560), 320), "a tablet: 800 dp")
	assert_true(ScreenZones.is_tablet("SM-T290", Vector2i(800, 1280), 213), "just over 600 dp")
	assert_false(ScreenZones.is_tablet("X", Vector2i(798, 1280), 213), "just under")
	assert_false(ScreenZones.is_tablet("X", Vector2i(1600, 2560), 0), "an unknown dpi is a phone")


func test_the_game_sits_on_the_bottom_edge_centred_across() -> void:
	assert_eq(ScreenZones.game_offset(Vector2(180, 320)), Vector2i.ZERO, "9:16: nothing around it")
	assert_eq(ScreenZones.game_offset(Vector2(180, 400)), Vector2i(0, 80), "a taller phone: all the extra is sky above")
	assert_eq(ScreenZones.game_offset(Vector2(195, 422)), Vector2i(7, 102), "whole pixels")
	assert_eq(ScreenZones.game_offset(Vector2(100, 100)), Vector2i.ZERO, "never negative")
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(50, 90)
	assert_eq((ScreenZones.to_game(tap, Vector2i(0, 40)) as InputEventScreenTouch).position, Vector2(50, 50))


func test_the_sky_above_fades_into_space_with_cool_stars() -> void:
	var top := Color("#0e1438")
	assert_eq(Backdrop.space_colour(10, -1, top), top, "the sky's top colour carries on")
	assert_eq(Backdrop.space_colour(10, -Backdrop.SKY_BAND - Backdrop.SEAM - 1, top), Palette.N0, "then space")
	var stars: Array[Vector2i] = Backdrop.margin_stars(Rect2i(0, -100, 180, 420))
	assert_gt(stars.size(), 50, "a starfield above the game")
	for p: Vector2i in stars:
		assert_true(p.y < 0, "only in the margin sky, never over the game's screen")
	assert_eq(stars, Backdrop.margin_stars(Rect2i(0, -100, 180, 420)), "fixed: they never move")


func test_main_places_the_world_and_the_ui_layers_together() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var offset: Vector2i = ScreenZones.game_offset(main.get_viewport().get_visible_rect().size)
	assert_eq((main.get_node("BigBang/Shake") as Camera2D).position, Vector2(-offset), "the camera moves the world")
	for path: String in ["HUD", "EndScreen", "DebugLayer", "BigBang/Front"]:
		assert_eq((main.get_node(path) as CanvasLayer).offset, Vector2(offset), path + " follows")
	assert_eq((main.get_node("SoundToggle") as SoundToggle).screen_offset, offset)


func test_the_backdrop_carries_the_background_on() -> void:
	var image: Image = (load(BACKGROUND) as Texture2D).get_image()
	assert_eq(Backdrop.edge_colour(image, 0, 0).to_html(false), image.get_pixel(0, 0).to_html(false), "sky above")
	assert_eq(Backdrop.edge_colour(image, 0, 319).to_html(false), "0a0c26", "M0 ground below")


## Commit 16 (docs/wide_sky_design.md §4): a portrait sky, the game's own 180 columns however tall,
## leaves the Backdrop exactly as it was. Digests of the margin image and its star positions recorded
## from the Backdrop before the change (a8b76d57), with the sky the run takes on each window: every
## one is portrait, so its spare columns stay backdrop (ScreenZones.widens_sky) and the sky is side 0.
func test_a_portrait_sky_leaves_the_backdrop_as_it_was() -> void:
	var background: Image = (load(BACKGROUND) as Texture2D).get_image()
	var recorded: Array[Array] = [
		[Vector2(195, 422), "7f5e21232da92ecec038745bebbafa6e", "e5628473954434fbea3f07a16ab60585", 97],
		[Vector2(256, 341), "1db6913f5b1d6e8578cb752b177ecdf1", "b919b586f5be66d080ec4f28d789a6f1", 107],
		[Vector2(240, 320), "994f521f655676c06417c8c07c1ec382", "c43101c0afdf3f64eee57d5874e7543a", 65],
		[Vector2(180, 420), "03e8ed343116b2b75b7b4272a474ea6d", "ae7da7ddbdafc91c7016268ef00cf85e", 77],
	]
	for case: Array in recorded:
		var visible: Vector2 = case[0]
		var offset: Vector2i = ScreenZones.game_offset(visible)
		var area := Rect2i(-offset, Vector2i(visible))
		var margin: Vector2i = ScreenZones.sky_margin(visible)
		assert_eq(margin, Vector2i(0, offset.y), "%s: a portrait window keeps the 180 columns" % visible)
		var sky: Rect2i = ScreenZones.play_sky(margin.y, margin.x)
		assert_eq(Backdrop.vignette_radii(sky), Backdrop.OUTER_RADII, "%s: the vignette as it was" % visible)
		assert_false(Backdrop.star_free(sky).has_area(), "%s: no star kept off" % visible)
		var stars: Array[Vector2i] = Backdrop.margin_stars(area, sky)
		assert_eq(stars.size(), case[3], "%s: as many margin stars" % visible)
		assert_eq(str(stars).md5_text(), case[2], "%s: the same margin stars" % visible)
		assert_eq(stars, Backdrop.margin_stars(area), "%s: the same as with no sky given" % visible)
		var image: Image = Backdrop.margin_image(background, area, sky)
		assert_eq(image.get_data().hex_encode().md5_text(), case[1], "%s: the same margin image" % visible)


## On a wide play sky the vignette frames the whole sky: every pixel of the sky keeps its colour,
## and the outer sky only darkens past it (out on an ultrawide window, past the 640 cap).
func test_the_vignette_frames_a_wide_play_sky() -> void:
	var sky: Rect2i = Fixtures.WIDE_SKY
	var radii: Vector2 = Backdrop.vignette_radii(sky)
	assert_gte(radii.x, sky.size.x / 2.0 + 30.0, "at least the plan's max(120, w / 2 + 30)")
	assert_eq(radii.y, Backdrop.OUTER_RADII.y, "as tall as before")
	for x: int in range(sky.position.x, sky.end.x):
		for y: int in [sky.position.y, sky.end.y - 1]:
			assert_eq(Backdrop.outer_sky(Palette.N3, x, y, radii), Palette.N3, "no darker at the sky's edge (%d, %d)" % [x, y])
	for y: int in range(sky.position.y, sky.end.y):
		for x: int in [sky.position.x, sky.end.x - 1]:
			assert_eq(Backdrop.outer_sky(Palette.N3, x, y, radii), Palette.N3, "no darker at the sky's side (%d, %d)" % [x, y])
	assert_eq(Backdrop.outer_sky(Palette.N3, -300, 140, radii), Palette.N2, "a step darker out past the sky")
	assert_eq(Backdrop.outer_sky(Palette.N3, 480, 140, radii), Palette.N2, "on both sides")
	assert_eq(Backdrop.outer_sky(Palette.N3, -40, 140), Palette.N2, "a portrait run's vignette is unchanged")
	assert_lte(Backdrop.vignette_radii(ScreenZones.play_sky(80, 230)).x, 400.0, "a taller wide sky (1280x800) still a close frame")


## No margin star (glint arms included) stands over a wide play sky, so none can be taken for a star
## in play; they fill the margin outside it: above it, and out past it on an ultrawide window.
func test_margin_stars_keep_off_a_wide_play_sky() -> void:
	for visible: Vector2 in [Vector2(640, 360), Vector2(853, 360), Vector2(640, 400)]:
		var offset: Vector2i = ScreenZones.game_offset(visible)
		var margin: Vector2i = ScreenZones.sky_margin(visible)
		var sky: Rect2i = ScreenZones.play_sky(margin.y, margin.x)
		var area := Rect2i(-offset, Vector2i(visible))
		var stars: Array[Vector2i] = Backdrop.margin_stars(area, sky)
		assert_gt(stars.size(), 20, "%s: a starfield in the margin" % visible)
		for p: Vector2i in stars:
			for q: Vector2i in Backdrop.star_pixels(p):
				assert_false(sky.has_point(q), "%s: star at %s off the play sky" % [visible, p])
		assert_gt(Backdrop.margin_stars(area).size(), stars.size(), "%s: a portrait sky would have put stars there" % visible)
	var wide := Vector2(853, 360)
	var sky: Rect2i = ScreenZones.play_sky(40, 230)
	var stars: Array[Vector2i] = Backdrop.margin_stars(Rect2i(-ScreenZones.game_offset(wide), Vector2i(wide)), sky)
	var left: int = 0
	var right: int = 0
	for p: Vector2i in stars:
		if p.x < sky.position.x and p.y >= sky.position.y:
			left += 1
		elif p.x >= sky.end.x and p.y >= sky.position.y:
			right += 1
	assert_gt(left, 3, "ultrawide: stars out past the sky's left side")
	assert_gt(right, 3, "and past its right side")


## A glint next to a wide sky whose arm would reach over it is left out whole, not cut; one a column
## further out stays.
func test_a_glint_beside_a_wide_sky_is_left_out_whole() -> void:
	var glint := Vector2i(-1, -1)
	for p: Vector2i in Backdrop.margin_stars(Rect2i(-600, -200, 400, 400)):
		if Backdrop.star_pixels(p).size() > 1:
			glint = p
			break
	assert_ne(glint, Vector2i(-1, -1), "a glint in the margin to test with")
	var area := Rect2i(glint - Vector2i(3, 3), Vector2i(7, 7))
	var touching := Rect2i(glint + Vector2i(1, -50), Vector2i(640, 212))
	var clear := Rect2i(glint + Vector2i(2, -50), Vector2i(640, 212))
	assert_false(touching.has_point(glint), "the glint's core is outside the sky")
	assert_false(Backdrop.margin_stars(area, touching).has(glint), "its arm would reach over the sky: left out")
	assert_true(Backdrop.margin_stars(area, clear).has(glint), "a column clear of the sky: kept")


## Main hands the Backdrop the run's sky, and a new run's sky when it takes one.
func test_main_hands_the_backdrop_the_runs_sky() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var backdrop: Backdrop = main.get_node("Backdrop")
	assert_eq(backdrop.get("_sky"), main.run.sky_rect, "the run's sky")
	main.fit_visible(Vector2(195, 422))
	assert_eq(backdrop.get("_sky"), main.run.sky_rect, "a run in play keeps its sky")
	assert_true(main.restart(), "a new run")
	assert_eq(main.run.sky_rect, ScreenZones.play_sky(102), "the new run takes the tall phone's sky")
	assert_eq(backdrop.get("_sky"), main.run.sky_rect, "and the Backdrop follows it")
	main.fit_visible(Vector2(180, 320))
	assert_eq(backdrop.get("_sky"), ScreenZones.play_sky(102), "a resize mid-run keeps the run's sky")
	assert_true(main.is_held_for_sky(), "(and holds still until it fits)")
	main.fit_visible(Vector2(195, 422))
	assert_false(main.is_held_for_sky())
	backdrop.follow_sky(Fixtures.WIDE_SKY)
	assert_eq(backdrop.get("_sky"), Fixtures.WIDE_SKY, "follows a wide sky")
