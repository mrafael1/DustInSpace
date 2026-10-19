class_name StarCharge
extends RefCounted
## Aries's ram (chapter 7): the ram stands at the sky's left edge, and every `every`-th launch, once
## that launch has fully resolved, it charges right along its lane: the band `lane` px tall centred
## on the lane row, the row of the landmark the last link lit. Every loose star whose centre is in the
## lane is butted `butt` px its `way`, the frontmost first, and on past a star or a landmark it would
## land on: nothing shelters it. With more than one of `ways`, the rams take turns (`turn` after each
## charge): the Fleece's second ram stands at the sky's top and charges down, its lane the band
## `lane` px wide centred on the lane column (the lit landmark's x). One carried out of the sky is
## lost, for nothing. No randomness, nodes or rewards. Its moves are StarCurrent.Moves (a lost one `drained`, `to` where it would have gone,
## past the sky's edge).

## What one charge does to the stars standing in the sky.
class Charge:
	extends RefCounted
	## The stars that move, rightmost first (a lost one `drained`).
	var moves: Array[StarCurrent.Move] = []

	## The ids of the stars this charge loses.
	func lost() -> Array[int]:
		var result: Array[int] = []
		for move: StarCurrent.Move in moves:
			if move.drained:
				result.append(move.star_id)
		return result

	## Where each star this charge moves ends up.
	func destinations() -> Dictionary[int, Vector2i]:
		var result: Dictionary[int, Vector2i] = {}
		for move: StarCurrent.Move in moves:
			result[move.star_id] = move.to
		return result

## The way the ram first charges: from the left edge, right.
const WAY := Vector2i.RIGHT

## It charges on every this-many-th launch.
var every: int
## The lane's breadth across its way, in px.
var lane: int
## How far it butts each star in its lane, in px.
var butt: int
## The lane row: the y a lane across the sky is centred on.
var row: int
## The lane column: the x a lane down the sky is centred on.
var column: int
## The way each charge runs, in turn (right: from the left edge; down: from the top).
var ways: Array[Vector2i] = [WAY]
## The way the next charge runs.
var way: Vector2i = WAY
## Launches thrown since the run began (intros don't count).
var launches: int = 0
var _turn: int = 0


func _init(p_every: int, p_lane: int, p_butt: int, p_row: int, p_ways: Array[Vector2i] = [WAY], p_column: int = 0) -> void:
	every = p_every
	lane = p_lane
	butt = p_butt
	row = p_row
	column = p_column
	ways = p_ways
	way = ways[0]


## The ram charges after the next launch.
func charges_next() -> bool:
	return (launches + 1) % every == 0


## How many launches, the next one included, until the ram charges (1: after the next).
func launches_left() -> int:
	return every - launches % every


## A launch was thrown: returns whether the ram charges now that it has resolved.
func count_launch() -> bool:
	var charges: bool = charges_next()
	launches += 1
	return charges


## A charge is over: the next ram in `ways` takes its turn.
func turn() -> void:
	_turn = (_turn + 1) % ways.size()
	way = ways[_turn]


## The first ram's turn again.
func rewind() -> void:
	_turn = 0
	way = ways[0]


## Whether the next charge runs down the sky (its lane a column) rather than across it.
func is_down() -> bool:
	return way.y != 0


## The lane's centre line across the next charge's way: the lane row, or the column charging down.
func line() -> int:
	return column if is_down() else row


## The lane follows the landmark a link lit, at `y` (and `x`). Returns whether the lane moved.
func aim(y: int, x: int = column) -> bool:
	if y == row and x == column:
		return false
	row = y
	column = x
	return true


## The lane's first row (or column): it runs from there `lane` px on (its line in its middle, the
## later middle for an even breadth).
func lane_top() -> int:
	return line() - lane / 2


## Whether a star centred at `point` stands in the lane.
func in_lane(point: Vector2i) -> bool:
	var across: int = point.x if is_down() else point.y
	return across >= lane_top() and across < lane_top() + lane


## Pure: what charging now does to `stars` (the loose stars), against the `landmarks` standing in
## `sky`. Each star in the lane is carried `butt` px its `way`, the frontmost first, and on past it until it lands clear (the
## usual spacing: StarScatter.MIN_SPACING from a star, as the ones ahead of it have just been left,
## and LANDMARK_SPACING from a landmark). One that ends outside the sky (StarScatter.inner_rect) is
## lost.
func charge(stars: Array[Star], sky: Rect2i, landmarks: Array[Vector2i]) -> Charge:
	var result := Charge.new()
	var occupied: Dictionary[int, Vector2i] = {}
	var charged: Array[Star] = []
	for star: Star in stars:
		occupied[star.id] = star.position
		if in_lane(star.position):
			charged.append(star)
	charged.sort_custom(func(a: Star, b: Star) -> bool:
		var ahead_a: int = a.position.x * way.x + a.position.y * way.y
		var ahead_b: int = b.position.x * way.x + b.position.y * way.y
		return a.id < b.id if ahead_a == ahead_b else ahead_a > ahead_b)
	for star: Star in charged:
		var from: Vector2i = star.position
		var to: Vector2i = from + way * butt
		while not leaves(to, sky) and (_star_within(star.id, to, occupied) or _landmark_within(to, landmarks)):
			to += way
		var lost: bool = leaves(to, sky)
		if lost:
			occupied.erase(star.id)
		else:
			occupied[star.id] = to
		result.moves.append(StarCurrent.Move.new(star.id, from, to, lost))
	return result


## Whether a star butted to `point` has left the sky (where stars live: StarScatter.inner_rect).
static func leaves(point: Vector2i, sky: Rect2i) -> bool:
	return not StarScatter.inner_rect(sky).has_point(point)


## Whether a star other than `id` stands closer to `spot` than the usual spacing.
static func _star_within(id: int, spot: Vector2i, occupied: Dictionary[int, Vector2i]) -> bool:
	for other: int in occupied:
		if other != id and spot.distance_squared_to(occupied[other]) < StarScatter.MIN_SPACING * StarScatter.MIN_SPACING:
			return true
	return false


## Whether any landmark stands closer to `spot` than the landmark spacing, so the star would sit over it.
static func _landmark_within(spot: Vector2i, landmarks: Array[Vector2i]) -> bool:
	for landmark: Vector2i in landmarks:
		if spot.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return true
	return false
