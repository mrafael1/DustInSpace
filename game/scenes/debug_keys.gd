class_name DebugKeys
extends Node
## Development shortcuts, active in debug builds only.
## L: launch the loaded pack at a random point in the sky (stand-in until the slingshot, #5).

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


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	_rng.seed = run.run_seed ^ TARGET_SEED_SALT


## Launches like a player would: not while a sequence is still playing.
func launch_at_random() -> bool:
	if _run == null or _sequencer.is_busy():
		return false
	var sky: Rect2i = _run.sky_rect
	var target := Vector2i(
		_rng.randi_range(sky.position.x, sky.end.x - 1),
		_rng.randi_range(sky.position.y, sky.end.y - 1),
	)
	return _run.launch(target)
