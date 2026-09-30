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
		assert_eq(cross.size(), 4 * OrionView.TICK)
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
	orion.advance(OrionView.MARK_TIME)
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


func test_collecting_the_marked_star_moves_the_crosshair_to_a_new_mark() -> void:
	run.launch(Vector2i(60, 150))
	_play()
	run.launch(Vector2i(60, 150))
	_play()
	var target: Star = run.marked_star()
	var a: Star = run.add_star(target.size, target.position + Vector2i(6, 0))
	var b: Star = run.add_star(target.size, target.position + Vector2i(0, 6))
	run.link([target.id, a.id, b.id] as Array[int])
	_play()
	assert_null(sky.star_view(target.id))
	assert_ne(orion.marked(), null, "the link was a move: Orion marked again")
	assert_eq(orion.marked(), sky.star_view(run.marked_star().id), "the crosshair moved to the new mark")


func test_a_new_mark_flashes_the_figure_and_runs_a_sight_line_to_the_star() -> void:
	run.launch(Vector2i(60, 150))
	_play()
	var rest: Dictionary[Vector2i, Color] = orion.figure_pixels()
	run.launch(Vector2i(60, 150))
	_play()
	# Replay the mark from its start.
	var view: StarView = orion.marked()
	orion.mark(view)
	assert_true(orion.is_aiming())
	assert_false(orion.shows_reticle(), "the line reaches the star first")
	var flash: Dictionary[Vector2i, Color] = orion.figure_pixels()
	for p: Vector2i in rest:
		assert_ne(flash[p], rest[p], "%s flashes" % p)
	orion.advance(OrionView.TRACE_TIME * 0.5)
	var half: Array[Vector2i] = orion.sight_pixels()
	orion.advance(OrionView.TRACE_TIME * 0.5)
	var full: Array[Vector2i] = orion.sight_pixels()
	assert_gt(full.size(), half.size(), "the line runs out from the bow")
	assert_eq(full[0], orion.bow_hand())
	var to := Vector2(view.position)
	assert_lt(Vector2(full[-1]).distance_to(to), 16.0, "it reaches the star")
	for p: Vector2i in full:
		assert_false(OrionView.reticle_pixels(view.size, OrionView.LOCK_STEPS).has(p - Vector2i(to)), "short of the reticle")
	assert_true(orion.shows_reticle())
	assert_eq(orion.lock_step(), OrionView.LOCK_STEPS, "then the reticle closes in")
	orion.advance(OrionView.LOCK_STEPS * OrionView.LOCK_STEP_TIME + 0.01)
	assert_false(orion.is_aiming())
	assert_true(orion.sight_pixels().is_empty(), "the line cuts once it's locked")
	assert_eq(orion.lock_step(), 0)
	var held: Dictionary[Vector2i, Color] = orion.figure_pixels()
	var bow_at: Vector2i = run.sky_rect.position + OrionView.FIGURE_AT + OrionView.BOW[2]
	assert_eq(held[bow_at], Palette.N6, "the bow stays drawn while the mark stands")
	assert_eq(rest[bow_at], Palette.N4)
	orion.clear_mark()
	assert_eq(orion.figure_pixels(), rest, "back at rest once the mark goes")


func test_the_locked_reticle_pulses_and_never_blinks_off() -> void:
	run.launch(Vector2i(60, 150))
	_play()
	run.launch(Vector2i(60, 150))
	_play()
	var steps: Array[int] = []
	for i: int in 120:
		orion.advance(1.0 / 60.0)
		assert_true(orion.shows_reticle())
		if not steps.has(orion.lock_step()):
			steps.append(orion.lock_step())
	assert_eq(steps, [0, 1] as Array[int], "it jumps a pixel out and back")


func test_the_figure_is_laid_out_like_orion() -> void:
	var betelgeuse: Vector2i = OrionView.BODY[0]
	var bellatrix: Vector2i = OrionView.BODY[1]
	var belt: Array[Vector2i] = OrionView.BODY.slice(2, 5)
	var saiph: Vector2i = OrionView.BODY[5]
	var rigel: Vector2i = OrionView.BODY[6]
	assert_lt(OrionView.HEAD.y, betelgeuse.y, "the head above the shoulders")
	assert_lt(betelgeuse.y, bellatrix.y, "Betelgeuse a little higher than Bellatrix")
	assert_lt(betelgeuse.x, bellatrix.x)
	for k: int in range(1, 3):
		assert_gt(belt[k].x, belt[k - 1].x, "the belt runs left to right")
		assert_lt(belt[k].y, belt[k - 1].y, "and rises")
	assert_lt(saiph.x, rigel.x, "Saiph left, Rigel right")
	assert_gt(saiph.y, rigel.y, "Saiph a little lower")
	for p: Vector2i in OrionView.BOW:
		assert_gt(p.x, rigel.x, "the bow held out right, towards the sky")


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
