class_name BurstSparks
extends Node2D
## The opening burst's spark pixels (game-feel: ring, spark pixels, stars scatter). The launcher
## draws the ring and the sky scatters the stars; this throws 1 px sparks out from the burst
## point, slowing as they go and cooling C0 to C3 before they vanish.
## A Big Bang starts exactly like a normal burst to keep the surprise, so it gets the same sparks.
## Owns no rules and never holds the sequencer.

const SPARKS: int = 12
## Spark life, inside the burst's ~650 ms.
const SPARK_TIME: float = 0.5
const REACH_MIN: int = 10
const REACH_MAX: int = 22
## A spark cools one step per quarter of its life.
const COOLING: Array[Color] = [Palette.C0, Palette.C1, Palette.C2, Palette.C3]


class Burst:
	extends RefCounted
	var at: Vector2i
	var age: float = 0.0
	## One end point per spark, as an offset from `at`.
	var reach: Array[Vector2] = []


var _sequencer: EventSequencer
var _bursts: Array[Burst] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for burst: Burst in _bursts:
		var dots: Dictionary[Vector2i, Color] = spark_pixels(burst.reach, burst.age / SPARK_TIME)
		for offset: Vector2i in dots:
			draw_rect(Rect2(Vector2(burst.at + offset), Vector2.ONE), dots[offset])


func setup(_run: RunState, sequencer: EventSequencer) -> void:
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_bursts.clear()
	queue_redraw()


func is_sparking() -> bool:
	return not _bursts.is_empty()


## Moves the sparks on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	if _bursts.is_empty():
		return
	for burst: Burst in _bursts:
		burst.age += delta
	_bursts = _bursts.filter(func(b: Burst) -> bool: return b.age < SPARK_TIME)
	queue_redraw()


## The sparks' pixels at `t` (0 to 1 of their life), as offsets from the burst point. They
## ease out to their reach and cool one ramp step per quarter; nothing is left at t = 1.
static func spark_pixels(reach: Array[Vector2], t: float) -> Dictionary[Vector2i, Color]:
	var dots: Dictionary[Vector2i, Color] = {}
	if t >= 1.0:
		return dots
	var travelled: float = 1.0 - (1.0 - t) * (1.0 - t)
	var colour: Color = COOLING[clampi(floori(t * COOLING.size()), 0, COOLING.size() - 1)]
	for end: Vector2 in reach:
		dots[Vector2i((end * travelled).round())] = colour
	return dots


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_burst":
			_spark(event.args[1])
		&"big_bang_started":
			_spark(event.args[0])


func _spark(at: Vector2i) -> void:
	var burst := Burst.new()
	burst.at = at
	for i: int in SPARKS:
		var angle: float = TAU * (i + _rng.randf_range(-0.3, 0.3)) / SPARKS
		burst.reach.append(Vector2.from_angle(angle) * _rng.randf_range(REACH_MIN, REACH_MAX))
	_bursts.append(burst)
	queue_redraw()
