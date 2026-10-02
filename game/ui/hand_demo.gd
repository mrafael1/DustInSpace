class_name HandDemo
extends Node2D
## The idle hint's hand (#90): the guided run's pointing hand acting out a drag through a link's
## stars, leaving its dotted trail (TutorialView.demo_point, trail_pixels and hand_pixels, so it
## looks and moves exactly like the tutorial's). IdleHint plays it and sets its time; it draws
## nothing while it has no path.

## The stars' centres the hand slides through, in link order (empty: hidden).
var _points: Array[Vector2i] = []
var _time: float = 0.0


## Starts the demo through `points` (the link's star centres, in order).
func play(points: Array[Vector2i]) -> void:
	_points = points.duplicate()
	_time = 0.0
	queue_redraw()


func stop() -> void:
	_points.clear()
	queue_redraw()


func is_playing() -> bool:
	return _points.size() > 1


## Moves the demo to `seconds` since it started.
func show_time(seconds: float) -> void:
	_time = seconds
	queue_redraw()


## Where the fingertip is now.
func fingertip() -> Vector2i:
	return TutorialView.demo_point(_points, _time)


## How long one pass of the demo through `count` stars takes: a rest on the first, a slide to each
## next one, a rest on the last.
static func pass_time(count: int) -> float:
	return TutorialView.DRAG_REST * 2.0 + TutorialView.DRAG_STEP * maxi(count - 1, 0)


## When, into a pass, the fingertip reaches star `k` of the path.
static func arrival(k: int) -> float:
	return 0.0 if k == 0 else TutorialView.DRAG_REST + TutorialView.DRAG_STEP * k


func _draw() -> void:
	if not is_playing():
		return
	var tip: Vector2i = fingertip()
	for p: Vector2i in TutorialView.trail_pixels(_points, tip):
		draw_rect(Rect2(Vector2(p), Vector2.ONE), Palette.C1)
	var dots: Dictionary[Vector2i, Color] = TutorialView.hand_pixels(tip, TutorialView.Point.DOWN)
	for p: Vector2i in dots:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), dots[p])
