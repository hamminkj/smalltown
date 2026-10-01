# Small Town: Godot Project Plan v0.1

Target: Godot 4.x, GDScript. Companion to `design-spec.md`.

## 1. Architecture principle

**The simulation is pure logic with no scene dependencies.** Rendering reads from it; it never reads from rendering. This buys you three things:

- **Headless batch runs.** Tune numbers by simulating hundreds of towns from the command line and reading a CSV, instead of watching one town at a time.
- **Deterministic replays.** A seed plus a nudge log recreates any run exactly.
- **Easy UI changes.** You can redo the map view without touching the sim.

## 2. Folder structure

```
res://
  project.godot
  autoload/
    event_bus.gd          # global signals (tick, nudge_applied, season_ended)
    game_session.gd       # holds current SimState, charter, seed
  data/
    villager_data.gd      # Resource
    tie_data.gd           # Resource
    location_data.gd      # Resource
    concept_data.gd       # Resource
    nudge_data.gd         # Resource
    charter_data.gd       # Resource
    scenario_data.gd      # Resource (bundles all of the above)
    scenarios/
      prototype_v0.tres
  sim/
    sim_state.gd          # RefCounted: all villagers, ties, locations, tick, rng
    tick_manager.gd       # runs the loop
    movement_system.gd
    conversation_system.gd
    contagion_system.gd
    decay_system.gd
    rewiring_system.gd
    nudge_system.gd
    metrics_system.gd
    event_log.gd          # records conversations, adoptions, nudges for replay
  ui/
    charter_picker.tscn
    dashboard.tscn
    nudge_panel.tscn
    replay_view.tscn
    end_report.tscn
  world/
    town_map.tscn
    villager_view.tscn
    location_view.tscn
  tests/
    batch_run.gd          # headless tuning runs
```

## 3. Core data classes (sketch)

```gdscript
# data/villager_data.gd
class_name VillagerData
extends Resource

enum Stage { CHILD, ADULT, ELDER }

@export var id: int
@export var display_name: String
@export var stage: Stage
@export var household_id: int
@export var job_id: int = -1
@export var openness: float = 0.5
@export var shyness: float = 0.5
@export var adoption_threshold: int = 2
@export var proficiency: Dictionary = {}   # language_id -> float
@export var domain_use: Dictionary = {}    # domain -> {language_id: float}
@export var variant_pref: Dictionary = {}  # concept_id -> variant_id
@export var is_broker: bool = false

# runtime state (not saved in scenario files)
var burnout: float = 0.0
var exposures: Array = []   # [{concept, variant, source, tick}]
var schedule: Array = []    # location id per slot, rebuilt daily

static func mutual(a: VillagerData, b: VillagerData) -> float:
	var best := 0.0
	for lang in a.proficiency:
		if b.proficiency.has(lang):
			best = maxf(best, minf(a.proficiency[lang], b.proficiency[lang]))
	return best
```

```gdscript
# data/tie_data.gd
class_name TieData
extends Resource

enum Kind { FAMILY, WORK, NEIGHBOR, SCHOOL }

@export var a: int
@export var b: int
@export var kind: Kind
@export var w: float = 0.2      # tie strength
var s: float = 0.5              # recent success rate
var last_contact_tick: int = 0
```

```gdscript
# data/charter_data.gd
class_name CharterData
extends Resource

@export var title: String
# metric name -> weight; chosen metrics are shown on the dashboard
@export var weights: Dictionary = {
	"job_access": 0.0, "neighbor_trust": 0.0, "kids_school": 0.0,
	"elder_connection": 0.0, "economic_vitality": 0.0, "heritage_vitality": 0.0,
}
```

## 4. Tick manager (sketch)

```gdscript
# sim/tick_manager.gd
class_name TickManager
extends RefCounted

const TICKS_PER_WEEK := 28

var state: SimState

func _init(s: SimState) -> void:
	state = s

func step() -> void:
	state.tick += 1
	NudgeSystem.apply_active(state)
	MovementSystem.run(state)
	var talks: Array = ConversationSystem.run(state)
	ContagionSystem.run(state, talks)
	DecaySystem.run(state)
	if state.tick % TICKS_PER_WEEK == 0:
		RewiringSystem.run(state)
		MetricsSystem.sample_weekly(state)
	state.log.record_tick(state.tick, talks)
	EventBus.tick_done.emit(state.tick)
```

Systems are `static` functions on `RefCounted` classes that take `SimState`. That keeps them testable without scenes.

## 5. Determinism

- `SimState` owns one `RandomNumberGenerator`, seeded from the scenario seed.
- Never call global `randf()` inside the sim.
- Player nudges are logged as `(tick, nudge_id, params)`. Replay = seed + nudge log.

## 6. Headless batch runner (for tuning)

```gdscript
# tests/batch_run.gd
extends SceneTree

func _init() -> void:
	var scenario: ScenarioData = load("res://data/scenarios/prototype_v0.tres")
	var out := FileAccess.open("res://tests/results.csv", FileAccess.WRITE)
	out.store_line("seed,week,job_access,trust,kids,elders,economy,heritage,segregation")
	for seed_value in range(200):
		var state := SimState.from_scenario(scenario, seed_value)
		var mgr := TickManager.new(state)
		for i in range(336):
			mgr.step()
			if state.tick % 28 == 0:
				var m := MetricsSystem.snapshot(state)
				out.store_line("%d,%d,%f,%f,%f,%f,%f,%f,%f" % [
					seed_value, state.tick / 28, m.job_access, m.trust, m.kids,
					m.elders, m.economy, m.heritage, m.segregation])
	quit()
```

Run with: `godot --headless --script res://tests/batch_run.gd`

Use the CSV to check the sanity targets in the spec (section 8): clusters persist with no nudges, adults reach 0.4 to 0.6 in the town language after one good season, variant adoption forms an S-curve.

## 7. Build milestones

1. **Headless core.** Villagers, locations, schedules, movement, conversation, proficiency gain. Print metrics. No visuals.
2. **Contagion.** Concepts, variants, exposure memory, distinct-source adoption. Verify the S-curve in the CSV.
3. **Decay and rewiring.** Check that heritage vitality drops without home use, and that clusters harden without intervention.
4. **Nudges.** Five nudge types with costs, durations, and a season budget. Log them for replay.
5. **Charters and metrics.** Charter picker, weighted dashboard, hidden metrics, end report.
6. **Town map view.** Simple top-down map, villagers as colored dots (color = home language), ties as lines (thickness = `w`).
7. **Replay view.** Trace one phrase's path through the network, with a timeline scrubber and a "what if" run using a different nudge log.

Rule of thumb: do not start milestone 6 until milestones 1 to 3 produce believable numbers in the CSV. Pretty maps hide bad dynamics.

## 8. Risks to watch

- **Single dominant strategy.** If "cafe in the center plus events" wins every charter, add costs (cafe crowds out the market, events cause fatigue) or make metrics conflict more.
- **Too-fast convergence.** Lower the gain rate, raise homophily.
- **Opaque cause and effect.** If players cannot tell why something happened, the replay view has to carry more explanation; add a "why" tag to every adoption event (which sources, which tick).
- **Performance.** 30 villagers is trivial. If you scale to 300 or more, avoid all-pairs checks inside a location; sample partners instead.
