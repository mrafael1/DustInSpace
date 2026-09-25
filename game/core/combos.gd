class_name Combos
extends RefCounted
## Evaluates exactly 3 star sizes into a combo key from balance.json, or INVALID.
## Triples: three of one size. Sequence: one of each size, in any order.
## Distance and crossings are ignored (design.md).

const INVALID: String = ""
const SEQUENCE: String = "sequence"
const TRIPLES: Array[String] = ["small_triple", "medium_triple", "big_triple"]
const LINK_LENGTH: int = 3


## `sizes` holds Star.Size values.
static func evaluate(sizes: Array[int]) -> String:
	if sizes.size() != LINK_LENGTH:
		return INVALID
	var counts: Array[int] = count_sizes(sizes)
	for size: int in Star.Size.values():
		if counts[size] == LINK_LENGTH:
			return TRIPLES[size]
	if counts[Star.Size.SMALL] == 1 and counts[Star.Size.MEDIUM] == 1 and counts[Star.Size.BIG] == 1:
		return SEQUENCE
	return INVALID


## True if any 3 of the given sizes form a valid combo. Used by the loss check.
static func has_any(sizes: Array[int]) -> bool:
	var counts: Array[int] = count_sizes(sizes)
	var one_of_each: bool = true
	for count: int in counts:
		if count >= LINK_LENGTH:
			return true
		if count == 0:
			one_of_each = false
	return one_of_each


static func count_sizes(sizes: Array[int]) -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for size: int in sizes:
		counts[size] += 1
	return counts
