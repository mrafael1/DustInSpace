class_name SkyView
extends Node2D
## Shows the run's stars: one StarView per star id on the StarLayer.
## Spawns views when a pack_burst event plays and removes them when a combo or Big Bang
## takes their stars. Owns no rules; it only follows the events the sequencer plays.

const StarViewScene := preload("res://game/scenes/star_view.tscn")

## Each star of a burst leaves a little after the previous one.
const BURST_STAGGER: float = 0.04

var _run: RunState
var _sequencer: EventSequencer
var _views: Dictionary[int, StarView] = {}

@onready var _star_layer: Node2D = $StarLayer


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_clear()
	for star: Star in run.stars:
		_spawn(star)


## The view of a star still in the sky, or null.
func star_view(id: int) -> StarView:
	return _views.get(id)


func star_count() -> int:
	return _views.size()


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_burst":
			_burst(event.args[1], event.args[2])
		&"combo_collected":
			_dissolve(event.args[1])
		&"big_bang_started":
			# Placeholder until the Big Bang sequence (#9): the cleared stars just dissolve.
			_dissolve(event.args[1])


func _burst(burst: Vector2i, stars: Array[Star]) -> void:
	for i: int in stars.size():
		_spawn(stars[i]).fly_from(burst, i * BURST_STAGGER)
	_sequencer.hold(StarView.SETTLE_TIME + BURST_STAGGER * maxi(stars.size() - 1, 0))


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
	_star_layer.add_child(view)
	_views[star.id] = view
	return view


## Removes every view, including ones still dissolving from the previous run.
func _clear() -> void:
	for view: Node in _star_layer.get_children():
		view.queue_free()
	_views.clear()
