class_name ChargeView
extends Node2D
## Aries's ram (chapter 7, a debug trial): its head at the sky's left edge on the lane row, the hoof
## pips counting the launches left until it charges, the lane's hoof-print track, and the charge
## itself. Owns no rules: RunState.ram says where and when; Sky plays ram_charged here.
## Look (the approved step A mock-up, ram A): a pale frontal ram's head with curled horns (M6, M4,
## M5, ember eyes), its left edge a pixel in from the sky's, the lane row through its muzzle. Under
## it, one hoof pip per launch of the clock: a lit one (a launch still to come before the charge) is
## a filled M6 cloven pair, a spent one an M4 outline (no pips when it charges after every launch). The lane shows as a sparse track of cloven
## hoof prints (N7) every PRINT_STEP px just outside its top and bottom edges, the two rows
## staggered, with no line; a print within PRINT_PAD px of a star is left out.
## While the next launch charges and nothing is playing (`settled`), the charge's outcome shows on
## the stars standing now (RunState.charge_preview): a crawling ember ring (HarvestView's) round each
## star it would butt out of the sky, and four C1 corner dots where each star it would stop against a
## landmark comes to rest, with a dotted C2 tick from the star to them. A fleeced star wears a solid
## gold ring (C1 over the top, C2 under) until it's linked or lost (while something plays, only one
## still standing in the run keeps it).
## The charge plays in two beats (charge_hold):
## - rear (REAR_TIME): the pips are spent, the ram rears up LIFT px, its hooves kick up dust and the
##   prints shift as it stamps; the stars it will take still wear their rings, and the corner dots
##   still show where each it fleeces will stop;
## - charge (CHARGE_TIME): the head lunges LUNGE px and a cloud of hoof dust (N7, N6, M4) streaks along
##   the lane from it to the far edge, fast then slowing, never over a star or a landmark; the stars
##   it butts drift right; one stopped against a landmark flashes a C0 ring for FLASH_TIME as it stops
##   (held for) and keeps its gold ring; one butted out of the
##   sky cuts out at the far edge in ember sparks (C3, S4, S3) over LOSS_TIME (not waited for).

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
## The fleece preview's corner dots and tick, and a fleeced star's ring.
const STOP_COLOUR: Color = Palette.C1
const TICK_COLOUR: Color = Palette.C2
## The charge's beats: the rear, then the charge (both waited for); the sparks of a lost star, and
## the C0 flash of one stopped against a landmark.
const REAR_TIME: float = 0.15
const CHARGE_TIME: float = 0.35
const LOSS_TIME: float = 0.3
const FLASH_TIME: float = 0.1
## The ram rears up LIFT px, then lunges LUNGE px as it charges.
const LIFT: int = 3
const LUNGE: int = 10
## The dust cloud: a puff every DUST_STEP px along the lane, at most DUST_TRAIL px behind its front.
const DUST: Array[Color] = [Palette.N7, Palette.N6, Palette.M4]
const DUST_STEP: int = 6
const DUST_TRAIL: int = 110
## The sparks a lost star cuts out in.
const SPARKS: int = 8

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
## (id -> position, and their sizes), the fleeced ones, and whether the next launch charges (its
## outcome on the stars standing).
var _row: int = 0
var _lit: int = 0
var _stars: Dictionary[int, Vector2i] = {}
var _sizes: Dictionary[int, int] = {}
var _fleeced: Array[int] = []
var _preview: StarCharge.Charge = StarCharge.Charge.new()
## The charge playing: the seconds since it began (-1: none), its row, its moves and the stars it
## fleeced.
var _age: float = -1.0
var _play_row: int = 0
var _moves: Array[StarCurrent.Move] = []
var _play_fleeced: Array[int] = []
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
	_play_fleeced.clear()
	_stars.clear()
	_sizes.clear()
	_fleeced.clear()
	_preview = StarCharge.Charge.new()
	visible = has_ram()
	set_process(visible)
	_follow_run()
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## Whether this run has the ram.
func has_ram() -> bool:
	return _run != null and _run.ram != null


## The lane row shown.
func row() -> int:
	return _play_row if is_charging() else _row


## The pips shown lit.
func lit_pips() -> int:
	return 0 if is_charging() else _lit


## Whether the charge's outcome shows on the stars (the next launch charges and nothing plays).
func cues_shown() -> bool:
	return has_ram() and settled and not is_charging() and (not _preview.lost().is_empty() or not _preview.fleeced.is_empty())


## The ram charges its lane at `charge_row`: `moves` are the stars it butts (a lost one drained),
## `fleeced` the ones a landmark stopped, `sizes` the size of each star shown (id -> Star.Size, the
## launch's new stars too). Sky drifts the stars; this plays the ram.
func charge(charge_row: int, moves: Array[StarCurrent.Move], fleeced: Array[int], sizes: Dictionary[int, int] = {}) -> void:
	_sizes.merge(sizes, true)
	for move: StarCurrent.Move in moves:
		if not _stars.has(move.star_id):
			_stars[move.star_id] = move.from
	_play_row = charge_row
	_moves = moves
	_play_fleeced = fleeced
	_age = 0.0
	_preview = StarCharge.Charge.new()
	queue_redraw()


func is_charging() -> bool:
	return _age >= 0.0


## How long the charge is waited for: its rear and its charge, or until the flash of a star stopped
## against a landmark is over if that's later (a lost star's sparks aren't waited for).
static func charge_hold() -> float:
	return maxf(REAR_TIME + CHARGE_TIME, REAR_TIME + StarView.DRIFT_TIME + FLASH_TIME)


## A star butted out of the sky cuts out at `at`, the far edge, in sparks.
func flash_loss(at: Vector2i) -> void:
	_losses[at] = 0.0
	queue_redraw()


## Where a star butted toward `to` (past the far edge) leaves the sky: a pixel past the inner sky.
func exit_point(to: Vector2i) -> Vector2i:
	var inner: Rect2i = StarScatter.inner_rect(_run.sky_rect)
	return Vector2i(mini(to.x, inner.end.x), to.y)


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
	if _age >= 0.0:
		_age += delta
		if _age >= charge_hold():
			_age = -1.0
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
		result.merge(print_pixels(_row, _run.ram.lane, _keep_clear(), _run.sky_rect, 0), true)
		result.merge(_clipped(head_pixels(_row, _run.sky_rect), _keep_clear(), HEAD_PAD), true)
		result.merge(pip_pixels(_row, _run.sky_rect, _run.ram.every, _lit), true)
		if cues_shown():
			result.merge(_cue_pixels(), true)
		for id: int in _fleeced:
			if _stars.has(id) and (settled or _run.find_star(id) != null):
				result.merge(fleece_ring_pixels(_stars[id], _sizes[id]), true)
	for at: Vector2i in _losses:
		result.merge(spark_pixels(at, _losses[at] / LOSS_TIME, at.y), true)
	var sky: Rect2i = _run.sky_rect
	for point: Vector2i in result.keys():
		if not sky.has_point(point):
			result.erase(point)
	return result


## The outcome of the coming charge on the stars standing: an ember ring on each it loses (clipped
## where it would run into a neighbour's), corner dots where each it fleeces stops.
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
	var destinations: Dictionary[int, Vector2i] = _preview.destinations()
	for id: int in _preview.fleeced:
		if _stars.has(id):
			result.merge(fleece_preview_pixels(_stars[id], destinations.get(id, _stars[id]), _sizes[id]), true)
	return result


## The charge playing: the ram rearing, then charging with its dust; the stars it butts.
func _charge_pixels() -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var sky: Rect2i = _run.sky_rect
	var lane: int = _run.ram.lane
	var moved: Dictionary[int, StarCurrent.Move] = {}
	for move: StarCurrent.Move in _moves:
		moved[move.star_id] = move
	var stopped: bool = _age >= REAR_TIME + StarView.DRIFT_TIME
	if _age < REAR_TIME:
		# The rear: pips spent, the head up, dust at its feet, the prints stamped along; the stars it
		# takes still ringed.
		result.merge(print_pixels(_play_row, lane, _keep_clear(), sky, 1), true)
		result.merge(_clipped(head_pixels(_play_row, sky, LIFT), _keep_clear(), HEAD_PAD), true)
		result.merge(pip_pixels(_play_row, sky, _run.ram.every, 0), true)
		var origin: Vector2i = head_origin(_play_row, sky)
		var i: int = 0
		for x: int in range(origin.x + 3, origin.x + head_size().x - 2, 4):
			result.merge(dust_pixels(Vector2i(x + 4, origin.y + head_size().y + 5), 0.3, i), true)
			i += 1
		for move: StarCurrent.Move in _moves:
			if not _sizes.has(move.star_id):
				continue
			if move.drained:
				result.merge(HarvestView.lone_ring_pixels(move.from, _sizes[move.star_id], _time * 3.0), true)
			elif _play_fleeced.has(move.star_id):
				result.merge(fleece_preview_pixels(move.from, move.to, _sizes[move.star_id]), true)
	else:
		var k: float = (_age - REAR_TIME) / CHARGE_TIME
		result.merge(rush_pixels(_play_row, lane, sky, k, _keep_clear() + _paths_clear()), true)
		result.merge(_clipped(head_pixels(_play_row, sky, 0, LUNGE if k < 0.7 else LUNGE / 2), _keep_clear(), HEAD_PAD), true)
		result.merge(pip_pixels(_play_row, sky, _run.ram.every, 0), true)
	# The fleeced stars: those that stand still keep their rings; those it moves show theirs as they stop.
	for id: int in _fleeced:
		if _stars.has(id) and not moved.has(id):
			result.merge(fleece_ring_pixels(_stars[id], _sizes[id]), true)
	if stopped:
		# Every star has come to rest where the run has it.
		for id: int in _fleeced + _play_fleeced:
			var star: Star = _run.find_star(id)
			if star != null and (moved.has(id) or _play_fleeced.has(id)):
				result.merge(fleece_ring_pixels(star.position, star.size), true)
		if _age < REAR_TIME + StarView.DRIFT_TIME + FLASH_TIME:
			for id: int in _play_fleeced:
				var star: Star = _run.find_star(id)
				if star != null:
					result.merge(flash_pixels(star.position, star.size), true)
	return result


## The ram's head's top-left for the lane row `lane_row` in `sky`, `lift` px up and `lunge` px on.
static func head_origin(lane_row: int, sky: Rect2i, lift: int = 0, lunge: int = 0) -> Vector2i:
	return Vector2i(sky.position.x + 1 + lunge, lane_row - HEAD_ABOVE - lift)


static func head_size() -> Vector2i:
	return Vector2i(HEAD[0].length(), HEAD.size())


static func head_pixels(lane_row: int, sky: Rect2i, lift: int = 0, lunge: int = 0) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	_blit(result, HEAD, head_origin(lane_row, sky, lift, lunge), HEAD_COLOURS)
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
## the sky and falling (S4, S3, a C3 core at first), scattered by `seed`.
static func spark_pixels(at: Vector2i, k: float, seed_value: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for i: int in SPARKS:
		var a: float = float((seed_value * 13 + i * 29) % 17) / 16.0
		var dx: int = -int(1.0 + a * 9.0 * (0.5 + k))
		var dy: int = int((i - 3.5) * 1.5 * (0.6 + k) + 6.0 * k * k)
		var colour: Color = Palette.C3 if i == 0 and k < 0.5 else (Palette.S4 if i % 2 == 0 else Palette.S3)
		result[at + Vector2i(dx, dy)] = colour
	return result


## A fleeced star's ring: solid, 3 px clear of the star, C1 over the top and C2 under.
static func fleece_ring_pixels(at: Vector2i, size: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for offset: Vector2i in ConstellationView.circle_pixels(StarView.half_extent(size as Star.Size) + 3):
		result[at + offset] = STOP_COLOUR if offset.y < 0 else TICK_COLOUR
	return result


## A star at `at` the charge will stop against a landmark at `stop`: four C1 corner dots round the
## stop, and a dotted C2 tick running to them from the star, under its path.
static func fleece_preview_pixels(at: Vector2i, stop: Vector2i, size: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	var half: int = StarView.half_extent(size as Star.Size)
	var corner: int = half + 1
	for dx: int in [-corner, corner]:
		for dy: int in [-corner, corner]:
			result[stop + Vector2i(dx, dy)] = STOP_COLOUR
	for x: int in range(at.x + half + 2, stop.x - corner, 2):
		result[Vector2i(x, stop.y + corner + 1)] = TICK_COLOUR
	return result


## The C0 flash of a star stopping against a landmark: a dotted ring 5 px clear of it.
static func flash_pixels(at: Vector2i, size: int) -> Dictionary[Vector2i, Color]:
	var result: Dictionary[Vector2i, Color] = {}
	for offset: Vector2i in ConstellationView.circle_pixels(StarView.half_extent(size as Star.Size) + 5):
		if posmod(offset.x + offset.y, 2) == 0:
			result[at + offset] = Palette.C0
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
		for x: int in range(move.from.x, move.to.x, 4):
			result.append(Vector3i(x, move.from.y, half))
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
	var fleeced: Array[int] = _run.ram.fleeced.duplicate()
	if _run.ram.row == _row and lit == _lit and stars == _stars and sizes == _sizes and fleeced == _fleeced:
		return
	_row = _run.ram.row
	_lit = lit
	_stars = stars
	_sizes = sizes
	_fleeced = fleeced
	_preview = _run.charge_preview()
	queue_redraw()
