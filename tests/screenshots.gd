extends SceneTree
## Renders each screen to tests/output/*.png. Needs a display (or xvfb-run on Linux):
##   godot --script res://tests/screenshots.gd
var frames := 0
var stage := 0
var out := "res://tests/output/"

func _initialize() -> void:
	change_scene_to_file("res://ui/title_screen.tscn")

func snap(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out + name + ".png")
	print("saved ", name, " ", img.get_size())

func _process(_d: float) -> bool:
	frames += 1
	if frames < 8:
		return false
	frames = 0
	match stage:
		0:
			snap("1_title")
			change_scene_to_file("res://ui/charter_screen.tscn")
		1:
			snap("2_charter")
			var gs = root.get_node("GameSession")
			gs.set_charter("Families and Elders", gs.PRESETS["Families and Elders"])
			gs.seed_value = 1
			gs.start_run()
			change_scene_to_file("res://ui/game_screen.tscn")
		2:
			var game = current_scene
			game.map.hover_id = 5
			game._on_hover(5)
			game._refresh_all()
		3:
			snap("3_game_start")
			var game = current_scene
			var st: SimState = game.st
			NudgeSystem.build(st, SimState.CAFE)
			NudgeSystem.signage(st, SimState.MARKET, "fizzy drink", "pop")
			for i in 336 * 2 + 30:
				var over: bool = game.mgr.step()
				if st.tick % 28 == 0:
					game._refresh_metrics(false)
				if over:
					NudgeSystem.signage(st, SimState.CAFE, "stuffed flatbread", "sabrel")
					NudgeSystem.event(st, SimState.CAFE, "heritage")
			game.lens.select(1)
			game.map.concept = "stuffed flatbread"
			game.map.hover_id = 5
			game._refresh_all()
		4:
			snap("4_game_midyear")
			current_scene._finish()
		5:
			snap("5_end_report")
			change_scene_to_file("res://ui/replay_screen.tscn")
		6:
			var rp = current_scene
			rp.word_pick.select(1)
			rp._set_concept("stuffed flatbread")
			rp._seek(rp.st.tick - 3 * 28)
			rp._next_switch()
		7:
			snap("6_replay")
			var rp = current_scene
			rp.whatif_pick.select(rp.whatif_pick.get_item_index(2))
			rp._run_whatif()
			rp._focus(-1)
			rp.map.focus_id = -1
		8:
			if current_scene.worker != null:
				return false
		9:
			snap("7_whatif")
			quit()
			return true
	stage += 1
	return false
