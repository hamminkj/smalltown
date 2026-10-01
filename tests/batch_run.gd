extends SceneTree
## Headless tuning runs. Simulates many towns under a few scripted strategies and
## writes weekly metrics to tests/output/results.csv, then prints a summary.
##
## Run from the project folder:
##   godot --headless --script res://tests/batch_run.gd
## Optional: -- --seeds=50
## Output: tests/output/results.csv (the folder is ignored by Godot and git)

const COLUMNS := ["job_access", "neighbor_trust", "kids_school", "elder_connection",
	"economic_vitality", "heritage_vitality", "segregation", "fragility", "helper_burnout",
	"pop_share", "h_adults_t", "h_kids_h"]

const STRATEGIES := ["no_nudges", "mixers", "heritage_care"]


func _init() -> void:
	var seeds := 30
	var overrides := {}
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = int(arg.get_slice("=", 1))
		elif arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
		elif arg.begins_with("--set="):
			# --set=gain:0.01,homophily:1.5
			for pair in arg.get_slice("=", 1).split(","):
				overrides[pair.get_slice(":", 0)] = float(pair.get_slice(":", 1))

	DirAccess.make_dir_recursive_absolute("res://tests/output")
	var out := FileAccess.open("res://tests/output/results.csv", FileAccess.WRITE)
	var header := "strategy,seed,week," + ",".join(COLUMNS)
	if out:
		out.store_line(header)

	var summary := {}
	for strat in STRATEGIES:
		if only != "" and strat != only:
			continue
		summary[strat] = {}
		for seed_value in range(seeds):
			var st := ScenarioV0.build(seed_value)
			for k in overrides:
				st.params[k] = overrides[k]
			var mgr := TickManager.new(st)
			while not st.is_finished():
				if st.tick % SimState.TICKS_PER_SEASON == 0:
					_apply_strategy(st, strat)
				mgr.step()
			for snap in st.history:
				var wk: int = snap["week"]
				if out:
					var row: Array = [strat, seed_value, wk]
					for c in COLUMNS:
						row.append("%.4f" % float(snap[c]))
					out.store_line(",".join(row.map(func(x): return str(x))))
				if wk % 12 == 0:
					if not summary[strat].has(wk):
						summary[strat][wk] = {}
					for c in COLUMNS:
						summary[strat][wk][c] = summary[strat][wk].get(c, 0.0) + float(snap[c]) / seeds

	if out:
		out.close()
	_print_summary(summary)
	quit()


## Simple scripted players, applied at the start of each season.
func _apply_strategy(st: SimState, strat: String) -> void:
	var s := st.season()
	match strat:
		"mixers":
			# Build places where groups mix, then keep them busy.
			if s == 0:
				NudgeSystem.build(st, SimState.CAFE)
				NudgeSystem.signage(st, SimState.MARKET, "fizzy drink", "pop")
			elif s == 1:
				NudgeSystem.event(st, SimState.CAFE)
				NudgeSystem.event(st, SimState.MARKET)
			else:
				NudgeSystem.event(st, SimState.CAFE)
				NudgeSystem.introduce(st, 8, 26)
				NudgeSystem.introduce(st, 11, 25)
		"heritage_care":
			# Bilingual helpers carry contact, so families can keep the heritage language at home.
			if s <= 1:
				NudgeSystem.helper(st)
				NudgeSystem.introduce(st, 1, 13)
				NudgeSystem.introduce(st, 7, 16)
			else:
				NudgeSystem.event(st, SimState.PARK, "heritage")
				NudgeSystem.introduce(st, 11, 5)
				NudgeSystem.introduce(st, 8, 10)


func _print_summary(summary: Dictionary) -> void:
	for strat in summary:
		print("\n=== %s ===" % strat)
		var head := "week".rpad(6)
		for c in COLUMNS:
			head += c.substr(0, 10).rpad(11)
		print(head)
		var weeks: Array = summary[strat].keys()
		weeks.sort()
		for wk in weeks:
			var line := str(wk).rpad(6)
			for c in COLUMNS:
				line += ("%.3f" % summary[strat][wk][c]).rpad(11)
			print(line)
