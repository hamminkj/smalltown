class_name NudgeSystem
extends RefCounted
## The player's toolkit. Each nudge costs budget points and is logged for replays.

const COSTS := {
	"build": 3,
	"event": 2,
	"helper": 2,
	"introduce": 1,
	"signage": 1,
}

const HELPER_NAMES := ["Ines", "Tomas", "Mei", "Farid"]


static func can_afford(st: SimState, nudge: String) -> bool:
	return st.budget >= COSTS[nudge]


static func _spend(st: SimState, nudge: String, args: Dictionary) -> bool:
	if not can_afford(st, nudge):
		return false
	st.budget -= COSTS[nudge]
	st.nudge_log.append({"tick": st.tick, "nudge": nudge, "args": args})
	return true


static func build(st: SimState, place_id: int) -> bool:
	var pl: Place = st.place_by_id[place_id]
	if pl.built or not pl.buildable:
		return false
	if not _spend(st, "build", {"place": place_id}):
		return false
	pl.built = true
	st.log_event("The %s opens its doors." % pl.title)
	return true


## theme "mixer": everyone mingles in the town language.
## theme "heritage": a heritage-language night; anyone who can follow speaks the heritage language.
static func event(st: SimState, place_id: int, theme: String = "mixer") -> bool:
	var pl: Place = st.place_by_id[place_id]
	if not pl.built or pl.kind != "public" or pl.has_event(st.tick):
		return false
	if not _spend(st, "event", {"place": place_id, "theme": theme}):
		return false
	pl.event_until = st.tick + SimState.TICKS_PER_WEEK
	pl.event_theme = theme
	# Reroll today's remaining plans so the event draws people right away.
	for v: Villager in st.villagers:
		v.schedule = MovementSystem.roll_day(st, v)
	if theme == "heritage":
		st.log_event("A week of heritage-language nights begins at the %s." % pl.title)
	else:
		st.log_event("A week of mixer events begins at the %s." % pl.title)
	return true


static func helper(st: SimState) -> bool:
	if st.helper_count >= HELPER_NAMES.size():
		return false
	if not _spend(st, "helper", {}):
		return false
	var room: Place = st.place_by_id[SimState.COMMUNITY_ROOM]
	room.built = true
	var v := Villager.new()
	v.id = 100 + st.helper_count
	v.display_name = HELPER_NAMES[st.helper_count]
	v.stage = Villager.Stage.ADULT
	v.household = SimState.COMMUNITY_ROOM
	v.home_place = SimState.COMMUNITY_ROOM
	v.job = "Bilingual helper"
	v.openness = 0.9
	v.shyness = 0.1
	v.threshold = 99
	v.is_helper = true
	v.home_lang = "B"
	v.set_prof("T", 0.9)
	v.set_prof("H", 0.9)
	v.last_used = {"T": st.tick, "H": st.tick}
	for c in st.concepts:
		v.variant[c] = "soda"
	st.add_villager(v)
	v.schedule = MovementSystem.roll_day(st, v)
	st.helper_count += 1
	st.log_event("%s joins the town as a bilingual helper." % v.display_name)
	return true


static func introduce(st: SimState, a_id: int, b_id: int) -> bool:
	if a_id == b_id or not st.by_id.has(a_id) or not st.by_id.has(b_id):
		return false
	if not _spend(st, "introduce", {"a": a_id, "b": b_id}):
		return false
	st.add_tie(a_id, b_id, Tie.Kind.MET, 0.4)
	st.pending_meets.append([a_id, b_id])
	st.log_event("You introduce %s to %s." % [st.by_id[a_id].display_name, st.by_id[b_id].display_name])
	return true


static func signage(st: SimState, place_id: int, concept: String, variant_name: String) -> bool:
	var pl: Place = st.place_by_id[place_id]
	if not pl.built or pl.kind != "public":
		return false
	if not _spend(st, "signage", {"place": place_id, "concept": concept, "variant": variant_name}):
		return false
	pl.signs.append({"concept": concept, "variant": variant_name, "source": st.next_sign_source})
	st.next_sign_source -= 1
	st.log_event("A sign saying \"%s\" goes up at the %s." % [variant_name, pl.title])
	return true


static func new_season(st: SimState) -> void:
	st.budget = SimState.SEASON_BUDGET
