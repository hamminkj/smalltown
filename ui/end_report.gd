extends Control
## End-of-year report: priorities, revealed hidden outcomes, and what the strategy cost.


func _ready() -> void:
	UiStyle.setup_root(self)
	var st: SimState = GameSession.state
	if st == null:
		get_tree().change_scene_to_file.call_deferred("res://ui/title_screen.tscn")
		return
	var start: Dictionary = st.history[0]
	var end: Dictionary = st.history[-1]
	var weights := GameSession.weights

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var weeks := int(end["week"])
	box.add_child(UiStyle.label("Your town after %d weeks" % weeks, 34))
	box.add_child(UiStyle.label("Charter: %s      Charter score: %d  (started at %d)" % [
		GameSession.charter_title, int(round(MetricsSystem.score(end, weights))), int(round(MetricsSystem.score(start, weights)))], 18))

	# Biggest hidden cost
	var cost := _biggest_cost(start, end, weights)
	if cost != "":
		var cl := UiStyle.label(cost, 17, UiStyle.ORANGE.darkened(0.2), true)
		box.add_child(cl)

	box.add_child(UiStyle.label("Outcomes", 22))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for h in ["Outcome", "", "Start", "End", "Change"]:
		grid.add_child(UiStyle.label(h, 14, UiStyle.MUTED))
	for key in MetricsSystem.OUTCOMES:
		var tag := "your priority" if int(weights.get(key, 0)) > 0 else "revealed now"
		_row(grid, key, tag, start, end, false)
	for key in MetricsSystem.HIDDEN:
		_row(grid, key, "hidden, lower is better", start, end, true)

	box.add_child(UiStyle.label("What happened to language", 22))
	var notes: Array = []
	notes.append("Heritage-language adults' town language: %d to %d." % [int(start["h_adults_t"] * 100), int(end["h_adults_t"] * 100)])
	notes.append("Heritage-language children's heritage language: %d to %d." % [int(start["h_kids_h"] * 100), int(end["h_kids_h"] * 100)])
	notes.append("Villagers who say \"pop\": %d%% to %d%%." % [_pct(start, "share:pop"), _pct(end, "share:pop")])
	notes.append("Heritage homes that say \"sabrel\": %d%% to %d%%.  Town homes that say it: %d%% to %d%%." % [
		_pct(start, "share:sabrel:H"), _pct(end, "share:sabrel:H"), _pct(start, "share:sabrel:T"), _pct(end, "share:sabrel:T")])
	notes.append(_bread_story(end))
	notes.append("Nudges you used: %d.  Bilingual helpers hired: %d." % [st.nudge_log.size(), st.helper_count])
	box.add_child(UiStyle.label("\n".join(notes), 15, UiStyle.INK, true))

	box.add_child(UiStyle.label(
		"Try the same seed (%d) with a different charter or different nudges, and compare what changes." % st.seed_value,
		15, UiStyle.MUTED, true))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var replay_b := UiStyle.button("Replay the year and ask \"what if\"", func(): get_tree().change_scene_to_file("res://ui/replay_screen.tscn"))
	replay_b.add_theme_stylebox_override("normal", UiStyle._box(UiStyle.TEAL.darkened(0.15), 6, 10, 6))
	row.add_child(replay_b)
	row.add_child(UiStyle.button("Play again", func(): get_tree().change_scene_to_file("res://ui/charter_screen.tscn")))
	row.add_child(UiStyle.button("Title screen", func(): get_tree().change_scene_to_file("res://ui/title_screen.tscn")))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	row.add_child(spacer)
	var credit := UiStyle.label(UiStyle.CREDIT, 16, UiStyle.MUTED)
	credit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(credit)


func _row(grid: GridContainer, key: String, tag: String, start: Dictionary, end: Dictionary, lower_better: bool) -> void:
	var a: float = start[key]
	var b: float = end[key]
	var diff := b - a
	var good := diff < 0 if lower_better else diff > 0
	var col := UiStyle.INK
	if absf(diff) >= 0.02:
		col = UiStyle.TEAL.darkened(0.2) if good else UiStyle.ORANGE.darkened(0.2)
	grid.add_child(UiStyle.label(MetricsSystem.LABELS[key], 16))
	grid.add_child(UiStyle.label(tag, 13, UiStyle.MUTED))
	grid.add_child(UiStyle.label(str(int(round(a * 100))), 16))
	grid.add_child(UiStyle.label(str(int(round(b * 100))), 16))
	grid.add_child(UiStyle.label("%+d" % int(round(diff * 100)), 16, col))


func _biggest_cost(start: Dictionary, end: Dictionary, weights: Dictionary) -> String:
	var worst_key := ""
	var worst := 0.03
	for key in MetricsSystem.OUTCOMES:
		if int(weights.get(key, 0)) > 0:
			continue
		var drop: float = start[key] - end[key]
		if drop > worst:
			worst = drop
			worst_key = key
	for key in MetricsSystem.HIDDEN:
		var rise: float = end[key] - start[key]
		if rise > worst:
			worst = rise
			worst_key = key
	if worst_key == "":
		return "No outcome outside your charter got noticeably worse. Nice balancing."
	var verb := "fell" if worst_key in MetricsSystem.OUTCOMES else "rose"
	return "Hidden cost: %s %s from %d to %d while you focused elsewhere." % [
		MetricsSystem.LABELS[worst_key], verb, int(round(start[worst_key] * 100)), int(round(end[worst_key] * 100))]


func _pct(snap: Dictionary, key: String) -> int:
	return int(round(float(snap.get(key, 0.0)) * 100))


## One sentence on how the heritage word for stuffed flatbread fared.
func _bread_story(end: Dictionary) -> String:
	var h := float(end.get("share:sabrel:H", 0.0))
	var t := float(end.get("share:sabrel:T", 0.0))
	if t >= 0.6 and h >= 0.6:
		return "The town borrowed the heritage word: most neighbors now call the market's stuffed flatbread \"sabrel.\""
	if h < 0.6 and t < 0.3:
		return "The heritage word is fading: some heritage families now say \"stuffed bread,\" even at home."
	if t >= 0.3:
		return "\"Sabrel\" is spreading into town homes, but the outcome isn't settled yet."
	return "Heritage families kept \"sabrel,\" but it hasn't caught on in the rest of town."
