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
			gs.seed_value = 42
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
					NudgeSystem.helper(st)
					NudgeSystem.event(st, SimState.CAFE, "heritage")
			game.map.hover_id = 100
			game._refresh_all()
		4:
			snap("4_game_midyear")
			current_scene._finish()
		5:
			snap("5_end_report")
			quit()
			return true
	stage += 1
	return false
