class_name TutorialView
extends Node2D
## The guided first run's guide (Tutorial), on the HUD layer: one line of text above the launcher
## saying what to do, and a pointing hand at where to do it, bobbing BOB px every BOB_STEP. The hand
## points down at a spot in the sky, a star or a landmark, and points right at the buy button. Free
## play shows its line for a moment and no hand. Owns no rules: the HUD tells it each step as it
## plays, with where to point.

## Where the line sits (the HUD's message line) and how long free play's line stays.
const LINE_Y: int = 262
const DONE_TIME: float = 2.5
const TEXTS: Dictionary = {
	Tutorial.Step.LAUNCH: "TAP THE SKY TO LAUNCH",
	Tutorial.Step.LINK: "DRAG THROUGH 3 STARS",
	Tutorial.Step.LAUNCH_NEAR: "LAUNCH NEXT TO THIS STAR",
	Tutorial.Step.LIGHT: "LINK IT WITH 2 STARS",
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


func _ready() -> void:
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.label_settings = HudText.primary(Palette.C1)
	add_child(_label)
	hide_guide()


func _process(delta: float) -> void:
	advance(delta)


## Shows step `step`: its line, and the hand at `target` (pointing down, or right at a button) when
## `has_target`.
func show_step(step: int, target: Vector2i = Vector2i.ZERO, has_target: bool = false, point: Point = Point.DOWN) -> void:
	_step = step
	_target = target
	_has_target = has_target and step != Tutorial.Step.DONE
	_point = point
	_time = 0.0
	_label.text = TEXTS.get(step, "")
	_label.size = _label.get_minimum_size()
	_label.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(_label.size.x / 2.0), LINE_Y)
	_label.visible = true
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
	if not _has_target:
		return
	var dots: Dictionary[Vector2i, Color] = hand_pixels(fingertip(), _point)
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])
