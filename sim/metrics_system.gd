class_name MetricsSystem
extends RefCounted
## Town outcomes, all on a 0 to 1 scale. Every metric is derived from proficiency, ties, and domain use.

const OUTCOMES := ["job_access", "neighbor_trust", "kids_school", "elder_connection", "economic_vitality", "heritage_vitality"]
const HIDDEN := ["segregation", "fragility", "helper_burnout"]

const LABELS := {
	"job_access": "Job access",
	"neighbor_trust": "Neighbor trust",
	"kids_school": "Kids' school success",
	"elder_connection": "Elder connection",
	"economic_vitality": "Economic vitality",
	"heritage_vitality": "Heritage language vitality",
	"segregation": "Segregation",
	"fragility": "Fragility",
	"helper_burnout": "Helper burnout",
}

const DESCRIPTIONS := {
	"job_access": "Working-age adults whose town language meets their job's needs.",
	"neighbor_trust": "Strength and ease of relationships; ties across groups count extra.",
	"kids_school": "Children's town language, plus a parent who can talk with the school.",
	"elder_connection": "How well elders can talk with their own families.",
	"economic_vitality": "Market trades that go smoothly.",
	"heritage_vitality": "The heritage language passing from parents to kids and used at home.",
	"segregation": "How much friendships stay inside one language group. Lower is better.",
	"fragility": "How much of the contact between language groups runs through just two people. Lower is better.",
	"helper_burnout": "Share of bilingual helpers near burnout. Lower is better.",
}


static func snapshot(st: SimState) -> Dictionary:
	return {
		"week": st.week(),
		"tick": st.tick,
		"job_access": job_access(st),
		"neighbor_trust": neighbor_trust(st),
		"kids_school": kids_school(st),
		"elder_connection": elder_connection(st),
		"economic_vitality": economic_vitality(st),
		"heritage_vitality": heritage_vitality(st),
		"segregation": segregation(st),
		"fragility": fragility(st),
		"helper_burnout": helper_burnout(st),
		"h_adults_t": mean_prof(st, "H", Villager.Stage.ADULT, "T"),
		"h_kids_h": mean_prof(st, "H", Villager.Stage.CHILD, "H"),
	}.merged(word_shares(st))


## Key for a word's share of the town ("" = everyone, "H" or "T" = one home-language group).
static func share_key(word: String, group: String = "") -> String:
	return "share:%s" % word if group == "" else "share:%s:%s" % [word, group]


## The readout keys for every word that competes with a default, in a stable order.
static func word_keys(st: SimState) -> Array:
	var out: Array = []
	for c in st.concepts:
		for w in st.concepts[c].slice(1):
			out.append(share_key(w))
			out.append(share_key(w, "H"))
			out.append(share_key(w, "T"))
	return out


static func word_label(key: String) -> String:
	var parts := key.split(":")
	var label := "Saying \"%s\"" % parts[1]
	if parts.size() > 2:
		label += " in heritage homes" if parts[2] == "H" else " in town homes"
	return label


static func sample_weekly(st: SimState) -> Dictionary:
	var snap := snapshot(st)
	st.history.append(snap)
	st.reset_week_stats()
	return snap


static func score(snap: Dictionary, weights: Dictionary) -> float:
	var total := 0.0
	var wsum := 0.0
	for k in weights:
		total += float(weights[k]) * float(snap.get(k, 0.0))
		wsum += float(weights[k])
	return 0.0 if wsum <= 0.0 else 100.0 * total / wsum


# ---- outcome metrics ----

static func job_access(st: SimState) -> float:
	var n := 0
	var ok := 0
	for v: Villager in st.residents():
		if v.stage != Villager.Stage.ADULT:
			continue
		n += 1
		if v.p["T"] >= v.job_req:
			ok += 1
	return 0.0 if n == 0 else float(ok) / n


static func neighbor_trust(st: SimState) -> float:
	var total := 0.0
	var wsum := 0.0
	for t: Tie in st.ties.values():
		var a: Villager = st.by_id[t.a]
		var b: Villager = st.by_id[t.b]
		var weight := 1.5 if a.home_lang != b.home_lang else 1.0
		total += weight * t.w * t.s
		wsum += weight
	return 0.0 if wsum == 0.0 else total / wsum


static func kids_school(st: SimState) -> float:
	var n := 0
	var total := 0.0
	for kid: Villager in st.residents():
		if kid.stage != Villager.Stage.CHILD:
			continue
		var parent_t := 0.0
		for v: Villager in st.residents():
			if v.household == kid.household and v.stage == Villager.Stage.ADULT:
				parent_t = maxf(parent_t, v.p["T"])
		total += 0.7 * kid.p["T"] + 0.3 * parent_t
		n += 1
	return 0.0 if n == 0 else total / n


static func elder_connection(st: SimState) -> float:
	var n := 0
	var total := 0.0
	for elder: Villager in st.residents():
		if elder.stage != Villager.Stage.ELDER:
			continue
		var fam := 0
		var m_sum := 0.0
		for v: Villager in st.residents():
			if v != elder and v.household == elder.household:
				m_sum += Villager.mutual(elder, v)
				fam += 1
		if fam > 0:
			total += m_sum / fam
			n += 1
	return 0.0 if n == 0 else total / n


static func economic_vitality(st: SimState) -> float:
	var ws := st.week_stats
	if ws["market_attempts"] == 0:
		if not st.history.is_empty():
			return st.history[-1]["economic_vitality"]
		# No trades yet: estimate from how well vendors and shoppers can talk.
		var n := 0
		var total := 0.0
		for vendor: Villager in st.residents():
			if not vendor.is_vendor:
				continue
			for v: Villager in st.residents():
				if not v.is_vendor:
					total += Villager.mutual(vendor, v)
					n += 1
		return 0.0 if n == 0 else total / n
	return float(ws["market_success"]) / float(ws["market_attempts"])


static func heritage_vitality(st: SimState) -> float:
	var homes := {}
	for v: Villager in st.residents():
		if v.home_lang == "H":
			homes[v.household] = true
	var n := 0
	var total := 0.0
	for hh in homes:
		var parent_h := 0.0
		var kid_h := 0.0
		for v: Villager in st.residents():
			if v.household != hh:
				continue
			if v.stage == Villager.Stage.CHILD:
				kid_h = maxf(kid_h, v.p["H"])
			elif v.stage == Villager.Stage.ADULT:
				parent_h = maxf(parent_h, v.p["H"])
		var talks: int = st.week_stats["home_talks"].get(hh, 0)
		var h_talks: int = st.week_stats["home_h"].get(hh, 0)
		var use := 1.0 if talks == 0 else float(h_talks) / talks
		total += minf(parent_h, kid_h) * use
		n += 1
	return 0.0 if n == 0 else total / n


# ---- hidden metrics ----

static func segregation(st: SimState) -> float:
	var counts := {}
	var res := st.residents()
	for v: Villager in res:
		counts[v.home_lang] = counts.get(v.home_lang, 0) + 1
	var expected := 0.0
	for g in counts:
		var share := float(counts[g]) / res.size()
		expected += share * share
	var same := 0.0
	var total := 0.0
	for t: Tie in st.ties.values():
		if t.kind == Tie.Kind.FAMILY:
			continue
		var a: Villager = st.by_id[t.a]
		var b: Villager = st.by_id[t.b]
		if a.is_helper or b.is_helper:
			continue
		total += t.w
		if a.home_lang == b.home_lang:
			same += t.w
	if total == 0.0 or expected >= 1.0:
		return 0.0
	return clampf((same / total - expected) / (1.0 - expected), 0.0, 1.0)


static func fragility(st: SimState) -> float:
	# Bridge score: each person's share of the tie strength that crosses language groups.
	var bridge := {}
	var cross_total := 0.0
	for t: Tie in st.ties.values():
		var a: Villager = st.by_id[t.a]
		var b: Villager = st.by_id[t.b]
		if a.home_lang != b.home_lang:
			bridge[t.a] = bridge.get(t.a, 0.0) + t.w
			bridge[t.b] = bridge.get(t.b, 0.0) + t.w
			cross_total += t.w
	if cross_total <= 0.0:
		return 1.0
	var scores: Array = bridge.values()
	scores.sort()
	scores.reverse()
	var top := 0.0
	for i in mini(2, scores.size()):
		top += scores[i]
	# Each tie counts for both ends, so the top two can carry at most all of it.
	return clampf(top / cross_total, 0.0, 1.0)


static func helper_burnout(st: SimState) -> float:
	var n := 0
	var tired := 0
	for v: Villager in st.villagers:
		if v.is_helper:
			n += 1
			if v.burnout >= 0.7 or st.tick < v.withdrawn_until:
				tired += 1
	return 0.0 if n == 0 else float(tired) / n


# ---- extra readouts ----

static func word_shares(st: SimState) -> Dictionary:
	var out := {}
	for c in st.concepts:
		for w in st.concepts[c].slice(1):
			out[share_key(w)] = variant_share(st, c, w)
			out[share_key(w, "H")] = variant_share(st, c, w, "H")
			out[share_key(w, "T")] = variant_share(st, c, w, "T")
	return out


static func variant_share(st: SimState, concept: String, vname: String, group: String = "") -> float:
	var total := 0
	var n := 0
	for v: Villager in st.residents():
		if group != "" and v.home_lang != group:
			continue
		total += 1
		if v.variant[concept] == vname:
			n += 1
	return 0.0 if total == 0 else float(n) / total


static func mean_prof(st: SimState, group: String, stage: int, lang: String) -> float:
	var n := 0
	var total := 0.0
	for v: Villager in st.residents():
		if v.home_lang == group and v.stage == stage:
			total += v.p[lang]
			n += 1
	return 0.0 if n == 0 else total / n
