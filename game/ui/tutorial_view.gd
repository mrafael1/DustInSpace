class_name TutorialView
extends Node2D
## The guided first run's guide (Tutorial), on the HUD layer: a line or two of text under the Sun,
## at the top of the sky, saying what to do, and a pointing hand at where to do it, bobbing BOB px every BOB_STEP. The hand
## points down at a spot in the sky, a star, a landmark or a planet, and points right at the buy button. Free
## play shows its line for a moment and no hand. Owns no rules: the HUD tells it each step as it
## plays, with where to point.
## The linking steps teach the two combos with a card at the top of the sky, drawn with the sky
## stars' own art: one of each size (small + medium + big) as the first link is made, three of the
## same size as the constellation star is lit, and both, with OR between them, as free play starts.
## The card is a plaque (N0 fill, N6 border, clipped corners) with the stars spaced in a row: no sign
## between them (a plus read as one more small star, which is plus-shaped).
## While a link is taught, the hand goes from star to star in an order that stays in reach
## (follow_path), moving on as each is picked (follow); once one is picked the line says to follow
## the link hint (the stars that can come next shine). Where the link is dragged, the hand acts it
## out until a star is picked: it slides from star to star along the path, leaving a dotted trail.
## The goal waits for a tap and says TAP TO CONTINUE (N8) below; the payout's steps (the dust, the
## Sun) point at it as it lands and go on by themselves after SHOW_TIME (timed_out; a tap goes on
## too). The HUD sends the tap and the time-out. Once free play is on, the first full Sun points at
## the star it lit (show_sun_full).

## A payout step (Tutorial.is_timed) has shown long enough: the HUD goes on.
signal timed_out

## Where the line sits (the HUD's message line; a second line goes above it, LINE_STEP up) and how
## long free play's line stays.
## The guide's top sits TOP px below the sky's top edge, under the Sun; the text comes first, then
## TAP TO CONTINUE, then the combo card, CARD_GAP px below.
const TOP: int = 6
const CARD_GAP: int = 4
const LINE_STEP: int = 11
const TAP_TEXT: String = "TAP TO CONTINUE"
## While a link is traced: the stars that can come next shine (the link hint).
const SHINE_TEXT: String = "FOLLOW THE SHINING STARS"
const DONE_TIME: float = 4.0
## How long the payout's steps point at the dust and the Sun before going on by themselves.
const SHOW_TIME: float = 2.0
## The first full Sun in free play: its line, shown this long with the hand on the star it lit.
const SUN_FULL_TEXT: String = "A FULL SUN LIGHTS A STAR"
const SUN_FULL_TIME: float = 3.0
## The dragged link's demo: the hand takes DRAG_STEP to slide from one star to the next, rests
## DRAG_REST at each end, and leaves a trail with a dot every TRAIL_GAP px.
const DRAG_STEP: float = 0.6
const DRAG_REST: float = 0.5
const TRAIL_GAP: int = 3
## The combo card: CARD_PAD px inside its border, STAR_GAP px between two stars, OR_GAP px either
## side of the OR between two combos.
const CARD_PAD: int = 4
const STAR_GAP: int = 5
const OR_GAP: int = 5
const OR_TEXT: String = "OR"
## Each step's line (the 5x7 font has letters, digits and + - / only: no punctuation).
const TEXTS: Dictionary = {
	Tutorial.Step.GOAL: "LIGHT EVERY STAR OF THE\nCONSTELLATION TO WIN",
	Tutorial.Step.LAUNCH: "TAP THE SKY TO LAUNCH\nA CHEAP BLUE PLANET",
	Tutorial.Step.LINK: "LINK ONE OF EACH SIZE\nTAP EACH STAR",
	Tutorial.Step.DUST: "DUST BUYS PLANETS",
	Tutorial.Step.SUN: "LIGHT FILLS THE SUN",
	Tutorial.Step.LAUNCH_NEAR: "LAUNCH NEXT TO THIS STAR",
	Tutorial.Step.LIGHT: "LINK 3 OF THE SAME SIZE\nNOW DRAG THROUGH THEM",
	Tutorial.Step.RED: "LAUNCH THE RED PLANET\nIT SPLITS IN TWO\nWITH MORE BIG STARS",
	Tutorial.Step.BUY: "SPEND DUST ON A PLANET",
	Tutorial.Step.DONE: "LIGHT EVERY STAR TO WIN",
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

## The step shown for free play's first full Sun (show_sun_full): no Tutorial step.
const SUN_FULL_STEP: int = -2

var _step: int = -1
var _target: Vector2i = Vector2i.ZERO
var _point: Point = Point.DOWN
var _has_target: bool = false
var _time: float = 0.0
var _label: Label
## The combo card's combos (each a row of Star.Size values; empty: no card), where its top sits, and
## its OR label.
var _combos: Array = []
## The guide's top (the sky's top edge plus TOP) and how many lines its text takes.
var _top: int = 78 + TOP
var _lines: int = 1
var _or: Label
var _tap: Label
## The link the hand teaches: the ids to pick in order and where it points for each.
var _path: Array[int] = []
var _path_points: Array[Vector2i] = []
## The path's star centres, where the dragged link's demo slides (empty: no demo).
var _demo: Array[Vector2i] = []
var _picked: int = 0
## Whether the payout step's time-out was sent already.
var _timed_out: bool = false


func _ready() -> void:
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.label_settings = HudText.primary(Palette.C1)
	# Two lines sit LINE_STEP apart: the font's 7 px, its shadow and a gap.
	_label.label_settings.line_spacing = LINE_STEP - 7 - 2
	add_child(_label)
	_or = Label.new()
	_or.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_or.label_settings = HudText.primary(Palette.C1)
	_or.text = OR_TEXT
	add_child(_or)
	_tap = Label.new()
	_tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap.label_settings = HudText.primary(Palette.N8)
	_tap.text = TAP_TEXT
	add_child(_tap)
	_tap.size = _tap.get_minimum_size()
	hide_guide()


func _process(delta: float) -> void:
	advance(delta)


## The combos the card shows at `step`: one of each size while linking the first pack, three of
## `same_size` while lighting the constellation star, both as free play starts; none otherwise.
static func card_combos(step: int, same_size: int = Star.Size.SMALL) -> Array:
	var each: Array[int] = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG]
	var same: Array[int] = [same_size, same_size, same_size]
	match step:
		Tutorial.Step.LINK:
			return [each]
		Tutorial.Step.LIGHT:
			return [same]
		Tutorial.Step.DONE:
			return [each, [Star.Size.MEDIUM, Star.Size.MEDIUM, Star.Size.MEDIUM] as Array[int]]
	return []


## Shows step `step`: its line, the hand at `target` (pointing down, or right at a button) when
## `has_target`, and the combo card for the step, with `same_size` for the three-of-a-size combo; the
## guide's top at `top` (the sky's top edge plus TOP).
func show_step(step: int, target: Vector2i = Vector2i.ZERO, has_target: bool = false, point: Point = Point.DOWN, top: int = 78 + TOP, same_size: int = Star.Size.SMALL) -> void:
	_combos = card_combos(step, same_size)
	_top = top
	_step = step
	_target = target
	_has_target = has_target and step != Tutorial.Step.DONE
	_point = point
	_time = 0.0
	_path.clear()
	_path_points.clear()
	_demo.clear()
	_picked = 0
	_timed_out = false
	_tap.visible = Tutorial.is_info(step) and not Tutorial.is_timed(step)
	_set_text(TEXTS.get(step, ""))
	visible = true
	queue_redraw()


## Free play's first full Sun: its line, and the hand on the star it lit (`target`), for
## SUN_FULL_TIME.
func show_sun_full(target: Vector2i, top: int = 78 + TOP) -> void:
	show_step(SUN_FULL_STEP, target, true, Point.DOWN, top)
	_set_text(SUN_FULL_TEXT)


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
## Where it's dragged (Tutorial.link_input), the hand acts the drag out through `centres` (the
## stars' centres) until a star is picked.
func follow_path(ids: Array[int], points: Array[Vector2i], centres: Array[Vector2i] = []) -> void:
	_path = ids.duplicate()
	_path_points = points.duplicate()
	_demo.clear()
	if _step >= 0 and Tutorial.link_input(_step) == Tutorial.LinkInput.DRAG and centres.size() > 1:
		_demo = centres.duplicate()
	follow([])


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
	_set_text(SHINE_TEXT if not selected.is_empty() else TEXTS.get(_step, ""))
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


## The combos the card shows now (rows of Star.Size), or [] with no card.
func combos() -> Array:
	return _combos.duplicate() if visible else []


## The card's plaque now, or an empty rect with no card.
func card_rect() -> Rect2i:
	if not visible or _combos.is_empty():
		return Rect2i()
	var width: int = 2 * CARD_PAD
	for k: int in _combos.size():
		width += row_width(_combos[k])
		if k > 0:
			width += 2 * OR_GAP + _or_width()
	var height: int = 2 * CARD_PAD + StarView.half_extent(Star.Size.BIG) * 2 + 1
	var top: int = _top + _lines * LINE_STEP + (LINE_STEP if _tap.visible else 0) + CARD_GAP
	return Rect2i(ScreenZones.SCREEN.x / 2 - width / 2, top, width, height)


## How wide one combo's row is: its stars' art, STAR_GAP apart.
static func row_width(sizes: Array) -> int:
	var width: int = 0
	for k: int in sizes.size():
		width += StarView.half_extent(sizes[k] as Star.Size) * 2 + 1
		if k > 0:
			width += STAR_GAP
	return width


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
	if (_step == Tutorial.Step.DONE and _time >= DONE_TIME) or (_step == SUN_FULL_STEP and _time >= SUN_FULL_TIME):
		hide_guide()
		return
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
	_draw_card()
	if not _has_target:
		return
	if is_demoing_drag():
		_draw_trail()
	var dots: Dictionary[Vector2i, Color] = hand_pixels(fingertip(), _point)
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])


## The drag's demo leaves a dotted trail (C1) from the first star to the fingertip.
func _draw_trail() -> void:
	var tip: Vector2i = fingertip()
	var count: int = 0
	for k: int in _demo.size() - 1:
		var on_leg: bool = _on_segment(tip, _demo[k], _demo[k + 1])
		for p: Vector2i in LinkLayer.line_pixels(_demo[k], _demo[k + 1]):
			if on_leg and (p - _demo[k]).length_squared() > (tip - _demo[k]).length_squared():
				return
			if count % TRAIL_GAP == 0:
				draw_rect(Rect2(Vector2(p), Vector2.ONE), Palette.C1)
			count += 1
		if on_leg:
			return


## Whether `p` lies on the leg from `a` to `b` (within a pixel).
static func _on_segment(p: Vector2i, a: Vector2i, b: Vector2i) -> bool:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(p), Vector2(a), Vector2(b))
	return closest.distance_to(Vector2(p)) <= 1.0 and p != b


## The line(s) from the guide's top, LINE_STEP apart; TAP TO CONTINUE under them, the card under that.
func _set_text(value: String) -> void:
	_label.text = value
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines = value.count("\n") + 1
	_label.size = Vector2(ScreenZones.SCREEN.x, _label.get_minimum_size().y)
	_label.position = Vector2(0, _top)
	_label.visible = true
	_tap.size = _tap.get_minimum_size()
	_tap.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(_tap.size.x / 2.0), _top + _lines * LINE_STEP)
	_lay_out_card()


func _or_width() -> int:
	return int(_or.get_minimum_size().x) if _or != null else 12


func _lay_out_card() -> void:
	_or.visible = _combos.size() > 1
	if not _or.visible:
		return
	var card: Rect2i = card_rect()
	_or.size = _or.get_minimum_size()
	var x: int = card.position.x + CARD_PAD + row_width(_combos[0]) + OR_GAP
	_or.position = Vector2(x, card.position.y + card.size.y / 2 - 3)


## The combo card: the plaque, then each combo's stars (their sky art, idle) in a row, an OR between
## two combos.
func _draw_card() -> void:
	var card: Rect2i = card_rect()
	if not card.has_area():
		return
	_draw_plaque(card)
	var mid: int = card.position.y + card.size.y / 2
	var x: int = card.position.x + CARD_PAD
	for k: int in _combos.size():
		if k > 0:
			x += OR_GAP + _or_width() + OR_GAP
		var sizes: Array = _combos[k]
		for i: int in sizes.size():
			var half: int = StarView.half_extent(sizes[i] as Star.Size)
			if i > 0:
				x += STAR_GAP
			var centre := Vector2i(x + half, mid)
			var art: Dictionary[Vector2i, Color] = ConstellationView.star_pixels(sizes[i])
			for d: Vector2i in art:
				draw_rect(Rect2(Vector2(centre + d), Vector2.ONE), art[d])
			x += half * 2 + 1


## A filled rect with a 1 px border that skips its four corner pixels (the end screen's plaque).
func _draw_plaque(rect: Rect2i) -> void:
	var r := Rect2(rect)
	draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), Palette.N0)
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), Palette.N6)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), Palette.N6)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), Palette.N6)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), Palette.N6)
