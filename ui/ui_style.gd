class_name UiStyle
extends RefCounted
## Shared colors, theme, and small builders for the UI. Light palette so it projects well in a classroom.

const PAPER := Color("f4efe6")
const PANEL := Color("fbf8f2")
const INK := Color("2b2d42")
const MUTED := Color("6b6f80")
const LINE := Color("d9d1c3")
const TEAL := Color("2a9d8f")       # heritage-language homes
const ORANGE := Color("e76f51")     # town-language homes
const PURPLE := Color("7b5ea7")     # bilingual helpers
const GOLD := Color("e9a93b")       # cross-group ties, highlights
const BUTTON := Color("2b2d42")
const BUTTON_HOVER := Color("3d4060")

const CREDIT := "Developed by Julianne Hammink"


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)

	t.set_stylebox("normal", "Button", _box(BUTTON, 6, 10, 6))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER, 6, 10, 6))
	t.set_stylebox("pressed", "Button", _box(GOLD.darkened(0.2), 6, 10, 6))
	t.set_stylebox("disabled", "Button", _box(LINE, 6, 10, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 0, 14, 12))
	t.set_stylebox("panel", "PopupPanel", _box(PANEL, 8, 16, 16))
	# Dialogs (season-end messages): light panel and frame so dark text stays readable.
	t.set_stylebox("panel", "AcceptDialog", _box(PANEL, 0, 18, 14))
	var frame := _box(PANEL, 8, 0, 0)
	frame.border_color = LINE.darkened(0.25)
	frame.set_border_width_all(2)
	frame.expand_margin_top = 30
	frame.expand_margin_left = 6
	frame.expand_margin_right = 6
	frame.expand_margin_bottom = 6
	frame.shadow_color = Color(0, 0, 0, 0.25)
	frame.shadow_size = 12
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_color("title_color", "Window", INK)
	t.set_color("close_color", "Window", INK)

	var bar_bg := _box(LINE, 4, 0, 0)
	var bar_fill := _box(TEAL, 4, 0, 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", INK)

	var field := _box(Color.WHITE, 4, 8, 4)
	field.border_color = LINE.darkened(0.2)
	field.set_border_width_all(1)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", INK)

	t.set_stylebox("slider", "HSlider", _box(LINE, 3, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", _box(TEAL, 3, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(TEAL, 3, 0, 3))
	return t


static func _box(color: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func setup_root(root: Control) -> void:
	root.theme = make_theme()
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)


static func label(text: String, size: int = 15, color: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


static func lang_color(home_lang: String) -> Color:
	match home_lang:
		"H":
			return TEAL
		"B":
			return PURPLE
	return ORANGE
