extends GutTest
## Collect particles and burst sparks: payouts travel, and bursts throw sparks.

const Fixtures := preload("res://tests/fixtures.gd")

var run: RunState
var sequencer: EventSequencer
var particles: CollectParticles
var sparks: BurstSparks
var dust_landed: Array[int] = []
var light_landed: Array[int] = []


func before_each() -> void:
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	particles = CollectParticles.new()
	add_child_autofree(particles)
	particles.set_process(false)
	particles.setup(run, sequencer)
	sparks = BurstSparks.new()
	add_child_autofree(sparks)
	sparks.set_process(false)
	sparks.setup(run, sequencer)
	dust_landed = []
	light_landed = []
	particles.dust_arrived.connect(func(n: int) -> void: dust_landed.append(n))
	particles.light_arrived.connect(func(n: int) -> void: light_landed.append(n))


func test_split_shares_a_reward_in_whole_numbers() -> void:
	assert_eq(CollectParticles.split(3, 3), [1, 1, 1] as Array[int])
	assert_eq(CollectParticles.split(7, 3), [3, 2, 2] as Array[int])
	var shares: Array[int] = CollectParticles.split(25, 10)
	assert_eq(shares.reduce(func(a: int, b: int) -> int: return a + b, 0), 25)
	assert_eq(shares.size(), 10)


func test_a_combo_sends_its_dust_and_light_as_particles() -> void:
	_link_sequence()
	sequencer.advance(0.0)
	assert_eq(particles.in_flight(CollectParticles.Kind.DUST), 3)
	assert_eq(particles.in_flight(CollectParticles.Kind.LIGHT), 25)
	assert_eq(particles.particle_count(), 3 + CollectParticles.MAX_PARTICLES, "one per dust; 25 light shared by 10")
	assert_false(sequencer.is_busy(), "particles never hold the sequence: input comes back")


func test_nothing_lands_before_the_link_dissolves_and_a_flight_passes() -> void:
	_link_sequence()
	sequencer.advance(0.0)
	particles.advance(CollectParticles.LAUNCH_DELAY + CollectParticles.FLIGHT_MIN - 0.01)
	assert_eq(dust_landed, [] as Array[int])
	assert_eq(light_landed, [] as Array[int])


func test_every_particle_lands_one_by_one_and_the_sums_match() -> void:
	_link_sequence()
	sequencer.advance(0.0)
	var steps: int = 0
	while particles.particle_count() > 0 and steps < 200:
		particles.advance(1.0 / 60.0)
		steps += 1
	assert_eq(particles.particle_count(), 0)
	assert_lte(steps / 60.0, CollectParticles.LONGEST_TRAVEL + 1.0 / 60.0, "within the longest travel")
	assert_eq(dust_landed.reduce(func(a: int, b: int) -> int: return a + b, 0), 3)
	assert_eq(light_landed.reduce(func(a: int, b: int) -> int: return a + b, 0), 25)
	assert_gt(light_landed.size(), 1, "the counter ticks, it doesn't jump")


func test_a_particle_flies_from_its_star_to_its_counter_on_whole_pixels() -> void:
	var p := CollectParticles.Particle.new()
	p.from = Vector2(70, 150)
	p.bend = Vector2(100, 100)
	p.to = Vector2(12, 300)
	assert_eq(p.point_at(0.0), Vector2i(70, 150))
	assert_eq(p.point_at(1.0), Vector2i(12, 300))
	assert_true(p.point_at(0.5) is Vector2i)


func test_targets_are_the_dust_icon_and_the_sun() -> void:
	var main: Main = preload("res://game/scenes/main.tscn").instantiate()
	add_child_autofree(main)
	var fx: CollectParticles = main.get_node("CollectParticles")
	assert_eq(Vector2(fx.dust_target), (main.get_node("HUD/DustIcon") as Node2D).position)
	assert_eq(Vector2(fx.light_target), (main.get_node("Sun") as Node2D).position)


func test_a_new_run_drops_the_particles_in_the_air() -> void:
	_link_sequence()
	sequencer.advance(0.0)
	particles.setup(Fixtures.run(), sequencer)
	particles.advance(CollectParticles.LONGEST_TRAVEL)
	assert_eq(particles.particle_count(), 0)
	assert_eq(dust_landed, [] as Array[int], "nothing from the old run lands")


func test_a_burst_throws_sparks_that_cool_and_vanish() -> void:
	assert_true(run.launch(Vector2i(90, 150)))
	sequencer.advance(0.0)
	assert_true(sparks.is_sparking())
	sparks.advance(BurstSparks.SPARK_TIME)
	assert_false(sparks.is_sparking(), "gone within the burst")


func test_a_big_bang_starts_with_the_same_sparks() -> void:
	run.force_next_big_bang = true
	assert_true(run.launch(Vector2i(90, 150)))
	sequencer.advance(0.0)
	assert_true(sparks.is_sparking(), "the surprise: it opens like any pack")


func test_spark_pixels_ease_out_and_cool_down_the_ramp() -> void:
	var reach: Array[Vector2] = [Vector2(20, 0), Vector2(0, -12)]
	var start: Dictionary[Vector2i, Color] = BurstSparks.spark_pixels(reach, 0.0)
	assert_eq(start, {Vector2i.ZERO: Palette.C0} as Dictionary[Vector2i, Color], "all at the burst point, hottest")
	var late: Dictionary[Vector2i, Color] = BurstSparks.spark_pixels(reach, 0.9)
	assert_true(late.has(Vector2i(20, 0)), "near its reach")
	for colour: Color in late.values():
		assert_eq(colour, Palette.C3, "cooled")
	assert_true(BurstSparks.spark_pixels(reach, 1.0).is_empty())


func _link_sequence() -> void:
	var ids: Array[int] = []
	for i: int in 3:
		ids.append(run.add_star(i as Star.Size, Vector2i(70 + 20 * i, 150)).id)
	assert_eq(run.link(ids), "sequence")
