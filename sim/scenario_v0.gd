class_name ScenarioV0
extends RefCounted
## Builds the prototype town from the v0 roster: 30 villagers, 10 households, two languages.

# id, name, stage, home, job, pT, pH, openness, shyness
const ROSTER := [
	[1, "Oren", "elder", 1, "Retired", 0.10, 0.95, 0.3, 0.6],
	[2, "Salma", "adult", 1, "Plant worker", 0.30, 0.90, 0.6, 0.4],
	[3, "Dani", "child", 1, "Student", 0.50, 0.85, 0.8, 0.3],
	[4, "Reza", "adult", 2, "Plant worker", 0.25, 0.90, 0.5, 0.5],
	[5, "Lina", "adult", 2, "Market vendor", 0.40, 0.90, 0.8, 0.2],
	[6, "Yusuf", "child", 2, "Student", 0.60, 0.85, 0.9, 0.2],
	[7, "Mirela", "elder", 3, "Retired", 0.05, 0.95, 0.3, 0.8],
	[8, "Anton", "adult", 3, "Plant worker", 0.20, 0.90, 0.4, 0.75],
	[9, "Sofi", "child", 3, "Student", 0.45, 0.85, 0.7, 0.5],
	[10, "Kofi", "adult", 4, "Plant worker", 0.30, 0.90, 0.6, 0.3],
	[11, "Amina", "adult", 4, "Seeking work", 0.15, 0.90, 0.7, 0.6],
	[12, "Jun", "child", 4, "Student", 0.50, 0.85, 0.8, 0.4],
	[13, "Walt", "elder", 5, "Retired", 0.95, 0.10, 0.3, 0.5],
	[14, "Grace", "adult", 5, "Teacher", 0.90, 0.10, 0.8, 0.3],
	[15, "Ben", "child", 5, "Student", 0.80, 0.10, 0.7, 0.4],
	[16, "Dolores", "elder", 6, "Retired", 0.95, 0.10, 0.4, 0.8],
	[17, "Marcus", "adult", 6, "Clinic aide", 0.90, 0.10, 0.7, 0.3],
	[18, "Ava", "child", 6, "Student", 0.80, 0.10, 0.6, 0.5],
	[19, "Earl", "elder", 7, "Retired", 0.95, 0.10, 0.2, 0.6],
	[20, "Patty", "adult", 7, "Plant supervisor", 0.90, 0.10, 0.5, 0.2],
	[21, "Cody", "child", 7, "Student", 0.80, 0.10, 0.8, 0.3],
	[22, "Ruth", "elder", 8, "Retired", 0.95, 0.10, 0.5, 0.4],
	[23, "Hank", "adult", 8, "Market vendor", 0.90, 0.10, 0.6, 0.2],
	[24, "Lily", "child", 8, "Student", 0.80, 0.10, 0.8, 0.3],
	[25, "Carla", "adult", 9, "Office clerk", 0.90, 0.10, 0.7, 0.3],
	[26, "Joe", "adult", 9, "Plant worker", 0.90, 0.10, 0.5, 0.5],
	[27, "Nina", "adult", 9, "Clinic cleaner", 0.90, 0.10, 0.8, 0.4],
	[28, "Sam", "adult", 10, "Plant driver", 0.90, 0.10, 0.4, 0.4],
	[29, "Tess", "adult", 10, "Market vendor", 0.90, 0.10, 0.7, 0.2],
	[30, "Pete", "adult", 10, "School aide", 0.90, 0.10, 0.5, 0.8],
]

# job -> [workplace, required town-language level]
const JOBS := {
	"Plant worker": [SimState.PLANT, 0.40],
	"Plant driver": [SimState.PLANT, 0.50],
	"Plant supervisor": [SimState.PLANT, 0.80],
	"Clinic aide": [SimState.CLINIC, 0.70],
	"Office clerk": [SimState.CLINIC, 0.80],
	"Clinic cleaner": [SimState.CLINIC, 0.30],
	"Market vendor": [SimState.MARKET, 0.50],
	"Teacher": [SimState.SCHOOL, 0.90],
	"School aide": [SimState.SCHOOL, 0.60],
	"Seeking work": [-1, 0.40],
}

const POP_SEEDS := [18, 19, 26]
const H_HOMES := [1, 2, 3, 4]


static func build(seed_value: int) -> SimState:
	var st := SimState.new()
	st.seed_value = seed_value
	st.rng.seed = seed_value
	_build_places(st)
	_build_villagers(st)
	_build_ties(st)
	return st


static func _build_places(st: SimState) -> void:
	var center := Vector2(400, 360)
	for k in range(1, 11):
		var pl := Place.new()
		pl.id = k
		pl.kind = "home"
		pl.title = "Home %d" % k
		pl.home_lang = "H" if k in H_HOMES else "T"
		var ang := PI * 0.6 + (k - 1) * TAU / 10.0
		pl.pos = center + Vector2(cos(ang) * 320.0, sin(ang) * 285.0)
		pl.box = Vector2(104, 54)
		st.add_place(pl)
	var specs := [
		[SimState.PLANT, "Packing Plant", "work", Vector2(265, 250), true],
		[SimState.CLINIC, "Clinic and Office", "work", Vector2(535, 250), true],
		[SimState.SCHOOL, "School", "school", Vector2(535, 470), true],
		[SimState.MARKET, "Market", "public", Vector2(400, 360), true],
		[SimState.PARK, "Park", "public", Vector2(265, 470), true],
		[SimState.CAFE, "Cafe", "public", Vector2(400, 215), false],
		[SimState.LAUNDROMAT, "Laundromat", "public", Vector2(400, 505), false],
		[SimState.COMMUNITY_ROOM, "Helpers' Room", "home", Vector2(262, 360), false],
	]
	for spec in specs:
		var pl := Place.new()
		pl.id = spec[0]
		pl.title = spec[1]
		pl.kind = spec[2]
		pl.pos = spec[3]
		pl.built = spec[4]
		pl.buildable = pl.id == SimState.CAFE or pl.id == SimState.LAUNDROMAT
		pl.box = Vector2(132, 78) if pl.id == SimState.MARKET else Vector2(120, 70)
		if pl.id == SimState.COMMUNITY_ROOM:
			pl.home_lang = "T"
			pl.box = Vector2(116, 52)
		st.add_place(pl)


static func _build_villagers(st: SimState) -> void:
	for row in ROSTER:
		var v := Villager.new()
		v.id = row[0]
		v.display_name = row[1]
		match row[2]:
			"child":
				v.stage = Villager.Stage.CHILD
			"elder":
				v.stage = Villager.Stage.ELDER
			_:
				v.stage = Villager.Stage.ADULT
		v.household = row[3]
		v.home_place = row[3]
		v.job = row[4]
		if JOBS.has(v.job):
			v.workplace = JOBS[v.job][0]
			v.job_req = JOBS[v.job][1]
		v.is_vendor = v.job == "Market vendor"
		v.set_prof("T", row[5])
		v.set_prof("H", row[6])
		v.openness = row[7]
		v.shyness = row[8]
		v.threshold = 3 if v.shyness > 0.7 else 2
		v.home_lang = "H" if v.household in H_HOMES else "T"
		for c in st.concepts:
			v.variant[c] = "soda"
		if v.id in POP_SEEDS:
			v.variant["fizzy drink"] = "pop"
			v.committed = true
		st.add_villager(v)


static func _build_ties(st: SimState) -> void:
	var by_home := {}
	var by_work := {}
	var children: Array = []
	for v: Villager in st.villagers:
		if not by_home.has(v.household):
			by_home[v.household] = []
		by_home[v.household].append(v)
		if v.workplace > 0:
			if not by_work.has(v.workplace):
				by_work[v.workplace] = []
			by_work[v.workplace].append(v)
		if v.stage == Villager.Stage.CHILD:
			children.append(v)
	# family
	for h in by_home:
		var members: Array = by_home[h]
		for i in members.size():
			for j in range(i + 1, members.size()):
				st.add_tie(members[i].id, members[j].id, Tie.Kind.FAMILY, 0.8)
	# neighbors: the first adult of each home knows the first adult next door on the ring
	for k in range(1, 11):
		var nxt := k % 10 + 1
		st.add_tie(_first_adult(by_home[k]).id, _first_adult(by_home[nxt]).id, Tie.Kind.NEIGHBOR, 0.2)
	# coworkers
	for wp in by_work:
		var staff: Array = by_work[wp]
		for i in staff.size():
			for j in range(i + 1, staff.size()):
				st.add_tie(staff[i].id, staff[j].id, Tie.Kind.WORK, 0.4)
	# school: children with each other and with the teacher and aide
	for i in children.size():
		for j in range(i + 1, children.size()):
			st.add_tie(children[i].id, children[j].id, Tie.Kind.SCHOOL, 0.4)
		for staff_id in [14, 30]:
			st.add_tie(children[i].id, staff_id, Tie.Kind.SCHOOL, 0.4)


static func _first_adult(members: Array) -> Villager:
	for v: Villager in members:
		if v.stage == Villager.Stage.ADULT:
			return v
	return members[0]
