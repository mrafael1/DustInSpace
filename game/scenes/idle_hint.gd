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
## While the telescope aims (#152) the hint never stops the aim, so the aim preview the player may
## be studying (drift trails, grow and burn outlines, reap outlines) stays: the hand acts out a
## launch instead, tapping the aimed spot without firing. With such a preview showing it waits
## longer (AIM_PREVIEW_IDLE_SECONDS), as the player is likely reading it.
## It watches input as Main's last child, so it sees every touch before anything takes it (a release
## over the speaker included), and takes none.

## A hint starts showing `link` (only while the telescope isn't aiming).
signal hint_started(link: Array[int])
## A hint starts acting out a launch: the hand taps `spot`, the aimed burst point (while aiming).
signal launch_hint_started(spot: Vector2i)
## A finger touched down, before anything else took the touch (the playtest log's idle gaps).
signal touch_started
## A finger lifted (or its touch was cancelled), and a finger moved: the playtest log's idle gaps
## start once the last interaction ends.
signal touch_ended
signal dragged

## The demo runs this many times through the link before the hand goes.
const PASSES: int = 2
## While an aim preview marks what the launch would change, the wait is at least this long:
## presentation timing (the player reading the marks), not a game rule, so it lives here and not in
## balance.json.
const AIM_PREVIEW_IDLE_SECONDS: float = 8.0

## Main sets it: the sky whose stars shine and whose link the hand shows.
var sky: SkyView
## Main sets it: true while an animation outside the sequencer plays, so the wait holds still.
var is_held: Callable = func() -> bool: return false
## Main sets it: true while the telescope aims (a hint then acts out a launch, never a link).
var is_aiming: Callable = func() -> bool: return false
## Main sets it: the aimed burst point the launch hint taps, on the 180x320 grid.
var aim_spot: Callable = func() -> Vector2i: return Vector2i.ZERO
## Main sets it: true while the aim shows a preview of what the launch changes (the longer wait).
var shows_aim_preview: Callable = func() -> bool: return false

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
			touch_ended.emit()
		reset()
	elif event is InputEventScreenDrag or event is InputEventMouseButton:
		if event is InputEventScreenDrag:
			dragged.emit()
		reset()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		# A real mouse aims by hovering: moving it is reading the sky, not idling.
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
		if _hand.is_tapping() and not is_aiming.call():
			_stop()
			return
		_shine_time += delta
		_show()
		return
	_idle += delta
	if _idle < wait_time():
		return
	_idle = 0.0
	if is_aiming.call():
		_start_launch_hint()
		return
	_link = _run.idle_hint_link(_rng)
	if not _link.is_empty():
		_shine_time = 0.0
		hint_started.emit(_link.duplicate())
		_hand.play(sky.link_points(_link))
		_show()


## Seconds of idling before a hint: hints.idle_seconds, or longer while an aim preview shows.
func wait_time() -> float:
	var wait: float = _run.balance.hint_idle_seconds
	if is_aiming.call() and shows_aim_preview.call():
		wait = maxf(wait, AIM_PREVIEW_IDLE_SECONDS)
	return wait


## Whether the hint acts out a launch now (the hand tapping the aim).
func shows_launch() -> bool:
	return _shine_time >= 0.0 and _hand.is_tapping()


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


## How long a launch hint plays: PASSES taps.
static func launch_play_time() -> float:
	return PASSES * HandDemo.tap_time()


## The hand taps the aimed spot (it fires nothing: the hand is drawn, no touch is made).
func _start_launch_hint() -> void:
	var spot: Vector2i = aim_spot.call()
	_shine_time = 0.0
	launch_hint_started.emit(spot)
	_hand.play_tap(spot)
	_show()


## Moves the hand on and shines the star it reached; once the last pass is done, the hint ends.
func _show() -> void:
	if _hand.is_tapping():
		if _shine_time >= launch_play_time():
			_stop()
			return
		_hand.move_tap(aim_spot.call())
		_hand.show_time(_shine_time)
		return
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
