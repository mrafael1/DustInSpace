class_name SkyView
extends Node2D
## Shows the run's stars: one StarView per star id on the StarLayer.
## Spawns views when a pack_burst event plays and removes them when a combo or Big Bang
## takes their stars. Owns no rules; it only follows the events the sequencer plays, so a
## star added to the run without an event (RunState.add_star) gets no view until the next setup.
## Halos are painted on the HaloLayer, under every star, so no halo covers another star.
## Linking: pointer input goes through a LinkGesture; the traced line is on the LinkLayer and
## the reward preview on the RewardPlaque. The link itself is RunState.link()'s call.

const StarViewScene := preload("res://game/scenes/star_view.tscn")

## Each star of a burst leaves a little after the previous one.
const BURST_STAGGER: float = 0.04
## Touch target per star, whatever its sprite: at least 44 pt (art-direction.md). With integer
## scaling a phone shows about 2 pt per native px, so a 22 px circle is 44 pt.
const HIT_RADIUS: int = 11

var _run: RunState
var _sequencer: EventSequencer
var _views: Dictionary[int, StarView] = {}
var _gesture := LinkGesture.new(star_at)
## Where the pointer is, for the line that follows a drag.
var _finger: Vector2i = Vector2i.ZERO

@onready var _halo_layer: Node2D = $HaloLayer
@onready var _link_layer: LinkLayer = $LinkLayer
@onready var _star_layer: Node2D = $StarLayer
@onready var _plaque: RewardPlaque = $UILayer/RewardPlaque


func _ready() -> void:
	_halo_layer.draw.connect(_draw_halos)
	_gesture.selection_changed.connect(_on_selection_changed)
	_gesture.link_requested.connect(_on_link_requested)


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
	for star: Star in run.stars:
		_spawn(star)


## The view of a star still in the sky, or null.
func star_view(id: int) -> StarView:
	return _views.get(id)


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


## The id of the star whose hit circle holds `point` (the nearest if several do), or 0.
## Uses the positions from the core, so a star still drifting home is hit where it will rest.
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
	return best_id


## Ids of the stars selected for the link being traced, in the order they were picked.
func selected_ids() -> Array[int]:
	return _gesture.selected.duplicate()


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_burst":
			_burst(event.args[1], event.args[2])
		&"combo_collected":
			_link_layer.flash_collected(_positions(event.args[1]))
			_dissolve(event.args[1])
		&"link_rejected":
			_link_layer.flash_rejected(_positions_of_ids(event.args[0]))
		&"big_bang_started":
			# Placeholder until the Big Bang sequence (#9): the cleared stars just dissolve.
			_dissolve(event.args[1])


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
	for id: int in _views:
		_views[id].selected = ids.has(id)
	_show_link()


func _on_link_requested(ids: Array[int]) -> void:
	_run.link(ids)


## Line through the selected stars (and to the finger while dragging), plus the reward preview.
func _show_link() -> void:
	var points: Array[Vector2i] = _positions_of_ids(_gesture.selected)
	if _gesture.is_dragging() and points.size() < Combos.LINK_LENGTH:
		points.append(_finger)
	_link_layer.show_path(points)
	_show_preview()


## Reads the combo and its reward; the plaque only displays them.
func _show_preview() -> void:
	var ids: Array[int] = _gesture.selected
	if ids.size() != Combos.LINK_LENGTH:
		_plaque.visible = false
		return
	var sizes: Array[int] = []
	for id: int in ids:
		sizes.append(_run.find_star(id).size)
	var last: Star = _run.find_star(ids[-1])
	var half: int = StarView.half_extent(last.size)
	var combo: String = Combos.evaluate(sizes)
	if combo == Combos.INVALID:
		_plaque.show_no_combo(last.position, half, _run.sky_rect)
	else:
		var reward: Balance.ComboReward = _run.balance.combos[combo]
		_plaque.show_reward(reward.dust, reward.light, last.position, half, _run.sky_rect)


func _positions(stars: Array[Star]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for star: Star in stars:
		points.append(star.position)
	return points


## Positions of the ids still in the run; unknown ids are skipped.
func _positions_of_ids(ids: Array[int]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for id: int in ids:
		var star: Star = _run.find_star(id)
		if star != null:
			points.append(star.position)
	return points


func _burst(burst: Vector2i, stars: Array[Star]) -> void:
	for i: int in stars.size():
		_spawn(stars[i]).fly_from(burst, i * BURST_STAGGER)
	# Input returns once the last star is past its overshoot; the settle keeps playing after.
	_sequencer.hold(BURST_STAGGER * maxi(stars.size() - 1, 0) + StarView.SETTLE_TIME * StarView.OVERSHOOT_PEAK)


func _dissolve(stars: Array[Star]) -> void:
	for star: Star in stars:
		var view: StarView = _views.get(star.id)
		if view != null:
			_views.erase(star.id)
			view.dissolve()
	if not stars.is_empty():
		_sequencer.hold(StarView.DISSOLVE_TIME)


func _spawn(star: Star) -> StarView:
	var view: StarView = StarViewScene.instantiate()
	view.setup(star, _run.sky_rect)
	view.halo_changed.connect(_on_halo_changed)
	_star_layer.add_child(view)
	_views[star.id] = view
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
