extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const SkyScene := preload("res://game/scenes/sky.tscn")
const STEP: float = 1.0 / 60.0

var run: RunState
var sky: SkyView
var sequencer: EventSequencer
var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)


func before_each() -> void:
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	sky = SkyScene.instantiate()
	add_child_autofree(sky)
	sky.setup(run, sequencer)


func test_stars_appear_when_the_burst_plays_not_when_the_run_resolves() -> void:
	run.launch(Vector2i(90, 160))
	assert_eq(sky.star_count(), 0, "the core resolved instantly; the view waits for the event")
	sequencer.advance(0.0)
	assert_eq(sky.star_count(), run.stars.size())
	for star: Star in run.stars:
		assert_not_null(sky.star_view(star.id), "one view per star id")


func test_burst_stars_fly_from_the_burst_point_and_settle_on_their_positions() -> void:
	run.launch(Vector2i(90, 160))
	var burst := Vector2i(90, 160)
	sequencer.advance(0.0)
	for star: Star in run.stars:
		assert_eq(Vector2i(sky.star_view(star.id).position), burst, "starts at the burst point")
	_play(1.0)
	for star: Star in run.stars:
		var view: StarView = sky.star_view(star.id)
		assert_eq(view.state, StarView.State.IDLE)
		assert_eq(Vector2i(view.position), star.position, "settled where the core put it")


func test_the_sequence_holds_while_stars_settle() -> void:
	run.launch(Vector2i(90, 160))
	var count: int = run.stars.size()
	sequencer.advance(0.0)
	assert_true(sequencer.is_busy(), "input stays locked while stars fly")
	var settle: float = StarView.SETTLE_TIME + SkyView.BURST_STAGGER * (count - 1)
	_play(settle - 0.05)
	assert_true(sequencer.is_busy())
	_play(0.1)
	assert_false(sequencer.is_busy(), "input returns once every star has settled")


func test_every_halo_is_painted_under_every_star() -> void:
	var halo_layer: Node2D = sky.get_node("HaloLayer")
	var star_layer: Node2D = sky.get_node("StarLayer")
	assert_lt(halo_layer.get_index(), star_layer.get_index(), "halos draw first")
	assert_eq(halo_layer.z_index, star_layer.z_index, "tree order decides, not z")
	var ids: Array[int] = _seed_sky([Star.Size.BIG, Star.Size.BIG])
	for id: int in ids:
		for child: Node in sky.star_view(id).get_children():
			assert_false(child is CanvasItem, "a star view draws only its own shape")
	assert_false(sky.star_view(ids[0]).halo_dots().is_empty(), "settled stars have a halo for the layer to paint")


func test_a_changing_halo_redraws_the_halo_layer() -> void:
	var ids: Array[int] = _seed_sky([Star.Size.SMALL])
	var halo_layer: Node2D = sky.get_node("HaloLayer")
	var redraws: Array[int] = [0]
	halo_layer.draw.connect(func() -> void: redraws[0] += 1)
	var view: StarView = sky.star_view(ids[0])
	watch_signals(view)
	view.dissolve()
	assert_signal_emitted(view, "halo_changed")
	await wait_physics_frames(2)
	assert_gt(redraws[0], 0, "the halo layer repainted")


func test_no_star_leaves_the_sky_from_a_burst_at_any_edge() -> void:
	var targets: Array[Vector2i] = [Vector2i(0, 0), Vector2i(179, 319), Vector2i(0, 249), Vector2i(179, 78),
		Vector2i(90, 78), Vector2i(90, 249)]
	run = Fixtures.run({"start_packs": {"blue": 3, "red": 3}})
	sequencer.bind(run)
	sky.setup(run, sequencer)
	for target: Vector2i in targets:
		assert_true(run.launch(target))
		sequencer.advance(0.0)
		for i: int in 90:
			_play(STEP)
			for view: StarView in _views():
				if view.visible:
					assert_true(inner.has_point(Vector2i(view.position)), "%s inside the sky" % view.position)
					assert_eq(view.position, view.position.round(), "whole pixels only")


func test_a_collected_combo_dissolves_its_stars() -> void:
	var ids: Array[int] = _seed_sky([Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL, Star.Size.BIG])
	var linked: Array[int] = ids.slice(0, 3)
	run.link(linked)
	sequencer.advance(0.0)
	for id: int in linked:
		assert_null(sky.star_view(id), "gone from the sky as soon as the collect plays")
	assert_not_null(sky.star_view(ids[3]), "unlinked stars stay")
	assert_true(sequencer.is_busy(), "the dissolve holds the sequence")
	_play(StarView.DISSOLVE_TIME + STEP)
	assert_false(sequencer.is_busy())
	assert_eq(_views().size(), 1, "dissolved views are freed")


func test_a_rejected_link_leaves_every_star() -> void:
	var ids: Array[int] = _seed_sky([Star.Size.SMALL, Star.Size.SMALL, Star.Size.BIG])
	run.link(ids)
	sequencer.advance(0.0)
	assert_eq(sky.star_count(), 3)


func test_a_big_bang_clears_every_view() -> void:
	_seed_sky([Star.Size.SMALL, Star.Size.MEDIUM])
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 160))
	_play(StarView.DISSOLVE_TIME + STEP)
	assert_eq(sky.star_count(), 0)
	assert_eq(_views().size(), 0)


func test_a_new_run_replaces_the_old_views() -> void:
	run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	var next_run: RunState = Fixtures.run({}, 2)
	next_run.add_star(Star.Size.BIG, Vector2i(40, 120))
	sequencer.bind(next_run)
	sky.setup(next_run, sequencer)
	assert_eq(sky.star_count(), 1)
	assert_eq(_views().size(), 1, "old views are removed, even mid-flight")
	var view: StarView = sky.star_view(next_run.stars[0].id)
	assert_eq(view.state, StarView.State.IDLE, "stars already in the sky show settled")
	assert_eq(Vector2i(view.position), Vector2i(40, 120))


func test_setup_twice_with_one_sequencer_hears_each_event_once() -> void:
	sky.setup(run, sequencer)
	run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	assert_eq(_views().size(), run.stars.size(), "no duplicate views from a second connection")


## Adds stars straight to the run and rebuilds the sky, so they start settled.
func _seed_sky(sizes: Array[int]) -> Array[int]:
	var ids: Array[int] = []
	for i: int in sizes.size():
		ids.append(run.add_star(sizes[i] as Star.Size, Vector2i(30 + 30 * i, 150)).id)
	sky.setup(run, sequencer)
	return ids


func _play(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		var delta: float = minf(STEP, left)
		sequencer.advance(delta)
		for view: StarView in _views():
			view.advance(delta)
		left -= delta


func _views() -> Array[StarView]:
	var views: Array[StarView] = []
	for child: Node in sky.get_node("StarLayer").get_children():
		if not child.is_queued_for_deletion():
			views.append(child as StarView)
	return views

