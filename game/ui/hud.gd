class_name Hud
extends CanvasLayer
## The HUD: dust on the left and one PackSlot per pack kind on the right (y 284-320, no panel).
## Numbers are bitmap-font Labels. The Sun's light has no number (#59): its fill is the progress.
## Pack taps follow docs/design.md (Packs): the icon loads an owned pack or buys one if none is
## owned; the cost buys one more. The core says whether that works: RunState.load_pack() and
## RunState.buy() refuse what isn't allowed, and a refused tap nudges the icon. No rules here.
## RunState resolves a whole launch at once, so the HUD keeps its own shown copy of the run and
## moves it only as the sequencer plays each event: counters never run ahead of the animation.
## A combo's dust arrives later, as particles land (receive_dust, wired by Main): the counter
## ticks up and hops a pixel. Until then that amount is "in flight". The core
## has already credited it, so a purchase may spend it: that part becomes a debt the next landings
## pay first, the counter never drops below 0, and it always ends on the run's total.
## The speaker in the top-left corner only shows the sound level (show_sound_level); its taps go
## to SoundToggle, ahead of the gameplay input gates.
## Costs light up against the shown counter: as the dust lands, the pack reacts (its one-off cue
## plays on the crossing). Buying works on the dust owned (shown + in flight - debt), which is never
## less, so a lit cost always buys; right after a collect, a grey one may buy too.
## The boss stage (the final): as Orion enters, his title card stamps onto the middle of the sky
## (BossBanner).

## A pack tap the run refused (the icon nudges). Feedback only (sound).
signal tap_refused(kind: String)
## A pack became buyable as the dust landed (its slot's cue). Feedback only (sound).
signal pack_ready(kind: String)
## The player picked a planet with its icon or its buy button, and it loaded (or was bought and
## loaded). The telescope aims with it (Main wires it).
signal planet_chosen(kind: String)
## The MAP button was tapped: back to the chapter's chart (#62; only shown in a chapter).
signal map_requested

const PackSlotScene := preload("res://game/ui/pack_slot.tscn")

## Slot layout: one column per pack kind, the last centred at LAST_SLOT_X.
const SLOT_SPACING: int = 30
const LAST_SLOT_X: int = 158
const SLOT_Y: int = 290
## Where the speaker, the dust icon and the dust counter sit on a 9:16 screen (fit_screen moves
## them to the real screen's corners).
## The speaker sits 10 px in from the corner: a phone's rounded corner clipped it at 4 px.
const SOUND_AT := Vector2i(10, 10)
## The MAP button (in a chapter) sits this far in from the top-right corner.
const MAP_INSET: int = 10
const DUST_ICON_AT := Vector2i(12, 300)
## On a wider screen the dust counter and the pack slots stay at most this many px out beside the
## game's own 180 columns, close to the stage, rather than in the far corners.
const HUD_REACH: int = 12
const DUST_AT := Vector2i(20, 297)
## A counter hops 1 px up for this long when a particle lands on it.
const HOP_TIME: float = 0.1
## The message line (show_message), on the land above the HUD row, and how long a message stays.
const MESSAGE_Y: int = 262
const MESSAGE_TIME: float = 1.6
## Orion's first mark of a run (#64) says what it means, a little longer.
const ORION_MESSAGE: String = "LINK IT NEXT OR ORION SHOOTS"
const ORION_MESSAGE_TIME: float = 3.0
## Orion's first hunting area of a run (#71) says what the ring means.
const HUNT_MESSAGE: String = "LAUNCH AND ORION SHOOTS HERE"
## Orion's volley countdown (#70) sits centred this far from his figure's top-left: above his head.
const VOLLEY_COUNTER_OFFSET := Vector2i(15, -8)

var _run: RunState
var _sequencer: EventSequencer
var _slots: Dictionary[String, PackSlot] = {}
## The target a press started on, as [kind, part], or [] for none. A tap needs press and
## release on the same target.
var _pressed: Array = []
## The run as the events played so far have shown it.
var _shown_dust: int = 0
var _shown_packs: Dictionary[String, int] = {}
var _shown_loaded: String = ""
## Rewards whose event has played but whose particles haven't landed yet.
var _dust_in_flight: int = 0
## The part of the dust in flight that a purchase already spent.
var _dust_debt: int = 0
## Seconds of hop left per counter, and where each counter rests.
var _hops: Dictionary[Label, float] = {}
var _rest: Dictionary[Label, Vector2] = {}
var _message_left: float = 0.0
## Orion's first mark has been explained this run.
var _orion_told: bool = false
## The volley countdown above Orion, shown on stages with a volley.
var _volley := VolleyCounter.new()
## The boss's title card, in the middle of the sky.
var _banner := BossBanner.new()
## The guided first run's guide: a line and a pointing hand.
var _guide := TutorialView.new()

@onready var _dust: Label = $Dust
@onready var _slot_layer: Node2D = $Slots
@onready var _sound: SoundIcon = $SoundIcon
@onready var _message: Label = $Message
@onready var _map: MapButton = $MapButton


func _ready() -> void:
	_dust.label_settings = HudText.primary(Palette.D0)
	_rest[_dust] = _dust.position
	_message.label_settings = HudText.primary(Palette.C1)
	_message.position = Vector2(0, MESSAGE_Y)
	_message.visible = false
	_volley.name = "VolleyCountdown"
	_volley.visible = false
	add_child(_volley)
	_banner.name = "BossBanner"
	add_child(_banner)
	_guide.name = "TutorialGuide"
	add_child(_guide)


func _process(delta: float) -> void:
	advance(delta)


## Anchors the HUD to the real screen, `screen` in game coordinates (on a 9:16 screen, the game's
## own 0,0 180x320): the speaker in its top-left corner, the dust counter on its bottom-left, the
## pack slots on its bottom-right (on a wide screen, no more than HUD_REACH px out from the game).
func fit_screen(screen: Rect2i) -> void:
	var bottom: int = screen.end.y - ScreenZones.SCREEN.y
	var left: int = maxi(screen.position.x, -HUD_REACH)
	var right: int = mini(screen.end.x - ScreenZones.SCREEN.x, HUD_REACH)
	_sound.position = Vector2(SOUND_AT + screen.position)
	# The MAP button mirrors the speaker in the top-right corner.
	_map.position = Vector2(Vector2i(screen.end.x - MAP_INSET - MapButton.SIZE.x, screen.position.y + MAP_INSET))
	($DustIcon as Node2D).position = Vector2(DUST_ICON_AT + Vector2i(left, bottom))
	_rest[_dust] = Vector2(DUST_AT + Vector2i(left, bottom))
	_dust.position = _rest[_dust]
	_slot_layer.position = Vector2(right, bottom)


func _unhandled_input(event: InputEvent) -> void:
	if handle_pointer(ScreenZones.to_game(event, Vector2i(offset))):
		get_viewport().set_input_as_handled()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_build_slots(run.balance.pack_kinds())
	_orion_told = false
	_volley.visible = run.volley != null
	if run.volley != null:
		_volley.position = Vector2(run.sky_rect.position + OrionView.FIGURE_AT + VOLLEY_COUNTER_OFFSET)
		_volley.reset(run.volley.links_left(), run.volley.interval)
	_banner.position = Vector2(run.sky_rect.get_center())
	_banner.hide_card()
	_guide.hide_guide()
	_press([])
	refresh()


## Catches up with the run as it stands: dust, and each pack's count, cost and state.
func refresh() -> void:
	_shown_dust = _run.dust
	_shown_packs = _run.owned_packs.duplicate()
	_shown_loaded = _run.loaded_pack
	_dust_in_flight = 0
	_dust_debt = 0
	_show(false)


## A dust particle landed on the counter.
func receive_dust(amount: int) -> void:
	_dust_in_flight = maxi(_dust_in_flight - amount, 0)
	var repaid: int = mini(amount, _dust_debt)
	_dust_debt -= repaid
	_shown_dust += amount - repaid
	if amount > repaid:
		_hop(_dust)
	_show()


## Moves the counters' hops on. Driven by `_process`; tests call it directly.
func advance(delta: float) -> void:
	for label: Label in _hops:
		_hops[label] = maxf(_hops[label] - delta, 0.0)
		label.position = _rest[label] + (Vector2.UP if _hops[label] > 0.0 else Vector2.ZERO)
	if _message_left > 0.0:
		_message_left -= delta
		_message.visible = _message_left > 0.0


## Shows a short message above the launcher for `seconds` ("" clears it).
func show_message(text: String, seconds: float = MESSAGE_TIME) -> void:
	_message.text = text
	_message_left = seconds if text != "" else 0.0
	_message.visible = text != ""


## The message on show, or "" for none.
func message() -> String:
	return _message.text if _message.visible else ""


## Shows the sound level (Sfx.Level) on the speaker.
func show_sound_level(level: int) -> void:
	_sound.level = level


func sound_level() -> int:
	return _sound.level


## The speaker's tap target on screen (SoundToggle takes the taps).
## Shows the MAP button (in a chapter) or hides it.
func show_map_button(on: bool) -> void:
	_map.visible = on


func is_map_button_shown() -> bool:
	return _map.visible


func map_target() -> Rect2i:
	return _map.target()


func sound_target() -> Rect2i:
	return Rect2i(SoundIcon.TARGET.position + Vector2i(_sound.position), SoundIcon.TARGET.size)


func slot(kind: String) -> PackSlot:
	return _slots.get(kind)


## Feeds one touch (in screen coordinates). Returns true if it was used.
func handle_pointer(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch == null or touch.index != 0 or _run == null:
		return false
	var target: Array = target_at(Vector2i(touch.position.floor()))
	if touch.canceled:
		var had: bool = not _pressed.is_empty()
		_press([])
		return had
	if touch.pressed:
		_press(target)
		return not target.is_empty()
	if _pressed.is_empty():
		return false
	var pressed: Array = _pressed
	_press([])
	if target == pressed:
		_tap(target[0], target[1])
	return true


## The tap target under a screen point, as [kind, &"icon" or &"cost"], or [] for none.
func target_at(point: Vector2i) -> Array:
	if _map.visible and _map.target().has_point(point):
		return ["", &"map"]
	for kind: String in _slots:
		var part: StringName = _slots[kind].target_at(point - Vector2i(_slot_layer.position + _slots[kind].position))
		if part != &"":
			return [kind, part]
	return []


## Remembers the target a press started on; a buy button shows held down while pressed.
func _press(target: Array) -> void:
	_pressed = target
	_map.pressed = target == ["", &"map"]
	for kind: String in _slots:
		_slots[kind].press_buy(target == [kind, &"cost"])


func _tap(kind: String, part: StringName) -> void:
	if part == &"map":
		map_requested.emit()
		return
	var done: bool
	if part == &"icon":
		done = _run.load_pack(kind) or _run.buy(kind)
	else:
		done = _run.buy(kind)
	if done:
		planet_chosen.emit(kind)
	if not done:
		_slots[kind].nudge()
		tap_refused.emit(kind)


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_bought":
			_shown_packs[event.args[0]] = _shown_packs.get(event.args[0], 0) + 1
			if _slots.has(event.args[0]):
				_slots[event.args[0]].flash_bought()
			_shown_dust = event.args[1] - (_dust_in_flight - _dust_debt)
			if _shown_dust < 0:
				_dust_debt -= _shown_dust
				_shown_dust = 0
		&"pack_loaded":
			_shown_loaded = event.args[0]
		&"pack_launched":
			_shown_packs[event.args[0]] = _shown_packs.get(event.args[0], 0) - 1
		&"big_bang_started":
			# Streams to the counter once it bangs, like a combo's dust.
			_dust_in_flight += event.args[2]
		&"sky_cleared":
			# Scorpio: the dust of the stars the Sun bursts streams in as they burst.
			_dust_in_flight += event.args[1]
		&"combo_collected":
			_dust_in_flight += event.args[2]
		&"volley_counted":
			_volley.count(event.args[0])
			return
		&"volley_fired":
			_volley.fire()
			return
		&"boss_appeared":
			_banner.play()
			return
		&"tutorial_step":
			_show_tutorial_step(event.args[0])
			return
		&"star_marked":
			if not _orion_told:
				_orion_told = true
				show_message(ORION_MESSAGE, ORION_MESSAGE_TIME)
			return
		&"area_marked":
			if not _orion_told:
				_orion_told = true
				show_message(HUNT_MESSAGE, ORION_MESSAGE_TIME)
			return
		_:
			return
	_show()


func tutorial_guide() -> TutorialView:
	return _guide


## Where the buy button of `kind` sits (its plate's left middle), in the HUD's coordinates.
func buy_button_at(kind: String) -> Vector2i:
	var slot: Vector2i = Vector2i(_slot_layer.position + _slots[kind].position)
	return slot + Vector2i(PackSlot.BUY_PLATE.position.x, PackSlot.BUY_PLATE.get_center().y)


## The guided first run's step: its line, and the hand at what it's about: a spot in the sky to
## launch at, the stars to link, the constellation star to launch by and light, the buy button.
func _show_tutorial_step(step: int) -> void:
	var card_top: int = _run.sky_rect.position.y + TutorialView.CARD_TOP
	match step:
		Tutorial.Step.LAUNCH:
			_guide.show_step(step, _run.sky_rect.get_center() + Vector2i(0, 12), true)
		Tutorial.Step.LINK:
			var star: Star = _run.stars[0] if not _run.stars.is_empty() else null
			_guide.show_step(step, star.position if star != null else Vector2i.ZERO, star != null, TutorialView.Point.DOWN, card_top)
		Tutorial.Step.LAUNCH_NEAR, Tutorial.Step.LIGHT:
			var index: int = _run.tutorial.landmark
			var at: Vector2i = _run.scorpio.landmark_position(index)
			var size: int = _run.scorpio.map.sizes[index]
			_guide.show_step(step, at - Vector2i(0, StarView.half_extent(size as Star.Size)), true, TutorialView.Point.DOWN, card_top, size)
		Tutorial.Step.BUY:
			_guide.show_step(step, buy_button_at("blue") - Vector2i(1, 0), true, TutorialView.Point.RIGHT)
		_:
			_guide.show_step(step, Vector2i.ZERO, false, TutorialView.Point.DOWN, card_top)


func boss_banner() -> BossBanner:
	return _banner


func volley_countdown() -> String:
	return _volley.text() if _volley.visible else ""


## The loaded marker needs a pack left to show: RunState empties the launcher without a signal
## when the last pack flies, like the launcher's rest pack. Costs light up against the shown dust.
## `announce` false (a refresh) updates the slots without playing their cue.
func _show(announce: bool = true) -> void:
	_dust.text = "%d" % _shown_dust
	for kind: String in _slots:
		var count: int = _shown_packs.get(kind, 0)
		var cost: int = _run.balance.packs[kind].cost
		var loaded: bool = _shown_loaded == kind and count > 0
		_slots[kind].show_pack(count, cost, _shown_dust >= cost, loaded, announce)


func _hop(label: Label) -> void:
	_hops[label] = HOP_TIME
	label.position = _rest[label] + Vector2.UP


func _build_slots(kinds: Array[String]) -> void:
	if kinds == _slots.keys():
		return
	for old: Node in _slot_layer.get_children():
		old.queue_free()
	_slots.clear()
	for i: int in kinds.size():
		var pack_slot: PackSlot = PackSlotScene.instantiate()
		pack_slot.kind = kinds[i]
		pack_slot.position = Vector2(LAST_SLOT_X - SLOT_SPACING * (kinds.size() - 1 - i), SLOT_Y)
		_slot_layer.add_child(pack_slot)
		pack_slot.cue_started.connect(pack_ready.emit)
		_slots[kinds[i]] = pack_slot
