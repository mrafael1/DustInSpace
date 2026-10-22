class_name ChargeView
extends Node2D
## Aries's ram (chapter 7): its head at the sky's left edge on the lane row, the hoof pips counting
## the launches left until it charges, the lane's hoof-print track, and the charge itself. Owns no
## rules: RunState.ram says where and when; Sky plays ram_charged here.
## Look (the approved step A mock-up, ram A, made bigger in playtest): a pale frontal ram's head with
## curled horns (M6, M4, M5, ember eyes), its left edge a pixel in from the sky's, the lane row
## through its muzzle; stars and landmarks show in front of it. A ram that charges from the right
## stands at the right edge: everything of its own (head, prints, pips, dust) is drawn as from the
## left and mirrored across the sky (the head is symmetric). The Fleece's second ram stands at the
## sky's top, upright, the lane column through its muzzle: its prints and dust are drawn as from
## the left and turned down the sky (x and y swapped). Of two rams, the one charging next is shown
## (its prints too); the other waits, dimmed (M4, M3), with no prints. When a lane moves, its ram
## (and prints) slides there, easing in over about 0.3 s, never jumping. Under it, one hoof pip per launch of
## the clock: a lit one (a launch still to come before the charge) is a filled M6 cloven pair, a spent
## one an M4 outline (no pips when it charges after every launch). The lane shows as a sparse track of
## cloven hoof prints (N7) every PRINT_STEP px just outside its top and bottom edges, the two rows
## staggered, with no line; a print within PRINT_PAD px of a star is left out.
## While the next launch charges and nothing is playing (`settled`), the charge's outcome shows on
## the stars standing now (RunState.charge_preview): a crawling ember ring (HarvestView's) round each
## star it would butt out of the sky.
## The charge plays in two beats (charge_hold):
## - rear (REAR_TIME): the pips are spent, the ram rears up LIFT px, its hooves kick up dust and the
##   prints shift as it stamps; the stars it will take still wear their rings;
## - charge (CHARGE_TIME): the head lunges LUNGE px and a cloud of hoof dust (N7, N6, M4) streaks along
##   the lane from it to the far edge in three rows, fast then slowing, never over a star or a
##   landmark; the stars it butts drift right; one butted out of the sky cuts out at the far edge in
##   ember sparks (C3, S4, S3) over LOSS_TIME (not waited for).
## A ram that charges harder (the Head) is heated: its horns ember (S4, S3) and its hoof prints and
## dust ember too (S4, S3, S2), so the harder push shows before it charges; its face stays pale.
## A wide sky: everything above is drawn against the run's frame (RunState.frame_rect), not the sky,
## so the ram stands at the frame's edge and its dust runs to the frame's far side.

## The ram's head, frontal: H horn light, h horn dark, F face, f face shade, E eye, n nostril.
const HEAD: Array[String] = [
	"...hhhhh.........hhhhh...",
	"..hHHHHHhh.....hhHHHHHh..",
	".hHh...hHHhhFhhHHh...hHh.",
	"hHh.hhh.hHHFFFHHh.hhh.hHh",
	"hH.hHHHh.hHFFFHh.hHHHh.Hh",
	"hH.hH..Hh.hFFFh.hH..Hh.Hh",
	"hH..hh.Hh.fFFFf.hH.hh..Hh",
	".hH....Hh.fFFFf.hH....Hh.",
	"..hHHHHh.EfFFFfE.hHHHHh..",
	"...hhhh...fFFFf...hhhh...",
	"..........fFFFf..........",
	"...........FFF...........",
	"...........fFf...........",
	"...........fFf...........",
	"...........fnf...........",
]
const HEAD_COLOURS: Dictionary[String, Color] = {
	"H": Palette.M6, "h": Palette.M4, "F": Palette.M5, "f": Palette.M4, "E": Palette.S4, "n": Palette.M3,
}
## A ram waiting for its turn: dimmed.
const WAIT_HEAD_COLOURS: Dictionary[String, Color] = {
	"H": Palette.M4, "h": Palette.M3, "F": Palette.M3, "f": Palette.M3, "E": Palette.S2, "n": Palette.M2,
}
## The heated ram's: ember horns round the pale face.
const HARD_HEAD_COLOURS: Dictionary[String, Color] = {
	"H": Palette.S4, "h": Palette.S3, "F": Palette.M5, "f": Palette.M4, "E": Palette.S4, "n": Palette.M3,
}
## Its prints and dust: each cool colour of the trail and its ember.
const HARD_TRAIL: Dictionary[Color, Color] = {Palette.N7: Palette.S4, Palette.N6: Palette.S3, Palette.M4: Palette.S2}
## The head's top-left is this far up from the lane row.
const HEAD_ABOVE: int = 10
## The head is left out within this many px of a star or landmark, so they show in front of it.
const HEAD_PAD: int = 1
## A hoof pip: two 3x3 toes with a 1 px cleft, filled when lit, an outline when spent.
const PIP_LIT: Array[String] = ["XXX.XXX", "XXX.XXX", "XXX.XXX"]
const PIP_SPENT: Array[String] = ["XXX.XXX", "X.X.X.X", "XXX.XXX"]
const PIP_ON: Color = Palette.M6
const PIP_OFF: Color = Palette.M4
## The pips sit a pixel under the head, PIP_STEP px apart, the first a pixel left of the head.
const PIP_STEP: int = 12
## A hoof print on the lane's edge: a cloven pair.
const PRINT: Array[String] = ["X.X", "X.X"]
const PRINT_COLOUR: Color = Palette.N7
const PRINT_STEP: int = 14
## A print is left out within this many px of a star's sprite.
const PRINT_PAD: int = 4
## The charge's beats: the rear, then the charge (both waited for); the sparks of a lost star.
const REAR_TIME: float = 0.15
const CHARGE_TIME: float = 0.35
const LOSS_TIME: float = 0.3
## The ram rears up LIFT px, then lunges LUNGE px as it charges.
const LIFT: int = 3
const LUNGE: int = 10
## The dust cloud: a puff every DUST_STEP px along the lane, at most DUST_TRAIL px behind its front.
const DUST: Array[Color] = [Palette.N7, Palette.N6, Palette.M4]
const DUST_STEP: int = 6
const DUST_TRAIL: int = 110
## The sparks a lost star cuts out in.
const SPARKS: int = 8
## How fast a ram slides to its lane's new line: the gap left shrinks by this rate a second (eased
## out, about 0.3 s to settle), snapping home within half a px.
const SLIDE_RATE: float = 14.0

## Nothing is playing (Main sets it each frame): what shows follows the run.
var settled: bool = true:
	set(value):
		settled = value
		if settled:
			_follow_run()

var _run: RunState
## Seconds shown, for the rings' crawl.
var _time: float = 0.0
## What shows, as the run had it when last settled: the lane row, the lit pips, the stars standing
## (id -> position, and their sizes), and what the next launch's charge does to them.
var _row: int = 0
var _column: int = 0
## Where each ram is drawn, sliding toward its lane's row and column.
var _shown_row: float = 0.0
var _shown_column: float = 0.0
var _way: Vector2i = StarCharge.WAY
var _lit: int = 0
var _stars: Dictionary[int, Vector2i] = {}
var _sizes: Dictionary[int, int] = {}
var _preview: StarCharge.Charge = StarCharge.Charge.new()
## The charge playing: the seconds since it began (-1: none), its row and its moves.
var _age: float = -1.0
var _play_row: int = 0
var _play_way: Vector2i = StarCharge.WAY
var _moves: Array[StarCurrent.Move] = []
## Stars lost off the far edge cutting out: where, and the seconds since.
var _losses: Dictionary[Vector2i, float] = {}


func _ready() -> void:
	set_process(has_ram())


func setup(run: RunState) -> void:
	_run = run
	_age = -1.0
	_time = 0.0
	_losses.clear()
	_moves.clear()
	_stars.clear()
	_sizes.clear()
	_preview = StarCharge.Charge.new()
	visible = has_ram()
	set_process(visible)
	_follow_run()
	_shown_row = _row
	_shown_column = _column
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## Whether this run has the ram.
func has_ram() -> bool:
	return _run != null and _run.ram != null


## The lane row shown.
func row() -> int:
	return _play_row if is_charging() else _row


## The lane's line shown: its row, or its column for a ram charging down.
func line() -> int:
	if is_charging():
		return _play_row
	return _column if _way.y != 0 else _row


## Where the ram running `way` is drawn now, sliding to its lane's line: its row, or its column.
func drawn_line(way: Vector2i) -> int:
	return roundi(_shown_column if way.y != 0 else _shown_row)


## Whether a ram is still sliding to its lane.
func is_sliding() -> bool:
	return drawn_line(Vector2i.RIGHT) != _row or drawn_line(Vector2i.DOWN) != _column


## Whether the ram charges harder on this stage (heated: ember horns, prints and dust).
func is_hard() -> bool:
	return has_ram() and _run.scorpio.map.ram_hard


## The way the ram shown charges (right: it stands at the left edge).
func way() -> Vector2i:
	return _play_way if is_charging() else _way


## The pips shown lit.
func lit_pips() -> int:
	return 0 if is_charging() else _lit


## Whether the charge's outcome shows on the stars (the next launch charges and nothing plays).
func cues_shown() -> bool:
	return has_ram() and settled and not is_charging() and not _preview.lost().is_empty()


## The ram charges its lane at `charge_row` (its column, running down), running `way`: `moves` are the stars it butts (a lost
## one drained), `sizes` the size of each star shown (id -> Star.Size, the launch's new stars too).
## Sky drifts the stars; this plays the ram.
func charge(charge_row: int, moves: Array[StarCurrent.Move], way: Vector2i = StarCharge.WAY, sizes: Dictionary[int, int] = {}) -> void:
	_sizes.merge(sizes, true)
	for move: StarCurrent.Move in moves:
		if not _stars.has(move.star_id):
			_stars[move.star_id] = move.from
	_play_row = charge_row
	_play_way = way
	# It charges from its lane (where it has slid by now, as a launch comes after the link).
	if way.y != 0:
		_shown_column = charge_row
	else:
		_shown_row = charge_row
	_moves = moves
	_age = 0.0
	_preview = StarCharge.Charge.new()
	queue_redraw()


func is_charging() -> bool:
	return _age >= 0.0


## How long the charge is waited for: its rear and its charge, or until the stars it butts have
## drifted to a stop if that's later (a lost star's sparks aren't waited for).
static func charge_hold() -> float:
	return maxf(REAR_TIME + CHARGE_TIME, REAR_TIME + StarView.DRIFT_TIME)


## A star butted out of the sky cuts out at `at`, the far edge, in sparks.
func flash_loss(at: Vector2i) -> void:
	_losses[at] = 0.0
	queue_redraw()


## Where a star butted toward `to` (past the frame's far edge) leaves: `to` itself while it's over
## the sky it plays in (launch_rect: the phone box on a wide sky, docs/wide_sky_design.md §9), else a
## pixel past its inner rect, as at a phone's screen edge.
func exit_point(to: Vector2i) -> Vector2i:
	var inner: Rect2i = StarScatter.inner_rect(_run.launch_rect())
	return Vector2i(clampi(to.x, inner.position.x - 1, inner.end.x), clampi(to.y, inner.position.y - 1, inner.end.y))


## Plays the charge and the sparks, and crawls the rings. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	var crawl: int = floori(_time / HarvestView.CRAWL_STEP)
	_time += delta
	if floori(_time / HarvestView.CRAWL_STEP) != crawl and not _preview.moves.is_empty():
		queue_redraw()
	for at: Vector2i in _losses.keys():
		_losses[at] += delta
		if _losses[at] >= LOSS_TIME:
			_losses.erase(at)
		queue_redraw()
	if is_sliding():
		var keep: float = exp(-SLIDE_RATE * delta)
		_shown_row = _row + (_shown_row - _row) * keep
		_shown_column = _column + (_shown_column - _column) * keep
		if absf(_shown_row - _row) < 0.5:
			_shown_row = _row
		if absf(_shown_column - _column) < 0.5:
			_shown_column = _column
		queue_redraw()
	if _age >= 0.0:
		_age += delta
		if _age >= charge_hold():
			_age = -1.0
			# The next ram in turn is shown at once (an intro's next round too); the rest once settled.
			var ways: Array[Vector2i] = _run.ram.ways
			_way = ways[(ways.find(_play_way) + 1) % ways.size()]
			if settled:
				_follow_run()
		queue_redraw()


func _draw() -> void:
	var dots: Dictionary[Vector2i, Color] = pixels()
	for point: Vector2i in dots:
		draw_rect(Rect2(Vector2(point), Vector2.ONE), dots[point], true)


func pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if not has_ram():
		return result
	if is_charging():
		result.merge(_charge_pixels(), true)
	else:
		var sky: Rect2i = _run.frame_rect
		var frame: Rect2i = _frame_sky(sky, _way)
		var clear: Array[Vector3i] = _framed(_keep_clear(), sky, _way)
		result.merge(_waiting_head(_way), true)
		var at: int = drawn_line(_way)
		var own: Dictionary[Vector2i, Color] = _trail(print_pixels(at, _run.ram.lane, clear, frame, 0))
		own.merge(pip_pixels(at, frame, _run.ram.every, _lit), true)
		result.merge(_framed_pixels(own, sky, _way), true)
		result.merge(_head(_way, at, 0, 0, _head_colours()), true)
		if cues_shown():
			result.merge(_cue_pixels(), true)
	var sky: Rect2i = _run.frame_rect
	var inner: Rect2i = StarScatter.inner_rect(sky)
	for at: Vector2i in _losses:
		# The sparks spray back into the sky from the edge the star left by.
		var back: Vector2i = Vector2i.LEFT if at.x >= sky.get_center().x else Vector2i.RIGHT
		if at.y >= inner.end.y:
			back = Vector2i.UP
		result.merge(spark_pixels(at, _losses[at] / LOSS_TIME, at.y, back), true)
	for point: Vector2i in result.keys():
		if not _run.sky_rect.has_point(point):
			result.erase(point)
	return result


## The outcome of the coming charge on the stars standing: an ember ring on each it loses (clipped
## where it would run into a neighbour's).
func _cue_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var lost: Array[int] = _preview.lost()
	var ringed: Array[Vector3i] = []
	for id: int in lost:
		if _stars.has(id):
			ringed.append(Vector3i(_stars[id].x, _stars[id].y, ring_radius(_sizes[id])))
	for id: int in lost:
		if not _stars.has(id):
			continue
		var at: Vector2i = _stars[id]
		var ring: Dictionary[Vector2i, Color] = HarvestView.lone_ring_pixels(at, _sizes[id], _time)
		for point: Vector2i in ring:
			var clear: bool = true
			for other: Vector3i in ringed:
				if Vector2i(other.x, other.y) != at and Vector2(point).distance_to(Vector2(other.x, other.y)) < other.z + 2.5:
					clear = false
			if clear:
				result[point] = ring[point]
	return result


## The charge playing: the ram rearing, then charging with its dust; the stars it butts.
func _charge_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var sky: Rect2i = _run.frame_rect
	var lane: int = _run.ram.lane
	# The ram's own pixels, drawn as from the left and mirrored for a charge from the right.
	var own: Dictionary[Vector2i, Color] = {}
	var frame: Rect2i = _frame_sky(sky, _play_way)
	var clear: Array[Vector3i] = _framed(_keep_clear(), sky, _play_way)
	var head: Dictionary[Vector2i, Color] = {}
	result.merge(_waiting_head(_play_way), true)
	if _age < REAR_TIME:
		# The rear: pips spent, the head up, dust at its feet, the prints stamped along; the stars it
		# takes still ringed.
		own.merge(_trail(print_pixels(_play_row, lane, clear, frame, 1)), true)
		head = _head(_play_way, _play_row, LIFT, 0, _head_colours())
		own.merge(pip_pixels(_play_row, frame, _run.ram.every, 0), true)
		var origin: Vector2i = head_origin(_play_row, frame)
		var i: int = 0
		for x: int in range(origin.x + 3, origin.x + head_size().x - 2, 4):
			own.merge(_trail(dust_pixels(Vector2i(x + 4, origin.y + head_size().y + 5), 0.3, i)), true)
			i += 1
		for move: StarCurrent.Move in _moves:
			if not _sizes.has(move.star_id):
				continue
			if move.drained:
				result.merge(HarvestView.lone_ring_pixels(move.from, _sizes[move.star_id], _time * 3.0), true)
	else:
		var k: float = (_age - REAR_TIME) / CHARGE_TIME
		own.merge(_trail(rush_pixels(_play_row, lane, frame, k, clear + _framed(_paths_clear(), sky, _play_way))), true)
		head = _head(_play_way, _play_row, 0, LUNGE if k < 0.7 else LUNGE / 2, _head_colours())
		own.merge(pip_pixels(_play_row, frame, _run.ram.every, 0), true)
	result.merge(_framed_pixels(own, sky, _play_way), true)
	result.merge(head, true)
	return result


## The ram charging `way`'s head on its lane's `charge_line`, reared `lift` and lunged `lunge` px, in
## `colours`, where it shows: one across the sky at its edge (mirrored from the right); one charging
## down at the top, upright. Left out next to a star or landmark.
func _head(way: Vector2i, charge_line: int, lift: int, lunge: int, colours: Dictionary[String, Color]) -> Dictionary[Vector2i, Color]:
	var sky: Rect2i = _run.frame_rect
	var result: Dictionary[Vector2i, Color] = {}
	if way.y != 0:
		_blit(result, HEAD, down_head_origin(charge_line, sky, lift, lunge), colours)
	else:
		_blit(result, HEAD, head_origin(charge_line, sky, lift, lunge), colours)
		result = _framed_pixels(result, sky, way)
	return _clipped(result, _keep_clear(), HEAD_PAD)


## The head of the ram not charging `way` (of two), dimmed on its own lane's line; none for one ram.
func _waiting_head(way: Vector2i) -> Dictionary[Vector2i, Color]:
	for other: Vector2i in _run.ram.ways:
		if other != way:
			return _head(other, drawn_line(other), 0, 0, WAIT_HEAD_COLOURS)
	return {}


func _head_colours() -> Dictionary[String, Color]:
	return HARD_HEAD_COLOURS if is_hard() else HEAD_COLOURS


## The sky as the ram running `way` draws its own pixels, as from the left: turned for one charging
## down (x and y swapped).
static func _frame_sky(sky: Rect2i, way: Vector2i) -> Rect2i:
	if way.y != 0:
		return Rect2i(sky.position.y, sky.position.x, sky.size.y, sky.size.x)
	return sky


## The ram's prints or dust `pixels`, in ember for a heated ram.
func _trail(pixels: Dictionary[Vector2i, Color]) -> Dictionary[Vector2i, Color]:
	if not is_hard():
		return pixels
	for point: Vector2i in pixels:
		pixels[point] = HARD_TRAIL.get(pixels[point], pixels[point])
	return pixels


## `spots` (x, y, half extent) as the ram running `way` sees them: mirrored across `sky` for a charge
## from the right, turned (x and y swapped) for one down, as they are for one from the left.
static func _framed(spots: Array[Vector3i], sky: Rect2i, way: Vector2i) -> Array[Vector3i]:
	if way.x > 0:
		return spots
	var result: Array[Vector3i] = []
	for spot: Vector3i in spots:
		if way.y != 0:
			result.append(Vector3i(spot.y, spot.x, spot.z))
		else:
			result.append(Vector3i(sky.position.x + sky.end.x - 1 - spot.x, spot.y, spot.z))
	return result


## The ram's own `pixels`, drawn as from the left, where they show for one running `way`.
static func _framed_pixels(pixels: Dictionary[Vector2i, Color], sky: Rect2i, way: Vector2i) -> Dictionary[Vector2i, Color]:
	if way.x > 0:
		return pixels
	var result: Dictionary[Vector2i, Color] = {}
	for point: Vector2i in pixels:
		if way.y != 0:
			result[Vector2i(point.y, point.x)] = pixels[point]
		else:
			result[Vector2i(sky.position.x + sky.end.x - 1 - point.x, point.y)] = pixels[point]
	return result


## The ram's head's top-left for the lane row `lane_row` in `sky`, `lift` px up and `lunge` px on.
static func head_origin(lane_row: int, sky: Rect2i, lift: int = 0, lunge: int = 0) -> Vector2i:
	return Vector2i(sky.position.x + 1 + lunge, lane_row - HEAD_ABOVE - lift)


## The head's top-left for a ram charging down the lane `column`: upright at the sky's top, the
## column through its muzzle, LIFT px down so it has room to rear.
static func down_head_origin(column: int, sky: Rect2i, lift: int = 0, lunge: int = 0) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(column - HEAD[0].length() / 2, sky.position.y + 1 + LIFT - lift + lunge)


static func head_size() -> Vector2i:
	return Vector2i(HEAD[0].length(), HEAD.size())


## The head (heated, `hard`: ember horns).
static func head_pixels(lane_row: int, sky: Rect2i, lift: int = 0, lunge: int = 0, hard: bool = false) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	_blit(result, HEAD, head_origin(lane_row, sky, lift, lunge), HARD_HEAD_COLOURS if hard else HEAD_COLOURS)
	return result


## One pip per launch of the clock (`every`) under the head, the first `lit` lit; none when it
## charges after every launch (there's nothing to count).
static func pip_pixels(lane_row: int, sky: Rect2i, every: int, lit: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	if every <= 1:
		return result
	var origin: Vector2i = head_origin(lane_row, sky)
	for i: int in every:
		var on: bool = i < lit
		_blit(result, PIP_LIT if on else PIP_SPENT, Vector2i(origin.x - 1 + i * PIP_STEP, origin.y + head_size().y + 1), {"X": PIP_ON if on else PIP_OFF})
	return result


## The lane's hoof-print track for the lane `lane` px tall on `lane_row`: a print every PRINT_STEP
## px just outside its top and bottom edges, the bottom row half a step on, `stamp` steps of 2 px
## along; none within PRINT_PAD px of a star in `clear` (x, y, half extent each).
static func print_pixels(lane_row: int, lane: int, clear: Array[Vector3i], sky: Rect2i, stamp: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	@warning_ignore("integer_division")
	var top: int = lane_row - lane / 2
	var start: int = head_origin(lane_row, sky).x - 1 + head_size().x + 3
	for edge: int in 2:
		var y: int = top - 2 if edge == 0 else top + lane
		@warning_ignore("integer_division")
		var x: int = start + stamp * 2 + edge * (PRINT_STEP / 2)
		while x + 2 < sky.end.x:
			if not _near_star(Rect2i(x, y, 3, 2), clear):
				_blit(result, PRINT, Vector2i(x, y), {"X": PRINT_COLOUR})
			x += PRINT_STEP
	return result


## The charge `k` (0 to 1) of the way: hoof dust streaking in three rows (its edges and, thickest,
## the lane row) from the ram along the lane to its front,
## fast then slowing, thinning out DUST_TRAIL px behind it; no speck within PRINT_PAD px of a star or
## landmark in `clear` (x, y, half extent each).
static func rush_pixels(lane_row: int, lane: int, sky: Rect2i, k: float, clear: Array[Vector3i] = []) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	@warning_ignore("integer_division")
	var top: int = lane_row - lane / 2
	var bottom: int = top + lane - 1
	var start: int = head_origin(lane_row, sky).x + head_size().x + 8
	var front: int = start + roundi(SeamView.rush_reach(k) * (sky.end.x - start))
	for x: int in range(start, front, DUST_STEP):
		if front - x > DUST_TRAIL:
			continue
		@warning_ignore("integer_division")
		var step: int = (x - sky.position.x) / DUST_STEP
		result.merge(dust_pixels(Vector2i(x, bottom - 2 - step % 3), 0.6, x), true)
		result.merge(dust_pixels(Vector2i(x + 2, lane_row + 1 - step % 2), 0.9, x + 2), true)
		result.merge(dust_pixels(Vector2i(x + 3, top + 4 + step % 2), 0.2, x + 1), true)
	for point: Vector2i in result.keys():
		if _near_star(Rect2i(point, Vector2i.ONE), clear):
			result.erase(point)
	return result


## A puff of hoof dust kicked up and back from `at`, `k` (0 to 1) grown: five cool specks in hard
## steps (no fades), scattered by `seed` (no random numbers drawn).
static func dust_pixels(at: Vector2i, k: float, seed_value: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in 5:
		var a: float = float((seed_value * 37 + i * 71) % 100) / 100.0
		var dx: int = -int(2.0 + a * 6.0 * (1.0 + k))
		var dy: int = -int(float(i % 3) + k * 2.0) + 1
		result[at + Vector2i(dx, dy)] = DUST[(i + seed_value) % 3]
	return result


## A star cutting out at `at` on the far edge, `k` (0 to 1) through: ember sparks spraying back into
## the sky (`back`: left from the right edge) and falling (S4, S3, a C3 core at first), scattered by
## `seed`.
static func spark_pixels(at: Vector2i, k: float, seed_value: int, back: Vector2i = Vector2i.LEFT) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in SPARKS:
		var a: float = float((seed_value * 13 + i * 29) % 17) / 16.0
		var dx: int = back.x * int(1.0 + a * 9.0 * (0.5 + k))
		var dy: int = int((i - 3.5) * 1.5 * (0.6 + k) + 6.0 * k * k)
		if back.y != 0:
			# Off the bottom: they spray back up, spread across.
			dx = int((i - 3.5) * 1.5 * (0.6 + k))
			dy = back.y * int(1.0 + a * 9.0 * (0.5 + k)) + int(4.0 * k * k)
		var colour: Color = Palette.C3 if i == 0 and k < 0.5 else (Palette.S4 if i % 2 == 0 else Palette.S3)
		result[at + Vector2i(dx, dy)] = colour
	return result


## The ember ring's radius round a star of `size` (HarvestView.lone_ring_pixels's).
static func ring_radius(size: int) -> int:
	return maxi(StarView.half_extent(size as Star.Size) + HarvestView.LONE_GAP, HarvestView.LONE_MIN)


static func _blit(result: Dictionary[Vector2i, Color], art: Array[String], origin: Vector2i, colours: Dictionary) -> void:
	for y: int in art.size():
		for x: int in art[y].length():
			var key: String = art[y][x]
			if colours.has(key):
				result[origin + Vector2i(x, y)] = colours[key]


## `pixels` without those within `pad` px of a star in `clear` (x, y, half extent each).
static func _clipped(pixels: Dictionary[Vector2i, Color], clear: Array[Vector3i], pad: int) -> Dictionary[Vector2i, Color]:
	for point: Vector2i in pixels.keys():
		if _near_star(Rect2i(point, Vector2i.ONE), clear, pad):
			pixels.erase(point)
	return pixels


static func _near_star(area: Rect2i, clear: Array[Vector3i], pad: int = PRINT_PAD) -> bool:
	for spot: Vector3i in clear:
		var reach: int = spot.z + pad
		if Rect2i(spot.x - reach, spot.y - reach, reach * 2 + 1, reach * 2 + 1).intersects(area):
			return true
	return false


## What the prints keep clear of: the stars shown and every landmark (x, y, half extent).
func _keep_clear() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for id: int in _stars:
		result.append(Vector3i(_stars[id].x, _stars[id].y, StarView.half_extent(_sizes[id] as Star.Size)))
	if _run.scorpio != null:
		for i: int in _run.scorpio.map.count():
			var at: Vector2i = _run.scorpio.landmark_position(i)
			result.append(Vector3i(at.x, at.y, StarView.half_extent(_run.scorpio.map.sizes[i] as Star.Size)))
	return result


## What the hoof dust keeps clear of besides: the way each star the charge butts drifts along, a
## spot every 4 px from where it stood to where it stops (x, y, half extent).
func _paths_clear() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for move: StarCurrent.Move in _moves:
		if not _sizes.has(move.star_id):
			continue
		var half: int = StarView.half_extent(_sizes[move.star_id] as Star.Size)
		var step: Vector2i = (move.to - move.from).sign() * 4
		var at: Vector2i = move.from
		while (move.to.x - at.x) * step.x + (move.to.y - at.y) * step.y > 0:
			result.append(Vector3i(at.x, at.y, half))
			at += step
		result.append(Vector3i(move.to.x, move.to.y, half))
	return result


## What shows follows the run as it stands (only called while nothing plays).
func _follow_run() -> void:
	if not has_ram() or is_charging():
		return
	var stars: Dictionary[int, Vector2i] = {}
	var sizes: Dictionary[int, int] = {}
	for star: Star in _run.stars:
		stars[star.id] = star.position
		sizes[star.id] = star.size
	var lit: int = 0 if _run.is_over() else _run.ram.launches_left()
	if _run.ram.row == _row and _run.ram.column == _column and _run.ram.way == _way and lit == _lit and stars == _stars and sizes == _sizes:
		return
	_row = _run.ram.row
	_column = _run.ram.column
	_way = _run.ram.way
	_lit = lit
	_stars = stars
	_sizes = sizes
	_preview = _run.charge_preview()
	queue_redraw()
