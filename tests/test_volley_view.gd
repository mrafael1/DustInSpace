extends GutTest
## Orion's volley in the scenes (#70): his figure on the Body, the countdown above it, the bow
## charging as the volley nears. As falling arrows (#98): each countdown starts with his arrows shot
## up to hang overhead; at zero they rain down, one breaking each star the volley takes.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var run: RunState
var sky: SkyView
var hud: Hud
var sequencer: EventSequencer
var orion: OrionView


func before_each() -> void:
	main = MainScene.instantiate()
	main.seed_override = 11
	main.star_map = "body"
	add_child_autofree(main)
	assert_true(main.start_run(Balance.from_dict(_balance_dict())))
	run = main.run
	sky = main.get_node("Sky")
	hud = main.get_node("HUD")
	sequencer = main.get_node("EventSequencer")
	orion = main.get_node("Sky/OrionLayer")
	for node: Node in [sequencer, orion, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)


func test_the_body_shows_orion_and_the_countdown() -> void:
	assert_true(orion.is_figure_shown())
	assert_eq(hud.volley_countdown(), "3", "three links left")
	var counter: VolleyCounter = hud.get_node("VolleyCountdown")
	var figure_top: Vector2i = run.sky_rect.position + OrionView.FIGURE_AT
	assert_lt(counter.position.y + 2 * VolleyCounter.ARM, figure_top.y, "above his figure")
	assert_eq(counter.position, counter.position.round(), "on the pixel grid")
	main.star_map = "tail"
	main.start_run(Balance.from_dict(_balance_dict()))
	assert_eq(hud.volley_countdown(), "", "no countdown where there's no volley")


func test_the_countdown_and_the_bow_build_to_the_volley() -> void:
	assert_eq(orion.volley_charge(), 0)
	_link_corner_trio()
	assert_eq(hud.volley_countdown(), "2")
	assert_eq(orion.volley_charge(), 1)
	var bow_at: Vector2i = run.sky_rect.position + OrionView.FIGURE_AT + OrionView.BOW[2]
	var rest: Dictionary[Vector2i, Color] = orion.figure_pixels()
	_link_corner_trio()
	assert_eq(hud.volley_countdown(), "1")
	assert_eq(orion.volley_charge(), 2)
	var seen: Dictionary = {}
	for i: int in 40:
		orion.advance(1.0 / 30.0)
		seen[orion.figure_pixels()[bow_at]] = true
	assert_eq(seen.size(), 2, "the bow blinks on the last link")
	assert_true(rest.has(bow_at))
	var counter: VolleyCounter = hud.get_node("VolleyCountdown")
	counter.advance(1.0)
	assert_true(counter.colour() in [Palette.S4, Palette.C3], "ember: it's coming")


func test_the_countdown_opens_with_arrows_shot_up_to_hang_overhead() -> void:
	assert_true(orion.is_staged(), "the stage's first countdown stages its arrows")
	assert_true(orion.overhead_arrows().is_empty(), "the bow draws first")
	orion.advance(OrionView.DRAW_TIME + 0.05)
	var flying: Array[Array] = orion.overhead_arrows()
	assert_false(flying.is_empty(), "they leave the bow")
	orion.advance(OrionView.UP_TIME / 2.0)
	flying = orion.overhead_arrows()
	var tip: Vector2i = flying[0][-1]
	var tail: Vector2i = flying[0][0]
	assert_lt(tip.y, tail.y, "flying up, tip first")
	assert_eq(tip.x, tail.x, "straight up")
	orion.advance(OrionView.UP_TIME / 2.0 + 0.01)
	assert_lt((orion.overhead_arrows()[0][-1] as Vector2i).y, run.sky_rect.position.y, "out over the top of the sky")
	orion.advance(OrionView.stage_time())
	var hanging: Array[Array] = orion.overhead_arrows()
	assert_eq(hanging.size(), OrionView.OVERHEAD_X.size())
	var spots: Array[Vector2i] = orion.overhead_spots()
	for i: int in hanging.size():
		assert_eq(hanging[i][-1], spots[i], "each hangs at its spot")
		assert_gt((hanging[i][-1] as Vector2i).y, (hanging[i][0] as Vector2i).y, "pointing down")
		assert_true(run.sky_rect.has_point(spots[i]), "under the top of the sky")
	var figure: Dictionary[Vector2i, Color] = orion.figure_pixels()
	for arrow: Array in hanging:
		for p: Vector2i in arrow:
			assert_false(figure.has(p), "clear of his figure")
	assert_eq(orion.stage_volley(), 0.0, "already up: nothing to shoot")


func test_volley_arrows_are_ember_with_a_head() -> void:
	orion.advance(OrionView.stage_time() + 0.1)
	var hanging: Array = orion.overhead_arrows()[0]
	var tip: Vector2i = hanging[-1]
	assert_eq(OrionView.head_pixels(hanging), [tip, tip + Vector2i(-1, -1), tip + Vector2i(1, -1)] as Array[Vector2i], "a V behind the tip")
	var shot: Array = [Vector2i(0, 0), Vector2i(1, 1)]
	assert_eq(OrionView.head_pixels(shot), [Vector2i(1, 1)] as Array[Vector2i], "a slanted shaft: just its tip")


func test_the_hanging_arrows_shiver_on_the_last_link() -> void:
	orion.advance(OrionView.stage_time() + 0.1)
	var still: Array[Array] = orion.overhead_arrows()
	orion.show_volley_charge(1, 3)
	var shapes: Dictionary = {}
	for i: int in 30:
		orion.advance(1.0 / 30.0)
		shapes[str(orion.overhead_arrows())] = true
	assert_eq(shapes.size(), 2, "a pixel out and back, in step with the bow")
	assert_true(shapes.has(str(still)), "and back to rest")


func test_tracing_the_link_that_fires_readies_the_bow() -> void:
	var trio: Array[int] = []
	for launch: int in 4:
		run.launch(Vector2i(50 + 30 * launch, 150))
		_play()
		trio = _sky_trio()
		if not trio.is_empty():
			break
	assert_false(trio.is_empty(), "a combo in the sky")
	run.volley.counted = 2
	orion.show_volley_charge(1, 3)
	assert_true(run.link_fires_volley(trio))
	_tap(run.find_star(trio[0]).position)
	_tap(run.find_star(trio[1]).position)
	assert_false(orion.is_bow_ready(), "two stars: not a link yet")
	_touch(run.find_star(trio[2]).position, true)
	assert_true(orion.is_bow_ready(), "this link would loose the volley")
	var cancel := InputEventScreenTouch.new()
	cancel.canceled = true
	sky.handle_pointer(cancel)
	assert_false(orion.is_bow_ready())


func test_at_zero_the_arrows_rain_down_one_onto_each_star_it_takes() -> void:
	for launch: int in 3:
		run.launch(Vector2i(50 + 40 * launch, 150))
		_play()
	run.volley.counted = 2
	var victims: Array[Star] = []
	run.volley_fired.connect(func(stars: Array[Star]) -> void: victims.append_array(stars))
	_link_corner_trio(false)
	assert_false(victims.is_empty())
	sequencer.advance(0.0)
	var waited: float = 0.0
	while not orion.is_volleying() and waited < 5.0:
		sequencer.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.is_volleying(), "the volley falls")
	assert_false(orion.is_staged(), "the arrows left their row")
	assert_true(orion.overhead_arrows().is_empty())
	assert_true(sequencer.is_busy(), "the countdown waits for the arrows")
	for star: Star in victims:
		assert_null(sky.star_view(star.id), "star %d is no longer the run's" % star.id)
	orion.advance(0.01)
	var falling: Array[Array] = orion.volley_arrows()
	assert_false(falling.is_empty(), "arrows in the air")
	var first: Array = falling[0]
	assert_gt((first[-1] as Vector2i).y, (first[0] as Vector2i).y, "pointing down")
	assert_eq((first[-1] as Vector2i).x, victims[0].position.x, "straight above its star")
	assert_lte((first[-1] as Vector2i).y, run.sky_rect.position.y + OrionView.OVERHEAD_Y + OrionView.SHAFT, "from the top of the sky")
	for i: int in 60:
		orion.advance(1.0 / 60.0)
	assert_false(orion.is_volleying(), "all landed")
	_play()
	assert_eq(hud.volley_countdown(), "3", "the countdown starts again")
	assert_eq(orion.volley_charge(), 0)
	assert_true(orion.is_staged(), "with new arrows shot up")


func test_the_arrows_land_as_their_stars_burst() -> void:
	var targets: Array[Vector2i] = [Vector2i(60, 200), Vector2i(120, 180)]
	var landings: Array[float] = orion.fire_volley(targets)
	assert_eq(landings.size(), 2)
	assert_almost_eq(landings[0], OrionView.RAIN_TIME, 0.001)
	assert_almost_eq(landings[1], OrionView.RAIN_TIME + OrionView.VOLLEY_STAGGER, 0.001, "staggered")
	orion.advance(landings[0] - 0.01)
	var arrow: Array = orion.volley_arrows()[0]
	assert_lte((arrow[-1] as Vector2i).distance_to(targets[0]), 5.0, "about to land on its star")
	assert_eq((arrow[-1] as Vector2i).x, targets[0].x, "straight down onto it")


func test_a_new_countdown_holds_play_while_its_arrows_fly_up() -> void:
	orion.fire_volley([] as Array[Vector2i])
	orion.advance(orion.volley_time() + 0.01)
	assert_false(orion.is_staged())
	run.volley_counted.emit(3)
	sequencer.advance(0.0)
	assert_true(orion.is_staged())
	assert_true(sequencer.is_busy(), "input waits while they fly up")
	sequencer.advance(OrionView.stage_time() + 0.01)
	assert_false(sequencer.is_busy())


func test_an_empty_sky_still_sees_the_arrows_fall_to_the_horizon() -> void:
	orion.advance(OrionView.stage_time() + 0.1)
	var landings: Array[float] = orion.fire_volley([] as Array[Vector2i])
	assert_true(landings.is_empty(), "no star to break")
	assert_true(orion.is_volleying())
	orion.advance(OrionView.VOLLEY_STAGGER * (OrionView.OVERHEAD_X.size() - 1) + 0.01)
	assert_eq(orion.volley_arrows().size(), OrionView.OVERHEAD_X.size(), "every hanging arrow falls")
	orion.advance(orion.volley_time())
	assert_false(orion.is_volleying())


func test_the_completion_takes_the_arrows_away_without_a_volley() -> void:
	orion.advance(OrionView.stage_time() + 0.1)
	assert_true(orion.is_staged())
	run.constellation_completed.emit()
	sequencer.advance(0.0)
	assert_false(orion.is_staged(), "no volley follows")
	assert_true(orion.overhead_arrows().is_empty())
	assert_false(orion.is_volleying())


func test_a_restart_resets_the_countdown_and_the_bow() -> void:
	_link_corner_trio()
	_link_corner_trio()
	assert_eq(orion.volley_charge(), 2)
	main.restart()
	assert_eq(orion.volley_charge(), 0)
	assert_eq(hud.volley_countdown(), "3")
	assert_false(orion.is_volleying())
	assert_true(orion.is_staged(), "the new run's first countdown is staged again")


func test_the_stage_opens_with_stars_and_a_volley_that_takes_them() -> void:
	var data: Dictionary = _balance_dict()
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	main.start_run(Balance.from_dict(data))
	run = main.run
	sequencer.advance(0.0)
	assert_true(run.stars.is_empty(), "the intro volley already took them in the run")
	var shown: int = 0
	for view: Node in sky.get_node("StarLayer").get_children():
		if view is StarView:
			shown += 1
	assert_eq(shown, 6, "but the sky shows them first")
	assert_false(orion.is_volleying(), "a beat before the arrows")
	var waited: float = 0.0
	while not orion.is_volleying() and waited < 3.0:
		sequencer.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.is_volleying(), "then the volley")
	assert_between(waited, SkyView.INTRO_HOLD - 0.05, SkyView.INTRO_HOLD + 0.2)
	_play()
	assert_eq(hud.volley_countdown(), "2", "and the countdown for the real ones")


func _balance_dict() -> Dictionary:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["volley"] = {"interval": 3, "fraction": 0.5}
	return data


## A combo of loose sky stars (with views), or none.
func _sky_trio() -> Array[int]:
	var ids: Array[int] = []
	for star: Star in run.stars:
		ids.append(star.id)
	for a: int in ids.size():
		for b: int in range(a + 1, ids.size()):
			for c: int in range(b + 1, ids.size()):
				var trio: Array[int] = [ids[a], ids[b], ids[c]]
				if run.combo_for(trio) != Combos.INVALID:
					return trio
	return []


func _tap(at: Vector2i) -> void:
	_touch(at, true)
	_touch(at, false)


func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	sky.handle_pointer(e)


func _corner_trio() -> Array[int]:
	var ids: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(10, 0), Vector2i(5, 8)]:
		ids.append(run.add_star(Star.Size.SMALL, Vector2i(24, 100) + offset).id)
	return ids


func _link_corner_trio(play: bool = true) -> void:
	assert_ne(run.link(_corner_trio()), Combos.INVALID)
	if play:
		_play()


func _play() -> void:
	var elapsed: float = 0.0
	sequencer.advance(0.0)
	while sequencer.is_busy() and elapsed < 10.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
