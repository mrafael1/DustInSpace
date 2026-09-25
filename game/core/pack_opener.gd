class_name PackOpener
extends RefCounted
## Opens a pack: rolls the Big Bang once, before any stars are drawn, then draws
## each star independently from the pack's weights. Positions are not decided here,
## so where a pack bursts can never change what is inside it.


class PackResult:
	extends RefCounted
	var kind: String = ""
	var big_bang: bool = false
	## Star.Size values. Empty when the pack is a Big Bang.
	var sizes: Array[int] = []


static func open(pack: Balance.PackDef, rng: RandomNumberGenerator, force_big_bang: bool = false) -> PackResult:
	var result := PackResult.new()
	result.kind = pack.kind
	# Always consume the roll so a forced Big Bang doesn't shift the RNG stream.
	var rolled: bool = rng.randf() < pack.big_bang_chance
	result.big_bang = rolled or force_big_bang
	if result.big_bang:
		return result
	for i: int in pack.stars:
		result.sizes.append(draw_size(pack.weights, rng))
	return result


## Weighted draw of one Star.Size. Zero-weight sizes are never drawn.
static func draw_size(weights: Array[int], rng: RandomNumberGenerator) -> int:
	var total: int = 0
	for w: int in weights:
		total += w
	var roll: int = rng.randi_range(0, total - 1)
	for size: int in weights.size():
		if roll < weights[size]:
			return size
		roll -= weights[size]
	return weights.size() - 1
