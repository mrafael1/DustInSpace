class_name TutorialView
extends Node2D
## The guided first run's guide (Tutorial), on the HUD layer: one line of text above the launcher
## saying what to do, and a pointing hand at where to do it, bobbing BOB px every BOB_STEP. The hand
## points down at a spot in the sky, a star or a landmark, and points right at the buy button. Free
## play shows its line for a moment and no hand. Owns no rules: the HUD tells it each step as it
## plays, with where to point.
## The linking steps teach the two combos with a card at the top of the sky, drawn with the sky
## stars' own art: one of each size (small + medium + big) as the first link is made, three of the
## same size as the constellation star is lit, and both, with OR between them, as free play starts.
## The card is a plaque (N0 fill, N6 border, clipped corners) with the stars spaced in a row: no sign
## between them (a plus read as one more small star, which is plus-shaped).

## Where the line sits (the HUD's message line) and how long free play's line stays.
const LINE_Y: int = 262
const DONE_TIME: float = 4.0
## The combo card: CARD_TOP px below the sky's top edge, CARD_PAD px inside its border, STAR_GAP px
## between two stars, OR_GAP px either side of the OR between two combos.
const CARD_TOP: int = 6
const CARD_PAD: int = 4
const STAR_GAP: int = 5
const OR_GAP: int = 5
const OR_TEXT: String = "OR"
const TEXTS: Dictionary = {
	Tutorial.Step.LAUNCH: "TAP THE SKY TO LAUNCH",
	Tutorial.Step.LINK: "LINK ONE OF EACH SIZE",
	Tutorial.Step.LAUNCH_NEAR: "LAUNCH NEXT TO THIS STAR",
	Tutorial.Step.LIGHT: "LINK 3 OF THE SAME SIZE",
	Tutorial.Step.BUY: "BUY A PLANET",
	Tutorial.Step.DONE: "LIGHT EVERY STAR",
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
## The combo card's combos (each a row of Star.Size values; empty: no card), where its top sits, and
## its OR label.
var _combos: Array = []
var _card_top: int = 0
var _or: Label


func _ready() -> void:
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.label_settings = HudText.primary(Palette.C1)
	add_child(_label)
	_or = Label.new()
	_or.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_or.label_settings = HudText.primary(Palette.C1)
	_or.text = OR_TEXT
	add_child(_or)
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
## `has_target`, and the combo card for the step, its top `card_top` (the sky's top edge plus
## CARD_TOP), with `same_size` for the three-of-a-size combo.
func show_step(step: int, target: Vector2i = Vector2i.ZERO, has_target: bool = false, point: Point = Point.DOWN, card_top: int = 78 + CARD_TOP, same_size: int = Star.Size.SMALL) -> void:
	_combos = card_combos(step, same_size)
	_card_top = card_top
	_step = step
	_target = target
	_has_target = has_target and step != Tutorial.Step.DONE
	_point = point
	_time = 0.0
	_label.text = TEXTS.get(step, "")
	_label.size = _label.get_minimum_size()
	_label.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(_label.size.x / 2.0), LINE_Y)
	_label.visible = true
	_lay_out_card()
	visible = true
	queue_redraw()


func hide_guide() -> void:
	_step = -1
	_has_target = false
	visible = false


func step() -> int:
	return _step


func text() -> String:
	return _label.text if visible and _label.visible else ""


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
	return Rect2i(ScreenZones.SCREEN.x / 2 - width / 2, _card_top, width, height)


## How wide one combo's row is: its stars' art, STAR_GAP apart.
static func row_width(sizes: Array) -> int:
	var width: int = 0
	for k: int in sizes.size():
		width += StarView.half_extent(sizes[k] as Star.Size) * 2 + 1
		if k > 0:
			width += STAR_GAP
	return width


## Where the hand's fingertip is now (bobbing towards its target and back).
func fingertip() -> Vector2i:
	var bob: int = BOB * (int(_time / BOB_STEP) % 2)
	if _point == Point.RIGHT:
		return _target - Vector2i(GAP - bob, 0)
	return _target - Vector2i(0, GAP - bob)


func advance(delta: float) -> void:
	if not visible:
		return
	var bob: int = int(_time / BOB_STEP) % 2
	_time += delta
	if _step == Tutorial.Step.DONE and _time >= DONE_TIME:
		hide_guide()
		return
	if int(_time / BOB_STEP) % 2 != bob:
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
	var dots: Dictionary[Vector2i, Color] = hand_pixels(fingertip(), _point)
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])


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
