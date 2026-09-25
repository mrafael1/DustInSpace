extends GutTest

const S: int = Star.Size.SMALL
const M: int = Star.Size.MEDIUM
const B: int = Star.Size.BIG


func _eval(sizes: Array) -> String:
	var typed: Array[int] = []
	typed.assign(sizes)
	return Combos.evaluate(typed)


func _any(sizes: Array) -> bool:
	var typed: Array[int] = []
	typed.assign(sizes)
	return Combos.has_any(typed)


func test_three_small_is_small_triple() -> void:
	assert_eq(_eval([S, S, S]), "small_triple")


func test_three_medium_is_medium_triple() -> void:
	assert_eq(_eval([M, M, M]), "medium_triple")


func test_three_big_is_big_triple() -> void:
	assert_eq(_eval([B, B, B]), "big_triple")


func test_sequence_in_any_order() -> void:
	var orders: Array = [[S, M, B], [S, B, M], [M, S, B], [M, B, S], [B, S, M], [B, M, S]]
	for order: Array in orders:
		assert_eq(_eval(order), "sequence", "order %s" % [order])


func test_two_of_a_size_plus_one_is_invalid() -> void:
	for sizes: Array in [[S, S, M], [S, S, B], [M, M, S], [M, B, B], [B, S, B]]:
		assert_eq(_eval(sizes), Combos.INVALID, "sizes %s" % [sizes])


func test_link_must_be_exactly_three() -> void:
	assert_eq(_eval([]), Combos.INVALID)
	assert_eq(_eval([S, S]), Combos.INVALID)
	assert_eq(_eval([S, S, S, S]), Combos.INVALID, "four of a size is not a triple")
	assert_eq(_eval([S, M, B, S]), Combos.INVALID, "four stars containing a sequence is not a sequence")


func test_has_any_finds_triple() -> void:
	assert_true(_any([M, S, M, B, M]))


func test_has_any_finds_sequence() -> void:
	assert_true(_any([S, S, B, M]))


func test_has_any_false_without_combo() -> void:
	assert_false(_any([S, S, M, M]), "two pairs, no big")
	assert_false(_any([B, B]))
	assert_false(_any([]), "empty sky")
