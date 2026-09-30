extends GutTest
## Orion's volley countdown (#70): no number, a row of pips that light as links count, hopping and
## flashing on each count, glowing on the last link, shaking when the volley fires, then dropping
## back in empty.

const STEP: float = 1.0 / 60.0

var counter: VolleyCounter


func before_each() -> void:
	counter = VolleyCounter.new()
	add_child_autofree(counter)
	counter.set_process(false)
	counter.reset(2, 2)


func test_a_pip_per_link_and_no_number() -> void:
	assert_eq(counter.get_child_count(), 0, "no label: the pips are the count")
	assert_eq(counter.text(), "2")
	var pips: Dictionary[Vector2i, Color] = counter.pip_pixels()
	assert_eq(pips.size(), 2 * VolleyCounter.PIP * VolleyCounter.PIP, "two pips")
	for c: Color in pips.values():
		assert_eq(c, Palette.N5, "none lit yet")
	var xs: Array[int] = []
	for p: Vector2i in pips:
		xs.append(p.x)
	assert_lte(absi(xs.min() + xs.max()), 1, "centred")


func test_a_count_lights_a_pip_hops_and_flashes() -> void:
	counter.count(1)
	assert_eq(counter.lit_count(), 1)
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.HOP), "hops up")
	assert_eq(_lit(), VolleyCounter.PIP * VolleyCounter.PIP, "one pip lit")
	assert_true(counter.pip_pixels().values().has(Palette.C0), "flashing white")
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
	assert_true(seen.has(Palette.S4) and seen.has(Palette.C3), "the lit pip glows")
	assert_true(seen.has(Palette.N5), "the other stays dim")


func test_the_volley_shakes_and_flashes_the_row_then_it_drops_back_empty() -> void:
	counter.count(1)
	counter.fire()
	assert_eq(_lit(), 2 * VolleyCounter.PIP * VolleyCounter.PIP, "every pip fires")
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
		assert_eq(_lit(), 2 * VolleyCounter.PIP * VolleyCounter.PIP, "all lit while the arrows fly")
		assert_eq(counter.colour(), Palette.S4, "steady ember")
	counter.count(2)
	assert_eq(_lit(), 0, "emptied")
	assert_eq(counter.offset(), Vector2i(0, -VolleyCounter.DROP), "dropping in from above")
	var last: int = counter.offset().y
	for i: int in 20:
		counter.advance(STEP)
		assert_gte(counter.offset().y, last, "falling")
		last = counter.offset().y
	assert_eq(counter.offset(), Vector2i.ZERO, "and lands")


func test_only_palette_colours_on_whole_pixels() -> void:
	var allowed: Array[Color] = [Palette.N5, Palette.N8, Palette.S4, Palette.C3, Palette.C0]
	counter.reset(3, 3)
	counter.count(2)
	counter.count(1)
	counter.fire()
	for i: int in 60:
		counter.advance(STEP)
		for c: Color in counter.pip_pixels().values():
			assert_true(c in allowed)


func _lit() -> int:
	return counter.pip_pixels().values().filter(func(c: Color) -> bool: return c != Palette.N5).size()
