# Small Town

A complex-systems game about how language moves through a community.

**Developed by Julianne Hammink**

![The town map mid-year](docs/screenshot-game.png)

You are the town's community connector. Thirty neighbors live here: some speak the town language at home, and some speak a heritage language. You can't teach anyone or tell anyone what to do. You can only **nudge**: open a place where people meet, hold an event, introduce two people, hire a bilingual helper, or put up a sign. Words, habits, and friendships spread on their own.

At the start you write a **town charter**: you give points to the outcomes your town cares about (jobs, neighbor trust, kids' school success, elder connection, economic vitality, heritage-language vitality). Those outcomes show on your dashboard. Everything else is tracked quietly and revealed in the end-of-year report, so you see what your strategy cost.

## Status

Playable prototype (v0.1). One town, one year (4 seasons of 12 weeks), two languages, one competing word pair ("soda" vs "pop").

## Running it

1. Install [Godot 4.4](https://godotengine.org/download) (standard version, not .NET).
2. Open Godot, choose **Import**, and select this folder's `project.godot`.
3. Press **F5** (Run Project).

### How to play

- **Pause / Play / Fast / Faster** control time. Each season gives you 4 nudge points.
- **Hover** over a dot to meet that villager and see their ties. **Click** two dots to pick them for an introduction.
- **Dots:** teal = heritage-language home, orange = town-language home, purple = bilingual helper. The colored ring around a dot shows how much of the *other* language that person has learned. A white center means they say "pop."
- **Gold lines** are strong friendships that cross language groups. Watch where they form.

| Nudge | Cost | What it does |
|---|---|---|
| Open the Cafe / Laundromat | 3 | A new shared space that pulls people in during free time |
| Week of events (Mixer) | 2 | Doubles conversations at a place and draws a crowd; mixing happens in the town language |
| Week of events (Heritage night) | 2 | Same crowd, but anyone who can follow speaks the heritage language |
| Bilingual helper | 2 | A helper who speaks both languages; learners seek them out, which wears them down |
| Introduction | 1 | Creates a tie between two people and has them meet at the park |
| Sign | 1 | A sign at a public place that counts as one more "voice" for a word |

## What's under the hood

The simulation is pure GDScript with no scene dependencies (`sim/`), so it runs headless and is deterministic: the same seed plus the same nudges give the same story.

Each time slot (4 per day):

1. **Move:** villagers follow daily schedules (school, work, market, park, home), plus pulls toward shared spaces and events.
2. **Pair:** people at the same place pick partners, weighted by tie strength and **homophily** (preferring easy conversations).
3. **Talk:** they use the language they share best, with place norms and children's lean toward the town language. Success depends on shared proficiency; both people learn, more when the partner is stronger.
4. **Adopt:** **complex contagion.** A villager switches words only after hearing the new one from enough *different* sources (2, or 3 if shy), compared against sources for their current word. Three "committed" speakers always say "pop."
5. **Decay:** unused languages fade slowly; unused ties weaken.
6. **Rewire (weekly):** the **adaptive network.** Some villagers drop a frustrating tie and keep an easy new one, so clusters harden unless you intervene.

Complex-systems features you can see in play: tipping points (one well-placed sign can flip the whole town's word), weak ties and brokers, homophily, path dependence, and delayed, noisy feedback (dashboard readings update weekly with a little survey noise).

## Project layout

```
autoload/game_session.gd   Current run, charter, and seed (shared between screens)
sim/                       The simulation (no scenes): state, scenario, systems, metrics
ui/                        Title, charter picker, game screen, end report, shared style
world/town_map.gd          Draws the town from the sim state
tests/batch_run.gd         Headless tuning runs, writes tests/output/results.csv
tests/smoke_test.gd        Loads every screen and plays a full year
tests/screenshots.gd       Renders each screen to tests/output/*.png
docs/                      Design spec, Godot plan, and starting roster
```

## Testing and tuning

From this folder (replace `godot` with your Godot executable path):

```
godot --headless --script res://tests/smoke_test.gd
godot --headless --script res://tests/batch_run.gd -- --seeds=20
godot --headless --script res://tests/batch_run.gd -- --seeds=10 --only=mixers --set=gain:0.01,homophily:1.5
```

`batch_run.gd` simulates many towns under three scripted strategies (no nudges, mixers, heritage care) and prints the average of every metric at the end of each season. All tunable numbers live in `params` at the top of `sim/sim_state.gd`.

Averages over 20 seeds at the end of the year (0 to 1):

| Strategy | Job access | Heritage vitality | Segregation | Fragility | Says "pop" |
|---|---|---|---|---|---|
| No nudges | 0.95 | 0.81 | 0.41 | 0.44 | 0.46 (patchy) |
| Mixers | 1.00 | 0.58 | 0.36 | 0.41 | 1.00 (tipped) |
| Heritage care | 0.96 | 0.84 | 0.46 | 0.48 | 0.10 |

No single strategy wins every charter, which is the point.

## Changes from the design spec (v0.1)

The starter numbers in `docs/design-spec.md` were guesses. Batch testing led to these changes:

- **Learning gain 0.02 → 0.008.** At 0.02, heritage-language adults reached 0.60 in the town language in one season with no nudges, so jobs never felt at risk.
- **Switch rule:** a new word needs at least half as many distinct sources as the current word (`switch_ratio` 0.5). With "must outnumber," the new word could never spread, even with help.
- **Committed speakers:** the three "pop" seeds never switch back, a committed minority.
- **Children's lean toward the town language** (`child_prestige`), which is what makes heritage vitality fall as parents learn the town language.
- **Heritage night** event theme, so players have a lever that supports the heritage language.
- **Helpers** can hold up to 3 conversations per time slot, and learners seek them out; otherwise they never felt any strain.
- **Fragility** is now the share of cross-group contact carried by the top two bridge people (the network-split version always read 0 in a town this connected).

## Not built yet

From `docs/godot-plan.md`: the replay view (trace one word's path, "what if" runs), a second concept and cross-language word pairs, a third language, saving scenarios as `.tres` resources, and sound.
