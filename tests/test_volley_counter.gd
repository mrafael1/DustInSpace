extends GutTest
## Orion's volley countdown (#70): no number, a tiny constellation whose stars light as links
## count, hopping and flashing on each count, glowing on the last link, shaking when the volley
## fires, then dropping back in unlit.

const STEP: float = 1.0 / 60.0

var counter: VolleyCounter


func before_each() -> void:
	counter = VolleyCounter.new()
	add_child_autofree(counter)
	counter.set_process(false)
	counter.reset(2, 2)


func test_a_star_per_link_joined_by_a_string_and_no_number() -> void:
	assert_eq(counter.get_child_count(), 0, "no label: the stars are the count")
	assert_eq(counter.text(), "2")
	assert_eq(counter.lit_stars(), 0)
	var pixels: Dictionary[Vector2i, Color] = counter.pip_pixels()
	for i: int in 2:
		assert_eq(pixels[counter.star_at(i)], Palette.S2, "a hollow ember heart (#93: ember, not dim blue)")
		for axis: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			assert_eq(pixels[counter.star_at(i) + axis], Palette.S3, "ember arms")
	assert_true(pixels.values().has(Palette.S2), "an ember string between them")
	for c: Color in pixels.values():
		assert_false(c in [Palette.N4, Palette.N5, Palette.N6, Palette.N8], "no dim blue left")
	assert_eq(counter.star_at(0).y, counter.star_at(1).y)
	assert_lte(absi(counter.star_at(0).x + counter.star_at(1).x), 1, "centred")
	assert_eq(counter.star_at(0).y - VolleyCounter.ARM, 0, "its top on the origin")


func test_a_count_lights_a_pip_hops_and_flashes() -> void:
	counter.count(1)
	assert_eq(counter.lit_count(), 1)
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.HOP), "hops up")
	assert_eq(counter.lit_stars(), 1, "one star lit")
	var pixels: Dictionary[Vector2i, Color] = counter.pip_pixels()
	assert_eq(pixels[counter.star_at(0)], Palette.C0, "a white-hot heart")
	assert_eq(pixels[counter.star_at(0) + Vector2i.UP * VolleyCounter.ARM], Palette.C1, "longer arms")
	assert_eq(pixels[counter.star_at(1)], Palette.S2, "the next still hollow")
	var heights: Array[int] = []
	for i: int in 20:
		counter.advance(STEP)
		if heights.is_empty() or heights[-1] != counter.offset().y:
			heights.append(counter.offset().y)
	assert_eq(heights, [-VolleyCounter.HOP, -1, 0] as Array[int], "and settles, a pixel a step")


func test_the_last_link_glows_between_two_embers() -> void:
	counter.count(1)
	for i: int in 20:
		counter.advance(STEP)
	var seen: Dictionary = {}
	for i: int in 60:
		counter.advance(STEP)
		for c: Color in counter.pip_pixels().values():
			seen[c] = true
	assert_true(seen.has(Palette.S4) and seen.has(Palette.C3), "the lit star glows")
	assert_true(seen.has(Palette.S3), "the other stays an empty ember pip")


func test_the_volley_shakes_and_flashes_the_row_then_it_drops_back_empty() -> void:
	counter.count(1)
	counter.fire()
	assert_eq(counter.lit_stars(), 2, "every star fires")
	var xs: Dictionary = {}
	var colours: Dictionary = {}
	while counter.is_shaking():
		xs[counter.offset().x] = true
		colours[counter.colour()] = true
		counter.advance(STEP)
	assert_eq(xs.keys().size(), 2, "a pixel side to side")
	assert_true(colours.has(Palette.C0), "flashing")
	for i: int in 30:
		counter.advance(STEP)
		assert_eq(counter.lit_stars(), 2, "all lit while the arrows fly")
		assert_eq(counter.colour(), Palette.S4, "steady ember")
	counter.count(2)
	assert_eq(counter.lit_stars(), 0, "unlit again")
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.DROP), "dropping in from above")
	var last: int = counter.offset().y
	for i: int in 20:
		counter.advance(STEP)
		assert_gte(counter.offset().y, last, "falling")
		last = counter.offset().y
	assert_eq(counter.offset(), Vector2i.ZERO, "and lands")


func test_a_volley_with_the_count_unchanged_still_drops_back_unlit() -> void:
	# The intro's volley: the count stays full, but the fired row must still reset.
	counter.fire()
	for i: int in 30:
		counter.advance(1.0 / 60.0)
	assert_eq(counter.lit_stars(), 2)
	counter.count(2)
	assert_eq(counter.lit_stars(), 0, "unlit")
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.DROP), "dropping in")


func test_only_palette_colours_on_whole_pixels() -> void:
	var allowed: Array[Color] = [Palette.S2, Palette.S3, Palette.S4, Palette.C3, Palette.C1, Palette.C0]
	counter.reset(3, 3)
	counter.count(2)
	counter.count(1)
	counter.fire()
	for i: int in 60:
		counter.advance(STEP)
		for c: Color in counter.pip_pixels().values():
			assert_true(c in allowed)

