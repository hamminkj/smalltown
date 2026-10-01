class_name RewiringSystem
extends RefCounted
## Adaptive network: once a week, some villagers drop a frustrating tie and keep an easy new one.


static func run(st: SimState) -> void:
	var chance: float = st.params["rewire_chance"]
	for v: Villager in st.villagers:
		if st.rng.randf() < chance:
			_drop_weakest(st, v)
			_add_best_new(st, v)
	for v: Villager in st.villagers:
		v.met.clear()


static func _drop_weakest(st: SimState, v: Villager) -> void:
	var worst: Tie = null
	for t: Tie in st.ties_of(v.id):
		if t.kind == Tie.Kind.FAMILY or t.s >= 0.3:
			continue
		if worst == null or t.w < worst.w:
			worst = t
	if worst != null:
		st.remove_tie(worst)


static func _add_best_new(st: SimState, v: Villager) -> void:
	var best_id := -1
	var best_rate := 0.6
	for other_id in v.met:
		if st.get_tie(v.id, other_id) != null:
			continue
		var rec: Array = v.met[other_id]
		if rec[0] < 2:
			continue
		var rate := float(rec[1]) / float(rec[0])
		if rate > best_rate:
			best_rate = rate
			best_id = other_id
	if best_id >= 0:
		var t := st.add_tie(v.id, best_id, Tie.Kind.MET, 0.25)
		t.s = best_rate
