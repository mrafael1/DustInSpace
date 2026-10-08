class_name ProgressStore
extends RefCounted
## Keeps chapter progress on the device (#62) as a small JSON file: {"scorpio": {...}}. Pure file
## access, no scene tree; tests point it at a file of their own. A missing or broken file reads
## as no progress, and loading never crashes.

const DEFAULT_PATH: String = "user://progress.json"

var path: String = DEFAULT_PATH


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## The chapter's saved progress, or {} for none.
func load_chapter(id: String) -> Dictionary:
	var all: Dictionary = _read()
	var data: Variant = all.get(id, {})
	return data if data is Dictionary else {}


## Saves one chapter's progress, keeping the others. Returns false if the file couldn't be written.
func save_chapter(id: String, data: Dictionary) -> bool:
	var all: Dictionary = _read()
	all[id] = data
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("progress not saved: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(all))
	return true


## Forgets every chapter's progress (the options' RESET PROGRESS). Returns false if the file is
## still there.
func clear() -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
