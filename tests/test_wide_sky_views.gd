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
