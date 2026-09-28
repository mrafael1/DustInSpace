class_name ChapterSelect
extends CanvasLayer
## Scorpio's chapter chart (#62): the constellation as a pixel-art star chart, each star a stage
## point, travelled from the tail. Tap a point to select it (a comet travels there along the
## strings); PLAY starts its stage if it's available or completed. Locked points can be selected to
## see what they are, never played.
## Points: completed ones are gold stars, and the strings between completed points glow; the one
## to play next has a warm ring that breathes; locked ones are dim. The selected point wears C0
## corner brackets. Numbers (3x5, UI text) count the route from the tail, and small chevrons on the
## strings point the way on, so the direction reads without astronomy.
## Back from a won stage (show_progress), the point flashes as it lights, then a comet travels to
## the point it unlocked. Owns no rules: Chapter says what's completed and available.
## Works in game coordinates (App sets the layer's offset like Main's UI layers).

## The player asked to play the stage at route point `point`.
signal stage_chosen(point: int)

const TITLE_Y: int = 30
const SUBTITLE_Y: int = 42
const INFO_Y: int = 252
const PLAY := Rect2i(58, 266, 64, 22)
## Press circle around a point: 44 pt at 2 pt per px.
const HIT_RADIUS: int = 12
## The breathing ring round the point to play next: radius 6 or 7, swapping every RING_STEP.
const RING_STEP: float = 0.45
## A comet travels the strings at TRAVEL_SPEED px a second: a small star for a head (C0 heart, C1
## arms) and a trail TRAIL long, cooling to C4.
const TRAVEL_SPEED: float = 140.0
const TRAIL: Array[Color] = [Palette.C0, Palette.C1, Palette.C1, Palette.C2, Palette.C2, Palette.C3, Palette.C3, Palette.C4, Palette.C4]
## A point lighting throws a ring out LIGHT_GROWTH px over LIGHT_TIME, cooling C0 to C3.
const LIGHT_TIME: float = 0.45
const LIGHT_GROWTH: int = 12
const LIGHT_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
## Where a point's number sits from the point.
const NUMBER_OFFSET := Vector2i(8, -12)
## The chart's faint grid, every GRID px.
const GRID: int = 20

var _chapter: Chapter
var _selected: int = 0
var _time: float = 0.0
## The comet: the pixels it follows and how far along it is (seconds); empty when none.
var _travel: Array[Vector2i] = []
var _travel_time: float = 0.0
var _travel_to: int = -1
## A point lighting up (back from its stage's win), and the point to travel to after, or -1.
var _light_point: int = -1
var _light_time: float = 0.0
var _then_travel_to: int = -1
var _pressed_point: int = -1
var _pressed_play: bool = false
## The visible screen in game coordinates (fit_screen).
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
var _numbers: Array[Label] = []

@onready var _chart: Node2D = $Chart
@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _info: Label = $Info
@onready var _play: Label = $Play


func _ready() -> void:
	_chart.draw.connect(_draw_chart)
	_title.label_settings = HudText.primary(Palette.C1)
	_subtitle.label_settings = HudText.primary(Palette.N8)
	_info.label_settings = HudText.primary(Palette.C1)
	_play.label_settings = HudText.primary(Palette.C1)
	_title.text = "SCORPIO"
	_subtitle.text = "CHAPTER 1"
	_centre(_title, TITLE_Y)
	_centre(_subtitle, SUBTITLE_Y)
	for point: int in Chapter.point_count():
		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = "%d" % (point + 1)
		add_child(number)
		_numbers.append(number)


func _process(delta: float) -> void:
	advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and handle_pointer(ScreenZones.to_game(event, Vector2i(offset))):
		get_viewport().set_input_as_handled()


## Shows `chapter`, the point to play next selected.
func setup(chapter: Chapter) -> void:
	_chapter = chapter
	_travel.clear()
	_light_point = -1
	_then_travel_to = -1
	_selected = chapter.current()
	_refresh()


func fit_screen(screen: Rect2i) -> void:
	_screen = screen
	_chart.queue_redraw()


## Back from a stage: `lit` (a route point just completed, or -1) flashes as it lights, then a
## comet travels to `unlocked` (the point it opened, or -1) and selects it.
func show_progress(lit: int, unlocked: int) -> void:
	_travel.clear()
	if lit >= 0:
		_selected = lit
		_light_point = lit
		_light_time = 0.0
		_then_travel_to = unlocked
	else:
		_selected = _chapter.current()
	_refresh()


func selected() -> int:
	return _selected


func is_travelling() -> bool:
	return not _travel.is_empty()


func is_lighting() -> bool:
	return _light_point >= 0


## Selects route point `point`; a comet travels there from the point selected before.
func select(point: int) -> void:
	if point == _selected:
		return
	_travel = travel_pixels(_selected, point)
	_travel_time = 0.0
	_travel_to = point
	_selected = point
	_refresh()


## Whether PLAY shows for the selected point: its stage exists and it's available or done.
func can_play() -> bool:
	return _chapter != null and _chapter.state(_selected) != Chapter.PointState.LOCKED


## Where route point `point` is drawn (game coordinates).
static func point_position(point: int) -> Vector2i:
	return Scorpio.LANDMARKS[Chapter.landmark(point)]


## The route point whose press circle holds `at`, the nearest if several do, or -1.
static func point_at(at: Vector2i) -> int:
	var best: int = -1
	var best_d: int = HIT_RADIUS * HIT_RADIUS + 1
	for point: int in Chapter.point_count():
		var d: int = (point_position(point) - at).length_squared()
		if d < best_d:
			best_d = d
			best = point
	return best


## The pixels a comet follows from one point to another, along the strings.
static func travel_pixels(from_point: int, to_point: int) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	var marks: Array[int] = Chapter.path(from_point, to_point)
	for k: int in range(1, marks.size()):
		var line: Array[Vector2i] = LinkLayer.line_pixels(Scorpio.LANDMARKS[marks[k - 1]], Scorpio.LANDMARKS[marks[k]])
		if not pixels.is_empty():
			line.pop_front()
		pixels.append_array(line)
	return pixels


## Feeds one touch (game coordinates). Returns true if it was used.
func handle_pointer(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0 or _chapter == null:
		return false
	var at := Vector2i(touch.position.floor())
	if touch.pressed:
		_pressed_play = can_play() and PLAY.has_point(at)
		_pressed_point = -1 if _pressed_play else point_at(at)
		_chart.queue_redraw()
		return _pressed_play or _pressed_point >= 0
	var used: bool = _pressed_play or _pressed_point >= 0
	if touch.canceled:
		_pressed_play = false
		_pressed_point = -1
		_chart.queue_redraw()
		return used
	if _pressed_play and PLAY.has_point(at) and can_play():
		stage_chosen.emit(_selected)
	elif _pressed_point >= 0 and point_at(at) == _pressed_point and not is_travelling() and not is_lighting():
		select(_pressed_point)
	_pressed_play = false
	_pressed_point = -1
	_chart.queue_redraw()
	return used


## Moves the comet, the lighting and the breathing ring on. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	var ring: int = _ring_frame()
	_time += delta
	var redraw: bool = _ring_frame() != ring
	if not _travel.is_empty():
		_travel_time += delta
		redraw = true
		if _travel_time * TRAVEL_SPEED >= _travel.size() + TRAIL.size():
			_travel.clear()
	# After the comet, so a trip the lighting starts begins from its start.
	if _light_point >= 0:
		_light_time += delta
		redraw = true
		if _light_time >= LIGHT_TIME:
			_light_point = -1
			if _then_travel_to >= 0:
				var to: int = _then_travel_to
				_then_travel_to = -1
				select(to)
	if redraw:
		_chart.queue_redraw()


func _ring_frame() -> int:
	return int(_time / RING_STEP) % 2


func _refresh() -> void:
	if _chapter == null or _info == null:
		return
	for point: int in _numbers.size():
		var colour: Color = Palette.N7
		match _chapter.state(point):
			Chapter.PointState.COMPLETED:
				colour = Palette.C1
			Chapter.PointState.AVAILABLE:
				colour = Palette.C2
		_numbers[point].label_settings = HudText.secondary(colour)
		_numbers[point].position = Vector2(point_position(point) + NUMBER_OFFSET)
	if _chapter.has_stage(_selected):
		_info.text = Chapter.stage_name(_selected)
		_info.label_settings.font_color = Palette.C1
	else:
		_info.text = "COMING SOON"
		_info.label_settings.font_color = Palette.N7
	_centre(_info, INFO_Y)
	_play.visible = can_play()
	_play.text = "REPLAY" if _chapter.is_completed(_selected) else "PLAY"
	_play.size = _play.get_minimum_size()
	_play.position = Vector2(PLAY.position.x + floori((PLAY.size.x - _play.size.x) / 2.0), PLAY.position.y + 8)
	_chart.queue_redraw()


func _centre(label: Label, y: int) -> void:
	label.size = label.get_minimum_size()
	label.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(label.size.x / 2.0), y)


func _draw_chart() -> void:
	_chart.draw_rect(Rect2(_screen), Palette.N0)
	for y: int in range(_screen.position.y + posmod(-_screen.position.y, GRID), _screen.end.y, GRID):
		for x: int in range(_screen.position.x, _screen.end.x, 3):
			_dot(Vector2i(x, y), Palette.N1)
	for x: int in range(_screen.position.x + posmod(-_screen.position.x, GRID), _screen.end.x, GRID):
		for y: int in range(_screen.position.y, _screen.end.y, 3):
			_dot(Vector2i(x, y), Palette.N1)
	if _chapter == null:
		return
	for segment: int in Scorpio.segment_count():
		_draw_string(segment)
	for point: int in range(1, Chapter.point_count()):
		_draw_chevron(point)
	for point: int in Chapter.point_count():
		_draw_point(point)
	_draw_selection(point_position(_selected))
	if _light_point >= 0:
		var k: float = _light_time / LIGHT_TIME
		var colour: Color = LIGHT_COLOURS[mini(floori(k * LIGHT_COLOURS.size()), LIGHT_COLOURS.size() - 1)]
		var radius: int = 4 + roundi(k * LIGHT_GROWTH)
		for d: Vector2i in ConstellationView.circle_pixels(radius):
			_dot(point_position(_light_point) + d, colour)
	_draw_comet()
	if can_play():
		_draw_plaque(PLAY, Palette.M3 if _pressed_play else Palette.N0, Palette.C2)


## A string glows C1 between two completed points; otherwise it's a dotted N6 guide.
func _draw_string(segment: int) -> void:
	var ends: Array[int] = Scorpio.segment_landmarks(segment)
	var done: bool = _landmark_completed(ends[0]) and _landmark_completed(ends[1])
	var pixels: Array[Vector2i] = LinkLayer.line_pixels(Scorpio.LANDMARKS[ends[0]], Scorpio.LANDMARKS[ends[1]])
	for i: int in pixels.size():
		if done:
			_dot(pixels[i], Palette.C1)
		elif i % 2 == 0:
			_dot(pixels[i], Palette.N6)


## A small chevron halfway from point `point - 1` towards `point`, pointing the way on: warm on
## the step to the point to play next, dim elsewhere.
func _draw_chevron(point: int) -> void:
	var marks: Array[int] = Chapter.path(point - 1, point)
	if marks.size() < 2:
		return
	var a := Vector2(Scorpio.LANDMARKS[marks[0]])
	var b := Vector2(Scorpio.LANDMARKS[marks[1]])
	var dir: Vector2 = (b - a).normalized()
	var mid: Vector2 = (a + b) / 2.0
	var side: Vector2 = dir.orthogonal()
	var colour: Color = Palette.C2 if _chapter.state(point) == Chapter.PointState.AVAILABLE and not _chapter.is_completed(point) else Palette.N7
	_dot(Vector2i((mid + dir * 1.5).round()), colour)
	_dot(Vector2i((mid - dir * 0.5 + side * 1.5).round()), colour)
	_dot(Vector2i((mid - dir * 0.5 - side * 1.5).round()), colour)


func _draw_point(point: int) -> void:
	var at: Vector2i = point_position(point)
	match _chapter.state(point):
		Chapter.PointState.COMPLETED:
			for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				_dot(at + d, Palette.C2)
			_fill(at, 1, Palette.C1)
			_dot(at, Palette.C0)
		Chapter.PointState.AVAILABLE:
			_fill(at, 1, Palette.C1)
			_dot(at, Palette.C0)
			for d: Vector2i in ConstellationView.circle_pixels(6 + _ring_frame()):
				if (d.x + d.y) % 2 == 0:
					_dot(at + d, Palette.C2)
		_:
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				_dot(at + d, Palette.N6)
			_dot(at, Palette.N8)


## C0 corner brackets round the selected point (a lighter C1 while it's pressed).
func _draw_selection(at: Vector2i) -> void:
	for corner: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var c: Vector2i = at + corner * 9
		for i: int in 3:
			_dot(c - Vector2i(corner.x * i, 0), Palette.C0)
			_dot(c - Vector2i(0, corner.y * i), Palette.C0)


func _draw_comet() -> void:
	if _travel.is_empty():
		return
	var head: int = int(_travel_time * TRAVEL_SPEED)
	for k: int in range(TRAIL.size() - 1, -1, -1):
		var i: int = head - k
		if i >= 0 and i < _travel.size():
			_dot(_travel[i], TRAIL[k])
	if head < _travel.size():
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(_travel[head] + n, Palette.C1)
		_dot(_travel[head], Palette.C0)


func _landmark_completed(landmark: int) -> bool:
	var point: int = Chapter.ROUTE.find(landmark)
	return point >= 0 and _chapter.is_completed(point)


func _fill(at: Vector2i, half: int, colour: Color) -> void:
	_chart.draw_rect(Rect2(Vector2(at - Vector2i(half, half)), Vector2(2 * half + 1, 2 * half + 1)), colour)


func _dot(p: Vector2i, colour: Color) -> void:
	_chart.draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)


## A filled rect with a 1 px border that skips its four corner pixels (like the end screen's).
func _draw_plaque(rect: Rect2i, fill: Color, border: Color) -> void:
	var r := Rect2(rect)
	_chart.draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), fill)
	_chart.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	_chart.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	_chart.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	_chart.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)
