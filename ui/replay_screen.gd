extends Control
## Replay: scrub through the year to see how a word spread, then ask "what if" about any nudge.

const PLAY_SPEED := 40.0     # ticks per second while playing

var st: SimState
var map: ReplayMap
var chart: SpreadChart
var slider: HSlider
var time_label: Label
var share_label: Label
var play_b: Button
var story: RichTextLabel
var whatif_pick: OptionButton
var whatif_b: Button
var whatif_out: RichTextLabel
var playing := false
var acc := 0.0
var signs := {}
var scroll: ScrollContainer
var worker: Thread = null
var title_label: Label
var word_pick: OptionButton
var chart_note: Label
var progress: Array = [0]


func _ready() -> void:
	st = GameSession.state
	UiStyle.setup_root(self)
	if st == null:
		get_tree().change_scene_to_file.call_deferred("res://ui/title_screen.tscn")
		return
	signs = Replay.sign_places(st)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	map = ReplayMap.new()
	map.setup(st)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(map)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	root.add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	title_label = UiStyle.label("", 24)
	head.add_child(title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	word_pick = OptionButton.new()
	for c in st.concepts:
		word_pick.add_item("\"%s\"" % st.concepts[c][1])
		word_pick.set_item_metadata(word_pick.item_count - 1, c)
	word_pick.item_selected.connect(func(i): _set_concept(word_pick.get_item_metadata(i)))
	head.add_child(word_pick)
	time_label = UiStyle.label("", 16)
	box.add_child(time_label)
	share_label = UiStyle.label("", 15, UiStyle.MUTED)
	box.add_child(share_label)

	chart = SpreadChart.new()
	chart.st = st
	chart.scrubbed.connect(_seek)
	box.add_child(chart)
	chart_note = UiStyle.label("", 12, UiStyle.MUTED, true)
	box.add_child(chart_note)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	box.add_child(controls)
	play_b = UiStyle.button("Play", _toggle_play)
	controls.add_child(play_b)
	controls.add_child(UiStyle.button("< Week", func(): _seek(map.tick - SimState.TICKS_PER_WEEK)))
	controls.add_child(UiStyle.button("Week >", func(): _seek(map.tick + SimState.TICKS_PER_WEEK)))
	controls.add_child(UiStyle.button("Next switch", _next_switch))
	slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = st.tick
	slider.step = 1
	slider.value_changed.connect(func(v): _seek(int(v)))
	box.add_child(slider)

	box.add_child(HSeparator.new())
	box.add_child(UiStyle.label("The story so far", 18))
	story = RichTextLabel.new()
	story.bbcode_enabled = true
	story.fit_content = true
	story.custom_minimum_size = Vector2(0, 120)
	story.meta_clicked.connect(func(meta): _focus(int(str(meta))))
	box.add_child(story)

	box.add_child(HSeparator.new())
	box.add_child(UiStyle.label("What if?", 18))
	box.add_child(UiStyle.label("Pick one of your nudges. The town replays the whole year without it, then checks a few more times with different luck, so you can tell real effects from chance.", 13, UiStyle.MUTED, true))
	whatif_pick = OptionButton.new()
	whatif_pick.fit_to_longest_item = false
	for i in st.nudge_log.size():
		whatif_pick.add_item(Replay.describe_nudge(st, st.nudge_log[i]), i)
	box.add_child(whatif_pick)
	whatif_b = UiStyle.button("Replay the year without it", _run_whatif)
	box.add_child(whatif_b)
	if st.nudge_log.is_empty():
		whatif_pick.add_item("You didn't make any nudges this year.", -1)
		whatif_pick.disabled = true
		whatif_b.disabled = true
	whatif_out = RichTextLabel.new()
	whatif_out.bbcode_enabled = true
	whatif_out.fit_content = true
	box.add_child(whatif_out)

	box.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(UiStyle.button("Back to report", func(): get_tree().change_scene_to_file("res://ui/end_report.tscn")))
	var credit := UiStyle.label(UiStyle.CREDIT, 12, UiStyle.MUTED)
	credit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(credit)

	_set_concept(st.concepts.keys()[0])


## Switch which word pair the replay traces, and jump to just before its first switch.
func _set_concept(c: String) -> void:
	map.concept = c
	map.word = st.concepts[c][1]
	map.focus_id = -1
	chart.word = map.word
	chart.by_group = st.word_lang.get(map.word, "T") != "T"
	title_label.text = "How \"%s\" spread" % map.word
	chart_note.text = "Triangles mark your nudges. Click or drag on the chart to jump."
	if chart.by_group:
		chart_note.text = "Teal: heritage homes. Orange: town homes. Gold: the whole town. " + chart_note.text
	var start := 0
	for a in st.adoptions:
		if a["concept"] == c:
			start = maxi(0, int(a["tick"]) - SimState.TICKS_PER_WEEK)
			break
	_seek(start)


func _process(delta: float) -> void:
	_poll_whatif()
	if not playing:
		return
	acc += delta * PLAY_SPEED
	if acc >= 1.0:
		var steps := int(acc)
		acc -= steps
		if map.tick + steps >= st.tick:
			_toggle_play()
		_seek(map.tick + steps)


func _toggle_play() -> void:
	playing = not playing
	acc = 0.0
	if playing and map.tick >= st.tick:
		_seek(0)
	play_b.text = "Pause" if playing else "Play"


func _next_switch() -> void:
	for a in st.adoptions:
		if int(a["tick"]) > map.tick and a["concept"] == map.concept:
			_focus(int(a["id"]))
			_seek(int(a["tick"]))
			return


func _focus(id: int) -> void:
	map.focus_id = id if map.focus_id != id else -1
	map.queue_redraw()


func _seek(t: int) -> void:
	t = clampi(t, 0, st.tick)
	map.tick = t
	chart.tick = t
	slider.set_value_no_signal(t)
	var wk := t / SimState.TICKS_PER_WEEK
	time_label.text = "Season %d, Week %d" % [mini(wk / SimState.WEEKS_PER_SEASON + 1, SimState.SEASONS), wk % SimState.WEEKS_PER_SEASON + 1]
	var share := Replay.share_at(st, map.concept, map.word, t)
	share_label.text = "%d%% of the town says \"%s\"" % [int(round(share * 100)), map.word]
	if chart.by_group:
		share_label.text += "  (heritage homes %d%%, town homes %d%%)" % [
			int(round(Replay.share_at(st, map.concept, map.word, t, "H") * 100)),
			int(round(Replay.share_at(st, map.concept, map.word, t, "T") * 100))]
	_update_story(t)
	map.queue_redraw()
	chart.queue_redraw()


func _update_story(t: int) -> void:
	var lines: Array = []
	var nudge_i := st.nudge_log.size() - 1
	var idx := st.adoptions.size() - 1
	while idx >= 0 and int(st.adoptions[idx]["tick"]) > t:
		idx -= 1
	while nudge_i >= 0 and int(st.nudge_log[nudge_i]["tick"]) > t:
		nudge_i -= 1
	# Merge recent switches (for this word pair) and your nudges, newest first.
	while lines.size() < 5 and (idx >= 0 or nudge_i >= 0):
		if idx >= 0 and st.adoptions[idx]["concept"] != map.concept:
			idx -= 1
			continue
		var use_nudge := nudge_i >= 0 and (idx < 0 or int(st.nudge_log[nudge_i]["tick"]) >= int(st.adoptions[idx]["tick"]))
		if use_nudge:
			lines.append("[color=#2b2d42][b]You:[/b] %s[/color]" % Replay.describe_nudge(st, st.nudge_log[nudge_i]).split(": ", true, 1)[1])
			nudge_i -= 1
		else:
			var a: Dictionary = st.adoptions[idx]
			var wk := int(a["tick"]) / SimState.TICKS_PER_WEEK + 1
			var col := "#a8761c" if a["to"] == map.word else "#6b6f80"
			lines.append("[color=#6b6f80]Wk %d[/color]  [url=%d][color=%s]%s[/color][/url]" % [wk, int(a["id"]), col, Replay.describe_adoption(st, a, signs)])
			idx -= 1
	if lines.is_empty():
		var first: String = st.concepts[map.concept][0]
		lines.append("[color=#6b6f80]Nobody has switched words yet. \"%s\" and \"%s\" are where they started.[/color]" % [first, map.word])
	story.text = "\n".join(lines)


func _run_whatif() -> void:
	var i := whatif_pick.get_selected_id()
	if i < 0 or worker != null:
		return
	whatif_b.disabled = true
	whatif_pick.disabled = true
	progress = [0]
	worker = Thread.new()
	worker.start(Replay.whatif.bind(st.seed_value, st.nudge_log, i, st.tick, progress))


func _poll_whatif() -> void:
	if worker == null:
		return
	if worker.is_alive():
		var total := 1 + 2 * Replay.LUCK_RUNS
		whatif_out.text = "[color=#6b6f80]Replaying the year without it, then checking %d more times with different luck... %d of %d[/color]" % [Replay.LUCK_RUNS, progress[0], total]
		return
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	whatif_b.disabled = false
	whatif_pick.disabled = false
	whatif_out.text = _compare(st.history[-1], result)
	await get_tree().process_frame
	scroll.ensure_control_visible(whatif_out)


func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()


func _compare(real: Dictionary, result: Dictionary) -> String:
	var w := GameSession.weights
	var alt: Dictionary = result["without"]
	var lines: Array = []
	var key := MetricsSystem.share_key(map.word)
	lines.append("[b]In your town:[/b] charter score %d with it, %d without it. \"%s\": %d%% with it, %d%% without it." % [
		int(round(MetricsSystem.score(real, w))), int(round(MetricsSystem.score(alt, w))),
		map.word, int(round(real[key] * 100)), int(round(alt[key] * 100))])
	var verdicts := Replay.judge(real, result)
	var real_fx: Array = []
	var luck_fx: Array = []
	for v in verdicts:
		var is_word: bool = str(v["key"]).begins_with("share:")
		# "Heritage word kept" already covers heritage-language words in heritage homes.
		var parts: PackedStringArray = str(v["key"]).split(":")
		if is_word and parts.size() == 3 and parts[2] == "H" and st.word_lang.get(parts[1], "T") == "H":
			continue
		var name: String = MetricsSystem.word_label(v["key"]) if is_word else MetricsSystem.LABELS[v["key"]]
		var pts := int(round(absf(v["mean"]) * 100))
		if v["verdict"] == "real":
			var col := "#1f7a6f" if v["helped"] else "#c0533a"
			var how := "went up" if v["mean"] > 0 else "went down"
			if v["key"] in MetricsSystem.HIDDEN or is_word:
				how = ("rose" if v["mean"] > 0 else "fell")
			real_fx.append("  [color=%s]%s %s about %d points[/color]  [color=#6b6f80](%d of %d runs)[/color]" % [col, name, how, pts, v["agree"], v["runs"]])
		elif v["verdict"] == "luck":
			luck_fx.append(name)
	if real_fx.is_empty():
		lines.append("[b]Effects that held up with different luck:[/b] none. This nudge didn't reliably change anything.")
	else:
		lines.append("[b]Effects that held up with different luck:[/b]")
		lines.append_array(real_fx.slice(0, 6))
	if not luck_fx.is_empty():
		lines.append("[color=#6b6f80][b]Probably just luck:[/b] %s changed in some runs but not others.[/color]" % Replay.join_names(luck_fx))
	if int(result["failed"]) > 0:
		lines.append("[color=#6b6f80]Without it, %d of your later nudges couldn't happen.[/color]" % int(result["failed"]))
	return "\n".join(lines)
