class_name Encounter
extends RefCounted
## One guided encounter with an Orion threat (#93, playtest: a first-time player understood none of
## them). The stage that introduces a threat plays it once, the first time (App saves it): it only
## guides, nothing is gated. Pure rules; RunState tells it what happened and announces each step
## (encounter_step), and the HUD's guide shows it.
## - MARK (the Tail): after Orion's first mark, the guide shows a link that saves the marked star.
##   The next successful link ends it, saved or shot (the player sees the arrow take it).
## - VOLLEY (the Body): from the start (after the intro volley), the guide points at the countdown
##   and the arrows hanging overhead and says what they do. The first real volley ends it.
## - HUNT (the Heart): after the intro's demo strike, the guide points at a spot outside the circle to
##   launch at. The first launch ends it, inside the circle or out (a launch inside shows the strike).

enum Threat { MARK, VOLLEY, HUNT }
enum Step { WAITING, GUIDING, DONE }

var threat: Threat
var step: Step = Step.WAITING


func _init(p_threat: Threat) -> void:
	threat = p_threat


## The threat a map introduces (its stage's encounter), or -1: the stages that bring a threat with
## an intro. The Claws and the final bring them all, already met.
static func threat_of(map: StarMap) -> int:
	if map == null or not map.intros:
		return -1
	if map.hunt:
		return Threat.HUNT
	if map.volley != "":
		return Threat.VOLLEY
	if map.orion:
		return Threat.MARK
	return -1


## The threat's name, for the save and the logs.
static func threat_name(p_threat: int) -> String:
	return (Threat.keys()[p_threat] as String).to_lower()


func is_guiding() -> bool:
	return step == Step.GUIDING


func is_done() -> bool:
	return step == Step.DONE


## The stage is under way, its intro played: the volley's guide starts. Returns whether it moved on.
func opened() -> bool:
	return _guide_if(threat == Threat.VOLLEY)


## Orion marked a star. Returns whether it moved on (the mark's guide starts).
func marked() -> bool:
	return _guide_if(threat == Threat.MARK)


## Orion marked his hunting circle for a real launch (after the intro). Returns whether it moved on.
func area_marked() -> bool:
	return _guide_if(threat == Threat.HUNT)


## A successful link. Returns whether it ended the encounter (the mark's).
func linked() -> bool:
	return _end_if(threat == Threat.MARK)


## A real volley fell (not the intro's). Returns whether it ended the encounter.
func volley_fired() -> bool:
	return _end_if(threat == Threat.VOLLEY)


## The player launched. Returns whether it ended the encounter (the hunt's).
func launched() -> bool:
	return _end_if(threat == Threat.HUNT)


func _guide_if(matches: bool) -> bool:
	if not matches or step != Step.WAITING:
		return false
	step = Step.GUIDING
	return true


func _end_if(matches: bool) -> bool:
	if not matches or step != Step.GUIDING:
		return false
	step = Step.DONE
	return true
