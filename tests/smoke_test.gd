extends SceneTree
## Loads every screen and plays a full year with nudges through the real UI scene.
## Run: godot --headless --script res://tests/smoke_test.gd

var frames := 0
var stage := 0

func _initialize() -> void:
	print("smoke: title")
	change_scene_to_file("res://ui/title_screen.tscn")

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	frames = 0
	match stage:
		0:
			print("smoke: charter")
			change_scene_to_file("res://ui/charter_screen.tscn")
		1:
			var gs = root.get_node("GameSession")
			gs.set_charter("Families and Elders", gs.PRESETS["Families and Elders"])
			gs.seed_value = 42
			gs.start_run()
			print("smoke: game")
			change_scene_to_file("res://ui/game_screen.tscn")
		2:
			var game = current_scene
			var st: SimState = game.st
			assert(NudgeSystem.build(st, SimState.CAFE))
			assert(NudgeSystem.signage(st, SimState.MARKET, "fizzy drink", "pop"))
			game._refresh_all()
			game._on_hover(5)
			game._on_click(8)
			game._on_click(26)
			game._do_intro()
			# Play the whole year through the screen's own loop logic
			while not st.is_finished():
				var over: bool = game.mgr.step()
				if st.tick % SimState.TICKS_PER_WEEK == 0:
					game._refresh_metrics(false)
				if over and not st.is_finished():
					NudgeSystem.helper(st)
					NudgeSystem.event(st, SimState.PARK, "heritage")
			game._refresh_all()
			game.map.queue_redraw()
			print("smoke: year done, score ", int(gs_score()), ", news items ", st.event_log.size(), ", adoptions ", st.adoptions.size())
			game._finish()
		3:
			print("smoke: end report shown: ", current_scene.name)
			print("SMOKE OK")
			quit()
			return true
	stage += 1
	return false

func gs_score() -> float:
	return root.get_node("GameSession").current_score()
