class_name TownMap
extends Control
## Draws the town from SimState. Reads the sim; never changes it.
##
## Dot color: home language (teal = heritage, orange = town, purple = helper).
## Arc around a dot: how much of the OTHER language that person has picked up.
## White center: says "pop" instead of "soda".
## Gold lines: strong friendships that cross language groups. Hover a dot to see all of that person's ties.

signal villager_hovered(id: int)
signal villager_clicked(id: int)

const DESIGN := Vector2(800, 720)

var st: SimState
var hover_id := -1
var selected: Array = []
var _dots := {}          # id -> screen position
var _k := 1.0
var _off := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func to_screen(p: Vector2) -> Vector2:
	return _off + p * _k


func _draw() -> void:
	if st == null:
		return
	_k = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_off = (size - DESIGN * _k) * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.PAPER)

	# Ring road
	var ring := PackedVector2Array()
	for i in 73:
		var a := TAU * i / 72.0
		ring.append(to_screen(Vector2(400, 360) + Vector2(cos(a) * 320.0, sin(a) * 285.0)))
	draw_polyline(ring, UiStyle.LINE, 10.0 * _k, true)

	_layout_dots()

	# Ties
	for t: Tie in st.ties.values():
		if not _dots.has(t.a) or not _dots.has(t.b):
			continue
		var a: Villager = st.by_id[t.a]
		var b: Villager = st.by_id[t.b]
		var hovered := t.a == hover_id or t.b == hover_id
		var cross := a.home_lang != b.home_lang
		if hovered:
			var hc := Color(UiStyle.GOLD, 0.9) if cross else Color(UiStyle.INK, 0.45)
			draw_line(_dots[t.a], _dots[t.b], hc, maxf(1.0, 3.0 * t.w * _k), true)
		elif cross and t.w >= 0.55 and a.location != b.location:
			draw_line(_dots[t.a], _dots[t.b], Color(UiStyle.GOLD, 0.2 + 0.6 * (t.w - 0.5)), maxf(1.0, 2.5 * t.w * _k), true)

	# Places
	for pl: Place in st.places:
		if not pl.built and not pl.buildable:
			continue
		var rect := Rect2(to_screen(pl.pos - pl.box * 0.5), pl.box * _k)
		if pl.built:
			var fill := _place_color(pl)
			draw_rect(rect, fill)
			var border := UiStyle.LINE.darkened(0.15)
			var width := 1.5
			if pl.has_event(st.tick):
				border = UiStyle.GOLD
				width = 4.0
			draw_rect(rect, border, false, width * _k)
		else:
			_dashed_rect(rect, UiStyle.MUTED)
		var title := pl.title if pl.built else "Empty lot"
		draw_string(font, rect.position + Vector2(6, 15) * _k, title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, int(13 * _k), UiStyle.INK)
		var tags: Array = []
		if pl.event_booked(st.tick):
			var kind := "Heritage nights" if pl.event_theme == "heritage" else "Mixer events"
			tags.append(kind if pl.has_event(st.tick) else kind + " (from tomorrow)")
		for sgn in pl.signs:
			tags.append("Sign: " + str(sgn["variant"]))
		if not tags.is_empty():
			draw_string(font, rect.position + Vector2(6, rect.size.y / _k + 13) * _k, ", ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), UiStyle.GOLD.darkened(0.3))
		if not pl.built:
			draw_string(font, rect.position + Vector2(6, 32) * _k, "(" + pl.title + ")", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, int(12 * _k), UiStyle.MUTED)

	# Villagers
	for v: Villager in st.villagers:
		if not _dots.has(v.id):
			continue
		var p: Vector2 = _dots[v.id]
		var r := (4.5 if v.stage == Villager.Stage.CHILD else 6.0) * _k
		var col := UiStyle.lang_color(v.home_lang)
		if v.is_helper and st.tick < v.withdrawn_until:
			col = col.lightened(0.5)
		draw_circle(p, r, col)
		# Arc: share of the other language
		if v.home_lang == "H" or v.home_lang == "T":
			var other := "T" if v.home_lang == "H" else "H"
			var other_col := UiStyle.ORANGE if other == "T" else UiStyle.TEAL
			var amount: float = v.p[other]
			if amount > 0.02:
				draw_arc(p, r + 2.5 * _k, -PI / 2, -PI / 2 + TAU * amount, 24, other_col, 2.0 * _k, true)
		if v.variant.get("fizzy drink", "soda") == "pop":
			draw_circle(p, r * 0.4, Color.WHITE)
		if v.stage == Villager.Stage.ELDER:
			draw_arc(p, r, 0, TAU, 20, UiStyle.INK.lightened(0.3), 1.0 * _k, true)
		if v.id in selected:
			draw_arc(p, r + 5.5 * _k, 0, TAU, 24, UiStyle.GOLD, 2.5 * _k, true)
		if v.id == hover_id:
			draw_arc(p, r + 5.5 * _k, 0, TAU, 24, UiStyle.INK, 2.0 * _k, true)
			draw_string(font, p + Vector2(10, -8) * _k, v.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * _k), UiStyle.INK)

	_draw_legend(font)


func _place_color(pl: Place) -> Color:
	match pl.kind:
		"home":
			if pl.id == SimState.COMMUNITY_ROOM:
				return UiStyle.PURPLE.lightened(0.75)
			return (UiStyle.TEAL if pl.home_lang == "H" else UiStyle.ORANGE).lightened(0.8)
		"work":
			return Color("dfe5ee")
		"school":
			return Color("f6e9b8")
	return Color("d8ead2")


func _dashed_rect(rect: Rect2, col: Color) -> void:
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], col, 1.5, 6.0 * _k)


func _layout_dots() -> void:
	_dots.clear()
	var groups := {}
	for v: Villager in st.villagers:
		if not groups.has(v.location):
			groups[v.location] = []
		groups[v.location].append(v)
	for pid in groups:
		var pl: Place = st.place_by_id[pid]
		var occupants: Array = groups[pid]
		occupants.sort_custom(func(x, y): return x.id < y.id)
		var cols := maxi(1, int((pl.box.x - 12.0) / 16.0))
		var top_left := pl.pos - pl.box * 0.5 + Vector2(12, 30)
		for i in occupants.size():
			@warning_ignore("integer_division")
			var row := i / cols
			var col := i % cols
			_dots[occupants[i].id] = to_screen(top_left + Vector2(col * 16, row * 15))


func _draw_legend(font: Font) -> void:
	var base := to_screen(Vector2(12, 660))
	var items := [
		[UiStyle.TEAL, "Heritage-language home"],
		[UiStyle.ORANGE, "Town-language home"],
		[UiStyle.PURPLE, "Bilingual helper"],
	]
	var x := 0.0
	for it in items:
		draw_circle(base + Vector2(x + 6, 0) * _k, 6 * _k, it[0])
		draw_string(font, base + Vector2(x + 16, 5) * _k, it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), UiStyle.INK)
		x += 175
	var line2 := to_screen(Vector2(12, 684))
	draw_string(font, line2, "Ring = other language learned.  White center = says \"pop\".  Gold line = strong friendship across groups.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), UiStyle.MUTED)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var found := -1
		var best := 10.0 * _k
		for id in _dots:
			var d: float = (_dots[id] as Vector2).distance_to(event.position)
			if d < best:
				best = d
				found = id
		if found != hover_id:
			hover_id = found
			villager_hovered.emit(found)
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hover_id >= 0:
			villager_clicked.emit(hover_id)
