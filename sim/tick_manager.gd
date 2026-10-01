class_name TickManager
extends RefCounted
## Runs one tick of the simulation in a fixed order.

var state: SimState
var last_talks: Array = []


func _init(s: SimState) -> void:
	state = s
	if state.history.is_empty():
		state.history.append(MetricsSystem.snapshot(state))


## Advances one time slot. Returns true when a season just ended.
func step() -> bool:
	var st := state
	MovementSystem.run(st)
	last_talks = ConversationSystem.run(st)
	ContagionSystem.run(st)
	DecaySystem.run(st)
	st.tick += 1
	var season_ended := false
	if st.tick % SimState.TICKS_PER_WEEK == 0:
		RewiringSystem.run(st)
		MetricsSystem.sample_weekly(st)
		_word_news(st)
	if st.tick % SimState.TICKS_PER_SEASON == 0:
		NudgeSystem.new_season(st)
		season_ended = true
	return season_ended


## Headlines when a newer word crosses a quarter, half, or three quarters of the town.
static func _word_news(st: SimState) -> void:
	const BANDS := ["a few people", "a quarter of the town", "half the town", "three quarters of the town"]
	for c in st.concepts:
		for word in st.concepts[c].slice(1):
			var share := MetricsSystem.variant_share(st, c, word)
			var band := mini(3, int(floor(share * 4.0 + 0.0001)))
			var old: int = st.word_band.get(word, 0)
			if band > old:
				st.log_event("\"%s\" has spread to %s." % [word, BANDS[band]])
			elif band < old:
				st.log_event("\"%s\" is fading; now under %s." % [word, BANDS[old]])
			st.word_band[word] = band
