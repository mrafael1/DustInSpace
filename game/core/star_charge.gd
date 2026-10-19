class_name StarCharge
extends RefCounted
## Aries's ram (chapter 7): the ram stands at the sky's left edge, and every `every`-th
## launch, once that launch has fully resolved, it charges right along its lane: the band `lane` px
## tall centred on the lane row, the row of the landmark the last link lit. Every loose star whose
## centre is in the lane is butted `butt` px right, the rightmost first. Only a landmark a star runs
## into stops it, just short of it (the usual landmark spacing; stars pile up behind it), and that
## star is fleeced; one passing above or below goes by. Any other star is carried the whole way, and
## on past a star or a landmark it would land on; one carried out of the sky is lost, for nothing.
## Fleeced is a mark only (no pay, no rule): a star keeps it until it's linked or lost. No
## randomness, nodes or rewards.
## Its moves are StarCurrent.Moves (a lost one `drained`, `to` where it would have gone, past the
## sky's edge).

## What one charge does to the stars standing in the sky.
class Charge:
	extends RefCounted
	## The stars that move, rightmost first (a lost one `drained`).
	var moves: Array[StarCurrent.Move] = []
	## The stars stopped against a landmark (moved or not), in the same order.
	var fleeced: Array[int] = []

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
## The fleeced stars' ids, in the order they were first fleeced.
var fleeced: Array[int] = []


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
## `sky`. Each star in the lane slides right a px at a time; only a landmark it runs into (its way
## passing closer than LANDMARK_SPACING) stops it, at the last spot that keeps that spacing, piled
## behind any star already resting against it, and fleeces it. Otherwise it's carried the whole `butt`, and on past it until it lands clear (the usual
## spacing: StarScatter.MIN_SPACING from a star, as the ones ahead of it have just been left, and
## LANDMARK_SPACING from a landmark out of the lane): nothing else shelters it. One that ends outside
## the sky (StarScatter.inner_rect) is lost.
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
	var reach: int = sky.size.x + butt
	for star: Star in charged:
		var from: Vector2i = star.position
		var to: Vector2i = from
		var stopped_by_landmark: bool = false
		for k: int in range(1, reach + 1):
			var spot: Vector2i = from + WAY * k
			if _landmark_ahead_within(from, spot, landmarks):
				to = _pile_spot(star.id, from, k - 1, occupied)
				stopped_by_landmark = true
				break
			to = spot
			if k >= butt and (leaves(spot, sky) or not (_star_within(star.id, spot, occupied) or _landmark_within(spot, landmarks))):
				break
		var lost: bool = leaves(to, sky)
		if lost:
			occupied.erase(star.id)
		else:
			occupied[star.id] = to
			if stopped_by_landmark:
				result.fleeced.append(star.id)
		if to != from:
			result.moves.append(StarCurrent.Move.new(star.id, from, to, lost))
	return result


## The stars `ids` were fleeced (one already fleeced stays so).
func fleece(ids: Array[int]) -> void:
	for id: int in ids:
		if not fleeced.has(id):
			fleeced.append(id)


## Whether the star `id` is fleeced.
func is_fleeced(id: int) -> bool:
	return fleeced.has(id)


## Only the fleeced stars still standing among `stars` stay fleeced (the others were linked or lost).
func keep_fleeced(stars: Array[Star]) -> void:
	var standing: Dictionary[int, bool] = {}
	for star: Star in stars:
		standing[star.id] = true
	fleeced = fleeced.filter(func(id: int) -> bool: return standing.has(id))


## Whether a star butted to `point` has left the sky (where stars live: StarScatter.inner_rect).
static func leaves(point: Vector2i, sky: Rect2i) -> bool:
	return not StarScatter.inner_rect(sky).has_point(point)


## Where a star stopped by a landmark `k` px along from `from` rests: there, else backed off toward
## `from` until it's clear of the stars ahead of it already piled against it (at `from` if none is).
static func _pile_spot(id: int, from: Vector2i, k: int, occupied: Dictionary[int, Vector2i]) -> Vector2i:
	var ahead: Dictionary[int, Vector2i] = {}
	for other: int in occupied:
		if occupied[other].x > from.x:
			ahead[other] = occupied[other]
	for back: int in range(k, 0, -1):
		var spot: Vector2i = from + WAY * back
		if not _star_within(id, spot, ahead):
			return spot
	return from


## Whether a star other than `id` stands closer to `spot` than the usual spacing.
static func _star_within(id: int, spot: Vector2i, occupied: Dictionary[int, Vector2i]) -> bool:
	for other: int in occupied:
		if other != id and spot.distance_squared_to(occupied[other]) < StarScatter.MIN_SPACING * StarScatter.MIN_SPACING:
			return true
	return false


## Whether a landmark ahead of `from` stands closer to `spot` than the landmark spacing: the star runs
## into it. One passing further above or below goes by.
static func _landmark_ahead_within(from: Vector2i, spot: Vector2i, landmarks: Array[Vector2i]) -> bool:
	for landmark: Vector2i in landmarks:
		if landmark.x > from.x and spot.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return true
	return false


## Whether any landmark stands closer to `spot` than the landmark spacing, so the star would sit over it.
static func _landmark_within(spot: Vector2i, landmarks: Array[Vector2i]) -> bool:
	for landmark: Vector2i in landmarks:
		if spot.distance_squared_to(landmark) < StarScatter.LANDMARK_SPACING * StarScatter.LANDMARK_SPACING:
			return true
	return false
