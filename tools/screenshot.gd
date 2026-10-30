extends SceneTree
## Renders the game and saves a PNG.
## Usage: -s tools/screenshot.gd -- out.png <mode> <ticks>
##   mode: title | picker | hq | settings | briefing | play | route | report | rain | wide
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
	if frame == 2:
		match mode:
			"picker": main._on_new_game(1)
			"hq": main._show_hq(main._show_title)
			"settings": main.open_settings()
	if frame == 3 and mode not in ["title", "picker", "hq", "settings"]:
		main.slot = 1
		main._begin_run(main.profile.make_run("courier", 0), 20261029)
		main._on_fleet_chosen([&"van", &"box"], false)
	if frame == 5 and mode not in ["title", "picker", "hq", "settings", "briefing"]:
		var sim: Sim = main.sim
		if mode == "rain":
			sim.weather = 1
		if mode == "report":
			AutoPlayer.run(sim, ticks)
			while sim.phase != Sim.Phase.EVENING:
				if sim.phase == Sim.Phase.MORNING or sim.phase == Sim.Phase.NIGHT:
					AutoPlayer.act(sim, 1)
				if sim.clock_running(): sim.step()
		else:
			AutoPlayer.run(sim, ticks)
			main.speed = 0
		if mode == "route":
			var p := sim.player()
			var found: Van = null
			for k in 4000:
				for v in p.vans:
					if v.state == Van.State.LOADING and v.cargo.size() >= 4:
						found = v
				if found: break
				if k % 40 == 0 and p.active_jobs().is_empty():
					for j in p.offers():
						sim.submit({"type": "accept_job", "company": 0, "job": j.id}); break
				if sim.clock_running(): sim.step()
				else: AutoPlayer.act(sim, 0)
			if found: main.select_van(found)
		elif mode in ["play", "rain"]:
			for v in sim.player().vans:
				if v.on_road():
					main.select_van(v); break
	if frame == 100:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
		quit()
	return false
