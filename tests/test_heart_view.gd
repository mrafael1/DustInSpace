extends GutTest
## The Heart in the scenes (#71): Orion's figure with both threats. The crosshair marks the single
## target and the countdown with the nocked arrows announces the volley; while tracing, only a link
## that would shoot the mark holds the sight line on it, so a rescue on a volley link never aims at
## the star it saves.

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
	main.seed_override = 5
	main.star_map = "heart"
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["heart_volley"] = {"interval": 3, "fraction": 0.5}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	hud = main.get_node("HUD")
	sequencer = main.get_node("EventSequencer")
	orion = main.get_node("Sky/OrionLayer")
	for node: Node in [sequencer, orion, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)


func test_the_heart_shows_orion_the_countdown_and_the_first_mark() -> void:
	assert_true(orion.is_figure_shown())
	assert_eq(hud.volley_countdown(), "3", "the volley's countdown")
	assert_true(sky.get_node("StarLayer").get_children().is_empty(), "no volley intro")
	run.launch(Vector2i(100, 190))
	_play()
	assert_not_null(run.marked_star())
	assert_eq(orion.marked(), sky.star_view(run.marked_star().id), "the crosshair on the mark")


func test_a_rescue_on_a_volley_link_readies_the_bow_without_aiming_at_the_mark() -> void:
	var rescue: Array[int] = _setup_sky()
	_trace(rescue)
	assert_true(run.link_fires_volley(rescue))
	assert_false(run.link_shoots(rescue))
	assert_true(orion.is_bow_ready(), "the volley is coming")
	assert_false(orion.is_shot_ready(), "but the mark is saved")
	assert_true(orion.sight_pixels().is_empty(), "no sight line on the star this link saves")
	assert_false(orion.nocked_pixels().is_empty(), "the nocked arrows say volley")


func test_a_link_that_leaves_the_mark_on_a_volley_link_aims_at_it_too() -> void:
	_setup_sky()
	var trio: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(12, 0), Vector2i(6, 10)]:
		trio.append(run.add_star(Star.Size.SMALL, Vector2i(30, 120) + offset).id)
	_respawn()
	_trace(trio)
	assert_true(run.link_shoots(trio))
	assert_true(run.link_fires_volley(trio))
	assert_true(orion.is_shot_ready(), "this link would shoot the mark")
	assert_false(orion.sight_pixels().is_empty(), "the sight line holds on it")
	sky.handle_pointer(_cancel_event())
	assert_false(orion.is_bow_ready(), "cancelled: the bow stands down")


func test_both_attacks_play_in_turn_then_a_new_mark() -> void:
	_setup_sky()
	var target: Star = run.marked_star()
	var trio: Array[int] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(12, 0), Vector2i(6, 10)]:
		trio.append(run.add_star(Star.Size.SMALL, Vector2i(30, 120) + offset).id)
	_respawn()
	assert_ne(run.link(trio), Combos.INVALID)
	sequencer.advance(0.0)
	var waited: float = 0.0
	while not orion.is_shooting() and waited < 5.0:
		sequencer.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.is_shooting(), "the single arrow first")
	assert_false(orion.is_volleying(), "the volley waits for it")
	assert_null(sky.star_view(target.id))
	while not orion.is_volleying() and waited < 10.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.is_volleying(), "then the volley")
	_play()
	assert_eq(hud.volley_countdown(), "3", "the countdown starts again")
	if run.marked_star() != null:
		assert_eq(orion.marked(), sky.star_view(run.marked_star().id), "and a new mark on a survivor")


## A launch marks a star; then two of its size join it (a rescue link), the countdown sits on its
## last link, and every star gets a view. Returns the rescue link: the mark, then the two.
func _setup_sky() -> Array[int]:
	run.launch(Vector2i(100, 190))
	_play()
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(-14, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, -14))
	run.volley.counted = run.volley.interval - 1
	_respawn()
	return [target.id, a.id, b.id]


## Views for every star in the run (added ones too), the mark and the charge shown again.
func _respawn() -> void:
	sky.setup(run, sequencer)
	orion.mark(sky.star_view(run.orion.target))
	orion.advance(OrionView.MARK_TIME)
	orion.show_volley_charge(run.volley.links_left(), run.volley.interval)


## Taps the first two stars and presses on the third, so the whole link is traced but not made.
func _trace(ids: Array[int]) -> void:
	_tap(run.find_star(ids[0]).position)
	_tap(run.find_star(ids[1]).position)
	_touch(run.find_star(ids[2]).position, true)
	assert_eq(sky.selected_ids(), ids)


func _tap(at: Vector2i) -> void:
	_touch(at, true)
	_touch(at, false)


func _touch(at: Vector2i, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(at)
	e.pressed = pressed
	sky.handle_pointer(e)


func _cancel_event() -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.canceled = true
	return e


func _play() -> void:
	var elapsed: float = 0.0
	sequencer.advance(0.0)
	while sequencer.is_busy() and elapsed < 10.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
