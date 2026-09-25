class_name EventSequencer
extends Node
## Queues RunState signals so their animations play one after another.
## RunState resolves every action instantly; this node replays the resulting events at
## animation speed. Views listen to `event_played` and call `hold()` for however long
## their animation for that event takes. The next event plays when the longest hold ends.
## Pointer input is swallowed while a sequence plays. For that to work this node must be
## the last child of Main: `_input` runs on the last node in tree order first.

signal sequence_started
signal event_played(event: RunEvent)
signal sequence_finished


## One RunState signal, recorded with its arguments.
class RunEvent:
	extends RefCounted
	## The RunState signal name, e.g. &"pack_burst".
	var type: StringName
	var args: Array

	func _init(p_type: StringName, p_args: Array) -> void:
		type = p_type
		args = p_args


var _run: RunState
## Signal name -> the callable connected to it, so unbind() removes exactly those.
var _connections: Dictionary[StringName, Callable] = {}
var _queue: Array[RunEvent] = []
var _hold_left: float = 0.0
var _busy: bool = false


func _process(delta: float) -> void:
	advance(delta)


func _input(event: InputEvent) -> void:
	if _busy and _is_pointer(event):
		get_viewport().set_input_as_handled()


## Listens to every signal of `run`. Drops any events still queued from a previous run.
func bind(run: RunState) -> void:
	unbind()
	_run = run
	for info: Dictionary in run.get_script().get_script_signal_list():
		var signal_name: StringName = info["name"]
		var callable: Callable = _on_run_signal.bind(signal_name)
		run.connect(signal_name, callable)
		_connections[signal_name] = callable


func unbind() -> void:
	if _run != null:
		for signal_name: StringName in _connections:
			_run.disconnect(signal_name, _connections[signal_name])
	_connections.clear()
	_run = null
	_queue.clear()
	_hold_left = 0.0
	_busy = false


## True while events are queued or an event's animation is still holding the sequence.
func is_busy() -> bool:
	return _busy


## Called by views from their `event_played` handler: keep the current event on screen
## for `seconds`. Several holds on one event overlap; the longest one wins.
func hold(seconds: float) -> void:
	_hold_left = maxf(_hold_left, seconds)


## Plays queued events whose turn has come. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if not _busy:
		return
	_hold_left -= delta
	while _hold_left <= 0.0 and not _queue.is_empty():
		_hold_left = 0.0
		event_played.emit(_queue.pop_front())
	if _hold_left <= 0.0 and _queue.is_empty():
		_hold_left = 0.0
		_busy = false
		sequence_finished.emit()


func _on_run_signal(...args: Array) -> void:
	var signal_name: StringName = args.pop_back()
	_queue.append(RunEvent.new(signal_name, _snapshot(args)))
	if not _busy:
		_busy = true
		sequence_started.emit()


## Copies array arguments so callers can reuse theirs (e.g. clear a selection) before the event plays.
func _snapshot(args: Array) -> Array:
	var copy: Array = []
	for arg: Variant in args:
		copy.append(arg.duplicate() if arg is Array else arg)
	return copy


func _is_pointer(event: InputEvent) -> bool:
	return (
		event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventMouseButton
		or event is InputEventMouseMotion
	)
