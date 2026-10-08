class_name HandDemo
extends Node2D
## The idle hint's hand (#90): the guided run's pointing hand acting out a drag through a link's
## stars, leaving its dotted trail (TutorialView.demo_point, trail_pixels and hand_pixels, so it
## looks and moves exactly like the tutorial's), or (#152, while the telescope aims) a tap on the
## aimed spot: it hovers TutorialView.GAP px above, presses down onto it, holds, and lifts, firing
## nothing. IdleHint plays it and sets its time; it draws nothing while it has no path or tap.

## The tap: hovering, pressing down (whole pixels), holding on the spot, lifting; seconds each.
const TAP_HOVER: float = 0.6
const TAP_PRESS: float = 0.2
const TAP_HOLD: float = 0.4
const TAP_LIFT: float = 0.2

## The stars' centres the hand slides through, in link order (empty: hidden).
var _points: Array[Vector2i] = []
## The spot a tap presses (only while `_tapping`).
var _spot: Vector2i = Vector2i.ZERO
var _tapping: bool = false
var _time: float = 0.0


## Starts the demo through `points` (the link's star centres, in order).
func play(points: Array[Vector2i]) -> void:
	_points = points.duplicate()
	_tapping = false
	_time = 0.0
	queue_redraw()


## Starts the tap demo on `spot` (the aimed burst point).
func play_tap(spot: Vector2i) -> void:
	_points.clear()
	_spot = spot
	_tapping = true
	_time = 0.0
	queue_redraw()


## Moves the tap to `spot` (the aim moved), keeping its time.
func move_tap(spot: Vector2i) -> void:
	if _tapping and spot != _spot:
		_spot = spot
		queue_redraw()


func stop() -> void:
	_points.clear()
	_tapping = false
	queue_redraw()


func is_playing() -> bool:
	return _points.size() > 1 or _tapping


## Whether it acts out a tap (true) rather than a drag.
func is_tapping() -> bool:
	return _tapping


## Moves the demo to `seconds` since it started.
func show_time(seconds: float) -> void:
	_time = seconds
	queue_redraw()


## Where the fingertip is now.
func fingertip() -> Vector2i:
	if _tapping:
		return tap_point(_spot, _time)
	return TutorialView.demo_point(_points, _time)


## How long one pass of the demo through `count` stars takes: a rest on the first, a slide to each
## next one, a rest on the last.
static func pass_time(count: int) -> float:
	return TutorialView.DRAG_REST * 2.0 + TutorialView.DRAG_STEP * maxi(count - 1, 0)


## How long one tap takes: hover, press, hold, lift.
static func tap_time() -> float:
	return TAP_HOVER + TAP_PRESS + TAP_HOLD + TAP_LIFT


## When, into a pass, the fingertip reaches star `k` of the path.
static func arrival(k: int) -> float:
	return 0.0 if k == 0 else TutorialView.DRAG_REST + TutorialView.DRAG_STEP * k


## Where the tap demo has the fingertip at `time`: hovering GAP px above `spot`, pressing down onto
## it a whole pixel at a time, holding, lifting back, then again.
static func tap_point(spot: Vector2i, time: float) -> Vector2i:
	var t: float = fmod(time, tap_time())
	var k: float = 0.0
	if t < TAP_HOVER:
		k = 0.0
	elif t < TAP_HOVER + TAP_PRESS:
		k = (t - TAP_HOVER) / TAP_PRESS
	elif t < TAP_HOVER + TAP_PRESS + TAP_HOLD:
		k = 1.0
	else:
		k = 1.0 - (t - TAP_HOVER - TAP_PRESS - TAP_HOLD) / TAP_LIFT
	return spot - Vector2i(0, roundi(TutorialView.GAP * (1.0 - clampf(k, 0.0, 1.0))))


func _draw() -> void:
	if not is_playing():
		return
	var tip: Vector2i = fingertip()
	if not _tapping:
		for p: Vector2i in TutorialView.trail_pixels(_points, tip):
			draw_rect(Rect2(Vector2(p), Vector2.ONE), Palette.C1)
	var dots: Dictionary[Vector2i, Color] = TutorialView.hand_pixels(tip, TutorialView.Point.DOWN)
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])
