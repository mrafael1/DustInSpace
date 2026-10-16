extends GutTest
## Aries's ram, as the scene shows it (the RAM trial): its head on the lane row, its pips, the charge's
## outcome cued on the stars only while nothing plays and the next launch charges, a lost star's view
## gone once the charge has played, its rule line, and nothing but palette colours.

const MainScene := preload("res://game/scenes/main.tscn")
const PALETTE_PATH := "res://assets/palettes/stellar_sun.gpl"


func _main(enabled: bool = true) -> Main:
	var main: Main = MainScene.instantiate()
	main.current_trial = true
	main.current_layout = "ram"
	main.current_enabled = enabled
	main.seed_override = 3
	(main.get_node("Sfx") as Sfx).settings_path = "user://test_charge_view_settings.cfg"
	add_child_autofree(main)
	return main


func _settle(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 400:
		sequencer.advance(0.05)
		if not sequencer.is_busy():
			return


func _view(main: Main) -> ChargeView:
	return main.get_node("Sky/ChargeLayer")


## Clears the sky's loose stars (views too) and stands `spec` ([size, position] each) in it.
func _stand(main: Main, spec: Array) -> Array[Star]:
	var run: RunState = main.run
	run.stars.clear()
	var born: Array[Star] = []
	for entry: Array in spec:
		born.append(run.add_star(entry[0] as Star.Size, entry[1] as Vector2i))
	(main.get_node("Sky") as SkyView).setup(run, main.get_node("EventSequencer"))
	return born


func _count(pixels: Dictionary[Vector2i, Color], colours: Array[Color]) -> int:
	var n: int = 0
	for point: Vector2i in pixels:
		if pixels[point] in colours:
			n += 1
	return n


func test_the_head_sits_on_the_lane_row_at_the_left_edge() -> void:
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	view.settled = true
	assert_true(view.has_ram())
	assert_eq(view.row(), main.run.ram.row)
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	var head: Dictionary[Vector2i, Color] = ChargeView.head_pixels(main.run.ram.row, main.run.sky_rect)
	for point: Vector2i in head:
		assert_eq(pixels.get(point), head[point])
	var origin: Vector2i = ChargeView.head_origin(main.run.ram.row, main.run.sky_rect)
	assert_eq(origin.x, main.run.sky_rect.position.x + 1, "a pixel in from the sky's left edge")
	assert_between(main.run.ram.row, origin.y, origin.y + ChargeView.head_size().y - 1, "the row runs through the head")
	assert_eq(view.lit_pips(), main.run.ram.launches_left())


func test_no_ram_no_view() -> void:
	var main: Main = _main(false)
	_settle(main)
	var view: ChargeView = _view(main)
	assert_false(view.has_ram())
	assert_false(view.visible)
	assert_true(view.pixels().is_empty())


func test_the_lane_row_follows_a_lit_landmark_once_settled() -> void:
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	view.settled = true
	var before: int = view.row()
	main.run.ram.aim(before + 30)
	view.settled = false
	assert_eq(view.row(), before, "not while something plays")
	view.settled = true
	assert_eq(view.row(), before + 30)


func test_cues_show_only_when_settled_and_the_next_launch_charges() -> void:
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	var row: int = main.run.ram.row
	var right: int = StarScatter.inner_rect(main.run.sky_rect).end.x
	# One star near the far edge in the lane (lost), one just short of landmark 1 (fleeced).
	var lm: Vector2i = main.run.scorpio.landmark_position(3)
	var stars: Array[Star] = _stand(main, [[Star.Size.MEDIUM, Vector2i(right - 10, row)], [Star.Size.SMALL, Vector2i(lm.x - 16, row)]])
	main.run.ram.launches = 0
	view.settled = true
	assert_false(main.run.ram_charges_next())
	assert_false(view.cues_shown(), "no cue two launches out")
	assert_eq(_count(view.pixels(), [Palette.S4, Palette.S3]) - _count(ChargeView.head_pixels(row, main.run.sky_rect), [Palette.S4]), 0, "no ember ring")
	main.run.ram.launches = 1
	view.settled = false
	assert_false(view.cues_shown(), "not while something plays")
	view.settled = true
	assert_true(view.cues_shown())
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	var ring: Dictionary[Vector2i, Color] = HarvestView.lone_ring_pixels(stars[0].position, stars[0].size, 0.0)
	var ringed: int = 0
	for point: Vector2i in ring:
		if main.run.sky_rect.has_point(point) and pixels.get(point) in [Palette.S4, Palette.S3]:
			ringed += 1
	assert_gt(ringed, ring.size() / 2, "the star it loses wears an ember ring")
	var stop: Vector2i = main.run.charge_preview().destinations()[stars[1].id]
	var corner: int = StarView.half_extent(stars[1].size) + 1
	assert_eq(pixels.get(stop + Vector2i(corner, corner)), Palette.C1, "corner dots where it will stop")
	assert_eq(pixels.get(stop + Vector2i(-corner, -corner)), Palette.C1)


func test_the_charge_plays_and_a_lost_star_is_gone_after() -> void:
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	var sky: SkyView = main.get_node("Sky")
	var row: int = main.run.ram.row
	var right: int = StarScatter.inner_rect(main.run.sky_rect).end.x
	var lm: Vector2i = main.run.scorpio.landmark_position(3)
	var stars: Array[Star] = _stand(main, [[Star.Size.MEDIUM, Vector2i(right - 10, row)], [Star.Size.SMALL, Vector2i(lm.x - 16, row)]])
	main.run.ram.launches = 1
	view.settled = true
	var lost: StarView = sky.star_view(stars[0].id)
	assert_not_null(lost)
	var charged: Array = []
	main.run.ram_charged.connect(func(r: int, moves: Array, fleeced: Array) -> void: charged.append([r, moves, fleeced]))
	main.run.dust = 999
	main.run.buy("blue")
	main.run.load_pack("blue")
	assert_true(main.run.launch(Vector2i(90, main.run.sky_rect.position.y + 20)))
	assert_eq(charged.size(), 1, "the second launch charges")
	await _play_out(main)
	assert_false(view.is_charging())
	assert_null(sky.star_view(stars[0].id), "the lost star's view is gone")
	assert_true(not is_instance_valid(lost) or lost.is_queued_for_deletion(), "and freed")
	assert_true(main.run.ram.is_fleeced(stars[1].id))
	view.settled = true
	var at: Vector2i = main.run.find_star(stars[1].id).position
	var ring: Dictionary[Vector2i, Color] = ChargeView.fleece_ring_pixels(at, stars[1].size)
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in ring:
		assert_eq(pixels.get(point), ring[point], "the fleeced star keeps a gold ring")
	assert_eq(view.lit_pips(), main.run.ram.every, "the pips refill")


func test_the_charge_rears_then_charges() -> void:
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	var sky: Rect2i = main.run.sky_rect
	var row: int = main.run.ram.row
	view.charge(row, [] as Array[StarCurrent.Move], [] as Array[int])
	assert_true(view.is_charging())
	assert_eq(view.lit_pips(), 0, "the pips are spent")
	var reared: Dictionary[Vector2i, Color] = ChargeView.head_pixels(row, sky, ChargeView.LIFT)
	var pixels: Dictionary[Vector2i, Color] = view.pixels()
	for point: Vector2i in reared:
		assert_eq(pixels.get(point), reared[point], "it rears up")
	view.advance(ChargeView.REAR_TIME + ChargeView.CHARGE_TIME * 0.5)
	pixels = view.pixels()
	var lunge: Dictionary[Vector2i, Color] = ChargeView.head_pixels(row, sky, 0, ChargeView.LUNGE)
	for point: Vector2i in lunge:
		assert_eq(pixels.get(point), lunge[point], "it lunges")
	assert_gt(_count(pixels, [Palette.N6]), 0, "its dust streaks along the lane")
	view.advance(ChargeView.CHARGE_TIME)
	assert_false(view.is_charging())
	assert_almost_eq(ChargeView.charge_hold(), ChargeView.REAR_TIME + ChargeView.CHARGE_TIME, 0.001)


func test_a_lost_star_cuts_out_in_ember_sparks() -> void:
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	var at := Vector2i(main.run.sky_rect.end.x - 6, main.run.ram.row)
	view.flash_loss(at)
	assert_gt(_count(view.pixels(), [Palette.S4, Palette.S3, Palette.C3]), 4)
	view.advance(ChargeView.LOSS_TIME + 0.01)
	assert_eq(_count(ChargeView.spark_pixels(at, 0.5, 1), [Palette.M5, Palette.M4]), 0, "embers, not water droplets")


func test_every_colour_is_from_the_palette() -> void:
	var allowed: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var fields: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if fields.size() >= 4 and fields[0].is_valid_int():
			allowed[Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()).to_html(false)] = true
	var main: Main = _main()
	_settle(main)
	var view: ChargeView = _view(main)
	var row: int = main.run.ram.row
	var right: int = StarScatter.inner_rect(main.run.sky_rect).end.x
	var lm: Vector2i = main.run.scorpio.landmark_position(3)
	var stars: Array[Star] = _stand(main, [[Star.Size.MEDIUM, Vector2i(right - 10, row)], [Star.Size.SMALL, Vector2i(lm.x - 16, row)]])
	main.run.ram.launches = 1
	main.run.ram.fleece([stars[1].id])
	view.settled = true
	var frames: Array[Dictionary] = [view.pixels()]
	var charge: StarCharge.Charge = main.run.charge_preview()
	view.charge(row, charge.moves, charge.fleeced)
	for i: int in 12:
		frames.append(view.pixels())
		view.advance(0.05)
	view.flash_loss(Vector2i(right, row))
	frames.append(view.pixels())
	var bad: int = 0
	for frame: Dictionary in frames:
		for point: Vector2i in frame:
			var c: Color = frame[point]
			if c.a8 != 255 or not allowed.has(c.to_html(false)):
				bad += 1
	assert_eq(bad, 0, "palette colours only")


func test_its_rule_line_fits_and_is_said() -> void:
	for line: String in Hud.RAM_MESSAGE.split("\n"):
		assert_lte(line.length(), 24, line)
	var main: Main = _main()
	var hud: Hud = main.get_node("HUD")
	assert_eq(hud._stage_rule(), Hud.RAM_MESSAGE)


## Plays in real frames until nothing is playing (the scene's tweens run too).
func _play_out(main: Main) -> void:
	var sequencer: EventSequencer = main.get_node("EventSequencer")
	var start: int = Time.get_ticks_msec()
	await get_tree().process_frame
	while sequencer.is_busy() and Time.get_ticks_msec() - start < 15000:
		await get_tree().process_frame
	for i: int in 5:
		await get_tree().process_frame
