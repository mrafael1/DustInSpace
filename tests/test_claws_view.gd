extends GutTest
## The Claws in the scenes (#74): Orion's figure with two of his cues at once. After the first burst
## the dotted ring of his hunting area and the crosshair on the star he marks; no volley countdown
## (#97). No intro plays.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var run: RunState
var hud: Hud
var sequencer: EventSequencer
var orion: OrionView


func before_each() -> void:
	main = MainScene.instantiate()
	main.seed_override = 5
	main.star_map = "claws"
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 1}
	data["volley"] = {"interval": 2, "fraction": 1.0, "intro_stars": 6}
	data["hunt"] = {"radius": 40, "intro_stars": 3}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	hud = main.get_node("HUD")
	sequencer = main.get_node("EventSequencer")
	orion = main.get_node("Sky/OrionLayer")
	for node: Node in [sequencer, orion, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)


func test_the_claws_open_quietly_with_no_countdown() -> void:
	assert_true(orion.is_figure_shown())
	assert_true(run.stars.is_empty(), "no intro stars")
	assert_eq(hud.volley_countdown(), "", "no volley, no countdown (#97)")
	assert_false(orion.has_area())
	assert_null(orion.marked())


func test_the_first_burst_shows_the_ring_and_the_crosshair_together() -> void:
	Fixtures.launch(run, Vector2i(100, 190))
	_settle()
	assert_true(orion.has_area(), "the ring")
	assert_not_null(orion.marked(), "the crosshair's star")
	assert_eq(hud.volley_countdown(), "", "still no countdown")
	assert_true(orion.shows_reticle())
	var ring: Array[Vector2i] = orion.area_pixels()
	assert_false(ring.is_empty())
	var figure: Dictionary[Vector2i, Color] = orion.figure_pixels()
	for p: Vector2i in ring:
		assert_false(figure.has(p), "the ring keeps off his figure")


func test_the_strike_takes_a_marked_star_in_the_ring_and_the_crosshair_moves_on() -> void:
	Fixtures.launch(run, Vector2i(100, 190))
	_settle()
	var target: Star = run.marked_star()
	run.hunt.centre = target.position
	Fixtures.launch(run, Vector2i(140, 210) if target.position.x < 90 else Vector2i(50, 210))
	_settle()
	assert_false(run.stars.has(target))
	if run.marked_star() != null:
		assert_eq(orion.marked().star_id, run.marked_star().id, "the crosshair follows the new mark")
	else:
		assert_null(orion.marked(), "no crosshair over an empty spot")


## Plays the queued events and Orion's animations out.
func _settle() -> void:
	sequencer.advance(0.0)
	for frame: int in 600:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		if not sequencer.is_busy():
			break
	orion.advance(OrionView.MARK_TIME)


func test_links_and_restart_never_show_a_volley_countdown_or_effect() -> void:
	Fixtures.launch(run, Vector2i(100, 190))
	_settle()
	for turn: int in 3:
		var ids: Array[int] = []
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(10, 0), Vector2i(5, 8)]:
			ids.append(run.add_star(Star.Size.SMALL, Vector2i(24, 100) + offset).id)
		(main.get_node("Sky") as SkyView).setup(run, sequencer)
		assert_ne(run.link(ids), Combos.INVALID)
		sequencer.advance(0.0)
		for frame: int in 600:
			assert_false(orion.is_volleying())
			assert_eq(hud.volley_countdown(), "")
			sequencer.advance(1.0 / 60.0)
			orion.advance(1.0 / 60.0)
			if not sequencer.is_busy():
				break
	assert_true(main.restart())
	assert_eq(hud.volley_countdown(), "")
	assert_false(orion.is_volleying())
