class_name ReplayMap
extends Control
## Draws everyone at home, colored by the word they used at `tick`, with arrows from the
## voices that convinced each recent switcher. Reads the finished SimState; changes nothing.

const DESIGN := Vector2(800, 720)
const TRAIL := 28            # ticks an arrow stays visible (one week)

var st: SimState
var tick := 0
var concept := "fizzy drink"
var word := "pop"
var focus_id := -1            # villager whose story is highlighted
var signs := {}
var _helper_arrival := {}     # helper id -> tick hired
var _sign_time := {}          # sign source id -> tick it went up
var _pos := {}
var _k := 1.0
var _off := Vector2.ZERO


func setup(state: SimState) -> void:
	st = state
	word = st.concepts[concept][1]
	signs = Replay.sign_places(st)
	# Helpers get ids 100, 101, ... and signs get sources -1, -2, ... in the order they were bought.
	var helpers := 0
	var sign_n := 0
	for e in st.nudge_log:
		if e["nudge"] == "helper":
			_helper_arrival[100 + helpers] = int(e["tick"])
			helpers += 1
		elif e["nudge"] == "signage":
			sign_n -= 1
			_sign_time[sign_n] = int(e["tick"])


func to_screen(p: Vector2) -> Vector2:
	return _off + p * _k


func _draw() -> void:
	if st == null:
		return
	_k = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_off = (size - DESIGN * _k) * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.PAPER)

	var ring := PackedVector2Array()
	for i in 73:
		var a := TAU * i / 72.0
		ring.append(to_screen(Vector2(400, 360) + Vector2(cos(a) * 320.0, sin(a) * 285.0)))
	draw_polyline(ring, UiStyle.LINE, 10.0 * _k, true)

	# Places: homes always; public places only if built by the end
	for pl: Place in st.places:
		if not pl.built:
			continue
		var rect := Rect2(to_screen(pl.pos - pl.box * 0.5), pl.box * _k)
		var fill := Color("e8e2d6") if pl.kind != "home" else (UiStyle.TEAL if pl.home_lang == "H" else UiStyle.ORANGE).lightened(0.85)
		if pl.id == SimState.COMMUNITY_ROOM:
			fill = UiStyle.PURPLE.lightened(0.8)
		draw_rect(rect, fill)
		draw_rect(rect, UiStyle.LINE.darkened(0.1), false, 1.0)
		draw_string(font, rect.position + Vector2(6, 15) * _k, pl.title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, int(12 * _k), UiStyle.MUTED)
		for sgn in pl.signs:
			if sgn["variant"] == word and _sign_up(int(sgn["source"])):
				draw_string(font, rect.position + Vector2(6, rect.size.y / _k + 13) * _k, "Sign: " + word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), UiStyle.GOLD.darkened(0.3))

	_layout()

	# Arrows: recent switches, fading with age
	for a in st.adoptions:
		var t := int(a["tick"])
		if t > tick:
			break
		if tick - t > TRAIL or a["concept"] != concept:
			continue
		var target: Vector2 = _pos.get(int(a["id"]), Vector2.ZERO)
		if target == Vector2.ZERO:
			continue
		var fresh := 1.0 - float(tick - t) / TRAIL
		var to_word: bool = a["to"] == word
		var col := UiStyle.GOLD if to_word else UiStyle.MUTED
		var mine := int(a["id"]) == focus_id
		for s in a["sources"]:
			var from := _source_pos(int(s))
			if from == Vector2.ZERO:
				continue
			var alpha := (0.05 + 0.8 * fresh * fresh) if focus_id < 0 else (0.95 if mine else 0.05)
			_arrow(from, target, Color(col, alpha), (2.5 if mine else 1.6) * _k)

	# People
	for v: Villager in st.villagers:
		if not _pos.has(v.id):
			continue
		if v.is_helper and not _arrived(v.id):
			continue
		var p: Vector2 = _pos[v.id]
		var r := (5.0 if v.stage == Villager.Stage.CHILD else 7.0) * _k
		var says := Replay.variant_at(st, v.id, concept, tick) == word
		draw_circle(p, r, UiStyle.lang_color(v.home_lang))
		if says:
			draw_circle(p, r * 0.45, Color.WHITE)
			draw_arc(p, r + 2.5 * _k, 0, TAU, 24, UiStyle.GOLD, 2.5 * _k, true)
		if v.id == focus_id:
			draw_arc(p, r + 6.0 * _k, 0, TAU, 24, UiStyle.INK, 2.0 * _k, true)
			draw_string(font, p + Vector2(11, -9) * _k, v.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * _k), UiStyle.INK)

	var legend := to_screen(Vector2(12, 684))
	draw_string(font, legend, "Gold ring = says \"%s\".  Gold arrows = the voices that convinced someone to switch.  Gray arrows = switched back." % word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), UiStyle.MUTED)


func _arrived(id: int) -> bool:
	return tick >= int(_helper_arrival.get(id, 0))


func _sign_up(source: int) -> bool:
	return tick >= int(_sign_time.get(source, 0))


func _source_pos(source: int) -> Vector2:
	if source < 0:
		if signs.has(source):
			var pl: Place = st.place_by_id[signs[source]]
			return to_screen(pl.pos)
		return Vector2.ZERO
	return _pos.get(source, Vector2.ZERO)


func _layout() -> void:
	_pos.clear()
	var groups := {}
	for v: Villager in st.villagers:
		if not groups.has(v.home_place):
			groups[v.home_place] = []
		groups[v.home_place].append(v)
	for pid in groups:
		var pl: Place = st.place_by_id[pid]
		var members: Array = groups[pid]
		members.sort_custom(func(x, y): return x.id < y.id)
		var top_left := pl.pos - pl.box * 0.5 + Vector2(16, 34)
		for i in members.size():
			_pos[members[i].id] = to_screen(top_left + Vector2(i * 22, 0))


func _arrow(from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var dir := (to - from)
	if dir.length() < 1.0:
		return
	var n := dir.normalized()
	var end := to - n * 9.0 * _k
	# Slight curve so arrows between the same homes don't overlap
	var mid := (from + end) * 0.5 + Vector2(-n.y, n.x) * dir.length() * 0.12
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(from.lerp(mid, t).lerp(mid.lerp(end, t), t))
	draw_polyline(pts, col, width, true)
	var tip_dir := (end - pts[10]).normalized()
	var side := Vector2(-tip_dir.y, tip_dir.x)
	draw_colored_polygon(PackedVector2Array([end, end - tip_dir * 8.0 * _k + side * 4.0 * _k, end - tip_dir * 8.0 * _k - side * 4.0 * _k]), col)
