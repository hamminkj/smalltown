extends Node
## Holds the current run between screens. The sim itself never reads this.

const PRESETS := {
	"Jobs First": {"job_access": 5, "economic_vitality": 3, "kids_school": 2},
	"Families and Elders": {"elder_connection": 5, "heritage_vitality": 3, "kids_school": 2},
	"Living Heritage": {"heritage_vitality": 5, "heritage_word": 4, "elder_connection": 3, "neighbor_trust": 2},
	"Good Neighbors": {"neighbor_trust": 5, "economic_vitality": 2, "elder_connection": 2, "job_access": 1},
}

var charter_title := "Jobs First"
var weights := {}
var seed_value := 0
var state: SimState = null
var manager: TickManager = null


func _ready() -> void:
	set_charter("Jobs First", PRESETS["Jobs First"])
	randomize()
	seed_value = randi() % 100000


func set_charter(title: String, w: Dictionary) -> void:
	charter_title = title
	weights = {}
	for k in MetricsSystem.OUTCOMES:
		weights[k] = int(w.get(k, 0))


func visible_metrics() -> Array:
	var out: Array = []
	for k in MetricsSystem.OUTCOMES:
		if int(weights.get(k, 0)) > 0:
			out.append(k)
	return out


func start_run() -> void:
	state = ScenarioV0.build(seed_value)
	manager = TickManager.new(state)


func current_score() -> float:
	if state == null or state.history.is_empty():
		return 0.0
	return MetricsSystem.score(state.history[-1], weights)
