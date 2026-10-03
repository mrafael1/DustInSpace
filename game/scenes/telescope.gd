class_name Telescope
extends Launcher
## The telescope launcher (issue #52, a prototype next to the slingshot), in the HUD's row: it
## launches the loaded planet wherever the player points in the sky, no pull back.
## Loading shows the planet dropping into the mouth; then it's hidden inside and a window on the
## barrel shows its colour. A loaded telescope aims: at the start of a run, as soon as a planet
## seats (after a launch, or when one is picked in the HUD), and when its own loaded body is tapped.
## A reticle and a dotted sight line show where the pack will burst, and the barrel turns to it in
## DIRECTIONS steps. Touch the sky to show the aim, slide to adjust, lift to launch (a tap launches
## straight away); with a mouse, hovering aims and a click launches. Tap the telescope to stop
## aiming and link stars again: nothing is spent. While aiming, every touch is the telescope's:
## none reaches the stars. An empty telescope says so and never aims.
## Owns no rules: it calls the same RunState.launch as the slingshot, and the flight, tremble and
## burst are the Launcher's. Messages go out as text for the HUD to show (message_shown).
## The guided first run (Tutorial) holds the aim during the steps that don't launch, so touches reach
## the stars, and aims again when a launch step comes; a launch the run refuses keeps aiming.

## The telescope started aiming (feedback: sound).
signal aim_started
## Aiming ended without a launch: the player tapped the telescope again (feedback: sound).
signal aim_cancelled
## A planet dropped into the telescope and clicked into place (feedback: sound).
signal planet_seated(kind: String)
## The empty telescope was tapped: nothing to launch (feedback: sound).
signal empty_tapped
## Text for the HUD's message line, "" to clear it.
signal message_shown(text: String)
## The run refused a launch at the aim (the guided first run's near launch, too far): still aiming.
signal launch_refused

const EMPTY_MESSAGE: String = "LOAD A PLANET FIRST"
## The tube turns in this many whole-pixel direction frames around the pivot.
const DIRECTIONS: int = 16
## Where the barrel pivots on the tripod's head. The tripod never moves; only the barrel turns.
const PIVOT := Vector2i(0, -6)
## The barrel along its own axis (u, px from the pivot, + towards the mouth), half-widths across:
## a brass eyepiece behind, the 7 px barrel with two straps, then the wider lens hood.
const EYEPIECE_BACK: int = -11
const BARREL_BACK: int = -7
const HOOD_BACK: int = 15
const MOUTH: int = 18
const EYEPIECE_HALF: int = 1
const BARREL_HALF: int = 3
const HOOD_HALF: int = 4
const STRAPS: Array[int] = [-4, 9]
## The lens opening: the hood's last rows inside its rim, dark and hollow.
const LENS_DEPTH: int = 2
## The loaded planet's window on the barrel (u from..to, 3 px across): the pack's own colours, or
## dark neutral glass when the telescope is empty.
const WINDOW_FROM: int = 2
const WINDOW_TO: int = 6
## Loading: the planet drops along the barrel from LOAD_FROM px past the mouth to LOAD_TO px inside
## it (the barrel draws over it), in LOAD_TIME; then it's hidden and the window lights.
const LOAD_FROM: int = 14
const LOAD_TO: int = -8
const LOAD_TIME: float = 0.3
## The tripod's head (under the pivot) and its three legs; the middle one is behind.
const HEAD_TOP: int = -4
const HEAD_ROWS: int = 3
const LEGS: Array[Vector2i] = [Vector2i(-9, 10), Vector2i(9, 10)]
const BACK_LEG := Vector2i(0, 8)
## Press areas: around the tripod and along the barrel (REACH px either side of it).
const SCOPE_RADIUS: int = 13
const REACH: int = 3
## The sight line: one dot every SIGHT_STEP px, starting SIGHT_CLEAR px past the mouth and
## stopping SIGHT_GAP px short of the reticle.
const SIGHT_STEP: int = 4
const SIGHT_CLEAR: int = 4
const SIGHT_GAP: int = 8
## The burst preview: a dotted ring where the stars will scatter (StarScatter.RING_MIN).
const RING_RADIUS: int = StarScatter.RING_MIN
const RING_DOTS: int = 16
## The reticle's corner brackets sit this far from the burst point.
const RETICLE: int = 6

var _aiming: bool = false
## The burst point being aimed at (clamped into the sky), on the 180x320 grid.
var _aim: Vector2i = Vector2i.ZERO
var _has_aim: bool = false
## A touch that started on the telescope (a tap there aims or cancels), or in the sky while aiming.
var _scope_pressed: bool = false
var _sky_pressed: bool = false
## Aim once the events playing now have played and the planet has seated: a planet picked in
## the HUD, a launch (the next planet), or a sequence that interrupted the aim.
var _aim_requested: bool = false
## The guided first run holds the aim (a step that doesn't launch).
var _tutorial_hold: bool = false
## The mark's encounter (#93) shows a link to make: the telescope doesn't aim by itself meanwhile, so
## the sky takes the link; a tap on it still aims (the encounter only guides).
var _encounter_hold: bool = false
## The planet seated inside (its window shows), and the one dropping in: seconds into its load, or
## -1 when none is loading.
var _seated_kind: String = ""
var _load_time: float = -1.0


func _ready() -> void:
	# The planet drops in at the HUD's size, behind the barrel, which draws over it.
	_rest_pack.radius_override = PackView.HUD_RADIUS
	_rest_pack.bright = true
	_rest_pack.show_behind_parent = true
	_rest_pack.visible = false


func _draw() -> void:
	if _aiming:
		_draw_sight()
	_draw_telescope()
	if _aiming:
		_draw_burst_preview()
	if _burst_time >= 0.0:
		_draw_burst_ring()


## A run starts ready: its planet already seated, and aiming.
func setup(run: RunState, sequencer: EventSequencer) -> void:
	_aim_requested = false
	_tutorial_hold = false
	_encounter_hold = false
	_has_aim = false
	_seated_kind = ""
	_load_time = -1.0
	super.setup(run, sequencer)
	_seat(shown_pack(), false)
	message_shown.emit("")
	if can_process() and shown_pack() != "":
		start_aim()


## The planet in the telescope (seated or still dropping in), or "" when it's empty.
func shown_pack() -> String:
	return _rest_pack.kind if _rest_pack != null else ""


## The planet seated inside, whose window shows on the barrel ("" while one is still dropping in).
func seated_pack() -> String:
	return _seated_kind


func is_loading() -> bool:
	return _load_time >= 0.0


func is_aiming() -> bool:
	return _aiming


## The planet in the telescope, or "" when it's empty.
func loaded_pack() -> String:
	return shown_pack()


## Where the pack will burst: the aimed point, clamped into the sky like the core does.
func burst_preview() -> Vector2i:
	if not _has_aim:
		_aim = _sky_centre()
	return _aim


## The tube's direction frame, 0 (pointing up) to DIRECTIONS - 1, clockwise.
func direction_frame() -> int:
	if not _aiming and not _has_aim:
		return 0
	var to: Vector2 = Vector2(burst_preview() - origin() - PIVOT)
	var angle: float = atan2(to.x, -to.y)
	return posmod(roundi(angle / TAU * DIRECTIONS), DIRECTIONS)


## The tube's unit direction for its frame.
func direction() -> Vector2:
	var angle: float = direction_frame() * TAU / DIRECTIONS
	return Vector2(sin(angle), -cos(angle))


## The mouth of the barrel, the hood's rim (this node's coordinates).
func mouth() -> Vector2i:
	return PIVOT + Vector2i((direction() * MOUTH).round())


## The middle of the loaded planet's window on the barrel (this node's coordinates).
func window() -> Vector2i:
	return PIVOT + Vector2i((direction() * ((WINDOW_FROM + WINDOW_TO) / 2.0)).round())


## Where the dropping planet is: along the barrel's axis, from past the mouth to inside it.
func pack_position() -> Vector2i:
	var k: float = clampf(_load_time / LOAD_TIME, 0.0, 1.0) if is_loading() else 1.0
	var eased: float = k * k
	return PIVOT + Vector2i((direction() * lerpf(MOUTH + LOAD_FROM, MOUTH + LOAD_TO, eased)).round())


## Starts aiming if the telescope holds a planet; the empty one says so. Returns true if it aims.
## A sequence still playing (a purchase, a burst) holds it back until it ends.
func start_aim() -> bool:
	if _run == null or _run.is_over() or _tutorial_hold:
		return false
	if _sequencer.is_busy():
		_aim_requested = true
		return false
	if shown_pack() == "":
		empty_tapped.emit()
		message_shown.emit(EMPTY_MESSAGE)
		return false
	if _aiming:
		return true
	if is_loading():
		_aim_requested = true
		return false
	_aiming = true
	_pose()
	aim_started.emit()
	return true


## The HUD picked a planet: aim with it as soon as its load has played.
func request_aim() -> void:
	if not can_process() or _run == null or _run.is_over():
		return
	_aim_requested = true


## Stops aiming without launching (the player tapped the telescope again).
func cancel_aim() -> void:
	if not _aiming:
		return
	_stop_aim()
	aim_cancelled.emit()


## A sequence starting takes the input: drop the touch in progress and stop aiming until it ends
## (then aim again, like a planet the HUD just picked).
func cancel_pull() -> void:
	super.cancel_pull()
	_scope_pressed = false
	_sky_pressed = false
	if _aiming:
		_stop_aim()
		_aim_requested = true
	_pose()


## Points at a spot on the 180x320 grid (clamped into the sky), as the finger or mouse moves.
func aim_at(point: Vector2i) -> void:
	_aim = StarScatter.clamp_to_sky(point, _run.sky_rect)
	_has_aim = true
	_pose()


func advance(delta: float) -> void:
	super.advance(delta)
	if is_loading():
		_load_time += delta
		if _load_time >= LOAD_TIME:
			_seat(shown_pack(), true)
	if _aim_requested and not _encounter_hold and _sequencer != null and not _sequencer.is_busy() and not is_loading():
		_aim_requested = false
		if shown_pack() != "":
			start_aim()
	_pose()


## Feeds one touch, drag or mouse move (in this node's coordinates). Returns true if it was used.
func handle_pointer(event: InputEvent) -> bool:
	if _run == null or _run.is_over():
		return false
	if event is InputEventMouseMotion:
		if not _aiming:
			return false
		if not _scope_pressed:
			aim_at(origin() + Vector2i((event as InputEventMouseMotion).position.floor()))
		return true
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0:
		if _sky_pressed:
			aim_at(origin() + Vector2i((event as InputEventScreenDrag).position.floor()))
		return _aiming or _scope_pressed
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		return _on_touch(event as InputEventScreenTouch)
	# Other fingers: while aiming, nothing else in the sky may take them.
	return _aiming and (event is InputEventScreenTouch or event is InputEventScreenDrag)


func _on_touch(touch: InputEventScreenTouch) -> bool:
	var point := Vector2i(touch.position.floor())
	if touch.canceled:
		var had: bool = _scope_pressed or _sky_pressed
		_scope_pressed = false
		_sky_pressed = false
		return had or _aiming
	if touch.pressed:
		if on_scope(point):
			_scope_pressed = true
			return true
		if not _aiming:
			return false
		_sky_pressed = true
		aim_at(origin() + point)
		return true
	if _scope_pressed:
		_scope_pressed = false
		if not on_scope(point):
			return true
		if _aiming:
			cancel_aim()
		else:
			start_aim()
		return true
	if _sky_pressed:
		_sky_pressed = false
		aim_at(origin() + point)
		_fire()
		return true
	return _aiming


## True if `point` (this node's coordinates) presses the telescope: its tripod or its barrel.
func on_scope(point: Vector2i) -> bool:
	if (point - PIVOT).length_squared() <= SCOPE_RADIUS * SCOPE_RADIUS:
		return true
	var uv: Vector2i = _barrel_uv(point)
	return uv.x >= EYEPIECE_BACK - REACH and uv.x <= MOUTH + REACH and absi(uv.y) <= HOOD_HALF + REACH


## Launches exactly one pack at the aim. The next planet, if one loads, is aimed as it seats.
func _fire() -> void:
	var target: Vector2i = burst_preview()
	_stop_aim()
	if _run.launch(target):
		_aim_requested = true
	else:
		launch_refused.emit()
		start_aim()


## The shown planet changed with the events: a new one drops in (a launch emptied the telescope, or
## the HUD loaded another kind), or the telescope is empty.
func _show_rest_pack() -> void:
	super._show_rest_pack()
	if _rest_pack == null:
		return
	var kind: String = _rest_pack.kind
	if kind == "":
		_seat("", false)
	elif kind != _seated_kind and not is_loading():
		_seated_kind = ""
		_load_time = 0.0
	_rest_pack.visible = is_loading()
	_pose()


## The planet leaves through the mouth: the telescope is empty until the next one drops in.
func _launch_view(kind: String, burst: Vector2i) -> void:
	super._launch_view(kind, burst)
	_rest_pack.kind = ""
	_seat("", false)


## A pack_loaded event keeps the sequence going while the planet drops in. A tutorial step holds
## the aim or lets it go.
func _on_event_played(event: EventSequencer.RunEvent) -> void:
	super._on_event_played(event)
	if event.type == &"tutorial_step":
		_tutorial_hold = not Tutorial.aims(event.args[0])
		if _tutorial_hold:
			_aim_requested = false
			if _aiming:
				_stop_aim()
		elif can_process():
			_aim_requested = true
	if event.type == &"encounter_step" and event.args[0] == Encounter.Threat.MARK:
		hold_for_encounter(event.args[1] == Encounter.Step.GUIDING)
	if event.type == &"pack_loaded" and can_process() and is_loading():
		_sequencer.hold(LOAD_TIME)


## The mark's encounter guides a link (`on`): stop aiming and don't aim again by itself, so the
## player's touch picks stars; once it's done, aim again as usual.
func hold_for_encounter(on: bool) -> void:
	if on == _encounter_hold:
		return
	_encounter_hold = on
	if on:
		if _aiming:
			_stop_aim()
			_aim_requested = true
	elif can_process():
		_aim_requested = true


func is_held_for_encounter() -> bool:
	return _encounter_hold


## Seats `kind` inside: the dropping planet hides and the window shows it. `click` for feedback.
func _seat(kind: String, click: bool) -> void:
	_load_time = -1.0
	_seated_kind = kind
	if _rest_pack != null:
		_rest_pack.visible = false
	if click and kind != "":
		planet_seated.emit(kind)
	queue_redraw()


func _stop_aim() -> void:
	_aiming = false
	_scope_pressed = false
	_sky_pressed = false
	message_shown.emit("")
	_pose()


func _sky_centre() -> Vector2i:
	if _run == null:
		return origin() + Vector2i(0, -100)
	return StarScatter.clamp_to_sky(_run.sky_rect.get_center(), _run.sky_rect)


## The flight starts at the mouth.
func _flight_from() -> Vector2i:
	return mouth()


## The dropping planet follows the barrel's current frame.
func _pose() -> void:
	if _rest_pack != null:
		_rest_pack.position = Vector2(pack_position())
	queue_redraw()


## The fixed tripod, then the barrel in its direction frame, then the pivot joint over it.
## Whole pixels only: each frame's barrel is filled pixel by pixel from its axis, never rotated.
func _draw_telescope() -> void:
	_draw_tripod()
	_draw_barrel()
	_draw_joint()


## Three legs (M4, the back one M3) from a stepped head under the pivot, M5 feet. Never moves.
func _draw_tripod() -> void:
	var foot_of_head: int = HEAD_TOP + HEAD_ROWS - 1
	for p: Vector2i in LinkLayer.line_pixels(Vector2i(0, foot_of_head), BACK_LEG):
		_dot(p, Palette.M3)
	for leg: Vector2i in LEGS:
		for p: Vector2i in LinkLayer.line_pixels(Vector2i(signi(leg.x) * 2, foot_of_head), leg):
			_dot(p, Palette.M4)
		draw_rect(Rect2(Vector2(leg - Vector2i(1 if leg.x > 0 else 0, 0)), Vector2(2, 1)), Palette.M5)
	for row: int in HEAD_ROWS:
		var half: int = 3 - row / 2
		draw_rect(Rect2(-half, HEAD_TOP + row, 2 * half + 1, 1), Palette.M4 if row == 0 else Palette.M3)


## The barrel, lit from the top-left: M5 on its lit edge, M3 on its shadow edge, M4 between, M5
## straps. A brass eyepiece (C3) behind; the lens hood in front, warm because it's the interactive
## end (C2 rim, C1 lip; C1 and C0 while aiming). The opening inside the rim is dark and hollow.
## A seated planet shows through a window on the barrel, in its own colours.
func _draw_barrel() -> void:
	var loaded: String = _seated_kind
	var reach: int = MOUTH + HOOD_HALF + 1
	for y: int in range(PIVOT.y - reach, PIVOT.y + reach + 1):
		for x: int in range(-reach, reach + 1):
			var p := Vector2i(x, y)
			var uv: Vector2i = _barrel_uv(p)
			var colour: Variant = _barrel_colour(uv.x, uv.y * _lit_side(), loaded)
			if colour != null:
				_dot(p, colour)


## The colour of the barrel at (u, v), v counted towards the light (+ is the lit edge), or null.
## `loaded` is the seated planet's kind, "" for none.
func _barrel_colour(u: int, v: int, loaded: String) -> Variant:
	if u < EYEPIECE_BACK or u > MOUTH:
		return null
	if u < BARREL_BACK:
		if absi(v) > EYEPIECE_HALF:
			return null
		return Palette.C2 if v == EYEPIECE_HALF else Palette.C3
	if u < HOOD_BACK:
		if absi(v) > BARREL_HALF:
			return null
		if u >= WINDOW_FROM and u <= WINDOW_TO and absi(v) <= 1:
			if loaded == "":
				return Palette.M3 if v == 1 and u > WINDOW_FROM and u < WINDOW_TO else Palette.M1
			var ramp: Array[Color] = Palette.RED_PACK if loaded == "red" else Palette.BLUE_PACK
			return ramp[3 + v] if u > WINDOW_FROM and u < WINDOW_TO else ramp[1]
		if v == BARREL_HALF or STRAPS.has(u):
			return Palette.M5
		return Palette.M3 if v == -BARREL_HALF else Palette.M4
	if absi(v) > HOOD_HALF:
		return null
	if u > MOUTH - LENS_DEPTH and absi(v) < HOOD_HALF:
		return Palette.M5 if v == 1 and u == MOUTH else Palette.N0
	if u == MOUTH:
		return Palette.C0 if _aiming else Palette.C1
	return Palette.C1 if _aiming else Palette.C2


## The pivot joint: a round M1 hub with an M5 cap and a brass (C3) bolt, over the barrel.
func _draw_joint() -> void:
	for p: Vector2i in [Vector2i(-1, -2), Vector2i(0, -2), Vector2i(1, -2), Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-2, 1), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(0, 2), Vector2i(1, 2)]:
		_dot(PIVOT + p, Palette.M1)
	for p: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		_dot(PIVOT + p, Palette.M5)
	_dot(PIVOT, Palette.C3)


## A point's place on the barrel: u along its axis from the pivot, v across it, on whole pixels.
func _barrel_uv(point: Vector2i) -> Vector2i:
	var dir: Vector2 = direction()
	var rel := Vector2(point - PIVOT)
	return Vector2i(roundi(rel.dot(dir)), roundi(rel.dot(Vector2(-dir.y, dir.x))))


## Which way across the barrel faces the top-left light: +1 or -1 for v.
func _lit_side() -> int:
	var dir: Vector2 = direction()
	return 1 if Vector2(-dir.y, dir.x).dot(Vector2(-1, -1)) >= 0.0 else -1


## A dotted C2 sight line from just past the mouth to the reticle.
func _draw_sight() -> void:
	var line: Array[Vector2i] = LinkLayer.line_pixels(mouth(), burst_preview() - origin())
	for i: int in range(SIGHT_CLEAR, line.size() - SIGHT_GAP, SIGHT_STEP):
		_dot(line[i], Palette.C2)


## The reticle at the burst point and a dotted ring where the stars will scatter: one ring per
## burst point for a pack that splits (the red pack's twin burst), each with a small C2 core.
func _draw_burst_preview() -> void:
	var at: Vector2i = burst_preview() - origin()
	var points: Array[Vector2i] = burst_points()
	for point: Vector2i in points:
		var centre: Vector2i = point - origin()
		for i: int in RING_DOTS:
			var angle: float = i * TAU / RING_DOTS
			_dot(centre + Vector2i((Vector2(cos(angle), sin(angle) * StarScatter.RING_SQUASH) * RING_RADIUS).round()), Palette.M5)
		if points.size() > 1:
			_dot(centre, Palette.C2)
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var c: Vector2i = at + corner * RETICLE
		for i: int in 3:
			_dot(c - Vector2i(corner.x * i, 0), Palette.C1)
			_dot(c - Vector2i(0, corner.y * i), Palette.C1)
	draw_rect(Rect2(Vector2(at - Vector2i.ONE), Vector2(3, 3)), Palette.C2)
	_dot(at, Palette.C0)


func _dot(p: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), color)
