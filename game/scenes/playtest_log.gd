class_name PlaytestLog
extends Node
## Playtest logging (#89, debug builds only): where testers stall, what they try that gets refused,
## and whether they read before moving on. Each record is one JSON object a line, appended to one
## file a session (`user://playtest/<timestamp>.jsonl`, shared by every run and stage in it):
## - run_started: the stage and whether it's the guided run (`guided`, set by Main).
## - step_entered / step_left: a tutorial step and, on leaving, the seconds spent on it (free play,
##   Tutorial.Step.DONE, isn't one).
## - refusal: a refused action's kind (launch, link, buy, load), on which step and stage.
## - idle: a gap of at least IDLE_MIN seconds without a touch, on which step (logged at the touch
##   that ends it, or when the run ends).
## - run_ended: the stage, won, lost or left (a restart, or back to the chart), packs launched and
##   the run's seconds.
## Presentation-side: it only listens to RunState's signals and the views' feedback signals (Main
## wires them), and adds no rules. Release builds and headless runs write nothing (`enabled`).

## Gaps shorter than this aren't worth a record.
const IDLE_MIN: float = 2.0
const DEFAULT_DIR: String = "user://playtest"

## Whether to write at all: debug builds only, and not headless (the GUT runs and CI, which would
## leave files behind). Tests set it.
var enabled: bool = OS.is_debug_build() and DisplayServer.get_name() != "headless"
## Where the session's file goes. Tests point it elsewhere.
var log_dir: String = DEFAULT_DIR
## Main sets it before each run: whether this run is the guided first run.
var guided: bool = false

## The session's file, shared by every PlaytestLog in the process (App makes a Main per stage).
static var _session_file: String = ""

var _run: RunState
## Seconds since the run started, counted in `advance`.
var _time: float = 0.0
var _last_touch: float = 0.0
var _step: int = -1
var _step_since: float = 0.0
var _launches: int = 0
var _ended: bool = false


func _process(delta: float) -> void:
	advance(delta)


## Each run is a fresh RunState: the last one's connections go with it.
func setup(run: RunState, _sequencer: EventSequencer) -> void:
	_end("left")
	_run = run
	_time = 0.0
	_last_touch = 0.0
	_step = -1
	_step_since = 0.0
	_launches = 0
	_ended = false
	_run.tutorial_step.connect(_on_tutorial_step)
	_run.pack_launched.connect(_on_pack_launched)
	_run.link_rejected.connect(_on_link_rejected)
	_run.run_won.connect(_on_run_won)
	_run.run_lost.connect(_on_run_lost)
	write({"type": "run_started", "stage": stage(), "tutorial": guided})


func _exit_tree() -> void:
	_end("left")


func advance(delta: float) -> void:
	_time += delta


## The stage being played: its star map's id, or "sun" for the plain Sun stage.
func stage() -> String:
	if _run == null:
		return ""
	return _run.scorpio.map.id if _run.scorpio != null else "sun"


## A touch began (IdleHint sees every one first): a long enough gap since the last is an idle record.
func touched() -> void:
	_log_idle()
	_last_touch = _time


## A refused action, by kind: "launch", "link", "buy" or "load".
func refused(kind: String) -> void:
	if _run == null or _ended:
		return
	write({"type": "refusal", "kind": kind, "step": _step_name(), "stage": stage()})


## The HUD refused a planet tap: its icon loads (a load), its button buys (a buy).
func pack_tap_refused(_kind: String, part: StringName) -> void:
	refused("load" if part == &"icon" else "buy")


## Appends `record` (with the run's time) to the session's file. Returns whether it was written.
func write(record: Dictionary) -> bool:
	if not enabled:
		return false
	if _session_file == "" or not _session_file.begins_with(log_dir + "/"):
		DirAccess.make_dir_recursive_absolute(log_dir)
		_session_file = "%s/%s.jsonl" % [log_dir, Time.get_datetime_string_from_system().replace(":", "-")]
	var file: FileAccess = FileAccess.open(_session_file, FileAccess.READ_WRITE if FileAccess.file_exists(_session_file) else FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	var line: Dictionary = {"t": snappedf(_time, 0.01)}
	line.merge(record)
	file.store_line(JSON.stringify(line))
	file.close()
	return true


## The file this session writes to ("" until the first record).
static func session_file() -> String:
	return _session_file


## Starts a new session file on the next record (tests).
static func new_session() -> void:
	_session_file = ""


func _on_tutorial_step(step: int) -> void:
	_leave_step()
	# Free play isn't a step to time.
	if step == Tutorial.Step.DONE:
		return
	_step = step
	_step_since = _time
	write({"type": "step_entered", "step": _step_name()})


func _on_pack_launched(_kind: String, _at: Vector2i) -> void:
	_launches += 1


func _on_link_rejected(_ids: Array[int]) -> void:
	refused("link")


func _on_run_won() -> void:
	_end("won")


func _on_run_lost() -> void:
	_end("lost")


func _end(outcome: String) -> void:
	if _run == null or _ended:
		return
	_log_idle()
	_leave_step()
	_ended = true
	write({"type": "run_ended", "stage": stage(), "outcome": outcome, "packs_used": _launches, "seconds": snappedf(_time, 0.01)})


func _leave_step() -> void:
	if _step < 0:
		return
	write({"type": "step_left", "step": _step_name(), "seconds": snappedf(_time - _step_since, 0.01)})
	_step = -1


func _log_idle() -> void:
	var gap: float = _time - _last_touch
	if gap >= IDLE_MIN and not _ended:
		write({"type": "idle", "seconds": snappedf(gap, 0.01), "step": _step_name(), "stage": stage()})


## The tutorial step on now by name ("" outside the guided run, or once it's done).
func _step_name() -> String:
	return Tutorial.Step.keys()[_step] if _step >= 0 else ""
