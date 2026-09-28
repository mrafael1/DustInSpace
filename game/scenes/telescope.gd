class_name Telescope
extends Launcher
## The telescope launcher (issue #52, a prototype next to the slingshot): it holds the loaded
## planet at its mouth and launches it wherever the player points in the sky, no pull back.
## Tap the telescope (or pick a planet in the HUD) to aim: a reticle and a dotted sight line show
## where the pack will burst, and the tube turns to it in DIRECTIONS steps. Touch the sky to show
## the aim, slide to adjust, lift to launch (a tap launches straight away); with a mouse, hovering
## aims and a click launches. Tap the telescope again to cancel. While aiming, every touch is the
## telescope's: none reaches the stars. An empty telescope says so and never aims.
## Owns no rules: it calls the same RunState.launch as the slingshot, and the flight, tremble and
## burst are the Launcher's. Messages go out as text for the HUD to show (message_shown).

## The telescope started aiming (feedback: sound).
signal aim_started
## Aiming ended without a launch: the player tapped the telescope again (feedback: sound).
signal aim_cancelled
## The empty telescope was tapped: nothing to launch (feedback: sound).
signal empty_tapped
## Text for the HUD's message line, "" to clear it.
signal message_shown(text: String)

const EMPTY_MESSAGE: String = "LOAD A PLANET FIRST"
const AIM_MESSAGE: String = "TAP THE SKY TO LAUNCH"
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
## The lens opening: the hood's last rows inside its rim. Dark and hollow when empty; the
## loaded planet shows through it, seated SEAT px deep behind the hood.
const LENS_DEPTH: int = 2
const SEAT: int = 4
## The tripod's head (under the pivot) and its three legs; the middle one is behind.
const HEAD_TOP: int = -4
const HEAD_ROWS: int = 3
const LEGS: Array[Vector2i] = [Vector2i(-9, 10), Vector2i(9, 10)]
const BACK_LEG := Vector2i(0, 8)
## Press areas: around the tripod, along the barrel, and around the planet at the mouth.
const SCOPE_RADIUS: int = 13
const PACK_REACH: int = 3
## The sight line: one dot every SIGHT_STEP px from the mouth, stopping short of the reticle.
const SIGHT_STEP: int = 4
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
## The HUD picked a planet: aim once its events have played.
var _aim_requested: bool = false


func _ready() -> void:
	# The loaded planet sits at the HUD's size, seated in the mouth: the barrel draws over it.
	_rest_pack.radius_override = PackView.HUD_RADIUS
	_rest_pack.bright = true
	_rest_pack.show_behind_parent = true


func _draw() -> void:
	if _aiming:
		_draw_sight()
	_draw_telescope()
	if _aiming:
		_draw_burst_preview()
	if _burst_time >= 0.0:
		_draw_burst_ring()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_aim_requested = false
	_has_aim = false
	super.setup(run, sequencer)


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


## Where the loaded planet sits: seated SEAT px into the mouth, the rest of it out in front.
func pack_position() -> Vector2i:
	return PIVOT + Vector2i((direction() * (MOUTH + PackView.HUD_RADIUS + 1 - SEAT)).round())


## Starts aiming if the telescope holds a planet; the empty one says so. Returns true if it aims.
## A sequence still playing (a purchase, a burst) holds it back until it ends.
func start_aim() -> bool:
	if _run == null or _run.is_over():
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
	_aiming = true
	_pose()
	aim_started.emit()
	message_shown.emit(AIM_MESSAGE)
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


## A sequence starting takes the input: drop the touch in progress and stop aiming. A planet
## the HUD just picked still gets aimed once the sequence ends.
func cancel_pull() -> void:
	super.cancel_pull()
	_scope_pressed = false
	_sky_pressed = false
	if _aiming:
		_stop_aim()
	_pose()


## Points at a spot on the 180x320 grid (clamped into the sky), as the finger or mouse moves.
func aim_at(point: Vector2i) -> void:
	_aim = StarScatter.clamp_to_sky(point, _run.sky_rect)
	_has_aim = true
	_pose()


func advance(delta: float) -> void:
	super.advance(delta)
	if _aim_requested and _sequencer != null and not _sequencer.is_busy():
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


## True if `point` (this node's coordinates) presses the telescope or the planet at its mouth.
func on_scope(point: Vector2i) -> bool:
	if (point - PIVOT).length_squared() <= SCOPE_RADIUS * SCOPE_RADIUS:
		return true
	var uv: Vector2i = _barrel_uv(point)
	if uv.x >= EYEPIECE_BACK and uv.x <= MOUTH and absi(uv.y) <= HOOD_HALF + PACK_REACH:
		return true
	var reach: int = PackView.HUD_RADIUS + PACK_REACH
	return shown_pack() != "" and (point - pack_position()).length_squared() <= reach * reach


## Launches exactly one pack at the aim and stops aiming.
func _fire() -> void:
	var target: Vector2i = burst_preview()
	_stop_aim()
	_run.launch(target)


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


## The flight starts where the planet sits, at the mouth.
func _flight_from() -> Vector2i:
	return pack_position()


## The planet sits at the mouth for the tube's current frame.
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
## end (C2 rim, C1 lip; C1 and C0 while aiming). The opening inside the rim is dark and hollow
## when empty; when loaded it's left open, so the planet seated behind it shows through.
func _draw_barrel() -> void:
	var loaded: bool = shown_pack() != ""
	var reach: int = MOUTH + HOOD_HALF + 1
	for y: int in range(PIVOT.y - reach, PIVOT.y + reach + 1):
		for x: int in range(-reach, reach + 1):
			var p := Vector2i(x, y)
			var uv: Vector2i = _barrel_uv(p)
			var colour: Variant = _barrel_colour(uv.x, uv.y * _lit_side(), loaded)
			if colour != null:
				_dot(p, colour)


## The colour of the barrel at (u, v), v counted towards the light (+ is the lit edge), or null.
func _barrel_colour(u: int, v: int, loaded: bool) -> Variant:
	if u < EYEPIECE_BACK or u > MOUTH:
		return null
	if u < BARREL_BACK:
		if absi(v) > EYEPIECE_HALF:
			return null
		return Palette.C2 if v == EYEPIECE_HALF else Palette.C3
	if u < HOOD_BACK:
		if absi(v) > BARREL_HALF:
			return null
		if v == BARREL_HALF or STRAPS.has(u):
			return Palette.M5
		return Palette.M3 if v == -BARREL_HALF else Palette.M4
	if absi(v) > HOOD_HALF:
		return null
	if u > MOUTH - LENS_DEPTH and absi(v) < HOOD_HALF:
		if loaded:
			return null
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


## A dotted C2 sight line from the planet to the reticle.
func _draw_sight() -> void:
	var from: Vector2i = pack_position()
	var to: Vector2i = burst_preview() - origin()
	var line: Array[Vector2i] = LinkLayer.line_pixels(from, to)
	for i: int in range(SIGHT_STEP, line.size() - SIGHT_GAP, SIGHT_STEP):
		_dot(line[i], Palette.C2)


## The reticle at the burst point and a dotted ring where the stars will scatter.
func _draw_burst_preview() -> void:
	var at: Vector2i = burst_preview() - origin()
	for i: int in RING_DOTS:
		var angle: float = i * TAU / RING_DOTS
		_dot(at + Vector2i((Vector2(cos(angle), sin(angle) * StarScatter.RING_SQUASH) * RING_RADIUS).round()), Palette.M5)
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var c: Vector2i = at + corner * RETICLE
		for i: int in 3:
			_dot(c - Vector2i(corner.x * i, 0), Palette.C1)
			_dot(c - Vector2i(0, corner.y * i), Palette.C1)
	draw_rect(Rect2(Vector2(at - Vector2i.ONE), Vector2(3, 3)), Palette.C2)
	_dot(at, Palette.C0)


func _dot(p: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), color)
