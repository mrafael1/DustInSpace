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
## The COMBOS button (under the MAP slot) opens the table (PaytableView, #94): each link and what it
## pays. While it shows the game holds still (Main pauses the world on table_opened; the HUD holds
## its own counters, message and guide) and any tap closes it.

## A pack tap the run refused (the icon nudges): `part` is &"icon" (a load) or &"cost" (a buy).
## Feedback only (sound, the playtest log).
signal tap_refused(kind: String, part: StringName)
## A pack became buyable as the dust landed (its slot's cue). Feedback only (sound).
signal pack_ready(kind: String)
## The player picked a planet with its icon or its buy button, and it loaded (or was bought and
## loaded). The telescope aims with it (Main wires it).
signal planet_chosen(kind: String)
## The MAP button was tapped: back to the chapter's chart (#62; only shown in a chapter).
signal map_requested
## The table opened or closed: Main pauses the world while it shows.
signal table_opened
signal table_closed

const PackSlotScene := preload("res://game/ui/pack_slot.tscn")
const MapButtonScene := preload("res://game/ui/map_button.tscn")

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
## The COMBOS button sits under the MAP slot, this far below its top: their 44 pt targets don't meet.
const TABLE_BELOW: int = 22
const TABLE_TEXT: String = "COMBOS"
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
## A current's rule, said once a run as the player first aims (#128: before the first launch is
## committed; revisits and retries hear it again, it's short): it moves stars; where it drains,
## that it takes the stars it carries past its edge; a tide or box, that it turns and drains.
## At most 22 characters a line (132 px).
const FLOW_MESSAGE: String = "EACH LAUNCH, THE FLOW\nMOVES THE STARS"
const DRAIN_MESSAGE: String = "STARS PAST THE EMBER\nLINE ARE LOST"
const TIDE_MESSAGE: String = "TIDE TURNS EACH LAUNCH\nBOTH SIDES DRAIN STARS"
const BOX_MESSAGE: String = "FLOW TURNS EACH LAUNCH\nEVERY SIDE DRAINS"
const RULE_MESSAGE_TIME: float = 3.5
## A final that isn't Orion's arrives with its title card for this long (no threat, no roar).
const ARRIVAL_TIME: float = 2.2
## A refused pick's reason, said on the message line (#91): two lines, so it fits the 180 px screen.
## It stays RULE_TIME, and the same reason again within RULE_QUIET says nothing new.
const REFUSAL_MESSAGES: Dictionary = {
	RunState.PickRefusal.SECOND_LANDMARK: "ONE CONSTELLATION STAR\nPER LINK",
}
const RULE_TIME: float = 2.5
const RULE_QUIET: float = 3.0
## A second line of the message goes above the first, this far up.
const MESSAGE_LINE_STEP: int = 10
## Each Orion encounter's line (#93), at the top of the sky like the tutorial's, centred right of
## ENCOUNTER_LINE_LEFT so it clears Orion's corner (two lines at most, 5x7, no punctuation). The
## volley's says its interval.
const ENCOUNTER_LINE_LEFT: int = 42
const ENCOUNTER_LINES: Dictionary = {
	Encounter.Threat.MARK: "LINK THE MARKED STAR\nOR HIS ARROW TAKES IT",
	Encounter.Threat.VOLLEY: "EVERY %d LINKS\nHIS ARROWS FALL",
	Encounter.Threat.HUNT: "LAUNCH AWAY FROM\nHIS CIRCLE",
}
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
var _current_told: bool = false
## Where the loaded planet shows on the launcher (the telescope's window), for the tutorial's hand.
## Main wires it: `func() -> Vector2i`.
var loaded_window_at: Callable
## The volley countdown above Orion, shown on stages with a volley.
var _volley := VolleyCounter.new()
## The boss's title card, in the middle of the sky.
var _banner := BossBanner.new()
## The table (#94) and its button.
var _table := PaytableView.new()
var _table_button: MapButton = MapButtonScene.instantiate()
## The HUD's own children's process modes while the table holds them still.
var _held: Dictionary[Node, Node.ProcessMode] = {}
## The guided first run's guide: a line and a pointing hand.
var _guide := TutorialView.new()
## Where the Sun is (Main sets it), for the guide's hand.
var sun_at: Vector2i = Vector2i(90, 39)

@onready var _dust: Label = $Dust
@onready var _slot_layer: Node2D = $Slots
@onready var _sound: SoundIcon = $SoundIcon
## Refusal reasons said lately, and seconds until they may be said again.
var _refusal_quiet: Dictionary[int, float] = {}
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
	_guide.timed_out.connect(func() -> void:
		if _run != null:
			_run.tutorial_continue())
	add_child(_guide)
	_table_button.name = "TableButton"
	_table_button.text = TABLE_TEXT
	add_child(_table_button)
	_table.name = "Table"
	add_child(_table)


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
	# The COMBOS button's right edge lines up with MAP's.
	_table_button.position = Vector2(Vector2i(screen.end.x - MAP_INSET - _table_button.plaque_size().x, screen.position.y + MAP_INSET + TABLE_BELOW))
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
	_current_told = false
	_volley.visible = run.volley != null
	if run.volley != null:
		_volley.position = Vector2(run.sky_rect.position + OrionView.FIGURE_AT + VOLLEY_COUNTER_OFFSET)
		_volley.reset(run.volley.links_left(), run.volley.interval)
	_banner.position = Vector2(run.sky_rect.get_center())
	_banner.hide_card()
	if run.scorpio != null and run.scorpio.map.arrival_epithet != "":
		_banner.play_arrival(run.scorpio.map.title, run.scorpio.map.arrival_epithet, ARRIVAL_TIME, Palette.M6, Palette.M4)
	_guide.hide_guide()
	close_table()
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


## Moves the counters' hops on. Driven by `_process`; tests call it directly. While the table shows,
## only its orders move.
func advance(delta: float) -> void:
	if _table.is_open():
		_table.advance(delta)
		return
	for label: Label in _hops:
		_hops[label] = maxf(_hops[label] - delta, 0.0)
		label.position = _rest[label] + (Vector2.UP if _hops[label] > 0.0 else Vector2.ZERO)
	if _message_left > 0.0:
		_message_left -= delta
		_message.visible = _message_left > 0.0
	for reason: int in _refusal_quiet.keys():
		_refusal_quiet[reason] -= delta
		if _refusal_quiet[reason] <= 0.0:
			_refusal_quiet.erase(reason)


## The run's current says its rule, once a run (Main calls it as the player first aims).
func tell_current_rule() -> void:
	if _current_told or _run == null or _run.current == null:
		return
	_current_told = true
	show_message(current_rule(_run.current), RULE_MESSAGE_TIME)


## What a current's message says: a box, a tide, a drain or a plain flow.
static func current_rule(current: StarCurrent) -> String:
	if current.turns.size() > 2:
		return BOX_MESSAGE
	if current.turns.size() > 1:
		return TIDE_MESSAGE
	return DRAIN_MESSAGE if current.drains else FLOW_MESSAGE


## Shows a short message above the launcher for `seconds` ("" clears it).
func show_message(text: String, seconds: float = MESSAGE_TIME) -> void:
	_message.text = text
	# Its last line stays on the message line; any line before it goes above.
	_message.position = Vector2(_message.position.x, MESSAGE_Y - text.count("\n") * MESSAGE_LINE_STEP)
	_message_left = seconds if text != "" else 0.0
	_message.visible = text != ""


## Says why a pick was refused (`reason`, a RunState.PickRefusal) on the message line, unless the
## same reason was said less than RULE_QUIET ago.
func explain_refusal(reason: RunState.PickRefusal) -> void:
	if not REFUSAL_MESSAGES.has(reason) or _refusal_quiet.has(reason):
		return
	_refusal_quiet[reason] = RULE_QUIET
	show_message(REFUSAL_MESSAGES[reason], RULE_TIME)


## Opens the table (#94) with the run's links and rewards; the game holds still until a tap.
func open_table() -> void:
	if _run == null or _table.is_open():
		return
	_table.open(_run.balance)
	for child: Node in get_children():
		if child != _table:
			_held[child] = child.process_mode
			child.process_mode = Node.PROCESS_MODE_DISABLED
	# The guide's line would crowd the plaque's top: it goes unseen (not hidden: it keeps its step).
	_guide.modulate = Color.TRANSPARENT
	table_opened.emit()


func close_table() -> void:
	if not _table.is_open():
		return
	_table.close()
	for child: Node in _held:
		if is_instance_valid(child):
			child.process_mode = _held[child]
	_held.clear()
	_guide.modulate = Color.WHITE
	table_closed.emit()


func table() -> PaytableView:
	return _table


## The COMBOS button's tap target.
func table_target() -> Rect2i:
	return _table_button.target()


## Where the COMBOS button's plaque starts (its left middle), for the guide's hand.
func table_button_at() -> Vector2i:
	return Vector2i(_table_button.position) + Vector2i(0, MapButton.SIZE.y / 2)


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
	# The table takes every touch while it shows; a tap closes it.
	if _table.is_open():
		var close := event as InputEventScreenTouch
		if close != null and not close.pressed and not close.canceled:
			close_table()
		return event is InputEventScreenTouch or event is InputEventScreenDrag
	# A tutorial step that only explains goes on at a tap. Off the buttons it takes the touch; on a
	# planet's button the tap goes on and does what it does too (MAP just leaves).
	var on_button: Array = target_at(Vector2i((event as InputEventScreenTouch).position.floor())) if event is InputEventScreenTouch else []
	if _guide.waits_for_tap() and _run != null and on_button != ["", &"map"]:
		var tap := event as InputEventScreenTouch
		if tap != null and not tap.pressed and not tap.canceled:
			_run.tutorial_continue()
		if on_button.is_empty():
			return event is InputEventScreenTouch or event is InputEventScreenDrag
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
	if _table_button.visible and _table_button.target().has_point(point):
		return ["", &"table"]
	for kind: String in _slots:
		var part: StringName = _slots[kind].target_at(point - Vector2i(_slot_layer.position + _slots[kind].position))
		if part != &"":
			return [kind, part]
	return []


## Remembers the target a press started on; a buy button shows held down while pressed.
func _press(target: Array) -> void:
	_pressed = target
	_map.pressed = target == ["", &"map"]
	_table_button.pressed = target == ["", &"table"]
	for kind: String in _slots:
		_slots[kind].press_buy(target == [kind, &"cost"])


func _tap(kind: String, part: StringName) -> void:
	if part == &"map":
		map_requested.emit()
		return
	if part == &"table":
		open_table()
		return
	var done: bool
	if part == &"icon":
		# The icon buys only a planet none is owned of (a refused load doesn't buy another).
		done = _run.load_pack(kind) or (_run.owned_packs.get(kind, 0) <= 0 and _run.buy(kind))
	else:
		done = _run.buy(kind)
	if done:
		planet_chosen.emit(kind)
	if not done:
		_slots[kind].nudge()
		tap_refused.emit(kind, part)


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
			# The tutorial's link is made: its stars are gone, so the hand stops pointing at them.
			_guide.drop_path()
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
		&"encounter_step":
			_show_encounter(event.args[0], event.args[1])
			return
		&"sun_rekindled":
			# The guided run's full Sun: the hand goes to the star it lights as the Sun ignites, so the
			# lighting is seen (the step itself comes once the sky has cleared).
			if _run.tutorial != null and not _run.tutorial.is_done() and event.args[0] >= 0:
				_guide.show_step(Tutorial.Step.SUN_FULL, _landmark_top(event.args[0]), true, TutorialView.Point.DOWN, _run.sky_rect.position.y + TutorialView.TOP)
			return
		&"stars_shifted":
			# Normally said when the player first aimed; a launch made without aiming says it here.
			tell_current_rule()
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


## Where the icon of `kind` tops out (its top middle), in the HUD's coordinates.
func pack_icon_top(kind: String) -> Vector2i:
	if not _slots.has(kind):
		return Vector2i.ZERO
	var slot: Vector2i = Vector2i(_slot_layer.position + _slots[kind].position)
	return slot - Vector2i(0, PackSlot.ICON_RADIUS + 1)


## Three big sky stars in an order that stays in reach (the red planet's link), or [] if there
## aren't three that can be linked.
func _big_three() -> Array[int]:
	var bigs: Array[int] = []
	for star: Star in _run.stars:
		if star.size == Star.Size.BIG:
			bigs.append(star.id)
	for a: int in bigs.size():
		for b: int in range(a + 1, bigs.size()):
			for c: int in range(b + 1, bigs.size()):
				var path: Array[int] = _reachable_order([bigs[a], bigs[b], bigs[c]])
				if _run.link_in_reach(path):
					return path
	return []


## Where the dust icon tops out (its top middle), in the HUD's coordinates.
func dust_icon_top() -> Vector2i:
	# The large icon is 9x9, centred on its node.
	return Vector2i(($DustIcon as Node2D).position) - Vector2i(0, 5)


## The guided first run's step: its line, and the hand at what it's about: a spot in the sky to
## launch at, the stars to link, the dust counter and the Sun as the payout lands, the
## constellation star to launch by and light, where the loaded planet shows (the telescope's
## window, its spinning icon), the star a full Sun lit, the buy button.
func _show_tutorial_step(step: int) -> void:
	var top: int = _run.sky_rect.position.y + TutorialView.TOP
	match step:
		Tutorial.Step.GOAL:
			var index: int = _run.rekindle_target()
			_guide.show_step(step, _landmark_top(index), index >= 0, TutorialView.Point.DOWN, top)
		Tutorial.Step.DUST:
			_guide.show_step(step, dust_icon_top(), true, TutorialView.Point.DOWN, top)
		Tutorial.Step.SUN:
			# From the left: the Sun sits at the top of the screen, with no room above it.
			_guide.show_step(step, sun_at - Vector2i(SunView.RADIUS + 2, 0), true, TutorialView.Point.RIGHT, top)
		Tutorial.Step.LAUNCH, Tutorial.Step.RED:
			_guide.show_step(step, _run.sky_rect.get_center() + Vector2i(0, 12), true, TutorialView.Point.DOWN, top)
		Tutorial.Step.LINK:
			_guide.show_step(step, Vector2i.ZERO, false, TutorialView.Point.DOWN, top)
			var ids: Array[int] = []
			for star: Star in _run.stars:
				ids.append(star.id)
			# The first link says either way works, and acts the drag out.
			var order: Array[int] = _reachable_order(ids)
			_guide.follow_path(order, _link_positions(order), _link_centres(order))
			# The table teaches the links first (#94); the hand plays once it's closed.
			open_table()
		Tutorial.Step.LAUNCH_NEAR, Tutorial.Step.LIGHT:
			var index: int = _run.tutorial.landmark
			var at: Vector2i = _run.scorpio.landmark_position(index)
			var size: int = _run.scorpio.map.sizes[index]
			_guide.show_step(step, at - Vector2i(0, StarView.half_extent(size as Star.Size)), true, TutorialView.Point.DOWN, top)
			if step == Tutorial.Step.LIGHT:
				var pair: Array[int] = []
				for star: Star in _run.stars:
					if star.size == size and pair.size() < 2:
						pair.append(star.id)
				if pair.size() == 2:
					var path: Array[int] = _reachable_order([pair[0], Scorpio.landmark_id(index), pair[1]])
					_guide.follow_path(path, _link_positions(path))
		Tutorial.Step.SCOPE:
			var window: Vector2i = loaded_window_at.call() if loaded_window_at.is_valid() else Vector2i(90, 290)
			# From the left: the barrel rises above its window, so the hand can't come down onto it.
			_guide.show_step(step, window - Vector2i(Telescope.BARREL_HALF + 1, 0), true, TutorialView.Point.RIGHT, top)
		Tutorial.Step.ICON:
			_guide.show_step(step, pack_icon_top(_run.loaded_pack), _run.loaded_pack != "", TutorialView.Point.DOWN, top)
		Tutorial.Step.RED_LINK:
			_guide.show_step(step, Vector2i.ZERO, false, TutorialView.Point.DOWN, top)
			var path: Array[int] = _big_three()
			if not path.is_empty():
				_guide.follow_path(path, _link_positions(path))
		Tutorial.Step.SUN_FULL:
			_guide.show_step(step, _landmark_top(_run.tutorial.landmark), _run.tutorial.landmark >= 0, TutorialView.Point.DOWN, top)
		Tutorial.Step.BUY:
			_guide.show_step(step, buy_button_at("blue") - Vector2i(1, 0), true, TutorialView.Point.RIGHT, top)
		Tutorial.Step.DONE:
			# Free play: the hand on the COMBOS button, from the left.
			_guide.show_step(step, table_button_at() - Vector2i(1, 0), true, TutorialView.Point.RIGHT, top)
		_:
			_guide.show_step(step, Vector2i.ZERO, false, TutorialView.Point.DOWN, top)


## An Orion threat's guided encounter (#93): its line at the top of the sky and the hand at what it's
## about, while it guides; gone once it's done. The mark: the hand acts out a link that saves the
## marked star. The volley: it points at the countdown above him. The hunting circle: it points at a
## spot outside it to launch at. It only guides: nothing is held back.
func _show_encounter(threat: int, step: int) -> void:
	if step != Encounter.Step.GUIDING:
		_guide.hide_guide()
		return
	var top: int = _run.sky_rect.position.y + TutorialView.TOP
	var left: int = _run.sky_rect.position.x + ENCOUNTER_LINE_LEFT
	match threat:
		Encounter.Threat.MARK:
			var link: Array[int] = _run.encounter_link()
			var target: Star = _run.marked_star()
			var at: Vector2i = target.position - Vector2i(0, StarView.half_extent(target.size)) if target != null else Vector2i.ZERO
			_guide.show_line(ENCOUNTER_LINES[threat], at, target != null, TutorialView.Point.DOWN, top, left)
			if not link.is_empty():
				_guide.follow_path(link, _link_positions(link), _link_centres(link))
		Encounter.Threat.VOLLEY:
			# Down onto the countdown above his head (its row's top is the node's origin).
			_guide.show_line(ENCOUNTER_LINES[threat] % _run.volley.interval, Vector2i(_volley.position), true, TutorialView.Point.DOWN, top, left)
		Encounter.Threat.HUNT:
			_guide.show_line(ENCOUNTER_LINES[threat], _run.safe_launch_spot(), true, TutorialView.Point.DOWN, top, left)


## The link being traced changed: the tutorial's hand moves on to the next star to pick.
func follow_link(ids: Array[int]) -> void:
	_guide.follow(ids)


## Where the hand points above a landmark (its art's top).
func _landmark_top(index: int) -> Vector2i:
	if index < 0:
		return Vector2i.ZERO
	return _run.scorpio.landmark_position(index) - Vector2i(0, StarView.half_extent(_run.scorpio.map.sizes[index] as Star.Size))


## `ids` in an order whose every step is in reach (the order the hand teaches).
func _reachable_order(ids: Array[int]) -> Array[int]:
	if ids.size() != 3:
		return ids
	for p: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var order: Array[int] = [ids[p[0]], ids[p[1]], ids[p[2]]]
		if _run.link_in_reach(order):
			return order
	return ids


## Where the hand points above each of `ids` (a sky star or a landmark): its art's top.
## Where the stars of a link sit (their centres): the dragged link's demo slides through them.
func _link_centres(ids: Array[int]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for id: int in ids:
		if _run.scorpio != null and _run.scorpio.is_landmark(id):
			points.append(_run.scorpio.landmark_position(Scorpio.landmark_index(id)))
		else:
			var star: Star = _run.find_star(id)
			points.append(star.position if star != null else Vector2i.ZERO)
	return points


func _link_positions(ids: Array[int]) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for id: int in ids:
		if _run.scorpio != null and _run.scorpio.is_landmark(id):
			points.append(_landmark_top(Scorpio.landmark_index(id)))
		else:
			var star: Star = _run.find_star(id)
			points.append(star.position - Vector2i(0, StarView.half_extent(star.size)) if star != null else Vector2i.ZERO)
	return points


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
