class_name ContagionSystem
extends RefCounted
## Complex contagion: a variant is adopted only after hearing it from enough different sources,
## and only if those sources are a large enough share compared with sources for the current variant.


static func run(st: SimState) -> void:
	var window: int = st.params["exposure_window"]
	for v: Villager in st.villagers:
		var here: Place = st.place_by_id[v.location]
		for sgn in here.signs:
			v.exposures.append({"concept": sgn["concept"], "variant": sgn["variant"], "source": sgn["source"], "tick": st.tick})
		# Drop old exposures
		var fresh: Array = []
		for e in v.exposures:
			if st.tick - int(e["tick"]) <= window:
				fresh.append(e)
		v.exposures = fresh
		if v.committed or v.is_helper:
			continue
		for c in st.concepts:
			_check_adoption(st, v, c)


static func _check_adoption(st: SimState, v: Villager, concept: String) -> void:
	var sources := {}   # variant -> {source: true}
	for e in v.exposures:
		if e["concept"] != concept:
			continue
		var vname: String = e["variant"]
		if not sources.has(vname):
			sources[vname] = {}
		sources[vname][e["source"]] = true
	var ratio: float = st.params["switch_ratio"]
	var current: String = v.variant[concept]
	var cur_n: int = sources.get(current, {}).size()
	for vname in sources:
		if vname == current:
			continue
		var n: int = sources[vname].size()
		if n >= v.threshold and float(n) >= ratio * cur_n:
			v.variant[concept] = vname
			var src: Array = sources[vname].keys()
			st.adoptions.append({"tick": st.tick, "id": v.id, "concept": concept, "from": current, "to": vname, "sources": src})
			st.log_event("%s now says \"%s\" instead of \"%s\"." % [v.display_name, vname, current])
			var kept: Array = []
			for e in v.exposures:
				if e["concept"] != concept:
					kept.append(e)
			v.exposures = kept
			return
