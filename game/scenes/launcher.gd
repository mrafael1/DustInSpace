class_name Launcher
extends Node2D
## The slingshot in the land zone. Pull the loaded pack back and release it to launch.
## The aim sets only where the pack bursts (RunState.launch clamps it into the sky); the pack's
## contents are rolled by the core. Then the pack flies, trembles and bursts as the events play.
## Owns no rules: which pack is loaded comes from pack_loaded / pack_bought / pack_launched events.
## Works in its own coordinates: the pack rests at (0, 0), which is where this node sits.

enum Flight { NONE, FLYING, TREMBLING }

## Aim feel, not balance. The weakest launch (MIN_PULL) reaches MIN_REACH px, just into the
## sky above the launcher; each further pixel of pull adds AIM_GAIN px. A full pull reaches
## 206 px, past the farthest sky corner (about 201 px away), so every corner and edge is aimable.
const MAX_PULL: int = 24
const AIM_GAIN: int = 9
const MIN_REACH: int = 26
## A shorter pull is a cancel: the pack snaps back.
const MIN_PULL: int = 4
## Press circle around the resting pack: 44 pt, like a star's (SkyView.HIT_RADIUS).
const HIT_RADIUS: int = SkyView.HIT_RADIUS
## Pull frames: the fork's gems light up in PULL_FRAMES steps as the pull grows.
const PULL_FRAMES: int = 4
## Timings from the game-feel skill.
const FLIGHT_TIME: float = 0.43
const TREMBLE_TIME: float = 0.28
const ARC_HEIGHT: int = 20
## Whole-pixel tremble, one step per TREMBLE_STEP.
const TREMBLE_SHAKE: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(0, -1)]
const TREMBLE_STEP: float = 0.04
## Burst ring radii, one per frame.
const BURST_RADII: Array[int] = [5, 9, 13]
const BURST_FRAME_TIME: float = 0.05
## Fork tips, where the bands attach and the star gems sit (the fork is about 30x36).
const FORK_TIPS: Array[Vector2i] = [Vector2i(-11, -4), Vector2i(11, -4)]

var _run: RunState
var _sequencer: EventSequencer
## The launcher's own view of the run, built from events so it never runs ahead of them.
var _loaded_kind: String = ""
var _owned: Dictionary[String, int] = {}
var _pulling: bool = false
## The pull as the finger reports it. The aim uses it unrounded: finger positions are finer than
## the 180x320 grid, and rounding first would snap the aim to AIM_GAIN px steps.
var _pull: Vector2 = Vector2.ZERO
var _flight: Flight = Flight.NONE
var _flight_time: float = 0.0
var _flight_to: Vector2i = Vector2i.ZERO
var _burst_time: float = -1.0
var _burst_at: Vector2i = Vector2i.ZERO

@onready var _rest_pack: PackView = $RestPack
@onready var _flying_pack: PackView = $FlyingPack


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if handle_pointer(make_input_local(event)):
		get_viewport().set_input_as_handled()


func _draw() -> void:
	_draw_fork()
	if _pulling and _pull.length() >= MIN_PULL:
		_draw_reticle(burst_preview() - origin())
	if _burst_time >= 0.0:
		_draw_burst_ring()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
			_sequencer.sequence_started.disconnect(cancel_pull)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
		_sequencer.sequence_started.connect(cancel_pull)
	_loaded_kind = run.loaded_pack
	_owned = run.owned_packs.duplicate()
	# A restart rebinds the sequencer, which drops a pending pack_burst: nothing else would
	# end a flight or burst ring from the old run.
	_end_flight()
	_burst_time = -1.0
	cancel_pull()
	_show_rest_pack()


## Where this node sits on the 180x320 grid.
func origin() -> Vector2i:
	return Vector2i(global_position.round())


## The pack in the fork, or "" when the fork is empty.
func shown_pack() -> String:
	return _rest_pack.kind if _rest_pack.visible else ""


func is_pulling() -> bool:
	return _pulling


## Where the pack would burst if released now (the same clamp the core applies).
func burst_preview() -> Vector2i:
	return StarScatter.clamp_to_sky(aim_target(origin(), _pull), _run.sky_rect)


## Feeds one touch or drag (in this node's coordinates). Returns true if it was used.
func handle_pointer(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		var touch := event as InputEventScreenTouch
		var point := Vector2i(touch.position.floor())
		if touch.canceled:
			return _end_pull(false)
		if touch.pressed:
			return _start_pull(point)
		return _end_pull(true)
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0 and _pulling:
		_pull = clamp_pull((event as InputEventScreenDrag).position)
		_rest_pack.position = Vector2(pull_pixel())
		queue_redraw()
		return true
	return false


## Drops a pull in progress; the pack snaps back. A sequence starting takes the input.
func cancel_pull() -> void:
	_pulling = false
	_pull = Vector2.ZERO
	if _rest_pack != null:
		_rest_pack.position = Vector2.ZERO
	queue_redraw()


## Moves the flight, tremble and burst ring forward. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _flight != Flight.NONE:
		_flight_time += delta
		_flying_pack.position = Vector2(flight_offset())
		_flying_pack.grown = _flight == Flight.TREMBLING and _flight_time >= TREMBLE_TIME * 0.5
		_flying_pack.bright = _flight == Flight.TREMBLING and _flight_time >= TREMBLE_TIME * 0.25
		if _flight == Flight.FLYING and _flight_time >= FLIGHT_TIME:
			_flight = Flight.TREMBLING
			_flight_time -= FLIGHT_TIME
	if _burst_time >= 0.0:
		_burst_time += delta
		if _burst_time >= BURST_RADII.size() * BURST_FRAME_TIME:
			_burst_time = -1.0
		queue_redraw()


## The flying pack's offset from the fork: an eased arc while flying, a whole-pixel shake after.
func flight_offset() -> Vector2i:
	if _flight == Flight.TREMBLING:
		return _flight_to + TREMBLE_SHAKE[int(_flight_time / TREMBLE_STEP) % TREMBLE_SHAKE.size()]
	var k: float = clampf(_flight_time / FLIGHT_TIME, 0.0, 1.0)
	var eased: float = 1.0 - (1.0 - k) * (1.0 - k)
	var point: Vector2 = Vector2.ZERO.lerp(Vector2(_flight_to), eased)
	return Vector2i(point.round()) + Vector2i(0, -roundi(sin(k * PI) * ARC_HEIGHT))


## Pull frame 0 (at rest) to PULL_FRAMES - 1 (full pull).
func pull_frame() -> int:
	if not _pulling:
		return 0
	return mini(int(_pull.length() / MAX_PULL * PULL_FRAMES), PULL_FRAMES - 1)


## Where the pulled pack is drawn: the pull on whole pixels.
func pull_pixel() -> Vector2i:
	return Vector2i(_pull.round())


## Clamps a finger offset to the pull circle.
static func clamp_pull(finger: Vector2) -> Vector2:
	return finger.limit_length(MAX_PULL)


## The aim: opposite the pull, MIN_REACH px at the shortest launch and AIM_GAIN px more per
## pixel pulled, on the grid. Not clamped into the sky; the core does that.
static func aim_target(launcher: Vector2i, pull: Vector2) -> Vector2i:
	var length: float = pull.length()
	if length < 0.001:
		return launcher
	var reach: float = MIN_REACH + (length - MIN_PULL) * AIM_GAIN
	return launcher - Vector2i((pull / length * reach).round())


func _start_pull(point: Vector2i) -> bool:
	if _run == null or _run.is_over() or _sequencer.is_busy() or shown_pack() == "":
		return false
	if point.length_squared() > HIT_RADIUS * HIT_RADIUS:
		return false
	_pulling = true
	_pull = Vector2.ZERO
	queue_redraw()
	return true


## Ends a pull; launches if `release` and the pull was long enough.
func _end_pull(release: bool) -> bool:
	if not _pulling:
		return false
	var pull: Vector2 = _pull
	cancel_pull()
	if release and pull.length() >= MIN_PULL:
		_run.launch(aim_target(origin(), pull))
	return true


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_bought":
			_owned[event.args[0]] = _owned.get(event.args[0], 0) + 1
			_show_rest_pack()
		&"pack_loaded":
			_loaded_kind = event.args[0]
			_show_rest_pack()
		&"pack_launched":
			_launch_view(event.args[0], event.args[1])
		&"pack_burst", &"big_bang_started":
			_burst_view(event.args[0] if event.type == &"big_bang_started" else event.args[1])


func _launch_view(kind: String, burst: Vector2i) -> void:
	_owned[kind] = _owned.get(kind, 0) - 1
	_rest_pack.visible = false
	_flying_pack.kind = kind
	_flying_pack.grown = false
	_flying_pack.bright = false
	_flying_pack.position = Vector2.ZERO
	_flying_pack.visible = true
	_flight = Flight.FLYING
	_flight_time = 0.0
	_flight_to = burst - origin()
	_sequencer.hold(FLIGHT_TIME + TREMBLE_TIME)


func _burst_view(burst: Vector2i) -> void:
	_end_flight()
	_burst_at = burst - origin()
	_burst_time = 0.0
	_show_rest_pack()
	queue_redraw()


func _end_flight() -> void:
	_flight = Flight.NONE
	_flight_time = 0.0
	_flying_pack.visible = false
	_flying_pack.grown = false
	_flying_pack.bright = false
	_flying_pack.position = Vector2.ZERO
	queue_redraw()


## The fork holds the loaded kind while one is owned and no pack is in the air.
func _show_rest_pack() -> void:
	if _rest_pack == null:
		return
	var shows: bool = _flight == Flight.NONE and _loaded_kind != "" and _owned.get(_loaded_kind, 0) > 0
	_rest_pack.kind = _loaded_kind if shows else ""
	_rest_pack.visible = shows


## Crescent fork on a stepped handle, bands from the tips to the pack, star gems on the tips.
## Only whole pixels: the bands are redrawn along their new line each frame, never stretched.
func _draw_fork() -> void:
	# Handle, down to the HUD line (y 284 on screen).
	draw_rect(Rect2(-1, 6, 3, 9), Palette.M3)
	draw_rect(Rect2(-1, 6, 1, 9), Palette.M4)
	# Fork arms: a crescent from the handle up to each tip.
	for side: int in [-1, 1]:
		var tip: Vector2i = FORK_TIPS[0 if side < 0 else 1]
		for p: Vector2i in LinkLayer.path_pixels([Vector2i(0, 6), Vector2i(side * 9, 3), tip] as Array[Vector2i]):
			draw_rect(Rect2(Vector2(p), Vector2(1, 2)), Palette.M4)
	# Bands to the pack.
	var pack: Vector2i = pull_pixel()
	if shown_pack() != "":
		for tip: Vector2i in FORK_TIPS:
			for p: Vector2i in LinkLayer.line_pixels(tip, pack):
				draw_rect(Rect2(Vector2(p), Vector2.ONE), Palette.M5)
	# Star gems: warm, because the slingshot is interactive; brighter as the pull grows.
	var gem: Color = [Palette.C3, Palette.C2, Palette.C1, Palette.C0][pull_frame()]
	for tip: Vector2i in FORK_TIPS:
		for d: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			draw_rect(Rect2(Vector2(tip + d), Vector2.ONE), gem if d == Vector2i.ZERO else Palette.C3)


## Four C1 corner ticks around the burst point.
func _draw_reticle(at: Vector2i) -> void:
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var c: Vector2i = at + corner * 4
		draw_rect(Rect2(Vector2(c), Vector2.ONE), Palette.C1)
		draw_rect(Rect2(Vector2(c - Vector2i(corner.x, 0)), Vector2.ONE), Palette.C1)
		draw_rect(Rect2(Vector2(c - Vector2i(0, corner.y)), Vector2.ONE), Palette.C1)
	draw_rect(Rect2(Vector2(at), Vector2.ONE), Palette.C0)


## A 1 px ring that grows frame by frame, dithered at 50%.
func _draw_burst_ring() -> void:
	var frame: int = mini(int(_burst_time / BURST_FRAME_TIME), BURST_RADII.size() - 1)
	var radius: int = BURST_RADII[frame]
	for dy: int in range(-radius - 1, radius + 2):
		for dx: int in range(-radius - 1, radius + 2):
			if roundi(sqrt(float(dx * dx + dy * dy))) == radius and posmod(dx + dy, 2) == 0:
				draw_rect(Rect2(Vector2(_burst_at + Vector2i(dx, dy)), Vector2.ONE), Palette.C1 if frame < 2 else Palette.C2)
