extends GutTest
## The views on a wide sky (docs/wide_sky_design.md §4): what stands by the constellation follows
## the run's frame (RunState.frame_rect), not the sky's left edge.

const Fixtures := preload("res://tests/fixtures.gd")
const SkyScene := preload("res://game/scenes/sky.tscn")
const HudScene := preload("res://game/ui/hud.tscn")

var sequencer: EventSequencer


func before_each() -> void:
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)


func _run(map_id: String, sky: Rect2i = Fixtures.WIDE_SKY) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(3), sky, StarMap.by_id(map_id))
	sequencer.bind(run)
	return run


func _sky_view(run: RunState) -> SkyView:
	var view: SkyView = SkyScene.instantiate()
	add_child_autofree(view)
	view.setup(run, sequencer)
	return view


func _hud(run: RunState) -> Hud:
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.setup(run, sequencer)
	return hud


# --- Orion stands in the frame's corner ---------------------------------------------------------

func test_orions_figure_stands_in_the_frames_top_left() -> void:
	var run: RunState = _run("tail")
	var orion: OrionView = _sky_view(run).get_node("OrionLayer")
	assert_true(orion.is_figure_shown())
	var corner := Rect2i(run.frame_rect.position, Volley.ORION_CORNER.size)
	for p: Vector2i in orion.figure_pixels():
		assert_true(corner.has_point(p), "%s in the frame's corner %s, not the sky's" % [p, corner])


func test_the_volleys_arrows_hang_along_the_frames_top() -> void:
	var run: RunState = _run("body")
	var orion: OrionView = _sky_view(run).get_node("OrionLayer")
	var home: RunState = _run("body", Fixtures.SKY)
	var home_orion: OrionView = _sky_view(home).get_node("OrionLayer")
	var spots: Array[Vector2i] = orion.overhead_spots()
	var home_spots: Array[Vector2i] = home_orion.overhead_spots()
	assert_eq(spots.size(), home_spots.size())
	for i: int in spots.size():
		assert_eq(spots[i], home_spots[i] + Vector2i(0, run.frame_rect.position.y - home.frame_rect.position.y), "as at home, with the frame")


func test_the_volley_counter_and_encounter_line_follow_the_frame() -> void:
	var run: RunState = _run("body")
	var hud: Hud = _hud(run)
	assert_eq(hud._volley.position, Vector2(run.frame_rect.position + OrionView.FIGURE_AT + Hud.VOLLEY_COUNTER_OFFSET))
	var block: Rect2i = hud.encounter_block(Hud.ENCOUNTER_LINES[Encounter.Threat.VOLLEY] % 2)
	assert_gte(block.position.x, run.frame_rect.position.x + Hud.ENCOUNTER_LINE_LEFT, "right of Orion's corner")
	assert_lte(block.end.x, run.frame_rect.end.x, "inside the frame, by the figure")


func test_on_the_portrait_sky_the_frame_is_the_sky() -> void:
	var run: RunState = _run("body", Fixtures.SKY)
	var hud: Hud = _hud(run)
	assert_eq(hud._volley.position, Vector2(Fixtures.SKY.position + OrionView.FIGURE_AT + Hud.VOLLEY_COUNTER_OFFSET))


# --- The frame edge is shaded on drain stages ---------------------------------------------------

func test_a_wide_drain_stage_shades_the_sky_outside_the_frame() -> void:
	var run: RunState = _run("aquarius_body")
	var rects: Array[Rect2i] = CurrentView.frame_shade_rects(run.current, run.sky_rect)
	assert_eq(rects, [Rect2i(-230, 38, 230, 212), Rect2i(180, 38, 230, 212)] as Array[Rect2i])
	var current := CurrentView.new()
	add_child_autofree(current)
	current.setup(run, sequencer)
	var dots: Dictionary[Vector2i, Color] = current.pixels()
	for y: int in range(38, 250, 2):
		assert_eq(dots.get(Vector2i(-1, y)), Palette.S3, "the frame's left side wears the drain line")
		assert_eq(dots.get(Vector2i(180, y)), Palette.S3)


func test_no_shade_without_a_drain_or_on_the_portrait_sky() -> void:
	var hand: RunState = _run("aquarius_hand")
	assert_true(CurrentView.frame_shade_rects(hand.current, hand.sky_rect).is_empty(), "the Hand has no drain")
	for map_id: String in ["aquarius_body", "aquarius_stream", "aquarius_jar", "aquarius_final"]:
		var home: RunState = _run(map_id, Fixtures.SKY)
		assert_true(CurrentView.frame_shade_rects(home.current, home.sky_rect).is_empty(), map_id)
		assert_true(CurrentView.frame_edge_pixels(home.current, home.sky_rect).is_empty(), map_id)


func test_the_shade_is_palette_locked() -> void:
	assert_eq(CurrentView.SHADE_COLOUR, Palette.S1)
