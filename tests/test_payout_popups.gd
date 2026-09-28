extends GutTest
## Floating dust payouts (#59): one popup per collected link, gone once its dust lands; the
## dust itself is counted as before.

const Fixtures := preload("res://tests/fixtures.gd")
const MainScene := preload("res://game/scenes/main.tscn")
const STEP: float = 1.0 / 60.0

var run: RunState
var sequencer: EventSequencer
var particles: CollectParticles
var popups: PayoutPopups
var dust_landed: int = 0


func before_each() -> void:
	run = Fixtures.run({"sun_target": 100000})
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	particles = CollectParticles.new()
	add_child_autofree(particles)
	particles.set_process(false)
	particles.setup(run, sequencer)
	popups = PayoutPopups.new()
	add_child_autofree(popups)
	popups.set_process(false)
	popups.setup(run, sequencer)
	particles.dust_payout_launched.connect(popups.show_payout)
	particles.dust_payout_landed.connect(popups.release)
	dust_landed = 0
	particles.dust_arrived.connect(func(n: int) -> void: dust_landed += n)


func test_a_valid_link_shows_its_dust_once() -> void:
	_link([Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL], [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)])
	sequencer.advance(0.0)
	var dust: int = run.balance.combos["small_triple"].dust
	assert_eq(popups.texts(), ["+%d" % dust] as Array[String])
	_play(0.3)
	assert_eq(popups.count(), 1, "still one")


func test_an_invalid_link_shows_nothing_and_spends_nothing() -> void:
	var dust_before: int = run.dust
	_link([Star.Size.SMALL, Star.Size.SMALL, Star.Size.BIG], [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)])
	sequencer.advance(0.0)
	assert_eq(popups.count(), 0)
	assert_eq(run.dust, dust_before)


func test_it_leaves_once_its_dust_has_landed() -> void:
	_link([Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL], [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)])
	sequencer.advance(0.0)
	var landed: Array[bool] = []
	particles.dust_payout_landed.connect(func(_payout: int) -> void: landed.append(true))
	var landed_at: float = -1.0
	var gone_at: float = -1.0
	var t: float = 0.0
	while t < PayoutPopups.MAX_TIME + 0.5 and gone_at < 0.0:
		t += STEP
		particles.advance(STEP)
		if not landed.is_empty() and landed_at < 0.0:
			landed_at = t
		popups.advance(STEP)
		if popups.count() == 0:
			gone_at = t
	assert_gt(landed_at, 0.0, "its dust landed")
	assert_gte(gone_at, landed_at, "not before the dust lands")
	assert_lte(gone_at, landed_at + PayoutPopups.LINGER + 2 * STEP, "and soon after")
	assert_gte(gone_at, PayoutPopups.MIN_TIME - STEP, "never shorter than MIN_TIME")


func test_the_dust_is_counted_once_as_before() -> void:
	_link([Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.MEDIUM], [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)])
	sequencer.advance(0.0)
	_play(3.0)
	assert_eq(dust_landed, run.balance.combos["medium_triple"].dust, "the popup adds nothing")
	assert_eq(run.dust, run.balance.start_dust + run.balance.combos["medium_triple"].dust)
	assert_false(sequencer.is_busy(), "nothing held the sequence")


func test_it_rises_on_whole_pixels_and_the_top_payout_flashes_and_hops() -> void:
	_link([Star.Size.BIG, Star.Size.BIG, Star.Size.BIG], [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)])
	sequencer.advance(0.0)
	var start: Vector2i = popups.rects()[0].position
	var label: Label = popups.get_child(0).get_child(0)
	assert_eq(label.label_settings.font_color, Palette.C0, "the top payout flashes")
	var lowest: int = start.y
	var highest: int = start.y
	for i: int in 40:
		popups.advance(STEP)
		var at: Vector2i = popups.rects()[0].position
		assert_eq(Vector2(at), popups.get_child(0).position, "whole pixels")
		lowest = maxi(lowest, at.y)
		highest = mini(highest, at.y)
	assert_eq(label.label_settings.font_color, Palette.D0, "then the dust colour")
	assert_eq(start.y - highest, PayoutPopups.RISE + 1, "rises RISE px, and hops one more")
	assert_eq(lowest, start.y)


func test_a_normal_payout_uses_the_dust_colour_and_does_not_hop() -> void:
	_link([Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL], [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)])
	sequencer.advance(0.0)
	var label: Label = popups.get_child(0).get_child(0)
	assert_eq(label.label_settings.font_color, Palette.D0)
	var start: int = popups.rects()[0].position.y
	var highest: int = start
	for i: int in 40:
		popups.advance(STEP)
		highest = mini(highest, popups.rects()[0].position.y)
	assert_eq(start - highest, PayoutPopups.RISE)


func test_it_starts_away_from_the_last_star() -> void:
	var stars: Array[Vector2i] = [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)]
	var size := Vector2i(17, 7)
	var at: Vector2i = PayoutPopups.place(stars, size, Fixtures.SKY)
	var centre: Vector2i = at + size / 2
	assert_lt(centre.x, 60, "pushed left, away from the last star on the right")
	assert_lt(centre.y, 150, "and up")


func test_it_stays_inside_the_visible_sky_on_any_layout() -> void:
	for screen: Rect2i in [Rect2i(0, 0, 180, 320), Rect2i(-7, -102, 195, 422), Rect2i(-38, -21, 256, 341)]:
		popups.fit_screen(screen)
		var area: Rect2i = popups.bounds()
		assert_eq(area.position.x, screen.position.x + PayoutPopups.EDGE)
		assert_eq(area.end.x, screen.end.x - PayoutPopups.EDGE)
		for stars: Array[Vector2i] in [
			[Vector2i(0, 78), Vector2i(4, 80), Vector2i(8, 79)] as Array[Vector2i],
			[Vector2i(175, 240), Vector2i(170, 245), Vector2i(179, 249)] as Array[Vector2i],
			[Vector2i(90, 90), Vector2i(90, 86), Vector2i(90, 82)] as Array[Vector2i],
		]:
			var size := Vector2i(23, 7)
			var at: Vector2i = PayoutPopups.place(stars, size, area)
			assert_true(area.encloses(Rect2i(at - Vector2i(0, PayoutPopups.RISE), size + Vector2i(0, PayoutPopups.RISE))), "%s inside %s all the way up" % [at, area])


func test_quick_successive_payouts_each_show_and_do_not_overlap() -> void:
	var stars: Array[Vector2i] = [Vector2i(40, 150), Vector2i(60, 150), Vector2i(80, 150)]
	popups.show_payout(1, 3, stars)
	popups.show_payout(2, 5, stars)
	popups.show_payout(3, 6, stars)
	assert_eq(popups.count(), 3)
	var rects: Array[Rect2i] = popups.rects()
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "popups %d and %d apart" % [i, j])
	popups.release(2)
	for i: int in ceili(PayoutPopups.MIN_TIME / STEP) + 2:
		popups.advance(STEP)
	assert_eq(popups.texts(), ["+3", "+6"] as Array[String], "each leaves on its own landing")


func test_a_new_run_clears_every_popup() -> void:
	popups.show_payout(1, 3, [Vector2i(60, 150)] as Array[Vector2i])
	popups.setup(Fixtures.run(), sequencer)
	assert_eq(popups.count(), 0)


func test_a_popup_whose_dust_never_lands_still_goes() -> void:
	popups.show_payout(1, 3, [Vector2i(60, 150)] as Array[Vector2i])
	for i: int in ceili(PayoutPopups.MAX_TIME / STEP) + 1:
		popups.advance(STEP)
	assert_eq(popups.count(), 0)


func test_the_text_is_a_bitmap_font_label_in_the_dust_colour() -> void:
	popups.show_payout(1, 3, [Vector2i(60, 150)] as Array[Vector2i])
	var label: Label = popups.get_child(0).get_child(0)
	assert_eq(label.label_settings.font, HudText.PRIMARY_FONT)
	assert_eq(label.label_settings.font_color, Palette.D0)
	assert_true(popups.get_child(0).get_child(1) is DustIcon, "with the small dust diamond")


func test_in_main_a_link_pops_its_payout() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var main_popups: PayoutPopups = main.get_node("Payouts")
	var ids: Array[int] = []
	for x: int in [40, 60, 80]:
		ids.append(main.run.add_star(Star.Size.SMALL, Vector2i(x, 150)).id)
	main.run.link(ids)
	(main.get_node("EventSequencer") as EventSequencer).advance(0.0)
	assert_eq(main_popups.count(), 1)
	assert_null(main.get_node("HUD").get_node_or_null("Light"), "no Sun number")


func _link(sizes: Array, at: Array[Vector2i]) -> void:
	var ids: Array[int] = []
	for i: int in sizes.size():
		ids.append(run.add_star(sizes[i], at[i]).id)
	run.link(ids)


func _play(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		t += STEP
		sequencer.advance(STEP)
		particles.advance(STEP)
		popups.advance(STEP)
