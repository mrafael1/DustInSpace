extends GutTest
## Pisces's final, PISCES, THE TWO FISH: the whole figure in two acts on one water line, up and down.
## Act one, the waves wipe the left then the right; the great wave floods the whole sky and wakes the
## fish; act two, the waves go on and the fish leaps every second throw. Winning ends in a great wave
## that washes the loose stars left into dust.

const MainScene := preload("res://game/scenes/main.tscn")
const Fixtures := preload("res://tests/fixtures.gd")
const SKY := Rect2i(0, 78, 180, 172)


func _run(seed_value: int = 7) -> RunState:
	var run := RunState.new(Balance.load_file(), Fixtures.rng(seed_value), SKY, StarMap.pisces_final())
	run.dust = 100
	run.owned_packs["blue"] = 20
	run.owned_packs["red"] = 0
	run.loaded_pack = "blue"
	return run


func _main() -> Main:
	var main: Main = MainScene.instantiate()
	main.star_map = "pisces_final"
	main.in_chapter = true
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_pisces_final_settings.cfg"
	add_child_autofree(main)
	return main


## Plays in real frames until nothing is playing (the scene's tweens run too).
func _play_out(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var start: int = Time.get_ticks_msec()
	await get_tree().process_frame
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 15000:
		await get_tree().process_frame


## One loose star in each corner round the sky's middle: [top left, top right, bottom right,
## bottom left].
func _corners(run: RunState) -> Array[Star]:
	run.stars.clear()
	var middle: Vector2i = run.wave.middle
	var corners: Array[Star] = []
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		corners.append(run.add_star(Star.Size.SMALL, middle + Vector2i(corner.x * 70, corner.y * 70)))
	return corners


func test_the_final_is_the_whole_figure_on_one_line_with_the_great_wave() -> void:
	var chapter := Chapter.new(ChapterDef.pisces())
	assert_eq(chapter.map_id(Chapter.FINAL), "pisces_final")
	var map: StarMap = StarMap.pisces_final()
	assert_eq(map.landmarks, StarMap.pisces().landmarks, "the whole Pisces")
	assert_eq(map.starting_lit, [0], "gamma lit: thirteen to light")
	assert_eq(map.seam, StarMap.Seam.VERTICAL, "act one: one line, between the fish")
	assert_true(map.splash)
	assert_true(map.wave)
	assert_true(map.wave_great)
	assert_true(map.wave_finale)
	assert_false(map.intros, "the stages showed every rule")
	assert_eq(map.arrival_epithet, "THE TWO FISH")
	var balance: Balance = Balance.load_file()
	assert_eq(balance.wave_great_launch, 4, "the great wave on the fourth throw")
	assert_gt(balance.wave_finale_dust_per_star, 0)
	var run: RunState = _run()
	assert_eq(run.seam, StarMap.Seam.VERTICAL)
	assert_true(run.wave.vertical)
	assert_eq(RunState.new(balance, Fixtures.rng(1), SKY, StarMap.pisces_north_fish()).wave.great_launch, 0, "only the final has it")


func test_act_one_left_and_right_then_the_great_wave_wakes_the_fish() -> void:
	var run: RunState = _run()
	var struck: Array = []
	var woke: Array = []
	run.wave_struck.connect(func(way: Vector2i, lost: Array[Star], next: Vector2i, great: bool) -> void:
		var ids: Array[int] = []
		for star: Star in lost:
			ids.append(star.id)
		ids.sort()
		struck.append([way, ids, next, great]))
	run.fish_arrived.connect(func(at: Vector2i) -> void: woke.append(at))
	var aim: Vector2i = run.wave.middle + Vector2i(30, 50)
	assert_true(run.launch(aim), "the first throw: no wave")
	assert_true(struck.is_empty())
	# Act one: the left, then the right.
	for i: int in 2:
		var corners: Array[Star] = _corners(run)
		var half: Array[int] = []
		half.assign([corners[0].id, corners[3].id] if i == 0 else [corners[1].id, corners[2].id])
		half.sort()
		assert_false(run.wave.great_next())
		run.load_pack("blue")
		assert_true(run.launch(aim))
		assert_eq(struck[i][0], Vector2i.LEFT if i == 0 else Vector2i.RIGHT)
		assert_eq(struck[i][1], half, "its half's two")
		assert_false(struck[i][3])
	assert_null(run.fish, "no fish in act one")
	# The fourth throw: the great wave takes every loose star and wakes the fish.
	var all: Array[Star] = _corners(run)
	assert_true(run.wave.great_next())
	assert_eq(run.wave_risk().size(), 4, "every loose star marked")
	run.load_pack("blue")
	assert_true(run.launch(aim))
	var ids: Array[int] = []
	for star: Star in all:
		ids.append(star.id)
	ids.sort()
	assert_eq(struck[2][1], ids, "the great wave floods the whole sky")
	assert_true(struck[2][3])
	assert_eq(struck[2][2], Vector2i.LEFT, "act two's first wave: the left again")
	assert_eq(run.seam, StarMap.Seam.VERTICAL, "still one line")
	assert_not_null(run.fish)
	assert_eq(woke, [run.fish.at])
	assert_eq(run.fish.at.x, run.wave.middle.x, "on the water line")
	assert_lte(absi(run.fish.at.y - run.wave.middle.y), RunState.FISH_SPAN, "near its middle")
	for landmark: Vector2i in run.scorpio.landmark_positions():
		assert_gt(Vector2(run.fish.at).distance_to(Vector2(landmark)), 12.0, "clear of the figure's stars")
	assert_true(run.fish.vertical)
	assert_eq(run.fish.launches, 0, "it counts from the next throw")


func test_in_act_two_the_fish_leaps_every_second_throw_before_the_wave() -> void:
	var run: RunState = _run()
	run.wave.launches = 3
	var aim: Vector2i = run.wave.middle + Vector2i(30, 50)
	assert_true(run.launch(aim), "the great wave")
	assert_not_null(run.fish)
	var middle: Vector2i = run.fish.at
	var order: Array[String] = []
	var jumped: Array = []
	run.stars_bitten.connect(func(_at: Vector2i, _moves: Array[StarCurrent.Move]) -> void: order.append("fish"))
	run.wave_struck.connect(func(_way: Vector2i, _lost: Array[Star], _next: Vector2i, _great: bool) -> void: order.append("wave"))
	run.fish_jumped.connect(func(_from: Vector2i, to: Vector2i, caught: Array[int]) -> void: jumped.append([to, caught]))
	run.stars.clear()
	assert_false(run.fish.jumps_next(), "not the first throw after it wakes")
	run.load_pack("blue")
	assert_true(run.launch(aim))
	assert_eq(order, ["fish", "wave"], "the fish's turn (nothing eaten), then the wave")
	assert_true(jumped.is_empty())
	run.stars.clear()
	assert_true(run.fish.jumps_next(), "the second throw: it leaps")
	# A star right of the line, the wave going left: only the fish can take it.
	var near: Star = run.add_star(Star.Size.SMALL, middle + Vector2i(24, -20))
	# Thrown far from it, so the splash leaves it where it is.
	var far: Vector2i = run.wave.middle + Vector2i(40, -70)
	assert_eq(run.fish_leap(far), near.position)
	assert_eq(run.launch_bites(far), [near.id] as Array[int])
	run.load_pack("blue")
	assert_true(run.launch(far))
	assert_eq(jumped, [[near.position, [near.id] as Array[int]]], "it leaps and eats it")
	assert_null(run.find_star(near.id))


func test_winning_ends_in_a_great_wave_that_washes_the_loose_stars_into_dust() -> void:
	var run: RunState = _run()
	for i: int in run.scorpio.map.count():
		if i != 13:
			run.scorpio.light(i)
	var events: Array[String] = []
	var paid: Array[int] = []
	run.wave_struck.connect(func(_way: Vector2i, lost: Array[Star], _next: Vector2i, great: bool) -> void:
		events.append("great wave" if great and lost.is_empty() else "wave"))
	run.sky_cleared.connect(func(stars: Array[Star], dust: int) -> void:
		events.append("cleared")
		paid.append(stars.size())
		paid.append(dust))
	run.constellation_completed.connect(func() -> void: events.append("completed"))
	run.run_won.connect(func() -> void: events.append("won"))
	var leftover: Star = run.add_star(Star.Size.BIG, Vector2i(150, 220))
	var other: Star = run.add_star(Star.Size.SMALL, Vector2i(130, 100))
	var tau: Star = run.scorpio.landmark_star(13)
	var a: Star = run.add_star(tau.size, tau.position + Vector2i(-20, 0))
	var b: Star = run.add_star(tau.size, tau.position + Vector2i(20, 0))
	assert_ne(run.link([a.id, tau.id, b.id] as Array[int]), Combos.INVALID)
	assert_eq(events, ["great wave", "cleared", "completed", "won"], "the great wave washes the sky, then the figure completes")
	assert_eq(paid[0], 2, "the stars left")
	assert_eq(paid[1], 2 * run.balance.wave_finale_dust_per_star, "each paid as a jackpot")
	assert_null(run.find_star(leftover.id))
	assert_null(run.find_star(other.id))


func test_its_lines_fit() -> void:
	for text: String in [Hud.GREAT_WAVE_MESSAGE, Hud.FISH_MESSAGE % 2, Hud.JUMP_MESSAGE, Hud.FISH_LOSS_MESSAGE, Hud.WAVE_NEXT_MESSAGE % "RIGHT", Hud.WAVE_NEXT_MESSAGE % "LEFT"]:
		for line: String in text.split("\n"):
			assert_lte(line.length(), 24, line)


func test_the_great_wave_is_cued_on_both_sides_and_said() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var hud: Hud = main.get_node("HUD")
	var run: RunState = main.run
	run.wave.launches = 3
	view.settled = true
	assert_true(view.cue_great())
	var left: int = 0
	var right: int = 0
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in pixels:
		if pixels[point] == Palette.S4:
			if point.x < run.wave.middle.x:
				left += 1
			else:
				right += 1
	assert_gt(left, 0, "chevrons left of the line")
	assert_gt(right, 0, "and right of it")
	hud.show_message("", 0.0, true)
	hud.call("_tell_wave")
	assert_eq(hud.message(), Hud.GREAT_WAVE_MESSAGE)


func test_the_great_wave_rushes_both_ways_and_the_fish_wakes_leaping() -> void:
	var main: Main = _main()
	await _play_out(main)
	var view: SeamView = main.get_node("Sky/SeamLayer")
	var run: RunState = main.run
	var middle: Vector2i = run.wave.middle
	view.sweep(Vector2i.RIGHT, Vector2i.LEFT, [] as Array[Vector2i], true)
	view.advance(SeamView.WINDUP_TIME + SeamView.SWEEP_TIME / 2.0)
	var left: int = 0
	var right: int = 0
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in pixels:
		if pixels[point] == Palette.M6 and absi(point.x - middle.x) > 8:
			if point.x < middle.x:
				left += 1
			else:
				right += 1
	assert_gt(left, 20, "a wall rushing left")
	assert_gt(right, 20, "and one rushing right")
	assert_eq(view.way_for(Vector2i.RIGHT, middle + Vector2i(-30, 5)), Vector2i.LEFT, "a star left of the line goes out left")
	assert_eq(view.way_for(Vector2i.RIGHT, middle + Vector2i(30, 5)), Vector2i.RIGHT)
	view.advance(SeamView.SWEEP_TIME / 2.0 + SeamView.CRASH_TIME)
	assert_false(view.is_fish_awake(), "no fish before the great wave")
	run.wave.launches = 3
	run.load_pack("blue")
	assert_true(run.launch(middle + Vector2i(30, 50)))
	await _play_out(main)
	assert_true(view.is_fish_awake(), "it woke with the great wave")
	assert_eq(view.fish_shown(), run.fish.at, "back on the line once its leap has played")
	assert_eq(view.pixels().get(run.fish.at), Palette.M5, "its back on the line")
	run.fish.launches = 1
	view.queue_redraw()
	assert_eq(view.pixels().get(run.fish.at), Palette.S4, "it glows red before it leaps")


func test_it_arrives_with_its_title_card_and_plays_its_acts_through_the_scene() -> void:
	var main: Main = _main()
	var banner: BossBanner = main.get_node("HUD").get("_banner")
	await get_tree().process_frame
	assert_true(banner.is_playing(), "the title card")
	await _play_out(main)
	var run: RunState = main.run
	var sky: SkyView = main.get_node("Sky")
	var view: SeamView = main.get_node("Sky/SeamLayer")
	assert_eq(sky.star_count(), 0, "no intro stars")
	run.dust = 100
	for i: int in 5:
		if run.is_over():
			break
		if run.total_packs() == 0:
			run.buy("blue")
		for kind: String in ["blue", "red"]:
			if run.load_pack(kind):
				break
		assert_true(run.launch(run.wave.middle + Vector2i(40 if i % 2 == 0 else -40, 40)))
		await _play_out(main)
		assert_eq(sky.star_count(), run.stars.size(), "the views follow the run after launch %d" % (i + 1))
	if run.wave.launches >= 4:
		assert_true(view.is_fish_awake(), "the fish shows once the great wave has played")
