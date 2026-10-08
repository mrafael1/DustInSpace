class_name StarHarvest
extends RefCounted
## Virgo's harvest (chapter 4): a clock of `every` launches. When it runs out, once that launch has
## resolved, the scythe reaps every loose star in the sky for nothing, except the stars that launch
## brought. Where it `binds` (bound sheaves), a constellation star lit since the last harvest goes
## dark again unless lit strings join it to the figure bound before. No randomness or nodes; the run
## applies it.

## Launches between two harvests.
var every: int
## Bound sheaves: the harvest puts out constellation stars not joined to the bound figure.
var binds: bool
## Launches left until the next harvest (1: the next launch brings it).
var launches_left: int


func _init(p_every: int = 3, p_binds: bool = false) -> void:
	assert(p_every >= 1, "a harvest needs at least one launch between")
	every = p_every
	binds = p_binds
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


## The stars of `stars` the harvest reaps: all but `skip` (the ids its own launch brought).
static func reaped(stars: Array[Star], skip: Dictionary[int, bool] = {}) -> Array[Star]:
	var result: Array[Star] = []
	for star: Star in stars:
		if not skip.has(star.id):
			result.append(star)
	return result


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
