class_name Tutorial
extends RefCounted
## The guided first run (the Stinger, played for the first time): a few steps teach the loop, each
## allowing only its own action. The goal first (lighting every constellation star wins; a tap goes
## on), then launch a pack (scripted: one of each size, a sequence), link its 3 stars, what links give
## (light and dust; a full Sun lights a star; a tap goes on), launch next to the constellation star
## to light next (scripted: two stars of its size and one other), link it with two of them, the two
## planets (blue, then red; a tap goes on each), spend dust on a planet, then play freely. Pure rules; RunState asks it what's allowed and tells it what
## happened, and announces each new step (tutorial_step).

enum Step { GOAL, LAUNCH, LINK, SUN, LAUNCH_NEAR, LIGHT, BLUE, RED, BUY, DONE }

## The near launch must be aimed within this many px of the landmark to light, so its stars land in
## reach of it. Tutorial layout, not balance.
const NEAR: int = 20
## The first pack: one star of each size, a sequence.
const FIRST_PACK: Array[int] = [Star.Size.SMALL, Star.Size.MEDIUM, Star.Size.BIG]

var step: Step = Step.GOAL
## The landmark the near launch aims at and the light step lights (-1 before then).
var landmark: int = -1
## Whether the dust bought a blue planet when the constellation star was lit: the planets' steps go
## on to the buy step, or straight to free play.
var _can_buy: bool = false


## Whether the telescope may aim in `at_step` (the launch steps and free play).
static func aims(at_step: Step) -> bool:
	return at_step == Step.LAUNCH or at_step == Step.LAUNCH_NEAR or at_step == Step.DONE


## Whether `at_step` only explains something: a tap goes on, and nothing else is allowed.
static func is_info(at_step: Step) -> bool:
	return at_step == Step.GOAL or at_step == Step.SUN or at_step == Step.BLUE or at_step == Step.RED


func is_done() -> bool:
	return step == Step.DONE


## The player tapped on through an explaining step. Returns true if the step moved on.
func continue_info() -> bool:
	if step == Step.GOAL:
		step = Step.LAUNCH
		return true
	if step == Step.SUN:
		step = Step.LAUNCH_NEAR
		return true
	if step == Step.BLUE:
		step = Step.RED
		return true
	if step == Step.RED:
		step = Step.BUY if _can_buy else Step.DONE
		return true
	return false


## A launch at `target` is allowed: the launch step, or the near launch close to its landmark (at
## `landmark_at`), or free play.
func allows_launch(target: Vector2i, landmark_at: Vector2i) -> bool:
	match step:
		Step.LAUNCH, Step.DONE:
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
## pack is a sequence; the near pack two stars of `landmark_size` and one of another size.
func pack_sizes(count: int, landmark_size: int) -> Array[int]:
	var sizes: Array[int] = []
	match step:
		Step.LAUNCH:
			sizes.assign(FIRST_PACK)
		Step.LAUNCH_NEAR:
			sizes = [landmark_size, landmark_size, (landmark_size + 1) % 3]
		_:
			return sizes
	while sizes.size() < count:
		sizes.append(sizes[sizes.size() % 3])
	return sizes.slice(0, count)


## A pack was launched. Returns true if the step moved on.
func launched() -> bool:
	if step == Step.LAUNCH:
		step = Step.LINK
		return true
	if step == Step.LAUNCH_NEAR:
		step = Step.LIGHT
		return true
	return false


## A link was collected; `lit` says whether it lit a landmark. `next_landmark`: the landmark the near
## launch should aim at now. Returns true if the step moved on.
func linked(lit: bool, next_landmark: int, can_buy: bool) -> bool:
	if step == Step.LINK:
		step = Step.SUN
		landmark = next_landmark
		return true
	if step == Step.LIGHT and lit:
		step = Step.BLUE
		_can_buy = can_buy
		return true
	return false


## A pack was bought. Returns true if the step moved on.
func bought() -> bool:
	if step == Step.BUY:
		step = Step.DONE
		return true
	return false
