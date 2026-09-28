extends GutTest
## Orion in the scenes (#64): his figure on the Tail only, the crosshair on the star he marks, and
## his arrow breaking it before the new pack bursts.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")

var main: Main
var run: RunState
var sky: SkyView
var sequencer: EventSequencer
var orion: OrionView


func before_each() -> void:
	main = MainScene.instantiate()
	main.seed_override = 7
	main.star_map = "tail"
	add_child_autofree(main)
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["orion"] = {"first_mark_launch": 2}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	sequencer = main.get_node("EventSequencer")
	orion = main.get_node("Sky/OrionLayer")
	for node: Node in [sequencer, orion, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)


func test_the_figure_shows_only_where_orion_hunts() -> void:
	assert_true(orion.is_figure_shown())
	assert_false(orion.figure_pixels().is_empty())
	for p: Vector2i in orion.figure_pixels():
		assert_true(run.sky_rect.has_point(p), "%s in the sky" % p)
		for i: int in run.scorpio.map.count():
			assert_gt((run.scorpio.landmark_position(i) - p).length(), 40.0, "clear of the tail")
	main.star_map = "stinger"
	main.start_run(Fixtures.balance({"scorpio": {"enabled": true, "sun_dust_per_star": 1}, "orion": {"first_mark_launch": 2}}))
	assert_false(orion.is_figure_shown())
	assert_true(orion.figure_pixels().is_empty())


func test_the_crosshair_is_unlike_the_landmark_cue() -> void:
	for size: int in 3:
		var cross: Array[Vector2i] = OrionView.reticle_pixels(size)
		assert_eq(cross.size(), 8)
		for p: Vector2i in cross:
			assert_true(p.x == 0 or p.y == 0, "on the axes, where the corner hints never are")
			assert_false(ConstellationView.cue_pixels(size).has(p))


func test_the_second_burst_marks_a_star_and_the_third_launch_shoots_it() -> void:
	run.launch(Vector2i(60, 150))
	_play()
	assert_null(orion.marked(), "launch 1: no mark")
	run.launch(Vector2i(60, 150))
	_play()
	var target: Star = run.marked_star()
	assert_eq(orion.marked(), sky.star_view(target.id), "the crosshair is on the marked star")
	orion.advance(OrionView.LOCK_STEPS * OrionView.LOCK_STEP_TIME)
	assert_true(orion.shows_reticle())
	run.launch(Vector2i(60, 150))
	# Launch, then the shot: the pack hovers while the arrow flies.
	sequencer.advance(0.0)
	var waited: float = 0.0
	while not orion.is_shooting() and waited < 5.0:
		sequencer.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.is_shooting(), "the arrow is out")
	assert_gt(waited, 0.3, "after the pack's flight")
	assert_null(sky.star_view(target.id), "the shot star is no longer the run's")
	assert_eq(orion.marked(), null)
	assert_true(sequencer.is_busy(), "the burst waits for the arrow")
	orion.advance(OrionView.DRAW_TIME + 0.01)
	assert_false(orion.arrow_pixels().is_empty())
	_play()
	assert_eq(orion.marked(), sky.star_view(run.marked_star().id), "the next mark")


func test_collecting_the_marked_star_takes_the_crosshair() -> void:
	run.launch(Vector2i(60, 150))
	_play()
	run.launch(Vector2i(60, 150))
	_play()
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	run.link([target.id, a.id, b.id] as Array[int])
	_play()
	assert_null(orion.marked())


func test_a_restart_clears_the_mark_and_the_arrow() -> void:
	run.launch(Vector2i(60, 150))
	_play()
	run.launch(Vector2i(60, 150))
	_play()
	assert_not_null(orion.marked())
	main.restart()
	assert_null(orion.marked())
	assert_false(orion.is_shooting())
	assert_null(main.run.marked_star())


func _play() -> void:
	var elapsed: float = 0.0
	sequencer.advance(0.0)
	while sequencer.is_busy() and elapsed < 10.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
