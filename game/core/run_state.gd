class_name RunState
extends RefCounted
## One "Restore the Sun" run: dust, light, owned packs, the launcher, stars in the sky,
## and win/loss. Resolves every action instantly; scenes animate from the signals.
## On the Scorpio map (#40) the objective is the constellation instead: lighting every landmark
## wins. A combo may use unlit landmarks as stars (they light up instead of being used up), and a
## full Sun doesn't win: it rekindles (back to 0 light), lights one landmark and clears the sky. There the Sun fills at scorpio.sun_target, and each step of a link, from
## one star to the next, must be at most scorpio.max_link_distance long.

signal pack_bought(kind: String, dust_after: int)
## `kind` is now in the slingshot; "" when a launch left it empty.
signal pack_loaded(kind: String)
signal pack_launched(kind: String, burst_position: Vector2i)
signal pack_burst(kind: String, burst_position: Vector2i, stars: Array[Star])
## A pack that splits (the red pack's twin burst) split at `at` into planets that burst at `points`
## (a pack_burst for each follows; a Big Bang splits too, then collapses at `at`).
signal pack_split(kind: String, at: Vector2i, points: Array[Vector2i])
## The burst(s) settled, then the current shifted loose stars. Positions are event snapshots.
## A move flagged drained took its star out of the sky, for nothing.
signal stars_shifted(moves: Array[StarCurrent.Move])
## The heat (Leo) changed the size of loose stars once the launch resolved (after any current).
## A change flagged lost took its star out of the sky, for nothing.
signal stars_resized(changes: Array[StarHeat.Change])
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
## Scorpio: every star still in the sky is cleared: `stars` were removed, paying `dust`. When
## the Sun rekindles (after the landmark it lights; each star it bursts pays sun_dust_per_star)
## and when a combo completes the constellation (just before constellation_completed; they pay
## nothing, the run is won). Only when the sky had stars.
signal sky_cleared(stars: Array[Star], dust: int)
## Scorpio: the last landmark lit. On the Scorpio map that's the win (run_won follows).
signal constellation_completed
## Orion (#64): Orion marked `star`, a loose sky star: after a successful link, or after a burst
## when none was marked. The next link that leaves it behind has his arrow take it.
signal star_marked(star: Star)
## Orion: a successful link left the marked `star` behind, and his arrow destroyed it. No reward.
signal star_shot(star: Star)
## Orion's volley (#70): a successful link was counted; `links_left` more until the next volley.
signal volley_counted(links_left: int)
## Orion's volley: a counted link looses it, and his arrows destroyed `stars` (maybe none). No reward.
signal volley_fired(stars: Array[Star])
## Orion's volley intro: a volley stage opened with `stars` already in the sky (the intro volley
## destroys them next).
signal volley_intro_placed(stars: Array[Star])
## Orion's hunting area (#71): he marked a circle of `radius` px at `centre`; the next launch's
## arrow strikes it.
signal area_marked(centre: Vector2i, radius: int)
## Orion's hunting area: a launch's pack burst, then his arrow struck the circle at `centre` and
## destroyed the loose `stars` inside (maybe none). No reward.
signal area_struck(centre: Vector2i, stars: Array[Star])
## Orion's hunting intro: the stage opened with `stars` already in the sky (inside the circle
## area_marked shows next).
signal hunt_intro_placed(stars: Array[Star])
## Orion's hunting intro: a demo pack of `kind` flies to `burst` (presentation: no pack is used).
signal hunt_intro_launched(kind: String, burst: Vector2i)
## Orion's hunting intro: the demo pack burst at `burst` into `stars` (area_struck takes them next).
signal hunt_intro_burst(burst: Vector2i, stars: Array[Star])
## The boss stage (the final) opened: Orion shows himself before play starts. Presentation only.
signal boss_appeared
## The guided first run moved on to `step` (a Tutorial.Step).
signal tutorial_step(step: int)
## An Orion threat's guided encounter (#93) moved on: `threat` (an Encounter.Threat) is at `step`
## (an Encounter.Step: GUIDING, then DONE).
signal encounter_step(threat: int, step: int)
signal run_won
signal run_lost

enum Outcome { PLAYING, WON, LOST }
## The loss check's three conditions: a lost run has all of them.
enum LossReason { NO_PACKS, NO_DUST, NO_COMBINATION }
## Why the picks of a link being traced can't stand, for the views to explain (#91): none, or a
## second constellation star in one link (Scorpio.LANDMARKS_PER_COMBO).
enum PickRefusal { NONE, SECOND_LANDMARK }


## The hunt's encounter: a safe launch spot keeps every burst point of the loaded pack this far
## beyond the circle's edge on top of the scatter ring's reach (StarScatter.RING_MAX), so its stars
## land clear of it even when the scatter relaxes them outward. Guide layout, not balance.
const ENCOUNTER_CLEARANCE: int = 10
## Candidate launch spots are tried on a grid this many px apart when no constellation star is safe.
const SAFE_SPOT_GRID: int = 8
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
## Orion (#64), or null when the map doesn't bring him (or balance.json has no "orion" block).
var orion: Orion
## Orion's volley (#70), or null when the map doesn't bring it (or balance.json has no "volley").
var volley: Volley
## Orion's hunting area (#71), or null when the map doesn't bring it (or balance.json has no "hunt").
var hunt: Hunt
## The guided first run (start_tutorial), or null: it says which actions are allowed.
var tutorial: Tutorial
## The stage's guided encounter with the threat it introduces (start_encounter), or null.
var encounter: Encounter
var current: StarCurrent
## Leo's heat (chapter 3), or null when the map has none.
var heat: StarHeat
## Existing-star reservations for this launch, also respected by the burst's scatter.
var _current_reserved: Dictionary[int, Vector2i] = {}
## The guided run's Sun has rekindled once (its own target is spent).
var _tutorial_rekindled: bool = false
## The landmark the last rekindle lit, for the tutorial (-1: none since the link began).
var _rekindled_landmark: int = -1

var _rng: RandomNumberGenerator
var _layout_rng := RandomNumberGenerator.new()
var _next_star_id: int = 1
var _boss_shown: bool = false


## `p_map`: the constellation layout when balance.json turns the constellation on (the full
## Scorpio unless a chapter stage gives its own, #62).
func _init(p_balance: Balance, p_rng: RandomNumberGenerator, p_sky_rect: Rect2i, p_map: StarMap = null) -> void:
	assert(p_balance.is_valid(), "RunState needs a valid Balance: %s" % [p_balance.errors])
	assert(StarScatter.inner_rect(p_sky_rect).has_area(), "sky rect too small for the edge margin")
	balance = p_balance
	sky_rect = p_sky_rect
	_rng = p_rng
	run_seed = p_rng.seed
	_layout_rng.seed = p_rng.seed ^ LAYOUT_SEED_SALT
	dust = balance.start_dust
	if balance.scorpio_enabled:
		scorpio = Scorpio.new(p_sky_rect, p_map)
		if scorpio.map.orion and balance.orion_first_mark_launch > 0:
			orion = Orion.new(balance.orion_first_mark_launch, run_seed)
		var tuning: Balance.VolleyDef = balance.volley(scorpio.map.volley)
		if tuning != null:
			volley = Volley.new(tuning.interval, tuning.fraction, run_seed, tuning.intro_stars)
		if scorpio.map.hunt and balance.hunt_radius > 0:
			hunt = Hunt.new(balance.hunt_radius, run_seed)
		var step: int = balance.current_step_for(scorpio.map.id)
		if scorpio.map.current_region.has_area() and step > 0:
			var area: Rect2i = _stage_area(scorpio.map.current_region)
			current = StarCurrent.new(area, scorpio.map.current_direction * step, scorpio.map.current_drains, scorpio.map.current_turns)
		if scorpio.map.heat_region.has_area():
			heat = StarHeat.new(_stage_area(scorpio.map.heat_region), scorpio.map.heat_change, scorpio.map.heat_burns)
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


## The light that fills the Sun: its own target on the Scorpio map, else sun_target. The guided
## first run fills it sooner the first time (scorpio.tutorial_sun_target), so a full Sun is shown.
func light_target() -> int:
	if tutorial != null and not _tutorial_rekindled and balance.scorpio_tutorial_sun_target > 0:
		return balance.scorpio_tutorial_sun_target
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
	for i: int in scorpio.map.count():
		if not scorpio.is_lit(i):
			pool.append(scorpio.landmark_star(i))
	for a: int in pool.size():
		for b: int in range(a + 1, pool.size()):
			for c: int in range(b + 1, pool.size()):
				var trio: Array[Star] = [pool[a], pool[b], pool[c]]
				if trio.filter(func(s: Star) -> bool: return scorpio.is_landmark(s.id)).size() > Scorpio.LANDMARKS_PER_COMBO:
					continue
				if Combos.evaluate([trio[0].size, trio[1].size, trio[2].size] as Array[int]) != Combos.INVALID and _can_chain(trio):
					return true
	return false


## Whether three stars can be linked in some order with every step in reach: one of them (the
## middle of the link) must reach both others.
func _can_chain(trio: Array[Star]) -> bool:
	return not _chain_order(trio).is_empty()


## `trio` in an order that links it with every step in reach (the middle one reaches both others),
## or empty if none does.
func _chain_order(trio: Array[Star]) -> Array[Star]:
	for m: int in 3:
		var mid: Star = trio[m]
		var first: Star = trio[(m + 1) % 3]
		var last: Star = trio[(m + 2) % 3]
		if in_reach(mid.position, first.position) and in_reach(mid.position, last.position):
			return [first, mid, last] as Array[Star]
	return [] as Array[Star]


## The idle hint (#90: show a stuck player a link): the ids of one valid link, in an order that
## keeps every step in reach, or empty when no link can be made (or the run is over). On the
## Scorpio map it may hold one unlit landmark, never two. Every valid link is as good as another:
## `rng` picks one.
func idle_hint_link(rng: RandomNumberGenerator) -> Array[int]:
	var found: Array[Array] = valid_links()
	if found.is_empty():
		return [] as Array[int]
	var picked: Array[int] = []
	picked.assign(found[rng.randi_range(0, found.size() - 1)])
	return picked


## Every valid link in the sky (unlit landmarks included, one at most), each as ids in an order that
## keeps every step in reach; none once the run is over.
func valid_links() -> Array[Array]:
	var found: Array[Array] = []
	if is_over():
		return found
	var pool: Array[Star] = stars.duplicate()
	if scorpio != null:
		for i: int in scorpio.map.count():
			if not scorpio.is_lit(i):
				pool.append(scorpio.landmark_star(i))
	for a: int in pool.size():
		for b: int in range(a + 1, pool.size()):
			for c: int in range(b + 1, pool.size()):
				var ordered: Array[Star] = _chain_order([pool[a], pool[b], pool[c]] as Array[Star])
				if ordered.is_empty():
					continue
				var ids: Array[int] = []
				for star: Star in ordered:
					ids.append(star.id)
				if combo_for(ids) != Combos.INVALID:
					found.append(ids)
	return found


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


## Pure preview of what the heat does to the stars now in the sky on the next launch (after any
## current carries them; a star it drains is gone first). The stars that launch brings don't change.
func heat_preview() -> Array[StarHeat.Change]:
	if heat == null:
		return []
	var positions: Dictionary[int, Vector2i] = current_preview()
	var remaining: Array[Star] = []
	for star: Star in stars:
		if current == null or not current.leaves(star.position, positions[star.id]):
			remaining.append(star)
	return heat.preview(remaining, {}, positions)


## Pure preview: no RNG draws and no changes to stars. New arrivals yield to these destinations.
func current_preview() -> Dictionary[int, Vector2i]:
	if current == null:
		return {}
	return current.preview(stars, sky_rect, scorpio.landmark_positions())


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
	# The tutorial's buy step ends here, so the bought pack may load.
	if tutorial != null and tutorial.bought():
		tutorial_step.emit(tutorial.step)
	load_pack(kind)
	return true


## Puts an owned pack in the slingshot.
func load_pack(kind: String) -> bool:
	if is_over() or owned_packs.get(kind, 0) <= 0:
		return false
	if tutorial != null and not tutorial.allows_load() and loaded_pack != kind:
		return false
	if loaded_pack != kind:
		loaded_pack = kind
		pack_loaded.emit(kind)
	return true


## Launches the loaded pack toward `target`. The burst point is clamped into the sky. A pack that
## splits (bursts > 1) bursts at points across it instead, one pack_burst each; it is still one
## launch: one Big Bang roll, one Orion count, one strike after every burst.
## With Orion: no arrow; after the pack opens he marks a loose star if none is marked. With his
## hunting area (#71): once the pack has opened, his arrow strikes the circle he marked (the new
## stars too), then he marks a new one. Win and loss are checked once, at the end.
func launch(target: Vector2i) -> bool:
	if is_over() or loaded_pack == "" or owned_packs.get(loaded_pack, 0) <= 0:
		return false
	var kind: String = loaded_pack
	var burst: Vector2i = StarScatter.clamp_to_sky(target, sky_rect)
	if tutorial != null and not tutorial.allows_launch(burst, _tutorial_landmark_at()):
		return false
	_current_reserved = current_preview()
	owned_packs[kind] -= 1
	pack_launched.emit(kind, burst)
	if encounter != null and encounter.launched():
		encounter_step.emit(encounter.threat, encounter.step)
	if orion != null:
		orion.count_launch()
	var big_bangs: bool = scorpio == null or balance.scorpio_big_bang
	var result: PackOpener.PackResult = PackOpener.open(balance.packs[kind], _rng, force_next_big_bang, big_bangs)
	force_next_big_bang = false
	var pack: Balance.PackDef = balance.packs[kind]
	if tutorial != null:
		var scripted: Array[int] = tutorial.pack_sizes(pack.stars * pack.bursts, _tutorial_landmark_size())
		if not scripted.is_empty():
			result.big_bang = false
			result.sizes = scripted
	# The stars this launch brings have ids from here on: the heat leaves them be until the next.
	var first_new_id: int = _next_star_id
	var points: Array[Vector2i] = []
	if pack.bursts > 1:
		points = StarScatter.split_points(burst, pack.burst_spread, pack.bursts, sky_rect)
		# A Big Bang splits too, so it opens like any red pack and keeps its surprise.
		pack_split.emit(kind, burst, points)
	if result.big_bang:
		_big_bang(burst)
	elif pack.bursts > 1:
		for i: int in points.size():
			_burst(kind, points[i], result.sizes.slice(i * pack.stars, (i + 1) * pack.stars))
	else:
		_burst(kind, burst, result.sizes)
	if current != null and not result.big_bang:
		_shift_stars()
	if heat != null and not result.big_bang:
		_heat_stars(first_new_id)
	if current != null:
		current.turn()
	_current_reserved.clear()
	# The hunting area's strike comes before any single mark, so a mark never lands on a star the
	# arrow is about to take.
	if hunt != null:
		_hunt_strike()
		area_marked.emit(hunt.mark(sky_rect, stars), hunt.radius)
		if encounter != null and encounter.area_marked():
			encounter_step.emit(encounter.threat, encounter.step)
	if orion != null and not orion.has_target():
		_orion_mark()
	_empty_slingshot()
	_check_end()
	if tutorial != null and tutorial.launched():
		tutorial_step.emit(tutorial.step)
	return true


## Starts the guided first run (a constellation stage): the first steps allow one action each and
## script the first three packs. Announces its first step.
func start_tutorial() -> void:
	if scorpio == null or tutorial != null:
		return
	tutorial = Tutorial.new()
	tutorial_step.emit(tutorial.step)


## Starts the stage's guided encounter with the threat it introduces (#93), once its intros have
## played (the scene calls it, the first time the stage is played): the volley's guide starts at once,
## the mark's and the circle's when they first appear. Returns whether there is one.
func start_encounter() -> bool:
	if scorpio == null or encounter != null or is_over():
		return false
	var threat: int = Encounter.threat_of(scorpio.map)
	if threat < 0:
		return false
	encounter = Encounter.new(threat as Encounter.Threat)
	if encounter != null and encounter.opened():
		encounter_step.emit(encounter.threat, encounter.step)
	return true


## The mark's encounter: a valid link that saves the marked star, in an order that keeps every
## step in reach (the first such link), or empty when none can be made.
func encounter_link() -> Array[int]:
	var target: Star = marked_star()
	if target == null:
		return [] as Array[int]
	for link: Array[int] in valid_links():
		if link.has(target.id):
			return link
	return [] as Array[int]


## The hunt's encounter: a spot to launch the loaded pack at so its stars land clear of the circle
## (is_safe_launch), near where it helps: the first unlit constellation star that's safe (in map
## order), else the safe spot of the inner sky nearest the first unlit one, else the spot furthest
## from the circle.
func safe_launch_spot() -> Vector2i:
	var inner: Rect2i = StarScatter.inner_rect(sky_rect)
	if hunt == null or not hunt.has_area():
		return inner.get_center()
	var goal: Vector2i = inner.get_center()
	if scorpio != null:
		var goal_set: bool = false
		for i: int in scorpio.map.count():
			if scorpio.is_lit(i):
				continue
			var at: Vector2i = scorpio.landmark_position(i)
			if is_safe_launch(at):
				return at
			if not goal_set:
				goal = at
				goal_set = true
	var best: Vector2i = Vector2i(-1, -1)
	var furthest: Vector2i = goal
	for y: int in range(inner.position.y, inner.end.y, SAFE_SPOT_GRID):
		for x: int in range(inner.position.x, inner.end.x, SAFE_SPOT_GRID):
			var spot := Vector2i(x, y)
			if (spot - hunt.centre).length_squared() > (furthest - hunt.centre).length_squared():
				furthest = spot
			if is_safe_launch(spot) and (best.x < 0 or (spot - goal).length_squared() < (best - goal).length_squared()):
				best = spot
	return best if best.x >= 0 else furthest


## Whether launching the loaded pack at `aim` keeps its stars out of the hunting circle: every point
## it bursts at (a split pack's every one) keeps its whole scatter ring, and a margin, outside it.
func is_safe_launch(aim: Vector2i) -> bool:
	if hunt == null or not hunt.has_area():
		return true
	var kind: String = loaded_pack if loaded_pack != "" else balance.pack_kinds()[0]
	var pack: Balance.PackDef = balance.packs[kind]
	var points: Array[Vector2i] = [StarScatter.clamp_to_sky(aim, sky_rect)]
	if pack.bursts > 1:
		points = StarScatter.split_points(aim, pack.burst_spread, pack.bursts, sky_rect)
	var clear: int = hunt.radius + StarScatter.RING_MAX + ENCOUNTER_CLEARANCE
	for point: Vector2i in points:
		if (point - hunt.centre).length_squared() <= clear * clear:
			return false
	return true


## The player tapped on through a tutorial step that only explains something.
func tutorial_continue() -> bool:
	if tutorial == null or not tutorial.continue_info():
		return false
	tutorial_step.emit(tutorial.step)
	return true


func _tutorial_landmark_at() -> Vector2i:
	return scorpio.landmark_position(tutorial.landmark) if tutorial.landmark >= 0 else Vector2i.ZERO


func _tutorial_landmark_size() -> int:
	return scorpio.map.sizes[tutorial.landmark] if tutorial.landmark >= 0 else Star.Size.SMALL


## Links exactly 3 distinct stars in the sky. An invalid link uses nothing up (nor moves Orion).
## On the Scorpio map a step between consecutive stars longer than the reach makes the link invalid.
## On the Scorpio map one unlit landmark can be in it too: the combo pays as usual and the
## landmark lights up instead of being used up. A full Sun then rekindles.
## Returns the combo key, or Combos.INVALID.
func link(star_ids: Array[int]) -> String:
	_rekindled_landmark = -1
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
	_orion_forget(linked)
	var reward: Balance.ComboReward = balance.combos[combo]
	dust += reward.dust
	light += reward.light
	combo_collected.emit(combo, linked, reward.dust, reward.light)
	if scorpio != null:
		for star: Star in linked:
			if scorpio.is_landmark(star.id):
				_light_landmark(Scorpio.landmark_index(star.id))
		# The last landmark lit is the win: no rekindle on top of it.
		var rekindled: bool = not scorpio.is_complete() and _rekindle_if_full()
		# A rekindled Sun bursts the sky's stars for dust; a combo's completion clears them for nothing.
		if rekindled:
			_clear_sky(balance.scorpio_sun_dust_per_star)
		elif scorpio.is_complete():
			_clear_sky(0)
		if scorpio.is_complete():
			constellation_completed.emit()
	# Orion: a link that left his mark behind has the arrow take it (a clear took it already), before
	# the loss check sees the sky. Then he marks a new star if the run goes on. On the Claws (#74) he
	# also looses volleys: the single arrow flies first, so the mark is always settled (saved or shot)
	# before the volley picks its victims, and the new mark comes after both: a volley never takes a
	# marked star, and no star is hit twice. Saving the mark doesn't touch the volley's count.
	if orion != null:
		_orion_shoot()
	if volley != null and not scorpio.is_complete():
		_count_for_volley()
	_check_end()
	if encounter != null and encounter.linked():
		encounter_step.emit(encounter.threat, encounter.step)
	if orion != null and not is_over():
		_orion_mark()
	if tutorial != null and not is_over():
		var lit: bool = linked.any(func(star: Star) -> bool: return scorpio != null and scorpio.is_landmark(star.id))
		if tutorial.linked(lit, rekindle_target() if scorpio != null else -1, owned_packs.get("red", 0) > 0, can_afford("blue"), _rekindled_landmark, not has_remaining_combo()):
			# The red planet's steps launch the one the run started with: it goes in the slingshot.
			if tutorial.step == Tutorial.Step.SCOPE and loaded_pack != "red":
				loaded_pack = "red"
				pack_loaded.emit("red")
			tutorial_step.emit(tutorial.step)
	return combo


## Orion: whether linking `star_ids` would have his arrow take the marked star: a valid link that
## leaves it behind and doesn't clear the sky (a rekindled Sun or the completion) first.
func link_shoots(star_ids: Array[int]) -> bool:
	if orion == null or not orion.has_target() or star_ids.has(orion.target):
		return false
	var combo: String = combo_for(star_ids)
	if combo == Combos.INVALID:
		return false
	return not _link_clears_sky(star_ids, balance.combos[combo].light)


## Scorpio: whether a valid link of `star_ids` paying `gain` light clears the sky: its Sun rekindles
## or its landmarks complete the constellation.
func _link_clears_sky(star_ids: Array[int], gain: int) -> bool:
	if scorpio == null:
		return false
	var lit: Array[bool] = scorpio.lit.duplicate()
	for id: int in star_ids:
		if scorpio.is_landmark(id):
			lit[Scorpio.landmark_index(id)] = true
	return light + gain >= light_target() or not lit.has(false)


## The link hint (playtest: show a new player what to pick next): the stars and unlit landmarks
## (by link id) that could join a link started with `star_ids` and still let it make a valid combo,
## every step in reach. After one pick, those in its reach that some third star could finish; after
## two, those that finish it now. Nothing before the first pick, after the third, for a link that
## can't be made, or once the run is over.
func link_candidates(star_ids: Array[int]) -> Array[int]:
	var found: Array[int] = []
	if is_over() or star_ids.is_empty() or star_ids.size() >= Combos.LINK_LENGTH:
		return found
	for id: int in star_ids:
		if _link_star(id) == null:
			return found
	var pool: Array[int] = []
	for star: Star in stars:
		pool.append(star.id)
	if scorpio != null:
		for i: int in scorpio.map.count():
			if not scorpio.is_lit(i):
				pool.append(Scorpio.landmark_id(i))
	for next: int in pool:
		if star_ids.has(next):
			continue
		var picked: Array[int] = star_ids.duplicate()
		picked.append(next)
		if picked.size() == Combos.LINK_LENGTH:
			if combo_for(picked) != Combos.INVALID:
				found.append(next)
			continue
		if not link_in_reach(picked):
			continue
		for last: int in pool:
			if picked.has(last):
				continue
			var trio: Array[int] = picked.duplicate()
			trio.append(last)
			if combo_for(trio) != Combos.INVALID:
				found.append(next)
				break
	return found


## Why the picks `star_ids` (in pick order) can't stand as a link in progress, or
## PickRefusal.NONE. The only such rule: one constellation star per link, so picking a second one
## is refused on the spot. (A step out of reach is refused before the pick: in_reach.)
func pick_refusal(star_ids: Array[int]) -> PickRefusal:
	if scorpio != null and star_ids.filter(scorpio.is_landmark).size() > Scorpio.LANDMARKS_PER_COMBO:
		return PickRefusal.SECOND_LANDMARK
	return PickRefusal.NONE


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
		if scorpio.is_landmark(id):
			lit[Scorpio.landmark_index(id)] = true
	for segment: int in scorpio.map.segment_count():
		var ends: Array[int] = scorpio.map.segment_landmarks(segment)
		if lit[ends[0]] and lit[ends[1]] and not scorpio.is_built(segment):
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
	_tutorial_rekindled = tutorial != null
	var index: int = rekindle_target()
	_rekindled_landmark = index
	sun_rekindled.emit(index)
	if index >= 0:
		_light_landmark(index)
	return true


## Scorpio: the landmark a rekindled Sun would light, or -1 when all are lit.
func rekindle_target() -> int:
	var first: int = -1
	for i: int in scorpio.map.count():
		if scorpio.is_lit(i):
			continue
		for n: int in scorpio.map.neighbours(i):
			if scorpio.is_lit(n):
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
	for destination: Vector2i in _current_reserved.values():
		if not occupied.has(destination):
			occupied.append(destination)
	var landmarks: Array[Vector2i] = []
	if scorpio != null:
		landmarks = scorpio.landmark_positions()
	var positions: Array[Vector2i] = StarScatter.place(sizes.size(), burst, sky_rect, occupied, _layout_rng, landmarks)
	var born: Array[Star] = []
	for i: int in sizes.size():
		var star: Star = add_star(sizes[i] as Star.Size, positions[i])
		# Core positions change immediately. Record the burst's pre-current positions for views.
		born.append(Star.new(star.id, star.size, star.position) if current != null else star)
	pack_burst.emit(kind, burst, born)


func _shift_stars() -> void:
	var destinations: Dictionary[int, Vector2i] = current.preview(stars, sky_rect, scorpio.landmark_positions(), _current_reserved)
	var shifted: Array[StarCurrent.Move] = current.moves(stars, destinations)
	for star: Star in stars:
		star.position = destinations[star.id]
	for move: StarCurrent.Move in shifted:
		if move.drained:
			stars.erase(find_star(move.star_id))
	if not shifted.is_empty():
		stars_shifted.emit(shifted)


func _heat_stars(first_new_id: int) -> void:
	var skip: Dictionary[int, bool] = {}
	for star: Star in stars:
		if star.id >= first_new_id:
			skip[star.id] = true
	var changes: Array[StarHeat.Change] = heat.preview(stars, skip)
	for change: StarHeat.Change in changes:
		var star: Star = find_star(change.star_id)
		if change.lost:
			stars.erase(star)
		else:
			star.size = change.to
	if not changes.is_empty():
		stars_resized.emit(changes)


## A stage region in home layout, placed in this sky: shifted with the map, and one spanning the
## home sky's full height spans this sky's.
func _stage_area(region: Rect2i) -> Rect2i:
	var area := Rect2i(region.position + scorpio.shift, region.size)
	if region.position.y <= Scorpio.HOME_SKY.position.y and region.end.y >= Scorpio.HOME_SKY.end.y:
		area = Rect2i(area.position.x, sky_rect.position.y, area.size.x, sky_rect.size.y)
	return area


## Scorpio's rekindle or completion: every star left in the sky goes, for `dust_per_star` each.
func _clear_sky(dust_per_star: int) -> void:
	if stars.is_empty():
		return
	var cleared: Array[Star] = stars.duplicate()
	stars.clear()
	_orion_forget(cleared)
	var gain: int = dust_per_star * cleared.size()
	dust += gain
	sky_cleared.emit(cleared, gain)


## Clears every star in the sky for base dust plus a bonus per star. No light.
func _big_bang(burst: Vector2i) -> void:
	var cleared: Array[Star] = stars.duplicate()
	stars.clear()
	_orion_forget(cleared)
	var gain: int = balance.big_bang_base_dust + balance.big_bang_dust_per_cleared_star * cleared.size()
	dust += gain
	big_bang_started.emit(burst, cleared, gain)


## Orion's volley: counts a successful link; the counted link that fills the interval destroys a
## share of the loose stars (after any Sun clear, so nothing is paid twice), before the loss check.
func _count_for_volley() -> void:
	if volley.count_link():
		var victims: Array[Star] = volley.pick(stars)
		for star: Star in victims:
			stars.erase(star)
		volley_fired.emit(victims)
		if encounter != null and encounter.volley_fired():
			encounter_step.emit(encounter.threat, encounter.step)
	volley_counted.emit(volley.links_left())


## The boss stage's entrance, as it opens (the scene calls it once its views are bound, before the
## other intros): Orion shows himself. It changes nothing in the run. Does nothing on a map that
## isn't a boss stage, or once the run has begun.
func play_boss_intro() -> void:
	if scorpio == null or not scorpio.map.boss or not stars.is_empty() or is_over() or _boss_shown:
		return
	_boss_shown = true
	boss_appeared.emit()


## Orion's volley intro, as a volley stage opens (the scene calls it once its views are bound): a
## few random stars already in the sky, then a volley at once that destroys them all. It pays
## nothing, doesn't count towards the next volley, and uses the volley's own RNG stream, so packs
## and layout never shift. Does nothing without a volley, on a map without intros, or once the run
## has begun.
func play_volley_intro() -> void:
	if volley == null or volley.intro_stars <= 0 or not scorpio.map.intros or not stars.is_empty() or is_over():
		return
	var sizes: Array[int] = volley.intro_sizes(volley.intro_stars)
	var spots: Array[Vector2i] = volley.intro_spots(StarScatter.inner_rect(sky_rect), sky_rect)
	var placed: Array[Star] = []
	var layout := RandomNumberGenerator.new()
	layout.seed = run_seed ^ Volley.SEED_SALT ^ LAYOUT_SEED_SALT
	for spot: int in spots.size():
		var count: int = sizes.size() / 2 if spot == 0 else sizes.size() - sizes.size() / 2
		var occupied: Array[Vector2i] = []
		for star: Star in placed:
			occupied.append(star.position)
		for p: Vector2i in StarScatter.place(count, spots[spot], sky_rect, occupied, layout, scorpio.landmark_positions()):
			placed.append(add_star(sizes[placed.size()] as Star.Size, p))
	volley_intro_placed.emit(placed)
	for star: Star in placed:
		stars.erase(star)
	volley_fired.emit(placed)
	# Like any volley, the countdown then shows where it stands (untouched: the intro doesn't count).
	volley_counted.emit(volley.links_left())


## Orion's hunting intro (#71), as the Heart opens (the scene calls it once its views are bound):
## the whole cycle once, to show what the circle means and when it strikes. A few stars in the sky,
## Orion marks a circle round them, a demo pack flies into it and bursts, then his arrow strikes the
## circle and takes them all. It pays nothing, uses no pack and leaves no circle (the first real
## launch marks one); it uses the hunt's own RNG stream, so packs and layout never shift. Does
## nothing without a hunt or an intro (or on a map without intros), or once the run has begun.
func play_hunt_intro() -> void:
	if hunt == null or balance.hunt_intro_stars <= 0 or not scorpio.map.intros or not stars.is_empty() or is_over():
		return
	var layout := RandomNumberGenerator.new()
	layout.seed = run_seed ^ Hunt.SEED_SALT ^ LAYOUT_SEED_SALT
	var centre: Vector2i = hunt.mark(sky_rect)
	var placed: Array[Star] = _hunt_intro_stars(balance.hunt_intro_stars, centre, layout)
	hunt_intro_placed.emit(placed)
	area_marked.emit(centre, hunt.radius)
	var kind: String = loaded_pack if loaded_pack != "" else balance.pack_kinds()[0]
	hunt_intro_launched.emit(kind, centre)
	var born: Array[Star] = _hunt_intro_stars(balance.packs[kind].stars, centre, layout)
	hunt_intro_burst.emit(centre, born)
	_hunt_strike()


## `count` stars of random sizes scattered round `centre`; one the scatter pushed out of the circle
## is pulled back in along its line, so the strike takes every one.
func _hunt_intro_stars(count: int, centre: Vector2i, layout: RandomNumberGenerator) -> Array[Star]:
	var occupied: Array[Vector2i] = []
	for star: Star in stars:
		occupied.append(star.position)
	var sizes: Array[int] = hunt.intro_sizes(count)
	var spots: Array[Vector2i] = StarScatter.place(count, centre, sky_rect, occupied, layout, scorpio.landmark_positions())
	var placed: Array[Star] = []
	for i: int in count:
		var spot: Vector2i = spots[i]
		if not hunt.contains(spot):
			spot = centre + Vector2i((Vector2(spot - centre).normalized() * (hunt.radius - 6)).round())
		placed.append(add_star(sizes[i] as Star.Size, spot))
	return placed


## Orion's volley: whether linking `star_ids` would loose it (a valid link, the last before the
## volley, that doesn't complete the stage).
func link_fires_volley(star_ids: Array[int]) -> bool:
	if volley == null or volley.links_left() != 1 or combo_for(star_ids) == Combos.INVALID:
		return false
	var lit: Array[bool] = scorpio.lit.duplicate()
	for id: int in star_ids:
		if scorpio.is_landmark(id):
			lit[Scorpio.landmark_index(id)] = true
	return lit.has(false)


## Orion's hunting area: the arrow strikes the marked circle (none on the first launch) and every
## loose star inside is destroyed, for nothing.
func _hunt_strike() -> void:
	if not hunt.has_area():
		return
	var at: Vector2i = hunt.centre
	var hit: Array[Star] = hunt.strike(stars)
	for star: Star in hit:
		stars.erase(star)
	_orion_forget(hit)
	area_struck.emit(at, hit)


## The star Orion has marked, or null.
func marked_star() -> Star:
	return find_star(orion.target) if orion != null and orion.has_target() else null


## Orion's arrow: the marked star, if it's still in the sky after a link, is destroyed for nothing.
func _orion_shoot() -> void:
	var star: Star = find_star(orion.draw_bow())
	if star == null:
		return
	stars.erase(star)
	star_shot.emit(star)


## Orion marks a loose sky star (the sky's stars: landmarks are never in it), if he can yet.
func _orion_mark() -> void:
	var id: int = orion.mark(stars)
	if id != 0:
		star_marked.emit(find_star(id))
		if encounter != null and encounter.marked():
			encounter_step.emit(encounter.threat, encounter.step)


func _orion_forget(gone: Array[Star]) -> void:
	if orion == null:
		return
	var ids: Array[int] = []
	for star: Star in gone:
		ids.append(star.id)
	orion.forget(ids)


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
		if scorpio != null and scorpio.is_landmark(id):
			landmark_count += 1
		else:
			sky_count += 1
		linked.append(star)
	if sky_count == 0 or landmark_count > Scorpio.LANDMARKS_PER_COMBO:
		linked.clear()
	return linked


## A sky star, or an unlit landmark on the Scorpio map, by link id. Null otherwise.
func _link_star(id: int) -> Star:
	if scorpio != null and scorpio.is_landmark(id):
		var index: int = Scorpio.landmark_index(id)
		return null if scorpio.is_lit(index) else scorpio.landmark_star(index)
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


## After a launch the slingshot stays empty until the player loads or buys a planet (playtest: an
## automatic reload made the next touch launch a planet they didn't pick). The guided run keeps
## reloading until free play: its scripted launches need their planet.
func _empty_slingshot() -> void:
	if tutorial != null and tutorial.step != Tutorial.Step.DONE:
		_auto_load()
	elif loaded_pack != "":
		loaded_pack = ""
		pack_loaded.emit("")


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
