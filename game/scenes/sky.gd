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

## A star joined the link being traced; `count` stars are in it now. Feedback only (sound).
signal star_selected(count: int)
## Scorpio: the rekindled Sun sent a sunbeam to the landmark it lights. Feedback only (sound).
signal sunbeam_launched
## Scorpio: the sunbeam reached its landmark at `at` (it lights now). Feedback only (sparks, sound).
signal sunbeam_landed(at: Vector2i)
## Scorpio: a second landmark was picked for one link; the link was dropped at once. Feedback only.
signal link_refused
## Scorpio: a star out of reach of the last one picked couldn't join the link. Feedback only.
signal step_refused
## Scorpio: the constellation is complete and a star left in the sky burst at `at` (or Orion's
## arrow broke it). Feedback only.
signal star_exploded(at: Vector2i)

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


func _ready() -> void:
	_decoy_rng.randomize()
	_constellation.sunbeam_landed.connect(func(at: Vector2i) -> void: sunbeam_landed.emit(at))
	_halo_layer.draw.connect(_draw_halos)
	_gesture.selection_changed.connect(_on_selection_changed)
	_gesture.link_requested.connect(_on_link_requested)
	_gesture.can_join = _can_join
	_gesture.join_refused.connect(_on_join_refused)


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
		&"string_built":
			_constellation.flash_string(event.args[0])
		&"sun_rekindled":
			_rekindle_landmark = event.args[0]
		&"sky_cleared":
			_explode(event.args[0])
		&"constellation_completed":
			# The tune waits for every payout to land (watch_payouts); the sequence waits for it.
			_sequencer.hold(CollectParticles.LONGEST_TRAVEL + ConstellationView.COMPLETION_TIME)
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
			_orion.show_volley_charge(event.args[0], _run.volley.interval)
		&"area_struck":
			_strike_area(event.args[1])
		&"area_marked":
			_orion.mark_area(event.args[0], event.args[1])
			_sequencer.hold(OrionView.MARK_TIME)
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
	if _too_many_landmarks(ids):
		_refuse_link(ids)
		return
	for id: int in _views:
		_views[id].selected = ids.has(id)
	if ids.size() > _selected_count:
		star_selected.emit(ids.size())
	_selected_count = ids.size()
	_show_link()


## Scorpio: a link can hold only Scorpio.LANDMARKS_PER_COMBO landmarks; picking another is
## refused on the spot, with the red shake of a wrong link, so the rule shows on the first try.
func _too_many_landmarks(ids: Array[int]) -> bool:
	if _run == null or _run.scorpio == null:
		return false
	return ids.filter(_run.scorpio.is_landmark).size() > Scorpio.LANDMARKS_PER_COMBO


func _refuse_link(ids: Array[int]) -> void:
	_link_layer.flash_rejected(_positions_of_ids(ids))
	_gesture.cancel()
	link_refused.emit()


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
## With a reach, the ring around the last star picked shows how far the next step can go, and the
## line to the finger goes loose past it.
func _show_link() -> void:
	var points: Array[Vector2i] = _positions_of_ids(_gesture.selected)
	var open: bool = not points.is_empty() and points.size() < Combos.LINK_LENGTH
	var loose: bool = false
	if _gesture.is_dragging() and points.size() < Combos.LINK_LENGTH:
		loose = not points.is_empty() and not _run.in_reach(points[-1], _finger)
		points.append(_finger)
	_link_layer.show_path(points, loose)
	var reach: int = _run.link_reach() if _run != null else 0
	_link_layer.show_reach(points[_gesture.selected.size() - 1] if open else Vector2i.ZERO, reach if open else 0)
	_show_preview()
	# Orion readies his bow while the link would leave his mark behind (the sight line holds on it),
	# or loose the volley.
	if _run != null:
		_orion.ready_bow(_run.link_shoots(_gesture.selected), _run.link_fires_volley(_gesture.selected))


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


func _play_completion() -> void:
	_constellation.play_completion()
	_sequencer.hold(ConstellationView.COMPLETION_TIME)


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
	_sequencer.hold(BURST_STAGGER * maxi(stars.size() - 1, 0) + StarView.SETTLE_TIME * StarView.OVERSHOOT_PEAK)


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
	var count: int = pack.stars if pack != null else 3
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
func _strike_area(stars: Array[Star]) -> void:
	var landing: float = _orion.strike_area()
	for star: Star in stars:
		var view: StarView = _views.get(star.id)
		if view != null:
			_views.erase(star.id)
			view.exploded.connect(func(v: StarView) -> void: star_exploded.emit(Vector2i(v.position)))
			view.explode(landing)
	_sequencer.hold(landing + StarView.DISSOLVE_TIME * 0.5)


## Orion's volley: an arrow flies to each star it takes, which bursts as its arrow lands; the next
## events wait for the last.
func _volley(stars: Array[Star]) -> void:
	var targets: Array[Vector2i] = []
	for star: Star in stars:
		targets.append(star.position)
	var landings: Array[float] = _orion.fire_volley(targets)
	var last: float = OrionView.DRAW_TIME
	for i: int in stars.size():
		last = landings[i]
		var view: StarView = _views.get(stars[i].id)
		if view != null:
			_views.erase(stars[i].id)
			view.exploded.connect(func(v: StarView) -> void: star_exploded.emit(Vector2i(v.position)))
			view.explode(landings[i])
	_sequencer.hold(last + StarView.DISSOLVE_TIME * 0.5)


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
