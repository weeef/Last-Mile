extends SceneTree
## Renders the game and saves a PNG.
## Usage: -s tools/screenshot.gd -- out.png <mode> <ticks>
##   mode: title | picker | tutorial | play | wide | low | settings
var main: Node
var frame := 0
var out := "shot.png"
var mode := "play"
var ticks := 1800

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	if args.size() > 1: mode = args[1]
	if args.size() > 2: ticks = int(args[2])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2 and mode == "settings":
		main.open_settings()
	if frame == 2 and mode == "low":
		main.settings.apply_preset(0)
		main.apply_settings()
	if frame == 2 and mode == "picker":
		main._on_new_game(1)
	if frame == 3 and mode not in ["picker", "settings", "title"]:
		main._on_new_game(1)
		main._on_fleet_chosen([&"van", &"box"], mode == "tutorial")
		main.set_speed(0)
	if frame == 5 and mode not in ["picker", "settings", "title"]:
		var sim: Sim = main.sim
		var p := sim.player()
		for i in ticks:
			if i % 40 == 0 and mode != "tutorial":
				if p.active_jobs().size() < 1 and p.backlog() < 10:
					for j in p.offers():
						if not j.needs_liftgate() or true:
							sim.submit({"type": "accept_job", "company": 0, "job": j.id}); break
				for v in p.vans:
					if v.ready: sim.submit({"type": "start_route", "company": 0, "van": v.id})
					if v.state == Van.State.IDLE and v.condition < 0.45:
						sim.submit({"type": "service_van", "company": 0, "van": v.id})
			sim.step()
		if mode == "play":
			for v in p.vans:
				if v.on_road():
					main.select_van(v); break
	if frame == 90:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
	return false
