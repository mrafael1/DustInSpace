class_name Haptics
extends RefCounted
## Touch feedback on phones (#150): short vibrations for the moments a slot machine sells by feel,
## carried through the Sfx layer: each sound cue that has a pattern here also pulses, whatever the
## sound level, so a muted player still feels a refused link or a payout. Not during the Big Bang's
## silence (Sfx refuses cues then). Presentation only; on/off is saved in user://settings.cfg.
## The vibration itself is a Callable (Input.vibrate_handheld by default), so tests can watch it.

const SECTION: String = "haptics"
const KEY: String = "on"
## Per cue, its pattern: pulses of [delay after the cue in seconds, duration in ms, amplitude 0-1].
## A tick for a star picked, a double tap for a valid link, a buzz for a refusal, a thump for a
## burst, a long rumble for the Big Bang, a rising triple for a win and one soft fall for a loss.
const PATTERNS: Dictionary[StringName, Array] = {
	&"star_select": [[0.0, 8, 0.3]],
	&"link_collect": [[0.0, 15, 0.6], [0.08, 15, 0.6]],
	&"link_reject": [[0.0, 35, 0.5]],
	&"tap_refused": [[0.0, 35, 0.5]],
	&"pack_buy": [[0.0, 15, 0.5]],
	&"burst": [[0.0, 40, 0.7]],
	&"drain": [[0.0, 40, 0.6]],
	&"sun_ignite": [[0.0, 80, 0.7]],
	&"big_bang_bang": [[0.0, 350, 1.0]],
	&"win": [[0.0, 30, 0.5], [0.12, 30, 0.7], [0.24, 60, 1.0]],
	&"loss": [[0.0, 120, 0.3]],
}
## Two patterns starting closer than this in time: the second is skipped (a stream of picks or
## bursts never blurs into one long buzz).
const MIN_GAP: float = 0.05

var enabled: bool = true
## Called as vibrate.call(duration_ms, amplitude).
var vibrate: Callable = Input.vibrate_handheld

## Pulses still to come: [at (on the owner's clock), duration ms, amplitude].
var _pending: Array[Array] = []
var _last_start: float = -INF


## Whether this device can vibrate: a phone, or a phone's browser.
static func is_supported() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


## Reads on/off from `path` (on when nothing is saved).
func load_setting(path: String) -> void:
	var config := ConfigFile.new()
	enabled = config.load(path) != OK or config.get_value(SECTION, KEY, true) == true


## Sets on/off and saves it to `path`, keeping the file's other settings.
func set_enabled(on: bool, path: String) -> void:
	enabled = on
	if not on:
		_pending.clear()
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(SECTION, KEY, on)
	config.save(path)


## `cue` sounded (or would have, muted) at `now`: its pattern starts, if it has one. True if so.
func cue(name: StringName, now: float) -> bool:
	if not enabled or not PATTERNS.has(name) or now - _last_start < MIN_GAP:
		return false
	_last_start = now
	for pulse: Array in PATTERNS[name]:
		_pending.append([now + pulse[0], pulse[1], pulse[2]])
	_pending.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	advance(now)
	return true


## Plays the pulses whose time has come by `now`.
func advance(now: float) -> void:
	while not _pending.is_empty() and _pending[0][0] <= now:
		var pulse: Array = _pending.pop_front()
		vibrate.call(pulse[1], pulse[2])


## Drops every pulse still to come (a new run).
func reset() -> void:
	_pending.clear()
	_last_start = -INF
