class_name MovementSystem
extends RefCounted
## Daily schedules and moving villagers to where their schedule says they are.

## Every villager draws exactly this many random numbers per day, whatever their plans.
## A nudge can change what the draws decide, but never shifts the luck of later draws.
const DRAWS_PER_DAY := 12


static func run(st: SimState) -> void:
	if st.slot() == 0:
		for v: Villager in st.villagers:
			v.schedule = roll_day(st, v, st.rng)
	var s := st.slot()
	for v: Villager in st.villagers:
		if v.is_helper and st.tick < v.withdrawn_until:
			v.location = v.home_place
		else:
			v.location = v.schedule[s]
	# Introductions: both people meet at the park this slot.
	for pair in st.pending_meets:
		for id in pair:
			if st.by_id.has(id):
				st.by_id[id].location = SimState.PARK


static func roll_day(st: SimState, v: Villager, r: RandomNumberGenerator) -> Array:
	var d: Array = []
	for i in DRAWS_PER_DAY:
		d.append(r.randf())
	var h := v.home_place
	var weekend := st.is_weekend()
	var sched: Array = [h, h, h, h]
	if v.is_helper:
		if weekend:
			sched = [h, SimState.MARKET, SimState.PARK, h]
		else:
			var rotation := [SimState.SCHOOL, SimState.CLINIC, SimState.PLANT]
			sched = [SimState.MARKET, rotation[st.day_of_week() % 3], SimState.MARKET, h]
	elif v.stage == Villager.Stage.CHILD:
		if weekend:
			sched = [h, _pick(d[0], 0.6, SimState.PARK, h), _pick(d[1], 0.4, SimState.PARK, h), h]
		else:
			sched = [SimState.SCHOOL, SimState.SCHOOL, _pick(d[0], 0.7, SimState.SCHOOL, SimState.PARK), h]
	elif v.stage == Villager.Stage.ELDER:
		var midday := SimState.PARK if d[0] < 0.4 else (SimState.MARKET if d[0] < 0.7 else h)
		sched = [h, midday, _pick(d[1], 0.3, SimState.PARK, h), h]
	elif v.is_vendor:
		if weekend:
			sched = [h, _pick(d[0], 0.6, SimState.MARKET, h), _pick(d[1], 0.6, SimState.MARKET, h), h]
		else:
			sched = [SimState.MARKET, SimState.MARKET, SimState.MARKET, h]
	elif v.workplace > 0 and not weekend:
		var wp := v.workplace
		sched = [wp, wp, _pick(d[0], 0.7, wp, SimState.MARKET), _pick(d[1], 0.8, h, SimState.PARK)]
	elif v.workplace < 0 and not weekend:
		sched = [h, _pick(d[0], 0.5, SimState.MARKET, h), _pick(d[1], 0.4, SimState.PARK, h), h]
	else:
		sched = [h, _pick(d[0], 0.5, SimState.MARKET, h), _pick(d[1], 0.3, SimState.PARK, h), h]

	# Free slots (at home or in the park, not mornings) can be pulled to events and shared spaces.
	# Draws 2 to 10: three per slot (event, cafe, laundromat).
	for i in [1, 2, 3]:
		var base: int = 2 + (i - 1) * 3
		if sched[i] != h and sched[i] != SimState.PARK:
			continue
		if v.stage == Villager.Stage.CHILD and i == 3:
			continue
		var event_place := _event_place(st, st.tick + i)
		if event_place >= 0 and d[base] < st.params["event_pull"]:
			sched[i] = event_place
			continue
		var k := 1
		for pid in [SimState.CAFE, SimState.LAUNDROMAT]:
			var sp: Place = st.place_by_id[pid]
			if sp.built and d[base + k] < st.params["shared_space_pull"]:
				sched[i] = pid
				break
			k += 1
	return sched


static func _event_place(st: SimState, tick: int) -> int:
	for pl: Place in st.places:
		if pl.kind == "public" and pl.built and pl.has_event(tick):
			return pl.id
	return -1


static func _pick(roll: float, chance: float, yes: int, no: int) -> int:
	return yes if roll < chance else no
