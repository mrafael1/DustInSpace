class_name StarHarvest
extends RefCounted
## Virgo's harvest (chapter 4): a clock of `every` launches. When it runs out, just before that
## launch's last burst (before a blue planet bursts, between a red planet's two bursts), the scythe
## reaps every loose star in the sky for nothing. Where it `binds` (bound sheaves), a constellation
## star lit since the last harvest goes dark again unless lit strings join it to the figure bound
## before. No randomness or nodes; the run applies it.

## Launches between two harvests (the clock as it starts; a quickening one shortens).
var every: int
## Bound sheaves: the harvest puts out constellation stars not joined to the bound figure.
var binds: bool
## The quickening: after each harvest the clock is a launch shorter, down to one.
var quickens: bool
## Tied at once: the binding acts after every launch, not only at the harvest.
var ties: bool
## Launches left until the next harvest (1: the next launch brings it).
var launches_left: int
## Launches between harvests now.
var period: int
## Harvests so far.
var harvests: int = 0


func _init(p_every: int = 3, p_binds: bool = false, p_quickens: bool = false, p_ties: bool = false) -> void:
	assert(p_every >= 1, "a harvest needs at least one launch between")
	every = p_every
	binds = p_binds
	quickens = p_quickens
	ties = p_ties
	period = every
	launches_left = every


## A launch is about to burst its last: the clock counts it. True when this launch brings the harvest
## (the clock then starts over, a launch shorter if it quickens).
func count_launch() -> bool:
	launches_left -= 1
	if launches_left > 0:
		return false
	harvests += 1
	if quickens:
		period = maxi(1, period - 1)
	launches_left = period
	return true



## Whether the next launch brings the harvest.
func is_next() -> bool:
	return launches_left == 1


## Bound sheaves: which of the `lit` landmarks go dark, given the ones `bound` before and the
## figure's `neighbours` (index to joined indices). A lit landmark stays if a path of lit landmarks
## joins it to a bound one.
static func unbound(lit: Array[bool], bound: Array[bool], neighbours: Callable) -> Array[int]:
	var reached: Array[bool] = []
	var frontier: Array[int] = []
	for i: int in lit.size():
		reached.append(lit[i] and bound[i])
		if reached[i]:
			frontier.append(i)
	while not frontier.is_empty():
		var at: int = frontier.pop_back()
		for n: int in neighbours.call(at):
			if lit[n] and not reached[n]:
				reached[n] = true
				frontier.append(n)
	var result: Array[int] = []
	for i: int in lit.size():
		if lit[i] and not reached[i]:
			result.append(i)
	return result
