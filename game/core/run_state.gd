class_name RunState
extends RefCounted
## One "Restore the Sun" run: dust, light, owned packs, the launcher, stars in the sky,
## and win/loss. Resolves every action instantly; scenes animate from the signals.
## On the Scorpio map (#40) the objective is the constellation instead: lighting every landmark
## wins. A combo may use unlit landmarks as stars (they light up instead of being used up), and a
## full Sun doesn't win: it rekindles (back to 0 light), lights one landmark and clears the sky. There the Sun fills at scorpio.sun_target, and each step of a link, from
## one star to the next, must be at most scorpio.max_link_distance long.

signal pack_bought(kind: String, dust_after: int)
signal pack_loaded(kind: String)
signal pack_launched(kind: String, burst_position: Vector2i)
signal pack_burst(kind: String, burst_position: Vector2i, stars: Array[Star])
signal big_bang_started(burst_position: Vector2i, cleared: Array[Star], dust: int)
signal combo_collected(combo: String, stars: Array[Star], dust: int, light: int)
signal link_rejected(star_ids: Array[int])
## Scorpio (#40): a landmark lit up (a combo used it, or the Sun rekindled).
signal landmark_lit(index: int)
## Scorpio: both ends of a string are lit, so the string formed.
signal string_built(segment: int)
## Scorpio: the Sun filled, so it rekindles at 0 light and lights `landmark` (-1: none left).
## Its light then clears the sky: sky_cleared follows the landmark's events.
signal sun_rekindled(landmark: int)
## Scorpio: every star still in the sky is cleared: `stars` were removed, paying nothing. When
## the Sun rekindles (after the landmark it lights) and when the constellation is complete (just
## before constellation_completed); only when the sky had stars.
signal sky_cleared(stars: Array[Star])
## Scorpio: the last landmark lit. On the Scorpio map that's the win (run_won follows).
signal constellation_completed
signal run_won
signal run_lost

enum Outcome { PLAYING, WON, LOST }
## The loss check's three conditions: a lost run has all of them.
enum LossReason { NO_PACKS, NO_DUST, NO_COMBINATION }


## XOR'd into the seed so star layout has its own RNG stream and can't shift pack contents.
const LAYOUT_SEED_SALT: int = 0x5CA77E4

var balance: Balance
## The seed of the RNG the run started with. Anything replayable derives its randomness from it.
var run_seed: int = 0
var sky_rect: Rect2i
var dust: int = 0
var light: int = 0
var owned_packs: Dictionary[String, int] = {}
## Kind currently in the slingshot, or "" when there is none.
var loaded_pack: String = ""
var stars: Array[Star] = []
var outcome: Outcome = Outcome.PLAYING
## Debug trigger: the next launched pack is a Big Bang (key B in debug builds).
var force_next_big_bang: bool = false
## The Scorpio map, or null when balance.json has it off.
var scorpio: Scorpio

var _rng: RandomNumberGenerator
var _layout_rng := RandomNumberGenerator.new()
var _next_star_id: int = 1


func _init(p_balance: Balance, p_rng: RandomNumberGenerator, p_sky_rect: Rect2i) -> void:
	assert(p_balance.is_valid(), "RunState needs a valid Balance: %s" % [p_balance.errors])
	assert(StarScatter.inner_rect(p_sky_rect).has_area(), "sky rect too small for the edge margin")
	balance = p_balance
	sky_rect = p_sky_rect
	_rng = p_rng
	run_seed = p_rng.seed
	_layout_rng.seed = p_rng.seed ^ LAYOUT_SEED_SALT
	dust = balance.start_dust
	if balance.scorpio_enabled:
		scorpio = Scorpio.new()
	for kind: String in balance.pack_kinds():
		owned_packs[kind] = balance.start_packs.get(kind, 0)
	_auto_load()


func is_over() -> bool:
	return outcome != Outcome.PLAYING


func total_packs() -> int:
	var total: int = 0
	for count: int in owned_packs.values():
		total += count
	return total


func can_afford(kind: String) -> bool:
	return balance.packs.has(kind) and dust >= balance.packs[kind].cost


## The light that fills the Sun: its own target on the Scorpio map, else sun_target.
func light_target() -> int:
	if scorpio != null and balance.scorpio_sun_target > 0:
		return balance.scorpio_sun_target
	return balance.sun_target


## The longest step between consecutive stars in a link, in native px; 0 means no limit.
func link_reach() -> int:
	return balance.scorpio_max_link_distance if scorpio != null else 0


## Whether a link can step from `a` to `b`.
func in_reach(a: Vector2i, b: Vector2i) -> bool:
	var reach: int = link_reach()
	return reach <= 0 or (b - a).length_squared() <= reach * reach


## Whether every step of a link, in pick order, is in reach. Unknown ids are skipped.
func link_in_reach(star_ids: Array[int]) -> bool:
	var previous: Star = null
	for id: int in star_ids:
		var star: Star = _link_star(id)
		if star == null:
			continue
		if previous != null and not in_reach(previous.position, star.position):
			return false
		previous = star
	return true


func sky_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for star: Star in stars:
		sizes.append(star.size)
	return sizes


## A combo is still possible. On the Scorpio map one unlit landmark may be in it, and its stars
## must be linkable within reach.
func has_remaining_combo() -> bool:
	if scorpio == null:
		return Combos.has_any(sky_sizes())
	var pool: Array[Star] = stars.duplicate()
	for i: int in Scorpio.LANDMARKS.size():
		if not scorpio.is_lit(i):
			pool.append(Scorpio.landmark_star(i))
	for a: int in pool.size():
		for b: int in range(a + 1, pool.size()):
			for c: int in range(b + 1, pool.size()):
				var trio: Array[Star] = [pool[a], pool[b], pool[c]]
				if trio.filter(func(s: Star) -> bool: return Scorpio.is_landmark_id(s.id)).size() > Scorpio.LANDMARKS_PER_COMBO:
					continue
				if Combos.evaluate([trio[0].size, trio[1].size, trio[2].size] as Array[int]) != Combos.INVALID and _can_chain(trio):
					return true
	return false


## Whether three stars can be linked in some order with every step in reach: one of them (the
## middle of the link) must reach both others.
func _can_chain(trio: Array[Star]) -> bool:
	for m: int in 3:
		var mid: Vector2i = trio[m].position
		if in_reach(mid, trio[(m + 1) % 3].position) and in_reach(mid, trio[(m + 2) % 3].position):
			return true
	return false


## Which of the loss check's conditions hold now, in LossReason order. A lost run has all three;
## the end screen names them.
func loss_reasons() -> Array[LossReason]:
	var reasons: Array[LossReason] = []
	if total_packs() == 0:
		reasons.append(LossReason.NO_PACKS)
	if dust < balance.cheapest_pack_cost():
		reasons.append(LossReason.NO_DUST)
	if not has_remaining_combo():
		reasons.append(LossReason.NO_COMBINATION)
	return reasons


func find_star(id: int) -> Star:
	for star: Star in stars:
		if star.id == id:
			return star
	return null


## Spends dust on a pack and loads it into the launcher.
func buy(kind: String) -> bool:
	if is_over() or not can_afford(kind):
		return false
	dust -= balance.packs[kind].cost
	owned_packs[kind] += 1
	pack_bought.emit(kind, dust)
	load_pack(kind)
	return true


## Puts an owned pack in the slingshot.
func load_pack(kind: String) -> bool:
	if is_over() or owned_packs.get(kind, 0) <= 0:
		return false
	if loaded_pack != kind:
		loaded_pack = kind
		pack_loaded.emit(kind)
	return true


## Launches the loaded pack toward `target`. The burst point is clamped into the sky.
func launch(target: Vector2i) -> bool:
	if is_over() or loaded_pack == "" or owned_packs.get(loaded_pack, 0) <= 0:
		return false
	var kind: String = loaded_pack
	var burst: Vector2i = StarScatter.clamp_to_sky(target, sky_rect)
	owned_packs[kind] -= 1
	pack_launched.emit(kind, burst)
	var result: PackOpener.PackResult = PackOpener.open(balance.packs[kind], _rng, force_next_big_bang)
	force_next_big_bang = false
	if result.big_bang:
		_big_bang(burst)
	else:
		_burst(kind, burst, result.sizes)
	_auto_load()
	_check_end()
	return true


## Links exactly 3 distinct stars in the sky. An invalid link uses nothing up. On the Scorpio map
## a step between consecutive stars longer than the reach makes the link invalid.
## On the Scorpio map one unlit landmark can be in it too: the combo pays as usual and the
## landmark lights up instead of being used up. A full Sun then rekindles.
## Returns the combo key, or Combos.INVALID.
func link(star_ids: Array[int]) -> String:
	var linked: Array[Star] = _stars_for_link(star_ids)
	var sizes: Array[int] = []
	for star: Star in linked:
		sizes.append(star.size)
	var combo: String = Combos.INVALID if is_over() or not link_in_reach(star_ids) else Combos.evaluate(sizes)
	if combo == Combos.INVALID:
		link_rejected.emit(star_ids)
		return Combos.INVALID
	for star: Star in linked:
		stars.erase(star)
	var reward: Balance.ComboReward = balance.combos[combo]
	dust += reward.dust
	light += reward.light
	combo_collected.emit(combo, linked, reward.dust, reward.light)
	if scorpio != null:
		for star: Star in linked:
			if Scorpio.is_landmark_id(star.id):
				_light_landmark(Scorpio.landmark_index(star.id))
		# The last landmark lit is the win: no rekindle on top of it.
		var rekindled: bool = not scorpio.is_complete() and _rekindle_if_full()
		# A rekindled Sun clears the sky, and so does the completion (by this combo or that Sun).
		if rekindled or scorpio.is_complete():
			_clear_sky()
		if scorpio.is_complete():
			constellation_completed.emit()
	_check_end()
	return combo


## The combo a link would make (Combos.INVALID if none), without making it. For previews.
func combo_for(star_ids: Array[int]) -> String:
	if not link_in_reach(star_ids):
		return Combos.INVALID
	var linked: Array[Star] = _stars_for_link(star_ids)
	var sizes: Array[int] = []
	for star: Star in linked:
		sizes.append(star.size)
	return Combos.evaluate(sizes)


## Scorpio: the strings a link would form by lighting its landmarks, if its combo is valid.
func strings_for(star_ids: Array[int]) -> Array[int]:
	var formed: Array[int] = []
	if scorpio == null or combo_for(star_ids) == Combos.INVALID:
		return formed
	var lit: Array[bool] = scorpio.lit.duplicate()
	for id: int in star_ids:
		if Scorpio.is_landmark_id(id):
			lit[Scorpio.landmark_index(id)] = true
	for segment: int in Scorpio.segment_count():
		if lit[segment] and lit[segment + 1] and not scorpio.is_built(segment):
			formed.append(segment)
	return formed


func _light_landmark(index: int) -> void:
	if scorpio.is_lit(index):
		return
	var formed: Array[int] = scorpio.light(index)
	landmark_lit.emit(index)
	for segment: int in formed:
		string_built.emit(segment)


## Scorpio: a full Sun (light_target) rekindles at 0 and lights the first unlit landmark next to a
## lit one (else the first unlit). The caller clears the sky after. Returns whether it rekindled.
func _rekindle_if_full() -> bool:
	if light < light_target():
		return false
	light = 0
	var index: int = rekindle_target()
	sun_rekindled.emit(index)
	if index >= 0:
		_light_landmark(index)
	return true


## Scorpio: the landmark a rekindled Sun would light, or -1 when all are lit.
func rekindle_target() -> int:
	var first: int = -1
	for i: int in Scorpio.LANDMARKS.size():
		if scorpio.is_lit(i):
			continue
		if (i > 0 and scorpio.is_lit(i - 1)) or (i + 1 < Scorpio.LANDMARKS.size() and scorpio.is_lit(i + 1)):
			return i
		if first < 0:
			first = i
	return first


## Adds a star directly. Used by launches, tests and the debug overlay.
func add_star(size: Star.Size, position: Vector2i) -> Star:
	var star := Star.new(_next_star_id, size, StarScatter.clamp_to_sky(position, sky_rect))
	_next_star_id += 1
	stars.append(star)
	return star


func _burst(kind: String, burst: Vector2i, sizes: Array[int]) -> void:
	var occupied: Array[Vector2i] = []
	for star: Star in stars:
		occupied.append(star.position)
	var landmarks: Array[Vector2i] = []
	if scorpio != null:
		landmarks = Scorpio.LANDMARKS
	var positions: Array[Vector2i] = StarScatter.place(sizes.size(), burst, sky_rect, occupied, _layout_rng, landmarks)
	var born: Array[Star] = []
	for i: int in sizes.size():
		born.append(add_star(sizes[i] as Star.Size, positions[i]))
	pack_burst.emit(kind, burst, born)


## Scorpio's rekindle or completion: every star left in the sky goes, for nothing.
func _clear_sky() -> void:
	if stars.is_empty():
		return
	var cleared: Array[Star] = stars.duplicate()
	stars.clear()
	sky_cleared.emit(cleared)


## Clears every star in the sky for base dust plus a bonus per star. No light.
func _big_bang(burst: Vector2i) -> void:
	var cleared: Array[Star] = stars.duplicate()
	stars.clear()
	var gain: int = balance.big_bang_base_dust + balance.big_bang_dust_per_cleared_star * cleared.size()
	dust += gain
	big_bang_started.emit(burst, cleared, gain)


## Returns the stars for a link, or an empty array if the ids aren't 3 distinct sky stars. On the
## Scorpio map one unlit landmark can be in it too (Scorpio.LANDMARKS_PER_COMBO).
func _stars_for_link(star_ids: Array[int]) -> Array[Star]:
	var linked: Array[Star] = []
	if star_ids.size() != Combos.LINK_LENGTH:
		return linked
	var sky_count: int = 0
	var landmark_count: int = 0
	for id: int in star_ids:
		var star: Star = _link_star(id)
		if star == null or linked.any(func(s: Star) -> bool: return s.id == star.id):
			linked.clear()
			return linked
		if Scorpio.is_landmark_id(id):
			landmark_count += 1
		else:
			sky_count += 1
		linked.append(star)
	if sky_count == 0 or landmark_count > Scorpio.LANDMARKS_PER_COMBO:
		linked.clear()
	return linked


## A sky star, or an unlit landmark on the Scorpio map, by link id. Null otherwise.
func _link_star(id: int) -> Star:
	if scorpio != null and Scorpio.is_landmark_id(id):
		var index: int = Scorpio.landmark_index(id)
		return null if scorpio.is_lit(index) else Scorpio.landmark_star(index)
	return find_star(id)


## Keeps the loaded kind while any remain; otherwise loads the first owned kind in balance order.
func _auto_load() -> void:
	if loaded_pack != "" and owned_packs.get(loaded_pack, 0) > 0:
		return
	for kind: String in balance.pack_kinds():
		if owned_packs[kind] > 0:
			loaded_pack = kind
			pack_loaded.emit(kind)
			return
	loaded_pack = ""


func _check_end() -> void:
	if is_over():
		return
	if scorpio.is_complete() if scorpio != null else light >= light_target():
		outcome = Outcome.WON
		run_won.emit()
		return
	if loss_reasons().size() == LossReason.size():
		outcome = Outcome.LOST
		run_lost.emit()
