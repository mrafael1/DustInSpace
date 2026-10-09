class_name Motion
extends RefCounted
## The player's reduced-motion option (game-feel principle 7), saved in user://settings.cfg beside
## the sound level. Reduced: nothing shakes or wiggles (every shake goes through shake / shake_x,
## and keeps its colour cue), the Big Bang leaves out its full-screen flash (its core stays), and
## the stage's sequences play at SEQUENCE_SPEED, half their length (Main).

const SECTION: String = "motion"
const KEY: String = "reduced"
## How much faster a stage's sequences play with reduced motion.
const SEQUENCE_SPEED: float = 2.0

static var reduced: bool = false


## Reads the saved option from `path` (off when nothing is saved).
static func load_setting(path: String) -> void:
	var config := ConfigFile.new()
	reduced = config.load(path) == OK and config.get_value(SECTION, KEY, false) == true


## Sets the option and saves it to `path`, keeping the file's other settings.
static func set_reduced(on: bool, path: String) -> void:
	reduced = on
	var config := ConfigFile.new()
	config.load(path)
	config.set_value(SECTION, KEY, on)
	config.save(path)


## A shake's whole-pixel offset, or none with reduced motion.
static func shake(offset: Vector2i) -> Vector2i:
	return Vector2i.ZERO if reduced else offset


## A sideways shake's whole pixels, or none with reduced motion.
static func shake_x(pixels: int) -> int:
	return 0 if reduced else pixels
