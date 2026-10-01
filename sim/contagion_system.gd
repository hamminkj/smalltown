class_name ContagionSystem
extends RefCounted
## Complex contagion: a variant is adopted only after hearing it from enough different sources
## within the exposure window, and only if those sources are a large enough share compared
## with sources for the villager's current variant.


static func run(st: SimState) -> void:
	var notice: float = st.params["sign_notice"]
	for v: Villager in st.villagers:
		var here: Place = st.place_by_id[v.location]
		for sgn in here.signs:
			if st.rng_spread.randf() < notice:
				v.hear(sgn["concept"], sgn["variant"], sgn["source"], st.tick)
		if not v.heard_new:
			continue
		v.heard_new = false
		if v.committed or v.is_helper:
			continue
		for c in v.heard:
			_check_adoption(st, v, c)


static func _check_adoption(st: SimState, v: Villager, concept: String) -> void:
	var window: int = st.params["exposure_window"]
	var ratio: float = st.params["switch_ratio"]
	var words: Dictionary = v.heard[concept]
	# Count recent distinct sources per word, forgetting old ones.
	var counts := {}
	for word in words:
		var sources: Dictionary = words[word]
		for src in sources.keys():
			if st.tick - int(sources[src]) > window:
				sources.erase(src)
		counts[word] = sources.size()
	var current: String = v.variant[concept]
	var cur_n: int = counts.get(current, 0)
	for word in counts:
		if word == current:
			continue
		var n: int = counts[word]
		if n >= v.threshold and float(n) >= ratio * cur_n:
			v.variant[concept] = word
			var src: Array = words[word].keys()
			st.adoptions.append({"tick": st.tick, "id": v.id, "concept": concept, "from": current, "to": word, "sources": src})
			v.heard[concept] = {}
			return
