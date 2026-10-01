extends Control
## Charter picker: the player decides what their town cares about.

var sliders := {}
var value_labels := {}
var charter_label: Label
var seed_box: SpinBox
var _setting := false


func _ready() -> void:
	UiStyle.setup_root(self)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	scroll.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	box.add_child(UiStyle.label("Write your town charter", 34))
	box.add_child(UiStyle.label(
		"Give points to the outcomes your town cares about most. Those outcomes appear on your dashboard. "
		+ "Everything else is still tracked quietly, and you'll see it at the end of the year.",
		16, UiStyle.MUTED, true))

	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	box.add_child(presets)
	presets.add_child(UiStyle.label("Start from:", 15, UiStyle.MUTED))
	for title in GameSession.PRESETS:
		presets.add_child(UiStyle.button(title, _apply_preset.bind(title)))

	charter_label = UiStyle.label("", 20)
	box.add_child(charter_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for key in MetricsSystem.OUTCOMES:
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(UiStyle.label(MetricsSystem.LABELS[key], 17))
		text_box.add_child(UiStyle.label(MetricsSystem.DESCRIPTIONS[key], 13, UiStyle.MUTED, true))
		grid.add_child(text_box)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 5
		slider.step = 1
		slider.custom_minimum_size = Vector2(220, 24)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_slider.bind(key))
		grid.add_child(slider)
		sliders[key] = slider
		var vl := UiStyle.label("0", 18)
		vl.custom_minimum_size = Vector2(28, 0)
		grid.add_child(vl)
		value_labels[key] = vl

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	box.add_child(seed_row)
	seed_row.add_child(UiStyle.label("Town seed (same seed and same nudges give the same story):", 14, UiStyle.MUTED))
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 99999
	seed_box.value = GameSession.seed_value
	seed_row.add_child(seed_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var begin := UiStyle.button("Begin the year", _begin)
	begin.custom_minimum_size = Vector2(200, 44)
	begin.add_theme_font_size_override("font_size", 18)
	row.add_child(begin)
	row.add_child(UiStyle.button("Back", func(): get_tree().change_scene_to_file("res://ui/title_screen.tscn")))

	_load_weights(GameSession.charter_title, GameSession.weights)


func _apply_preset(title: String) -> void:
	_load_weights(title, GameSession.PRESETS[title])


func _load_weights(title: String, w: Dictionary) -> void:
	_setting = true
	for key in sliders:
		sliders[key].value = int(w.get(key, 0))
		value_labels[key].text = str(int(w.get(key, 0)))
	_setting = false
	charter_label.text = "Charter: " + title


func _on_slider(value: float, key: String) -> void:
	value_labels[key].text = str(int(value))
	if not _setting:
		charter_label.text = "Charter: Custom"


func _begin() -> void:
	var w := {}
	var total := 0
	for key in sliders:
		w[key] = int(sliders[key].value)
		total += w[key]
	if total == 0:
		charter_label.text = "Give at least one outcome some points first."
		return
	GameSession.set_charter(charter_label.text.trim_prefix("Charter: "), w)
	GameSession.seed_value = int(seed_box.value)
	GameSession.start_run()
	get_tree().change_scene_to_file("res://ui/game_screen.tscn")
