class_name ConstellationView
extends Node2D
## Draws the Scorpio map (#40) under the stars. Each landmark is drawn with the star art of its
## size, so a small, medium or big landmark has the shape of the sky star it can stand in for.
## Unlit (usable in a combo), it looks exactly like that sky star, in shape and colour (small
## orange, medium mauve, big blue-white), still, with four small corner brackets in ember (C3/C4,
## swapping every CUE_STEP) that say "you can pick this". Lit, it turns gold whatever its size
## (the "lit" frames), with a warm halo (LIT_HALO) and the twinkle (the lit_glint frame for a
## moment every StarView.TWINKLE_PERIOD), and no brackets: gold in the sky means "done", like the
## strings. Strings between two lit landmarks glow C1 with a C0 glint
## running along them; strings still to form are dotted N8. While a link is traced, the landmarks
## in it keep their colour and show their halo and the dashed C1 selection ring, like a picked sky
## star, and the strings it would form are dashed C2; every other string thins (TRACE_THIN) so
## the gold trace reads over it. Like the HUD and the Sun it keeps
## a shown copy of what's lit, moved only by played landmark_lit events, so a landmark the Sun
## lights stays unlit until the Sun's ignition has played. Owns no rules:
## RunState says what's lit. Draws nothing without the map.
## Completion plays the constellation like an instrument once every payout has landed (the Sky
## waits): string by string from the bottom of the sky to the top, each flashing C0 and vibrating
## as its note sounds (string_sung). Then the map's painting (StarMap.painting: the whole Scorpio,
## or a part stage's own piece of it) forms from the constellation's stars (#100, Apparition): it
## spreads outward from every star at once through the artwork, a bright edge leading (C0, then
## C1), until the figure is whole; then it flashes C0 once and stays.

## The sunbeam reached its landmark, at `at`. Feedback only.
signal sunbeam_landed(at: Vector2i)
## Completion: the `order`-th string (0 = the lowest) lit and its note should sound.
signal string_sung(segment: int, order: int)
## The Head: landmark `index`, big, burned back to small as it popped. Feedback only.
signal landmark_rekindled(index: int)
## Leo's final arriving: its `order`-th star caught fire. Feedback only (sound).
signal blaze_lit(order: int)
## Leo's final arriving: the whole lion is alight and roars. Feedback only (sound).
signal roared

## Leo's final arrives (play_blaze): its stars, dark at first (their dim art), catch fire one every
## BLAZE_STEP along the figure from the lit tail tuft: C0 for BLAZE_FLASH, ember (S4) until
## BLAZE_EMBER, then themselves. Then the lion roars for ROAR_TIME: the whole figure flashes C0 on
## two ROAR_FLASH beats and shakes a pixel side to side.
const BLAZE_STEP: float = 0.12
const BLAZE_FLASH: float = 0.08
const BLAZE_EMBER: float = 0.24
const ROAR_TIME: float = 0.4
const ROAR_FLASH: float = 0.08
## The outline stops this far short of each landmark, so the stars stay clear.
const LANDMARK_CLEAR: int = 5
## A string still to form: one pixel in OUTLINE_STEP.
const OUTLINE_STEP: int = 2
## While a link is traced, strings not in it keep one pixel in TRACE_THIN of their usual ones, and
## built strings hold still (no glint), so the player's gold path stands out where they run beside it.
const TRACE_THIN: int = 2
## Built strings' idle glow: a C0 glint every GLOW_SPACING px moves one pixel per GLOW_STEP.
const GLOW_SPACING: int = 6
const GLOW_STEP: float = 0.12
## The selectable cue: its brackets sit this far out from the star art's edge, and swap between
## C3 and C4 every CUE_STEP.
const CUE_COLOURS: Array[Color] = [Palette.C3, Palette.C4]
const CUE_GAP: int = 2
const CUE_STEP: float = 0.6
## A lit landmark's halo, near then far, on every size: warm, like its gold.
const LIT_HALO: Array = [Palette.C4, Palette.C5]
## A landmark or string that just lit shows C0 this long.
const LIT_FLASH: float = 0.25
## A landmark lighting throws a 1 px ring from its art's edge out LIT_RING_GROWTH px over
## LIT_RING_TIME, cooling C0 to C3.
const LIT_RING_TIME: float = 0.4
const LIT_RING_GROWTH: int = 14
const LIT_RING_COLOURS: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
## The Sun lights a landmark with a sunbeam: a comet from the Sun's rim to the landmark over
## BEAM_TIME, eased out: a small star for a head (C0 heart, C1 arms) and a 3 px wide trail of
## BEAM_TRAIL pixels cooling C0 to C3, its edges a step dimmer. The landmark lights as it lands
## (the Sun holds the sequence that long, still shining).
const BEAM_TIME: float = 0.5
const BEAM_TRAIL: int = 14
const BEAM_RAMP: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]
const SUN_RIM: int = 20
## Completion: every string in TUNE_TIME, bottom to top (string_step apart, whatever the map's
## string count); then the painting forms.
const TUNE_TIME: float = 1.7
## The painting: it forms from the stars over FIGURE_RISE, then flashes C0 for FIGURE_FLASH, then
## holds for FIGURE_CODA. Drawn in home layout, like the map.
const FIGURE_RISE: float = 1.8
const FIGURE_FLASH: float = 0.1
## The finished figure holds the screen this long before the end screen.
const FIGURE_CODA: float = 1.6
## A stage won before (a replay) keeps its whole reveal but holds the painting only this long
## (#128: the first reveal is the reward; seen again, the hold just delays the end screen).
const REPEAT_CODA: float = 0.5
## A sung string vibrates: a standing wave of VIBRATE_AMPLITUDE px, VIBRATE_CYCLES swings, dying
## out over VIBRATE_TIME. Whole pixels, across the string.
const VIBRATE_TIME: float = 0.5
const VIBRATE_AMPLITUDE: float = 2.0
const VIBRATE_CYCLES: float = 3.0

var _run: RunState
var _time: float = 0.0
var _selected: Array[int] = []
## The link hint: unlit landmarks (indices) that could come next in the link being traced, and
## seconds since it started. Like the sky stars, they keep their halo and shine in step with the
## hinted stars, while every other unlit landmark dims; no corner brackets while a link is traced.
var _hinted: Array[int] = []
var _hint_time: float = 0.0
var _tracing: bool = false
## This stage was won before (Main sets it): its completion holds the painting for REPEAT_CODA.
var repeat: bool = false
var current_aiming: bool = false:
	set(value):
		if current_aiming != value:
			current_aiming = value
			queue_redraw()
## Which landmarks show lit: the run's as of setup, then each played landmark_lit.
var _shown_lit: Array[bool] = []
## The size each landmark shows: the map's as of setup, then each played landmarks_resized (the
## core changes its sizes the moment a launch resolves).
var _shown_sizes: Array[int] = []
## Landmarks the heat is resizing (the Head): index -> [from, to, seconds in, rekindled]. They play
## a sky star's resize (StarView's charge and pop), switching size at RESIZE_FLARE.
var _resizing: Dictionary[int, Array] = {}
## Landmarks being cropped by Virgo's scythe, and the seconds until they show again (unlit).
var _cropping: Dictionary[int, float] = {}
## Leo's final arriving: seconds into the blaze (-1: none), and the order its stars catch fire in.
var _blaze_time: float = -1.0
var _blaze_order: Array[int] = []
var _preview_strings: Array[int] = []
var _flash_landmark: int = -1
var _flash_string: int = -1
var _flash_left: float = 0.0
## The landmark whose lit ring is spreading, and for how long it has (-1: none).
var _ring_landmark: int = -1
var _ring_time: float = -1.0
## The sunbeam in flight: from, to, and its age (-1: none).
var _beam_from: Vector2i = Vector2i.ZERO
var _beam_to: Vector2i = Vector2i.ZERO
var _beam_time: float = -1.0
var _completion_time: float = -1.0
## The painting is fully shown (after a completion, until the next run).
var _revealed: bool = false
## Landmark pixels per star size, from the star art: [unlit, lit, lit glinting].
var _art: Array = []
## Each painting's opaque pixels, row by row (path -> {y -> xs}), and its top and bottom rows.
static var _figure_rows: Dictionary = {}
static var _figure_spans: Dictionary = {}
static var _paintings: Dictionary = {}


func _ready() -> void:
	for size: int in 3:
		_art.append([landmark_pixels(size), landmark_pixels(size, true), landmark_pixels(size, true, true), star_pixels(size, &"dim"), star_pixels(size, &"glint")])


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	if _run == null or _run.scorpio == null:
		return
	_draw_figure()
	var map: StarMap = _map()
	for segment: int in map.segment_count():
		_draw_string(segment)
	for i: int in map.count():
		_draw_landmark(i)
	if _ring_time >= 0.0:
		for p: Vector2i in lit_ring_pixels(shown_size(_ring_landmark), _ring_time / LIT_RING_TIME):
			_dot(map.landmarks[_ring_landmark] + p, LIT_RING_COLOURS[mini(floori(_ring_time / LIT_RING_TIME * 4.0), 3)])
	if _beam_time >= 0.0:
		_draw_beam(beam_pixels(_beam_from, _beam_to, _beam_time / BEAM_TIME))
	if _completion_time >= 0.0:
		_draw_completion()


func setup(run: RunState) -> void:
	_run = run
	# The map sits where the run's sky puts it (a taller sky moves it up); everything here is drawn
	# in its home layout, so the whole view moves with it.
	position = Vector2(run.scorpio.shift) if run.scorpio != null else Vector2.ZERO
	if has_painting(_map()):
		painting(_map().painting)
		figure_rows(_map().painting)
	_shown_lit.clear()
	_shown_sizes.clear()
	_resizing.clear()
	_cropping.clear()
	_blaze_time = -1.0
	if run.scorpio != null:
		_shown_lit.assign(run.scorpio.lit)
		_shown_sizes.assign(run.scorpio.map.sizes)
	clear_preview()
	_flash_left = 0.0
	_ring_time = -1.0
	_beam_time = -1.0
	_completion_time = -1.0
	_revealed = false


## The layout drawn: the run's map (#62), or the full Scorpio without one.
func _map() -> StarMap:
	return _run.scorpio.map if _run != null and _run.scorpio != null else StarMap.scorpio()


## How long the completion plays: the tune, the painting forming and flashing, the hold (shorter
## on a `replay`). A map without its painting yet (`map`; the full Scorpio's has one) ends once
## the last string has rung, instead of holding an empty sky for the painting.
static func completion_time(map: StarMap = null, replay: bool = false) -> float:
	if map != null and not has_painting(map):
		return TUNE_TIME + VIBRATE_TIME
	return TUNE_TIME + FIGURE_RISE + FIGURE_FLASH + (REPEAT_CODA if replay else FIGURE_CODA)


## Whether `map`'s painting has been drawn (a new chapter's stages come before their art: they
## complete with their song and no painting).
static func has_painting(map: StarMap) -> bool:
	return map.painting != "" and ResourceLoader.exists(map.painting)


## The painting at `path` (a StarMap.painting), loaded once. Views load theirs before they draw
## (setup, _ready): a texture loaded in the middle of a draw call broke the whole canvas layer.
static func painting(path: String = StarMap.FIGURE) -> Texture2D:
	if not _paintings.has(path):
		_paintings[path] = load(path) as Texture2D
	return _paintings[path]


## A painting's opaque pixels by row (y -> Array of x), read once from its image.
static func figure_rows(path: String = StarMap.FIGURE) -> Dictionary:
	if not _figure_rows.has(path):
		var image: Image = painting(path).get_image()
		var rows: Dictionary = {}
		var top: int = image.get_height()
		var bottom: int = -1
		for y: int in image.get_height():
			var xs: Array[int] = []
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					xs.append(x)
			if not xs.is_empty():
				rows[y] = xs
				top = mini(top, y)
				bottom = maxi(bottom, y)
		_figure_rows[path] = rows
		_figure_spans[path] = Vector2i(top, bottom)
	return _figure_rows[path]


## A painting's top and bottom rows.
static func figure_span(path: String = StarMap.FIGURE) -> Vector2i:
	figure_rows(path)
	return _figure_spans[path]


## How `map`'s painting forms: from the map's own stars, every one of them.
static func apparition(map: StarMap) -> Apparition:
	return Apparition.of(map.painting, painting(map.painting), map.landmarks)


## Seconds between the completion tune's strings: the whole tune takes TUNE_TIME.
static func string_step(map: StarMap = null) -> float:
	return TUNE_TIME / maxi(_or_full(map).segment_count(), 1)


static func _or_full(map: StarMap) -> StarMap:
	return map if map != null else StarMap.scorpio()


## The link being traced: the landmarks in it and the strings it would form.
func show_link_preview(landmarks: Array[int], strings: Array[int]) -> void:
	_selected = landmarks.duplicate()
	_preview_strings = strings.duplicate()
	queue_redraw()


func clear_preview() -> void:
	_selected.clear()
	_preview_strings.clear()
	queue_redraw()


## The link hint: these unlit landmarks could come next in the link being traced; `tracing` is
## whether a link is being traced at all (the others dim and the corner brackets hide).
func show_hints(landmarks: Array[int], tracing: bool) -> void:
	if landmarks != _hinted:
		_hint_time = 0.0
	_hinted = landmarks.duplicate()
	_tracing = tracing
	queue_redraw()


func hinted() -> Array[int]:
	return _hinted.duplicate()


## Whether string `segment` shows thinned: a link is traced and it wouldn't form the string.
func shows_thin(segment: int) -> bool:
	return (_tracing or current_aiming) and not _preview_strings.has(segment)


## Whether unlit landmark `index` shows dimmed: a link is traced and it can't come next.
func shows_dimmed(index: int) -> bool:
	return _tracing and not shows_lit(index) and not _selected.has(index) and not _hinted.has(index)


## A landmark_lit event played: it shows lit from now, with a C0 flash and a ring spreading out.
func flash_landmark(index: int) -> void:
	if index < _shown_lit.size():
		_shown_lit[index] = true
	_ring_landmark = index
	_ring_time = 0.0
	_flash_landmark = index
	_flash_string = -1
	_flash_left = LIT_FLASH
	queue_redraw()


## Virgo's bound sheaves: landmark `index` shows dark again (unlit), its strings with it.
func put_out(index: int) -> void:
	if index < _shown_lit.size():
		_shown_lit[index] = false
	queue_redraw()


## Virgo's scythe crops landmark `index`: it goes dark and isn't drawn for `seconds` (its cut halves
## are drawn over it), then shows unlit.
func crop(index: int, seconds: float) -> void:
	put_out(index)
	_cropping[index] = seconds


func is_cropping(index: int) -> bool:
	return _cropping.has(index)


## The Sun's ignition is over: a sunbeam flies from its rim (the Sun sits at `sun`) to landmark
## `index`, which lights when it lands (its landmark_lit event plays then). -1: no beam.
func launch_sunbeam(sun: Vector2i, index: int) -> void:
	if index < 0 or index >= _map().count():
		return
	_beam_to = _map().landmarks[index]
	var sun_here: Vector2i = sun - Vector2i(position)
	var toward: Vector2 = Vector2(_beam_to - sun_here).normalized()
	_beam_from = sun_here + Vector2i((toward * SUN_RIM).round())
	_beam_time = 0.0
	queue_redraw()


func is_beaming() -> bool:
	return _beam_time >= 0.0


## The sunbeam's head and trail at `k` (0-1 of its flight), head first: whole pixels along the
## line, the head eased out, the trail the BEAM_TRAIL pixels behind it.
static func beam_pixels(from: Vector2i, to: Vector2i, k: float) -> Array[Vector2i]:
	var line: Array[Vector2i] = LinkLayer.line_pixels(from, to)
	var eased: float = 1.0 - (1.0 - clampf(k, 0.0, 1.0)) * (1.0 - clampf(k, 0.0, 1.0))
	var head: int = roundi(eased * (line.size() - 1))
	var pixels: Array[Vector2i] = []
	for i: int in range(head, maxi(head - BEAM_TRAIL, -1), -1):
		pixels.append(line[i])
	return pixels


## The sunbeam: its trail, 3 px wide and cooling, then its star-shaped head on top.
func _draw_beam(trail: Array[Vector2i]) -> void:
	var along: Vector2 = Vector2(_beam_to - _beam_from).normalized()
	var side := Vector2i(Vector2(-along.y, along.x).round())
	for i: int in range(trail.size() - 1, 0, -1):
		var step: int = mini(i * BEAM_RAMP.size() / trail.size(), BEAM_RAMP.size() - 1)
		var edge: Color = BEAM_RAMP[mini(step + 1, BEAM_RAMP.size() - 1)]
		if i < trail.size() - 3:
			_dot(trail[i] + side, edge)
			_dot(trail[i] - side, edge)
		_dot(trail[i], BEAM_RAMP[step])
	for n: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		_dot(trail[0] + n, Palette.C1)
		_dot(trail[0] + n * 2, Palette.C2)
	_dot(trail[0], Palette.C0)


## A lit ring around a landmark of `size`, `k` (0-1) of the way out: a 1 px circle.
static func lit_ring_pixels(size: int, k: float) -> Array[Vector2i]:
	return circle_pixels(StarView.half_extent(size as Star.Size) + 2 + roundi(clampf(k, 0.0, 1.0) * LIT_RING_GROWTH))


## A 1 px circle of `radius` round the origin, on whole pixels.
static func circle_pixels(radius: int) -> Array[Vector2i]:
	var dots: Array[Vector2i] = []
	for dy: int in range(-radius - 1, radius + 2):
		for dx: int in range(-radius - 1, radius + 2):
			if roundi(sqrt(dx * dx + dy * dy)) == radius:
				dots.append(Vector2i(dx, dy))
	return dots


func flash_string(segment: int) -> void:
	_flash_string = segment
	_flash_left = LIT_FLASH
	queue_redraw()


## The strings from the bottom of the sky to the top: lowest midpoint first.
static func song_order(map: StarMap = null) -> Array[int]:
	var m: StarMap = _or_full(map)
	var order: Array[int] = []
	for segment: int in m.segment_count():
		order.append(segment)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _mid_y(m, a) > _mid_y(m, b) or (_mid_y(m, a) == _mid_y(m, b) and a > b))
	return order


static func _mid_y(map: StarMap, segment: int) -> int:
	var ends: Array[Vector2i] = map.segment_ends(segment)
	return ends[0].y + ends[1].y


func play_completion() -> void:
	_completion_time = 0.0
	string_sung.emit(song_order(_map())[0], 0)
	queue_redraw()


func is_completing() -> bool:
	return _completion_time >= 0.0


func is_revealed() -> bool:
	return _revealed


## Where the painting stands now: -1 hidden, 0-1 forming, 2 flashing, 3 shown.
func figure_stage() -> float:
	if _revealed:
		return 3.0
	if _completion_time < TUNE_TIME:
		return -1.0
	var t: float = _completion_time - TUNE_TIME
	if t < FIGURE_RISE:
		return t / FIGURE_RISE
	return 2.0 if t < FIGURE_RISE + FIGURE_FLASH else 3.0


## How far string pixel `i` of `count` is pushed across the string `age` seconds after its note.
static func vibration(i: int, count: int, age: float) -> int:
	if age < 0.0 or age >= VIBRATE_TIME or count < 2:
		return 0
	var envelope: float = VIBRATE_AMPLITUDE * (1.0 - age / VIBRATE_TIME)
	var swing: float = cos(TAU * VIBRATE_CYCLES * age / VIBRATE_TIME)
	return roundi(envelope * swing * sin(PI * i / (count - 1)))


## Where the built strings' glints are now, as a step 0 to GLOW_SPACING - 1.
func glow_step() -> int:
	return int(_time / GLOW_STEP) % GLOW_SPACING


## Moves the glow, flashes and completion on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	for index: int in _cropping.keys():
		_cropping[index] -= delta
		if _cropping[index] <= 0.0:
			_cropping.erase(index)
			queue_redraw()
	var step: int = glow_step()
	var cue: int = cue_frame()
	var twinkling: Array[bool] = _twinkling()
	var ring: int = ring_frame()
	var shine: int = StarView.shine_stage(_hint_time)
	_time += delta
	_hint_time += delta
	if not _hinted.is_empty() and StarView.shine_stage(_hint_time) != shine:
		queue_redraw()
	var mapped: bool = _run != null and _run.scorpio != null
	var redraw: bool = mapped and ((glow_step() != step and _shown_lit.count(true) > 1) \
		or (cue_frame() != cue and _shown_lit.has(false)) or _twinkling() != twinkling \
		or (ring_frame() != ring and not _selected.is_empty()))
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		redraw = true
	if _blaze_time >= 0.0:
		var before: float = _blaze_time
		_blaze_time += delta
		for k: int in _blaze_order.size():
			if before < k * BLAZE_STEP and _blaze_time >= k * BLAZE_STEP:
				blaze_lit.emit(k)
		if before < roar_at(_map()) and _blaze_time >= roar_at(_map()):
			roared.emit()
		if _blaze_time >= blaze_time(_map()):
			_blaze_time = -1.0
		redraw = true
	for index: int in _resizing.keys():
		var anim: Array = _resizing[index]
		var before: float = anim[2]
		anim[2] = before + delta
		if before < StarView.RESIZE_FLARE and anim[2] >= StarView.RESIZE_FLARE:
			_shown_sizes[index] = anim[1]
			if anim[3]:
				landmark_rekindled.emit(index)
		if anim[2] >= StarView.RESIZE_TIME:
			_resizing.erase(index)
		redraw = true
	if _ring_time >= 0.0:
		_ring_time += delta
		if _ring_time >= LIT_RING_TIME:
			_ring_time = -1.0
		redraw = true
	if _beam_time >= 0.0:
		_beam_time += delta
		if _beam_time >= BEAM_TIME:
			_beam_time = -1.0
			sunbeam_landed.emit(_beam_to)
		redraw = true
	if _completion_time >= 0.0:
		var step_time: float = string_step(_map())
		var before: int = floori(_completion_time / step_time)
		_completion_time += delta
		var now: int = floori(_completion_time / step_time)
		var order: Array[int] = song_order(_map())
		for k: int in range(before + 1, mini(now, order.size() - 1) + 1):
			string_sung.emit(order[k], k)
		if _completion_time >= completion_time(_map(), repeat):
			_completion_time = -1.0
			_revealed = true
		redraw = true
	if redraw:
		queue_redraw()


## Every pixel of a string, head to stinger, with the ends kept clear of the landmarks.
static func outline_pixels(segment: int, map: StarMap = null) -> Array[Vector2i]:
	var ends: Array[Vector2i] = _or_full(map).segment_ends(segment)
	var line: Array[Vector2i] = LinkLayer.line_pixels(ends[0], ends[1])
	return line.slice(LANDMARK_CLEAR, line.size() - LANDMARK_CLEAR)


## A frame of the star art for a size, as offsets from its centre.
static func star_pixels(size: int, frame: StringName = &"idle") -> Dictionary[Vector2i, Color]:
	var image: Image = StarView.SHEETS[size].get_image()
	var side: int = image.get_height()
	var half: int = side >> 1
	var left: int = StarView.FRAMES.find(frame) * side
	var dots: Dictionary[Vector2i, Color] = {}
	for y: int in side:
		for x: int in side:
			var c: Color = image.get_pixel(left + x, y)
			if c.a > 0.5:
				dots[Vector2i(x - half, y - half)] = Color(c.r, c.g, c.b)
	return dots


## A landmark's pixels: unlit, the sky star's of its size; lit, its gold frame, `glinting` for its
## twinkle's moment.
static func landmark_pixels(size: int, lit: bool = false, glinting: bool = false) -> Dictionary[Vector2i, Color]:
	if not lit:
		return star_pixels(size)
	return star_pixels(size, &"lit_glint" if glinting else &"lit")


## A lit landmark's halo of `size`, as offsets from its centre.
static func lit_halo_pixels(size: int) -> Dictionary[Vector2i, Color]:
	return StarView.halo_pixels(size as Star.Size, LIT_HALO)


## Whether lit landmark `index` shows its twinkle's glint `time` seconds in: like a sky star, for
## StarView.GLINT_TIME every StarView.TWINKLE_PERIOD, each landmark at its own phase.
static func twinkles(index: int, time: float) -> bool:
	var phase: float = fposmod(index * 0.618, 1.0) * StarView.TWINKLE_PERIOD
	return fposmod(time + phase, StarView.TWINKLE_PERIOD) < StarView.GLINT_TIME


func _draw_string(segment: int) -> void:
	var pixels: Array[Vector2i] = outline_pixels(segment, _map())
	var age: float = _sung_age(segment)
	if age >= 0.0 and age < VIBRATE_TIME:
		_draw_vibrating(segment, pixels, age)
		return
	var preview: bool = _preview_strings.has(segment)
	var quiet: bool = shows_thin(segment)
	if shows_built(segment):
		var flash: bool = segment == _flash_string and _flash_left > 0.0
		var step: int = glow_step()
		for i: int in pixels.size():
			if quiet and not flash:
				if i % TRACE_THIN == 0:
					_dot(pixels[i], Palette.C1)
				continue
			var glint: bool = (i + GLOW_SPACING - step) % GLOW_SPACING == 0
			_dot(pixels[i], Palette.C0 if flash or glint else Palette.C1)
		return
	var spacing: int = OUTLINE_STEP * (TRACE_THIN if quiet else 1)
	for i: int in pixels.size():
		if preview and i % 3 != 2:
			_dot(pixels[i], Palette.C2)
		elif not preview and i % spacing == 0:
			_dot(pixels[i], Palette.N8)


## The selectable cue's pixels around a landmark of `size`: an L in each corner, pointing in.
static func cue_pixels(size: int) -> Array[Vector2i]:
	var o: int = StarView.half_extent(size as Star.Size) + CUE_GAP
	var dots: Array[Vector2i] = []
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var corner := Vector2i(sx * o, sy * o)
			dots.append_array([corner, corner - Vector2i(sx, 0), corner - Vector2i(0, sy)])
	return dots


## Which landmarks show their twinkle's glint now (lit ones only).
func _twinkling() -> Array[bool]:
	var found: Array[bool] = []
	for i: int in _shown_lit.size():
		found.append(_shown_lit[i] and twinkles(i, _time))
	return found


## Whether landmark `index` shows lit: its landmark_lit event has played (or it was lit at setup).
func shows_lit(index: int) -> bool:
	return index < _shown_lit.size() and _shown_lit[index]


## Whether string `segment` shows formed: both its landmarks show lit.
func shows_built(segment: int) -> bool:
	var ends: Array[int] = _map().segment_landmarks(segment)
	return shows_lit(ends[0]) and shows_lit(ends[1])


## Which of the cue's two colours shows now: 0 (C3) or 1 (C4).
func cue_frame() -> int:
	return int(_time / CUE_STEP) % 2


## Whether landmark `index` shows the selectable cue: unlit, not while a link is traced (the
## strings still show it belongs), and not while the constellation plays.
func shows_cue(index: int) -> bool:
	return _run != null and _run.scorpio != null and not shows_lit(index) \
		and not _tracing and not _selected.has(index) and _completion_time < 0.0


## Which of the selection ring's two dash frames shows now, like a picked sky star's.
func ring_frame() -> int:
	return int(_time / StarView.RING_FRAME_TIME) % 2


func _draw_landmark(index: int) -> void:
	if _cropping.has(index):
		return
	var size: int = shown_size(index)
	var at: Vector2i = _map().landmarks[index]
	if _blaze_time >= 0.0:
		at += Motion.shake(blaze_shake(_blaze_time, _map()))
		var blaze: int = blaze_stage(index)
		if blaze >= 0:
			# Dark before it catches fire, then C0, then ember.
			var art: Dictionary = _art[size][3 if blaze == 0 else 0]
			for d: Vector2i in art:
				_dot(at + d, art[d] if blaze == 0 else (Palette.C0 if blaze == 1 else Palette.S4))
			return
	if _resizing.has(index) and _resizing[index][2] >= 0.0 and not shows_lit(index):
		_draw_resizing(index, size, at)
		return
	if shows_cue(index):
		for d: Vector2i in cue_pixels(size):
			_dot(at + d, CUE_COLOURS[cue_frame()])
	var lit: bool = shows_lit(index)
	var picked: bool = _selected.has(index) and not lit
	var hinted: bool = _hinted.has(index) and not lit and not picked
	var flash: bool = index == _flash_landmark and _flash_left > 0.0
	if not flash and (lit or picked or hinted):
		var halo: Dictionary[Vector2i, Color] = lit_halo_pixels(size) if lit else StarView.halo_pixels(size as Star.Size)
		for d: Vector2i in halo:
			_dot(at + d, halo[d])
	var shine: int = StarView.shine_stage(_hint_time) if hinted else -1
	var dots: Dictionary = _art[size][3 if shows_dimmed(index) else (4 if shine >= 0 else 0)]
	if lit:
		dots = _art[size][2 if twinkles(index, _time) else 1]
	for d: Vector2i in dots:
		_dot(at + d, Palette.C0 if flash else dots[d])
	var rays: Dictionary[Vector2i, Color] = StarView.shine_pixels(size as Star.Size, shine)
	for d: Vector2i in rays:
		_dot(at + d, rays[d])
	if picked:
		_draw_ring(size, at)


## A landmark the heat is resizing: a sky star's charge and pop (StarView.resize_frame, _offset and
## _pixels) in the landmark's own art; its flare is the art in C0.
func _draw_resizing(index: int, size: int, at: Vector2i) -> void:
	var anim: Array = _resizing[index]
	var t: float = anim[2]
	var frame: StringName = StarView.resize_frame(t, false)
	var dots: Dictionary = _art[size][4 if frame == &"glint" else (3 if frame == &"dim" else 0)]
	var offset: Vector2i = StarView.resize_offset(t, false)
	for d: Vector2i in dots:
		_dot(at + offset + d, Palette.C0 if frame == &"flare" else dots[d])
	var extra: Dictionary[Vector2i, Color] = StarView.resize_pixels(anim[0], anim[1], t, false)
	for p: Vector2i in extra:
		_dot(at + p, extra[p])


## Leo's final arrives: the lion catches fire star by star, then roars. Returns how long it plays.
func play_blaze() -> float:
	_blaze_order = blaze_order(_map())
	_blaze_time = 0.0
	queue_redraw()
	return blaze_time(_map())


func is_blazing() -> bool:
	return _blaze_time >= 0.0


## The order `map`'s stars catch fire in: from its first lit star outward along the strings.
static func blaze_order(map: StarMap) -> Array[int]:
	var order: Array[int] = [map.starting_lit[0] if not map.starting_lit.is_empty() else 0]
	var k: int = 0
	while k < order.size():
		for next: int in map.neighbours(order[k]):
			if not order.has(next):
				order.append(next)
		k += 1
	return order


## When the lion has caught fire and roars, and when the blaze is over.
static func roar_at(map: StarMap) -> float:
	return map.count() * BLAZE_STEP


static func blaze_time(map: StarMap) -> float:
	return roar_at(map) + ROAR_TIME


## The roar shakes the figure a pixel side to side, `t` seconds into the blaze.
static func blaze_shake(t: float, map: StarMap) -> Vector2i:
	var roar: float = t - roar_at(map)
	if roar < 0.0 or roar >= ROAR_TIME:
		return Vector2i.ZERO
	return Vector2i.RIGHT if floori(roar / (ROAR_FLASH * 0.5)) % 2 == 0 else Vector2i.LEFT


## How landmark `index` shows in the blaze: 0 still dark, 1 catching (C0), 2 ember, 3 roaring (C0),
## -1 itself.
func blaze_stage(index: int) -> int:
	var roar: float = _blaze_time - roar_at(_map())
	if roar >= 0.0:
		var beat: int = floori(roar / ROAR_FLASH)
		return 1 if roar < ROAR_TIME and beat % 2 == 0 and beat < 4 else -1
	var age: float = _blaze_time - _blaze_order.find(index) * BLAZE_STEP
	if age < 0.0:
		return 0
	if age < BLAZE_FLASH:
		return 1
	return 2 if age < BLAZE_EMBER else -1


## The size landmark `index` shows now (it may lag the core's while the heat's resize plays).
func shown_size(index: int) -> int:
	return _shown_sizes[index] if index < _shown_sizes.size() else _map().sizes[index]


## The heat changed these constellation stars (the Head): each charges at its old size, then pops
## to its new one; a big that burns back to small says so as it pops (landmark_rekindled). `delays`:
## seconds before a landmark's starts, by landmark index (the lion's heatwave on its way).
func resize_landmarks(changes: Array[StarHeat.Change], delays: Dictionary = {}) -> void:
	for change: StarHeat.Change in changes:
		var index: int = Scorpio.landmark_index(change.star_id)
		if index >= 0 and index < _map().count():
			_resizing[index] = [change.from, change.to, -float(delays.get(index, 0.0)), change.rekindled]
	queue_redraw()


func is_resizing() -> bool:
	return not _resizing.is_empty()


## The dashed C1 selection ring around a picked landmark: the sky star's ring art for its size.
func _draw_ring(size: int, at: Vector2i) -> void:
	var sheet: Texture2D = StarView.RING_SHEETS[size]
	var cell: int = sheet.get_height()
	var corner := Vector2(at - Vector2i(cell >> 1, cell >> 1))
	draw_texture_rect_region(sheet, Rect2(corner, Vector2(cell, cell)), Rect2(ring_frame() * cell, 0, cell, cell))


## Completion: the landmarks of the strings played so far flash C0.
func _draw_completion() -> void:
	var order: Array[int] = song_order(_map())
	var played: int = mini(floori(_completion_time / string_step(_map())) + 1, order.size())
	for k: int in played:
		var segment: int = order[k]
		for index: int in _map().segment_landmarks(segment):
			var dots: Dictionary = _art[shown_size(index)][1]
			for d: Vector2i in dots:
				_dot(_map().landmarks[index] + d, Palette.C0 if dots[d] != Palette.C3 else Palette.C1)


## Seconds since `segment`'s note in the completion tune, or -1 if it hasn't sounded.
func _sung_age(segment: int) -> float:
	if _completion_time < 0.0:
		return -1.0
	var start: float = song_order(_map()).find(segment) * string_step(_map())
	return _completion_time - start if _completion_time >= start else -1.0


## A string just sung: C0, pushed across itself by the standing wave.
func _draw_vibrating(segment: int, pixels: Array[Vector2i], age: float) -> void:
	var ends: Array[Vector2i] = _map().segment_ends(segment)
	var along: Vector2i = ends[1] - ends[0]
	var across := Vector2i(1, 0) if absi(along.y) > absi(along.x) else Vector2i(0, 1)
	for i: int in pixels.size():
		_dot(pixels[i] + across * vibration(i, pixels.size(), age), Palette.C0)


## The map's painting, as far as it has formed from the stars (Apparition): what's inside the edge
## in its own colours, the edge C0 at the front and C1 behind; flashing, every pixel C0; then the
## painting itself.
func _draw_figure() -> void:
	var stage: float = figure_stage()
	if stage < 0.0 or not has_painting(_map()):
		return
	var path: String = _map().painting
	var rows: Dictionary = figure_rows(path)
	if stage == 2.0:
		for y: int in rows:
			for x: int in rows[y]:
				_dot(Vector2i(x, y), Palette.C0)
		return
	var art: Texture2D = painting(path)
	if stage >= 3.0:
		draw_texture(art, Vector2.ZERO)
		return
	var forming: Apparition = apparition(_map())
	var radius: int = forming.radius_at(stage)
	draw_texture(forming.formed(radius), Vector2.ZERO)
	var edge: Dictionary[Vector2i, Color] = forming.edge(radius)
	for p: Vector2i in edge:
		_dot(p, edge[p])


func _dot(p: Vector2i, colour: Color) -> void:
	draw_rect(Rect2(Vector2(p), Vector2.ONE), colour)
