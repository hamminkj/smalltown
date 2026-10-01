class_name Villager
extends RefCounted
## One person in the town. Pure data plus a few helpers; no scene dependencies.

enum Stage { CHILD, ADULT, ELDER }

var id: int
var display_name: String
var stage: int = Stage.ADULT
var household: int
var home_place: int
var job: String = ""
var workplace: int = -1
var job_req: float = 0.0
var is_vendor := false
var openness := 0.5
var shyness := 0.5
var threshold := 2
var committed := false          # never switches variants (seed speakers)

# Language state
var p := {"T": 0.0, "H": 0.0}   # proficiency per language
var peak := {"T": 0.0, "H": 0.0}
var last_used := {"T": 0, "H": 0}
var home_lang := "T"            # "T", "H", or "B" (bilingual helper)
var variant := {}               # concept -> variant name
var exposures: Array = []       # [{concept, variant, source, tick}]

# Daily life
var schedule: Array = [0, 0, 0, 0]
var location: int = 0
var met := {}                   # partner id -> [talks, successes] since last rewire

# Helper (broker) state
var is_helper := false
var burnout := 0.0
var withdrawn_until := -1


func age_mult() -> float:
	match stage:
		Stage.CHILD:
			return 1.5
		Stage.ELDER:
			return 0.6
	return 1.0


func stage_name() -> String:
	match stage:
		Stage.CHILD:
			return "Child"
		Stage.ELDER:
			return "Elder"
	return "Adult"


func set_prof(lang: String, value: float) -> void:
	p[lang] = clampf(value, 0.0, 1.0)
	if p[lang] > peak[lang]:
		peak[lang] = p[lang]


## Mutual intelligibility: the best shared language level between two people.
static func mutual(a: Villager, b: Villager) -> float:
	var best := 0.0
	for lang in a.p:
		best = maxf(best, minf(a.p[lang], b.p[lang]))
	return best
