class_name ScreenShake
extends Camera2D
## Juice: the world jolts a whole pixel when a pack bursts (game-feel: 1-3 px, never on UI
## text). A Camera2D moves only the world canvas; the HUD and other CanvasLayers stay still.
## A Big Bang opens like a normal burst, so it jolts the same. Owns no rules.

## Whole-pixel offsets, one per step, then back to rest.
const SHAKE: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SHAKE_STEP: float = 0.03

var _sequencer: EventSequencer
## Seconds since the shake started, or -1 when still.
var _time: float = -1.0


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT


func _process(delta: float) -> void:
	advance(delta)


func setup(_run: RunState, sequencer: EventSequencer) -> void:
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_time = -1.0
	offset = Vector2.ZERO


func is_shaking() -> bool:
	return _time >= 0.0


## Moves the shake on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	var step: int = floori(_time / SHAKE_STEP)
	if step >= SHAKE.size():
		_time = -1.0
		offset = Vector2.ZERO
	else:
		offset = Vector2(SHAKE[step])


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	if event.type == &"pack_burst" or event.type == &"big_bang_started":
		_time = 0.0
		offset = Vector2(SHAKE[0])
