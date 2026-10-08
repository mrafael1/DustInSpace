class_name StarHarvest
extends RefCounted
## Virgo's harvest (chapter 4): a clock of `every` launches. When the clock runs out, once that
## launch has resolved, every loose star in the sky pays dust by its size (`pay`) and is reaped,
## gone. No light. Unless `reaps_new`, the stars that launch brought stand until the next harvest.
## Landmarks never change. No randomness or nodes; the run applies it.

## Launches between two harvests.
var every: int
## Dust a reaped star pays, by Star.Size.
var pay: Array[int]
## The harvest also reaps the stars its own launch brought.
var reaps_new: bool
## Launches left until the next harvest (1: the next launch brings it).
var launches_left: int


func _init(p_every: int = 3, p_pay: Array[int] = [1, 2, 3], p_reaps_new: bool = false) -> void:
	assert(p_every >= 1, "a harvest needs at least one launch between")
	assert(p_pay.size() == 3, "one pay per size")
	every = p_every
	pay = p_pay
	reaps_new = p_reaps_new
	launches_left = every


## A launch has resolved: the clock counts it. True when this launch brings the harvest (the clock
## then starts over).
func count_launch() -> bool:
	launches_left -= 1
	if launches_left > 0:
		return false
	launches_left = every
	return true


## Whether the next launch brings the harvest.
func is_next() -> bool:
	return launches_left == 1


## What the harvest pays for `star`.
func pay_for(star: Star) -> int:
	return pay[star.size]


## The stars a harvest reaps from `stars` (`skip`: the ids its own launch brought, which stand
## unless it reaps_new).
func reaped(stars: Array[Star], skip: Dictionary[int, bool] = {}) -> Array[Star]:
	var result: Array[Star] = []
	for star: Star in stars:
		if reaps_new or not skip.has(star.id):
			result.append(star)
	return result


## The dust a harvest of `stars` pays.
func value(stars: Array[Star]) -> int:
	var total: int = 0
	for star: Star in stars:
		total += pay_for(star)
	return total
