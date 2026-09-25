extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")

var sequencer: EventSequencer
var run: RunState
var played: Array[StringName] = []


func before_each() -> void:
	sequencer = EventSequencer.new()
	sequencer.set_process(false)
	add_child_autofree(sequencer)
	run = Fixtures.run({"start_dust": 20})
	sequencer.bind(run)
	played.clear()
	sequencer.event_played.connect(func(event: EventSequencer.RunEvent) -> void: played.append(event.type))
	watch_signals(sequencer)


func test_idle_until_the_run_emits() -> void:
	assert_false(sequencer.is_busy())
	sequencer.advance(1.0)
	assert_eq(played, [] as Array[StringName])


func test_events_queue_and_play_in_order_on_advance() -> void:
	run.buy("red")
	assert_true(sequencer.is_busy(), "busy as soon as something is queued")
	assert_signal_emitted(sequencer, "sequence_started")
	assert_eq(played, [] as Array[StringName], "nothing plays during the RunState call")
	sequencer.advance(0.0)
	assert_eq(played, [&"pack_bought", &"pack_loaded"] as Array[StringName])
	assert_false(sequencer.is_busy())
	assert_signal_emitted(sequencer, "sequence_finished")


func test_event_keeps_its_arguments() -> void:
	var events: Array[EventSequencer.RunEvent] = []
	sequencer.event_played.connect(func(event: EventSequencer.RunEvent) -> void: events.append(event))
	run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	var burst: EventSequencer.RunEvent = events.filter(
		func(e: EventSequencer.RunEvent) -> bool: return e.type == &"pack_burst"
	)[0]
	assert_eq(burst.args[0], "blue")
	assert_eq(burst.args[1], Vector2i(90, 160))
	assert_eq((burst.args[2] as Array).size(), 3, "the burst carries its stars")


func test_hold_delays_the_next_event() -> void:
	sequencer.event_played.connect(func(_e: EventSequencer.RunEvent) -> void: sequencer.hold(0.5))
	run.buy("red")
	sequencer.advance(0.0)
	assert_eq(played, [&"pack_bought"] as Array[StringName])
	sequencer.advance(0.4)
	assert_eq(played.size(), 1, "still holding")
	sequencer.advance(0.2)
	assert_eq(played, [&"pack_bought", &"pack_loaded"] as Array[StringName])
	assert_true(sequencer.is_busy(), "the last event is still holding")
	sequencer.advance(0.5)
	assert_false(sequencer.is_busy())
	assert_signal_emit_count(sequencer, "sequence_finished", 1)


func test_longest_hold_wins() -> void:
	sequencer.event_played.connect(func(_e: EventSequencer.RunEvent) -> void: sequencer.hold(0.2))
	sequencer.event_played.connect(func(_e: EventSequencer.RunEvent) -> void: sequencer.hold(0.6))
	run.buy("blue")
	sequencer.advance(0.0)
	sequencer.advance(0.5)
	assert_true(sequencer.is_busy())
	sequencer.advance(0.2)
	assert_false(sequencer.is_busy())


func test_events_emitted_while_playing_join_the_same_sequence() -> void:
	sequencer.event_played.connect(func(_e: EventSequencer.RunEvent) -> void: sequencer.hold(0.3))
	run.buy("red")
	sequencer.advance(0.0)
	run.launch(Vector2i(90, 160))
	sequencer.advance(1.0)
	sequencer.advance(1.0)
	sequencer.advance(1.0)
	assert_signal_emit_count(sequencer, "sequence_started", 1)
	assert_eq(played.slice(0, 3), [&"pack_bought", &"pack_loaded", &"pack_launched"] as Array[StringName])


func test_rejected_link_is_queued_too() -> void:
	run.link([1, 2, 3] as Array[int])
	sequencer.advance(0.0)
	assert_eq(played, [&"link_rejected"] as Array[StringName])


func test_rebinding_drops_the_old_run() -> void:
	run.buy("blue")
	var next_run: RunState = Fixtures.run({"start_dust": 20}, 2)
	sequencer.bind(next_run)
	assert_false(sequencer.is_busy(), "queued events from the old run are dropped")
	run.buy("blue")
	sequencer.advance(0.0)
	assert_eq(played, [] as Array[StringName], "the old run is no longer heard")
	next_run.buy("red")
	sequencer.advance(0.0)
	assert_eq(played, [&"pack_bought", &"pack_loaded"] as Array[StringName])


func test_pointer_input_is_swallowed_only_while_busy() -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	sequencer._input(touch)
	assert_false(get_viewport().is_input_handled(), "idle: touches pass")
	run.buy("blue")
	sequencer._input(key)
	assert_false(get_viewport().is_input_handled(), "keys (debug B) always pass")
	sequencer._input(touch)
	assert_true(get_viewport().is_input_handled(), "busy: touches are swallowed")


func test_queued_events_keep_a_snapshot_of_array_arguments() -> void:
	var events: Array[EventSequencer.RunEvent] = []
	sequencer.event_played.connect(func(event: EventSequencer.RunEvent) -> void: events.append(event))
	var selection: Array[int] = [1, 2, 3]
	run.link(selection)
	selection.clear()
	sequencer.advance(0.0)
	assert_eq(events[0].args[0], [1, 2, 3] as Array[int], "clearing the selection after link() doesn't empty the event")
