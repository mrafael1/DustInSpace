extends GutTest
## Pisces's cord trial in the scenes: the CORD ON/OFF switch, the cords drawn as a dim rope on the
## palette (laid after a link, gone with a clear), the trace refusing a step across one and breaking
## where it would cross, and the rule said as the trial opens.

const MainScene := preload("res://game/scenes/main.tscn")

## A small triple up the open sky's left side (clear of the Heart's stars): linked, it ties the cord
## x = 30, y 95-135.
const CORD_POINTS: Array[Vector2i] = [Vector2i(30, 95), Vector2i(30, 115), Vector2i(30, 135)]
## Two mediums either side of the cord (their step crosses it) and one below it that reaches both.
const LEFT := Vector2i(18, 110)
const RIGHT := Vector2i(44, 110)
const BELOW := Vector2i(31, 150)
const ROPE: Array[Color] = [Palette.N5, Palette.N6]
const EMBER: Array[Color] = [Palette.S3, Palette.S4]

var main: Main
var run: RunState
var sky: SkyView
var sequencer: EventSequencer
var view: CordView


func _start(enabled: bool = true) -> void:
	main = MainScene.instantiate()
	main.current_trial = true
	main.current_layout = "cord"
	main.current_enabled = enabled
	main.seed_override = 7
	add_child_autofree(main)
	run = main.run
	sky = main.get_node("Sky")
	sequencer = main.get_node("EventSequencer")
	view = main.get_node("Sky/CordLayer")
	for node: Node in [sequencer, view, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sky/ConstellationLayer"), main.get_node("Sun")]:
		node.set_process(false)
	_play_out()


func test_trial_switch_replays_the_same_seed_without_cords() -> void:
	_start()
	assert_not_null(run.cords)
	assert_eq(run.scorpio.map.id, "cord_trial")
	main.switch_current()
	assert_null(main.run.cords)
	assert_eq(main.run.run_seed, 7)
	assert_false((main.get_node("Sky/CordLayer") as CordView).is_processing())
	main.switch_current()
	assert_not_null(main.run.cords)
	assert_true(view.is_processing())


func test_controls_name_the_cords() -> void:
	_start()
	var controls: CurrentTrialControls = main.get_node("CurrentTrialControls")
	assert_true(controls.visible)
	assert_eq((controls.get("_button") as MapButton).text, "CORD ON")
	assert_eq((controls.get("_caption") as Label).text, "LINKS LEAVE CORDS")
	main.switch_current()
	assert_eq((controls.get("_button") as MapButton).text, "CORD OFF")
	assert_eq((controls.get("_caption") as Label).text, "LINKS LEAVE NOTHING")


func test_the_rule_is_said_as_the_trial_opens() -> void:
	_start()
	assert_eq((main.get_node("HUD") as Hud).message(), Hud.CORD_MESSAGE)
	for line: String in Hud.CORD_MESSAGE.split("\n"):
		assert_lt(line.length(), 26, "fits the message line")


func test_a_link_lays_a_dim_rope_once_its_flash_fades() -> void:
	_start()
	_tie_the_cord()
	assert_true(view.pixels().is_empty(), "nothing while the link's collect flash plays")
	view.advance(CordView.TIE_DELAY + CordView.TIE_TIME * 0.25)
	assert_eq(view.pixels().get(CORD_POINTS[0]), Palette.N7, "laid solid from the first star picked")
	view.advance(CordView.TIE_TIME + CordView.TIE_FLASH)
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	assert_eq(view.shown_count(), 2)
	for p: Vector2i in LinkLayer.path_pixels(CORD_POINTS):
		assert_true(not pixels.has(p) or ROPE.has(pixels[p]), "%s: the rope" % p)
	for color: Color in pixels.values():
		assert_has(ROPE, color, "never the lit strings' gold")
	assert_eq(pixels[CORD_POINTS[1]], Palette.N6, "a knot where the middle star stood")
	var gaps: int = LinkLayer.path_pixels(CORD_POINTS).filter(func(p: Vector2i) -> bool: return not pixels.has(p)).size()
	assert_gt(gaps, 0, "dashed")


func test_the_rope_stays_on_the_palette_and_glows_ember_when_crossed() -> void:
	var rope: Dictionary[Vector2i, Color] = CordView.rope_pixels(Vector2i(30, 95), Vector2i(30, 135), false)
	var hot: Dictionary[Vector2i, Color] = CordView.rope_pixels(Vector2i(30, 95), Vector2i(30, 135), true)
	for color: Color in rope.values():
		assert_has(ROPE, color)
	for color: Color in hot.values():
		assert_has(EMBER, color)
	for color: Color in CordView.laying_pixels(Vector2i(30, 95), Vector2i(30, 135), 0.5).values():
		assert_eq(color, Palette.N7)


func test_a_cord_the_trace_would_cross_glows() -> void:
	_start()
	_tie_the_cord()
	view.advance(1.0)
	view.tracing_step = [LEFT, RIGHT] as Array[Vector2i]
	assert_eq(view.pixels()[CORD_POINTS[0] + Vector2i(0, 4)], Palette.S4, "the crossed half glows ember")
	view.tracing_step = [LEFT, LEFT + Vector2i(0, -40)] as Array[Vector2i]
	assert_has(ROPE, view.pixels()[CORD_POINTS[0] + Vector2i(0, 4)], "a step that doesn't cross leaves it dim")


func test_cords_go_with_the_cleared_sky() -> void:
	_start()
	_tie_the_cord()
	view.advance(1.0)
	run.light = run.light_target() - 1
	var a: Star = _star(Star.Size.MEDIUM, Vector2i(150, 220))
	var b: Star = _star(Star.Size.MEDIUM, Vector2i(160, 240))
	var c: Star = _star(Star.Size.MEDIUM, Vector2i(140, 240))
	var cleared: Array[bool] = []
	run.cords_cleared.connect(func() -> void: cleared.append(true))
	assert_ne(run.link([a.id, b.id, c.id] as Array[int]), Combos.INVALID)
	assert_eq(cleared.size(), 1, "the Sun rekindled and cleared the sky")
	_play_out()
	view.advance(1.0)
	assert_eq(view.shown_count(), 0)
	assert_true(view.pixels().is_empty())


func test_a_big_bang_keeps_the_cords_until_its_freeze() -> void:
	_start()
	_tie_the_cord()
	view.advance(1.0)
	run.cords.clear()
	view.clear_cords()
	view.hold_for_big_bang()
	view.advance(BigBangSequence.FREEZE_AT - 0.05)
	assert_has(ROPE, view.pixels()[CORD_POINTS[1]], "the bang still opens like a burst")
	view.advance(0.1)
	assert_eq(view.pixels()[CORD_POINTS[1]], Palette.N7, "at the freeze they flash")
	view.advance(CordView.CLEAR_FLASH + 0.01)
	assert_true(view.pixels().is_empty(), "and go")


func test_a_restart_rebuilds_the_cords_from_the_run() -> void:
	_start()
	_tie_the_cord()
	view.setup(run, sequencer)
	assert_eq(view.shown_count(), 2)
	for color: Color in view.pixels().values():
		assert_has(ROPE, color)


func test_a_star_across_a_cord_cant_join_and_nothing_is_used() -> void:
	_start()
	_tie_the_cord()
	var left: Star = _star(Star.Size.MEDIUM, LEFT)
	var right: Star = _star(Star.Size.MEDIUM, RIGHT)
	var below: Star = _star(Star.Size.MEDIUM, BELOW)
	var refused: Array[bool] = []
	sky.step_refused.connect(func() -> void: refused.append(true))
	var dust: int = run.dust
	_tap(left.position)
	_tap(right.position)
	assert_eq(sky.selected_ids(), [left.id] as Array[int], "across the cord: it doesn't join")
	assert_eq(refused, [true], "the step shakes ember with a buzz")
	assert_eq(run.stars.size(), 3)
	assert_eq(run.dust, dust)
	_tap(below.position)
	_tap(right.position)
	assert_eq(run.stars.size(), 0, "round the cord: linked")
	assert_eq(run.cords.count(), 4)


func test_the_trace_breaks_where_it_would_cross_a_cord() -> void:
	_start()
	_tie_the_cord()
	var link_layer: LinkLayer = main.get_node("Sky/LinkLayer")
	var left: Star = _star(Star.Size.MEDIUM, LEFT)
	_star(Star.Size.MEDIUM, BELOW)
	_touch(left.position, true)
	_drag(left.position + Vector2i(0, -10))
	assert_false(link_layer.is_loose_end())
	assert_eq(link_layer.cord_cut(), StarCords.NO_CROSSING)
	_drag(RIGHT)
	assert_true(link_layer.is_loose_end(), "in reach, but across a cord")
	assert_eq(link_layer.cord_cut(), Vector2i(30, 110), "it breaks on the cord")
	assert_eq(view.tracing_step, [LEFT, RIGHT] as Array[Vector2i])
	_touch(RIGHT, false)
	assert_eq(view.tracing_step, [] as Array[Vector2i])


func test_cords_draw_under_the_map_and_the_stars() -> void:
	_start()
	var order: int = view.get_index()
	assert_lt(order, main.get_node("Sky/ConstellationLayer").get_index(), "a lit landmark or string keeps its gold over a cord")
	assert_lt(order, main.get_node("Sky/LinkLayer").get_index())
	assert_lt(order, main.get_node("Sky/StarLayer").get_index())


func test_a_tapped_step_across_a_cord_has_that_cord_glow_with_the_shake() -> void:
	_start()
	_tie_the_cord()
	view.advance(1.0)
	var left: Star = _star(Star.Size.MEDIUM, LEFT)
	var right: Star = _star(Star.Size.MEDIUM, RIGHT)
	_tap(left.position)
	_tap(right.position)
	assert_eq(view.tracing_step, [] as Array[Vector2i], "a tap traces nothing to the finger")
	assert_true(view.is_flashing_blocking())
	assert_eq(view.pixels()[CORD_POINTS[0] + Vector2i(0, 4)], Palette.S4, "the cord it crosses glows ember")
	assert_has(ROPE, view.pixels()[CORD_POINTS[2]], "the half it doesn't cross stays dim")
	view.advance(LinkLayer.REJECT_TIME + 0.01)
	assert_false(view.is_flashing_blocking())
	assert_has(ROPE, view.pixels()[CORD_POINTS[0] + Vector2i(0, 4)], "dim again once the shake is over")


func test_only_a_cord_within_the_reach_breaks_the_trace_and_glows() -> void:
	_start()
	_tie_the_cord()
	view.advance(1.0)
	var link_layer: LinkLayer = main.get_node("Sky/LinkLayer")
	var far: Star = _star(Star.Size.MEDIUM, Vector2i(100, 110))
	_touch(far.position, true)
	_drag(Vector2i(10, 110))
	assert_true(link_layer.is_loose_end(), "past the reach")
	assert_eq(link_layer.cord_cut(), StarCords.NO_CROSSING, "the cord lies past the reach")
	assert_has(ROPE, view.pixels()[CORD_POINTS[0] + Vector2i(0, 4)], "so it doesn't glow")
	_touch(Vector2i(10, 110), false)
	var near: Star = _star(Star.Size.MEDIUM, Vector2i(64, 110))
	_touch(near.position, true)
	_drag(Vector2i(4, 110))
	assert_eq(link_layer.cord_cut(), Vector2i(30, 110), "within the reach, it breaks on the cord")
	assert_eq(view.pixels()[CORD_POINTS[0] + Vector2i(0, 4)], Palette.S4)


func test_with_cords_off_nothing_is_drawn_and_the_trace_never_breaks_on_one() -> void:
	_start(false)
	_tie_the_cord()
	view.advance(1.0)
	assert_true(view.pixels().is_empty())
	var link_layer: LinkLayer = main.get_node("Sky/LinkLayer")
	var left: Star = _star(Star.Size.MEDIUM, LEFT)
	_touch(left.position, true)
	_drag(RIGHT)
	assert_false(link_layer.is_loose_end())
	assert_eq(link_layer.cord_cut(), StarCords.NO_CROSSING)
	assert_eq(view.tracing_step, [] as Array[Vector2i])


func test_before_cut_stops_a_pixel_short_of_the_cord() -> void:
	var line: Array[Vector2i] = LinkLayer.line_pixels(LEFT, RIGHT)
	var kept: Array[Vector2i] = LinkLayer.before_cut(line, LEFT, Vector2i(30, 110))
	assert_eq(kept[-1], Vector2i(29, 110))


## Links the small triple up the left side, tying the cord; its events play.
func _tie_the_cord() -> void:
	var ids: Array[int] = []
	for point: Vector2i in CORD_POINTS:
		ids.append(run.add_star(Star.Size.SMALL, point).id)
	assert_eq(run.link(ids), "small_triple")
	sequencer.advance(0.0)


## Plays every queued event (the sequencer's processing is off).
func _play_out() -> void:
	for i: int in 400:
		if not sequencer.is_busy():
			break
		sequencer.advance(0.1)
		view.advance(0.1)


## A star in the sky with a view, as if it had burst there.
func _star(size: Star.Size, at: Vector2i) -> Star:
	var star: Star = run.add_star(size, at)
	sky.setup(run, sequencer)
	return star


func _tap(at: Vector2i) -> void:
	_touch(at, true)
	_touch(at, false)


func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	sky.handle_pointer(e)


func _drag(at: Vector2i) -> void:
	var e := InputEventScreenDrag.new()
	e.position = Vector2(at)
	sky.handle_pointer(e)
