extends GutTest
## Sound effects: which moments sound, voice limits, the dust count-up, the Big Bang's silence,
## the player's level, and nothing left over after a restart.

const Fixtures := preload("res://tests/fixtures.gd")
const MainScene := preload("res://game/scenes/main.tscn")
const SETTINGS := "user://test_sfx_settings.cfg"

var run: RunState
var sequencer: EventSequencer
var sfx: Sfx
var played: Array[StringName] = []
var pitches: Array[float] = []


func before_each() -> void:
	DirAccess.remove_absolute(SETTINGS)
	run = Fixtures.run()
	sequencer = EventSequencer.new()
	add_child_autofree(sequencer)
	sequencer.set_process(false)
	sequencer.bind(run)
	sfx = _new_sfx()
	sfx.setup(run, sequencer)
	played = []
	pitches = []
	sfx.cue_played.connect(_record)


func after_all() -> void:
	DirAccess.remove_absolute(SETTINGS)


func test_every_cue_has_a_short_clean_sound() -> void:
	for cue: StringName in Sfx.CUES:
		var stream: AudioStreamWAV = load(Sfx.AUDIO_DIR + cue + ".wav")
		assert_not_null(stream, "%s.wav" % cue)
		assert_gt(stream.get_length(), 0.0)
		assert_lt(stream.get_length(), 2.1, "%s: no long or looping sounds" % cue)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s never loops" % cue)
	for cue: StringName in [&"dust_land", &"light_land", &"star_select", &"pull_step", &"pack_load", &"pack_ready"]:
		var stream: AudioStream = load(Sfx.AUDIO_DIR + cue + ".wav")
		assert_lt(stream.get_length(), 0.35, "%s is heard many times a run: short" % cue)


## Reads the source WAVs (16-bit PCM from tools/audio/build_sfx.py): the import may compress them.
func test_no_sound_file_clips() -> void:
	for cue: StringName in Sfx.CUES:
		var data: PackedByteArray = FileAccess.get_file_as_bytes(Sfx.AUDIO_DIR + cue + ".wav")
		assert_eq(data.slice(0, 4).get_string_from_ascii(), "RIFF", "%s.wav" % cue)
		var peak: int = 0
		for i: int in range(44, data.size() - 1, 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		assert_between(peak, 1000, 29300, "%s is audible and peaks at -1 dBFS or under" % cue)


func test_the_run_events_sound_as_they_play() -> void:
	_link_small_triple()
	assert_eq(played, [] as Array[StringName], "nothing before the event plays")
	sequencer.advance(0.0)
	assert_eq(played, [&"link_collect"] as Array[StringName])
	var ids: Array[int] = []
	for size: Star.Size in [Star.Size.SMALL, Star.Size.SMALL, Star.Size.BIG]:
		ids.append(run.add_star(size, Vector2i(60 + ids.size() * 20, 150)).id)
	run.link(ids)
	sequencer.advance(0.0)
	assert_eq(played.back(), &"link_reject")
	run.dust = 10
	run.buy("red")
	sequencer.advance(0.0)
	assert_has(played, &"pack_buy")


## No launcher holds the sequencer here, so a launch's events all play in one step.
func test_a_launch_whooshes_and_bursts_and_a_big_bang_opens_like_any_burst() -> void:
	run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	assert_eq(played.slice(0, 2), [&"launch", &"burst"] as Array[StringName])
	played.clear()
	sfx.advance(1.0)
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	assert_eq(played.slice(0, 2), [&"launch", &"burst"] as Array[StringName], "no spoiler: the same burst")
	for cue: StringName in played:
		assert_false(String(cue).begins_with("big_bang"), "the Big Bang's own sounds wait for its timeline")


func test_a_dust_payout_climbs_a_semitone_per_landing_then_starts_over() -> void:
	for i: int in 4:
		sfx.on_dust_arrived(1)
		sfx.advance(0.05)
	assert_eq(played.size(), 4)
	for i: int in 4:
		var expected: float = pow(Sfx.SEMITONE, i)
		assert_almost_eq(pitches[i], expected, expected * Sfx.JITTER + 0.001, "landing %d" % i)
	sfx.advance(Sfx.DUST_CLIMB_RESET + 0.01)
	sfx.on_dust_arrived(1)
	assert_almost_eq(pitches.back(), 1.0, Sfx.JITTER + 0.001, "a pause starts the count-up over")


func test_the_count_up_tops_out() -> void:
	for i: int in 30:
		sfx.on_dust_arrived(1)
		sfx.advance(0.1)
	var top: float = pow(Sfx.SEMITONE, Sfx.DUST_CLIMB_MAX)
	assert_almost_eq(pitches.max(), top, top * Sfx.JITTER + 0.001)


func test_a_burst_of_landings_never_stacks_past_the_voice_limit() -> void:
	for i: int in 20:
		sfx.on_dust_arrived(1)
	assert_eq(played.size(), 1, "same instant: one tick, not twenty")
	for i: int in 40:
		sfx.on_dust_arrived(1)
		sfx.advance(0.01)
		assert_true(sfx.voices_of(&"dust_land") <= int(Sfx.LIMITS[&"dust_land"].x))
	assert_lt(played.size(), 40, "the gap thins a dense stream")
	assert_gt(played.size(), 5, "but it still sounds like one")


func test_a_full_pool_steals_its_oldest_voice() -> void:
	var cues: Array[StringName] = [&"burst", &"launch", &"win", &"loss", &"sun_ignite", &"restart", &"link_collect"]
	for round: int in 2:
		for cue: StringName in cues:
			assert_true(sfx.play(cue), "%s under its own limit" % cue)
			sfx.advance(0.031)
	assert_eq(sfx.voices(), Sfx.VOICES, "14 asked, the pool holds 12")
	assert_eq(sfx.voices_of(&"burst"), 1, "the oldest burst gave its voice up")


func test_star_taps_ring_up_a_triad() -> void:
	for count: int in [1, 2, 3]:
		sfx.on_star_selected(count)
		sfx.advance(0.1)
	assert_eq(pitches, Sfx.SELECT_PITCH)


func test_the_pull_creaks_higher_per_gem() -> void:
	for frame: int in range(1, Launcher.PULL_FRAMES):
		sfx.on_pull_stepped(frame)
		sfx.advance(0.1)
	assert_eq(played.size(), Launcher.PULL_FRAMES - 1)
	for i: int in range(1, pitches.size()):
		assert_gt(pitches[i], pitches[i - 1])


func test_the_silence_cuts_every_voice_and_refuses_cues_until_the_bang() -> void:
	sfx.play(&"burst")
	sfx.play(&"big_bang_collapse")
	assert_gt(sfx.voices(), 0)
	sfx.duck()
	assert_eq(sfx.voices(), 0, "silence")
	assert_false(sfx.play(&"dust_land"))
	sfx.on_big_bang_banged()
	assert_false(sfx.is_ducked())
	assert_eq(played.back(), &"big_bang_bang", "the bang breaks it")


func test_a_duck_nothing_lifts_lifts_itself() -> void:
	sfx.duck()
	sfx.advance(Sfx.DUCK_SAFETY + 0.01)
	assert_false(sfx.is_ducked())
	assert_true(sfx.play(&"burst"))


func test_a_new_run_starts_in_silence_with_no_duck() -> void:
	sfx.play(&"burst")
	sfx.duck()
	sfx.setup(Fixtures.run(), sequencer)
	assert_false(sfx.is_ducked())
	assert_eq(sfx.voices(), 0)


func test_muted_nothing_plays_and_low_still_plays() -> void:
	sfx.set_level(Sfx.Level.MUTE)
	assert_false(sfx.play(&"burst"))
	_link_small_triple()
	sequencer.advance(0.0)
	assert_eq(played, [] as Array[StringName])
	sfx.set_level(Sfx.Level.LOW)
	assert_true(sfx.play(&"burst"))
	var bus: int = AudioServer.get_bus_index(Sfx.BUS)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), Sfx.LEVEL_DB[Sfx.Level.LOW], 0.01)


func test_the_level_cycles_and_is_remembered() -> void:
	var levels: Array[int] = []
	sfx.level_changed.connect(func(l: int) -> void: levels.append(l))
	sfx.cycle_level()
	sfx.cycle_level()
	sfx.cycle_level()
	assert_eq(levels, [Sfx.Level.LOW, Sfx.Level.MUTE, Sfx.Level.ON] as Array[int])
	sfx.cycle_level()
	var next: Sfx = _new_sfx()
	assert_eq(next.level, Sfx.Level.LOW, "saved between sessions")


func test_the_speaker_draws_its_level() -> void:
	var on: Array[Vector2i] = SoundIcon.pixels(Sfx.Level.ON)
	var low: Array[Vector2i] = SoundIcon.pixels(Sfx.Level.LOW)
	var mute: Array[Vector2i] = SoundIcon.pixels(Sfx.Level.MUTE)
	assert_gt(on.size(), low.size(), "one arc fewer")
	assert_ne(mute, low)
	for dot: Vector2i in on + mute:
		assert_true(Rect2i(0, 0, 9, 7).has_point(dot), "9x7")


func test_the_big_bang_marks_its_timeline_once_each() -> void:
	var big_bang: BigBangSequence = preload("res://game/fx/big_bang.tscn").instantiate()
	add_child_autofree(big_bang)
	big_bang.set_process(false)
	big_bang.setup(run, sequencer)
	var marks: Array[String] = []
	big_bang.collapse_started.connect(func() -> void: marks.append("collapse"))
	big_bang.silence_started.connect(func() -> void: marks.append("silence"))
	big_bang.banged.connect(func() -> void: marks.append("bang"))
	run.force_next_big_bang = true
	run.launch(Vector2i(90, 160))
	sequencer.advance(0.0)
	sequencer.advance(0.0)
	var t: float = 0.0
	while t < BigBangSequence.BANG_AT + 3.0:
		big_bang.advance(1.0 / 30.0)
		t += 1.0 / 30.0
		if t < BigBangSequence.FREEZE_AT:
			assert_eq(marks.size(), 0)
		elif t >= BigBangSequence.FREEZE_AT + BigBangSequence.COLLAPSE_TIME + 0.04 and t < BigBangSequence.BANG_AT:
			assert_eq(marks.size(), 2, "silent from the implosion")
	assert_eq(marks.size(), 3)
	assert_eq(marks, ["collapse", "silence", "bang"])


func test_main_wires_the_feedback_moments() -> void:
	var main: Main = _main()
	var main_sfx: Sfx = main.get_node("Sfx")
	main_sfx.cue_played.connect(_record)
	var launcher: Launcher = main.get_node("Launcher")
	launcher.pull_started.emit()
	launcher.tremble_started.emit()
	(main.get_node("Sky") as SkyView).star_selected.emit(1)
	(main.get_node("HUD") as Hud).tap_refused.emit("red")
	(main.get_node("Sun") as SunView).ignited.emit()
	for cue: StringName in [&"pull_start", &"tremble", &"star_select", &"tap_refused", &"sun_ignite"]:
		assert_has(played, cue)


func test_a_pack_chimes_when_the_counter_reaches_its_cost() -> void:
	var main: Main = _main()
	var main_sfx: Sfx = main.get_node("Sfx")
	main_sfx.level = Sfx.Level.ON
	main_sfx.cue_played.connect(_record)
	var hud: Hud = main.get_node("HUD")
	main.run.dust = 2
	hud.refresh()
	assert_false(played.has(&"pack_ready"), "a refresh isn't news")
	var ids: Array[int] = []
	for x: int in [70, 90, 110]:
		ids.append(main.run.add_star(Star.Size.SMALL, Vector2i(x, 150)).id)
	main.run.link(ids)
	(main.get_node("EventSequencer") as EventSequencer).advance(0.0)
	hud.receive_dust(1)
	main_sfx.advance(0.1)
	assert_false(played.has(&"pack_ready"), "3 is short of 4")
	hud.receive_dust(1)
	assert_eq(played.count(&"pack_ready"), 1, "4: blue is buyable, with its flash")
	main_sfx.advance(0.1)
	hud.receive_dust(1)
	assert_eq(played.count(&"pack_ready"), 1, "still buyable: no repeat")


func test_a_new_run_never_chimes_its_packs() -> void:
	var main: Main = _main()
	var main_sfx: Sfx = main.get_node("Sfx")
	main_sfx.level = Sfx.Level.ON
	main_sfx.cue_played.connect(_record)
	var rich: Dictionary = Fixtures.balance_dict()
	rich["start_dust"] = 20
	main.start_run(Balance.from_dict(rich))
	assert_false(played.has(&"pack_ready"))


func test_the_speaker_target_sits_on_the_hud_speaker() -> void:
	var hud: Hud = _main().get_node("HUD")
	assert_eq(SoundToggle.TARGET, hud.sound_target())
	assert_eq(hud.target_at(Vector2i(8, 8)), [], "the HUD doesn't take speaker taps itself")


func test_a_speaker_tap_cycles_the_level_and_shows_it() -> void:
	var main: Main = _main()
	_tap_screen(Vector2i(8, 8))
	assert_eq((main.get_node("Sfx") as Sfx).level, Sfx.Level.LOW)
	assert_eq((main.get_node("HUD") as Hud).sound_level(), Sfx.Level.LOW)


func test_the_speaker_works_while_a_sequence_blocks_the_game() -> void:
	var main: Main = _main()
	var main_sfx: Sfx = main.get_node("Sfx")
	main.run.dust = 20
	main.run.launch(Vector2i(90, 160))
	assert_true((main.get_node("EventSequencer") as EventSequencer).is_busy())
	_tap_screen(Vector2i(8, 8))
	assert_eq(main_sfx.level, Sfx.Level.LOW, "turned down mid-launch")
	var blue: Vector2i = Vector2i((main.get_node("HUD") as Hud).slot("blue").position) + PackSlot.COST_TARGET.get_center()
	var owned: int = main.run.owned_packs["blue"]
	_tap_screen(blue)
	assert_eq(main.run.owned_packs["blue"], owned, "the game itself stays blocked")


func test_the_speaker_works_over_the_end_screen() -> void:
	var main: Main = _main()
	var end_screen: EndScreen = main.get_node("EndScreen")
	for kind: String in main.run.owned_packs.keys():
		main.run.owned_packs[kind] = 0
	main.run.loaded_pack = ""
	var ids: Array[int] = []
	for x: int in [70, 90, 110]:
		ids.append(main.run.add_star(Star.Size.SMALL, Vector2i(x, 150)).id)
	main.run.link(ids)
	assert_eq(main.run.outcome, RunState.Outcome.LOST)
	var main_sequencer: EventSequencer = main.get_node("EventSequencer")
	var particles: CollectParticles = main.get_node("CollectParticles")
	particles.set_process(false)
	for i: int in 180:
		main_sequencer.advance(1.0 / 30.0)
		particles.advance(1.0 / 30.0)
	assert_true(end_screen.is_showing())
	_tap_screen(Vector2i(8, 8))
	assert_eq((main.get_node("Sfx") as Sfx).level, Sfx.Level.LOW, "muted over the jingle")
	assert_true(end_screen.is_showing(), "the plaque stays")
	_tap_screen(end_screen.restart_rect().get_center())
	assert_false(end_screen.is_showing(), "and RESTART still works")


func test_a_press_off_the_speaker_released_on_it_does_nothing() -> void:
	var toggle := SoundToggle.new()
	add_child_autofree(toggle)
	var toggles: Array[bool] = []
	toggle.toggled.connect(func() -> void: toggles.append(true))
	assert_false(toggle.handle_pointer(_touch(Vector2(90, 160), true)))
	assert_true(toggle.handle_pointer(_touch(Vector2(8, 8), false)), "the release on it is still taken")
	assert_eq(toggles, [] as Array[bool])


func test_the_pull_signals_its_start_its_growing_gems_and_a_short_release() -> void:
	var launcher: Launcher = _main().get_node("Launcher")
	var heard: Array[String] = []
	launcher.pull_started.connect(func() -> void: heard.append("start"))
	launcher.pull_stepped.connect(func(frame: int) -> void: heard.append("gem %d" % frame))
	launcher.pull_cancelled.connect(func() -> void: heard.append("cancel"))
	assert_true(launcher.handle_pointer(_touch(Vector2.ZERO, true)))
	for y: int in [8, 14, 24, 10, 24, 2]:
		launcher.handle_pointer(_drag(Vector2(0, y)))
	launcher.handle_pointer(_touch(Vector2(0, 2), false))
	assert_eq(heard, ["start", "gem 1", "gem 2", "gem 3", "gem 3", "cancel"],
		"a gem sounds only as the pull grows (a jump sounds its top gem once); letting go short snaps back")


func test_a_full_pull_launches_without_a_cancel() -> void:
	var launcher: Launcher = _main().get_node("Launcher")
	var cancelled: Array[bool] = []
	launcher.pull_cancelled.connect(func() -> void: cancelled.append(true))
	launcher.handle_pointer(_touch(Vector2.ZERO, true))
	launcher.handle_pointer(_drag(Vector2(0, 24)))
	launcher.handle_pointer(_touch(Vector2(0, 24), false))
	assert_eq(cancelled, [] as Array[bool])


func test_the_sky_signals_each_star_joining_a_link() -> void:
	var main: Main = _main()
	var sky: SkyView = main.get_node("Sky")
	main.run.launch(Vector2i(90, 160))
	var main_sequencer: EventSequencer = main.get_node("EventSequencer")
	for i: int in 120:
		main_sequencer.advance(1.0 / 30.0)
	var counts: Array[int] = []
	sky.star_selected.connect(func(count: int) -> void: counts.append(count))
	var first: Vector2i = main.run.stars[0].position
	var second: Vector2i = main.run.stars[1].position
	for point: Vector2i in [first, second, second]:
		sky.handle_pointer(_touch(Vector2(point), true))
		sky.handle_pointer(_touch(Vector2(point), false))
	assert_eq(counts, [1, 2] as Array[int], "tapping a selected star again drops it: no sound")


func test_restarting_during_the_big_bang_silence_leaves_nothing_behind() -> void:
	var main: Main = _main()
	var main_sfx: Sfx = main.get_node("Sfx")
	var main_sequencer: EventSequencer = main.get_node("EventSequencer")
	var big_bang: BigBangSequence = main.get_node("BigBang")
	main.run.force_next_big_bang = true
	main.run.launch(Vector2i(90, 160))
	main_sequencer.advance(0.0)
	main_sequencer.advance(Launcher.FLIGHT_TIME + Launcher.TREMBLE_TIME)
	assert_true(big_bang.is_playing())
	big_bang.advance(BigBangSequence.FREEZE_AT + BigBangSequence.COLLAPSE_TIME + 0.05)
	assert_true(main_sfx.is_ducked(), "the silence")
	main.restart()
	assert_false(main_sfx.is_ducked(), "a restart lifts it")
	assert_eq(main_sfx.voices(), 0)
	big_bang.advance(5.0)
	main_sfx.cue_played.connect(_record)
	main_sfx.advance(0.1)
	assert_false(played.has(&"big_bang_bang"), "the old bang never comes")


func test_muted_play_keeps_every_visual() -> void:
	var main: Main = _main()
	var main_sfx: Sfx = main.get_node("Sfx")
	main_sfx.level = Sfx.Level.MUTE
	var ids: Array[int] = []
	for x: int in [70, 90, 110]:
		ids.append(main.run.add_star(Star.Size.SMALL, Vector2i(x, 150)).id)
	main.run.link(ids)
	(main.get_node("EventSequencer") as EventSequencer).advance(0.0)
	assert_gt((main.get_node("CollectParticles") as CollectParticles).particle_count(), 0, "payouts still fly")
	assert_true((main.get_node("Sky/LinkLayer") as LinkLayer).is_flashing(), "the link still flares")


func _main() -> Main:
	var main: Main = MainScene.instantiate()
	main.seed_override = 7
	main.get_node("Sfx").settings_path = SETTINGS
	add_child_autofree(main)
	for node: Node in [main.get_node("EventSequencer"), main.get_node("BigBang"), main.get_node("Sfx"), main.get_node("Launcher")]:
		node.set_process(false)
	return main


## A tap through the real viewport, so every _input gate sees it in tree order.
func _tap_screen(at: Vector2i) -> void:
	for pressed: bool in [true, false]:
		get_viewport().push_input(_touch(Vector2(at), pressed), true)


func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = at
	e.pressed = pressed
	return e


func _drag(at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.position = at
	return e


func _new_sfx() -> Sfx:
	var s := Sfx.new()
	s.settings_path = SETTINGS
	add_child_autofree(s)
	s.set_process(false)
	return s


func _record(cue: StringName, pitch: float) -> void:
	played.append(cue)
	pitches.append(pitch)


func _link_small_triple() -> void:
	var ids: Array[int] = []
	for x: int in [70, 90, 110]:
		ids.append(run.add_star(Star.Size.SMALL, Vector2i(x, 150)).id)
	assert_eq(run.link(ids), "small_triple")
