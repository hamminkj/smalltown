extends Control
## Title screen.


func _ready() -> void:
	UiStyle.setup_root(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(680, 0)
	center.add_child(box)

	var title := UiStyle.label("Small Town", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := UiStyle.label("A game about how language moves through a community", 20, UiStyle.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var how := UiStyle.label(
		"You are the town's community connector. Thirty neighbors live here: some speak the town language at home, "
		+ "some speak a heritage language. You can't teach anyone or tell anyone what to do. "
		+ "You can only nudge: open a place where people meet, hold an event, introduce two people, hire a bilingual helper, or put up a sign.\n\n"
		+ "Words, habits, and friendships spread on their own. Pick what your town cares about, then watch what your nudges really do.",
		16, UiStyle.INK, true)
	box.add_child(how)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var start := UiStyle.button("Start", func(): get_tree().change_scene_to_file("res://ui/charter_screen.tscn"))
	start.custom_minimum_size = Vector2(160, 44)
	start.add_theme_font_size_override("font_size", 20)
	buttons.add_child(start)
	if OS.get_name() != "Web":
		var quit_b := UiStyle.button("Quit", func(): get_tree().quit())
		quit_b.custom_minimum_size = Vector2(120, 44)
		buttons.add_child(quit_b)

	var credit := UiStyle.label(UiStyle.CREDIT, 16, UiStyle.MUTED)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credit)
