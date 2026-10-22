extends GutTest
## The phone box's play paths (docs/wide_sky_design.md §9): each rule a box stage plays on a wide
## sky gives what the 9:16 phone gives, moved by the shift. Every check here runs the wide run and
## the phone run side by side: a path that read the wide sky instead of the box would differ by the
## box's top or bottom rows, or its sides.

const Fixtures := preload("res://tests/fixtures.gd")

const DRAIN_MAPS: Array[String] = ["aquarius_body", "aquarius_legs", "aquarius_stream", "aquarius_jar", "aquarius_final"]
const HUNT_MAPS: Array[String] = ["heart", "claws", "final"]
const REFLECT_MAPS: Array[String] = ["pisces_knot", "pisces_east_cord", "pisces_north_fish", "pisces_final"]


func _stage(map_id: String, sky: Rect2i, seed_value: int = 1) -> RunState:
	var map: StarMap = StarMap.by_id(map_id)
	map.intros = true
	return RunState.new(Balance.load_file(), Fixtures.rng(seed_value), sky, map)


## From the phone's sky to the wide sky's box.
func _shift() -> Vector2i:
	return Scorpio.shift_in(Fixtures.WIDE_SKY) - Scorpio.shift_in(Fixtures.SKY)


## Small stars every 9 columns by the inner top and bottom rows of `sky`'s box, moved by `shift`.
func _crowd(run: RunState, shift: Vector2i) -> void:
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	for x: int in range(inner.position.x, inner.end.x, 9):
		for y: int in [inner.position.y, inner.position.y + 3, inner.end.y - 1, inner.end.y - 4]:
			run.add_star(Star.Size.SMALL, Vector2i(x, y) + shift)


## Every move of `run`'s flows and splashes, in order: start, whether it is lost, end.
func _record_moves(run: RunState, into: Array) -> void:
	var record: Callable = func(moves: Array[StarCurrent.Move]) -> void:
		for move: StarCurrent.Move in moves:
			into.append([move.from, move.drained, move.to])
	run.stars_shifted.connect(record)
	run.stars_splashed.connect(func(at: Vector2i, moves: Array[StarCurrent.Move]) -> void:
		into.append([at])
		record.call(moves))


## `wide` moved back by the shift: positions inside nested arrays, flags kept.
func _unshift(wide: Array, shift: Vector2i) -> Array:
	var result: Array = []
	for entry: Variant in wide:
		if entry is Vector2i:
			result.append(entry - shift)
		elif entry is Array:
			result.append(_unshift(entry, shift))
		else:
			result.append(entry)
	return result


# --- The flow's real step (_shift_stars) ------------------------------------------------------

func test_a_launch_on_a_crowded_box_flows_its_new_stars_as_on_a_phone() -> void:
	# New stars bursting by the box's top or bottom rows, among crowded ones, flow round them: in the
	# box, as in the phone's sky, never into the box's edge band a phone's clamp keeps them out of.
	var shift: Vector2i = _shift()
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	var moved_any: bool = false
	for map_id: String in DRAIN_MAPS:
		for x: int in range(inner.position.x + 6, inner.end.x, 21):
			for y: int in [inner.position.y + 1, inner.end.y - 2]:
				var home: Array = []
				var wide: Array = []
				var runs: Array[RunState] = [_stage(map_id, Fixtures.SKY), _stage(map_id, Fixtures.WIDE_SKY)]
				for k: int in 2:
					var run: RunState = runs[k]
					var offset: Vector2i = Vector2i.ZERO if k == 0 else shift
					_crowd(run, offset)
					_record_moves(run, home if k == 0 else wide)
					run.pack_burst.connect(func(_kind: String, _at: Vector2i, placed: Array[Star]) -> void:
						for star: Star in placed:
							(home if k == 0 else wide).append([star.position]))
					run.owned_packs["blue"] = 1
					assert_true(run.load_pack("blue"))
					assert_true(run.launch(Vector2i(x, y) + offset), "%s: the launch goes" % map_id)
				moved_any = moved_any or not home.is_empty()
				assert_eq(_unshift(wide, shift), home, "%s aimed at %s" % [map_id, Vector2i(x, y)])
	assert_true(moved_any, "the flows moved stars")


# --- The current intro's flow ------------------------------------------------------------------

func test_the_current_intro_flows_as_on_a_phone() -> void:
	var shift: Vector2i = _shift()
	for map_id: String in DRAIN_MAPS:
		for seed_value: int in range(1, 4):
			var traces: Array[Array] = [[], []]
			var runs: Array[RunState] = [_stage(map_id, Fixtures.SKY, seed_value), _stage(map_id, Fixtures.WIDE_SKY, seed_value)]
			for k: int in 2:
				var trace: Array = traces[k]
				runs[k].current_intro_placed.connect(func(placed: Array[Star]) -> void:
					for star: Star in placed:
						trace.append([star.position]))
				runs[k].current_intro_flowed.connect(func(way: Vector2i) -> void: trace.append([way.x, way.y]))
				_record_moves(runs[k], trace)
				runs[k].play_current_intro()
			assert_false(traces[0].is_empty(), "%s: the intro played" % map_id)
			assert_eq(_unshift(traces[1], shift), traces[0], "%s seed %d" % [map_id, seed_value])


# --- The ring dots: where a launch's own stars land and drain -----------------------------------

func test_a_ring_dot_round_the_box_reads_as_round_a_phones_sky() -> void:
	var shift: Vector2i = _shift()
	var around: Rect2i = Fixtures.SKY.grow(10)
	for map_id: String in DRAIN_MAPS:
		var phone: RunState = _stage(map_id, Fixtures.SKY)
		var wide: RunState = _stage(map_id, Fixtures.WIDE_SKY)
		var draining: int = 0
		for y: int in range(around.position.y, around.end.y, 2):
			for x: int in range(around.position.x, around.end.x, 3):
				var dot := Vector2i(x, y)
				var expected: bool = phone.burst_drains_at(dot)
				if expected:
					draining += 1
				assert_eq(wide.burst_drains_at(dot + shift), expected, "%s: dot %s" % [map_id, dot])
		assert_gt(draining, 0, "%s: some dots drain" % map_id)


# --- The hunt's guide: safe launches -----------------------------------------------------------

func _hunted(map_id: String, sky: Rect2i, centre: Vector2i, kind: String) -> RunState:
	var run: RunState = _stage(map_id, sky)
	run.hunt.mark(run.frame_rect)
	run.hunt.centre = centre
	if kind != "":
		run.owned_packs[kind] = 1
		assert_true(run.load_pack(kind))
	else:
		run.loaded_pack = ""
	return run


func test_a_launch_is_safe_where_it_is_on_a_phone() -> void:
	var shift: Vector2i = _shift()
	var inner: Rect2i = StarScatter.inner_rect(Fixtures.SKY)
	var centres: Array[Vector2i] = [inner.position + Vector2i(20, 20), inner.end - Vector2i(20, 20), inner.get_center(), Vector2i(inner.end.x - 20, inner.position.y + 20)]
	for map_id: String in HUNT_MAPS:
		for centre: Vector2i in centres:
			for kind: String in ["blue", "red", ""]:
				var phone: RunState = _hunted(map_id, Fixtures.SKY, centre, kind)
				var wide: RunState = _hunted(map_id, Fixtures.WIDE_SKY, centre + shift, kind)
				var around: Rect2i = Fixtures.SKY.grow(10)
				for y: int in range(around.position.y, around.end.y, 4):
					for x: int in range(around.position.x, around.end.x, 4):
						var aim := Vector2i(x, y)
						assert_eq(wide.is_safe_launch(aim + shift), phone.is_safe_launch(aim), "%s %s circle %s: %s" % [map_id, kind, centre, aim])
				assert_eq(wide.safe_launch_spot() - shift, phone.safe_launch_spot(), "%s %s circle %s: the guide's spot" % [map_id, kind, centre])


# --- The guided launch spot --------------------------------------------------------------------

func test_the_open_launch_spot_is_where_it_is_on_a_phone() -> void:
	var shift: Vector2i = _shift()
	for map_id: String in ["heart", "aquarius_body", "aquarius_final", "pisces_knot", "aries_head"]:
		for kind: String in ["blue", "red"]:
			var phone: RunState = _stage(map_id, Fixtures.SKY)
			var wide: RunState = _stage(map_id, Fixtures.WIDE_SKY)
			for run: RunState in [phone, wide]:
				run.owned_packs[kind] = 1
				assert_true(run.load_pack(kind))
			_crowd(phone, Vector2i.ZERO)
			_crowd(wide, shift)
			for top: int in [Fixtures.SKY.position.y, Fixtures.SKY.position.y + 60]:
				assert_eq(wide.open_launch_spot(top + shift.y) - shift, phone.open_launch_spot(top), "%s %s below %d" % [map_id, kind, top])


# --- Pisces's intros ---------------------------------------------------------------------------

func test_the_pisces_intros_throw_and_burst_as_on_a_phone() -> void:
	var shift: Vector2i = _shift()
	for map_id: String in REFLECT_MAPS:
		for seed_value: int in range(1, 4):
			var traces: Array[Array] = [[], []]
			var runs: Array[RunState] = [_stage(map_id, Fixtures.SKY, seed_value), _stage(map_id, Fixtures.WIDE_SKY, seed_value)]
			for k: int in 2:
				var trace: Array = traces[k]
				var run: RunState = runs[k]
				run.planet_reflected.connect(func(thrown: Vector2i, burst: Vector2i) -> void: trace.append([thrown, burst]))
				run.hunt_intro_burst.connect(func(burst: Vector2i, placed: Array[Star]) -> void:
					trace.append([burst])
					for star: Star in placed:
						trace.append([star.position]))
				run.splash_intro_placed.connect(func(placed: Array[Star]) -> void:
					for star: Star in placed:
						trace.append([star.position]))
				_record_moves(run, trace)
				run.play_reflect_intro()
			assert_false(traces[0].is_empty(), "%s: the intro played" % map_id)
			assert_eq(_unshift(traces[1], shift), traces[0], "%s seed %d" % [map_id, seed_value])
