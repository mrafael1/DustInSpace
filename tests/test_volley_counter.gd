extends GutTest
## Orion's volley countdown (#70): the number of links left with pips, hopping and flashing on each
## count, glowing on the last link, shaking when the volley fires, and dropping the next one in.

const STEP: float = 1.0 / 60.0

var counter: VolleyCounter


func before_each() -> void:
	counter = VolleyCounter.new()
	var number := Label.new()
	number.name = "Number"
	counter.add_child(number)
	add_child_autofree(counter)
	counter.set_process(false)
	counter.reset(2, 2)


func test_it_shows_the_links_left_and_a_pip_per_link() -> void:
	assert_eq(counter.text(), "2")
	assert_eq(counter.offset(), Vector2i.ZERO)
	assert_eq(counter.colour(), Palette.N8)
	var pips: Dictionary[Vector2i, Color] = counter.pip_pixels()
	assert_eq(pips.size(), 2 * VolleyCounter.PIP * VolleyCounter.PIP, "two pips")
	for p: Vector2i in pips:
		assert_eq(pips[p], Palette.N5, "none counted yet")
		assert_gt(p.y, 7, "under the number")
	var xs: Array[int] = []
	for p: Vector2i in pips:
		xs.append(p.x)
	assert_eq(xs.min() + xs.max(), -1, "centred under it")


func test_a_count_hops_flashes_and_fills_a_pip() -> void:
	counter.count(1)
	assert_eq(counter.text(), "1")
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.HOP), "hops up")
	assert_eq(counter.colour(), Palette.C0, "flashes white")
	var filled: int = counter.pip_pixels().values().filter(func(c: Color) -> bool: return c != Palette.N5).size()
	assert_eq(filled, VolleyCounter.PIP * VolleyCounter.PIP, "one pip lit")
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
		seen[counter.colour()] = true
	assert_eq(seen.keys().size(), 2)
	assert_true(seen.has(Palette.S4) and seen.has(Palette.C3))


func test_the_volley_shakes_it_then_the_next_number_drops_in() -> void:
	counter.count(1)
	counter.fire()
	assert_true(counter.is_shaking())
	var xs: Dictionary = {}
	var colours: Dictionary = {}
	while counter.is_shaking():
		xs[counter.offset().x] = true
		colours[counter.colour()] = true
		assert_eq(counter.offset().y, 0)
		counter.advance(STEP)
	assert_eq(xs.keys().size(), 2, "a pixel side to side")
	assert_true(colours.has(Palette.C0), "flashing")
	counter.count(2)
	assert_eq(counter.text(), "2")
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.DROP), "the next drops in from above")
	var last: int = counter.offset().y
	for i: int in 20:
		counter.advance(STEP)
		assert_gte(counter.offset().y, last, "falling")
		last = counter.offset().y
	assert_eq(counter.offset(), Vector2i.ZERO, "and lands")
	assert_eq(counter.colour(), Palette.N8)


func test_only_palette_colours_on_whole_pixels() -> void:
	var allowed: Array[Color] = [Palette.N5, Palette.N8, Palette.S4, Palette.C3, Palette.C0]
	counter.count(1)
	counter.fire()
	for i: int in 60:
		counter.advance(STEP)
		assert_true(counter.colour() in allowed)
		var number: Label = counter.get_node("Number")
		assert_eq(number.position, number.position.round())
		for c: Color in counter.pip_pixels().values():
			assert_true(c in allowed)
