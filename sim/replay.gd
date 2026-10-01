class_name Replay
extends RefCounted
## Looking back at a finished run: what each villager said at any moment, how a word
## spread, and "what if" reruns. Reruns are exact because the sim is deterministic:
## the same seed plus the same nudges at the same ticks give the same town.


## The word a villager used for a concept at a given tick (null-safe for helpers who arrived later).
static func variant_at(st: SimState, id: int, concept: String, tick: int) -> String:
	var start: Dictionary = st.initial_variants.get(id, {})
	var word: String = start.get(concept, st.concepts[concept][0])
	for a in st.adoptions:
		if int(a["tick"]) > tick:
			break
		if int(a["id"]) == id and a["concept"] == concept:
			word = a["to"]
	return word


## Share of residents (optionally one home-language group) using a word at a given tick.
static func share_at(st: SimState, concept: String, word: String, tick: int, group: String = "") -> float:
	var total := 0
	var n := 0
	for v: Villager in st.residents():
		if group != "" and v.home_lang != group:
			continue
		total += 1
		if variant_at(st, v.id, concept, tick) == word:
			n += 1
	return 0.0 if total == 0 else float(n) / total


## First week a word went from under half the town to at least half, or -1.
static func tipping_week(st: SimState, word: String = "pop") -> int:
	var key := MetricsSystem.share_key(word)
	if st.history.is_empty() or float(st.history[0].get(key, 0.0)) >= 0.5:
		return -1
	for snap in st.history:
		if float(snap.get(key, 0.0)) >= 0.5:
			return int(snap["week"])
	return -1


## Which place each sign "voice" belongs to (signs have negative source ids).
static func sign_places(st: SimState) -> Dictionary:
	var out := {}
	for pl: Place in st.places:
		for sgn in pl.signs:
			out[int(sgn["source"])] = pl.id
	return out


static func source_name(st: SimState, source: int, signs: Dictionary) -> String:
	if source < 0:
		if signs.has(source):
			return "a sign at the %s" % st.place_by_id[signs[source]].title
		return "a sign"
	if st.by_id.has(source):
		return st.by_id[source].display_name
	return "someone"


## Plain-language list: "Ava, Joe, and a sign at the Market".
static func join_names(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	if names.size() == 2:
		return "%s and %s" % names
	return ", ".join(names.slice(0, names.size() - 1)) + ", and " + str(names[-1])


static func describe_adoption(st: SimState, a: Dictionary, signs: Dictionary) -> String:
	var names: Array = []
	for s in a["sources"]:
		names.append(source_name(st, int(s), signs))
	return "%s switched to \"%s\" after hearing it from %s." % [st.by_id[a["id"]].display_name, a["to"], join_names(names)]


static func describe_nudge(st: SimState, entry: Dictionary) -> String:
	var args: Dictionary = entry["args"]
	var wk := int(entry["tick"]) / SimState.TICKS_PER_WEEK + 1
	var text := ""
	match entry["nudge"]:
		"build":
			text = "Opened the %s" % st.place_by_id[int(args["place"])].title
		"event":
			var kind := "Heritage nights" if args.get("theme", "mixer") == "heritage" else "Mixer events"
			text = "%s at the %s" % [kind, st.place_by_id[int(args["place"])].title]
		"helper":
			text = "Hired a bilingual helper"
		"introduce":
			text = "Introduced %s and %s" % [st.by_id[int(args["a"])].display_name, st.by_id[int(args["b"])].display_name]
		"signage":
			text = "Sign saying \"%s\" at the %s" % [args["variant"], st.place_by_id[int(args["place"])].title]
		_:
			text = str(entry["nudge"])
	return "Week %d: %s" % [wk, text]


## Replays a run from its seed and nudge log, skipping one nudge (or none with -1),
## stopping at end_tick (or the end of the year with -1), the same moment the real game ended.
## Returns {state, failed}: failed counts later nudges that could not happen without the skipped one.
static func rerun(seed_value: int, nudge_log: Array, skip_index: int = -1, end_tick: int = -1) -> Dictionary:
	var st := ScenarioV0.build(seed_value)
	var mgr := TickManager.new(st)
	var i := 0
	var failed := 0
	var limit := SimState.TICKS_PER_SEASON * SimState.SEASONS
	if end_tick >= 0:
		limit = mini(limit, end_tick)
	while st.tick < limit:
		while i < nudge_log.size() and int(nudge_log[i]["tick"]) == st.tick:
			if i != skip_index:
				if not apply_nudge(st, nudge_log[i]):
					failed += 1
			i += 1
		mgr.step()
	close_out(st)
	return {"state": st, "failed": failed}


## Takes a final reading if the run stopped partway through a week (the game does the same).
static func close_out(st: SimState) -> void:
	if st.history.is_empty() or int(st.history[-1].get("tick", -1)) != st.tick:
		st.history.append(MetricsSystem.snapshot(st))


static func apply_nudge(st: SimState, entry: Dictionary) -> bool:
	var args: Dictionary = entry["args"]
	match entry["nudge"]:
		"build":
			return NudgeSystem.build(st, int(args["place"]))
		"event":
			return NudgeSystem.event(st, int(args["place"]), str(args.get("theme", "mixer")))
		"helper":
			return NudgeSystem.helper(st)
		"introduce":
			return NudgeSystem.introduce(st, int(args["a"]), int(args["b"]))
		"signage":
			return NudgeSystem.signage(st, int(args["place"]), str(args["concept"]), str(args["variant"]))
	return false


# ---- "what if" with a luck check ----

const LUCK_RUNS := 3
const EFFECT_MIN := 0.03     # differences smaller than 3 points are treated as no change


## Seeds for "the same town with different luck". The roster never changes; only chance does.
static func luck_seeds(seed_value: int) -> Array:
	var out: Array = []
	for k in LUCK_RUNS:
		out.append(absi(hash([seed_value, "luck", k])) % 100000)
	return out


## Runs everything a what-if needs. Safe to call from a background thread.
## progress (if given) is an Array whose first element is bumped after each run.
static func whatif(seed_value: int, nudge_log: Array, skip: int, end_tick: int, progress: Array = []) -> Dictionary:
	var this_without := rerun(seed_value, nudge_log, skip, end_tick)
	_bump(progress)
	var pairs: Array = []
	for s in luck_seeds(seed_value):
		var with_it: SimState = rerun(s, nudge_log, -1, end_tick)["state"]
		_bump(progress)
		var without_it: SimState = rerun(s, nudge_log, skip, end_tick)["state"]
		_bump(progress)
		pairs.append([with_it.history[-1], without_it.history[-1]])
	return {"without": this_without["state"].history[-1], "failed": this_without["failed"], "pairs": pairs}


static func _bump(progress: Array) -> void:
	if not progress.is_empty():
		progress[0] += 1


## For each outcome: the difference the nudge made in this town, the average difference
## across this town plus the luck runs, and whether the effect is consistent.
## verdict: "real" (same direction in nearly every run), "luck" (only in some runs), or "none".
static func judge(real: Dictionary, result: Dictionary) -> Array:
	var out: Array = []
	var keys: Array = MetricsSystem.OUTCOMES + MetricsSystem.HIDDEN
	for k in real:
		if str(k).begins_with("share:"):
			keys.append(k)
	for k in keys:
		var here := float(real[k]) - float(result["without"][k])
		var diffs: Array = [here]
		for pair in result["pairs"]:
			diffs.append(float(pair[0][k]) - float(pair[1][k]))
		var mean := 0.0
		for d in diffs:
			mean += d
		mean /= diffs.size()
		var agree := 0
		for d in diffs:
			if absf(d) >= EFFECT_MIN * 0.5 and signf(d) == signf(mean):
				agree += 1
		var verdict := "none"
		if absf(mean) >= EFFECT_MIN and agree >= diffs.size() - 1:
			verdict = "real"
		elif absf(here) >= EFFECT_MIN or absf(mean) >= EFFECT_MIN:
			verdict = "luck"
		var lower_better: bool = k in MetricsSystem.HIDDEN
		out.append({
			"key": k, "here": here, "mean": mean, "agree": agree, "runs": diffs.size(),
			"verdict": verdict, "helped": (mean < 0) if lower_better else (mean > 0),
		})
	out.sort_custom(func(x, y): return absf(x["mean"]) > absf(y["mean"]))
	return out
