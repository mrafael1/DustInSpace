extends GutTest
## The Heart in the scenes (#71): Orion's figure, the dotted ember ring of his hunting area (marked
## after the first burst, with its line of text), and each later launch's arrow striking it once the
## pack's stars are out, breaking the loose stars inside.

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
	data["hunt"] = {"radius": 24}
	assert_true(main.start_run(Balance.from_dict(data)))
	run = main.run
	sky = main.get_node("Sky")
	hud = main.get_node("HUD")
	sequencer = main.get_node("EventSequencer")
	orion = main.get_node("Sky/OrionLayer")
	for node: Node in [sequencer, orion, main.get_node("CollectParticles"), main.get_node("Sfx"), main.get_node("Sun")]:
		node.set_process(false)


func test_the_heart_shows_orion_and_no_countdown() -> void:
	assert_true(orion.is_figure_shown())
	assert_eq(hud.volley_countdown(), "", "no volley here")
	assert_false(orion.has_area(), "no ring before the first launch")


func test_shipped_hunting_radius_matches_the_ring_and_boundary_on_every_hunting_stage() -> void:
	var balance: Balance = Balance.load_file()
	for map_id: String in ["heart", "claws", "final"]:
		main.star_map = map_id
		assert_true(main.start_run(balance))
		run = main.run
		_play()
		assert_eq(run.hunt.radius, balance.hunt_radius, map_id)
		assert_true(run.launch(Vector2i(100, 190)))
		_play()
		assert_true(orion.has_area(), map_id)
		assert_eq(orion.get("_area_radius"), balance.hunt_radius, "ring uses shipped tuning: " + map_id)
		var centre: Vector2i = run.hunt.centre
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			assert_true(run.hunt.contains(centre + direction * balance.hunt_radius), "edge is hit: " + map_id)
			assert_false(run.hunt.contains(centre + direction * (balance.hunt_radius + 1)), "one pixel beyond is safe: " + map_id)


func test_the_first_burst_marks_a_ring_with_its_line_of_text() -> void:
	run.launch(Vector2i(100, 190))
	sequencer.advance(0.0)
	var waited: float = 0.0
	while not orion.has_area() and waited < 5.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.has_area())
	assert_eq(hud.message(), Hud.HUNT_MESSAGE, "says what the ring means")
	var label: Label = hud.get_node("Message")
	assert_lte(label.get_minimum_size().x, 180.0, "the line fits the screen")
	assert_true(orion.is_aiming(), "the figure flashes as he marks it")
	assert_true(orion.sight_pixels().is_empty(), "no star is marked: no star's sight line")
	assert_false(orion.area_sight_pixels().is_empty(), "the sight line runs to the ring")
	orion.queue_redraw()
	await wait_process_frames(1)
	orion.advance(OrionView.MARK_TIME)
	assert_true(orion.area_sight_pixels().is_empty(), "and cuts once it's marked")
	var ring: Array[Vector2i] = orion.area_pixels()
	assert_false(ring.is_empty())
	for p: Vector2i in ring:
		var d: float = Vector2(p - run.hunt.centre).length()
		assert_between(d, run.hunt.radius - 1.0, run.hunt.radius + 2.0, "on the circle")


func test_the_ring_is_a_clean_symmetric_dotted_circle() -> void:
	for radius: int in [24, 38, 40, 41]:
		var ring: Array[Vector2i] = OrionView.ring_pixels(radius)
		assert_gt(ring.size(), 24, "radius %d: dots all round" % radius)
		var dots: Dictionary = {}
		for p: Vector2i in ring:
			assert_false(dots.has(p), "no pixel twice")
			dots[p] = true
			assert_between(Vector2(p).length(), radius - 0.75, radius + 0.75, "radius %d: %s on the circle" % [radius, p])
		for p: Vector2i in ring:
			for mirror: Vector2i in [Vector2i(-p.x, p.y), Vector2i(p.x, -p.y), Vector2i(p.y, p.x)]:
				assert_true(dots.has(mirror), "radius %d: %s mirrored" % [radius, p])
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					if dx != 0 or dy != 0:
						assert_false(dots.has(p + Vector2i(dx, dy)), "radius %d: dots never touch at %s" % [radius, p])
	assert_ne(OrionView.ring_pixels(40, 1), OrionView.ring_pixels(40), "a pulse steps it out")


func test_the_next_launch_strikes_the_ring_and_marks_a_new_one() -> void:
	run.launch(Vector2i(100, 190))
	_play()
	var centre: Vector2i = run.hunt.centre
	var inside: Star = run.add_star(Star.Size.SMALL, centre)
	sky.setup(run, sequencer)
	orion.mark_area(centre, run.hunt.radius)
	orion.advance(OrionView.MARK_TIME)
	assert_not_null(sky.star_view(inside.id))
	var hit: Array[Star] = []
	run.area_struck.connect(func(_at: Vector2i, stars: Array[Star]) -> void: hit.append_array(stars))
	run.launch(Vector2i(150, 230) if centre.x < 110 else Vector2i(40, 230))
	assert_true(hit.has(inside))
	sequencer.advance(0.0)
	var waited: float = 0.0
	while not orion.is_shooting() and waited < 5.0:
		sequencer.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_true(orion.is_shooting(), "the arrow flies once the pack's stars are out")
	assert_null(sky.star_view(inside.id), "the star inside is no longer the run's")
	assert_true(sequencer.is_busy(), "the new ring waits for the arrow")
	orion.advance(OrionView.DRAW_TIME + 0.01)
	assert_false(orion.arrow_pixels().is_empty())
	_play()
	assert_true(orion.has_area(), "a new ring")


func test_the_stage_opens_with_the_whole_cycle_once() -> void:
	var data: Dictionary = Fixtures.balance_dict()
	data["packs"]["blue"]["big_bang_chance"] = 0.0
	data["packs"]["red"]["big_bang_chance"] = 0.0
	data["start_packs"] = {"blue": 6, "red": 0}
	data["scorpio"] = {"enabled": true, "sun_dust_per_star": 1, "sun_target": 75, "max_link_distance": 56}
	data["hunt"] = {"radius": 40, "intro_stars": 3}
	main.start_run(Balance.from_dict(data))
	run = main.run
	var telescope: Telescope = main.get_node("Telescope")
	telescope.set_process(false)
	assert_true(run.stars.is_empty(), "the intro already played in the run")
	sequencer.advance(0.0)
	assert_eq(_shown_stars(), 3, "the sky shows its stars first")
	assert_false(orion.has_area(), "a beat before the circle")
	var seen: Dictionary = {}
	var waited: float = 0.0
	while sequencer.is_busy() and waited < 10.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		telescope.advance(1.0 / 60.0)
		waited += 1.0 / 60.0
		if orion.has_area():
			seen["ring"] = true
			if hud.message() == Hud.HUNT_MESSAGE:
				seen["text"] = true
		if (telescope.get_node("FlyingPack") as CanvasItem).visible:
			seen["demo launch"] = true
			assert_true(seen.has("ring"), "the circle is marked before the demo launch")
		if _shown_stars() == 6:
			seen["demo burst"] = true
		if orion.is_shooting():
			seen["strike"] = true
			assert_true(seen.has("demo burst"), "the arrow comes after the burst")
	assert_eq(seen.keys().size(), 5, "ring, text, demo launch, demo burst and strike all played: %s" % [seen.keys()])
	assert_false(orion.has_area(), "no circle left")
	assert_eq(run.owned_packs["blue"], 6, "no pack used")
	assert_eq(telescope.shown_pack(), "blue", "the telescope keeps its planet")


func _shown_stars() -> int:
	var shown: int = 0
	for view: Node in sky.get_node("StarLayer").get_children():
		if view is StarView and not view.is_queued_for_deletion():
			shown += 1
	return shown


func _play() -> void:
	var elapsed: float = 0.0
	sequencer.advance(0.0)
	while sequencer.is_busy() and elapsed < 10.0:
		sequencer.advance(1.0 / 60.0)
		orion.advance(1.0 / 60.0)
		elapsed += 1.0 / 60.0
