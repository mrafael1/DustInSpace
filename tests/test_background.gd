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
	assert_eq(background.get_index(), 0, "drawn first: behind the Sun's glow, the stars and the HUD")
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
