extends GutTest
## The night background (assets/art/background.png, tools/art/build_background.py).

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
