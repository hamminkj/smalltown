extends SceneTree
## Checks that rerunning a game from its seed and nudge log reproduces it exactly,
## and that skipping a nudge changes the outcome.
## Run: godot --headless --script res://tests/determinism_test.gd

func _init() -> void:
	var st := ScenarioV0.build(42)
	var mgr := TickManager.new(st)
	var plan := {
		0: [["build", SimState.CAFE], ["signage", SimState.MARKET]],
		336: [["helper"], ["event", SimState.PARK, "heritage"]],
		700: [["introduce", 8, 26], ["introduce", 11, 25]],
	}
	while not st.is_finished():
		if plan.has(st.tick):
			for n in plan[st.tick]:
				match n[0]:
					"build": NudgeSystem.build(st, n[1])
					"signage": NudgeSystem.signage(st, n[1], "fizzy drink", "pop")
					"helper": NudgeSystem.helper(st)
					"event": NudgeSystem.event(st, n[1], n[2])
					"introduce": NudgeSystem.introduce(st, n[1], n[2])
		mgr.step()
	var original: Dictionary = st.history[-1]

	var same: SimState = Replay.rerun(42, st.nudge_log)["state"]
	var ok := true
	for k in MetricsSystem.OUTCOMES + MetricsSystem.HIDDEN + MetricsSystem.word_keys(st):
		if not is_equal_approx(float(original[k]), float(same.history[-1][k])):
			print("MISMATCH ", k, ": ", original[k], " vs ", same.history[-1][k])
			ok = false
	if same.adoptions.size() != st.adoptions.size():
		print("MISMATCH adoptions: ", st.adoptions.size(), " vs ", same.adoptions.size())
		ok = false

	var without_sign: Dictionary = Replay.rerun(42, st.nudge_log, 1)
	var alt: SimState = without_sign["state"]
	print("nudges: ", st.nudge_log.size())
	for i in st.nudge_log.size():
		print("  ", Replay.describe_nudge(st, st.nudge_log[i]))
	print("pop share with sign: %.2f, without sign: %.2f" % [original["share:pop"], alt.history[-1]["share:pop"]])
	print("tipping week: ", Replay.tipping_week(st), "  share at week 6: %.2f" % Replay.share_at(st, "fizzy drink", "pop", 6 * 28))
	var signs := Replay.sign_places(st)
	for a in st.adoptions.slice(0, 3):
		print("  wk %d: %s" % [int(a["tick"]) / 28 + 1, Replay.describe_adoption(st, a, signs)])
	# Separate random streams: removing a "pop" sign may only change who says "pop".
	for k in MetricsSystem.OUTCOMES + MetricsSystem.HIDDEN + [MetricsSystem.share_key("sabrel")]:
		if not is_equal_approx(float(original[k]), float(alt.history[-1][k])):
			print("LEAK: removing the sign changed ", k, ": ", original[k], " vs ", alt.history[-1][k])
			ok = false
	# A game that ends early (mid-week) must replay to the same moment.
	var short := ScenarioV0.build(9)
	var short_mgr := TickManager.new(short)
	NudgeSystem.signage(short, SimState.MARKET, "fizzy drink", "pop")
	while short.tick < 450:
		short_mgr.step()
	Replay.close_out(short)
	var short_again: SimState = Replay.rerun(9, short.nudge_log, -1, short.tick)["state"]
	for k in MetricsSystem.OUTCOMES + MetricsSystem.HIDDEN + MetricsSystem.word_keys(short):
		if not is_equal_approx(float(short.history[-1][k]), float(short_again.history[-1][k])):
			print("MISMATCH (early end) ", k)
			ok = false
	var wi := Replay.whatif(9, short.nudge_log, 0, short.tick)
	for v in Replay.judge(short.history[-1], wi):
		if not str(v["key"]).begins_with("share:pop") and v["verdict"] != "none":
			print("LEAK: sign what-if flagged ", v["key"], " as ", v["verdict"])
			ok = false
	var skip_cafe: Dictionary = Replay.rerun(42, st.nudge_log, 0)
	print("without the cafe, failed later nudges: ", skip_cafe["failed"])
	# variant_at must agree with live state at the end
	for v: Villager in st.villagers:
		for c in st.concepts:
			if Replay.variant_at(st, v.id, c, st.tick) != v.variant[c]:
				print("MISMATCH variant_at for ", v.display_name, " ", c)
				ok = false
	print("DETERMINISM OK" if ok else "DETERMINISM FAILED")
	quit(0 if ok else 1)
