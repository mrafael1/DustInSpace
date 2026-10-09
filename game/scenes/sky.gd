class_name SkyView
extends Node2D
## Shows the run's stars: one StarView per star id on the StarLayer.
## Spawns views when a pack_burst event plays and removes them when a combo or Big Bang
## takes their stars. Owns no rules; it only follows the events the sequencer plays, so a
## star added to the run without an event (RunState.add_star) gets no view until the next setup.
## Halos are painted on the HaloLayer, under every star, so no halo covers another star.
## Linking: pointer input goes through a LinkGesture; the traced line is on the LinkLayer. The
## link itself is RunState.link()'s call; its payout floats up from it (PayoutPopups, #59).
## Scorpio (#40): the ConstellationLayer, under everything, draws the landmarks and the outline.
## Unlit landmarks can be picked like stars (their ids are negative, Scorpio.landmark_id); the
## combo and the strings a link would form come from RunState. When the Sun rekindles, a sunbeam
## carries its light to the landmark it lights (launch_sunbeam, wired by Main). Each step of a link
## has a reach (RunState.link_reach): while tracing, the LinkLayer shows it as a ring around the
## last star picked, and a star out of reach can't join (its step shakes ember; the link stays).
## A rekindle and the completion clear the sky: every star left bursts in turn, lowest first
## (sky_cleared).
## Big Bang: the pack still "opens" into decoy stars (presentation only: never in the run, never
## linkable), then every star in the sky and the decoys collapse into the burst point.
## Orion (#64): on stages he hunts, the OrionLayer shows his figure, the reticle on the star he
## marked, his bow readying while a traced link would leave it behind, and his arrow; the shot star
## bursts as the arrow lands, once that link resolves. On the Heart (#71) it shows his hunting
## area's ring; each launch, once the pack's stars are out, his arrow strikes it.
## The boss stage (the final): Orion enters as it opens (boss_appeared), each landmark lit hurts
## him, and the completion starts with his fall (his stars burst one by one) before the
## constellation plays.

## A star joined the link being traced; `count` stars are in it now. Feedback only (sound).
signal star_selected(count: int)
## Scorpio: the rekindled Sun sent a sunbeam to the landmark it lights. Feedback only (sound).
signal sunbeam_launched
## Scorpio: the sunbeam reached its landmark at `at` (it lights now). Feedback only (sparks, sound).
signal sunbeam_landed(at: Vector2i)
## The link being traced changed: `ids` are in it now, in order (empty once it ends). Feedback only
## (the tutorial's hand follows it).
signal link_traced(ids: Array[int])
## A pick couldn't stand (`reason`, a RunState.PickRefusal: a second landmark in one link); the link
## was dropped at once. The HUD says why (#91).
signal link_refused(reason: RunState.PickRefusal)
## Scorpio: a star out of reach of the last one picked couldn't join the link. Feedback only.
signal step_refused
## The player let a traced link go: the drag was released away from its last star, so nothing was
## linked and the selection is gone. Feedback only (sound).
signal link_cancelled
## Scorpio: the constellation is complete and a star left in the sky burst at `at` (or Orion's
## arrow broke it). Feedback only.
signal star_exploded(at: Vector2i)
## A draining current took a star at `at`, on the field's edge. Feedback only.
signal star_drained(at: Vector2i)
## The heat burned a star out at `at`. Feedback only.
signal star_burned(at: Vector2i)
## The cold faded a small star out at `at`. Feedback only.
signal star_faded(at: Vector2i)
## The Head: a big constellation star burned back to small at `at`. Feedback only.
signal landmark_rekindled(at: Vector2i)
## Virgo's harvest: the scythe swept the sky. Feedback only (sound).
signal harvest_swept
## Virgo's bound sheaves: a constellation star at `at` went dark. Feedback only (sound).
signal landmark_put_out(at: Vector2i)
## Virgo's binding intro: the star joined to the figure was kept. Feedback only (sound).
signal landmark_kept(at: Vector2i)
## Virgo's binding intro: its demo combo collected (no payout). Feedback only (sound).
signal intro_link_collected

const StarViewScene := preload("res://game/scenes/star_view.tscn")

## Each star of a burst leaves a little after the previous one.
const BURST_STAGGER: float = 0.04
## Scorpio's completion clears the sky: the stars left burst one after another, from the bottom of
## the sky to the top, this far apart, before the constellation plays.
const EXPLODE_STAGGER: float = 0.06
## Touch target per star, whatever its sprite: at least 44 pt (art-direction.md). With integer
## scaling a phone shows about 2 pt per native px, so a 22 px circle is 44 pt.
const HIT_RADIUS: int = 11

## Orion's volley intro (#70): how long its stars show before the volley takes them.
const INTRO_HOLD: float = 0.9
## Virgo's binding intro: its demo combo is traced at this many seconds a step, star to star.
const INTRO_TRACE_STEP: float = 0.32
## No heatwave: a resize starts everywhere at once.
const NO_ORIGIN := Vector2i(-9999, -9999)
## Leo's heat intro: the beat between one change of its stars and the next (or their leaving).
const HEAT_INTRO_BEAT: float = 0.55

var _run: RunState
var _sequencer: EventSequencer
var _views: Dictionary[int, StarView] = {}
var _gesture := LinkGesture.new(star_at)
## The kind of the pack last launched, so a Big Bang's decoys look like that pack's stars.
var _launched_kind: String = ""
## Draws decoy sizes and places. Its own stream, so decoys never shift the run's randomness.
var _decoy_rng := RandomNumberGenerator.new()
## Where the pointer is, for the line that follows a drag.
var _finger: Vector2i = Vector2i.ZERO
## Stars in the link as last shown, to tell a star joining it from one leaving.
var _selected_count: int = 0
## Scorpio: the landmark the rekindling Sun lights, for its sunbeam (-1: none).
var _rekindle_landmark: int = -1
## Scorpio: the completion tune waits for the payouts still flying.
var _payouts: CollectParticles
var _completion_waiting: bool = false

@onready var _constellation: ConstellationView = $ConstellationLayer
@onready var _halo_layer: Node2D = $HaloLayer
@onready var _link_layer: LinkLayer = $LinkLayer
@onready var _star_layer: Node2D = $StarLayer
@onready var _orion: OrionView = $OrionLayer
@onready var _current: CurrentView = $CurrentLayer
@onready var _heat: HeatView = $HeatLayer
@onready var _harvest: HarvestView = $HarvestLayer


func _ready() -> void:
	_decoy_rng.randomize()
	_constellation.sunbeam_landed.connect(func(at: Vector2i) -> void: sunbeam_landed.emit(at))
	_constellation.landmark_rekindled.connect(func(index: int) -> void:
		var at: Vector2i = _run.scorpio.landmark_position(index)
		_heat.flash_burn(at)
		landmark_rekindled.emit(at))
	_halo_layer.draw.connect(_draw_halos)
	_gesture.selection_changed.connect(_on_selection_changed)
	_gesture.link_requested.connect(_on_link_requested)
	_gesture.can_join = _can_join
	_gesture.join_refused.connect(_on_join_refused)
	_gesture.link_cancelled.connect(func() -> void: link_cancelled.emit())
	_orion.star_fell.connect(func(at: Vector2i) -> void: star_exploded.emit(at))
	_orion.fallen.connect(_constellation.play_completion)


func _unhandled_input(event: InputEvent) -> void:
	if handle_pointer(make_input_local(event)):
		get_viewport().set_input_as_handled()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
			_sequencer.sequence_started.disconnect(_gesture.cancel)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
		# A sequence takes the input (its pointer events are swallowed), so drop any link in progress.
		_sequencer.sequence_started.connect(_gesture.cancel)
	_gesture.cancel()
	_clear()
	_completion_waiting = false
	_rekindle_landmark = -1
	_constellation.setup(run)
	_orion.setup(run.orion != null or run.volley != null or run.hunt != null, run.sky_rect)
	if run.volley != null:
		_orion.show_volley_charge(run.volley.links_left(), run.volley.interval)
	if run.scorpio != null and run.scorpio.map.boss:
		_orion.setup_boss(run.scorpio.unlit_sizes().size())
	for star: Star in run.stars:
		_spawn(star)


## The view of a star still in the sky, or null.
func star_view(id: int) -> StarView:
	return _views.get(id)


## The payout particles the completion tune waits for (Main wires them).
func watch_payouts(payouts: CollectParticles) -> void:
	_payouts = payouts
	_payouts.all_landed.connect(_on_payouts_landed)


## Scorpio: the Sun (at `sun`) finished its ignition and releases its light: a sunbeam carries it
## to the landmark it lights, which lights as the beam lands.
func launch_sunbeam(sun: Vector2i) -> void:
	_constellation.launch_sunbeam(sun, _rekindle_landmark)
	if _rekindle_landmark >= 0:
		sunbeam_launched.emit()
	_rekindle_landmark = -1


func star_count() -> int:
	return _views.size()


## Feeds one touch or drag (in sky coordinates) to the link gesture. Only the first finger
## links. Returns true if the event was used, so it shouldn't reach anything else.
func handle_pointer(event: InputEvent) -> bool:
	if _run == null or _run.is_over():
		return false
	var used: bool = false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).index == 0:
		used = _on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == 0:
		_finger = Vector2i((event as InputEventScreenDrag).position.floor())
		_gesture.drag(_finger)
		used = _gesture.is_dragging()
	else:
		return false
	_show_link()
	return used


## The id of the star (or Scorpio landmark) whose hit circle holds `point` (the nearest if
## several do), or 0. Uses the positions from the core, so a star still drifting home is hit
## where it will rest.
func star_at(point: Vector2i) -> int:
	var best_id: int = 0
	var best_dist_sq: int = HIT_RADIUS * HIT_RADIUS + 1
	for id: int in _views:
		var star: Star = _run.find_star(id)
		if star == null:
			continue
		var dist_sq: int = (star.position - point).length_squared()
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_id = id
	if _run.scorpio != null:
		for i: int in _run.scorpio.map.count():
			if _run.scorpio.is_lit(i):
				continue
			var dist_sq: int = (_run.scorpio.landmark_position(i) - point).length_squared()
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				best_id = Scorpio.landmark_id(i)
	return best_id


## Ids of the stars selected for the link being traced, in the order they were picked.
func selected_ids() -> Array[int]:
	return _gesture.selected.duplicate()


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	# The gap hints follow the stars in the sky.
	_constellation.queue_redraw()
	match event.type:
		&"pack_burst":
			_burst(event.args[1], event.args[2])
		&"stars_shifted":
			_shift(event.args[0])
		&"stars_resized":
			_resize(event.args[0])
		&"combo_collected":
			_link_layer.flash_collected(_positions(event.args[1]))
			_dissolve(event.args[1])
		&"link_rejected":
			_link_layer.flash_rejected(_positions_of_ids(event.args[0]))
		&"pack_launched":
			_launched_kind = event.args[0]
		&"big_bang_started":
			_big_bang(event.args[0], event.args[1])
		&"landmark_lit":
			_constellation.flash_landmark(event.args[0])
			_orion.hurt(_unlit_shown())
		&"boss_appeared":
			_orion.enter()
			_sequencer.hold(OrionView.ENTER_TIME)
		&"string_built":
			_constellation.flash_string(event.args[0])
		&"sun_rekindled":
			_rekindle_landmark = event.args[0]
		&"sky_cleared":
			_explode(event.args[0])
		&"constellation_completed":
			# No volley follows: the arrows overhead go.
			_orion.clear_overhead()
			# The tune waits for every payout to land (watch_payouts); the sequence waits for it.
			_sequencer.hold(CollectParticles.LONGEST_TRAVEL + _completion_time())
			if _payouts != null and _payouts.particle_count() > 0:
				_completion_waiting = true
			else:
				_play_completion()
		&"star_marked":
			var marked: StarView = _views.get((event.args[0] as Star).id)
			if marked != null:
				_orion.mark(marked)
				_sequencer.hold(OrionView.MARK_TIME)
		&"star_shot":
			_shoot(event.args[0])
		&"volley_intro_placed":
			for star: Star in event.args[0]:
				_spawn(star)
			# A beat to see the stars before the intro volley takes them.
			_sequencer.hold(INTRO_HOLD)
		&"volley_fired":
			_volley(event.args[0])
		&"volley_counted":
			# A new countdown: Orion shoots its arrows up to hang overhead (#98), and play waits.
			var staging: float = _orion.show_volley_charge(event.args[0], _run.volley.interval)
			if staging > 0.0:
				_sequencer.hold(staging)
		&"area_struck":
			_strike_area(event.args[1])
		&"hunt_intro_placed":
			for star: Star in event.args[0]:
				_spawn(star)
			# A beat to see the stars before Orion marks his circle round them.
			_sequencer.hold(INTRO_HOLD)
		&"hunt_intro_burst":
			_burst(event.args[0], event.args[1])
		&"heat_intro_placed":
			for star: Star in event.args[0]:
				_spawn(star)
			# A beat to see the stars before the heat changes them.
			_sequencer.hold(INTRO_HOLD)
		&"current_intro_placed":
			for star: Star in event.args[0]:
				_spawn(star)
			# A beat to see the stars before the flow carries them.
			_sequencer.hold(INTRO_HOLD)
		&"current_intro_flowed":
			# The water shows the way it's about to flow (a tide's turn), a beat before it does.
			_current.show_flow(event.args[0])
			_sequencer.hold(HEAT_INTRO_BEAT)
		&"current_intro_cleared":
			# What the flow left fades out once it has been seen: no reward, nothing drained.
			_sequencer.hold(StarView.DISSOLVE_TIME)
			for star: Star in event.args[0]:
				var view: StarView = _views.get(star.id)
				if view != null:
					_views.erase(star.id)
					view.dissolve()
		&"heat_breathed":
			_breathe(event.args[0], event.args[1])
		&"lion_arrived":
			_sequencer.hold(_constellation.play_blaze())
		&"landmarks_resized":
			_constellation.resize_landmarks(event.args[0])
			_sequencer.hold(StarView.RESIZE_TIME)
		&"heat_intro_paused":
			_sequencer.hold(HEAT_INTRO_BEAT)
		&"heat_intro_turned":
			# The Mane's demo: night falls (or day breaks) before the cold acts.
			_heat.show_change(event.args[0])
			_sequencer.hold(HEAT_INTRO_BEAT)
		&"heat_intro_cleared":
			# What the heat left fades out once it has been seen: no reward, nothing burst.
			_sequencer.hold(StarView.DISSOLVE_TIME)
			for star: Star in event.args[0]:
				var view: StarView = _views.get(star.id)
				if view != null:
					_views.erase(star.id)
					view.dissolve()
		&"area_marked":
			_orion.mark_area(event.args[0], event.args[1])
			_sequencer.hold(OrionView.MARK_TIME)
		&"harvested":
			_reap(event.args[0])
		&"landmarks_unbound":
			_put_out(event.args[0])
		&"harvest_intro_ended":
			# The demo planet's stars leave once they've been seen: no reward.
			_sequencer.hold(StarView.DISSOLVE_TIME + INTRO_HOLD)
			for star: Star in event.args[0]:
				var view: StarView = _views.get(star.id)
				if view != null:
					_views.erase(star.id)
					view.dissolve()
		&"harvest_intro_quickened":
			# A beat to see the clock: ripe, then one ear fewer, then as the run starts.
			_sequencer.hold(INTRO_HOLD)
		&"harvest_intro_placed":
			for star: Star in event.args[0]:
				_spawn(star)
			# A beat to see the stars before the scythe takes them.
			_sequencer.hold(INTRO_HOLD)
		&"harvest_intro_lit":
			# The demo combo is traced star by star, collects and lights the star; then a beat to see it
			# lit, joined or alone, before the next.
			_sequencer.hold(_trace_intro_link(event.args[2], event.args[0], event.args[1]) + INTRO_HOLD)
		&"harvest_intro_kept":
			var at: Vector2i = _run.scorpio.landmark_position(event.args[0])
			_harvest.flash_kept(at)
			landmark_kept.emit(at)
			_sequencer.hold(HarvestView.KEPT_TIME)
		&"harvest_intro_cleared":
			# A beat to see what the scythe kept, then the demo's star shows as it really is.
			_sequencer.hold(INTRO_HOLD)
			for index: int in event.args[0]:
				_constellation.put_out(index)
	# A marked star that left the sky (a combo, a clear, a Big Bang) takes its reticle with it.
	if _orion.marked() != null and not _views.values().has(_orion.marked()):
		_orion.clear_mark()


## Presses only start inside the sky; a release always ends the press that started.
func _on_touch(touch: InputEventScreenTouch) -> bool:
	var point := Vector2i(touch.position.floor())
	_finger = point
	if touch.canceled:
		_gesture.cancel()
		return true
	if touch.pressed:
		if not _run.sky_rect.has_point(point) and star_at(point) == 0:
			return false
		return _gesture.press(point)
	return _gesture.release(point)


func _on_selection_changed(ids: Array[int]) -> void:
	var refusal: RunState.PickRefusal = _run.pick_refusal(ids) if _run != null else RunState.PickRefusal.NONE
	if refusal != RunState.PickRefusal.NONE:
		_refuse_link(ids, refusal)
		return
	for id: int in _views:
		_views[id].selected = ids.has(id)
	_show_hints(ids)
	if ids.size() > _selected_count:
		star_selected.emit(ids.size())
	_selected_count = ids.size()
	_show_link()
	link_traced.emit(ids)


## The link hint (playtest): while a link is traced, the stars and landmarks that could come next
## and still make a valid combo keep their look with a pulsing halo (StarView.hinted), and every
## other star dims (StarView.dimmed, ConstellationView.show_hints). Nothing before the first pick.
func _show_hints(ids: Array[int]) -> void:
	var next: Array[int] = _run.link_candidates(ids) if _run != null else ([] as Array[int])
	var landmarks: Array[int] = []
	for id: int in next:
		if _run.scorpio != null and _run.scorpio.is_landmark(id):
			landmarks.append(Scorpio.landmark_index(id))
	var tracing: bool = not ids.is_empty()
	for id: int in _views:
		_views[id].hinted = next.has(id)
		_views[id].dimmed = tracing and not next.has(id) and not ids.has(id)
	_constellation.show_hints(landmarks, tracing)


## A lost run's beat (EndScreen.loss_beat_started): every star left in the sky, and every
## unlit landmark, dims a step as the link hint dims them, and stays so. Presentation only.
func cool_down() -> void:
	for id: int in _views:
		_views[id].hinted = false
		_views[id].dimmed = true
	_constellation.show_hints([], true)


## The idle hint (#90, IdleHint): the stars and landmarks of `ids` shine with the link hint's shine
## and nothing dims; empty clears it. Never while a link is traced: the link hint has the sky then.
func show_idle_hint(ids: Array[int]) -> void:
	if _run == null or not _gesture.selected.is_empty():
		return
	var landmarks: Array[int] = []
	for id: int in ids:
		if _run.scorpio != null and _run.scorpio.is_landmark(id):
			landmarks.append(Scorpio.landmark_index(id))
	for id: int in _views:
		_views[id].hinted = ids.has(id)
	_constellation.show_hints(landmarks, false)


## Where the stars and landmarks of `ids` are, in order (ids no longer in the run are skipped).
func link_points(ids: Array[int]) -> Array[Vector2i]:
	return _positions_of_ids(ids)


## A pick the core refuses (RunState.pick_refusal: a second landmark in one link) drops the link on
## the spot with the red shake of a wrong link along its line, and the HUD's line says why (#91), so
## the rule shows on the first try.
func _refuse_link(ids: Array[int], reason: RunState.PickRefusal) -> void:
	_link_layer.flash_rejected(_positions_of_ids(ids))
	_gesture.cancel()
	link_refused.emit(reason)


func _on_link_requested(ids: Array[int]) -> void:
	_run.link(ids)


## A star may join the link only within reach of the last one picked (RunState rules the same).
func _can_join(ids: Array[int], id: int) -> bool:
	if ids.is_empty() or _run == null:
		return true
	var ends: Array[Vector2i] = _positions_of_ids([ids[-1], id] as Array[int])
	return ends.size() < 2 or _run.in_reach(ends[0], ends[1])


func _on_join_refused(ids: Array[int], id: int) -> void:
	if ids.is_empty():
		return
	_link_layer.flash_rejected(_positions_of_ids([ids[-1], id] as Array[int]))
	step_refused.emit()


## Line through the selected stars (and to the finger while dragging), plus the reward preview.
## With a reach, the line to the finger goes loose past it. A drag that has left its last star (a
## release now lets the link go) shows the whole line let go, out to the finger.
func _show_link() -> void:
	var points: Array[Vector2i] = _positions_of_ids(_gesture.selected)
	var loose: bool = false
	var reach: int = 0
	var letting_go: bool = _gesture.is_letting_go()
	if letting_go:
		points.append(_finger)
	elif _gesture.is_dragging() and points.size() < Combos.LINK_LENGTH:
		loose = not points.is_empty() and not _run.in_reach(points[-1], _finger)
		reach = _run.link_reach()
		points.append(_finger)
	_link_layer.show_path(points, loose, reach, letting_go)
	_show_preview()
	# Orion readies his bow while the link would leave his mark behind (the sight line holds on it),
	# or loose the volley.
	if _run != null:
		_orion.ready_bow(_run.link_shoots(_gesture.selected), _run.link_fires_volley(_gesture.selected))
		# Leo's final: a full, valid link shows what its breath would do.
		var full: bool = _gesture.selected.size() == Combos.LINK_LENGTH and _run.combo_for(_gesture.selected) != Combos.INVALID
		var breathes: bool = _run.scorpio != null and _run.scorpio.map.heat_on_links
		_heat.tracing = _gesture.selected if full and breathes else ([] as Array[int])


## On the Scorpio map, previews the landmarks in the link, the strings it would form, and where it
## would sting. (The boxed reward preview is gone, #59: the payout floats up once collected.)
func _show_preview() -> void:
	if _run.scorpio == null:
		return
	var ids: Array[int] = _gesture.selected
	var landmarks: Array[int] = []
	for id: int in ids:
		if _run.scorpio.is_landmark(id):
			landmarks.append(Scorpio.landmark_index(id))
	_constellation.show_link_preview(landmarks, _run.strings_for(ids))


func _on_payouts_landed() -> void:
	if _completion_waiting:
		_completion_waiting = false
		_play_completion()


## The boss stage: Orion falls first, his stars bursting one by one, then the constellation plays.
func _play_completion() -> void:
	_sequencer.hold(_completion_time())
	if _run != null and _run.scorpio != null and _run.scorpio.map.boss:
		_orion.fall()
		return
	_constellation.play_completion()


## How many landmarks show unlit: the boss's health.
func _unlit_shown() -> int:
	var count: int = 0
	if _run != null and _run.scorpio != null:
		for i: int in _run.scorpio.map.count():
			if not _constellation.shows_lit(i):
				count += 1
	return count


## How long the completion plays here: Orion's fall on the boss stage, then the constellation.
func _completion_time() -> float:
	var map: StarMap = _run.scorpio.map if _run != null and _run.scorpio != null else null
	var fall: float = OrionView.FALL_TIME if map != null and map.boss else 0.0
	return fall + ConstellationView.completion_time(map, _constellation.repeat)


func _positions(stars: Array[Star]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for star: Star in stars:
		points.append(star.position)
	return points


## Positions of the ids still in the run (landmarks included); unknown ids are skipped.
func _positions_of_ids(ids: Array[int]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for id: int in ids:
		if _run.scorpio != null and _run.scorpio.is_landmark(id):
			points.append(_run.scorpio.landmark_position(Scorpio.landmark_index(id)))
			continue
		var star: Star = _run.find_star(id)
		if star != null:
			points.append(star.position)
	return points


func _burst(burst: Vector2i, stars: Array[Star]) -> void:
	for i: int in stars.size():
		_spawn(stars[i]).fly_from(burst, i * BURST_STAGGER)
	# Input returns once the last star is past its overshoot; the settle keeps playing after.
	# A current starts from the settled positions shown in its preview.
	var flight: float = StarView.SETTLE_TIME if _run.current != null else StarView.SETTLE_TIME * StarView.OVERSHOOT_PEAK
	_sequencer.hold(BURST_STAGGER * maxi(stars.size() - 1, 0) + flight)


## The Big Bang's stars: decoys fly out like a normal burst, then at the freeze every star,
## decoys included, is pulled into the burst point. BigBangSequence holds the sequencer.
func _big_bang(burst: Vector2i, cleared: Array[Star]) -> void:
	var collapsing: Array[StarView] = []
	for star: Star in cleared:
		var view: StarView = _views.get(star.id)
		if view != null:
			_views.erase(star.id)
			collapsing.append(view)
	var decoys: Array[Star] = _decoys(burst)
	for i: int in decoys.size():
		var view: StarView = _add_view(decoys[i])
		view.fly_from(burst, i * BURST_STAGGER)
		collapsing.append(view)
	for view: StarView in collapsing:
		view.collapse_to(burst, BigBangSequence.FREEZE_AT, BigBangSequence.COLLAPSE_TIME, BigBangSequence.SWIRL, BigBangSequence.HOVER)


## Stars the launched pack would have opened into, drawn and placed like real ones. Ids are
## negative so they never match a star in the run.
func _decoys(burst: Vector2i) -> Array[Star]:
	var pack: Balance.PackDef = _run.balance.packs.get(_launched_kind)
	var count: int = pack.stars * pack.bursts if pack != null else 3
	var weights: Array[int] = pack.weights if pack != null else [1, 1, 1] as Array[int]
	var places: Array[Vector2i] = StarScatter.place(count, burst, _run.sky_rect, [] as Array[Vector2i], _decoy_rng)
	var decoys: Array[Star] = []
	for i: int in count:
		decoys.append(Star.new(-1 - i, PackOpener.draw_size(weights, _decoy_rng) as Star.Size, places[i]))
	return decoys


## Scorpio's rekindle or completion: the stars left burst in turn, lowest first, and what follows
## (the tune) waits for them.
func _explode(stars: Array[Star]) -> void:
	var order: Array[Star] = explode_order(stars)
	var last: int = -1
	for i: int in order.size():
		var view: StarView = _views.get(order[i].id)
		if view == null:
			continue
		_views.erase(order[i].id)
		view.exploded.connect(func(v: StarView) -> void: star_exploded.emit(Vector2i(v.position)))
		view.explode(i * EXPLODE_STAGGER)
		last = i
	if last >= 0:
		_sequencer.hold(EXPLODE_STAGGER * last + StarView.DISSOLVE_TIME)


## The order a sky clear bursts `stars` in, EXPLODE_STAGGER apart: lowest first, then left to
## right. Their dust leaves in the same order (CollectParticles).
static func explode_order(stars: Array[Star]) -> Array[Star]:
	var order: Array[Star] = stars.duplicate()
	order.sort_custom(func(a: Star, b: Star) -> bool:
		return a.position.y > b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	return order


## Orion's arrow flies to `star`, which bursts as it lands; the next events wait for it.
func _shoot(star: Star) -> void:
	var landing: float = _orion.shoot(star.position, star.size)
	var view: StarView = _views.get(star.id)
	if view != null:
		_views.erase(star.id)
		view.exploded.connect(func(v: StarView) -> void: star_exploded.emit(Vector2i(v.position)))
		view.explode(landing)
	_sequencer.hold(landing + StarView.DISSOLVE_TIME * 0.5)


## Orion's hunting area (#71): his arrow flies to the ring's centre, and the stars inside burst as
## it lands; the next events (the new ring) wait for it.
## The current: every moved star drifts; a drained one drifts to the field's edge and cuts out
## there as the drain flashes, for nothing.
func _shift(moves: Array[StarCurrent.Move]) -> void:
	for move: StarCurrent.Move in moves:
		var view: StarView = _views.get(move.star_id)
		if view == null:
			continue
		if not move.drained:
			view.drift_to(move.to)
			continue
		_views.erase(move.star_id)
		view.drained.connect(func(v: StarView) -> void:
			_current.flash_drain(Vector2i(v.position), Vector2i(signi(move.to.x - move.from.x), signi(move.to.y - move.from.y)))
			star_drained.emit(Vector2i(v.position)))
		view.drain_to(_edge_point(move.to))
	_sequencer.hold(StarView.DRIFT_TIME)


## The lion breathed (Leo's final): a heatwave rolls out from the link at `at`, and every star it
## changes, loose or the lion's own, charges and pops as the wave reaches it.
func _breathe(at: Vector2i, changes: Array[StarHeat.Change]) -> void:
	_heat.flash_breath(at)
	var loose: Array[StarHeat.Change] = []
	var lion: Array[StarHeat.Change] = []
	var delays: Dictionary = {}
	var latest: float = 0.0
	for change: StarHeat.Change in changes:
		if change.star_id < 0:
			var index: int = Scorpio.landmark_index(change.star_id)
			delays[index] = HeatView.breath_delay(at, _run.scorpio.landmark_position(index))
			latest = maxf(latest, delays[index])
			lion.append(change)
		else:
			loose.append(change)
	_constellation.resize_landmarks(lion, delays)
	var hold: float = _resize(loose, at)
	_sequencer.hold(maxf(hold, latest + StarView.RESIZE_TIME))


## The heat (or the cold): every changed star charges and pops to its new size where it stands; a
## lost one charges the same, then bursts into embers (a big burning out) or a fall of frost (a
## small fading), for nothing. With a heatwave from `origin`, each starts as the wave reaches it.
## Returns (and holds) how long it plays.
func _resize(changes: Array[StarHeat.Change], origin: Vector2i = NO_ORIGIN) -> float:
	var hold: float = StarView.RESIZE_TIME
	for change: StarHeat.Change in changes:
		var view: StarView = _views.get(change.star_id)
		if view == null:
			continue
		var delay: float = 0.0 if origin == NO_ORIGIN else HeatView.breath_delay(origin, Vector2i(view.position))
		hold = maxf(hold, delay + StarView.RESIZE_TIME)
		if not change.lost:
			view.resize_to(change.to, delay)
			continue
		_views.erase(change.star_id)
		var fades: bool = change.is_cold()
		view.exploded.connect(func(v: StarView) -> void:
			if fades:
				_heat.flash_fade(Vector2i(v.position))
				star_faded.emit(Vector2i(v.position))
			else:
				_heat.flash_burn(Vector2i(v.position))
				star_burned.emit(Vector2i(v.position)))
		view.charge(fades, delay)
		view.explode(delay + StarView.RESIZE_FLARE)
		hold = maxf(hold, delay + StarView.RESIZE_FLARE + StarView.DISSOLVE_TIME)
	_sequencer.hold(hold)
	return hold


## Where a drained star's path meets the field's edge: the first pixel outside it.
func _edge_point(exit: Vector2i) -> Vector2i:
	var area: Rect2i = _run.current.region
	return Vector2i(clampi(exit.x, area.position.x - 1, area.end.x), clampi(exit.y, area.position.y - 1, area.end.y))


func _strike_area(stars: Array[Star]) -> void:
	var landing: float = _orion.strike_area()
	for star: Star in stars:
		var view: StarView = _views.get(star.id)
		if view != null:
			_views.erase(star.id)
			view.exploded.connect(func(v: StarView) -> void: star_exploded.emit(Vector2i(v.position)))
			view.explode(landing)
	_sequencer.hold(landing + StarView.DISSOLVE_TIME * 0.5)


## Orion's volley: the arrows overhead rain down, one onto each star it takes, which bursts as its
## arrow lands; the next events wait for the last (an empty sky: for the arrows to reach the horizon).
func _volley(stars: Array[Star]) -> void:
	var targets: Array[Vector2i] = []
	for star: Star in stars:
		targets.append(star.position)
	var landings: Array[float] = _orion.fire_volley(targets)
	var last: float = _orion.volley_time()
	for i: int in stars.size():
		last = landings[i]
		var view: StarView = _views.get(stars[i].id)
		if view != null:
			_views.erase(stars[i].id)
			view.exploded.connect(func(v: StarView) -> void: star_exploded.emit(Vector2i(v.position)))
			view.explode(landings[i])
	_sequencer.hold(last + StarView.DISSOLVE_TIME * 0.5)


## Virgo's harvest: the scythe's blade sweeps the sky, cutting each reaped star as it passes.
func _reap(stars: Array[Star]) -> void:
	var lasts: float = _harvest.sweep()
	harvest_swept.emit()
	for star: Star in stars:
		var view: StarView = _views.get(star.id)
		if view == null:
			continue
		_views.erase(star.id)
		var delay: float = _harvest.cut_delay(star.position.x)
		view.exploded.connect(func(v: StarView) -> void: _harvest.flash_chaff(Vector2i(v.position)))
		view.explode(delay)
		lasts = maxf(lasts, delay + StarView.DISSOLVE_TIME)
	_sequencer.hold(lasts)


## Virgo's binding intro: the demo combo `link` (two demo stars, then constellation star `index`) is
## traced as a player would, the line running from star to star at INTRO_TRACE_STEP a step (each
## star selected as it's reached, chiming its note), then it collects (the line flares, the demo stars
## dissolve) and the constellation star lights, its lone ring on if it's `alone`. Returns how long.
func _trace_intro_link(link: Array[int], index: int, alone: bool) -> float:
	var points: Array[Vector2i] = []
	for id: int in link:
		points.append(_run.scorpio.landmark_position(Scorpio.landmark_index(id)) if Scorpio.is_landmark_id(id) else Vector2i(_views[id].position) if _views.has(id) else Vector2i.ZERO)
	var steps: int = points.size() - 1
	var tween: Tween = create_tween()
	_selected_count = 0
	tween.tween_method(_show_intro_trace.bind(link, points), 0.0, float(steps), INTRO_TRACE_STEP * steps)
	tween.tween_callback(_collect_intro_link.bind(link, points, index, alone))
	return INTRO_TRACE_STEP * steps + StarView.DISSOLVE_TIME


## The demo combo `t` steps along `points` (the stars of `link`): the line up to its tip, the stars
## reached so far selected.
func _show_intro_trace(t: float, link: Array[int], points: Array[Vector2i]) -> void:
	var reached: int = mini(floori(t), points.size() - 1)
	var path: Array[Vector2i] = points.slice(0, reached + 1)
	if reached < points.size() - 1:
		path.append(Vector2i(Vector2(points[reached]).lerp(Vector2(points[reached + 1]), t - reached).round()))
	_link_layer.show_path(path)
	for k: int in reached + 1:
		if _views.has(link[k]):
			_views[link[k]].selected = true
	if reached + 1 > _selected_count:
		_selected_count = reached + 1
		star_selected.emit(_selected_count)


func _collect_intro_link(link: Array[int], points: Array[Vector2i], index: int, alone: bool) -> void:
	_selected_count = 0
	_link_layer.show_path([] as Array[Vector2i])
	_link_layer.flash_collected(points)
	for id: int in link:
		var view: StarView = _views.get(id)
		if view != null:
			_views.erase(id)
			view.dissolve()
	_constellation.flash_landmark(index)
	if alone:
		_harvest.show_alone(_run.scorpio.landmark_position(index), _run.scorpio.map.sizes[index])
	intro_link_collected.emit()


## Virgo's bound sheaves: the constellation stars the harvest put out go dark, one after another.
func _put_out(indices: Array[int]) -> void:
	for index: int in indices:
		var at: Vector2i = _run.scorpio.landmark_position(index)
		# The lit strings that joined it snap with it.
		var ends: Array[Vector2i] = []
		for n: int in _run.scorpio.map.neighbours(index):
			if _constellation.shows_lit(n):
				ends.append(_run.scorpio.landmark_position(n))
		_constellation.crop(index, HarvestView.CROP_TIME)
		_harvest.flash_crop(at, _constellation.shown_size(index), ends)
		landmark_put_out.emit(at)
	_sequencer.hold(HarvestView.CROP_TIME)


func _dissolve(stars: Array[Star]) -> void:
	for star: Star in stars:
		var view: StarView = _views.get(star.id)
		if view != null:
			_views.erase(star.id)
			view.dissolve()
	if not stars.is_empty():
		_sequencer.hold(StarView.DISSOLVE_TIME)


func _spawn(star: Star) -> StarView:
	var view: StarView = _add_view(star)
	_views[star.id] = view
	return view


## A view on the star layer that isn't tracked as one of the run's stars.
func _add_view(star: Star) -> StarView:
	var view: StarView = StarViewScene.instantiate()
	view.setup(star, _run.sky_rect)
	view.halo_changed.connect(_on_halo_changed)
	_star_layer.add_child(view)
	return view


## Removes every view, including ones still dissolving from the previous run.
func _clear() -> void:
	for view: Node in _star_layer.get_children():
		view.queue_free()
	_views.clear()
	_halo_layer.queue_redraw()


func _on_halo_changed(_view: StarView) -> void:
	_halo_layer.queue_redraw()


## Every star's halo, including stars still dissolving, before any star is drawn.
func _draw_halos() -> void:
	for view: Node in _star_layer.get_children():
		if view.is_queued_for_deletion():
			continue
		var dots: Dictionary[Vector2i, Color] = (view as StarView).halo_dots()
		for dot: Vector2i in dots:
			_halo_layer.draw_rect(Rect2(Vector2(dot), Vector2.ONE), dots[dot])
