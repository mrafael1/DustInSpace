extends GutTest
## The end screen: when it shows, what it says, what it blocks, and restart.

const Fixtures := preload("res://tests/fixtures.gd")
const EndScreenScene := preload("res://game/ui/end_screen.tscn")
const MainScene := preload("res://game/scenes/main.tscn")

var run: RunState
var sequencer: EventSequencer
var screen: EndScreen


func before_each() -> void:
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	screen = EndScreenScene.instantiate()
	add_child_autofree(screen)
	screen.setup(run, sequencer)


func test_hidden_while_the_run_plays() -> void:
	assert_false(screen.is_showing())
	assert_false(screen.handle_pointer(_touch(Vector2i(90, 160), true)), "no input taken")


func test_a_win_waits_for_the_sequence_then_shows() -> void:
	sequencer.event_played.connect(_hold_on_win)
	_win()
	sequencer.advance(0.0)
	assert_false(screen.is_showing(), "the Sun's ignition plays first")
	sequencer.advance(1.0)
	assert_true(screen.is_showing(), "then the end screen")
	assert_eq(screen.lines(), ["SUN RESTORED", "LIGHT 105/100"] as Array[String])


func test_a_loss_shows_the_sun_fading_and_the_light_reached() -> void:
	run.light = 40
	_lose()
	sequencer.advance(1.0)
	assert_true(screen.is_showing())
	assert_eq(screen.lines(), ["THE SUN FADES", "LIGHT 45/100"] as Array[String])


func test_a_loss_waits_for_the_last_payout_to_land() -> void:
	var payouts := CollectParticles.new()
	add_child_autofree(payouts)
	payouts.set_process(false)
	payouts.setup(run, sequencer)
	screen.watch_payouts(payouts)
	_lose()
	sequencer.advance(1.0)
	assert_gt(payouts.particle_count(), 0, "the losing combo's dust and light are still flying")
	assert_false(screen.is_showing(), "the verdict waits for the counters")
	payouts.advance(CollectParticles.LONGEST_TRAVEL)
	assert_eq(payouts.particle_count(), 0)
	assert_true(screen.is_showing(), "then shows")


func test_a_second_ending_lays_out_exactly_like_the_first() -> void:
	_win()
	sequencer.advance(1.0)
	var first: Array = _layout()
	var next: RunState = Fixtures.run()
	sequencer.bind(next)
	screen.setup(next, sequencer)
	run = next
	_win()
	sequencer.advance(1.0)
	assert_true(screen.is_showing())
	assert_eq(screen.lines(), ["SUN RESTORED", "LIGHT 105/100"] as Array[String], "only this ending's rows")
	assert_eq(_layout(), first, "same rows, same plaque, same button: nothing left from the last ending")


func test_the_text_is_bitmap_font_and_palette_only() -> void:
	_lose()
	sequencer.advance(1.0)
	for label: Node in screen.get_node("Canvas/Lines").get_children():
		var settings: LabelSettings = (label as Label).label_settings
		assert_eq(settings.font, HudText.PRIMARY_FONT)
		assert_true(settings.font_color in [Palette.C1, Palette.S4])
		assert_eq((label as Label).position, (label as Label).position.round(), "whole pixels")
		for c: String in (label as Label).text:
			assert_true(HudText.PRIMARY_FONT.has_char(c.unicode_at(0)), "the font has %s" % c)


func test_restart_is_a_44_pt_target_inside_the_screen() -> void:
	_lose()
	sequencer.advance(1.0)
	var button: Rect2i = screen.restart_rect()
	assert_gte(button.size.y, 22, "44 pt at 2 pt per px")
	assert_true(Rect2i(0, 0, 180, 320).encloses(button))


func test_a_tap_on_restart_asks_for_a_new_run() -> void:
	_lose()
	sequencer.advance(1.0)
	watch_signals(screen)
	var centre: Vector2i = screen.restart_rect().get_center()
	assert_true(screen.handle_pointer(_touch(centre, true)))
	assert_true(screen.handle_pointer(_touch(centre, false)))
	assert_signal_emitted(screen, "restart_requested")


func test_everything_else_is_blocked_and_does_nothing() -> void:
	_lose()
	sequencer.advance(1.0)
	watch_signals(screen)
	assert_true(screen.handle_pointer(_touch(Vector2i(90, 40), true)), "taken")
	assert_true(screen.handle_pointer(_touch(Vector2i(90, 40), false)))
	var centre: Vector2i = screen.restart_rect().get_center()
	screen.handle_pointer(_touch(Vector2i(90, 40), true))
	screen.handle_pointer(_touch(centre, false))
	assert_signal_not_emitted(screen, "restart_requested", "a tap must start and end on the button")


func test_restart_in_main_starts_a_fresh_run_and_hides_the_screen() -> void:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	add_child_autofree(main)
	var old: RunState = main.run
	old.light = 60
	old.outcome = RunState.Outcome.LOST
	var end_screen: EndScreen = main.get_node("EndScreen")
	end_screen.visible = true
	end_screen.restart_requested.emit()
	assert_ne(main.run, old, "a new RunState")
	assert_eq(main.run.outcome, RunState.Outcome.PLAYING)
	assert_eq(main.run.light, 0)
	assert_eq(main.run.balance, old.balance, "on the same balance")
	assert_false(end_screen.is_showing())


## Where each row sits and where the button is, for comparing layouts.
func _layout() -> Array:
	var rows: Array = []
	for label: Node in screen.get_node("Canvas/Lines").get_children():
		rows.append((label as Label).position)
	return [rows, screen.restart_rect()]


## Links a sequence (25 light) with 80 already in: a win at 105.
func _win() -> void:
	run.light = 80
	_link([Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG])
	assert_eq(run.outcome, RunState.Outcome.WON)


## No packs, and a small triple that pays 3 dust (a pack costs 4) and empties the sky.
func _lose() -> void:
	for kind: String in run.owned_packs.keys():
		run.owned_packs[kind] = 0
	run.loaded_pack = ""
	_link([Star.Size.SMALL, Star.Size.SMALL, Star.Size.SMALL])
	assert_eq(run.outcome, RunState.Outcome.LOST)


func _link(sizes: Array) -> void:
	var ids: Array[int] = []
	for i: int in sizes.size():
		ids.append(run.add_star(sizes[i] as Star.Size, Vector2i(60 + 20 * i, 150)).id)
	run.link(ids)


## Stands in for the Sun: the win's event keeps the sequence busy for a moment.
func _hold_on_win(event: EventSequencer.RunEvent) -> void:
	if event.type == &"run_won":
		sequencer.hold(0.5)


func _touch(point: Vector2i, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(point)
	e.pressed = pressed
	return e
