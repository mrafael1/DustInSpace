class_name IdleHint
extends Node
## The idle hint (#90, playtest: a player who freezes gets no help). After `hints.idle_seconds`
## without an interaction, with a valid link in the sky, the guided run's hand (HandDemo) acts out
## dragging one valid link (RunState.idle_hint_link), star to star in an order that stays in reach,
## leaving its dotted trail; each star shines with the link hint's shine as the hand reaches it
## (Sky.show_idle_hint). The demo plays PASSES times, then the hand goes and the wait starts over.
## Any touch (a pick, an aim, a buy, a tap anywhere) resets the wait and stops the hint, and nothing
## counts while a finger is down or a link is being traced. The wait holds still while animations
## play: the event sequencer is busy (a burst, a Big Bang, the Sun igniting) or `is_held` says so
## (Main: payouts still flying, the tutorial's own hand showing); a hint playing then stops. Owns no
## rules; which link it shows is the core's call.
## It watches input as Main's last child, so it sees every touch before anything takes it (a release
## over the speaker included), and takes none.

## A hint starts showing `link` (Main stops an aiming telescope, so the sky takes links).
signal hint_started(link: Array[int])
## A finger touched down, before anything else took the touch (the playtest log's idle gaps).
signal touch_started

## The demo runs this many times through the link before the hand goes.
const PASSES: int = 2

## Main sets it: the sky whose stars shine and whose link the hand shows.
var sky: SkyView
## Main sets it: true while an animation outside the sequencer plays, so the wait holds still.
var is_held: Callable = func() -> bool: return false

var _run: RunState
var _sequencer: EventSequencer
## Seconds of idling counted so far.
var _idle: float = 0.0
## The link shown now, and seconds since its hint started (-1: none).
var _link: Array[int] = []
var _shine_time: float = -1.0
var _hand := HandDemo.new()
## Fingers down now, by touch index.
var _fingers: Dictionary[int, bool] = {}
## Picks among equal links. Its own stream, so a hint never shifts the run's randomness.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_hand.name = "Hand"
	add_child(_hand)


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	observe(event)


func _notification(what: int) -> void:
	# A release lost with the focus would hold the hint for good.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_fingers.clear()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	_sequencer = sequencer
	_fingers.clear()
	reset()


## Seeds the choice among equal links (tests).
func seed_choice(value: int) -> void:
	_rng.seed = value


## An interaction: the wait starts over and a hint playing stops.
func reset() -> void:
	_idle = 0.0
	_stop()


## Feeds one input event: a touch, a drag or a click is an interaction.
func observe(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_fingers[touch.index] = true
			touch_started.emit()
		else:
			_fingers.erase(touch.index)
		reset()
	elif event is InputEventScreenDrag or event is InputEventMouseButton:
		reset()


## Seconds of idling counted so far.
func idle_time() -> float:
	return _idle


## The link the hint shows now (empty when none).
func shining_link() -> Array[int]:
	return _link.duplicate()


## The hand acting out the link.
func hand() -> HandDemo:
	return _hand


## Counts the wait and plays the shine. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _held():
		_stop()
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
		hint_started.emit(_link.duplicate())
		_hand.play(sky.link_points(_link))
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


## How long the whole hint plays: PASSES runs of the hand's demo through the link.
static func play_time() -> float:
	return PASSES * HandDemo.pass_time(Combos.LINK_LENGTH)


## Moves the hand on and shines the star it reached; once the last pass is done, the hint ends.
func _show() -> void:
	if _shine_time >= play_time():
		_stop()
		return
	_hand.show_time(_shine_time)
	sky.show_idle_hint(_shining_at(_shine_time))


## Ends a hint playing: the hand goes and nothing shines.
func _stop() -> void:
	if _shine_time < 0.0:
		return
	_shine_time = -1.0
	_link.clear()
	_hand.stop()
	if sky != null:
		sky.show_idle_hint([] as Array[int])


## The stars of the link that shine `t` seconds into the hint: each from when the hand reaches it,
## for one shine.
func _shining_at(t: float) -> Array[int]:
	var on: Array[int] = []
	var local: float = fmod(t, HandDemo.pass_time(_link.size()))
	for k: int in _link.size():
		var since: float = local - HandDemo.arrival(k)
		if since >= 0.0 and since < shine_time():
			on.append(_link[k])
	return on
