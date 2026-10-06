# Chapters 2 and 3: ideas and prototype plan

**Status: proposal, 2026-10-06.** This records ideas from the chapter research and plans how to evaluate them. The user requested a plan; gameplay implementation, final themes, and tuning have not been approved. [design.md](design.md) remains the reference for the current game. The rules below are provisional design choices, not shipped behavior.

## Campaign direction

Give each chapter a new use for the existing launch-and-link controls. Preserve the anticipation of random packs, frequent tactile actions, and satisfying dust and light payouts.

| Chapter | Proposed identity | Main decision | Desired player reaction |
|---|---|---|---|
| 1: Scorpio | Protect stars from Orion | Which stars should I save before acting? | "I saved the star he was hunting." |
| 2: Aquarius | Arrange the sky through predictable movement | Link now, or launch to bring stars together? | "That launch made the combo possible." |
| 3: Gemini | Use paired landmarks to prepare another success | Which completion sets up the next one? | "That echo gave me the missing star." |

Aquarius and Gemini are working themes. Mechanics can be retained if the themes change. Part-stage names below are working labels, not claims about astronomical constellation subdivisions.

The baseline keeps three star sizes, exactly three stars per valid link, triples and mixed-size sequences, one unlit landmark per link, the two existing pack roles, dust, light, the Sun, and constellation completion. New chapters initially omit Orion's threats. No new currency, inventory, persistent upgrade, or run buff is proposed.

## Chapter 2: Aquarius

### Main mechanic: star currents

Visible current regions shift loose stars when a pack is launched. The sky stays still between actions, including while a link is traced. This changes placement without changing star sizes or destroying resources.

**Provisional prototype rules:**

- Both bursts of a red pack finish before movement resolves. A red pack triggers one current step, like a blue pack.
- All loose stars, including the new burst's stars, are eligible. Landmarks remain fixed.
- Determine field membership from a snapshot of positions before movement. Each eligible star moves once; entering another field does not trigger another step.
- Start with non-overlapping current regions and fixed directions. A star on the boundary counts as inside, using the same rule in preview and resolution.
- Displacement is an integer vector. Clamp destinations to the safe playable sky; no star leaves the screen.
- Resolve crowding deterministically with the existing scatter/spacing concepts and a stable star-ID order. Preview and execution must use the same placement function. Never merge stars or change their sizes to make room.
- Only a successful launch advances currents. Buying, loading, aiming, cancelling, and invalid links do not move them. Ordinary successful links do not move them either.
- Refresh legal links and hints after movement, then perform the normal loss check. With no affordable or owned launch and no legal link, there is no free current tick that rescues the run.

Example: two small stars lie beyond useful reach of a small landmark. Launching upstream shifts them closer while adding new stars. The player can now link the landmark with those stars.

**Presentation:** cool stepped ribbons and arrow shapes show flow; palette colours must come from the existing N/M ramps. Warm colours mark an actionable preview or useful destination. While aiming, preview exact destinations for existing stars and an uncertainty region for the unopened burst. Do not imply that unknown star sizes or scatter positions are guaranteed. Keep silhouettes, touch targets, and constellation strings readable.

**First playable experiment:** one current, one direction, a compact map, and one guided useful launch. Use ordinary packs after the demonstration. Test whether the player can then use the current deliberately without another prompt.

### Optional companion: gravity wells

Only explore wells if currents need another kind of decision. A well pulls nearby loose stars after a successful link. That gives launches and links distinct spatial effects.

- Resolve normal rewards, landmark lighting, and any Sun clear first.
- On a continuing run, pull remaining loose stars once from a position snapshot; landmarks stay fixed. A final completion skips the pulse.
- Use bounded integer displacement, stable spacing, and a preview of the affected stars while tracing a valid link.
- A well never consumes stars, grants a reward, or advances while the player waits.
- Start with one well and no overlapping influences. Keep more elaborate fields out of the first prototype.

Example: collecting a medium triple pulls two remaining small stars within reach of a small landmark. The combo pays normally and prepares another useful link.

The difficulty should come from choosing an action and anticipating its effect. Avoid continuous physics, stars escaping the sky, or movement timed to finger speed.

### Proposed stage progression

| Stage | Working label | Content and teaching goal |
|---|---|---|
| 1 | First Flow | One current helps the player reach a landmark; teach launch, movement, then link. |
| 2 | Forked Stream | Separate current regions serve different landmarks; choose which area to feed. |
| 3 | Gathering Pool | Introduce one gravity well if justified; otherwise deepen current layouts. |
| 4 | Confluence | Combine current and well timing, or combine established current layouts. |
| 5 | Return Flow | Test planning across a longer constellation using established rules. Direction reversal is a separate optional experiment, not required content. |
| 6 | Aquarius / Maelstrom | Finale built from mastered movement rules and deliberate placement; no additional mechanic required. |

Keep the finale objective as lighting the constellation. "Maelstrom" is an environmental encounter concept; a new enemy character or separate boss-health system is not required.

## Chapter 3: Gemini

### Main mechanic: twin echoes

Some landmarks have a visible partner. Lighting the first member of a pair sends a helpful ordinary sky star toward the still-unlit partner. It creates a finite opportunity for another link.

**Provisional prototype rules:**

- A pair emits once, when its first member becomes lit during the run. Pairs with a member already lit at the start are treated as spent; no opening free echo.
- The echo matches the receiving landmark's size. Prefer equal-size pairs in the introduction so the visual echo reads simply.
- The echo is an ordinary small, medium, or big star with normal rewards and no persistent special status. Its arrival effect identifies where it came from.
- Landing points sit near the receiving landmark and use deterministic safe placement, with clear spacing from the landmark and other stars. An echo never occupies the landmark's touch target.
- Direct combo lighting and Sun-triggered lighting both qualify. Resolve a Sun clear before delivering echoes generated by that action, so the arrival is useful rather than immediately erased.
- If both members become lit in the same action, emit nothing for that pair. Final completion takes priority over echo delivery.
- Echo arrival does not automatically collect a combo, light another landmark, or trigger another echo. The player makes the next link.
- Resolve pending arrivals before checking for remaining combos and loss. Echo placement must not consume the pack RNG stream.

Example: completing a small landmark sends a small star beside its unlit partner. One additional small sky star is enough to form a triple with that partner. A previously unhelpful small star elsewhere may now be worth saving or moving toward the pair.

**Presentation:** a pair has a distinctive dotted connection that cannot be mistaken for a completed gold constellation string. On completion, a pulse travels along it and the ordinary star appears with a brief arrival effect. During tracing, show the destination if that link would generate an echo. Avoid introducing another permanent selection ring or star colour.

**First playable experiment:** one pair, a visible echo landing point, and an ordinary link opportunity afterward. The player should understand that the arriving star can be linked without learning a new star type.

### Optional companion: paired resonance

An extra light payout rewards completing the two members of a pair on consecutive successful links. This introduces timing through player choices rather than a real-time deadline.

- A direct link that lights the first member primes its partner.
- If the next successful link directly lights that partner, award bonus light once for the pair, alongside normal rewards.
- Launches, purchases, loading, cancelled gestures, and invalid links preserve the opportunity. A different successful link expires it.
- Missing the opportunity never dims a completed landmark or removes progress.
- Sun-triggered lighting still generates echoes but does not start or satisfy resonance. This is a provisional distinction: the bonus rewards deliberate paired links and must be taught visibly.
- Apply earned bonus light before evaluating the Sun threshold. Preserve the existing rules for Sun overflow and final completion until a separate design decision changes them.
- A successful link settles the previous opportunity before potentially priming a different pair. There is only one pending opportunity; no stack of hidden bonuses.

Example: a useful dust triple is available, but collecting it would end the pending resonance. The player can instead spend a pack preparing the paired landmark for a larger light payout.

The Sun can clear saved stars when resonance fills it. Preview an imminent rekindle while tracing so the consequence is visible. Start without resonance and add it only if echoes leave room for a meaningful collect-now-or-prepare decision.

### Proposed stage progression

| Stage | Working label | Content and teaching goal |
|---|---|---|
| 1 | First Answer | One pair demonstrates an echo, then lets the player use it. |
| 2 | Twin Paths | Multiple pairs let the player choose which side to complete first. |
| 3 | In Harmony | Introduce resonance if justified; otherwise deepen echo placement choices. |
| 4 | Crossing Voices | Echo arrivals and existing stars prepare opportunities across different pairs. No additional star type. |
| 5 | Shared Light | Test the choice between immediate dust and a prepared paired payout. Without resonance, test completion order instead. |
| 6 | Gemini / The Twins | Finale combines established pair layouts, echo placement, and optional resonance. Keep the usual constellation objective. |

Do not require finishing both twins simultaneously, undo completed landmarks, or make all non-resonant links invalid. An unfinished pair remains completable even after its bonus opportunity expires.

## Build and evaluation order

Implement these steps only after a gameplay task is authorized. Each implementation topic gets its own branch and PR; this document does not create executable tasks or approve all optional ideas.

| Step | Deliverable | Evidence needed before continuing |
|---|---|---|
| A | Paper layouts for a current stage and an echo stage | Both offer a useful choice through existing controls; rules are expressible with a short demonstration. |
| B | Standalone current prototype with core tests and a minimal view | Preview matches movement; stars remain selectable; players intentionally use movement to make links. |
| C | Standalone echo prototype with core tests and a minimal view | Arrival and pairing are understood; echo use creates a choice; no repeated free-star loop. |
| D | Comparative spatial bot runs and touch playtests | Planning produces useful opportunities across varied seeds; results are not driven solely by extra resources or one scripted solution. |
| E | Decide keep, revise, or drop each main mechanic | Record observed misunderstandings and successful strategies. Do not build a whole chapter around an unproven prototype. |
| F | Minimal support for multiple chapter definitions, maps, and saved progress | Existing Scorpio saves and behavior remain compatible; chapter progress stays separate. |
| G | First two Aquarius stages, then remaining stages | Layout variation supports the mechanic. Test wells only if needed, and replace optional stages with layout challenges if dropped. |
| H | First two Gemini stages, then remaining stages | Pair order and echo placement stay readable. Test resonance only if needed. |
| I | Chapter charts, paintings, encounter feedback, and finales | Pixel and palette review, small-screen touch review, complete runs, and documented balance checks. |

Prototype effects behind explicit development-only access. Do not expose unfinished chapters through the normal campaign or unlock them in existing saves.

### Implementation boundaries

- `Chapter` currently fixes Scorpio's identity and stage list; `ChapterSelect` draws its chart and paintings. Generalize only the definitions and view inputs needed for an actual second chapter. Avoid a general effects framework or unrelated rename/refactor.
- `StarMap` already provides per-stage landmark layouts. Add chapter maps and explicit mechanic settings there; keep costs, chances, rewards, targets, displacement amounts, field radii, and other tuning exclusively in `game/config/balance.json`.
- `ProgressStore` already loads and saves by chapter ID. Preserve existing Scorpio records and tutorial/encounter flags. Campaign unlock conditions remain an open design decision.
- Pure typed GDScript classes decide movement, pairing, rewards, and loss; `RunState` owns action order. Views and the event sequencer animate past-tense events and never decide rules.
- Random streams remain injectable. Presentation, previews, demonstrations, and placement must not silently change future pack contents. Use integer coordinates and the existing pixel grid throughout.
- Keep the COMBOS table true to the base combinations. Show chapter effects through a replayable demonstration or compact help view; explain conditional bonus light where it becomes relevant.
- Begin with Big Bang disabled on these constellation prototypes, matching the current constellation-stage baseline. Restoring it needs a separate useful interaction with the new chapter objective.

### Checks that matter

| Area | Required coverage for implementation |
|---|---|
| Currents | Fixed landmarks; movement once per launch including red twin bursts; snapshot membership; bounds; stable crowding; preview equality; no movement on cancelled or invalid actions; new legal links recognized before loss. |
| Optional wells | Valid-link trigger only; fixed landmarks; one pulse; remaining stars after a Sun clear; completion priority; spacing and reachable-link checks after movement. |
| Echoes | One emission per eligible pair; ordinary star size and rewards; safe placement; starting-lit pairs; direct and Sun lighting; both members lit in one action; delivery after clear and before loss; no automatic links or emission loops. |
| Optional resonance | Consecutive successful direct links; launch/buy preservation; invalid links preserve state; unrelated links expire it; Sun lighting is excluded visibly; bonus counted once; final completion and Sun ordering. |
| Chapters | Unlock/replay behavior, separate progress, old-save compatibility, missing or malformed data, and unchanged Scorpio rules. |
| Presentation | 180x320 and taller layouts; selectable stars after movement; distinguishable field and pair cues; integer pixels; palette-only colours; labels rendered as text. |

The Python balance simulator currently ignores positions and link reach. It can evaluate resource economics after being extended for new rules, but cannot validate currents or spatial echo placement by itself. Supplement it with seeded bot runs through the actual GDScript core. Report simulator win rates whenever balance changes, and label which rules each measurement models.

Compare matched seeds with effects enabled and disabled. Separate ordinary greedy play from movement/pair-aware play, and compare blue-only, red-when-affordable, and deliberate mixed-pack strategies. Include map, seed range, run count, wins/losses, packs used, useful current moves, echoes used, and optional resonance bonuses. More wins alone do not prove the mechanic is interesting; inspect whether players make and understand different decisions.

Human playtests should capture first-use understanding, deliberate use after the demonstration, tracing refusals, crowding mistakes, time to choose an action, and the player's explanation of a surprising outcome. Desired win rates, chapter duration, and acceptable difficulty are still undecided. Define those targets after prototype evidence, then tune through the shared balance file.

## Decisions to revisit

| Decision | Proposed starting point | Still open |
|---|---|---|
| Themes | Aquarius, then Gemini | Keep these names and figures or choose alternatives. |
| Chapter structure | Five part stages plus a finale | Final layouts, part names, and landmark counts. |
| Main mechanics | Currents; one-time paired echoes | Keep only after prototype evidence. |
| Companion mechanics | Wells; resonance | Optional; neither is required to ship a chapter. |
| Echo fairness | Predictable size and placement; one emission per pair | How much reliable help is appropriate alongside random packs. |
| Sun interaction | Keep current clears/overflow; deliver new echoes after the clear | Whether this remains understandable and satisfying in Gemini. |
| Finale identity | Environmental Maelstrom; paired Twins encounter | Narrative, enemy art, and presentation, with no separate health currency. |
| Campaign unlocks | Separate progress per chapter | Whether later chapters require the previous finale or a different completion condition. |
| Difficulty | No numerical target yet | Playtest targets and resource tuning; no claimed win rates for unbuilt chapters. |

## Reserve ideas

| Idea | Why keep it | Why defer it |
|---|---|---|
| Wormholes | Deliver stars between separated regions. | Transport previews, arrival spacing, and portal-link reach need their own prototype. Start with star transport, not links through portals. |
| Triangle enclosure | Existing trios could activate a beacon inside their triangle. | Thin triangles and precise touch geometry may feel arbitrary. Needs a forgiving preview and a distinct rule for the closing edge. |
| Eclipse phases | A visible phase could reward different familiar combos. | Competes with resonance and adds another timing cue. Test as an alternative, not another required layer. |
| Transformation fields | Turn awkward sizes into useful ones through placement. | Changing silhouettes undermines recognition unless the result is previewed clearly. |
| Conducting strings | Completed constellation branches could route useful effects. | Requires rules for branching and effect destinations; better explored after paired echoes. |
| Rhythm / Lyra | Links and sound could support a musical chapter. | Real-time timing changes the current pace and accessibility; separate experiment. |
| Longer links, fourth size, buffs, upgrades | Potential later expansion. | Broader changes to rules, economy, tutorial, and UI; outside this proposal's baseline. |

## Research behind the proposal

These are references for mechanics and design methods, not evidence that the proposed chapters will succeed. The applications to Dust In Space are original design inferences.

| Primary source | Relevant observation | Proposed application |
|---|---|---|
| [Osmos: official game page](https://www.osmos-game.com/) | Attractors and repulsors vary spatial play. | Predictable fields create chapter variety through the same controls. |
| [Into the Breach: developer's game description](https://store.steampowered.com/app/590380/Into_the_Breach/) | Attacks are telegraphed before resolution. | Preview movement and action consequences before commitment. |
| [Grindstone: developer AMA](https://www.reddit.com/r/Grindstone/comments/i1a9e4/) | Bridge objects support larger chains; saving resources can improve later opportunities; layouts were also prototyped on paper grids. | Echoes create useful future setups; test layouts before chapter art. |
| [Peglin: developer's game description](https://store.steampowered.com/app/1296610/Peglin/) | Aiming interacts with crit, refresh, and bomb board features. | Visible regions make launch location more expressive. |
| [Two Dots: official square mechanic explanation](https://dots.helpshift.com/hc/en/3-two-dots/faq/382-why-does-the-game-prompt-me-to-make-squares/) | Closed squares and enclosure add effects to familiar linking. | Reserve triangle geometry as a separate experiment. |
| [Balatro: official FAQ](https://www.playbalatro.com/faq/) | Boss rounds restrict familiar hands. | Finales test established mechanics rather than require another system. |
| [Mini Metro: developer's game page](https://dinopoloclub.com/games/mini-metro/) | Players draw and revise routes between stations. | Reserve useful constellation strings for later exploration. |
| [Railbound: developer press kit](https://afterburn.games/press/sheet.php?p=railbound) | Tunnels and other route features vary connection puzzles. | Wormholes are a possible transport experiment. |
| [Luck be a Landlord: Questions and Danswers](https://blog.trampolinetales.com/questions-and-danswers/) | Early content deliberately carries less complexity. | Teach main mechanics before optional companions. |
| [Luck be a Landlord: Making Rules and Breaking Rules](https://blog.trampolinetales.com/making-rules-and-breaking-rules/) | Unclear exceptions can be reported as bugs even when implemented intentionally. | Keep chapter rules accessible and test Sun/resonance exceptions explicitly. |
