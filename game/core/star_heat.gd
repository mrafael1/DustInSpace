class_name StarHeat
extends RefCounted
## Leo's heat (chapter 3), over the whole stage: once a launch has resolved, every loose star in
## the sky changes one size. The heat grows them (small to medium to big); the cold (change -1)
## shrinks them. A star pushed past the last size is lost for nothing when the heat burns (a big
## burns out in the heat, a small fades in the cold); otherwise it stays at the last size. The
## stars a launch brought don't change on that launch. A heat that turns (the Mane's day and night)
## swaps heat and cold after every launch. No randomness, nodes or rewards; landmarks never change.

class Change:
	extends RefCounted
	var star_id: int
	var from: Star.Size
	var to: Star.Size
	## Pushed past the last size: the star is lost (`to` is `from`).
	var lost: bool
	## A constellation star the heat pushed past big came back small (it can't be lost).
	var rekindled: bool

	func _init(id: int, p_from: Star.Size, p_to: Star.Size, p_lost: bool = false, p_rekindled: bool = false) -> void:
		star_id = id
		from = p_from
		to = p_to
		lost = p_lost
		rekindled = p_rekindled

	## The cold made it: it shrank, or a small one faded out (a lost big burned in the heat).
	func is_cold() -> bool:
		return from == Star.Size.SMALL if lost else to < from and not rekindled

## +1: the heat, stars grow; -1: the cold, they shrink.
var change: int
var burns: bool
## Heat and cold take turns: `change` flips after every launch.
var turns: bool


func _init(p_change: int = 1, p_burns: bool = false, p_turns: bool = false) -> void:
	assert(absi(p_change) == 1, "a star changes one size a launch")
	change = p_change
	burns = p_burns
	turns = p_turns


## A launch has resolved: a turning heat becomes the cold, or the cold the heat.
func turn() -> void:
	if turns:
		change = -change


## What the next launch does to the constellation stars still to light (`landmarks`, as stars with
## their landmark ids), where the heat changes them instead of the loose stars (the Head). They
## can't be lost: past the last size one comes back at the first (a big burns back to small), so
## they never settle.
func preview_landmarks(landmarks: Array[Star]) -> Array[Change]:
	var result: Array[Change] = []
	for star: Star in landmarks:
		var next: int = star.size + change
		if next >= Star.Size.SMALL and next <= Star.Size.BIG:
			result.append(Change.new(star.id, star.size, next as Star.Size))
		else:
			result.append(Change.new(star.id, star.size, (Star.Size.SMALL if change > 0 else Star.Size.BIG), false, true))
	return result


## What the next launch does to `stars`, one Change per star it touches. `skip`: ids that don't
## change (the stars that launch brought).
func preview(stars: Array[Star], skip: Dictionary[int, bool] = {}) -> Array[Change]:
	var result: Array[Change] = []
	for star: Star in stars:
		if skip.has(star.id):
			continue
		var next: int = star.size + change
		if next >= Star.Size.SMALL and next <= Star.Size.BIG:
			result.append(Change.new(star.id, star.size, next as Star.Size))
		elif burns:
			result.append(Change.new(star.id, star.size, star.size, true))
	return result
