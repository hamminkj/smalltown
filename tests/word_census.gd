extends SceneTree
## Word census: runs 24 towns for a year and counts how each word pair ended.
## "borrowed" = the town took up "sabrel"; "heritage-loss" = heritage homes are losing it.
## By default a "pop" sign goes up at the market in week 1.
##
##   godot --headless --script res://tests/word_census.gd -- [options]
##
## Options (any number):
##   param:value       override a sim param, e.g. sign_notice:0.2
##   appeal:1.6        appeal of "pop"
##   nosign:1          no "pop" sign
##   sabrelsign:1      a "sabrel" sign at the market in week 1
##   bread_sign:1      a "stuffed bread" sign at the market in week 1
##   hnight:1          heritage nights at the market every season
##   mixer:1           mixer events at the park every season
func _init():
	var args = OS.get_cmdline_user_args()
	var borrowed = 0; var lost = 0; var mixed = 0; var tipped = 0; var adopt = 0
	var finals = []
	var sumh = 0.0
	var n = 24
	for s in range(1, n + 1):
		var st = ScenarioV0.build(s)
		for a in args:
			if a.begins_with("appeal:"):
				st.word_appeal["pop"] = float(a.get_slice(":",1))
			else:
				st.params[a.get_slice(":",0)] = float(a.get_slice(":",1))
		var mgr = TickManager.new(st)
		if st.params.get("sabrelsign", 0) == 1:
			NudgeSystem.signage(st, SimState.MARKET, "stuffed flatbread", "sabrel")
		if st.params.get("bread_sign", 0) == 1:
			NudgeSystem.signage(st, SimState.MARKET, "stuffed flatbread", "stuffed bread")
		if not st.params.has("nosign") or st.params["nosign"] == 0:
			NudgeSystem.signage(st, SimState.MARKET, "fizzy drink", "pop")
		while not st.is_finished():
			if st.params.get("hnight", 0) == 1 and st.tick % 336 == 0:
				st.budget = 10
				NudgeSystem.event(st, SimState.MARKET, "heritage")
			if st.params.get("mixer", 0) == 1 and st.tick % 336 == 0:
				st.budget = 10
				NudgeSystem.event(st, SimState.PARK, "mixer")
			mgr.step()
		var h = st.history[-1]
		var hh = h["share:sabrel:H"]; var tt = h["share:sabrel:T"]
		sumh += hh
		if tt >= 0.6 and hh >= 0.6: borrowed += 1
		elif hh <= 0.6 and tt < 0.3: lost += 1
		else: mixed += 1
		if h["share:pop"] >= 0.5: tipped += 1
		adopt += st.adoptions.size()
		finals.append("%d/%d" % [int(round(hh*100)), int(round(tt*100))])
	print("borrowed %d  heritage-loss %d  mixed %d  | pop tipped %d of %d | avg switches %d" % [borrowed, lost, mixed, tipped, n, adopt / n])
	print("  sabrel H/T by town: ", " ".join(finals))
	print("  mean sabrel in heritage homes: %d%%" % int(round(sumh * 100 / n)))
	quit()
