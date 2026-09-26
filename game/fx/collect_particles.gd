class_name CollectParticles
extends Node2D
## Payouts travel (game-feel): when a combo_collected event plays, dust particles fly from the
## linked stars to the dust counter and light particles fly into the Sun. Each particle carries
## part of the reward; `dust_arrived` / `light_arrived` fire as it lands, so the counters tick up
## on arrival. Particles never hold the sequencer, so input comes back while they fly.
## A Big Bang's dust streams from the burst point once it bangs, in more, smaller shares.
## Owns no rules: the amounts come from the event. Every particle is 1-2 palette pixels on
## whole pixels: a head and a one-step-darker trail.

signal dust_arrived(amount: int)
signal light_arrived(amount: int)
## The last particle in the air has landed.
signal all_landed

enum Kind { DUST, LIGHT }

## Particles leave once the link has flared and dissolved.
const LAUNCH_DELAY: float = StarView.DISSOLVE_TIME
## Game-feel timings: staggered ~28 ms each, 750-1100 ms along a Bézier path.
const STAGGER: float = 0.028
const FLIGHT_MIN: float = 0.75
const FLIGHT_MAX: float = 1.1
## A reward bigger than this is shared between this many particles, so a big payout stays quick.
const MAX_PARTICLES: int = 10
## A Big Bang's dust streams in up to this many particles.
const BIG_BANG_PARTICLES: int = 24
## How far the path bows sideways at its middle, at most.
const MAX_BOW: int = 30
## The longest a combo's particles can take to all land: dust and light together.
const LONGEST_TRAVEL: float = LAUNCH_DELAY + STAGGER * (2 * MAX_PARTICLES - 1) + FLIGHT_MAX
## Head colour, then trail colour, per kind.
const COLOURS: Dictionary[Kind, Array] = {
	Kind.DUST: [Palette.D0, Palette.N8],
	Kind.LIGHT: [Palette.C0, Palette.C2],
}

## Where dust particles land: the dust icon.
@export var dust_target: Vector2i = Vector2i(12, 300)
## Where light particles land: the Sun's centre.
@export var light_target: Vector2i = Vector2i(90, 39)


class Particle:
	extends RefCounted
	var kind: Kind
	var amount: int
	var from: Vector2
	var bend: Vector2
	var to: Vector2
	var delay: float
	var duration: float
	var age: float = 0.0

	func progress() -> float:
		return clampf((age - delay) / duration, 0.0, 1.0)

	## The point at `t` along the quadratic Bézier, eased so it speeds into the counter.
	func point_at(t: float) -> Vector2i:
		var e: float = t * t
		return Vector2i(from.lerp(bend, e).lerp(bend.lerp(to, e), e).round())


var _sequencer: EventSequencer
var _particles: Array[Particle] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for p: Particle in _particles:
		if p.age < p.delay:
			continue
		var t: float = p.progress()
		var head: Vector2i = p.point_at(t)
		var trail: Vector2i = p.point_at(maxf(t - 0.06, 0.0))
		if trail != head:
			draw_rect(Rect2(Vector2(trail), Vector2.ONE), COLOURS[p.kind][1])
		draw_rect(Rect2(Vector2(head), Vector2.ONE), COLOURS[p.kind][0])


## A new run drops every particle still in the air: the new run's counters start from its state.
func setup(_run: RunState, sequencer: EventSequencer) -> void:
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_particles.clear()
	queue_redraw()


func in_flight(kind: Kind) -> int:
	var total: int = 0
	for p: Particle in _particles:
		if p.kind == kind:
			total += p.amount
	return total


func particle_count() -> int:
	return _particles.size()


## Moves every particle on and lands those that arrived. Driven by `_process`; tests call it.
func advance(delta: float) -> void:
	if _particles.is_empty():
		return
	var landed: Array[Particle] = []
	for p: Particle in _particles:
		p.age += delta
		if p.age >= p.delay + p.duration:
			landed.append(p)
	for p: Particle in landed:
		_particles.erase(p)
		if p.kind == Kind.DUST:
			dust_arrived.emit(p.amount)
		else:
			light_arrived.emit(p.amount)
	if not landed.is_empty() and _particles.is_empty():
		all_landed.emit()
	queue_redraw()


## `total` shared between `parts` as evenly as whole numbers allow, largest shares first.
@warning_ignore("integer_division")
static func split(total: int, parts: int) -> Array[int]:
	var shares: Array[int] = []
	for i: int in parts:
		shares.append(total / parts + (1 if i < total % parts else 0))
	return shares


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	if event.type == &"big_bang_started":
		var n0: int = _particles.size()
		_launch(Kind.DUST, event.args[2], [event.args[0]] as Array[Vector2i], dust_target, BIG_BANG_PARTICLES)
		for i: int in range(n0, _particles.size()):
			_particles[i].delay = BigBangSequence.BANG_AT + STAGGER * (i - n0)
		return
	if event.type != &"combo_collected":
		return
	var sources: Array[Vector2i] = []
	for star: Star in event.args[1]:
		sources.append(star.position)
	if sources.is_empty():
		return
	var n: int = _particles.size()
	_launch(Kind.DUST, event.args[2], sources, dust_target)
	_launch(Kind.LIGHT, event.args[3], sources, light_target)
	# Stagger dust and light together, in launch order, from this combo's first particle.
	for i: int in range(n, _particles.size()):
		_particles[i].delay = LAUNCH_DELAY + STAGGER * (i - n)


func _launch(kind: Kind, total: int, sources: Array[Vector2i], target: Vector2i, most: int = MAX_PARTICLES) -> void:
	if total <= 0:
		return
	var shares: Array[int] = split(total, mini(total, most))
	for i: int in shares.size():
		var p := Particle.new()
		p.kind = kind
		p.amount = shares[i]
		p.from = Vector2(sources[i % sources.size()])
		p.to = Vector2(target)
		var middle: Vector2 = p.from.lerp(p.to, 0.5)
		p.bend = middle + (p.to - p.from).orthogonal().normalized() * _rng.randf_range(-MAX_BOW, MAX_BOW)
		p.duration = _rng.randf_range(FLIGHT_MIN, FLIGHT_MAX)
		_particles.append(p)
