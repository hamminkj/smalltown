extends Control
## The main play screen: town map on the left, dashboard and nudges on the right.

const SPEEDS := [0.0, 6.0, 24.0, 80.0]   # ticks per second
const SPEED_NAMES := ["Pause", "Play", "Fast", "Faster"]
const NOISE := 0.03                       # dashboard readings are a little noisy

var st: SimState
var mgr: TickManager
var map: TownMap
var speed_index := 0
var acc := 0.0
var finished := false
var display_rng := RandomNumberGenerator.new()
var shown := {}
var log_seen := -1
var pick_first := true

var time_label: Label
var score_label: Label
var budget_label: Label
var metric_rows := {}
var speed_buttons: Array = []
var info_label: RichTextLabel
var news_label: RichTextLabel
var popup: AcceptDialog

var build_cafe_b: Button
var build_laundry_b: Button
var event_place: OptionButton
var event_theme: OptionButton
var event_b: Button
var helper_b: Button
var intro_a: OptionButton
var intro_b: OptionButton
var intro_btn: Button
var sign_place: OptionButton
var sign_variant: OptionButton
var sign_b: Button
var lens: OptionButton


func _ready() -> void:
	if GameSession.state == null:
		GameSession.start_run()
	st = GameSession.state
	mgr = GameSession.manager
	display_rng.seed = st.seed_value + 7
	UiStyle.setup_root(self)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	map = TownMap.new()
	map.st = st
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.villager_hovered.connect(_on_hover)
	map.villager_clicked.connect(_on_click)
	root.add_child(map)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 0)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	_build_header(box)
	_build_metrics(box)
	_build_nudges(box)
	_build_info(box)

	popup = AcceptDialog.new()
	popup.title = "Small Town"
	popup.confirmed.connect(_after_popup)
	popup.canceled.connect(_after_popup)
	add_child(popup)

	_refresh_metrics(true)
	_refresh_all()
	_add_news_line("Welcome to town. Press Play to start the year, or make a nudge first.")


# ---------- layout ----------

func _section(box: VBoxContainer, text: String) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	box.add_child(sep)
	box.add_child(UiStyle.label(text, 18))


func _build_header(box: VBoxContainer) -> void:
	time_label = UiStyle.label("", 18)
	box.add_child(time_label)
	box.add_child(UiStyle.label("Charter: " + GameSession.charter_title, 14, UiStyle.MUTED))
	score_label = UiStyle.label("", 20)
	box.add_child(score_label)

	var lens_row := HBoxContainer.new()
	lens_row.add_theme_constant_override("separation", 6)
	box.add_child(lens_row)
	lens_row.add_child(UiStyle.label("Map shows who says:", 14, UiStyle.MUTED))
	lens = OptionButton.new()
	for c in st.concepts:
		lens.add_item("\"%s\" (%s)" % [st.concepts[c][1], c])
		lens.set_item_metadata(lens.item_count - 1, c)
	lens.item_selected.connect(func(i): map.concept = lens.get_item_metadata(i); map.queue_redraw())
	lens_row.add_child(lens)

	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	box.add_child(speeds)
	for i in SPEEDS.size():
		var b := UiStyle.button(SPEED_NAMES[i], _set_speed.bind(i))
		b.toggle_mode = true
		speeds.add_child(b)
		speed_buttons.append(b)


func _build_metrics(box: VBoxContainer) -> void:
	_section(box, "Your town's priorities")
	for key in GameSession.visible_metrics():
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var top := HBoxContainer.new()
		var name_l := UiStyle.label("%s  (weight %d)" % [MetricsSystem.LABELS[key], GameSession.weights[key]], 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_l)
		var val_l := UiStyle.label("", 14)
		top.add_child(val_l)
		row.add_child(top)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.tooltip_text = MetricsSystem.DESCRIPTIONS[key]
		row.add_child(bar)
		box.add_child(row)
		metric_rows[key] = [bar, val_l]
	box.add_child(UiStyle.label("Readings update weekly and are a little noisy, like real surveys. Other outcomes are tracked quietly and revealed at year's end.", 12, UiStyle.MUTED, true))


func _build_nudges(box: VBoxContainer) -> void:
	_section(box, "Nudges")
	budget_label = UiStyle.label("", 15)
	box.add_child(budget_label)

	# Build
	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 6)
	box.add_child(build_row)
	build_cafe_b = UiStyle.button("Open the Cafe (3)", func(): _do(NudgeSystem.build(st, SimState.CAFE)))
	build_laundry_b = UiStyle.button("Open the Laundromat (3)", func(): _do(NudgeSystem.build(st, SimState.LAUNDROMAT)))
	build_row.add_child(build_cafe_b)
	build_row.add_child(build_laundry_b)

	# Event
	var ev_row := HBoxContainer.new()
	ev_row.add_theme_constant_override("separation", 6)
	box.add_child(ev_row)
	event_place = OptionButton.new()
	event_theme = OptionButton.new()
	event_theme.add_item("Mixer", 0)
	event_theme.add_item("Heritage night", 1)
	event_theme.tooltip_text = "Mixer: people mingle in the town language.\nHeritage night: anyone who can follow speaks the heritage language."
	event_b = UiStyle.button("Hold a week of events (2)", _do_event)
	ev_row.add_child(event_place)
	ev_row.add_child(event_theme)
	box.add_child(event_b)

	# Helper
	helper_b = UiStyle.button("Hire a bilingual helper (2)", func(): _do(NudgeSystem.helper(st)))
	helper_b.tooltip_text = "Helpers speak both languages. Learners seek them out, which wears them down over time."
	box.add_child(helper_b)

	# Introduction
	var intro_row := HBoxContainer.new()
	intro_row.add_theme_constant_override("separation", 6)
	box.add_child(intro_row)
	intro_a = OptionButton.new()
	intro_b = OptionButton.new()
	for v: Villager in st.residents():
		intro_a.add_item(v.display_name, v.id)
		intro_b.add_item(v.display_name, v.id)
	intro_b.select(1)
	intro_row.add_child(intro_a)
	intro_row.add_child(UiStyle.label("and", 14, UiStyle.MUTED))
	intro_row.add_child(intro_b)
	intro_btn = UiStyle.button("Introduce (1)", _do_intro)
	intro_row.add_child(intro_btn)
	box.add_child(UiStyle.label("Tip: click two villagers on the map to pick them.", 12, UiStyle.MUTED))

	# Signage
	var sign_row := HBoxContainer.new()
	sign_row.add_theme_constant_override("separation", 6)
	box.add_child(sign_row)
	sign_place = OptionButton.new()
	sign_variant = OptionButton.new()
	for c in st.concepts:
		for vname in st.concepts[c]:
			sign_variant.add_item("\"%s\"" % vname)
			sign_variant.set_item_metadata(sign_variant.item_count - 1, [c, vname])
			sign_variant.set_item_tooltip(sign_variant.item_count - 1, "A word for %s" % c)
	sign_variant.select(1)
	sign_b = UiStyle.button("Put up a sign (1)", _do_sign)
	sign_row.add_child(sign_place)
	sign_row.add_child(sign_variant)
	sign_row.add_child(sign_b)


func _build_info(box: VBoxContainer) -> void:
	_section(box, "Villager")
	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.custom_minimum_size = Vector2(0, 96)
	info_label.text = "[color=#6b6f80]Hover over a dot on the map to meet someone.[/color]"
	box.add_child(info_label)

	_section(box, "Town news")
	news_label = RichTextLabel.new()
	news_label.bbcode_enabled = true
	news_label.fit_content = true
	news_label.custom_minimum_size = Vector2(0, 150)
	box.add_child(news_label)

	var end_b := UiStyle.button("End the year now", _finish)
	box.add_child(end_b)
	box.add_child(UiStyle.label(UiStyle.CREDIT, 12, UiStyle.MUTED))


# ---------- loop ----------

func _process(delta: float) -> void:
	if finished or popup.visible:
		return
	acc += delta * SPEEDS[speed_index]
	var steps := 0
	while acc >= 1.0 and steps < 12:
		acc -= 1.0
		steps += 1
		var season_over := mgr.step()
		if st.tick % SimState.TICKS_PER_WEEK == 0:
			_refresh_metrics(false)
		if season_over:
			acc = 0.0
			_season_end()
			break
	if steps > 0:
		_refresh_all()


func _set_speed(i: int) -> void:
	speed_index = i
	acc = 0.0
	for j in speed_buttons.size():
		speed_buttons[j].set_pressed_no_signal(j == i)


func _season_end() -> void:
	_set_speed(0)
	if st.is_finished():
		_finish()
		return
	var done := st.season()
	popup.dialog_text = "Season %d is over.\n\nCharter score: %d\nYou have %d nudge points for season %d." % [done, int(round(GameSession.current_score())), st.budget, done + 1]
	popup.popup_centered()


func _after_popup() -> void:
	pass


func _finish() -> void:
	if finished:
		return
	finished = true
	Replay.close_out(st)
	get_tree().change_scene_to_file("res://ui/end_report.tscn")


# ---------- nudges ----------

func _do(ok: bool) -> void:
	if not ok:
		_add_news_line("[color=#e76f51]That nudge isn't possible right now.[/color]")
	_refresh_all()


func _do_event() -> void:
	if event_place.item_count == 0:
		return
	var pid := event_place.get_selected_id()
	var theme_name := "heritage" if event_theme.get_selected_id() == 1 else "mixer"
	_do(NudgeSystem.event(st, pid, theme_name))


func _do_intro() -> void:
	_do(NudgeSystem.introduce(st, intro_a.get_selected_id(), intro_b.get_selected_id()))
	map.selected.clear()


func _do_sign() -> void:
	if sign_place.item_count == 0:
		return
	var meta: Array = sign_variant.get_item_metadata(sign_variant.selected)
	_do(NudgeSystem.signage(st, sign_place.get_selected_id(), meta[0], meta[1]))


# ---------- refresh ----------

func _refresh_all() -> void:
	time_label.text = st.time_label()
	score_label.text = "Charter score: %d" % int(round(GameSession.current_score()))
	budget_label.text = "%d nudge points left this season" % st.budget

	var cafe: Place = st.place_by_id[SimState.CAFE]
	var laundry: Place = st.place_by_id[SimState.LAUNDROMAT]
	build_cafe_b.visible = not cafe.built
	build_laundry_b.visible = not laundry.built
	build_cafe_b.disabled = not NudgeSystem.can_afford(st, "build")
	build_laundry_b.disabled = build_cafe_b.disabled
	event_b.disabled = not NudgeSystem.can_afford(st, "event")
	helper_b.disabled = not NudgeSystem.can_afford(st, "helper") or st.helper_count >= NudgeSystem.HELPER_NAMES.size()
	intro_btn.disabled = not NudgeSystem.can_afford(st, "introduce")
	sign_b.disabled = not NudgeSystem.can_afford(st, "signage")
	_refresh_place_options(event_place, true)
	_refresh_place_options(sign_place, false)

	if st.event_log.size() != log_seen:
		var lines: Array = []
		for i in range(st.event_log.size() - 1, maxi(-1, st.event_log.size() - 9), -1):
			var e: Dictionary = st.event_log[i]
			var when := "Wk %d" % (int(e["tick"]) / SimState.TICKS_PER_WEEK + 1)
			lines.append("[color=#6b6f80]%s[/color]  %s" % [when, e["text"]])
		news_label.text = "\n".join(lines)
		log_seen = st.event_log.size()

	if map.hover_id >= 0:
		_on_hover(map.hover_id)
	map.queue_redraw()


func _refresh_place_options(ob: OptionButton, skip_busy: bool) -> void:
	var keep := ob.get_selected_id() if ob.item_count > 0 else -1
	var ids: Array = []
	for pl: Place in st.places:
		if pl.kind == "public" and pl.built:
			if skip_busy and pl.event_booked(st.tick):
				continue
			ids.append(pl.id)
	var current: Array = []
	for i in ob.item_count:
		current.append(ob.get_item_id(i))
	if current == ids:
		return
	ob.clear()
	for id in ids:
		ob.add_item(st.place_by_id[id].title, id)
	if keep in ids:
		ob.select(ob.get_item_index(keep))


func _refresh_metrics(first: bool) -> void:
	var snap: Dictionary = st.history[-1]
	for key in metric_rows:
		var true_v: float = snap[key]
		var v := true_v if first else clampf(true_v + display_rng.randf_range(-NOISE, NOISE), 0.0, 1.0)
		shown[key] = v
		metric_rows[key][0].value = v * 100.0
		metric_rows[key][1].text = "%d" % int(round(v * 100.0))


func _add_news_line(text: String) -> void:
	st.log_event(text)
	log_seen = -1


# ---------- map interaction ----------

func _on_hover(id: int) -> void:
	if id < 0 or not st.by_id.has(id):
		return
	var v: Villager = st.by_id[id]
	var lines: Array = []
	var role := v.job if v.stage != Villager.Stage.CHILD else "Student"
	lines.append("[b]%s[/b]  (%s, %s)" % [v.display_name, v.stage_name(), role])
	if v.is_helper:
		var state_txt := "stepping back to rest" if st.tick < v.withdrawn_until else "strain %d%%" % int(v.burnout * 100)
		lines.append("Bilingual helper, %s" % state_txt)
	else:
		lines.append("Home language: %s" % ("heritage" if v.home_lang == "H" else "town"))
	var job_note := ""
	if v.stage == Villager.Stage.ADULT and not v.is_helper:
		job_note = "  (job needs %d: %s)" % [int(v.job_req * 100), "meets it" if v.p["T"] >= v.job_req else "below"]
	lines.append("Town language: %d%s" % [int(v.p["T"] * 100), job_note])
	lines.append("Heritage language: %d" % int(v.p["H"] * 100))
	var words: Array = []
	for c in st.concepts:
		words.append("\"%s\"" % v.variant[c])
	lines.append("Says %s  |  %d ties  |  at the %s" % [" and ".join(words), st.adjacency[v.id].size(), st.place_by_id[v.location].title])
	info_label.text = "\n".join(lines)


func _on_click(id: int) -> void:
	if not st.by_id.has(id) or st.by_id[id].is_helper:
		return
	var target := intro_a if pick_first else intro_b
	target.select(target.get_item_index(id))
	pick_first = not pick_first
	map.selected = [intro_a.get_selected_id(), intro_b.get_selected_id()]
	map.queue_redraw()
