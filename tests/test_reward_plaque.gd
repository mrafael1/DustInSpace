extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const PlaqueScene := preload("res://game/ui/reward_plaque.tscn")


func test_plaque_sits_above_the_star_on_whole_pixels() -> void:
	var at: Vector2i = RewardPlaque.place(Vector2i(90, 160), 7, Fixtures.SKY)
	assert_eq(at, Vector2i(90 - 23, 160 - 7 - RewardPlaque.GAP - 11))


func test_plaque_drops_below_a_star_at_the_top_of_the_sky() -> void:
	var at: Vector2i = RewardPlaque.place(Vector2i(90, 86), 7, Fixtures.SKY)
	assert_gt(at.y, 86 + 7, "below the sprite")
	assert_true(Fixtures.SKY.encloses(Rect2i(at, RewardPlaque.PLAQUE_SIZE)))


func test_plaque_stays_on_screen_at_the_sides() -> void:
	for x: int in [0, 8, 172, 179]:
		var at: Vector2i = RewardPlaque.place(Vector2i(x, 160), 7, Fixtures.SKY)
		assert_true(Fixtures.SKY.encloses(Rect2i(at, RewardPlaque.PLAQUE_SIZE)), "x %d" % x)


func test_plaque_labels_take_their_colours_from_the_palette() -> void:
	var plaque: RewardPlaque = PlaqueScene.instantiate()
	add_child_autofree(plaque)
	assert_eq((plaque.get_node("Dust") as Label).get_theme_color("font_color"), Palette.D0, "dust")
	assert_eq((plaque.get_node("Light") as Label).get_theme_color("font_color"), Palette.C1, "light")
	assert_eq((plaque.get_node("NoCombo") as Label).get_theme_color("font_color"), Palette.N7, "no value")


func test_plaque_shows_numbers_as_labels() -> void:
	var plaque: RewardPlaque = PlaqueScene.instantiate()
	add_child_autofree(plaque)
	assert_false(plaque.visible)
	plaque.show_reward(3, 25, Vector2i(90, 160), 7, Fixtures.SKY)
	assert_true(plaque.visible)
	assert_eq((plaque.get_node("Dust") as Label).text, "+3")
	assert_eq((plaque.get_node("Light") as Label).text, "+25")
	assert_false((plaque.get_node("NoCombo") as Label).visible)
	assert_eq(plaque.size, Vector2(46, 11))
	plaque.show_no_combo(Vector2i(90, 160), 7, Fixtures.SKY)
	assert_true((plaque.get_node("NoCombo") as Label).visible)
	assert_false((plaque.get_node("Dust") as Label).visible)
