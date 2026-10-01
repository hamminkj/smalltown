class_name MovementSystem
extends RefCounted
## Daily schedules and moving villagers to where their schedule says they are.


static func run(st: SimState) -> void:
	if st.slot() == 0:
		for v: Villager in st.villagers:
			v.schedule = roll_day(st, v)
	var s := st.slot()
	for v: Villager in st.villagers:
		if v.is_helper and st.tick < v.withdrawn_until:
			v.location = v.home_place
		else:
			v.location = v.schedule[s]
	# introductions: both people meet at the park this slot
	for pair in st.pending_meets:
		for id in pair:
			if st.by_id.has(id):
				st.by_id[id].location = SimState.PARK


static func roll_day(st: SimState, v: Villager) -> Array:
	var r := st.rng
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
			sched = [h, _pick(r, 0.6, SimState.PARK, h), _pick(r, 0.4, SimState.PARK, h), h]
		else:
			sched = [SimState.SCHOOL, SimState.SCHOOL, _pick(r, 0.7, SimState.SCHOOL, SimState.PARK), h]
	elif v.stage == Villager.Stage.ELDER:
		var roll := r.randf()
		var midday := SimState.PARK if roll < 0.4 else (SimState.MARKET if roll < 0.7 else h)
		sched = [h, midday, _pick(r, 0.3, SimState.PARK, h), h]
	elif v.is_vendor:
		if weekend:
			sched = [h, _pick(r, 0.6, SimState.MARKET, h), _pick(r, 0.6, SimState.MARKET, h), h]
		else:
			sched = [SimState.MARKET, SimState.MARKET, SimState.MARKET, h]
	elif v.workplace > 0 and not weekend:
		var wp := v.workplace
		sched = [wp, wp, _pick(r, 0.7, wp, SimState.MARKET), _pick(r, 0.8, h, SimState.PARK)]
	elif v.workplace < 0 and not weekend:
		sched = [h, _pick(r, 0.5, SimState.MARKET, h), _pick(r, 0.4, SimState.PARK, h), h]
	else:
		sched = [h, _pick(r, 0.5, SimState.MARKET, h), _pick(r, 0.3, SimState.PARK, h), h]

	# Free slots (at home or in the park, not mornings) can be pulled to shared spaces and events.
	for i in [1, 2, 3]:
		if sched[i] != h and sched[i] != SimState.PARK:
			continue
		if v.stage == Villager.Stage.CHILD and i == 3:
			continue
		var pulled := false
		for pl: Place in st.places:
			if pl.kind == "public" and pl.built and pl.has_event(st.tick + i):
				if r.randf() < st.params["event_pull"]:
					sched[i] = pl.id
					pulled = true
					break
		if pulled:
			continue
		for pid in [SimState.CAFE, SimState.LAUNDROMAT]:
			var sp: Place = st.place_by_id[pid]
			if sp.built and r.randf() < st.params["shared_space_pull"]:
				sched[i] = pid
				break
	return sched


static func _pick(r: RandomNumberGenerator, chance: float, yes: int, no: int) -> int:
	return yes if r.randf() < chance else no
