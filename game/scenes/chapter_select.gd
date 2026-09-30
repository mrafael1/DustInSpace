class_name ChapterSelect
extends CanvasLayer
## Scorpio's chapter chart (#62): the constellation as a pixel-art star chart over deep space
## (a stepped sky, a milky way, faint nebulae and cool background stars). Its stars are grouped
## into the chapter's part stages (Stinger, Tail, Body, Heart, Claws), travelled from the tail,
## and a crown point above the figure is the final stage, the full Scorpio. Tap a star to select
## the stage it belongs to (a comet travels there); PLAY starts it if it's available or completed.
## Locked stages can be selected to see what they are, never played.
## A stage's stars are gold once it's won; the stage to play next shows warm, with a breathing
## ring round its point (its first star from the tail); locked ones are cool and quieter. Each
## part's point is its main star: bigger than the rest, twinkling on its own beat; the point to play
## next is the biggest and flares brighter once a beat (solid steps, no fades). The
## selected stage's point wears C0 corner brackets. The path is solid: gold between won stars,
## warm through and into the stage to play next, a cool guide elsewhere. Numbers (3x5, UI text)
## count the stages from the tail. The selected stage's name and PLAY sit on their own panel.
## The space behind is alive: some background stars twinkle, and now and then a cool shooting star
## streaks across behind the chart.
## Back from a won stage (show_progress), its point flashes as its stars light, then a comet
## travels to the stage it opened. Owns no rules: Chapter says what's won and available.
## Works in game coordinates (App sets the layer's offset like Main's UI layers).

## The player asked to play stage `stage`.
signal stage_chosen(stage: int)

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
## The breathing ring round the point to play next: radius RING_RADIUS or one more, swapping every
## RING_STEP.
const RING_STEP: float = 0.45
const RING_RADIUS: int = 8
## A part's main star twinkles (step 1) for TWINKLE_ON once every TWINKLE_PERIOD, each part
## TWINKLE_OFFSET later than the one before, so they never all twinkle together.
const TWINKLE_PERIOD: float = 1.6
const TWINKLE_ON: float = 0.15
const TWINKLE_OFFSET: float = 0.55
## The point to play next flares once every FLARE_PERIOD: FLARE_STEPS says how long each step lasts
## (1: rising, 2: full, 1: falling), then it rests at step 0.
const FLARE_PERIOD: float = 1.2
const FLARE_STEPS: Array[Vector2] = [Vector2(0.08, 1), Vector2(0.2, 2), Vector2(0.3, 1)]
## The chart redraws its animations at most once per ANIM_TICK.
const ANIM_TICK: float = 1.0 / 30.0
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
const STAR_CLEAR: int = 10
const STAR_COLOURS: Array[Color] = [Palette.N7, Palette.N7, Palette.N8, Palette.M5]
## One background star in SKY_TWINKLE_ODDS twinkles: it flashes M6 for SKY_TWINKLE_ON once every
## SKY_TWINKLE_PERIOD, at a phase of its own.
const SKY_TWINKLE_ODDS: int = 3
const SKY_TWINKLE_PERIOD: float = 2.6
const SKY_TWINKLE_ON: float = 0.2
## A shooting star every METEOR_WAIT seconds (x to y, at random): it starts in the top METEOR_TOP rows,
## streaks down and sideways at METEOR_SPEED px a second for METEOR_LENGTH px with a METEOR_TRAIL
## behind its head, all cool colours, behind the chart.
const METEOR_WAIT := Vector2(3.0, 8.0)
const METEOR_TOP: int = 200
const METEOR_SPEED: float = 200.0
const METEOR_LENGTH := Vector2i(60, 110)
const METEOR_TRAIL: Array[Color] = [Palette.M6, Palette.M6, Palette.M5, Palette.M5, Palette.M5, Palette.N8, Palette.N8, Palette.N8, Palette.N7, Palette.N7, Palette.N6, Palette.N6]

## Where a stage's number sits from its point.
const NUMBER_OFFSET := Vector2i(9, -15)
## The final stage's crown point, above the figure.
const FINAL_AT := Vector2i(90, 66)

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
## The space behind the chart, built once per screen, and its twinkling stars.
var _space: ImageTexture
var _twinklers: Array[Vector2i] = []
## Picks when and where shooting stars fly (tests seed it).
var meteor_rng := RandomNumberGenerator.new()
## The shooting star: the pixels it streaks along and how long it's been flying (-1: none), and how
## long until the next.
var _meteor: Array[Vector2i] = []
var _meteor_age: float = -1.0
var _meteor_wait: float = 0.0

@onready var _chart: Node2D = $Chart
@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _info: Label = $Info
@onready var _play: Label = $Play


func _ready() -> void:
	meteor_rng.randomize()
	_meteor_wait = meteor_rng.randf_range(METEOR_WAIT.x, METEOR_WAIT.y)
	_chart.draw.connect(_draw_chart)
	_title.label_settings = HudText.primary(Palette.C1)
	_subtitle.label_settings = HudText.primary(Palette.N8)
	_info.label_settings = HudText.primary(Palette.C1)
	_play.label_settings = HudText.primary(Palette.C0)
	_title.text = "SCORPIO"
	_subtitle.text = "CHAPTER 1"
	_centre(_title, TITLE_Y)
	_centre(_subtitle, SUBTITLE_Y)
	for stage: int in Chapter.stage_count():
		var number := Label.new()
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.text = "%d" % (stage + 1)
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
		_twinklers = twinkling_stars(screen)
	_screen = screen
	_chart.queue_redraw()


## The background stars of `screen` that twinkle: plain 1 px ones (not glints), one in
## SKY_TWINKLE_ODDS.
static func twinkling_stars(screen: Rect2i) -> Array[Vector2i]:
	var twinklers: Array[Vector2i] = []
	for p: Vector2i in space_stars(screen):
		var h: int = _hash(p) / STAR_ODDS
		if h % GLINT_ODDS != 0 and (h / GLINT_ODDS) % SKY_TWINKLE_ODDS == 0:
			twinklers.append(p)
	return twinklers


## Whether the background star at `p` is lit up at `time` (its own phase, from its hash).
static func sky_twinkles(p: Vector2i, time: float) -> bool:
	var phase: float = float(_hash(p + Vector2i(7, 3)) % 1000) / 1000.0 * SKY_TWINKLE_PERIOD
	return fmod(time + phase, SKY_TWINKLE_PERIOD) < SKY_TWINKLE_ON


## Starts a shooting star now, from a random point near the top, streaking down and sideways.
func launch_meteor() -> void:
	var from := Vector2i(meteor_rng.randi_range(_screen.position.x + 10, _screen.end.x - 10), meteor_rng.randi_range(_screen.position.y + 4, METEOR_TOP))
	var side: int = -1 if from.x > _screen.position.x + _screen.size.x / 2 else 1
	var length: int = meteor_rng.randi_range(METEOR_LENGTH.x, METEOR_LENGTH.y)
	var drop: int = meteor_rng.randi_range(length / 3, length / 2)
	_meteor = LinkLayer.line_pixels(from, from + Vector2i(side * length, drop))
	_meteor_age = 0.0


func is_meteor_flying() -> bool:
	return _meteor_age >= 0.0


## The shooting star's pixels now, head first, with their colours; none when none flies.
func meteor_pixels() -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if _meteor_age < 0.0:
		return dots
	var head: int = int(_meteor_age * METEOR_SPEED)
	for k: int in METEOR_TRAIL.size():
		var i: int = head - k
		if i >= 0 and i < _meteor.size():
			dots[_meteor[i]] = METEOR_TRAIL[k]
	# A head a pixel thicker, below the line.
	if head < _meteor.size():
		dots[_meteor[head] + Vector2i.DOWN] = Palette.M5
	return dots


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
			for star: Vector2i in Scorpio.LANDMARKS + [FINAL_AT]:
				if (star - p).length_squared() < STAR_CLEAR * STAR_CLEAR:
					clear = false
					break
			for stage: int in Chapter.stage_count():
				if Rect2i(stage_position(stage) + NUMBER_OFFSET - Vector2i(2, 2), Vector2i(12, 10)).has_point(p):
					clear = false
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


## Back from a stage: `lit` (a stage just won, or -1) flashes as its stars light, then a comet
## travels to `unlocked` (the stage it opened, or -1) and selects it.
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


## Selects stage `stage`; a comet travels there from the stage selected before.
func select(stage: int) -> void:
	if stage == _selected:
		return
	_travel = travel_pixels(_selected, stage)
	_travel_time = 0.0
	_travel_to = stage
	_selected = stage
	_refresh()


## Whether PLAY shows for the selected stage: its map exists and it's available or done.
func can_play() -> bool:
	return _chapter != null and _chapter.state(_selected) != Chapter.PointState.LOCKED


## Where stage `stage`'s point is drawn (game coordinates): a part's first star from the tail,
## or the crown point for the final.
static func stage_position(stage: int) -> Vector2i:
	if Chapter.is_final(stage):
		return FINAL_AT
	return Scorpio.LANDMARKS[Chapter.stars(stage)[0]]


## The stage a tap at `at` picks: the part owning the nearest star in reach, or the final on its
## crown point, or -1.
static func stage_at(at: Vector2i) -> int:
	var best: int = -1
	var best_d: int = HIT_RADIUS * HIT_RADIUS + 1
	for landmark: int in Scorpio.LANDMARKS.size():
		var d: int = (Scorpio.LANDMARKS[landmark] - at).length_squared()
		if d < best_d:
			best_d = d
			best = Chapter.stage_of(landmark)
	if (FINAL_AT - at).length_squared() < best_d:
		best = Chapter.FINAL
	return best


## The pixels a comet follows from one stage's point to another's: along the strings between
## parts, straight up to the crown for the final.
static func travel_pixels(from_stage: int, to_stage: int) -> Array[Vector2i]:
	if Chapter.is_final(from_stage) or Chapter.is_final(to_stage):
		return LinkLayer.line_pixels(stage_position(from_stage), stage_position(to_stage))
	var pixels: Array[Vector2i] = []
	var marks: Array[int] = Scorpio.landmark_path(Chapter.stars(from_stage)[0], Chapter.stars(to_stage)[0])
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
		_pressed_point = -1 if _pressed_play else stage_at(at)
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
	elif _pressed_point >= 0 and stage_at(at) == _pressed_point and not is_travelling() and not is_lighting():
		select(_pressed_point)
	_pressed_play = false
	_pressed_point = -1
	_chart.queue_redraw()
	return used


## Moves the comet, the lighting and the breathing ring on. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	var tick: int = int(_time / ANIM_TICK)
	_time += delta
	var redraw: bool = int(_time / ANIM_TICK) != tick
	if not _travel.is_empty():
		_travel_time += delta
		redraw = true
		if _travel_time * TRAVEL_SPEED >= _travel.size() + TRAIL.size():
			_travel.clear()
	# After the comet, so a trip the lighting starts begins from its start.
	_advance_meteor(delta)
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


## The shooting star flies on and ends; the next one waits its turn.
func _advance_meteor(delta: float) -> void:
	if _meteor_age >= 0.0:
		_meteor_age += delta
		if _meteor_age * METEOR_SPEED >= _meteor.size() + METEOR_TRAIL.size():
			_meteor_age = -1.0
			_meteor_wait = meteor_rng.randf_range(METEOR_WAIT.x, METEOR_WAIT.y)
		return
	_meteor_wait -= delta
	if _meteor_wait <= 0.0:
		launch_meteor()


func _ring_frame() -> int:
	return int(_time / RING_STEP) % 2


## Stage `stage`'s main star twinkle step at `time`: 1 for TWINKLE_ON once a period, else 0.
static func twinkle_step(stage: int, time: float) -> int:
	return 1 if fposmod(time - stage * TWINKLE_OFFSET, TWINKLE_PERIOD) >= TWINKLE_PERIOD - TWINKLE_ON else 0


## The point to play next's flare step at `time`: 0 at rest, 1 rising and falling, 2 at full.
static func flare_step(time: float) -> int:
	var t: float = fmod(time, FLARE_PERIOD)
	for step: Vector2 in FLARE_STEPS:
		if t < step.x:
			return int(step.y)
	return 0


## A part's main star (its point), centred on 0,0, in `state` at animation `step`: a 4-point star,
## bigger than the other chart stars. Locked: cool, twinkling to a longer, lighter cross (step 1).
## Won: gold, twinkling the same. To play next: the biggest, flaring (steps 1 and 2) longer and
## whiter, with diagonal glints.
static func main_star_pixels(state: Chapter.PointState, step: int) -> Dictionary[Vector2i, Color]:
	var core: Color
	var corners: Color
	var arms: Array[Color] = []
	var glints: Array[Color] = []
	match state:
		Chapter.PointState.LOCKED:
			core = Palette.M6
			corners = Palette.N6
			if step == 0:
				arms = [Palette.N8, Palette.N6]
			else:
				arms = [Palette.M5, Palette.N8, Palette.N6]
		Chapter.PointState.COMPLETED:
			core = Palette.C0
			corners = Palette.C2
			if step == 0:
				arms = [Palette.C1, Palette.C1, Palette.C2]
			else:
				arms = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
		_:
			core = Palette.C0
			corners = Palette.C1
			match step:
				0:
					arms = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
				1:
					arms = [Palette.C0, Palette.C0, Palette.C1, Palette.C2, Palette.C3]
					glints = [Palette.C2]
				_:
					arms = [Palette.C0, Palette.C0, Palette.C0, Palette.C1, Palette.C2, Palette.C3]
					glints = [Palette.C1, Palette.C3]
	var dots: Dictionary[Vector2i, Color] = {}
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		dots[d] = corners
		for k: int in glints.size():
			dots[d * (k + 2)] = glints[k]
	for axis: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for k: int in arms.size():
			dots[axis * (k + 1)] = arms[k]
	dots[Vector2i.ZERO] = core
	return dots


func _refresh() -> void:
	if _chapter == null or _info == null:
		return
	for stage: int in _numbers.size():
		var colour: Color = Palette.N8
		match _chapter.state(stage):
			Chapter.PointState.COMPLETED:
				colour = Palette.C1
			Chapter.PointState.AVAILABLE:
				colour = Palette.C2
		_numbers[stage].label_settings = HudText.secondary(colour)
		_numbers[stage].position = Vector2(stage_position(stage) + NUMBER_OFFSET)
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
	for p: Vector2i in _twinklers:
		if sky_twinkles(p, _time):
			_dot(p, Palette.M6)
	var meteor: Dictionary[Vector2i, Color] = meteor_pixels()
	for p: Vector2i in meteor:
		_dot(p, meteor[p])
	if _chapter == null:
		return
	var legs: Array[Leg] = string_legs()
	for leg: Leg in [Leg.GUIDE, Leg.NEXT, Leg.LIT]:
		for segment: int in Scorpio.segment_count():
			if legs[segment] == leg:
				_draw_string(segment, leg)
	for landmark: int in Scorpio.LANDMARKS.size():
		_draw_star(landmark)
	_draw_crown()
	_draw_selection(stage_position(_selected))
	if _light_point >= 0:
		var k: float = _light_time / LIGHT_TIME
		var colour: Color = LIGHT_COLOURS[mini(floori(k * LIGHT_COLOURS.size()), LIGHT_COLOURS.size() - 1)]
		var radius: int = 4 + roundi(k * LIGHT_GROWTH)
		for d: Vector2i in ConstellationView.circle_pixels(radius):
			_dot(stage_position(_light_point) + d, colour)
	_draw_comet()
	_draw_plaque(PANEL, Palette.M1, Palette.N6)
	if can_play():
		_draw_plaque(PLAY, Palette.C4 if _pressed_play else Palette.C5, Palette.C2)


## How each string shows (Scorpio.SEGMENTS order): LIT between two won stars, NEXT through
## and into the part to play next (from the won stars before it), GUIDE elsewhere.
func string_legs() -> Array[Leg]:
	var legs: Array[Leg] = []
	for segment: int in Scorpio.segment_count():
		var ends: Array[int] = Scorpio.segment_landmarks(segment)
		var a: Chapter.PointState = _star_state(ends[0])
		var b: Chapter.PointState = _star_state(ends[1])
		if a == Chapter.PointState.COMPLETED and b == Chapter.PointState.COMPLETED:
			legs.append(Leg.LIT)
		elif a != Chapter.PointState.LOCKED and b != Chapter.PointState.LOCKED:
			legs.append(Leg.NEXT)
		else:
			legs.append(Leg.GUIDE)
	return legs


## A chart star shows its part stage's state.
func _star_state(landmark: int) -> Chapter.PointState:
	return _chapter.state(Chapter.stage_of(landmark))


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


## A chart star in its part's state: a gold star once won; warm while its part is the one to
## play; cool and quieter while locked. A part's first star is its main star (main_star_pixels),
## wearing the breathing ring while it's the one to play.
func _draw_star(landmark: int) -> void:
	var at: Vector2i = Scorpio.LANDMARKS[landmark]
	var stage: int = Chapter.stage_of(landmark)
	if landmark == Chapter.stars(stage)[0]:
		_draw_main_star(stage)
		return
	match _chapter.state(stage):
		Chapter.PointState.COMPLETED:
			for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				_dot(at + d, Palette.C2)
			_fill(at, 1, Palette.C1)
			_dot(at, Palette.C0)
		Chapter.PointState.AVAILABLE:
			_fill(at, 1, Palette.C2)
			_dot(at, Palette.C0)
		_:
			_fill(at, 1, Palette.N0)
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				_dot(at + d, Palette.N8)
			_dot(at, Palette.M6)


## Stage `stage`'s main star, animated: the point to play next flares and wears the ring; the others
## twinkle on their own beat.
func _draw_main_star(stage: int) -> void:
	var at: Vector2i = stage_position(stage)
	var state: Chapter.PointState = _chapter.state(stage)
	var step: int = flare_step(_time) if state == Chapter.PointState.AVAILABLE else twinkle_step(stage, _time)
	var dots: Dictionary[Vector2i, Color] = main_star_pixels(state, step)
	for d: Vector2i in dots:
		_dot(at + d, dots[d])
	if state == Chapter.PointState.AVAILABLE:
		_ring(at)


## The final stage's crown point: a star with 3 px arms (gold once won, warm and ringed while
## playable, cool while locked).
func _draw_crown() -> void:
	var state: Chapter.PointState = _chapter.state(Chapter.FINAL)
	var core: Color = Palette.N8
	var arms: Color = Palette.N6
	if state == Chapter.PointState.COMPLETED:
		core = Palette.C0
		arms = Palette.C1
	elif state == Chapter.PointState.AVAILABLE:
		core = Palette.C1
		arms = Palette.C2
		_ring(FINAL_AT)
	for k: int in range(1, 4):
		for d: Vector2i in [Vector2i(0, -k), Vector2i(0, k), Vector2i(-k, 0), Vector2i(k, 0)]:
			_dot(FINAL_AT + d, core if k == 1 else arms)
	_dot(FINAL_AT, Palette.C0 if state != Chapter.PointState.LOCKED else Palette.M6)


func _ring(at: Vector2i) -> void:
	for d: Vector2i in ConstellationView.circle_pixels(RING_RADIUS + _ring_frame()):
		_dot(at + d, Palette.C2)


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
