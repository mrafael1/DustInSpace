class_name Tutorial
extends RefCounted
## The guided first run (the Stinger, played for the first time): a few steps teach the loop by
## doing it, each allowing only its own action. The goal first (lighting every constellation star
## wins; a tap goes on). Launch a blue planet (scripted: one of each size, a sequence) and link its
## 3 stars by tapping each. Then the payout is shown as it lands: the dust it gave (dust buys
## planets), the light (it fills the Sun); each moves on by itself (or with a tap). Launch next to
## the constellation star to light next (scripted: two stars of its size and one other) and link it
## with two of them by dragging through. Launch the red planet the run started with (scripted: it
## splits in two with more big stars), spend dust on a planet, then play freely. Pure rules;
## RunState asks it what's allowed and tells it what happened, and announces each new step
## (tutorial_step).

enum Step { GOAL, LAUNCH, LINK, DUST, SUN, LAUNCH_NEAR, LIGHT, RED, BUY, DONE }
## How a step's link may be made: either way, by tapping each star, or by dragging through them.
enum LinkInput { ANY, TAP, DRAG }

## The near launch must be aimed within this many px of the landmark to light, so its stars land in
## reach of it. Tutorial layout, not balance.
const NEAR: int = 20
## The first pack: one star of each size, a sequence.
const FIRST_PACK: Array[int] = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG]
## The red planet's twin bursts, one after the other: more big stars than a blue one, with a big
## three across them.
const RED_PACK: Array[int] = [Star.Size.BIG, Star.Size.MEDIUM, Star.Size.BIG, Star.Size.BIG, Star.Size.SMALL, Star.Size.MEDIUM]

var step: Step = Step.GOAL
## The landmark the near launch aims at and the light step lights (-1 before then).
var landmark: int = -1


## Whether the telescope may aim in `at_step` (the launch steps and free play).
static func aims(at_step: Step) -> bool:
	return at_step in [Step.LAUNCH, Step.LAUNCH_NEAR, Step.RED, Step.DONE]


## Whether `at_step` only shows or tells something: a tap goes on, and nothing else is allowed.
static func is_info(at_step: Step) -> bool:
	return at_step == Step.GOAL or is_timed(at_step)


## Whether `at_step` shows the payout as it lands and goes on by itself (the guide's timer).
static func is_timed(at_step: Step) -> bool:
	return at_step == Step.DUST or at_step == Step.SUN


## How `at_step`'s link is made: the first link by tapping each star, the constellation star's by
## dragging through them, either way otherwise.
static func link_input(at_step: Step) -> LinkInput:
	match at_step:
		Step.LINK:
			return LinkInput.TAP
		Step.LIGHT:
			return LinkInput.DRAG
	return LinkInput.ANY


func is_done() -> bool:
	return step == Step.DONE


## The player tapped on (or the guide's timer ran out) through a showing step. Returns true if the
## step moved on.
func continue_info() -> bool:
	match step:
		Step.GOAL:
			step = Step.LAUNCH
		Step.DUST:
			step = Step.SUN
		Step.SUN:
			step = Step.LAUNCH_NEAR
		_:
			return false
	return true


## A launch at `target` is allowed: the launch steps, or the near launch close to its landmark (at
## `landmark_at`), or free play.
func allows_launch(target: Vector2i, landmark_at: Vector2i) -> bool:
	match step:
		Step.LAUNCH, Step.RED, Step.DONE:
			return true
		Step.LAUNCH_NEAR:
			return Vector2(target).distance_to(Vector2(landmark_at)) <= NEAR
	return false


func allows_link() -> bool:
	return step == Step.LINK or step == Step.LIGHT or step == Step.DONE


func allows_buy(kind: String) -> bool:
	return step == Step.DONE or (step == Step.BUY and kind == "blue")


func allows_load() -> bool:
	return step == Step.DONE


## The sizes the pack now launched opens into, `count` stars, or [] for a normal draw: the first
## pack is a sequence; the near pack two stars of `landmark_size` and one of another size; the red
## one RED_PACK.
func pack_sizes(count: int, landmark_size: int) -> Array[int]:
	var sizes: Array[int] = []
	match step:
		Step.LAUNCH:
			sizes.assign(FIRST_PACK)
		Step.LAUNCH_NEAR:
			sizes = [landmark_size, landmark_size, (landmark_size + 1) % 3]
		Step.RED:
			sizes.assign(RED_PACK)
		_:
			return sizes
	while sizes.size() < count:
		sizes.append(sizes[sizes.size() % 3])
	return sizes.slice(0, count)


## A pack was launched; `can_buy`: whether the dust buys a blue planet now. Returns true if the
## step moved on.
func launched(can_buy: bool) -> bool:
	match step:
		Step.LAUNCH:
			step = Step.LINK
		Step.LAUNCH_NEAR:
			step = Step.LIGHT
		Step.RED:
			step = Step.BUY if can_buy else Step.DONE
		_:
			return false
	return true


## A link was collected; `lit` says whether it lit a landmark. `next_landmark`: the landmark the near
## launch should aim at now; `has_red`: whether a red planet is owned to launch; `can_buy`: whether
## the dust buys a blue one. Returns true if the step moved on.
func linked(lit: bool, next_landmark: int, has_red: bool, can_buy: bool) -> bool:
	if step == Step.LINK:
		step = Step.DUST
		landmark = next_landmark
		return true
	if step == Step.LIGHT and lit:
		if has_red:
			step = Step.RED
		else:
			step = Step.BUY if can_buy else Step.DONE
		return true
	return false


## A pack was bought. Returns true if the step moved on.
func bought() -> bool:
	if step == Step.BUY:
		step = Step.DONE
		return true
	return false
