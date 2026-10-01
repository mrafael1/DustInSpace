class_name App
extends Node
## The game's entry (#62): Scorpio's chapter chart first; PLAY opens the selected stage (Main,
## in_chapter, playing that stage's StarMap) and MAP brings the chart back. A stage won counts at
## once (Main.stage_won): the chapter records it and saves it (ProgressStore), and back on the
## chart its stars light and a comet travels to the stage it opened. Owns no rules: Chapter keeps the progress.
## Fills the window like Main (a whole-number scale, the game's screen on the bottom edge).
## Debug builds, on the chart: U wins every part (not saved) and plays the final's unlock; F wins
## the final too (not saved) and plays its painted Scorpio rising.

## A stage was opened (tests and feedback).
signal stage_opened(point: int)

const MainScene := preload("res://game/scenes/main.tscn")

## Where progress is kept. Tests point it at a file of their own.
@export var progress_path: String = ProgressStore.DEFAULT_PATH

var chapter: Chapter
var _store: ProgressStore
## The stage in play, or null on the chart.
var _stage: Main
var _stage_point: int = -1
## Back from a win: the point it completed and the one it unlocked (-1 for none).
var _won_point: int = -1
var _unlocked: int = -1

@onready var _chart: ChapterSelect = $ChapterSelect


func _ready() -> void:
	_store = ProgressStore.new(progress_path)
	chapter = Chapter.new()
	chapter.from_save(_store.load_chapter(Chapter.ID))
	_chart.setup(chapter)
	_chart.stage_chosen.connect(open_stage)
	get_window().size_changed.connect(fit_screen)
	fit_screen()
	set_process_unhandled_key_input(OS.is_debug_build())


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _stage != null:
		return
	if key.keycode == KEY_U:
		debug_win_parts()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F:
		debug_win_final()
		get_viewport().set_input_as_handled()


## Debug: every part won (not saved), then the chart plays the final's unlock.
func debug_win_parts() -> void:
	for stage: int in Chapter.FINAL:
		chapter.complete(stage)
	_chart.show_progress(Chapter.FINAL - 1, Chapter.FINAL)


## Debug: every stage won (not saved), then the chart plays the final's win.
func debug_win_final() -> void:
	for stage: int in Chapter.stage_count():
		chapter.complete(stage)
	_chart.show_progress(Chapter.FINAL, -1)


## The stage in play, or null on the chart.
func stage() -> Main:
	return _stage


## Opens stage `point` (only one that can be played).
func open_stage(point: int) -> void:
	if _stage != null or chapter.state(point) == Chapter.PointState.LOCKED:
		return
	_stage_point = point
	_won_point = -1
	_unlocked = -1
	_stage = MainScene.instantiate()
	_stage.in_chapter = true
	_stage.star_map = chapter.map_id(point)
	_stage.stage_won.connect(_on_stage_won)
	_stage.map_requested.connect(back_to_chart)
	_show_chart(false)
	add_child(_stage)
	stage_opened.emit(point)


## Leaves the stage for the chart, which shows what a win just lit and unlocked.
func back_to_chart() -> void:
	if _stage == null:
		return
	remove_child(_stage)
	_stage.queue_free()
	_stage = null
	_show_chart(true)
	fit_screen()
	_chart.show_progress(_won_point, _unlocked)
	_won_point = -1
	_unlocked = -1


func fit_screen() -> void:
	var window: Window = get_window()
	if window == get_tree().root:
		window.content_scale_size = ScreenZones.fill_size(window.size)
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2i = ScreenZones.game_offset(visible)
	_chart.fit_screen(Rect2i(-offset, Vector2i(visible)))


func _on_stage_won() -> void:
	var first_time: bool = not chapter.is_completed(_stage_point)
	var unlocked: int = chapter.complete(_stage_point)
	_store.save_chapter(Chapter.ID, chapter.to_save())
	_won_point = _stage_point if first_time else -1
	_unlocked = unlocked


func _show_chart(on: bool) -> void:
	_chart.visible = on
	_chart.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
