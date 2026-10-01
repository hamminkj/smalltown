class_name DecaySystem
extends RefCounted
## Unused languages fade, and ties without contact weaken.


static func run(st: SimState) -> void:
	var after: int = st.params["decay_after"]
	var rate: float = st.params["decay"]
	var floor_hi: float = st.params["decay_floor"]
	for v: Villager in st.villagers:
		for lang in v.p:
			if st.tick - int(v.last_used[lang]) > after:
				var floor_v := floor_hi if v.peak[lang] > 0.6 else 0.0
				v.p[lang] = maxf(floor_v, v.p[lang] - rate)
		if v.is_helper and v.location == v.home_place:
			v.burnout = maxf(0.0, v.burnout - st.params["burnout_recover"])

	var idle: float = st.params["w_idle"]
	var w_floor: float = st.params["w_floor"]
	for t: Tie in st.ties.values():
		if t.kind != Tie.Kind.FAMILY and not t.talked_this_tick:
			t.w = maxf(w_floor, t.w - idle)
