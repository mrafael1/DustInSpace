class_name RunState
extends RefCounted
## One "Restore the Sun" run: dust, light, owned packs, the launcher, stars in the sky,
## and win/loss. Resolves every action instantly; scenes animate from the signals.

signal pack_bought(kind: String, dust_after: int)
signal pack_loaded(kind: String)
signal pack_launched(kind: String, burst_position: Vector2i)
signal pack_burst(kind: String, burst_position: Vector2i, stars: Array[Star])
signal big_bang_started(burst_position: Vector2i, cleared: Array[Star], dust: int)
signal combo_collected(combo: String, stars: Array[Star], dust: int, light: int)
signal link_rejected(star_ids: Array[int])
signal run_won
signal run_lost

enum Outcome { PLAYING, WON, LOST }

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


func sky_sizes() -> Array[int]:
	var sizes: Array[int] = []
	for star: Star in stars:
		sizes.append(star.size)
	return sizes


func has_remaining_combo() -> bool:
	return Combos.has_any(sky_sizes())


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


## Links exactly 3 distinct stars in the sky. An invalid link uses nothing up.
## Returns the combo key, or Combos.INVALID.
func link(star_ids: Array[int]) -> String:
	var linked: Array[Star] = _stars_for_link(star_ids)
	var sizes: Array[int] = []
	for star: Star in linked:
		sizes.append(star.size)
	var combo: String = Combos.INVALID if is_over() else Combos.evaluate(sizes)
	if combo == Combos.INVALID:
		link_rejected.emit(star_ids)
		return Combos.INVALID
	for star: Star in linked:
		stars.erase(star)
	var reward: Balance.ComboReward = balance.combos[combo]
	dust += reward.dust
	light += reward.light
	combo_collected.emit(combo, linked, reward.dust, reward.light)
	_check_end()
	return combo


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
	var positions: Array[Vector2i] = StarScatter.place(sizes.size(), burst, sky_rect, occupied, _layout_rng)
	var born: Array[Star] = []
	for i: int in sizes.size():
		born.append(add_star(sizes[i] as Star.Size, positions[i]))
	pack_burst.emit(kind, burst, born)


## Clears every star in the sky for base dust plus a bonus per star. No light.
func _big_bang(burst: Vector2i) -> void:
	var cleared: Array[Star] = stars.duplicate()
	stars.clear()
	var gain: int = balance.big_bang_base_dust + balance.big_bang_dust_per_cleared_star * cleared.size()
	dust += gain
	big_bang_started.emit(burst, cleared, gain)


## Returns the stars for a link, or an empty array if the ids aren't 3 distinct sky stars.
func _stars_for_link(star_ids: Array[int]) -> Array[Star]:
	var linked: Array[Star] = []
	if star_ids.size() != Combos.LINK_LENGTH:
		return linked
	for id: int in star_ids:
		var star: Star = find_star(id)
		if star == null or linked.has(star):
			linked.clear()
			return linked
		linked.append(star)
	return linked


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
	if light >= balance.sun_target:
		outcome = Outcome.WON
		run_won.emit()
		return
	var can_buy: bool = dust >= balance.cheapest_pack_cost()
	if total_packs() == 0 and not can_buy and not has_remaining_combo():
		outcome = Outcome.LOST
		run_lost.emit()
