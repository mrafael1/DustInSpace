class_name TutorialView
extends Node2D
## The guided first run's guide (Tutorial), on the HUD layer: a line or two of text under the Sun,
## at the top of the sky, saying what to do, and a pointing hand at where to do it, bobbing BOB px every BOB_STEP. The hand
## points down at a spot in the sky, a star, a landmark, the dust counter, the telescope's window or a
## planet's icon, and points right at the Sun and the buy button. Free
## play shows its line for a moment, the hand on the COMBOS button. Owns no rules: the HUD tells it
## each step as it plays, with where to point. The links themselves are taught by the table (#94),
## which the HUD opens at the first link.
## While a link is taught, the hand goes from star to star in an order that stays in reach
## (follow_path), moving on as each is picked (follow); once one is picked the line says to follow
## the link hint (the stars that can come next shine). On the first link, which says either way
## works, the hand acts a drag out until a star is picked: it slides from star to star along the
## path, leaving a dotted trail.
## The goal waits for a tap and says TAP TO CONTINUE (N8) below; the showing steps (the payout's
## dust and Sun as it lands, where the loaded planet shows, the star a full Sun lit) point at it and
## go on by themselves after SHOW_TIME (timed_out; a tap goes on too). The HUD sends the tap and the
## time-out.

## A payout step (Tutorial.is_timed) has shown long enough: the HUD goes on.
signal timed_out

## Where the line sits (the HUD's message line; a second line goes above it, LINE_STEP up) and how
## long free play's line stays.
## The guide's top sits TOP px below the sky's top edge, under the Sun; the text comes first, then
## TAP TO CONTINUE.
const TOP: int = 6
const LINE_STEP: int = 11
const TAP_TEXT: String = "TAP TO CONTINUE"
## While a link is traced: the stars that can come next shine (the link hint).
const SHINE_TEXT: String = "FOLLOW THE SHINING STARS"
const DONE_TIME: float = 4.0
## How long a showing step points at what it shows before going on by itself.
const SHOW_TIME: float = 3.0
## The dragged link's demo: the hand takes DRAG_STEP to slide from one star to the next, rests
## DRAG_REST at each end, and leaves a trail with a dot every TRAIL_GAP px.
const DRAG_STEP: float = 0.6
const DRAG_REST: float = 0.5
const TRAIL_GAP: int = 3
## The near launch's zone (#148): a dotted ring (C1, the hand's colour) round the star, as far out as
## a launch may land, ZONE_DOTS dots. A refused launch flashes it C0 every ZONE_FLASH_STEP for
## ZONE_FLASH, and the line says REFUSED_TEXT for REFUSED_TIME.
const ZONE_DOTS: int = 28
const ZONE_FLASH: float = 0.48
const ZONE_FLASH_STEP: float = 0.08
const REFUSED_TEXT: String = "AIM INSIDE THE RING"
const REFUSED_TIME: float = 2.0
## Each step's line (the 5x7 font has letters, digits and + - / only: no punctuation).
const TEXTS: Dictionary = {
	Tutorial.Step.GOAL: "LIGHT EVERY STAR OF THE\nCONSTELLATION TO WIN",
	Tutorial.Step.LAUNCH: "TAP THE SKY TO LAUNCH\nA CHEAP BLUE PLANET",
	Tutorial.Step.LINK: "TAP OR DRAG THROUGH THEM",
	Tutorial.Step.DUST: "DUST BUYS PLANETS",
	Tutorial.Step.SUN: "LIGHT FILLS THE SUN",
	Tutorial.Step.LAUNCH_NEAR: "LAUNCH NEXT TO THIS STAR",
	Tutorial.Step.LIGHT: "LINK 3 OF THE SAME SIZE",
	Tutorial.Step.SCOPE: "THE TELESCOPE SHOWS\nTHE LOADED PLANET",
	Tutorial.Step.ICON: "THE LOADED PLANET SPINS",
	Tutorial.Step.RED: "LAUNCH THE RED PLANET\nIT SPLITS IN TWO\nWITH MORE BIG STARS",
	Tutorial.Step.RED_LINK: "LINK THEM TO FILL THE SUN",
	Tutorial.Step.SUN_FULL: "A FULL SUN LIGHTS A STAR",
	Tutorial.Step.BUY: "SPEND DUST ON A PLANET",
	Tutorial.Step.DONE: "LIGHT EVERY STAR TO WIN\nCOMBOS SHOWS EVERY LINK",
}
## The hand, pointing down, as rows (top to bottom): X outline (N0), C fill (C0), S shade (C1); its
## fingertip is the bottom pixel of column TIP_X. It stands GAP px off what it points at.
const HAND: Array[String] = [
	"..XXXXX..",
	".XCCCCCX.",
	"XCCCCCCSX",
	"XCCCCCCSX",
	"XCCCCCCSX",
	".XCCCCSX.",
	"..XCCSX..",
	"...XCX...",
	"...XCX...",
	"...XCX...",
	"...XSX...",
	"....X....",
]
const TIP_X: int = 4
const GAP: int = 10
## The bob: BOB px towards the target and back, a step every BOB_STEP.
const BOB: int = 2
const BOB_STEP: float = 0.35

enum Point { DOWN, RIGHT }

var _step: int = -1
var _target: Vector2i = Vector2i.ZERO
var _point: Point = Point.DOWN
var _has_target: bool = false
var _time: float = 0.0
var _label: Label
## The guide's top (the sky's top edge plus TOP) and how many lines its text takes.
var _top: int = 78 + TOP
var _lines: int = 1
var _tap: Label
## The link the hand teaches: the ids to pick in order and where it points for each.
var _path: Array[int] = []
var _path_points: Array[Vector2i] = []
## The path's star centres, where the dragged link's demo slides (empty: no demo).
var _demo: Array[Vector2i] = []
var _picked: int = 0
## Whether the payout step's time-out was sent already.
var _timed_out: bool = false
## Where the line's space starts (an encounter's line keeps clear of Orion's corner).
var _left: int = 0
## An encounter's own line (show_line), shown again once a link it guides is dropped.
var _line: String = ""
## The near launch's zone: its centre and radius (0: none), and seconds since a launch outside it
## was refused (-1: none).
var _zone_centre: Vector2i = Vector2i.ZERO
var _zone_radius: int = 0
var _refused_for: float = -1.0


func _ready() -> void:
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.label_settings = HudText.primary(Palette.C1)
	# Two lines sit LINE_STEP apart: the font's 7 px, its shadow and a gap.
	_label.label_settings.line_spacing = LINE_STEP - 7 - 2
	add_child(_label)
	_tap = Label.new()
	_tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap.label_settings = HudText.primary(Palette.N8)
	_tap.text = TAP_TEXT
	add_child(_tap)
	_tap.size = _tap.get_minimum_size()
	hide_guide()


func _process(delta: float) -> void:
	advance(delta)


## Shows step `step`: its line, the hand at `target` (pointing down, or right at a button) when
## `has_target`; the guide's top at `top` (the sky's top edge plus TOP).
func show_step(step: int, target: Vector2i = Vector2i.ZERO, has_target: bool = false, point: Point = Point.DOWN, top: int = 78 + TOP) -> void:
	_top = top
	_step = step
	_target = target
	_has_target = has_target
	_point = point
	_time = 0.0
	_path.clear()
	_path_points.clear()
	_demo.clear()
	_picked = 0
	_timed_out = false
	_left = 0
	_line = ""
	_zone_radius = 0
	_refused_for = -1.0
	_tap.visible = Tutorial.is_info(step) and not Tutorial.is_timed(step)
	_set_text(TEXTS.get(step, ""))
	visible = true
	queue_redraw()


## A line of its own, outside the guided run's steps, and the hand at `target` when `has_target`:
## an Orion encounter's guide (#93). The line is centred between `left` and the screen's right edge
## (clear of Orion's corner). Nothing waits for a tap; hide_guide ends it.
func show_line(line: String, target: Vector2i = Vector2i.ZERO, has_target: bool = false, point: Point = Point.DOWN, top: int = 78 + TOP, left: int = 0) -> void:
	show_step(-1, target, has_target, point, top)
	_left = left
	_line = line
	_set_text(line)


## Shows the zone a launch must land in: a dotted ring of `radius` round `centre`.
func show_zone(centre: Vector2i, radius: int) -> void:
	_zone_centre = centre
	_zone_radius = radius
	queue_redraw()


## A launch outside the zone was refused: the ring flashes and the line says to aim inside it, for a
## moment.
func refuse_launch() -> void:
	if _zone_radius <= 0 or not visible:
		return
	_refused_for = 0.0
	_set_text(REFUSED_TEXT)
	queue_redraw()


## The ring's dots: ZONE_DOTS whole pixels round the zone (none without one).
func zone_pixels() -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	if _zone_radius <= 0:
		return dots
	for i: int in ZONE_DOTS:
		var angle: float = i * TAU / ZONE_DOTS
		var dot: Vector2i = _zone_centre + Vector2i((Vector2(cos(angle), sin(angle)) * _zone_radius).round())
		if not dots.has(dot):
			dots.append(dot)
	return dots


## Whether the zone is flashing now (a refused launch, every other step).
func is_zone_flashing() -> bool:
	return _refused_for >= 0.0 and _refused_for < ZONE_FLASH and int(_refused_for / ZONE_FLASH_STEP) % 2 == 0


func hide_guide() -> void:
	_step = -1
	_has_target = false
	visible = false


func step() -> int:
	return _step


## Whether the step only explains something and waits for a tap.
func waits_for_tap() -> bool:
	return visible and _step >= 0 and Tutorial.is_info(_step)


## The link this step teaches: `ids` to pick in this order, the hand pointing at `points` (one each).
## Given `centres` (the stars' centres), the hand acts a drag out through them until a star is
## picked.
func follow_path(ids: Array[int], points: Array[Vector2i], centres: Array[Vector2i] = []) -> void:
	_path = ids.duplicate()
	_path_points = points.duplicate()
	_demo.clear()
	if centres.size() > 1:
		_demo = centres.duplicate()
	follow([])


## The link taught was made (its stars may be gone): the hand stops following it until the next step.
func drop_path() -> void:
	if _path.is_empty():
		return
	_path.clear()
	_path_points.clear()
	_demo.clear()
	_has_target = false
	queue_redraw()


## Whether the hand is acting out the drag now (a dragged link, nothing picked yet).
func is_demoing_drag() -> bool:
	return visible and not _demo.is_empty() and _picked == 0


## The link being traced now holds `selected`: the hand points at the first star of the path not in
## it, and once one is picked the line says the stars that can come next shine.
func follow(selected: Array[int]) -> void:
	if _path.is_empty() or not visible:
		return
	_picked = 0
	for k: int in _path.size():
		if selected.has(_path[k]):
			_picked += 1
	var next: int = -1
	for k: int in _path.size():
		if not selected.has(_path[k]):
			next = k
			break
	_has_target = next >= 0
	if next >= 0:
		_target = _path_points[next]
	_set_text(SHINE_TEXT if not selected.is_empty() else (_line if _step < 0 else TEXTS.get(_step, "")))
	queue_redraw()


## Where the hand points now (its target, before the bob and gap).
func target() -> Vector2i:
	return _target


func text() -> String:
	return _label.text if visible and _label.visible else ""


func shows_tap_hint() -> bool:
	return visible and _tap.visible


func has_hand() -> bool:
	return visible and _has_target


## Where the hand's fingertip is now (bobbing towards its target and back; sliding along the path
## while it acts out a drag).
func fingertip() -> Vector2i:
	if is_demoing_drag():
		return demo_point(_demo, _time)
	var bob: int = BOB * (int(_time / BOB_STEP) % 2)
	if _point == Point.RIGHT:
		return _target - Vector2i(GAP - bob, 0)
	return _target - Vector2i(0, GAP - bob)


## Where the drag's demo has the fingertip at `time`: resting on the first star, sliding from star
## to star (DRAG_STEP each), resting on the last, then again. Whole pixels.
static func demo_point(points: Array[Vector2i], time: float) -> Vector2i:
	var legs: int = points.size() - 1
	var t: float = fmod(time, DRAG_REST * 2.0 + DRAG_STEP * legs) - DRAG_REST
	if t <= 0.0:
		return points[0]
	var leg: int = int(t / DRAG_STEP)
	if leg >= legs:
		return points[legs]
	var along: Vector2 = Vector2(points[leg]).lerp(Vector2(points[leg + 1]), t / DRAG_STEP - leg)
	return Vector2i(along.round())


func advance(delta: float) -> void:
	if not visible:
		return
	var bob: int = int(_time / BOB_STEP) % 2
	_time += delta
	if _step == Tutorial.Step.DONE and _time >= DONE_TIME:
		hide_guide()
		return
	if _refused_for >= 0.0:
		_refused_for += delta
		queue_redraw()
		if _refused_for >= REFUSED_TIME:
			_refused_for = -1.0
			_set_text(TEXTS.get(_step, ""))
	if _step >= 0 and Tutorial.is_timed(_step) and _time >= SHOW_TIME and not _timed_out:
		_timed_out = true
		timed_out.emit()
	if is_demoing_drag() or int(_time / BOB_STEP) % 2 != bob:
		queue_redraw()


## The hand's pixels, with colours, for its fingertip at `tip` pointing `point`.
static func hand_pixels(tip: Vector2i, point: Point) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	var colours: Dictionary = {"X": Palette.N0, "C": Palette.C0, "S": Palette.C1}
	var bottom: int = HAND.size() - 1
	for row: int in HAND.size():
		for col: int in HAND[row].length():
			var c: String = HAND[row][col]
			if not colours.has(c):
				continue
			# Down: fingertip (TIP_X, bottom) at `tip`. Right: the same hand turned a quarter.
			var d := Vector2i(col - TIP_X, row - bottom)
			if point == Point.RIGHT:
				d = Vector2i(d.y, -d.x)
			dots[tip + d] = colours[c]
	return dots


func _draw() -> void:
	var zone: Color = Palette.C0 if is_zone_flashing() else Palette.C1
	for p: Vector2i in zone_pixels():
		draw_rect(Rect2(Vector2(p), Vector2.ONE), zone)
	if not _has_target:
		return
	if is_demoing_drag():
		_draw_trail()
	var dots: Dictionary[Vector2i, Color] = hand_pixels(fingertip(), _point)
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])


## The drag's demo leaves a dotted trail (C1) from the first star to the fingertip.
func _draw_trail() -> void:
	for p: Vector2i in trail_pixels(_demo, fingertip()):
		draw_rect(Rect2(Vector2(p), Vector2.ONE), Palette.C1)


## The dotted trail a drag's demo through `points` leaves behind its fingertip at `tip`: a dot every
## TRAIL_GAP px along the path, up to the fingertip. The idle hint's hand (HandDemo) shares it.
static func trail_pixels(points: Array[Vector2i], tip: Vector2i) -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	var count: int = 0
	for k: int in points.size() - 1:
		var on_leg: bool = _on_segment(tip, points[k], points[k + 1])
		for p: Vector2i in LinkLayer.line_pixels(points[k], points[k + 1]):
			if on_leg and (p - points[k]).length_squared() > (tip - points[k]).length_squared():
				return dots
			if count % TRAIL_GAP == 0:
				dots.append(p)
			count += 1
		if on_leg:
			return dots
	return dots


## Whether `p` lies on the leg from `a` to `b` (within a pixel).
static func _on_segment(p: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(p), Vector2(a), Vector2(b))
	return closest.distance_to(Vector2(p)) <= 1.0 and p != b


## The line(s) from the guide's top, LINE_STEP apart; TAP TO CONTINUE under them.
func _set_text(value: String) -> void:
	_label.text = value
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines = value.count("\n") + 1
	_label.size = Vector2(ScreenZones.SCREEN.x - _left, _label.get_minimum_size().y)
	_label.position = Vector2(_left, _top)
	_label.visible = true
	_tap.size = _tap.get_minimum_size()
	_tap.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(_tap.size.x / 2.0), _top + _lines * LINE_STEP)
