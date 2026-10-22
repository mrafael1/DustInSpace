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


# --- The frame edge is shaded on splash stages --------------------------------------------------

func test_a_wide_splash_stage_dots_the_frames_sides() -> void:
	var run: RunState = _run("pisces_knot")
	var seam: SeamView = _sky_view(run).get_node("SeamLayer")
	seam.setup(run)
	var dots: Dictionary[Vector2i, Color] = seam.pixels()
	for y: int in range(38, 250, 2):
		assert_eq(dots.get(Vector2i(-1, y)), SeamView.FRAME_EDGE_COLOUR, "the frame's left side")
		assert_eq(dots.get(Vector2i(180, y)), SeamView.FRAME_EDGE_COLOUR, "the frame's right side")
	assert_eq(SeamView.FRAME_EDGE_COLOUR, Palette.S3)


func test_no_frame_edge_without_a_splash_or_on_the_portrait_sky() -> void:
	var circlet: RunState = _run("pisces_circlet")
	var seam: SeamView = _sky_view(circlet).get_node("SeamLayer")
	seam.setup(circlet)
	assert_false(seam.pixels().has(Vector2i(-1, 100)), "the Circlet has no splash")
	var home: RunState = _run("pisces_knot", Fixtures.SKY)
	assert_true(CurrentView.outside_frame(home.frame_rect, home.sky_rect).is_empty())
	assert_true(CurrentView.frame_side_pixels(home.frame_rect, home.sky_rect).is_empty())


# --- The ram stands at the frame's edge ---------------------------------------------------------

func test_the_ram_and_its_lane_are_drawn_within_the_frame() -> void:
	var run: RunState = _run("aries_horns")
	var view: ChargeView = _sky_view(run).get_node("ChargeLayer")
	view.setup(run)
	var dots: Dictionary[Vector2i, Color] = view.pixels()
	assert_false(dots.is_empty())
	for p: Vector2i in dots:
		assert_true(run.frame_rect.has_point(p), "%s inside the frame %s" % [p, run.frame_rect])
	var head: Vector2i = ChargeView.head_origin(run.ram.row, run.frame_rect)
	assert_eq(head.x, run.frame_rect.position.x + 1, "a pixel in from the frame's left edge")


func test_a_wide_ram_stage_shades_and_dots_the_frame_edge() -> void:
	var run: RunState = _run("aries_horns")
	var current := CurrentView.new()
	add_child_autofree(current)
	current.setup(run, sequencer)
	var dots: Dictionary[Vector2i, Color] = current.pixels()
	for y: int in range(38, 250, 2):
		assert_eq(dots.get(Vector2i(-1, y)), Palette.S3)
		assert_eq(dots.get(Vector2i(180, y)), Palette.S3)
	var home: RunState = _run("aries_horns", Fixtures.SKY)
	var home_current := CurrentView.new()
	add_child_autofree(home_current)
	home_current.setup(home, sequencer)
	assert_true(home_current.pixels().is_empty(), "nothing on the 9:16 sky")


# --- The aim keeps to the phone box (§9) --------------------------------------------------------

const TelescopeScene := preload("res://game/scenes/telescope.tscn")


func _scope(run: RunState) -> Telescope:
	var scope: Telescope = TelescopeScene.instantiate()
	scope.position = Vector2(90, 270)
	add_child_autofree(scope)
	scope.set_process(false)
	scope.setup(run, sequencer)
	return scope


func test_the_aim_stops_at_the_phone_boxs_edge() -> void:
	for map_id: String in ["heart", "aquarius_final", "pisces_knot", "aries_head"]:
		var run: RunState = _run(map_id)
		var scope: Telescope = _scope(run)
		var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
		assert_true(inner.has_point(scope.burst_preview()), "%s: the aim starts in the box" % map_id)
		for point: Vector2i in [Vector2i(-200, 150), Vector2i(400, 150), Vector2i(90, 40), Vector2i(90, 240), Vector2i(-230, 38)]:
			scope.aim_at(point)
			assert_eq(scope.burst_preview(), StarScatter.clamp_to_sky(point, run.frame_rect), "%s: %s stops at the box" % [map_id, point])
			assert_true(inner.has_point(scope.burst_preview()))
	var tail: RunState = _run("tail")
	var tail_scope: Telescope = _scope(tail)
	tail_scope.aim_at(Vector2i(-200, 45))
	assert_eq(tail_scope.burst_preview(), StarScatter.clamp_to_sky(Vector2i(-200, 45), Fixtures.WIDE_SKY), "no edge stake: the whole wide sky")


func test_the_red_split_preview_splits_in_the_box() -> void:
	var run: RunState = _run("aquarius_final")
	run.owned_packs["red"] = 1
	assert_true(run.load_pack("red"))
	var scope: Telescope = _scope(run)
	var inner: Rect2i = StarScatter.inner_rect(run.frame_rect)
	scope.aim_at(Vector2i(-50, 60))
	var points: Array[Vector2i] = scope.burst_points()
	assert_eq(points.size(), 2)
	assert_eq(points, run.splash_points("red", scope.burst_preview()), "the preview is where the core splits")
	for at: Vector2i in points:
		assert_true(inner.has_point(at), "twin preview %s in the box" % at)


func test_a_finger_lifted_below_the_box_lets_the_launch_go() -> void:
	var box_run: RunState = _run("heart")
	var scope: Telescope = _scope(box_run)
	var strip_aim := Vector2i(165, box_run.frame_rect.end.y + 4)
	var point: Vector2i = strip_aim - scope.origin() + Vector2i(0, Telescope.TOUCH_LIFT)
	assert_true(Fixtures.WIDE_SKY.has_point(strip_aim), "still over the sky")
	assert_false(scope.on_scope(point), "away from the telescope")
	assert_true(scope.lets_go(point), "below the box, as below a phone's sky")
	var tail: RunState = _run("tail")
	assert_false(_scope(tail).lets_go(point), "no edge stake: the sky's own bottom")


func test_the_flight_decoys_land_in_the_box() -> void:
	var run: RunState = _run("aries_head")
	var view: SkyView = _sky_view(run)
	view.set("_launched_kind", "red")
	var box: Rect2i = run.frame_rect
	for burst: Vector2i in [StarScatter.clamp_to_sky(Vector2i(0, 58), box), StarScatter.clamp_to_sky(Vector2i(179, 229), box)]:
		var decoys: Array[Star] = view.call("_decoys", burst)
		assert_false(decoys.is_empty())
		for decoy: Star in decoys:
			assert_true(box.has_point(decoy.position), "decoy %s in the box" % decoy.position)
