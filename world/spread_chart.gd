class_name SpreadChart
extends Control
## Weekly share of the town using a word, with nudge markers and the tipping point.
## Click or drag on it to scrub the timeline.

signal scrubbed(tick: int)

var st: SimState
var tick := 0
var _plot := Rect2()


func _ready() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	if st == null:
		return
	var font := ThemeDB.fallback_font
	var end_tick := maxi(1, st.tick)
	_plot = Rect2(Vector2(34, 10), size - Vector2(44, 34))
	draw_rect(_plot, Color.WHITE)
	for f in [0.0, 0.5, 1.0]:
		var y: float = _plot.end.y - f * _plot.size.y
		draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), UiStyle.LINE, 1.0)
		draw_string(font, Vector2(2, y + 4), "%d%%" % int(f * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.MUTED)

	# Season boundaries
	for s in range(1, SimState.SEASONS):
		if s * SimState.TICKS_PER_SEASON >= end_tick:
			break
		var x := _x(s * SimState.TICKS_PER_SEASON, end_tick)
		draw_line(Vector2(x, _plot.position.y), Vector2(x, _plot.end.y), Color(UiStyle.LINE, 0.8), 1.0)
		draw_string(font, Vector2(x + 3, _plot.end.y + 14), "S%d" % (s + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.MUTED)
	draw_string(font, Vector2(_plot.position.x + 3, _plot.end.y + 14), "S1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.MUTED)

	# Share line
	var pts := PackedVector2Array()
	for snap in st.history:
		var t := int(snap.get("tick", int(snap["week"]) * SimState.TICKS_PER_WEEK))
		pts.append(Vector2(_x(t, end_tick), _plot.end.y - float(snap["pop_share"]) * _plot.size.y))
	if pts.size() > 1:
		draw_polyline(pts, UiStyle.GOLD.darkened(0.15), 2.5, true)

	# Nudge markers
	for e in st.nudge_log:
		var x := _x(int(e["tick"]), end_tick)
		draw_colored_polygon(PackedVector2Array([Vector2(x, _plot.end.y + 2), Vector2(x - 5, _plot.end.y + 10), Vector2(x + 5, _plot.end.y + 10)]), UiStyle.INK)

	# Tipping point
	var tip := Replay.tipping_week(st)
	if tip >= 0:
		var tx := _x(tip * SimState.TICKS_PER_WEEK, end_tick)
		draw_circle(Vector2(tx, _plot.end.y - 0.5 * _plot.size.y), 4.0, UiStyle.ORANGE)
		draw_string(font, Vector2(tx + 6, _plot.end.y - 0.5 * _plot.size.y - 6), "tipping point", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.ORANGE.darkened(0.2))

	# Playhead
	var px := _x(tick, end_tick)
	draw_line(Vector2(px, _plot.position.y), Vector2(px, _plot.end.y), UiStyle.INK, 2.0)


func _x(t: int, end_tick: int) -> float:
	return _plot.position.x + clampf(float(t) / end_tick, 0.0, 1.0) * _plot.size.x


func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var drag: bool = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	if (press or drag) and st != null and _plot.size.x > 0:
		var f := clampf((event.position.x - _plot.position.x) / _plot.size.x, 0.0, 1.0)
		scrubbed.emit(int(round(f * st.tick)))
