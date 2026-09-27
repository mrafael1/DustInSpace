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


func test_the_forest_ground_under_the_hud_is_dark() -> void:
	var image: Image = (load(BACKGROUND) as Texture2D).get_image()
	var off: int = 0
	for y: int in range(288, 320):
		for x: int in 180:
			if image.get_pixel(x, y).to_html(false) != "0a0c26":
				off += 1
	assert_eq(off, 0, "flat M0 from y 288 down: the HUD reads on it")


## The sky and land ramps from the .gpl, by hex.
func _cool_colours() -> Dictionary[String, String]:
	var colours: Dictionary[String, String] = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 4 and fields[0].is_valid_int() and fields[3].left(1) in RAMP_NAMES:
			colours[Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()).to_html(false)] = fields[3]
	return colours


func test_the_game_screen_sits_centred_on_whole_pixels() -> void:
	assert_eq(ScreenZones.game_offset(Vector2(180, 320)), Vector2i.ZERO, "9:16: nothing around it")
	assert_eq(ScreenZones.game_offset(Vector2(180, 400)), Vector2i(0, 40), "a taller phone: sky above, ground below")
	assert_eq(ScreenZones.game_offset(Vector2(191, 320)), Vector2i(5, 0), "whole pixels")
	assert_eq(ScreenZones.game_offset(Vector2(100, 100)), Vector2i.ZERO, "never negative")
	var tap := InputEventScreenTouch.new()
	tap.position = Vector2(50, 90)
	assert_eq((ScreenZones.to_game(tap, Vector2i(0, 40)) as InputEventScreenTouch).position, Vector2(50, 50))


func test_main_centres_the_world_and_the_ui_layers_together() -> void:
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
