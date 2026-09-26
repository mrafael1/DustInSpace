class_name Hud
extends CanvasLayer
## The HUD: dust on the left and one PackSlot per pack kind on the right (y 284-320, no panel),
## plus the light counter "n/target" under the Sun. Numbers are bitmap-font Labels.
## Pack taps follow docs/design.md (Packs): the icon loads an owned pack or buys one if none is
## owned; the cost buys one more. The core says whether that works: RunState.load_pack() and
## RunState.buy() refuse what isn't allowed, and a refused tap nudges the icon. No rules here.
## RunState resolves a whole launch at once, so the HUD keeps its own shown copy of the run and
## moves it only as the sequencer plays each event: counters never run ahead of the animation.

const PackSlotScene := preload("res://game/ui/pack_slot.tscn")

## Slot layout: one column per pack kind, the last centred at LAST_SLOT_X.
const SLOT_SPACING: int = 30
const LAST_SLOT_X: int = 158
const SLOT_Y: int = 292

var _run: RunState
var _sequencer: EventSequencer
var _slots: Dictionary[String, PackSlot] = {}
## The target a press started on, as [kind, part], or [] for none. A tap needs press and
## release on the same target.
var _pressed: Array = []
## The run as the events played so far have shown it.
var _shown_dust: int = 0
var _shown_light: int = 0
var _shown_packs: Dictionary[String, int] = {}
var _shown_loaded: String = ""

@onready var _dust: Label = $Dust
@onready var _light: Label = $Light
@onready var _slot_layer: Node2D = $Slots


func _ready() -> void:
	_dust.label_settings = HudText.primary(Palette.D0)
	_light.label_settings = HudText.secondary(Palette.C1)


func _unhandled_input(event: InputEvent) -> void:
	if handle_pointer(event):
		get_viewport().set_input_as_handled()


func setup(run: RunState, sequencer: EventSequencer) -> void:
	_run = run
	if _sequencer != sequencer:
		if _sequencer != null:
			_sequencer.event_played.disconnect(_on_event_played)
		_sequencer = sequencer
		_sequencer.event_played.connect(_on_event_played)
	_pressed = []
	_build_slots(run.balance.pack_kinds())
	refresh()


## Catches up with the run as it stands: dust, light, and each pack's count, cost and state.
func refresh() -> void:
	_shown_dust = _run.dust
	_shown_light = _run.light
	_shown_packs = _run.owned_packs.duplicate()
	_shown_loaded = _run.loaded_pack
	_show()


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
		_pressed = []
		return had
	if touch.pressed:
		_pressed = target
		return not target.is_empty()
	if _pressed.is_empty():
		return false
	if target == _pressed:
		_tap(target[0], target[1])
	_pressed = []
	return true


## The tap target under a screen point, as [kind, &"icon" or &"cost"], or [] for none.
func target_at(point: Vector2i) -> Array:
	for kind: String in _slots:
		var part: StringName = _slots[kind].target_at(point - Vector2i(_slots[kind].position))
		if part != &"":
			return [kind, part]
	return []


func _tap(kind: String, part: StringName) -> void:
	var done: bool
	if part == &"icon":
		done = _run.load_pack(kind) or _run.buy(kind)
	else:
		done = _run.buy(kind)
	if not done:
		_slots[kind].nudge()


func _on_event_played(event: EventSequencer.RunEvent) -> void:
	match event.type:
		&"pack_bought":
			_shown_packs[event.args[0]] = _shown_packs.get(event.args[0], 0) + 1
			_shown_dust = event.args[1]
		&"pack_loaded":
			_shown_loaded = event.args[0]
		&"pack_launched":
			_shown_packs[event.args[0]] = _shown_packs.get(event.args[0], 0) - 1
		&"big_bang_started":
			_shown_dust += event.args[2]
		&"combo_collected":
			_shown_dust += event.args[2]
			_shown_light += event.args[3]
		_:
			return
	_show()


## The loaded marker needs a pack left to show: RunState empties the launcher without a signal
## when the last pack flies, like the launcher's rest pack. Costs light up against the shown dust.
func _show() -> void:
	_dust.text = "%d" % _shown_dust
	_light.text = "%d/%d" % [_shown_light, _run.balance.sun_target]
	for kind: String in _slots:
		var count: int = _shown_packs.get(kind, 0)
		var cost: int = _run.balance.packs[kind].cost
		_slots[kind].show_pack(count, cost, _shown_dust >= cost, _shown_loaded == kind and count > 0)


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
		_slots[kinds[i]] = pack_slot
