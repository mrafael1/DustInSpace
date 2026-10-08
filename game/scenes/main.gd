class_name Main
extends Node2D
## Builds a run (Balance, seeded RNG, RunState) and hands it to every view through
## `setup(run, sequencer)`. Owns no rules. If balance.json is invalid the run doesn't
## start, and debug builds list the errors on screen.

signal run_started(run: RunState)
## In a chapter (#62): the run in play was won. Sent as the core decides it, so the win counts even
## if the player leaves before the end screen.
signal stage_won
## In a chapter: the player asked to go back to the chart (MAP in the pause menu or on the end
## screen).
signal map_requested
## The guided first run reached free play (App saves it, so it plays only once).
signal tutorial_finished
## The stage's Orion encounter (#93) is done: `threat` (an Encounter.Threat) has been met (App saves
## it, so it plays only the first time).
signal encounter_finished(threat: int)

## Seed for the next run; 0 picks a random one. The seed is printed in debug builds for replays.
@export var seed_override: int = 0
## Where the first run's balance comes from. Tests point it elsewhere.
@export_file("*.json") var balance_path: String = Balance.DEFAULT_PATH
## Issue #52's prototype: launch with the telescope (point and tap) instead of the slingshot.
## Debug builds switch with T to compare the two.
@export var use_telescope: bool = true
## Played from a chapter's chart (App sets it before adding Main): offers MAP (pause menu, end
## screen).
@export var in_chapter: bool = false
## The constellation layout to play when balance.json turns the constellation on (a StarMap id:
## a chapter stage's, #62; the full Scorpio by default).
@export var star_map: String = "scorpio"
## This stage was won before (App sets it): its completion holds its painting more briefly.
@export var replay: bool = false
## The guided first run (App sets it for the Stinger's first play): each run starts the tutorial
## until it's finished once.
@export var tutorial: bool = false
## The stage's Orion threat hasn't been met yet (App sets it): each run plays its guided encounter
## (#93) until it's done once.
@export var encounter: bool = false
## Debug-only Aquarius experiment, using Tail geometry with every Orion rule disabled.
@export var current_trial: bool = false
@export var current_enabled: bool = true
## Which trial map: "tail" or "aquarius" (StarMap.current_layout).
@export var current_layout: String = "tail"

var run: RunState
## Rows the screen shows above the game's 180x320 (fit_screen): the Sun rises by this much and
## the next run's play sky grows by it.
var _extra: int = 0

@onready var _sequencer: EventSequencer = $EventSequencer
@onready var _balance_errors: Label = $DebugLayer/BalanceErrors
@onready var _collect: CollectParticles = $CollectParticles
@onready var _hud: Hud = $HUD
@onready var _sun: SunView = $Sun
@onready var _end_screen: EndScreen = $EndScreen
@onready var _sfx: Sfx = $Sfx
@onready var _launcher: Launcher = $Launcher
@onready var _telescope: Telescope = $Telescope
@onready var _sky: SkyView = $Sky
@onready var _big_bang: BigBangSequence = $BigBang
@onready var _sound_toggle: SoundToggle = $SoundToggle
@onready var _backdrop: Backdrop = $Backdrop
@onready var _sparks: BurstSparks = $BurstSparks
@onready var _payouts: PayoutPopups = $Payouts
@onready var _idle_hint: IdleHint = $IdleHint
@onready var _playtest_log: PlaytestLog = $PlaytestLog

## The world's process modes while the table (#94) holds it still.
var _paused: Dictionary[Node, Node.ProcessMode] = {}


func _ready() -> void:
	set_process(false)
	# _input runs from the last child up: the idle hint watches every touch first (it takes none),
	# then the speaker, then the sequencer's input lock.
	assert(_idle_hint.get_index() == get_child_count() - 1, "IdleHint must be Main's last child")
	assert(_sound_toggle.get_index() == get_child_count() - 2, "SoundToggle must come right before it")
	assert(_sequencer.get_index() == get_child_count() - 3, "EventSequencer must come right before that to lock input")
	# Payouts travel: the counters tick up as the collect particles land on them.
	_collect.dust_arrived.connect(_hud.receive_dust)
	# A link's dust floats up from it until it lands on the counter (#59).
	_collect.dust_payout_launched.connect(_payouts.show_payout)
	_collect.dust_payout_landed.connect(_payouts.release)
	_collect.light_arrived.connect(_sun.receive_light)
	_sun.released.connect(func() -> void: _sky.launch_sunbeam(Vector2i(_sun.position)))
	_sky.watch_payouts(_collect)
	_end_screen.restart_requested.connect(restart)
	_end_screen.map_enabled = in_chapter
	_end_screen.map_requested.connect(map_requested.emit)
	_hud.offer_map(in_chapter)
	_hud.map_requested.connect(map_requested.emit)
	_hud.restart_requested.connect(restart)
	_hud.pause_opened.connect(_pause_world.bind(true))
	_hud.pause_closed.connect(_pause_world.bind(false))
	_end_screen.watch_payouts(_collect)
	_hud.planet_chosen.connect(func(_kind: String) -> void: _telescope.request_aim())
	_sky.link_traced.connect(_hud.follow_link)
	# A refused pick: the line says why (#91), instead of the shake and buzz of a wrong link.
	_sky.link_refused.connect(_hud.explain_refusal)
	# The idle hint (#90) shows a link in the sky. It holds still while payouts fly or the Sun
	# ignites, and while the tutorial's own hand is out (one hand at a time).
	_idle_hint.sky = _sky
	_idle_hint.is_held = func() -> bool:
		return _collect.particle_count() > 0 or _sun.is_igniting() or _hud.tutorial_guide().has_hand()
	# The hand shows a link, so the sky must take links: an aiming telescope (which takes every sky
	# touch) stops aiming, as if tapped; and a telescope that starts aiming ends the hint.
	_idle_hint.hint_started.connect(func(_link: Array[int]) -> void:
		if use_telescope and _telescope.is_aiming():
			_telescope.cancel_aim())
	_telescope.aim_started.connect(_idle_hint.reset)
	_hud.loaded_window_at = func() -> Vector2i:
		return _telescope.origin() + _telescope.window() if use_telescope else _launcher.origin()
	_telescope.message_shown.connect(_hud.show_message)
	_hud.table_opened.connect(_pause_world.bind(true))
	_hud.table_closed.connect(_pause_world.bind(false))
	($DebugKeys as DebugKeys).launcher_switch_requested.connect(func() -> void: switch_launcher(not use_telescope))
	($DebugKeys as DebugKeys).current_switch_requested.connect(switch_current)
	($CurrentTrialControls as CurrentTrialControls).current_switch_requested.connect(switch_current)
	_wire_playtest_log()
	switch_launcher(use_telescope)
	_wire_sound()
	get_window().size_changed.connect(fit_screen)
	fit_screen()
	start_run(Balance.load_file(balance_path))


## Starts a fresh run. If `balance` is invalid it returns false and changes nothing:
## a run already in play keeps going, so views never hold a run Main has dropped.
func start_run(balance: Balance) -> bool:
	if not balance.is_valid():
		_report_balance_errors(balance.errors)
		return false
	_balance_errors.visible = false
	var map: StarMap = StarMap.current_layout(current_layout, current_enabled) if current_trial and OS.is_debug_build() else StarMap.by_id(star_map)
	run = RunState.new(balance, _new_rng(), ScreenZones.play_sky(_extra), map)
	set_process(run.current != null or run.heat != null or run.harvest != null)
	($Sky/ConstellationLayer as ConstellationView).current_aiming = false
	($Sky/ConstellationLayer as ConstellationView).repeat = replay
	($Sky/CurrentLayer as CurrentView).setup(run, _sequencer)
	($Sky/HeatLayer as HeatView).setup(run, _sequencer)
	($Sky/HarvestLayer as HarvestView).setup(run, _sequencer)
	run.run_won.connect(stage_won.emit)
	_sequencer.bind(run)
	_playtest_log.guided = tutorial
	for child: Node in get_children():
		if child.has_method("setup"):
			child.setup(run, _sequencer)
	# The guided first run, once every view is bound to show its first step.
	if tutorial:
		run.tutorial_step.connect(_on_tutorial_step)
		run.start_tutorial()
	# The boss stage opens with Orion's entrance, once every view is bound.
	run.play_boss_intro()
	# A volley stage opens by showing its volley (#70), once every view is bound.
	run.play_volley_intro()
	# So does a hunting stage (#71): the whole cycle once, with a demo launch.
	run.play_hunt_intro()
	# And a stage bringing Leo's heat or cold: the effect shown once on a few stars.
	run.play_heat_intro()
	# And a stage bringing Virgo's scythe or its binding: shown once as it opens.
	run.play_harvest_intro()
	# The threat's guided encounter, once its intro has shown it (#93).
	if encounter:
		run.encounter_step.connect(_on_encounter_step)
		run.start_encounter()
	# A current's rule is said as the player first aims; a launcher already aiming (it can start
	# before the HUD is bound, and keeps aiming through a restart) says it now.
	if _telescope.is_aiming() if use_telescope else _launcher.is_pulling():
		_hud.tell_current_rule()
	run_started.emit(run)
	return true


func _process(_delta: float) -> void:
	var aiming: bool = run != null and not _sequencer.is_busy() and (
		_telescope.is_aiming() if use_telescope else _launcher.is_pulling())
	($Sky/CurrentLayer as CurrentView).aiming = aiming and run.current != null
	($Sky/HeatLayer as HeatView).aiming = aiming and run.heat != null
	($Sky/HarvestLayer as HarvestView).aiming = aiming and run.harvest != null
	($Sky/ConstellationLayer as ConstellationView).current_aiming = aiming and (run.current != null or run.heat != null)


## C restarts the trial with the same seed and the other setting.
func switch_current() -> void:
	if not OS.is_debug_build() or not current_trial or _sequencer.is_busy() or not _paused.is_empty():
		return
	seed_override = run.run_seed
	current_enabled = not current_enabled
	restart()


## Fills the window and places the game's 180x320 screen in it (a phone that isn't 9:16 shows
## more; see ScreenZones): the camera moves the world, the UI layers follow it, and the Backdrop
## fills the rest.
func fit_screen() -> void:
	# Fill the window at a whole-number scale (Godot's own "expand" leaves bars on phones).
	var window: Window = get_window()
	if window == get_tree().root:
		window.content_scale_size = ScreenZones.fill_size(window.size)
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2i = ScreenZones.game_offset(visible)
	($BigBang/Shake as Camera2D).position = Vector2(-offset)
	for layer: CanvasLayer in [$HUD, $Payouts, $EndScreen, $DebugLayer, $BigBang/Front, $CurrentTrialControls] as Array[CanvasLayer]:
		layer.offset = Vector2(offset)
	_sound_toggle.screen_offset = offset
	_backdrop.fit(offset, Vector2i(visible))
	# The UI anchors to the real screen's edges, not the game's 180x320 (the Sun's counter aside).
	var screen := Rect2i(-offset, Vector2i(visible))
	($CurrentTrialControls as CurrentTrialControls).fit_screen(screen)
	_hud.fit_screen(screen)
	_payouts.fit_screen(screen)
	_sound_toggle.target = _hud.sound_target()
	_end_screen.fit_screen(screen)
	_sun.fit_screen(screen)
	# The Sun rises to the top of the screen; its light follows it. A run already in play keeps its
	# sky: the next one (RESTART) takes the new size.
	_extra = offset.y
	_sun.position = Vector2(ScreenZones.sun_centre(_extra))
	_hud.sun_at = ScreenZones.sun_centre(_extra)
	_collect.light_target = ScreenZones.sun_centre(_extra)


## Shows the telescope (true) or the slingshot and hands it the input; the other one hides and
## takes none. Both keep following the run's events, so either can take over at any time.
func switch_launcher(telescope: bool) -> void:
	use_telescope = telescope
	for launcher: Launcher in [_launcher, _telescope] as Array[Launcher]:
		var on: bool = (launcher == _telescope) == telescope
		launcher.cancel_pull()
		launcher.visible = on
		var mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		# Under the table the world is held: the switch is kept for when it lets go.
		if _paused.has(launcher):
			_paused[launcher] = mode
		else:
			launcher.process_mode = mode
	_hud.show_message("")
	if telescope:
		_telescope.request_aim()


## The launcher in use: the telescope or the slingshot.
func launcher() -> Launcher:
	return _telescope if use_telescope else _launcher


## A fresh run on the current run's balance (the end screen's or the pause menu's RESTART).
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
	_telescope.tremble_started.connect(_sfx.play.bind(&"tremble", 1.0))
	_telescope.aim_started.connect(_sfx.play.bind(&"pull_start", 1.0))
	# A current's rule is said as the player first aims, before the first launch is committed.
	_telescope.aim_started.connect(_hud.tell_current_rule)
	_launcher.pull_started.connect(_hud.tell_current_rule)
	_telescope.aim_cancelled.connect(_sfx.play.bind(&"pull_cancel", 1.0))
	_telescope.empty_tapped.connect(_sfx.play.bind(&"tap_refused", 1.0))
	_telescope.launch_refused.connect(_sfx.play.bind(&"tap_refused", 1.0))
	_telescope.planet_seated.connect(func(_kind: String) -> void: _sfx.play(&"pack_load", 1.5))
	_sky.star_selected.connect(_sfx.on_star_selected)
	_sky.step_refused.connect(_sfx.play.bind(&"link_reject", 1.0))
	_sky.link_cancelled.connect(_sfx.play.bind(&"pull_cancel", 1.0))
	_sky.star_exploded.connect(_on_star_exploded)
	# A drained star is the player's loss: sucked down the drain, a thump and a falling gulp.
	_sky.star_drained.connect(func(_at: Vector2i) -> void: _sfx.play(&"drain"))
	# A burnt star is lost too: it bursts low.
	_sky.star_burned.connect(func(at: Vector2i) -> void:
		_sparks.explode_at(at)
		_sfx.play(&"burst", 0.7))
	# A faded star goes quietly: frost falls, and the burst sounds high and brittle.
	# A constellation star burning back to small: its embers burst, a fuller burst than a loss.
	_sky.landmark_rekindled.connect(func(_at: Vector2i) -> void: _sfx.play(&"burst", 1.0))
	# Leo's final arriving: each star catching fire chimes a step higher, then the lion roars low.
	var constellation := _sky.get_node("ConstellationLayer") as ConstellationView
	constellation.blaze_lit.connect(func(order: int) -> void: _sfx.play(&"star_select", 0.8 + 0.06 * order))
	constellation.roared.connect(_sfx.play.bind(&"big_bang_collapse", 0.8))
	_sky.star_faded.connect(func(_at: Vector2i) -> void: _sfx.play(&"burst", 1.5))
	# Virgo's scythe swishes across the sky; a constellation star put out sinks with a low buzz.
	_sky.harvest_swept.connect(_sfx.play.bind(&"launch", 0.7))
	_sky.landmark_put_out.connect(func(_at: Vector2i) -> void: _sfx.play(&"link_reject", 0.7))
	_sky.sunbeam_launched.connect(_sfx.play.bind(&"launch", 1.5))
	_sky.sunbeam_landed.connect(_on_star_exploded)
	(_sky.get_node("ConstellationLayer") as ConstellationView).string_sung.connect(_sfx.on_string_sung)
	var orion := _sky.get_node("OrionLayer") as OrionView
	orion.arrow_loosed.connect(_sfx.play.bind(&"launch", 2.0))
	# The boss: a rumble as his stars light, a low roar, a low buzz each time he's hurt.
	orion.entered.connect(_sfx.play.bind(&"tremble", 0.6))
	orion.roared.connect(_sfx.play.bind(&"big_bang_collapse", 1.5))
	orion.hurt_taken.connect(_sfx.play.bind(&"link_reject", 0.6))
	_hud.tap_refused.connect(func(_kind: String, _part: StringName) -> void: _sfx.play(&"tap_refused"))
	_hud.pack_ready.connect(func(_kind: String) -> void: _sfx.play(&"pack_ready"))
	_sound_toggle.toggled.connect(_sfx.cycle_level)
	_hud.sound_cycle_requested.connect(_sfx.cycle_level)
	_hud.restart_requested.connect(_sfx.play.bind(&"restart", 1.0))
	_sfx.level_changed.connect(_hud.show_sound_level)
	_hud.show_sound_level(_sfx.level)
	_big_bang.collapse_started.connect(_sfx.play.bind(&"big_bang_collapse", 1.0))
	_big_bang.silence_started.connect(_sfx.duck)
	_big_bang.banged.connect(_sfx.on_big_bang_banged)
	_sun.ignited.connect(_sfx.play.bind(&"sun_ignite", 1.0))
	_end_screen.shown.connect(_sfx.on_end_shown)
	_end_screen.restart_requested.connect(_sfx.play.bind(&"restart", 1.0))


## The playtest log (#89, debug builds) hears the touches first (through the idle hint) and every
## refused action the views feed back.
func _wire_playtest_log() -> void:
	_idle_hint.touch_started.connect(_playtest_log.touched)
	_idle_hint.touch_ended.connect(_playtest_log.released)
	_idle_hint.dragged.connect(_playtest_log.dragged)
	_hud.tap_refused.connect(_playtest_log.pack_tap_refused)
	# Whatever these signals carry, only the kind of refusal is logged.
	_telescope.empty_tapped.connect(func(..._args: Array) -> void: _playtest_log.refused("launch"))
	_telescope.launch_refused.connect(func(..._args: Array) -> void: _playtest_log.refused("launch"))
	_sky.link_refused.connect(func(..._args: Array) -> void: _playtest_log.refused("link"))
	_sky.step_refused.connect(func(..._args: Array) -> void: _playtest_log.refused("link"))


func _on_encounter_step(threat: int, step: int) -> void:
	if step == Encounter.Step.DONE:
		encounter = false
		encounter_finished.emit(threat)


func _on_tutorial_step(step: int) -> void:
	if step == Tutorial.Step.DONE:
		tutorial = false
		tutorial_finished.emit()


## Scorpio clears the sky (and a sunbeam lands): each star blows up with a ring, big sparks and
## the burst sound.
func _on_star_exploded(at: Vector2i) -> void:
	_sparks.explode_at(at)
	_sfx.play(&"burst")


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


## The table or the pause menu holds the world still (`on`): everything but the HUD, the speaker and the debug
## tools stops processing and taking input, and starts again as it was.
func _pause_world(on: bool) -> void:
	if on:
		for child: Node in get_children():
			if child in [_hud, _sound_toggle, $DebugKeys, $DebugLayer] or _paused.has(child):
				continue
			_paused[child] = child.process_mode
			child.process_mode = Node.PROCESS_MODE_DISABLED
		return
	for child: Node in _paused:
		if is_instance_valid(child):
			child.process_mode = _paused[child]
	_paused.clear()
