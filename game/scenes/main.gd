class_name Main
extends Node2D
## Builds a run (Balance, seeded RNG, RunState) and hands it to every view through
## `setup(run, sequencer)`. Owns no rules. If balance.json is invalid the run doesn't
## start, and debug builds list the errors on screen.

signal run_started(run: RunState)

## Seed for the next run; 0 picks a random one. The seed is printed in debug builds for replays.
@export var seed_override: int = 0
## Where the first run's balance comes from. Tests point it elsewhere.
@export_file("*.json") var balance_path: String = Balance.DEFAULT_PATH

var run: RunState

@onready var _sequencer: EventSequencer = $EventSequencer
@onready var _balance_errors: Label = $DebugLayer/BalanceErrors
@onready var _collect: CollectParticles = $CollectParticles
@onready var _hud: Hud = $HUD
@onready var _sun: SunView = $Sun
@onready var _end_screen: EndScreen = $EndScreen


func _ready() -> void:
	assert(_sequencer.get_index() == get_child_count() - 1, "EventSequencer must be Main's last child to lock input")
	# Payouts travel: the counters tick up as the collect particles land on them.
	_collect.dust_arrived.connect(_hud.receive_dust)
	_collect.light_arrived.connect(_hud.receive_light)
	_collect.light_arrived.connect(_sun.receive_light)
	_end_screen.restart_requested.connect(restart)
	_end_screen.watch_payouts(_collect)
	start_run(Balance.load_file(balance_path))


## Starts a fresh run. If `balance` is invalid it returns false and changes nothing:
## a run already in play keeps going, so views never hold a run Main has dropped.
func start_run(balance: Balance) -> bool:
	if not balance.is_valid():
		_report_balance_errors(balance.errors)
		return false
	_balance_errors.visible = false
	run = RunState.new(balance, _new_rng(), ScreenZones.SKY)
	_sequencer.bind(run)
	for child: Node in get_children():
		if child.has_method("setup"):
			child.setup(run, _sequencer)
	run_started.emit(run)
	return true


## A fresh run on the current run's balance (the end screen's RESTART).
func restart() -> bool:
	return run != null and start_run(run.balance)


func _new_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if seed_override != 0:
		rng.seed = seed_override
	else:
		rng.randomize()
	if OS.is_debug_build():
		print("run seed: %d" % rng.seed)
	return rng


func _report_balance_errors(errors: Array[String]) -> void:
	for error: String in errors:
		push_error("balance.json: " + error)
	if OS.is_debug_build():
		_balance_errors.text = "balance.json is invalid:\n- " + "\n- ".join(errors)
		_balance_errors.visible = true
