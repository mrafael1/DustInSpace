class_name PlaytestLog
extends Node
## Playtest logging (#89, debug builds only): where testers stall, what they try that gets refused,
## and whether they read before moving on. Each record is one JSON object a line, appended to one
## file a session (`user://playtest/<timestamp>.jsonl`, shared by every run and stage in it):
## - run_started: the stage, whether it's the guided run (`guided`, set by Main), and the platform.
## - step_entered / step_left: a tutorial step and, on leaving, the seconds spent on it (free play,
##   Tutorial.Step.DONE, isn't one).
## - refusal: a refused action's kind (launch, link, buy, load), on which step and stage.
## - idle: a gap of at least IDLE_MIN seconds without any interaction, on which step: it starts
##   when the last finger lifts (holding, dragging and aiming are interaction) and is logged at the
##   touch that ends it, or when the run ends.
## - link: a collected link's combo, stars, dust and light, on which stage.
## - run_ended: the stage, won, lost or left (a restart, or back to the chart), packs launched, the
##   run's seconds, links collected, stars linked, links rejected, Big Bangs and dust earned.
## Every record has the run's time (`t`) and the session's random id (`session`), so records from
## many players can be told apart.
## Presentation-side: it only listens to RunState's signals and the views' feedback signals (Main
## wires them), and adds no rules. Release builds and headless runs write no file (`enabled`).
## Web playtest: each record is also sent to the endpoint in game/config/analytics.json, in any
## build (AnalyticsUpload; `upload`), so a web build's records reach the developer. No endpoint, no
## sending; headless runs never send.

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
## Sends one record (its JSON) somewhere, or empty for nowhere. Tests replace it.
var upload: Callable = AnalyticsUpload.sender(AnalyticsUpload.endpoint())

## The session's file, shared by every PlaytestLog in the process (App makes a Main per stage).
static var _session_file: String = ""
## The session's random id, shared the same way: it tells one player's records from another's.
static var _session_id: String = ""

var _run: RunState
## Seconds since the run started, counted in `advance`.
var _time: float = 0.0
var _last_touch: float = 0.0
## Fingers down now: no gap runs while one is.
var _fingers: int = 0
var _step: int = -1
var _step_since: float = 0.0
var _launches: int = 0
var _links: int = 0
var _stars_linked: int = 0
var _rejected: int = 0
var _big_bangs: int = 0
var _dust_earned: int = 0
var _ended: bool = false


func _process(delta: float) -> void:
	advance(delta)


## Each run is a fresh RunState: the last one's connections go with it.
func setup(run: RunState, _sequencer: EventSequencer) -> void:
	_end("left")
	_run = run
	_time = 0.0
	_last_touch = 0.0
	_fingers = 0
	_step = -1
	_step_since = 0.0
	_launches = 0
	_links = 0
	_stars_linked = 0
	_rejected = 0
	_big_bangs = 0
	_dust_earned = 0
	_ended = false
	_run.tutorial_step.connect(_on_tutorial_step)
	_run.pack_launched.connect(_on_pack_launched)
	_run.combo_collected.connect(_on_combo_collected)
	_run.link_rejected.connect(_on_link_rejected)
	_run.big_bang_started.connect(_on_big_bang_started)
	_run.run_won.connect(_on_run_won)
	_run.run_lost.connect(_on_run_lost)
	write({"type": "run_started", "stage": stage(), "tutorial": guided, "platform": platform()})


func _exit_tree() -> void:
	_end("left")


func advance(delta: float) -> void:
	_time += delta


## The stage being played: its star map's id, or "sun" for the plain Sun stage.
func stage() -> String:
	if _run == null:
		return ""
	return _run.scorpio.map.id if _run.scorpio != null else "sun"


## Where the game runs: the OS, and for a web build which browser OS ("web_android", "web_ios"…).
static func platform() -> String:
	for feature: String in ["web_android", "web_ios", "web_windows", "web_macos", "web_linuxbsd"]:
		if OS.has_feature(feature):
			return feature
	return OS.get_name().to_lower()


## A touch began (IdleHint sees every one first): a long enough gap since the last interaction
## ended is an idle record.
func touched() -> void:
	_log_idle()
	_fingers += 1
	_last_touch = _time


## A finger lifted: if it was the last, the next gap starts now.
func released() -> void:
	_fingers = maxi(_fingers - 1, 0)
	_last_touch = _time


## A finger moved: still interacting.
func dragged() -> void:
	_last_touch = _time


## A refused action, by kind: "launch", "link", "buy" or "load".
func refused(kind: String) -> void:
	if _run == null or _ended:
		return
	write({"type": "refusal", "kind": kind, "step": _step_name(), "stage": stage()})


## The HUD refused a planet tap: its icon loads (a load), its button buys (a buy).
func pack_tap_refused(_kind: String, part: StringName) -> void:
	refused("load" if part == &"icon" else "buy")


## Appends `record` (with the run's time and the session's id) to the session's file and sends it
## (`upload`). Returns whether it was written or sent.
func write(record: Dictionary) -> bool:
	if not enabled and not upload.is_valid():
		return false
	var line: Dictionary = {"t": snappedf(_time, 0.01), "session": session_id()}
	line.merge(record)
	var text: String = JSON.stringify(line)
	if upload.is_valid():
		upload.call(text)
	return _append(text) or upload.is_valid()


## The session's random id (12 hex digits), made on first use.
static func session_id() -> String:
	if _session_id == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_session_id = "%06x%06x" % [rng.randi() & 0xffffff, rng.randi() & 0xffffff]
	return _session_id


## The file this session writes to ("" until the first record).
static func session_file() -> String:
	return _session_file


## Starts a new session file (and id) on the next record (tests).
static func new_session() -> void:
	_session_file = ""
	_session_id = ""


func _append(text: String) -> bool:
	if not enabled:
		return false
	if _session_file == "" or not _session_file.begins_with(log_dir + "/"):
		DirAccess.make_dir_recursive_absolute(log_dir)
		_session_file = "%s/%s.jsonl" % [log_dir, Time.get_datetime_string_from_system().replace(":", "-")]
	var file: FileAccess = FileAccess.open(_session_file, FileAccess.READ_WRITE if FileAccess.file_exists(_session_file) else FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(text)
	file.close()
	return true


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


func _on_combo_collected(combo: String, stars: Array[Star], dust: int, light: int) -> void:
	_links += 1
	_stars_linked += stars.size()
	_dust_earned += dust
	write({"type": "link", "combo": combo, "stars": stars.size(), "dust": dust, "light": light, "stage": stage()})


func _on_link_rejected(_ids: Array[int]) -> void:
	_rejected += 1
	refused("link")


func _on_big_bang_started(_at: Vector2i, _cleared: Array[Star], dust: int) -> void:
	_big_bangs += 1
	_dust_earned += dust


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
	write({
		"type": "run_ended", "stage": stage(), "outcome": outcome, "packs_used": _launches,
		"seconds": snappedf(_time, 0.01), "links": _links, "stars_linked": _stars_linked,
		"links_rejected": _rejected, "big_bangs": _big_bangs, "dust_earned": _dust_earned,
	})


func _leave_step() -> void:
	if _step < 0:
		return
	write({"type": "step_left", "step": _step_name(), "seconds": snappedf(_time - _step_since, 0.01)})
	_step = -1


func _log_idle() -> void:
	var gap: float = _time - _last_touch
	if gap >= IDLE_MIN and _fingers == 0 and not _ended:
		write({"type": "idle", "seconds": snappedf(gap, 0.01), "step": _step_name(), "stage": stage()})


## The tutorial step on now by name ("" outside the guided run, or once it's done).
func _step_name() -> String:
	return Tutorial.Step.keys()[_step] if _step >= 0 else ""
