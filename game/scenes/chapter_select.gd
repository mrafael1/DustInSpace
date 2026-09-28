class_name ChapterSelect
extends CanvasLayer
## Scorpio's chapter chart (#62): the constellation as a pixel-art star chart over deep space
## (a stepped sky, a milky way, faint nebulae and cool background stars), each star a stage
## point, travelled from the tail. Tap a point to select it (a comet travels there along the
## strings); PLAY starts its stage if it's available or completed. Locked points can be selected to
## see what they are, never played.
## Points: completed ones are gold stars; the one to play next has a warm ring that breathes;
## locked ones are cool and quieter. The selected point wears C0 corner brackets. The path is solid:
## gold along the route between completed stages, warm from the last one to the stage to play
## next, and a cool guide elsewhere. Numbers (3x5, UI text) count the route from the tail, so the
## direction reads without astronomy. The selected stage's name and PLAY sit on their own panel.
## Back from a won stage (show_progress), the point flashes as it lights, then a comet travels to
## the point it unlocked. Owns no rules: Chapter says what's completed and available.
## Works in game coordinates (App sets the layer's offset like Main's UI layers).

## The player asked to play the stage at route point `point`.
signal stage_chosen(point: int)

## How a string of the path shows: a cool guide, the way to the stage to play next, or travelled.
enum Leg { GUIDE, NEXT, LIT }

const TITLE_Y: int = 30
const SUBTITLE_Y: int = 42
const INFO_Y: int = 251
const PLAY := Rect2i(58, 264, 64, 22)
## The stage panel behind the name and PLAY: M1 fill, N6 border, clipped corners.
const PANEL := Rect2i(26, 242, 128, 50)
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
## Space behind the chart (cool colours only: warm is for the route and stages). The sky steps
## down from N0 to N2 through ordered-dither seams (SKY_STOPS: the row each step starts at, in game
## rows); a milky way runs across it (dithered N2/N3 about MILKY_WAY's line, MILKY_WIDTH px either
## side); two nebulae glow faintly (NEBULAE: centre and radius, N4/N5 dither); background stars are
## 1 px N7/N8/M5, one in STAR_ODDS pixels, one in GLINT_ODDS of them a 3 px glint, kept STAR_CLEAR
## px from every stage point and off its number, the title and the stage panel.
const SKY_STOPS: Array[int] = [104, 214]
const SKY_STEPS: Array[Color] = [Palette.N0, Palette.N1, Palette.N2]
const SEAM: int = 32
const MILKY_WAY: Array[Vector2i] = [Vector2i(-40, 300), Vector2i(220, 10)]
const MILKY_WIDTH: int = 22
const NEBULAE: Array[Vector3i] = [Vector3i(46, 118, 34), Vector3i(150, 222, 26)]
const STAR_ODDS: int = 110
const GLINT_ODDS: int = 12
const STAR_CLEAR: int = 8
const STAR_COLOURS: Array[Color] = [Palette.N7, Palette.N7, Palette.N8, Palette.M5]

## Where a point's number sits from the point.
const NUMBER_OFFSET := Vector2i(8, -12)

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
## The space behind the chart, built once per screen.
var _space: ImageTexture

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
	_play.label_settings = HudText.primary(Palette.C0)
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
	if screen != _screen or _space == null:
		_space = ImageTexture.create_from_image(space_image(screen))
	_screen = screen
	_chart.queue_redraw()


## The space behind the chart for a visible screen `screen` (game coordinates; the image's 0,0 is
## screen.position). Opaque, cool palette colours only, the same pixels for the same place.
static func space_image(screen: Rect2i) -> Image:
	var image := Image.create_empty(screen.size.x, screen.size.y, false, Image.FORMAT_RGBA8)
	var a := Vector2(MILKY_WAY[0])
	var along: Vector2 = (Vector2(MILKY_WAY[1]) - a).normalized()
	for y: int in screen.size.y:
		for x: int in screen.size.x:
			var p := Vector2i(x, y) + screen.position
			image.set_pixel(x, y, _space_colour(p, a, along))
	for p: Vector2i in space_stars(screen):
		var h: int = _hash(p) / STAR_ODDS
		var local: Vector2i = p - screen.position
		if h % GLINT_ODDS == 0:
			for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var q: Vector2i = local + n
				if q.x >= 0 and q.y >= 0 and q.x < screen.size.x and q.y < screen.size.y:
					image.set_pixel(q.x, q.y, Palette.N7)
			image.set_pixel(local.x, local.y, Palette.M5)
		else:
			image.set_pixel(local.x, local.y, STAR_COLOURS[h % STAR_COLOURS.size()])
	return image


## Where the background stars are in `screen`: a fixed hash per pixel, clear of the stage points
## and the stage panel.
static func space_stars(screen: Rect2i) -> Array[Vector2i]:
	var stars: Array[Vector2i] = []
	var panel: Rect2i = PANEL.grow(3)
	var title := Rect2i(40, TITLE_Y - 3, 100, SUBTITLE_Y - TITLE_Y + 13)
	for y: int in range(screen.position.y, screen.end.y):
		for x: int in range(screen.position.x, screen.end.x):
			var p := Vector2i(x, y)
			if _hash(p) % STAR_ODDS != 0 or panel.has_point(p) or title.has_point(p):
				continue
			var clear: bool = true
			for point: int in Chapter.point_count():
				var number := Rect2i(point_position(point) + NUMBER_OFFSET - Vector2i(2, 2), Vector2i(12, 10))
				if (point_position(point) - p).length_squared() < STAR_CLEAR * STAR_CLEAR or number.has_point(p):
					clear = false
					break
			if clear:
				stars.append(p)
	return stars


static func _space_colour(p: Vector2i, milky_start: Vector2, milky_along: Vector2) -> Color:
	var bayer: float = StarView.BAYER[posmod(p.y, 4) * 4 + posmod(p.x, 4)] / 16.0
	# The sky's steps, each seam an ordered dither SEAM rows deep.
	var step: int = 0
	for i: int in SKY_STOPS.size():
		var into: float = float(p.y - SKY_STOPS[i]) / SEAM
		if into >= 1.0 or (into > 0.0 and bayer < into):
			step = i + 1
	var colour: Color = SKY_STEPS[step]
	# The milky way: N2, then N3 at its heart, thinning out to its edges.
	var rel: Vector2 = Vector2(p) - milky_start
	var off: float = absf(rel.dot(milky_along.orthogonal())) + 4.0 * sin(rel.dot(milky_along) * 0.05)
	var band: float = 1.0 - absf(off) / MILKY_WIDTH
	if band > 0.0:
		if band > 0.6 and bayer < (band - 0.6) * 1.2:
			colour = Palette.N3
		elif bayer < band * 0.55:
			colour = Palette.N2 if step < 2 else Palette.N3
	# Nebulae: a soft N4 cloud with an N5 heart, dithered sparser to its rim.
	for nebula: Vector3i in NEBULAE:
		var d: float = Vector2(p).distance_to(Vector2(nebula.x, nebula.y)) / nebula.z
		var wobble: float = 0.12 * sin(p.x * 0.21 + nebula.x) * cos(p.y * 0.17 + nebula.y)
		var k: float = 1.0 - d + wobble
		if k > 0.55 and bayer < (k - 0.55) * 1.4:
			colour = Palette.N5
		elif k > 0.0 and bayer < k * 0.5:
			colour = Palette.N4
	return colour


## A fixed, well-mixed hash of a pixel (non-negative).
static func _hash(p: Vector2i) -> int:
	var h: int = p.x * 374761393 + p.y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


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
		var colour: Color = Palette.N8
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
		_info.label_settings.font_color = Palette.N8
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
	if _space == null:
		_space = ImageTexture.create_from_image(space_image(_screen))
	_chart.draw_texture(_space, Vector2(_screen.position))
	if _chapter == null:
		return
	var legs: Array[Leg] = string_legs()
	for leg: Leg in [Leg.GUIDE, Leg.NEXT, Leg.LIT]:
		for segment: int in Scorpio.segment_count():
			if legs[segment] == leg:
				_draw_string(segment, leg)
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
	_draw_plaque(PANEL, Palette.M1, Palette.N6)
	if can_play():
		_draw_plaque(PLAY, Palette.C4 if _pressed_play else Palette.C5, Palette.C2)


## How each string shows (Scorpio.SEGMENTS order): LIT along the route between completed stages
## (following the strings, so the way back through the head to a claw lights too), NEXT from the
## last completed stage to the stage to play next, GUIDE elsewhere.
func string_legs() -> Array[Leg]:
	var legs: Array[Leg] = []
	for segment: int in Scorpio.segment_count():
		legs.append(Leg.GUIDE)
	for point: int in range(1, Chapter.point_count()):
		var leg: Leg = Leg.GUIDE
		if _chapter.is_completed(point - 1) and _chapter.is_completed(point):
			leg = Leg.LIT
		elif _chapter.is_completed(point - 1) and _chapter.is_available(point):
			leg = Leg.NEXT
		if leg == Leg.GUIDE:
			continue
		var marks: Array[int] = Chapter.path(point - 1, point)
		for k: int in range(1, marks.size()):
			var segment: int = _segment_between(marks[k - 1], marks[k])
			legs[segment] = maxi(legs[segment], leg) as Leg
	return legs


## A solid 1 px string: C1 when travelled, C3 on the way to the next stage, an N6 guide elsewhere.
func _draw_string(segment: int, leg: Leg) -> void:
	var ends: Array[int] = Scorpio.segment_landmarks(segment)
	var colour: Color = Palette.N6
	if leg == Leg.LIT:
		colour = Palette.C1
	elif leg == Leg.NEXT:
		colour = Palette.C3
	for p: Vector2i in LinkLayer.line_pixels(Scorpio.LANDMARKS[ends[0]], Scorpio.LANDMARKS[ends[1]]):
		_dot(p, colour)


static func _segment_between(a: int, b: int) -> int:
	for segment: int in Scorpio.segment_count():
		var pair: Vector2i = Scorpio.SEGMENTS[segment]
		if (pair.x == a and pair.y == b) or (pair.x == b and pair.y == a):
			return segment
	return -1


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
				_dot(at + d, Palette.C2)
		_:
			_fill(at, 1, Palette.N0)
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				_dot(at + d, Palette.N8)
			_dot(at, Palette.M6)


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
