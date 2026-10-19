extends GutTest
## Aries's ram (StarCharge, pure): its clock, its lane, and how a charge butts the stars in it.

const SKY := Rect2i(0, 78, 180, 172)
const ROW: int = 160


func _ram() -> StarCharge:
	return StarCharge.new(2, 20, 48, ROW)


func _stars(points: Array[Vector2i]) -> Array[Star]:
	var result: Array[Star] = []
	for i: int in points.size():
		result.append(Star.new(i + 1, Star.Size.SMALL, points[i]))
	return result


func _move(charge: StarCharge.Charge, id: int) -> StarCurrent.Move:
	for move: StarCurrent.Move in charge.moves:
		if move.star_id == id:
			return move
	return null


func test_it_charges_every_second_launch() -> void:
	var ram: StarCharge = _ram()
	var charged: Array[bool] = []
	var announced: Array[bool] = []
	for i: int in 6:
		announced.append(ram.charges_next())
		charged.append(ram.count_launch())
	assert_eq(charged, [false, true, false, true, false, true] as Array[bool])
	assert_eq(announced, charged, "charges_next says it before the launch")
	assert_eq(ram.launches, 6)


func test_launches_left_counts_down_to_the_charge() -> void:
	var ram := StarCharge.new(3, 20, 48, ROW)
	assert_eq(ram.launches_left(), 3)
	ram.count_launch()
	assert_eq(ram.launches_left(), 2)
	ram.count_launch()
	assert_eq(ram.launches_left(), 1)
	assert_true(ram.charges_next())
	ram.count_launch()
	assert_eq(ram.launches_left(), 3)


func test_the_lane_is_20_rows_centred_on_the_row() -> void:
	var ram: StarCharge = _ram()
	assert_eq(ram.lane_top(), ROW - 10)
	assert_false(ram.in_lane(Vector2i(50, ROW - 11)), "a row above the top")
	assert_true(ram.in_lane(Vector2i(50, ROW - 10)), "the top row")
	assert_true(ram.in_lane(Vector2i(50, ROW + 9)), "the bottom row")
	assert_false(ram.in_lane(Vector2i(50, ROW + 10)), "a row below the bottom")


func test_a_star_just_outside_the_lane_is_left_alone() -> void:
	var ram: StarCharge = _ram()
	var stars: Array[Star] = _stars([Vector2i(40, ROW - 11), Vector2i(40, ROW + 10), Vector2i(90, ROW - 10), Vector2i(90, ROW + 9)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	assert_null(_move(charge, 1))
	assert_null(_move(charge, 2))
	assert_eq(_move(charge, 3).to, Vector2i(138, ROW - 10), "the top row is butted")
	assert_eq(_move(charge, 4).to, Vector2i(138, ROW + 9), "the bottom row is butted")


func test_a_star_in_the_lane_is_butted_48_px_right() -> void:
	var ram: StarCharge = _ram()
	var stars: Array[Star] = _stars([Vector2i(40, ROW + 3)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	assert_eq(charge.moves.size(), 1)
	assert_eq(charge.moves[0].from, Vector2i(40, ROW + 3))
	assert_eq(charge.moves[0].to, Vector2i(88, ROW + 3))
	assert_false(charge.moves[0].drained)
	assert_eq(stars[0].position, Vector2i(40, ROW + 3), "pure: the stars don't move")


func test_the_rightmost_goes_first_so_the_one_behind_follows() -> void:
	var ram: StarCharge = _ram()
	var stars: Array[Star] = _stars([Vector2i(40, ROW), Vector2i(58, ROW)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	assert_eq(charge.moves[0].star_id, 2, "the rightmost first")
	assert_eq(charge.moves[0].to, Vector2i(106, ROW))
	assert_eq(charge.moves[1].to, Vector2i(88, ROW), "the one behind butted its full 48 px into the room")


func test_a_landmark_in_the_way_doesnt_stop_it() -> void:
	var ram: StarCharge = _ram()
	# Butted 48 px it would land on the landmark: it's carried on past it until clear.
	var stars: Array[Star] = _stars([Vector2i(40, ROW)])
	var landmark := Vector2i(88, ROW)
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [landmark])
	assert_eq(charge.moves[0].to, landmark + StarCharge.WAY * StarScatter.LANDMARK_SPACING, "on past it, clear of it")
	assert_false(charge.moves[0].drained)


func test_a_star_against_a_landmark_is_butted_past_it() -> void:
	var ram: StarCharge = _ram()
	var stars: Array[Star] = _stars([Vector2i(56, ROW)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [Vector2i(70, ROW)])
	assert_eq(charge.moves[0].to, Vector2i(104, ROW), "no shelter: butted its full 48 px")


func test_a_landmark_behind_doesnt_stop_it() -> void:
	var ram: StarCharge = _ram()
	var stars: Array[Star] = _stars([Vector2i(40, ROW)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [Vector2i(30, ROW), Vector2i(40, ROW - 8)])
	assert_eq(charge.moves[0].to, Vector2i(88, ROW))


func test_a_star_in_the_way_doesnt_stop_it() -> void:
	var ram: StarCharge = _ram()
	# The one ahead is butted 48 px; the one behind would land on it, so it's carried on past it.
	var stars: Array[Star] = _stars([Vector2i(40, ROW), Vector2i(50, ROW)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	assert_eq(_move(charge, 2).to, Vector2i(98, ROW))
	assert_eq(_move(charge, 1).to, Vector2i(98 + StarScatter.MIN_SPACING, ROW), "on past it, clear of it")


func test_a_star_never_lands_on_one_out_of_the_lane() -> void:
	var ram: StarCharge = _ram()
	var stars: Array[Star] = _stars([Vector2i(40, ROW + 9), Vector2i(88, ROW + 12)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	assert_null(_move(charge, 2), "out of the lane: not butted")
	var to: Vector2i = _move(charge, 1).to
	assert_gt(to.x, 88, "carried on past it")
	assert_gte(to.distance_squared_to(Vector2i(88, ROW + 12)), StarScatter.MIN_SPACING * StarScatter.MIN_SPACING, "never over it")


func test_a_star_butted_out_of_the_sky_is_lost() -> void:
	var ram: StarCharge = _ram()
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	var last_in: int = inner.end.x - 1 - 48
	var stars: Array[Star] = _stars([Vector2i(last_in, ROW), Vector2i(last_in + 1 + StarScatter.MIN_SPACING, ROW - 6)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	var lost: StarCurrent.Move = _move(charge, 2)
	assert_true(lost.drained)
	assert_eq(lost.to, Vector2i(last_in + 1 + StarScatter.MIN_SPACING + 48, ROW - 6), "where it would have gone, past the edge")
	var kept: StarCurrent.Move = _move(charge, 1)
	assert_false(kept.drained, "landing on the sky's last column keeps it")
	assert_eq(kept.to, Vector2i(inner.end.x - 1, ROW), "butted to the sky's last column")
	assert_eq(charge.lost(), [2] as Array[int])


func test_a_lost_star_frees_the_way_for_the_one_behind() -> void:
	var ram: StarCharge = _ram()
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	var last_in: int = inner.end.x - 1 - 48
	# Closer than the usual spacing: had the lost one stayed where it would have gone, 10 px ahead,
	# it would stop the one behind 6 px short.
	var stars: Array[Star] = _stars([Vector2i(last_in, ROW), Vector2i(last_in + 10, ROW)])
	var charge: StarCharge.Charge = ram.charge(stars, SKY, [])
	assert_true(_move(charge, 2).drained)
	assert_eq(_move(charge, 1).to, Vector2i(last_in + 48, ROW), "butted its full 48 px")
	assert_false(_move(charge, 1).drained)


func test_one_a_px_further_is_lost() -> void:
	var ram: StarCharge = _ram()
	var inner: Rect2i = StarScatter.inner_rect(SKY)
	var charge: StarCharge.Charge = ram.charge(_stars([Vector2i(inner.end.x - 48, ROW)]), SKY, [])
	assert_true(charge.moves[0].drained)


func test_a_landmark_by_the_edge_doesnt_save_it() -> void:
	var ram: StarCharge = _ram()
	var charge: StarCharge.Charge = ram.charge(_stars([Vector2i(140, ROW)]), SKY, [Vector2i(160, ROW)])
	assert_true(charge.moves[0].drained, "butted on past it and out of the sky")


func test_aim_moves_the_row() -> void:
	var ram: StarCharge = _ram()
	assert_false(ram.aim(ROW), "the same row")
	assert_true(ram.aim(ROW + 8))
	assert_eq(ram.row, ROW + 8)


func test_a_ram_from_each_side_turns_after_each_charge() -> void:
	var ram := StarCharge.new(1, 20, 48, ROW, true)
	assert_eq(ram.way, Vector2i.RIGHT, "it starts from the left")
	ram.turn()
	assert_eq(ram.way, Vector2i.LEFT)
	ram.turn()
	assert_eq(ram.way, Vector2i.RIGHT)
	var one := StarCharge.new(1, 20, 48, ROW)
	one.turn()
	assert_eq(one.way, Vector2i.RIGHT, "a ram from one side never turns")


func test_from_the_right_it_butts_left_and_the_leftmost_goes_first() -> void:
	var ram := StarCharge.new(1, 20, 48, ROW, true)
	ram.turn()
	var charge: StarCharge.Charge = ram.charge(_stars([Vector2i(100, ROW), Vector2i(120, ROW)]), SKY, [])
	assert_eq(charge.moves[0].star_id, 1, "the leftmost first")
	assert_eq(_move(charge, 1).to, Vector2i(52, ROW))
	assert_eq(_move(charge, 2).to, Vector2i(72, ROW))


func test_from_the_right_it_butts_out_of_the_left_edge() -> void:
	var ram := StarCharge.new(1, 20, 48, ROW, true)
	ram.turn()
	var charge: StarCharge.Charge = ram.charge(_stars([Vector2i(30, ROW)]), SKY, [Vector2i(10, ROW)])
	assert_true(charge.moves[0].drained, "out by the left edge, past a landmark")
