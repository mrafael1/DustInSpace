extends GutTest
## Orion's volley in the scenes (#70): his figure on the Body, the countdown above it, the bow
## charging as the volley nears, and an arrow breaking each star the volley takes.

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
	assert_lt(counter.position.y + VolleyCounter.PIP, figure_top.y, "above his figure")
	assert_eq(counter.position, counter.position.round(), "on the pixel grid")
	main.star_map = "tail"
	main.start_run(Balance.from_dict(_balance_dict()))
	assert_eq(hud.volley_countdown(), "", "no countdown where there's no volley")


func test_the_countdown_and_the_bow_build_to_the_volley() -> void:
	assert_eq(orion.volley_charge(), 0)
	var rest: Dictionary[Vector2i, Color] = orion.figure_pixels()
	assert_true(orion.nocked_pixels().is_empty(), "nothing nocked at rest")
	_link_corner_trio()
	assert_eq(hud.volley_countdown(), "2")
	assert_eq(orion.volley_charge(), 1)
	assert_eq(orion.nocked_pixels().size(), OrionView.NOCK + 1, "one arrow nocked")
	var bow_at: Vector2i = run.sky_rect.position + OrionView.FIGURE_AT + OrionView.BOW[2]
	assert_ne(orion.figure_pixels()[bow_at], rest[bow_at], "the bow drawn")
	_link_corner_trio()
	assert_eq(hud.volley_countdown(), "1")
	assert_eq(orion.volley_charge(), 2)
	assert_gt(orion.nocked_pixels().size(), OrionView.NOCK + 1, "a fan of arrows nocked")
	var seen: Dictionary = {}
	for i: int in 40:
		orion.advance(1.0 / 30.0)
		seen[orion.figure_pixels()[bow_at]] = true
	assert_eq(seen.size(), 2, "the bow blinks on the last link")
	var counter: VolleyCounter = hud.get_node("VolleyCountdown")
	counter.advance(1.0)
	assert_true(counter.colour() in [Palette.S4, Palette.C3], "ember: it's coming")


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


func test_the_volley_sends_an_arrow_to_each_star_it_takes() -> void:
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
	assert_true(orion.is_volleying(), "the volley is loosed")
	assert_true(sequencer.is_busy(), "the countdown waits for the arrows")
	for star: Star in victims:
		assert_null(sky.star_view(star.id), "star %d is no longer the run's" % star.id)
	orion.advance(OrionView.DRAW_TIME + 0.01)
	assert_false(orion.volley_arrows().is_empty(), "arrows in the air")
	var most: int = 0
	for i: int in 60:
		orion.advance(1.0 / 60.0)
		most = maxi(most, orion.volley_arrows().size())
	assert_gt(most, 0)
	assert_false(orion.is_volleying(), "all landed")
	_play()
	assert_eq(hud.volley_countdown(), "3", "the countdown starts again")
	assert_eq(orion.volley_charge(), 0)


func test_a_restart_resets_the_countdown_and_the_bow() -> void:
	_link_corner_trio()
	_link_corner_trio()
	assert_eq(orion.volley_charge(), 2)
	main.restart()
	assert_eq(orion.volley_charge(), 0)
	assert_eq(hud.volley_countdown(), "3")
	assert_false(orion.is_volleying())


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
