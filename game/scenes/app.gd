class_name App
extends Node
## The game's entry (#62): Scorpio's chapter chart first; PLAY opens the selected stage (Main,
## in_chapter, playing that stage's StarMap) and MAP brings the chart back. A stage won counts at
## once (Main.stage_won): the chapter records it and saves it (ProgressStore), and back on the
## chart its stars light and a comet travels to the stage it opened. Owns no rules: Chapter keeps the progress.
## Fills the window like Main (a whole-number scale, the game's screen on the bottom edge).
## The Stinger's first play is the guided first run (Main.tutorial) until it's finished once; that
## is saved with the progress ("tutorial": {"done": true}). After that the chart's TUTORIAL button
## plays it again (replay_tutorial): the Stinger, guided, its win counting as usual.
## Chapters (ChapterDef.all): each keeps its own progress. One opens once the chapter before it is
## won (Aquarius after Scorpio's final). The chart's arrows (or a swipe) slide to the chapter before
## or after, if it's open; a locked one shows a padlock. Winning the final that opens the next
## chapter plays its opening back on the chart (the padlock bursts), then slides on to it and
## reveals it. The chart opens on the latest open chapter. The chart has its own sound (Sfx).
## Debug builds, on the chart: [ and ] go to the chapter before or after, open or not; O plays the
## next chapter's opening.
## Debug builds, on the chart: U previews every part won and plays the final's unlock; F previews
## the final won too and plays its painted Scorpio rising. A preview is a copy of the chapter shown
## on the chart only: it is never saved and never unlocks a stage; opening a stage drops it.

## A stage was opened (tests and feedback).
signal stage_opened(point: int)

const MainScene := preload("res://game/scenes/main.tscn")
## Where the guided first run's state is saved, beside the chapter's.
const TUTORIAL_ID: String = "tutorial"
## Which Orion threats' guided encounters (#93) have been played through, saved with the progress:
## {"mark": true, ...}. Each plays only the first time its stage is played.
const ENCOUNTERS_ID: String = "encounters"

## Where progress is kept. Tests point it at a file of their own.
@export var progress_path: String = ProgressStore.DEFAULT_PATH

## The chapter the chart shows (and stages open from).
var chapter: Chapter
## Every chapter, in campaign order, with its progress.
var chapters: Array[Chapter] = []
## The guided first run was finished once.
var tutorial_done: bool = false
var encounters_met: Dictionary = {}
var _store: ProgressStore
## The stage in play, or null on the chart.
var _stage: Main
var _stage_point: int = -1
## Back from a win: whether it opened the next chapter (its final, won the first time).
var _opens_chapter: bool = false
## The chart's sound.
var _sfx: Sfx
## Back from a win: the point it completed and the one it unlocked (-1 for none).
var _won_point: int = -1
var _unlocked: int = -1
## Debug: the chapter copy the chart previews, or null.
var _preview: Chapter

@onready var _chart: ChapterSelect = $ChapterSelect


func _ready() -> void:
	_store = ProgressStore.new(progress_path)
	for def: ChapterDef in ChapterDef.all():
		var loaded := Chapter.new(def)
		loaded.from_save(_store.load_chapter(def.id))
		chapters.append(loaded)
	chapter = chapters[0]
	for each: Chapter in chapters:
		if is_open(each):
			chapter = each
	tutorial_done = _store.load_chapter(TUTORIAL_ID).get("done", false) == true
	encounters_met = _store.load_chapter(ENCOUNTERS_ID)
	_chart.setup(chapter)
	_chart.stage_chosen.connect(open_stage)
	_chart.tutorial_requested.connect(replay_tutorial)
	_chart.current_trial_requested.connect(open_current_trial.bind(true, 0, "aquarius"))
	_chart.chapter_step_requested.connect(step_chapter)
	_chart.chapter_opened.connect(step_chapter.bind(1, true, true))
	_sfx = Sfx.new()
	_sfx.name = "ChartSfx"
	add_child(_sfx)
	_chart.slid.connect(_sfx.play.bind(&"launch", 1.6))
	_chart.star_landed.connect(_sfx.play.bind(&"star_select", 1.3))
	_chart.nav_refused.connect(_sfx.play.bind(&"tap_refused", 1.0))
	_chart.padlock_shaken.connect(_sfx.play.bind(&"tremble", 1.3))
	_chart.padlock_broke.connect(func() -> void:
		_sfx.play(&"burst", 1.2)
		_sfx.play(&"pack_ready", 1.0))
	_chart.star_revealed.connect(func(order: int) -> void: _sfx.on_string_sung(-1, order))
	_chart.chapter_revealed.connect(_sfx.play.bind(&"sun_ignite", 1.0))
	_show_navigation()
	get_window().size_changed.connect(fit_screen)
	fit_screen()
	set_process_unhandled_key_input(OS.is_debug_build())
	if OS.is_debug_build():
		if "--currents" in OS.get_cmdline_user_args():
			open_current_trial()
		elif "--currents-off" in OS.get_cmdline_user_args():
			open_current_trial(false)
		elif "--aquarius" in OS.get_cmdline_user_args():
			open_current_trial(true, 0, "aquarius")
		elif "--aquarius-off" in OS.get_cmdline_user_args():
			open_current_trial(false, 0, "aquarius")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _stage != null:
		return
	if key.keycode == KEY_C:
		open_current_trial(not key.shift_pressed)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_A:
		open_current_trial(not key.shift_pressed, 0, "aquarius")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_U:
		debug_win_parts()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F:
		debug_win_final()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_BRACKETLEFT or key.keycode == KEY_BRACKETRIGHT:
		step_chapter(-1 if key.keycode == KEY_BRACKETLEFT else 1, false, true)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_O:
		debug_open_next()
		get_viewport().set_input_as_handled()


## Debug: previews every part won, then the chart plays the final's unlock.
func debug_win_parts() -> void:
	_show_preview(Chapter.FINAL)
	_chart.show_progress(Chapter.FINAL - 1, Chapter.FINAL)


## Debug: the chart plays the next chapter's opening (as after its final's win), then slides on to
## it, open or not. Nothing is saved.
func debug_open_next() -> void:
	if chapters.find(chapter) + 1 < chapters.size():
		_chart.show_progress(-1, -1, false)
		_chart.play_opening()


## Debug: previews every stage won, then the chart plays the final's win.
func debug_win_final() -> void:
	_show_preview(Chapter.stage_count())
	_chart.show_progress(Chapter.FINAL, -1)


## Whether `which` can be played: the first chapter, or one whose opening chapter's final is won.
func is_open(which: Chapter) -> bool:
	if which.def.unlocked_by == "":
		return true
	for each: Chapter in chapters:
		if each.id == which.def.unlocked_by:
			return each.is_completed(Chapter.FINAL)
	return false


## The chart voyages to the chapter `step` away (-1 before, +1 after) if there is one and it's open
## (`force`: open or not, for debug); `reveal` pops its stars in, as when it has just opened.
func step_chapter(step: int, reveal: bool = false, force: bool = false) -> void:
	if _stage != null:
		return
	var at: int = chapters.find(chapter) + step
	if at < 0 or at >= chapters.size() or not (force or is_open(chapters[at])):
		return
	_end_preview()
	chapter = chapters[at]
	_chart.voyage_to(chapter, reveal)
	_show_navigation()


## Tests and debug: the chart goes at once to the next chapter (round to the first), if it's open or
## this is a debug build.
func switch_chapter() -> void:
	if _stage != null:
		return
	var other: Chapter = _other_chapter()
	if other == null:
		return
	_end_preview()
	chapter = other
	_chart.setup(chapter)
	_show_navigation()


## The chapter the plaque goes to, or null.
func _other_chapter() -> Chapter:
	var at: int = chapters.find(chapter)
	for step: int in range(1, chapters.size()):
		var candidate: Chapter = chapters[(at + step) % chapters.size()]
		if is_open(candidate) or OS.is_debug_build():
			return candidate
	return null


## The TUTORIAL plaque (Scorpio's guided run) and where the chart's arrows lead.
func _show_navigation() -> void:
	_chart.show_tutorial_button(tutorial_done and chapter == chapters[0])
	var at: int = chapters.find(chapter)
	_chart.show_navigation(_nav_to(at - 1), _nav_to(at + 1))


## Where an arrow to chapter `index` leads: nowhere past the ends, else open or locked.
func _nav_to(index: int) -> ChapterSelect.Nav:
	if index < 0 or index >= chapters.size():
		return ChapterSelect.Nav.NONE
	return ChapterSelect.Nav.OPEN if is_open(chapters[index]) else ChapterSelect.Nav.LOCKED


func is_previewing() -> bool:
	return _preview != null


## The chart shows a copy of the chapter with the first `stages` stages won; the chapter itself
## (what's saved and what opens) is untouched.
func _show_preview(stages: int) -> void:
	_preview = Chapter.new(chapter.def)
	_preview.from_save(chapter.to_save())
	for stage: int in stages:
		_preview.complete(stage)
	_chart.setup(_preview)


func _end_preview() -> void:
	if _preview == null:
		return
	_preview = null
	_chart.setup(chapter)


## The stage in play, or null on the chart.
func stage() -> Main:
	return _stage


## Plays the guided first run again: the Stinger, guided.
func replay_tutorial() -> void:
	open_stage(0, true)


## No progress callbacks: experimental wins never count toward Scorpio. `layout`: "tail" or
## "aquarius" (StarMap.current_layout).
func open_current_trial(enabled: bool = true, seed_value: int = 0, layout: String = "tail") -> void:
	if not OS.is_debug_build() or _stage != null:
		return
	_end_preview()
	_stage_point = -1
	_won_point = -1
	_unlocked = -1
	_stage = MainScene.instantiate()
	_stage.in_chapter = true
	_stage.current_trial = true
	_stage.current_enabled = enabled
	_stage.current_layout = layout
	_stage.seed_override = seed_value
	_stage.map_requested.connect(back_to_chart)
	_show_chart(false)
	add_child(_stage)


## Opens stage `point` (only one that can be played); `guided` plays the guided first run on it (the
## Stinger's first play is guided anyway until it's been finished once).
func open_stage(point: int, guided: bool = false) -> void:
	_end_preview()
	if _stage != null or chapter.state(point) == Chapter.PointState.LOCKED:
		return
	_stage_point = point
	_won_point = -1
	_unlocked = -1
	_stage = MainScene.instantiate()
	_stage.in_chapter = true
	_stage.star_map = chapter.map_id(point)
	# The guided first run is Scorpio's Stinger: the first chapter's first stage.
	_stage.tutorial = chapter == chapters[0] and point == 0 and (guided or not tutorial_done)
	_stage.replay = chapter.is_completed(point)
	_stage.tutorial_finished.connect(_on_tutorial_finished)
	var threat: int = Encounter.threat_of(StarMap.by_id(_stage.star_map))
	_stage.encounter = threat >= 0 and encounters_met.get(Encounter.threat_name(threat), false) != true
	_stage.encounter_finished.connect(_on_encounter_finished)
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
	_chart.show_progress(_won_point, _unlocked, _opens_chapter)
	_won_point = -1
	_unlocked = -1
	_opens_chapter = false
	_show_navigation()


func fit_screen() -> void:
	var window: Window = get_window()
	if window == get_tree().root:
		window.content_scale_size = ScreenZones.fill_size(window.size)
	var visible: Vector2 = get_viewport().get_visible_rect().size
	var offset: Vector2i = ScreenZones.game_offset(visible)
	_chart.fit_screen(Rect2i(-offset, Vector2i(visible)))


func _on_tutorial_finished() -> void:
	tutorial_done = true
	_store.save_chapter(TUTORIAL_ID, {"done": true})
	_chart.show_tutorial_button(true)


func _on_encounter_finished(threat: int) -> void:
	encounters_met[Encounter.threat_name(threat)] = true
	_store.save_chapter(ENCOUNTERS_ID, encounters_met)


func _on_stage_won() -> void:
	var first_time: bool = not chapter.is_completed(_stage_point)
	var next: int = chapters.find(chapter) + 1
	_opens_chapter = first_time and Chapter.is_final(_stage_point) and next < chapters.size() and chapters[next].def.unlocked_by == chapter.id
	var unlocked: int = chapter.complete(_stage_point)
	_store.save_chapter(chapter.id, chapter.to_save())
	_won_point = _stage_point if first_time else -1
	_unlocked = unlocked


func _show_chart(on: bool) -> void:
	_chart.visible = on
	_chart.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
