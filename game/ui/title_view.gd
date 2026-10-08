class_name TitleView
extends Node2D
## The title over the sky above the chart (ChapterSelect shows it on start): DUST IN over SPACE in
## the 5x7 font at whole-number scales (2x, then 3x), C1 with an N0 shadow; under them a thin rule
## tipped with small stars (the chart label's), and on its middle the light star: the selection
## star, twinkling, which lifts off and leads the way down to the chart when the player taps.
## Now and then a sparkle (a C0 cross, then a C1 dot) catches a letter. TAP TO START blinks (C2)
## near the bottom. Presentation only: ChapterSelect places it a screen above the chart and owns
## the tap. Lays out in the coordinates of the visible screen it's given (layout).

const LINE_1: String = "DUST IN"
const LINE_2: String = "SPACE"
const SCALE_1: int = 2
const SCALE_2: int = 3
## The 5x7 font: 6 px a letter (5 and a gap), 7 rows.
const LETTER: int = 6
const ROWS: int = 7
## The title's top sits TITLE_AT of the way down the screen; LINE_GAP px between the lines.
const TITLE_AT: float = 0.26
const LINE_GAP: int = 6
## The rule under the title: RULE_GAP px below it, RULE px either side of the star's gap STAR_GAP.
const RULE_GAP: int = 12
const RULE: int = 26
const STAR_GAP: int = 7
## The light star twinkles (longer arms, C0) for TWINKLE_ON once every TWINKLE_PERIOD.
const TWINKLE_PERIOD: float = 1.6
const TWINKLE_ON: float = 0.2
## TAP TO START: TAP_FROM_BOTTOM px above the screen's bottom, shown TAP_ON then hidden TAP_OFF.
const TAP_TEXT: String = "TAP TO START"
const TAP_FROM_BOTTOM: int = 64
const TAP_ON: float = 0.8
const TAP_OFF: float = 0.4
## A sparkle every SPARKLE_EVERY seconds on a letter, SPARKLE_LIFE long.
const SPARKLE_EVERY: float = 0.5
const SPARKLE_LIFE: float = 0.24

var _time: float = 0.0
var _started: bool = false
var _screen := Rect2i(Vector2i.ZERO, ScreenZones.SCREEN)
var _line_1: Label
var _line_2: Label
var _tap: Label
## Draws the sparkles over the letters.
var _front := Node2D.new()


func _ready() -> void:
	_line_1 = _label(LINE_1, HudText.primary(Palette.C1), SCALE_1)
	_line_2 = _label(LINE_2, HudText.primary(Palette.C1), SCALE_2)
	_tap = _label(TAP_TEXT, HudText.primary(Palette.C2), 1)
	_front.name = "Sparkles"
	add_child(_front)
	_front.draw.connect(_draw_sparkle)
	layout(_screen)


func _process(delta: float) -> void:
	advance(delta)


## Lays the title out on `screen` (this node's coordinates).
func layout(screen: Rect2i) -> void:
	_screen = screen
	if _line_1 == null:
		return
	var top: int = title_rect().position.y
	_line_1.position = Vector2(_line_x(LINE_1, SCALE_1), top)
	_line_2.position = Vector2(_line_x(LINE_2, SCALE_2), top + ROWS * SCALE_1 + LINE_GAP)
	_tap.size = _tap.get_minimum_size()
	_tap.position = Vector2(ScreenZones.SCREEN.x / 2 - floori(_tap.size.x / 2.0), _screen.end.y - TAP_FROM_BOTTOM)
	queue_redraw()


## The title's letters (this node's coordinates): the background stars keep off them.
func title_rect() -> Rect2i:
	var width: int = maxi(LINE_1.length() * LETTER * SCALE_1, LINE_2.length() * LETTER * SCALE_2)
	var height: int = ROWS * SCALE_1 + LINE_GAP + ROWS * SCALE_2
	var top: int = _screen.position.y + roundi(_screen.size.y * TITLE_AT)
	return Rect2i(ScreenZones.SCREEN.x / 2 - width / 2, top, width, height)


## Where the light star sits (this node's coordinates): the middle of the rule under the title.
func star_at() -> Vector2i:
	return Vector2i(ScreenZones.SCREEN.x / 2, title_rect().end.y + RULE_GAP)


## The player tapped: TAP TO START goes and the light star leaves (it leads the way down).
func set_started(on: bool) -> void:
	_started = on
	_tap.visible = not on
	queue_redraw()


func is_tap_shown() -> bool:
	return _tap.visible


## Moves the blink, the twinkle and the sparkles on. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	var before: int = int(_time / (1.0 / 30.0))
	_time += delta
	if not _started:
		_tap.visible = fmod(_time, TAP_ON + TAP_OFF) < TAP_ON
	if int(_time / (1.0 / 30.0)) != before:
		queue_redraw()
		_front.queue_redraw()


func _draw() -> void:
	var star: Vector2i = star_at()
	for side: int in [-1, 1]:
		var start: int = star.x + side * STAR_GAP
		var end: int = start + side * RULE
		for x: int in range(mini(start, end), maxi(start, end) + 1):
			_dot(Vector2i(x, star.y), Palette.N6)
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_dot(Vector2i(end + side * 2, star.y) + n, Palette.C2)
		_dot(Vector2i(end + side * 2, star.y), Palette.C0)
	if not _started:
		var twinkle: bool = fmod(_time, TWINKLE_PERIOD) >= TWINKLE_PERIOD - TWINKLE_ON
		var arms: Array[Color] = [Palette.C1, Palette.C2]
		if twinkle:
			arms = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			for k: int in arms.size():
				_dot(star + n * (k + 1), arms[k])
		_dot(star, Palette.C0)


## The sparkle of the moment: on a lit pixel of a letter, chosen from the time.
func _draw_sparkle() -> void:
	var beat: int = int(_time / SPARKLE_EVERY)
	var age: float = _time - beat * SPARKLE_EVERY
	if age >= SPARKLE_LIFE:
		return
	var rect: Rect2i = title_rect()
	var h: int = absi(beat * 2654435761) % 1000003
	var at := Vector2i(rect.position.x + h % rect.size.x, rect.position.y + (h / rect.size.x) % rect.size.y)
	if age < SPARKLE_LIFE / 2.0:
		for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			_front.draw_rect(Rect2(Vector2(at + n), Vector2.ONE), Palette.C1)
		_front.draw_rect(Rect2(Vector2(at), Vector2.ONE), Palette.C0)
	else:
		_front.draw_rect(Rect2(Vector2(at), Vector2.ONE), Palette.C0)


func _label(text: String, settings: LabelSettings, scale_by: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.label_settings = settings
	label.text = text
	label.scale = Vector2(scale_by, scale_by)
	add_child(label)
	return label


func _line_x(text: String, scale_by: int) -> int:
	return ScreenZones.SCREEN.x / 2 - (text.length() * LETTER - 1) * scale_by / 2


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
