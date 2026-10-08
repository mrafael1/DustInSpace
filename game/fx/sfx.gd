class_name Sfx
extends Node
## Sound effects (assets/audio, built by tools/audio/build_sfx.py). Presentation only: it plays
## what the sequencer plays and what the views signal (Main wires those), never touches the run,
## the sequencer's holds or input, and has its own RNG for pitch jitter.
## Payouts sound as their particles land, not when the core grants them. A dust payout climbs a
## semitone per landing, like a slot machine's count-up, and restarts after a pause.
## Voice limits keep many particles from stacking: each cue has a most-at-once and a least gap
## between starts; a cue over its limit is skipped, and a full pool steals its oldest voice.
## The Big Bang's silence ducks everything: voices are cut and new cues refused until the bang.
## The player's level (on, low, mute) lives on the SFX bus and is saved in user://settings.cfg.
## setup() (every new run, restart included) cuts every voice and lifts any duck.

signal cue_played(cue: StringName, pitch: float)
signal level_changed(level: Level)

enum Level { ON, LOW, MUTE }

const BUS: StringName = &"SFX"
const LEVEL_DB: Array[float] = [0.0, -12.0, -80.0]
const SETTINGS_PATH: String = "user://settings.cfg"
const AUDIO_DIR: String = "res://assets/audio/"
const CUES: Array[StringName] = [
	&"pack_load", &"pack_buy", &"tap_refused", &"pull_start", &"pull_step", &"pull_cancel",
	&"launch", &"tremble", &"burst", &"star_select", &"link_collect", &"link_reject",
	&"dust_land", &"light_land", &"big_bang_collapse", &"big_bang_bang", &"sun_ignite",
	&"win", &"loss", &"restart", &"pack_ready", &"drain", &"crop",
]
const VOICES: int = 12
## Per cue: x = most voices at once, y = least seconds between two starts.
const DEFAULT_LIMIT := Vector2(2, 0.03)
const LIMITS: Dictionary[StringName, Vector2] = {
	&"dust_land": Vector2(3, 0.035),
	&"light_land": Vector2(2, 0.06),
	&"pull_step": Vector2(1, 0.0),
	&"big_bang_bang": Vector2(1, 0.0),
}
const SEMITONE: float = 1.0594631
## The dust count-up: a semitone per landing, at most DUST_CLIMB_MAX, reset after DUST_CLIMB_RESET.
const DUST_CLIMB_MAX: int = 12
const DUST_CLIMB_RESET: float = 0.4
## Random pitch spread on the particle cues, so a stream never sounds like one sample.
const JITTER: float = 0.03
## Scorpio's completion tune: a major pentatonic, one note per string.
const PENTATONIC: Array[float] = [1.0, 1.125, 1.25, 1.5, 1.6667]
## A link's stars ring up a major triad: root, third, fifth.
const SELECT_PITCH: Array[float] = [1.0, 1.26, 1.5]
## Lifts a duck nothing else lifted (the bang is 0.5 s after the silence starts).
const DUCK_SAFETY: float = 2.0

var level: Level = Level.ON
## Tests point this elsewhere before the node enters the tree.
var settings_path: String = SETTINGS_PATH

var _sequencer: EventSequencer
var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
## Per player: the cue it plays, when it started and when it ends, on this node's clock.
var _voice_cue: Array[StringName] = []
var _voice_start: Array[float] = []
var _voice_end: Array[float] = []
var _last_start: Dictionary[StringName, float] = {}
var _clock: float = 0.0
var _duck_left: float = 0.0
var _dust_climb: int = 0
var _last_dust: float = -INF
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_ensure_bus()
	for cue: StringName in CUES:
		_streams[cue] = load(AUDIO_DIR + cue + ".wav")
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		# Use Godot's mixer on Web; native Sample routing can silently drop custom buses.
		if OS.has_feature("web"):
			player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.bus = BUS
		add_child(player)
		_players.append(player)
		_voice_cue.append(&"")
		_voice_start.append(-INF)
		_voice_end.append(-INF)
	_load_level()


func _process(delta: float) -> void:
	advance(delta)


func setup(_run: RunState, sequencer: EventSequencer) -> void:
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	reset()


## Cuts every voice and lifts any duck: a new run starts in silence.
func reset() -> void:
	_cut_all()
	_duck_left = 0.0
	_dust_climb = 0
	_last_dust = -INF
	_last_start.clear()


## Plays `cue` at `pitch` unless muted, ducked or over its voice limit. True if it played.
func play(cue: StringName, pitch: float = 1.0) -> bool:
	if level == Level.MUTE or is_ducked() or not _streams.has(cue):
		return false
	var limit: Vector2 = LIMITS.get(cue, DEFAULT_LIMIT)
	if _clock - _last_start.get(cue, -INF) < limit.y or voices_of(cue) >= int(limit.x):
		return false
	var i: int = _free_voice()
	var player: AudioStreamPlayer = _players[i]
	player.stream = _streams[cue]
	player.pitch_scale = pitch
	player.play()
	_voice_cue[i] = cue
	_voice_start[i] = _clock
	_voice_end[i] = _clock + _streams[cue].get_length() / pitch
	_last_start[cue] = _clock
	cue_played.emit(cue, pitch)
	return true


## Voices of `cue` still sounding.
func voices_of(cue: StringName) -> int:
	var count: int = 0
	for i: int in _players.size():
		if _voice_cue[i] == cue and _voice_end[i] > _clock:
			count += 1
	return count


func voices() -> int:
	var count: int = 0
	for i: int in _players.size():
		if _voice_end[i] > _clock:
			count += 1
	return count


## The Big Bang's silence: cut everything and refuse new cues until unduck() (or DUCK_SAFETY).
func duck() -> void:
	_cut_all()
	_duck_left = DUCK_SAFETY


func unduck() -> void:
	_duck_left = 0.0


func is_ducked() -> bool:
	return _duck_left > 0.0


## The speaker icon's tap: on, low, mute, on.
func cycle_level() -> void:
	set_level(((level + 1) % Level.size()) as Level)


func set_level(value: Level) -> void:
	level = value
	_apply_level()
	if level == Level.MUTE:
		_cut_all()
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("audio", "sfx_level", int(level))
	config.save(settings_path)
	level_changed.emit(level)


## Reads the saved level again (another Sfx, the stage's, may have changed it).
func reload_level() -> void:
	_load_level()
	level_changed.emit(level)


## Moves the clock, the duck and the voices on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	_clock += delta
	if _duck_left > 0.0:
		_duck_left = maxf(_duck_left - delta, 0.0)


# --- cues from the views, wired by Main ---

func on_dust_arrived(_amount: int) -> void:
	if _clock - _last_dust > DUST_CLIMB_RESET:
		_dust_climb = 0
	_last_dust = _clock
	if play(&"dust_land", pow(SEMITONE, _dust_climb) * _jitter()):
		_dust_climb = mini(_dust_climb + 1, DUST_CLIMB_MAX)


func on_light_arrived(_amount: int) -> void:
	play(&"light_land", _jitter())


## `count` stars now in the link being traced.
func on_star_selected(count: int) -> void:
	play(&"star_select", SELECT_PITCH[clampi(count - 1, 0, SELECT_PITCH.size() - 1)])


## The slingshot's pull reached gem `frame` (1 to Launcher.PULL_FRAMES - 1): each one creaks higher.
func on_pull_stepped(frame: int) -> void:
	play(&"pull_step", pow(SEMITONE, 3 * (frame - 1)))


func on_big_bang_banged() -> void:
	unduck()
	play(&"big_bang_bang")


## Scorpio's completion: string `order` (0 = the lowest) sounds the next note up a major
## pentatonic, so the constellation plays a rising tune as it lights.
func on_string_sung(_segment: int, order: int) -> void:
	play(&"light_land", PENTATONIC[order % PENTATONIC.size()] * (2.0 if order >= PENTATONIC.size() else 1.0))


func on_end_shown(won: bool) -> void:
	play(&"win" if won else &"loss")


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_bought":
			play(&"pack_buy")
		&"pack_loaded":
			if event.args[0] != "":
				play(&"pack_load")
		&"pack_launched":
			play(&"launch")
		&"pack_split":
			# The red pack's twin burst: a quick, higher whoosh as it splits.
			play(&"launch", 1.8)
		&"pack_burst", &"big_bang_started", &"hunt_intro_burst":
			# A Big Bang opens exactly like a normal burst, to keep the surprise.
			play(&"burst")
		&"hunt_intro_launched":
			play(&"launch")
		&"heat_breathed":
			# The lion breathes: a low whoosh as the heatwave rolls out, and the heat's chime.
			play(&"launch", 0.6)
			play(&"star_select", 1.25)
		&"stars_resized", &"landmarks_resized":
			# The heat changes stars where they stand: a bright chime, a lower one as the cold
			# shrinks them (a burn or a fade sounds on its own).
			var changes: Array[StarHeat.Change] = event.args[0]
			play(&"star_select", 0.85 if changes[0].is_cold() else 1.25)
		&"combo_collected":
			play(&"link_collect")
		&"link_rejected":
			play(&"link_reject")
		&"landmark_lit":
			play(&"star_select", 1.5)
		&"string_built":
			play(&"pack_ready")
		&"star_marked", &"area_marked":
			play(&"link_reject", 0.6)



func _jitter() -> float:
	return 1.0 + _rng.randf_range(-JITTER, JITTER)


## A voice that has finished, or else the oldest one.
func _free_voice() -> int:
	var oldest: int = 0
	for i: int in _players.size():
		if _voice_end[i] <= _clock:
			return i
		if _voice_start[i] < _voice_start[oldest]:
			oldest = i
	return oldest


func _cut_all() -> void:
	for i: int in _players.size():
		_players[i].stop()
		_voice_cue[i] = &""
		_voice_end[i] = -INF


func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	# An explicit append position avoids Godot's Web Sample add_bus(-1) routing bug.
	AudioServer.add_bus(AudioServer.bus_count)
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, &"Master")


func _load_level() -> void:
	var config := ConfigFile.new()
	var saved: int = Level.ON
	if config.load(settings_path) == OK:
		saved = config.get_value("audio", "sfx_level", Level.ON)
	level = clampi(saved, 0, Level.size() - 1) as Level
	_apply_level()


func _apply_level() -> void:
	_ensure_bus()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), LEVEL_DB[level])
