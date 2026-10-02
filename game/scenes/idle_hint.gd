class_name IdleHint
extends Node
## The idle hint (#90, playtest: a player who freezes gets no help). After `hints.idle_seconds`
## without an interaction, with a valid link in the sky, the three stars of one valid link
## (RunState.idle_hint_link) shine one after another, in link order, with the link hint's shine
## (Sky.show_idle_hint). Then the wait starts over.
## Any touch (a pick, an aim, a buy, a tap anywhere) resets the wait, and nothing counts while a
## finger is down or a link is being traced. The wait holds still while animations play: the event
## sequencer is busy (a burst, a Big Bang, the Sun igniting) or `is_held` says so (Main: payouts
## still flying). Owns no rules; which link shines is the core's call.

## The next star of the link starts to shine this long after the previous one.
const STAR_STEP: float = 0.3

## Main sets it: the sky whose stars shine.
var sky: SkyView
## Main sets it: true while an animation outside the sequencer plays, so the wait holds still.
var is_held: Callable = func() -> bool: return false

var _run: RunState
var _sequencer: EventSequencer
## Seconds of idling counted so far.
var _idle: float = 0.0
## The link shining now, and seconds since it started (-1: none).
var _link: Array[int] = []
var _shine_time: float = -1.0
## Fingers down now, by touch index.
var _fingers: Dictionary[int, bool] = {}
## Picks among equal links. Its own stream, so a hint never shifts the run's randomness.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	observe(event)


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	_fingers.clear()
	reset()


## Seeds the choice among equal links (tests).
func seed_choice(value: int) -> void:
	_rng.seed = value


## An interaction: the wait starts over and a hint shining stops.
func reset() -> void:
	_idle = 0.0
	if _shine_time >= 0.0:
		_shine_time = -1.0
		_link.clear()
		if sky != null:
			sky.show_idle_hint([] as Array[int])


## Feeds one input event: a touch, a drag or a click is an interaction.
func observe(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_fingers[touch.index] = true
		else:
			_fingers.erase(touch.index)
		reset()
	elif event is InputEventScreenDrag or event is InputEventMouseButton:
		reset()


## Seconds of idling counted so far.
func idle_time() -> float:
	return _idle


## The link shining now (empty when none).
func shining_link() -> Array[int]:
	return _link.duplicate()


## Counts the wait and plays the shine. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _held():
		return
	if _shine_time >= 0.0:
		_shine_time += delta
		_show()
		return
	_idle += delta
	if _idle < _run.balance.hint_idle_seconds:
		return
	_idle = 0.0
	_link = _run.idle_hint_link(_rng)
	if not _link.is_empty():
		_shine_time = 0.0
		_show()


## Whether the wait holds still: no hint here, the run is over, someone is touching or tracing, or
## an animation plays.
func _held() -> bool:
	if _run == null or sky == null or _run.balance.hint_idle_seconds <= 0.0 or _run.is_over():
		return true
	if not _fingers.is_empty() or not sky.selected_ids().is_empty():
		return true
	return _sequencer.is_busy() or is_held.call()


## How long each star shines: the link hint's shine once, from its longest rays to gone.
static func shine_time() -> float:
	return StarView.SHINE_STEP * StarView.SHINE_RAYS.size()


## Shines the stars of the link whose turn it is; once the last is done, the wait starts over.
func _show() -> void:
	var on: Array[int] = []
	for i: int in _link.size():
		var since: float = _shine_time - i * STAR_STEP
		if since >= 0.0 and since < shine_time():
			on.append(_link[i])
	sky.show_idle_hint(on)
	if _shine_time >= (_link.size() - 1) * STAR_STEP + shine_time():
		_shine_time = -1.0
		_link.clear()
