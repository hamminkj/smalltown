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
	if st.tick % SimState.TICKS_PER_SEASON == 0:
		NudgeSystem.new_season(st)
		season_ended = true
	return season_ended
