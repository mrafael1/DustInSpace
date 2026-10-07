class_name StarHeat
extends RefCounted
## Leo's heat (chapter 3): once a launch has resolved, every loose star inside its region changes
## one size. The heat grows them (small to medium to big); the cold (change -1) shrinks them. A
## star pushed past the last size is lost for nothing when the region burns (a big burns out in the
## heat, a small fades in the cold); otherwise it stays at the last size. The stars a launch brought
## don't change on that launch. No randomness, nodes or rewards; landmarks never change.

class Change:
	extends RefCounted
	var star_id: int
	var from: Star.Size
	var to: Star.Size
	## Pushed past the last size: the star is lost (`to` is `from`).
	var lost: bool

	func _init(id: int, p_from: Star.Size, p_to: Star.Size, p_lost: bool = false) -> void:
		star_id = id
		from = p_from
		to = p_to
		lost = p_lost

var region: Rect2i
## +1: the heat, stars grow; -1: the cold, they shrink.
var change: int
var burns: bool


func _init(area: Rect2i, p_change: int = 1, p_burns: bool = false) -> void:
	assert(absi(p_change) == 1, "a star changes one size a launch")
	region = area
	change = p_change
	burns = p_burns


## What the next launch does to `stars`, one Change per star it touches. `skip`: ids that don't
## change (the stars that launch brought). `positions`: where the stars will be when it happens
## (a current's destinations); a star missing from it is where it is.
func preview(stars: Array[Star], skip: Dictionary[int, bool] = {}, positions: Dictionary[int, Vector2i] = {}) -> Array[Change]:
	var result: Array[Change] = []
	for star: Star in stars:
		if skip.has(star.id) or not region.has_point(positions.get(star.id, star.position)):
			continue
		var next: int = star.size + change
		if next >= Star.Size.SMALL and next <= Star.Size.BIG:
			result.append(Change.new(star.id, star.size, next as Star.Size))
		elif burns:
			result.append(Change.new(star.id, star.size, star.size, true))
	return result
