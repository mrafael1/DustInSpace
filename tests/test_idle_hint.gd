extends GutTest
## The idle hint (#90): after hints.idle_seconds without an interaction, the tutorial's hand drags
## through one valid link, each star shining as it lands. The core picks the link
## (RunState.idle_hint_link); IdleHint times it, HandDemo draws the hand and Sky shines the stars.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const IDLE: float = 4.0

var main: Main
var run: RunState
var sky: SkyView
var sequencer: EventSequencer
var constellation: ConstellationView
var hint: IdleHint


# --- The core: which link -------------------------------------------------------------------

func test_a_hinted_link_is_valid_and_in_reach() -> void:
	var r: RunState = Fixtures.run()
	r.add_star(Star.Size.SMALL, Vector2i(40, 120))
	r.add_star(Star.Size.MEDIUM, Vector2i(60, 120))
	r.add_star(Star.Size.BIG, Vector2i(80, 120))
	r.add_star(Star.Size.BIG, Vector2i(100, 160))
	var link: Array[int] = r.idle_hint_link(Fixtures.rng())
	assert_eq(link.size(), Combos.LINK_LENGTH)
	assert_ne(r.combo_for(link), Combos.INVALID)


func test_no_valid_link_no_hint() -> void:
	var r: RunState = Fixtures.run()
	assert_eq(r.idle_hint_link(Fixtures.rng()), [] as Array[int], "an empty sky")
	r.add_star(Star.Size.SMALL, Vector2i(40, 120))
	r.add_star(Star.Size.SMALL, Vector2i(60, 120))
	r.add_star(Star.Size.MEDIUM, Vector2i(80, 120))
	assert_eq(r.idle_hint_link(Fixtures.rng()), [] as Array[int], "no combo in it")


func test_a_finished_run_hints_nothing() -> void:
	var r: RunState = Fixtures.run()
	for x: int in [40, 60, 80]:
		r.add_star(Star.Size.SMALL, Vector2i(x, 120))
	r.outcome = RunState.Outcome.LOST
	assert_eq(r.idle_hint_link(Fixtures.rng()), [] as Array[int])


func test_the_order_keeps_every_step_in_reach() -> void:
	var r: RunState = _scorpio_run()
	for i: int in r.scorpio.map.count():
		r.scorpio.light(i)
	# 50 px apart in a row: the ends are 100 px apart, out of reach (56), so the middle goes second.
	var a: Star = r.add_star(Star.Size.SMALL, Vector2i(20, 236))
	var mid: Star = r.add_star(Star.Size.SMALL, Vector2i(70, 236))
	var c: Star = r.add_star(Star.Size.SMALL, Vector2i(120, 236))
	var link: Array[int] = r.idle_hint_link(Fixtures.rng())
	assert_eq(link.size(), 3)
	assert_eq(link[1], mid.id, "the middle star in the middle")
	assert_true(link.has(a.id) and link.has(c.id))
	assert_true(r.link_in_reach(link))


func test_ties_are_seeded() -> void:
	var r: RunState = Fixtures.run()
	for x: int in [30, 50, 70, 90, 110, 130]:
		r.add_star(Star.Size.SMALL, Vector2i(x, 120))
	assert_eq(r.idle_hint_link(Fixtures.rng(5)), r.idle_hint_link(Fixtures.rng(5)), "same seed, same link")
	var seen: Dictionary[String, bool] = {}
	for s: int in range(1, 30):
		var link: Array[int] = r.idle_hint_link(Fixtures.rng(s))
		link.sort()
		seen[str(link)] = true
	assert_gt(seen.size(), 1, "the seed picks among equal links")


func test_on_the_scorpio_map_one_unlit_landmark_and_never_two() -> void:
	var r: RunState = _scorpio_run()
	var index: int = 3
	var at: Vector2i = r.scorpio.landmark_positions()[index]
	var size: Star.Size = r.scorpio.map.sizes[index] as Star.Size
	r.add_star(size, at + Vector2i(-14, 10))
	r.add_star(size, at + Vector2i(14, 10))
	for s: int in range(1, 30):
		var link: Array[int] = r.idle_hint_link(Fixtures.rng(s))
		assert_eq(link.size(), 3, "two stars and a landmark make a link")
		assert_eq(link.filter(r.scorpio.is_landmark).size(), 1, "one landmark, never two")
		assert_ne(r.combo_for(link), Combos.INVALID)
	r.scorpio.light(index)
	for id: int in r.idle_hint_link(Fixtures.rng()):
		assert_ne(id, Scorpio.landmark_id(index), "a lit landmark is no star to pick")


# --- Balance --------------------------------------------------------------------------------

func test_the_delay_is_tuned_in_balance() -> void:
	assert_eq(Balance.load_file().hint_idle_seconds, 4.0, "the shipped delay")
	assert_eq(Fixtures.balance().hint_idle_seconds, 0.0, "no hints block: no hint")
	var data: Dictionary = Fixtures.balance_dict()
	data["hints"] = {"idle_seconds": 0}
	assert_false(Balance.from_dict(data).is_valid(), "must be above 0")
	data["hints"] = {"idle_seconds": 2.5}
	assert_eq(Balance.from_dict(data).hint_idle_seconds, 2.5)


# --- The view: timing and shine -------------------------------------------------------------

func test_idle_for_the_delay_and_the_hand_drags_through_the_link() -> void:
	_start_scene()
	var stars: Array[Star] = _small_triple()
	hint.advance(IDLE - 0.1)
	assert_eq(hint.shining_link(), [] as Array[int], "not yet")
	assert_false(hint.hand().is_playing())
	hint.advance(0.1)
	var link: Array[int] = hint.shining_link()
	var points: Array[Vector2i] = sky.link_points(link)
	assert_eq(_sorted(link), _sorted(Fixtures.ids(stars)))
	assert_true(hint.hand().is_playing(), "the tutorial's hand comes out")
	assert_eq(hint.hand().fingertip(), points[0], "on the first star")
	assert_eq(_hinted(), [link[0]] as Array[int], "which shines")
	assert_false(sky.star_view(link[0]).dimmed, "nothing dims")
	hint.advance(TutorialView.DRAG_REST / 2.0)
	assert_eq(hint.hand().fingertip(), points[0], "resting a moment")
	hint.advance(HandDemo.arrival(1) - TutorialView.DRAG_REST / 2.0)
	assert_eq(hint.hand().fingertip(), points[1], "then it slides to the second")
	assert_eq(_hinted(), [link[1]] as Array[int], "which shines as it lands")
	hint.advance(HandDemo.arrival(2) - HandDemo.arrival(1))
	assert_eq(hint.hand().fingertip(), points[2], "then the third")
	assert_eq(_hinted(), [link[2]] as Array[int])
	hint.advance(HandDemo.pass_time(3) - HandDemo.arrival(2))
	assert_eq(hint.hand().fingertip(), points[0], "and again")
	assert_eq(_hinted(), [link[0]] as Array[int])
	hint.advance(IdleHint.play_time() - HandDemo.pass_time(3))
	assert_false(hint.hand().is_playing(), "then the hand goes")
	assert_eq(_hinted(), [] as Array[int])
	assert_eq(hint.shining_link(), [] as Array[int])
	hint.advance(IDLE - 0.1)
	assert_eq(hint.shining_link(), [] as Array[int], "the wait starts over")
	hint.advance(0.1)
	assert_eq(hint.shining_link().size(), 3, "and it shows again")


func test_the_hand_is_the_tutorials_with_its_trail() -> void:
	var points: Array[Vector2i] = [Vector2i(40, 120), Vector2i(80, 120)]
	assert_eq(TutorialView.trail_pixels(points, points[0]), [points[0]] as Array[Vector2i], "a dot on the first star")
	var half: Array[Vector2i] = TutorialView.trail_pixels(points, Vector2i(60, 120))
	assert_eq(half[0], points[0])
	assert_eq(half.size(), 7, "a dot every TRAIL_GAP px up to the fingertip")
	for p: Vector2i in half:
		assert_true(p.x <= 60)
	_start_scene()
	_small_triple()
	hint.advance(IDLE)
	var hand: HandDemo = hint.hand()
	assert_eq(hand.get_parent(), hint)
	assert_true(hand.is_visible_in_tree())


func test_a_tutorial_hand_out_holds_the_idle_hint() -> void:
	_start_scene()
	_small_triple()
	var guide: TutorialView = (main.get_node("HUD") as Hud).tutorial_guide()
	guide.show_step(Tutorial.Step.LAUNCH, Vector2i(90, 160), true)
	hint.is_held = func() -> bool: return guide.has_hand()
	hint.advance(IDLE * 2)
	assert_eq(hint.shining_link(), [] as Array[int], "one hand at a time")
	guide.hide_guide()
	hint.advance(IDLE)
	assert_eq(hint.shining_link().size(), 3)


func test_an_animation_starting_stops_a_hint_playing() -> void:
	_start_scene()
	_small_triple()
	hint.advance(IDLE)
	assert_true(hint.hand().is_playing())
	run.link_rejected.emit([] as Array[int])
	hint.advance(0.1)
	assert_false(hint.hand().is_playing())
	assert_eq(_hinted(), [] as Array[int])


func test_a_touch_before_the_delay_means_no_hint() -> void:
	_start_scene()
	_small_triple()
	hint.advance(IDLE - 0.1)
	_touch(Vector2i(90, 120), true)
	_touch(Vector2i(90, 120), false)
	hint.advance(0.2)
	assert_eq(hint.shining_link(), [] as Array[int])
	assert_almost_eq(hint.idle_time(), 0.2, 0.001, "the wait started over")


func test_a_touch_stops_a_hint_playing() -> void:
	_start_scene()
	_small_triple()
	hint.advance(IDLE)
	assert_false(_hinted().is_empty())
	var drag := InputEventScreenDrag.new()
	hint.observe(drag)
	assert_eq(hint.shining_link(), [] as Array[int])
	assert_eq(_hinted(), [] as Array[int], "the shine stops at once")
	assert_false(hint.hand().is_playing(), "and the hand goes")


func test_a_finger_held_down_is_no_idling() -> void:
	_start_scene()
	_small_triple()
	_touch(Vector2i(90, 300), true)
	hint.advance(IDLE * 2)
	assert_eq(hint.shining_link(), [] as Array[int], "aiming, say")
	_touch(Vector2i(90, 300), false)
	hint.advance(IDLE)
	assert_eq(hint.shining_link().size(), 3)


func test_animations_dont_count_towards_the_delay() -> void:
	_start_scene()
	_small_triple()
	hint.advance(IDLE - 1.5)
	run.link_rejected.emit([] as Array[int])
	assert_true(sequencer.is_busy())
	hint.advance(IDLE * 2)
	assert_eq(hint.shining_link(), [] as Array[int], "the sequencer plays")
	_drain()
	# Lambdas capture locals by value: the flag lives in an array.
	var held: Array[bool] = [true]
	hint.is_held = func() -> bool: return held[0]
	hint.advance(IDLE * 2)
	assert_eq(hint.shining_link(), [] as Array[int], "payouts fly, the Sun ignites")
	held[0] = false
	hint.advance(1.0)
	assert_eq(hint.shining_link(), [] as Array[int], "the wait went on where it was")
	hint.advance(0.5)
	assert_eq(hint.shining_link().size(), 3)


func test_no_valid_link_no_hint_in_the_sky() -> void:
	_start_scene()
	_star(Star.Size.SMALL, Vector2i(150, 236))
	_star(Star.Size.MEDIUM, Vector2i(168, 236))
	hint.advance(IDLE * 3)
	assert_eq(hint.shining_link(), [] as Array[int])
	assert_eq(_hinted(), [] as Array[int])


func test_tracing_a_link_holds_the_wait_and_keeps_the_link_hint() -> void:
	_start_scene()
	var stars: Array[Star] = _small_triple()
	_touch(stars[0].position, true)
	_touch(stars[0].position, false)
	assert_eq(sky.selected_ids(), [stars[0].id] as Array[int], "a tap picks it, no finger stays down")
	hint.advance(IDLE * 2)
	assert_eq(hint.shining_link(), [] as Array[int])
	assert_true(sky.star_view(stars[1].id).hinted, "the link hint is untouched")


func test_a_landmark_in_the_link_shines_on_the_constellation() -> void:
	_start_scene()
	var index: int = 7
	var at: Vector2i = run.scorpio.landmark_positions()[index]
	var size: Star.Size = run.scorpio.map.sizes[index] as Star.Size
	_star(size, at + Vector2i(-16, 10))
	_star(size, at + Vector2i(16, 10))
	hint.advance(IDLE)
	var link: Array[int] = hint.shining_link()
	assert_eq(link.filter(run.scorpio.is_landmark), [Scorpio.landmark_id(index)] as Array[int])
	var seen: bool = false
	for k: int in 3:
		hint.advance(HandDemo.arrival(k) - (HandDemo.arrival(k - 1) if k > 0 else 0.0))
		seen = seen or constellation.hinted() == ([index] as Array[int])
	assert_true(seen, "the landmark shines in its turn")
	hint.advance(IdleHint.play_time())
	assert_eq(constellation.hinted(), [] as Array[int])
	assert_true(constellation.shows_cue(index), "its brackets stay: nothing is traced")


func test_an_aiming_telescope_stops_so_following_the_hand_links() -> void:
	_start_scene()
	hint.set_process_input(true)
	var stars: Array[Star] = _small_triple()
	var telescope: Telescope = main.get_node("Telescope")
	telescope.advance(2.0)
	assert_true(telescope.start_aim(), "a seated planet aims")
	var packs: int = run.total_packs()
	hint.advance(IDLE)
	var link: Array[int] = hint.shining_link()
	assert_eq(link.size(), 3)
	assert_false(telescope.is_aiming(), "the hint hands the sky back to linking")
	_tap_screen(sky.link_points(link)[0])
	assert_eq(sky.selected_ids(), [link[0]] as Array[int], "a tap on the hand's first star picks it")
	assert_eq(run.total_packs(), packs, "and launches nothing")
	assert_false(stars.is_empty())


func test_a_telescope_starting_to_aim_ends_the_hint() -> void:
	_start_scene()
	_small_triple()
	var telescope: Telescope = main.get_node("Telescope")
	telescope.advance(2.0)
	hint.advance(IDLE)
	assert_true(hint.hand().is_playing())
	assert_true(telescope.start_aim())
	assert_false(hint.hand().is_playing(), "the sky is the telescope's again")


func test_a_release_the_speaker_takes_still_lifts_the_finger() -> void:
	_start_scene()
	hint.set_process_input(true)
	_small_triple()
	var speaker: Rect2i = (main.get_node("SoundToggle") as SoundToggle).target
	var on_speaker: Vector2i = speaker.get_center()
	_push_touch(on_speaker + Vector2i(0, 60), true)
	_push_touch(on_speaker, false)
	hint.advance(IDLE)
	assert_eq(hint.shining_link().size(), 3, "the finger is up: the wait ran")


func test_the_hint_watches_input_before_anything_takes_it() -> void:
	_start_scene()
	hint.set_process_input(true)
	_small_triple()
	run.link_rejected.emit([] as Array[int])
	assert_true(sequencer.is_busy())
	_push_touch(Vector2i(90, 300), true)
	_drain()
	hint.advance(IDLE * 2)
	assert_eq(hint.shining_link(), [] as Array[int], "a press the sequencer swallowed still holds the hint")
	_push_touch(Vector2i(90, 300), false)
	hint.advance(IDLE)
	assert_eq(hint.shining_link().size(), 3)


func test_a_run_without_the_hints_block_never_hints() -> void:
	_start_scene({})
	_small_triple()
	hint.advance(60.0)
	assert_eq(hint.shining_link(), [] as Array[int])


func _start_scene(hints: Dictionary = {"idle_seconds": IDLE}) -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	if not hints.is_empty():
		data["hints"] = hints
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	sequencer = main.get_node("EventSequencer")
	constellation = main.get_node("Sky/ConstellationLayer")
	hint = main.get_node("IdleHint")
	hint.seed_choice(3)
	# Only what the test feeds counts: no frames, no payouts in flight.
	hint.set_process(false)
	hint.set_process_input(false)
	hint.is_held = func() -> bool: return false
	_drain()


## Three small stars in the lower right, out of every landmark's reach: the only link.
func _small_triple() -> Array[Star]:
	return [
		_star(Star.Size.SMALL, Vector2i(150, 236)),
		_star(Star.Size.SMALL, Vector2i(168, 236)),
		_star(Star.Size.SMALL, Vector2i(159, 222)),
	] as Array[Star]


func _scorpio_run() -> RunState:
	var data: Dictionary = Fixtures.balance_dict()
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	return RunState.new(Balance.from_dict(data), Fixtures.rng(), Fixtures.SKY)


func _star(size: Star.Size, at: Vector2i) -> Star:
	var star: Star = run.add_star(size, at)
	sky.setup(run, sequencer)
	return star


func _drain() -> void:
	for i: int in 100:
		if not sequencer.is_busy():
			return
		sequencer.advance(1.0)


## The stars (sky stars and landmarks, by link id) shining now.
func _hinted() -> Array[int]:
	var ids: Array[int] = []
	for star: Star in run.stars:
		var view: StarView = sky.star_view(star.id)
		if view != null and view.hinted:
			ids.append(star.id)
	for index: int in constellation.hinted():
		ids.append(Scorpio.landmark_id(index))
	return ids


func _sorted(ids: Array[int]) -> Array[int]:
	var copy: Array[int] = ids.duplicate()
	copy.sort()
	return copy


## A touch fed to both the hint (as Main's _input would) and the sky.
func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	hint.observe(e)
	sky.handle_pointer(e)


## A touch through the real viewport, so every _input gate sees it in tree order. `at` is on the
## game's 180x320 screen; the window may show more around it (ScreenZones.game_offset).
func _push_touch(at: Vector2i, pressed: bool) -> void:
	var offset: Vector2i = ScreenZones.game_offset(get_viewport().get_visible_rect().size)
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at + offset)
	e.pressed = pressed
	# GUT's own panel would take the touch as GUI input before the game's _unhandled_input.
	var gut_layer: CanvasLayer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	var shown: bool = gut_layer != null and gut_layer.visible
	if gut_layer != null:
		gut_layer.visible = false
	get_viewport().push_input(e, true)
	if gut_layer != null:
		gut_layer.visible = shown


func _tap_screen(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		_push_touch(at, pressed)
