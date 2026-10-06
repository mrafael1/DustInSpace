class_name DebugKeys
extends Node
## Development shortcuts, active in debug builds only.
## L: launch the loaded pack at a random point in the sky (stand-in until the slingshot, #5); with
##    the slingshot empty, it loads the first owned kind first.
## B: the next pack opens as a Big Bang.
## T: switch between the telescope and the slingshot (issue #52's comparison).

## T was pressed (Main swaps the launchers).
signal launcher_switch_requested
signal current_switch_requested

## XOR'd into the run seed so debug targets get their own stream.
const TARGET_SEED_SALT: int = 0xDEB6

var _run: RunState
var _sequencer: EventSequencer
## Picks debug launch targets. Separate from the run's RNG so it never shifts pack contents,
## but seeded from the run so the same seed and the same L presses replay the same sky.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process_unhandled_key_input(OS.is_debug_build())


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_L:
		launch_at_random()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_B:
		force_big_bang()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_T:
		launcher_switch_requested.emit()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_C and _run != null and _run.scorpio != null and _run.scorpio.map.id.begins_with("current_"):
		current_switch_requested.emit()
		get_viewport().set_input_as_handled()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	_rng.seed = run.run_seed ^ TARGET_SEED_SALT


## Makes the next launched pack a Big Bang. Returns false with no run.
func force_big_bang() -> bool:
	if _run == null:
		return false
	_run.force_next_big_bang = true
	return true


## Launches like a player would: not while a sequence is still playing. An empty slingshot is
## loaded first with the first owned kind, so L can be pressed again and again.
func launch_at_random() -> bool:
	if _run == null or _sequencer.is_busy():
		return false
	if _run.loaded_pack == "":
		for kind: String in _run.balance.pack_kinds():
			if _run.load_pack(kind):
				break
	var sky: Rect2i = _run.sky_rect
	var target := Vector2i(
		_rng.randi_range(sky.position.x, sky.end.x - 1),
		_rng.randi_range(sky.position.y, sky.end.y - 1),
	)
	return _run.launch(target)
