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
@onready var _sfx: Sfx = $Sfx
@onready var _launcher: Launcher = $Launcher
@onready var _sky: SkyView = $Sky
@onready var _big_bang: BigBangSequence = $BigBang
@onready var _sound_toggle: SoundToggle = $SoundToggle
@onready var _backdrop: Backdrop = $Backdrop


func _ready() -> void:
	# _input runs from the last child up: the speaker first, then the sequencer's input lock.
	assert(_sound_toggle.get_index() == get_child_count() - 1, "SoundToggle must be Main's last child")
	assert(_sequencer.get_index() == get_child_count() - 2, "EventSequencer must come right before it to lock input")
	# Payouts travel: the counters tick up as the collect particles land on them.
	_collect.dust_arrived.connect(_hud.receive_dust)
	_collect.light_arrived.connect(_hud.receive_light)
	_collect.light_arrived.connect(_sun.receive_light)
	# Scorpio: a rekindled Sun resets the light counter and then pays its dust.
	_sun.rekindled.connect(_hud.reset_light)
	_sun.rekindled.connect(_collect.release_rekindle)
	_sun.rekindled.connect(_sky.shine_rekindled)
	_sky.watch_payouts(_collect)
	_end_screen.restart_requested.connect(restart)
	_end_screen.watch_payouts(_collect)
	_wire_sound()
	get_viewport().size_changed.connect(fit_screen)
	fit_screen()
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


## Centres the game's 180x320 screen in whatever the window shows (a phone that isn't 9:16
## shows more; see ScreenZones.SCREEN): the camera moves the world, the UI layers follow it,
## and the Backdrop fills the margins.
func fit_screen() -> void:
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2i = ScreenZones.game_offset(visible)
	($BigBang/Shake as Camera2D).position = Vector2(-offset)
	for layer: CanvasLayer in [$HUD, $EndScreen, $DebugLayer, $BigBang/Front] as Array[CanvasLayer]:
		layer.offset = Vector2(offset)
	_sound_toggle.screen_offset = offset
	_backdrop.fit(offset, Vector2i(visible))


## A fresh run on the current run's balance (the end screen's RESTART).
func restart() -> bool:
	return run != null and start_run(run.balance)


## Sound follows the views' feedback moments; the run's events reach Sfx through setup().
## After restart's own connection, so the restart cue plays into the new run's silence.
func _wire_sound() -> void:
	_collect.dust_arrived.connect(_sfx.on_dust_arrived)
	_collect.light_arrived.connect(_sfx.on_light_arrived)
	_launcher.pull_started.connect(_sfx.play.bind(&"pull_start", 1.0))
	_launcher.pull_stepped.connect(_sfx.on_pull_stepped)
	_launcher.pull_cancelled.connect(_sfx.play.bind(&"pull_cancel", 1.0))
	_launcher.tremble_started.connect(_sfx.play.bind(&"tremble", 1.0))
	_sky.star_selected.connect(_sfx.on_star_selected)
	_sky.star_shone.connect(_sfx.on_star_shone)
	_sky.link_refused.connect(_sfx.play.bind(&"link_reject", 1.0))
	_sky.step_refused.connect(_sfx.play.bind(&"link_reject", 1.0))
	(_sky.get_node("ConstellationLayer") as ConstellationView).string_sung.connect(_sfx.on_string_sung)
	_hud.tap_refused.connect(func(_kind: String) -> void: _sfx.play(&"tap_refused"))
	_hud.pack_ready.connect(func(_kind: String) -> void: _sfx.play(&"pack_ready"))
	_sound_toggle.toggled.connect(_sfx.cycle_level)
	_sfx.level_changed.connect(_hud.show_sound_level)
	_hud.show_sound_level(_sfx.level)
	_big_bang.collapse_started.connect(_sfx.play.bind(&"big_bang_collapse", 1.0))
	_big_bang.silence_started.connect(_sfx.duck)
	_big_bang.banged.connect(_sfx.on_big_bang_banged)
	_sun.ignited.connect(_sfx.play.bind(&"sun_ignite", 1.0))
	_end_screen.shown.connect(_sfx.on_end_shown)
	_end_screen.restart_requested.connect(_sfx.play.bind(&"restart", 1.0))


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
