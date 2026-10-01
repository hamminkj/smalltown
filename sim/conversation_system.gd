class_name ConversationSystem
extends RefCounted
## Pairs up co-located villagers and runs one conversation per pair.


static func run(st: SimState) -> Array:
	var talks: Array = []
	for t: Tie in st.ties.values():
		t.talked_this_tick = false

	var groups := {}
	for v: Villager in st.villagers:
		if not groups.has(v.location):
			groups[v.location] = []
		groups[v.location].append(v)

	# Introductions happen first.
	var already := {}
	for pair in st.pending_meets:
		if st.by_id.has(pair[0]) and st.by_id.has(pair[1]):
			var a: Villager = st.by_id[pair[0]]
			var b: Villager = st.by_id[pair[1]]
			talks.append(talk(st, a, b, st.place_by_id[SimState.PARK]))
			already[a.id] = already.get(a.id, 0) + 1
			already[b.id] = already.get(b.id, 0) + 1
	st.pending_meets.clear()

	var place_ids: Array = groups.keys()
	place_ids.sort()
	for pid in place_ids:
		var place: Place = st.place_by_id[pid]
		var rounds := 2 if place.has_event(st.tick) else 1
		for _r in rounds:
			var pool := st.shuffled(groups[pid], st.rng_talk)
			var used := already.duplicate() if _r == 0 else {}
			for v: Villager in pool:
				if _full(v, used):
					continue
				if st.rng_talk.randf() < v.shyness * st.params["shy_skip"]:
					continue
				var partner := _choose_partner(st, v, pool, used)
				if partner == null:
					continue
				used[v.id] = used.get(v.id, 0) + 1
				used[partner.id] = used.get(partner.id, 0) + 1
				talks.append(talk(st, v, partner, place))
	return talks


## Helpers can hold several conversations per time slot; everyone else holds one.
static func _full(v: Villager, used: Dictionary) -> bool:
	var cap := 3 if v.is_helper else 1
	return int(used.get(v.id, 0)) >= cap


static func _choose_partner(st: SimState, v: Villager, pool: Array, used: Dictionary) -> Villager:
	var cands: Array = []
	var weights: Array = []
	var total := 0.0
	for other: Villager in pool:
		if other == v or _full(other, used):
			continue
		var t := st.get_tie(v.id, other.id)
		var w := t.w if t != null else 0.0
		var homophily: float = st.params["homophily"]
		var weight := (0.3 + w) * (1.0 + homophily * Villager.mutual(v, other))
		# Learners seek out bilingual helpers.
		if other.is_helper and v.p["T"] < 0.6:
			weight *= 3.0
		cands.append(other)
		weights.append(weight)
		total += weight
	if cands.is_empty():
		return null
	var roll := st.rng_talk.randf() * total
	for i in cands.size():
		roll -= weights[i]
		if roll <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


static func choose_language(st: SimState, a: Villager, b: Villager, place: Place) -> String:
	var norm := place.norm_lang(st.tick)
	var heritage_event := place.has_event(st.tick) and place.event_theme == "heritage"
	if place.kind == "home" and place.home_lang == "":
		norm = a.home_lang
	var best_lang := norm
	var best_val := minf(a.p[norm], b.p[norm])
	for lang in a.p:
		var val := minf(a.p[lang], b.p[lang])
		if val > best_val + 0.05:
			best_val = val
			best_lang = lang
	# Children lean toward the town language when it is close enough.
	if heritage_event and minf(a.p["H"], b.p["H"]) >= 0.3:
		return "H"
	if best_lang != "T" and (a.stage == Villager.Stage.CHILD or b.stage == Villager.Stage.CHILD):
		if minf(a.p["T"], b.p["T"]) >= best_val - st.params["child_prestige"]:
			best_lang = "T"
	return best_lang


static func talk(st: SimState, a: Villager, b: Villager, place: Place) -> Dictionary:
	var lang := choose_language(st, a, b, place)
	var m := minf(a.p[lang], b.p[lang])
	var floor_p: float = st.params["gesture_floor"]
	var success := st.rng_talk.randf() < floor_p + (1.0 - floor_p) * m

	_learn(st, a, b, lang, success)
	_learn(st, b, a, lang, success)

	var t := st.get_tie(a.id, b.id)
	if t != null:
		t.talked_this_tick = true
		t.last_contact = st.tick
		if success:
			t.w = minf(1.0, t.w + st.params["w_gain"])
			t.s += st.params["s_step"] * (1.0 - t.s)
		else:
			t.s -= st.params["s_step"] * t.s
	_track_met(a, b.id, success)
	_track_met(b, a.id, success)

	# Helpers carry conversations with people still learning the town language.
	for pair in [[a, b], [b, a]]:
		var helper: Villager = pair[0]
		var other: Villager = pair[1]
		if helper.is_helper and not other.is_helper and other.p["T"] < 0.6:
			helper.burnout += st.params["burnout_gain"]
			if helper.burnout >= 1.0 and st.tick >= helper.withdrawn_until:
				helper.withdrawn_until = st.tick + SimState.TICKS_PER_WEEK
				helper.burnout = 0.5
				st.log_event("%s is burned out and stepping back for a week." % helper.display_name)

	if success:
		for c in st.concepts:
			a.hear(c, b.variant[c], b.id, st.tick)
			b.hear(c, a.variant[c], a.id, st.tick)

	# Weekly stats for metrics
	var ws := st.week_stats
	ws["talks"] += 1
	if a.home_lang != b.home_lang:
		ws["cross_talks"] += 1
	if place.id == SimState.MARKET and (a.is_vendor != b.is_vendor):
		ws["market_attempts"] += 1
		if success:
			ws["market_success"] += 1
	if place.kind == "home" and a.household == b.household and not a.is_helper:
		var hh := a.household
		ws["home_talks"][hh] = ws["home_talks"].get(hh, 0) + 1
		if lang == "H":
			ws["home_h"][hh] = ws["home_h"].get(hh, 0) + 1

	return {"a": a.id, "b": b.id, "lang": lang, "success": success, "place": place.id}


static func _learn(st: SimState, learner: Villager, partner: Villager, lang: String, success: bool) -> void:
	var cur: float = learner.p[lang]
	var model_gap := clampf(0.25 + (partner.p[lang] - cur), 0.25, 1.0)
	var gain: float = st.params["gain"] * (1.0 - cur) * learner.age_mult() * (0.5 + 0.5 * learner.openness) * model_gap
	if not success:
		gain *= st.params["failure_gain_mult"]
	learner.set_prof(lang, cur + gain)
	learner.last_used[lang] = st.tick


static func _track_met(v: Villager, other_id: int, success: bool) -> void:
	var rec: Array = v.met.get(other_id, [0, 0])
	rec[0] += 1
	if success:
		rec[1] += 1
	v.met[other_id] = rec
