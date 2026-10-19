class_name StarCharge
extends RefCounted
## Aries's ram (chapter 7): the ram stands at the sky's left edge, and every `every`-th launch, once
## that launch has fully resolved, it charges right along its lane: the band `lane` px tall centred
## on the lane row, the row of the landmark the last link lit. Every loose star whose centre is in the
## lane is butted `butt` px right, the rightmost first, and on past a star or a landmark it would land
## on: nothing shelters it. One carried out of the sky is lost, for nothing. No randomness, nodes or
## rewards. Its moves are StarCurrent.Moves (a lost one `drained`, `to` where it would have gone,
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

## The way the ram charges: from the left edge, right.
const WAY := Vector2i.RIGHT

## It charges on every this-many-th launch.
var every: int
## The lane's height, in px.
var lane: int
## How far it butts each star in its lane, in px.
var butt: int
## The lane row: the y the lane is centred on.
var row: int
## Launches thrown since the run began (intros don't count).
var launches: int = 0


func _init(p_every: int, p_lane: int, p_butt: int, p_row: int) -> void:
	every = p_every
	lane = p_lane
	butt = p_butt
	row = p_row


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


## The lane follows the landmark a link lit, at `y`. Returns whether the row moved.
func aim(y: int) -> bool:
	if y == row:
		return false
	row = y
	return true


## The lane's top row: it runs from there `lane` rows down (the row in its middle, the lower middle
## for an even height).
func lane_top() -> int:
	return row - lane / 2


## Whether a star centred at `point` stands in the lane.
func in_lane(point: Vector2i) -> bool:
	return point.y >= lane_top() and point.y < lane_top() + lane


## Pure: what charging now does to `stars` (the loose stars), against the `landmarks` standing in
## `sky`. Each star in the lane is carried `butt` px right, and on past it until it lands clear (the
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
		return a.id < b.id if a.position.x == b.position.x else a.position.x > b.position.x)
	for star: Star in charged:
		var from: Vector2i = star.position
		var to: Vector2i = from + WAY * butt
		while not leaves(to, sky) and (_star_within(star.id, to, occupied) or _landmark_within(to, landmarks)):
			to += WAY
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
