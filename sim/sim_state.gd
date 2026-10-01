class_name SimState
extends RefCounted
## Everything about one run of the town. Systems read and write this; nothing here touches scenes.

const TICKS_PER_DAY := 4
const DAYS_PER_WEEK := 7
const TICKS_PER_WEEK := 28
const WEEKS_PER_SEASON := 12
const TICKS_PER_SEASON := 336
const SEASONS := 4
const SEASON_BUDGET := 4
const SLOT_NAMES := ["Morning", "Midday", "Afternoon", "Evening"]
const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

# Place ids (match the roster)
const PLANT := 11
const CLINIC := 12
const SCHOOL := 13
const MARKET := 14
const PARK := 15
const CAFE := 16
const LAUNDROMAT := 17
const COMMUNITY_ROOM := 18

## Tunable numbers. Every value here is a guess to calibrate by playtesting.
var params := {
	"gain": 0.008,                # proficiency gain rate per conversation (spec started at 0.02; too fast)
	"failure_gain_mult": 0.4,     # struggling still teaches a little
	"gesture_floor": 0.1,         # chance a conversation works with no shared language
	"homophily": 1.0,             # preference for easy conversation partners
	"child_prestige": 0.25,       # children lean toward the town language
	"shy_skip": 0.4,              # chance scale that shy villagers skip starting a talk
	"decay": 0.0005,              # proficiency loss per tick when unused
	"decay_after": 14,            # ticks unused before decay starts
	"decay_floor": 0.15,          # floor for anyone who once exceeded 0.6
	"exposure_window": 56,        # ticks an exposure counts toward adoption
	"switch_ratio": 1.0,          # new-word voices needed per voice for the current word (plus loyalty)
	"sign_notice": 0.15,          # chance a villager notices a sign on each visit
	"loyalty": 1.0,               # sources credited to your own current word (you hear yourself)
	"habit_ticks": 112,           # after switching words, a villager keeps the new word at least this long (4 weeks)
	"elder_extra_threshold": 1,   # elders need this many more distinct sources to switch
	"word_switch_level": 0.5,     # heritage proficiency needed to use the heritage word when speaking it
	"w_gain": 0.02,
	"s_step": 0.1,
	"w_idle": 0.001,
	"w_floor": 0.05,
	"rewire_chance": 0.1,
	"burnout_gain": 0.06,
	"burnout_recover": 0.08,      # per tick at home
	"shared_space_pull": 0.2,     # chance a free slot is spent at a built shared space
	"event_pull": 0.5,            # chance a free slot is spent at an active event
	"curious_pull": 0.3,          # heritage nights: share of the pull felt by non-speakers (times openness)
}

## Separate random streams per system, so a nudge that changes one system
## doesn't reshuffle the luck of all the others. That keeps "what if" replays fair.
var rng := RandomNumberGenerator.new()          # movement and schedules
var rng_talk := RandomNumberGenerator.new()     # pairing and conversation success
var rng_spread := RandomNumberGenerator.new()   # noticing signs
var rng_rewire := RandomNumberGenerator.new()   # weekly tie rewiring
var seed_value := 0
var tick := 0

var villagers: Array = []          # Array of Villager
var by_id := {}                    # id -> Villager
var ties := {}                     # key -> Tie
var adjacency := {}                # id -> {key: true}
var places: Array = []             # Array of Place
var place_by_id := {}              # id -> Place
## Things with competing names. The first word in each list is the starting default.
## "sabrel" is an invented word in the town's unnamed heritage language.
var concepts := {
	"fizzy drink": ["soda", "pop"],
	"stuffed flatbread": ["stuffed bread", "sabrel"],
}
## Which language each word belongs to.
var word_lang := {"soda": "T", "pop": "T", "stuffed bread": "T", "sabrel": "H"}
## How catchy each word is: each voice for it counts this much when deciding to switch.
var word_appeal := {"soda": 1.0, "pop": 1.4, "stuffed bread": 1.0, "sabrel": 1.0}

var budget := SEASON_BUDGET
var event_log: Array = []          # [{tick, text}]
var nudge_log: Array = []          # [{tick, nudge, args}] for replays
var adoptions: Array = []          # [{tick, id, concept, from, to, sources}]
var initial_variants := {}         # id -> {concept: variant} at the moment each villager arrived
var pending_meets: Array = []      # [[a, b]] introductions waiting to happen
var next_sign_source := -1
var helper_count := 0
var word_band := {}                # word -> last share band announced (0 to 3)

var week_stats := {}
var history: Array = []            # weekly metric snapshots


func _init() -> void:
	reset_week_stats()


# ---- time ----

func slot() -> int:
	return tick % TICKS_PER_DAY


func day_of_week() -> int:
	@warning_ignore("integer_division")
	return (tick / TICKS_PER_DAY) % DAYS_PER_WEEK


func week() -> int:
	@warning_ignore("integer_division")
	return tick / TICKS_PER_WEEK


func season() -> int:
	@warning_ignore("integer_division")
	return tick / TICKS_PER_SEASON


func is_weekend() -> bool:
	return day_of_week() >= 5


func is_finished() -> bool:
	return tick >= TICKS_PER_SEASON * SEASONS


func time_label() -> String:
	var wk: int = week() % WEEKS_PER_SEASON + 1
	return "Season %d, Week %d, %s %s" % [mini(season() + 1, SEASONS), wk, DAY_NAMES[day_of_week()], SLOT_NAMES[slot()]]


# ---- population ----

func add_villager(v: Villager) -> void:
	villagers.append(v)
	by_id[v.id] = v
	adjacency[v.id] = {}
	v.location = v.home_place
	initial_variants[v.id] = v.variant.duplicate()


func residents() -> Array:
	var out: Array = []
	for v: Villager in villagers:
		if not v.is_helper:
			out.append(v)
	return out


func add_place(pl: Place) -> void:
	places.append(pl)
	place_by_id[pl.id] = pl


# ---- ties ----

func get_tie(x: int, y: int) -> Tie:
	return ties.get(Tie.key(x, y), null)


func add_tie(x: int, y: int, kind: int, w: float) -> Tie:
	if x == y:
		return null
	var k := Tie.key(x, y)
	var existing: Tie = ties.get(k, null)
	if existing != null:
		if w > existing.w:
			existing.w = w
		if kind == Tie.Kind.FAMILY:
			existing.kind = kind
		return existing
	var t := Tie.new()
	t.a = mini(x, y)
	t.b = maxi(x, y)
	t.kind = kind
	t.w = w
	t.last_contact = tick
	ties[k] = t
	adjacency[t.a][k] = true
	adjacency[t.b][k] = true
	return t


func remove_tie(t: Tie) -> void:
	var k := Tie.key(t.a, t.b)
	ties.erase(k)
	adjacency[t.a].erase(k)
	adjacency[t.b].erase(k)


func ties_of(id: int) -> Array:
	var out: Array = []
	for k in adjacency[id]:
		out.append(ties[k])
	return out


# ---- misc ----

func set_seed(value: int) -> void:
	seed_value = value
	rng.seed = value
	rng_talk.seed = hash([value, "talk"])
	rng_spread.seed = hash([value, "spread"])
	rng_rewire.seed = hash([value, "rewire"])


func shuffled(arr: Array, r: RandomNumberGenerator) -> Array:
	var out := arr.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


## The word a speaker actually says for a concept in a conversation held in `lang`.
## Speaking the heritage language, you use the heritage word if you know the language well;
## speaking the town language, you use whichever word you prefer (so loanwords can travel).
func word_used(v: Villager, concept: String, lang: String) -> String:
	if lang != "T" and v.p.get(lang, 0.0) >= params["word_switch_level"]:
		for w in concepts[concept]:
			if word_lang.get(w, "T") == lang:
				return w
	return v.variant[concept]


func log_event(text: String) -> void:
	event_log.append({"tick": tick, "text": text})


func reset_week_stats() -> void:
	week_stats = {
		"market_attempts": 0,
		"market_success": 0,
		"home_talks": {},
		"home_h": {},
		"talks": 0,
		"cross_talks": 0,
	}
