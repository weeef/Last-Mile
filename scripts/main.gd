extends Node3D
## Entry point. Owns the clock and the current session (sim + world + HUD),
## and moves between the title screen, run setup, a new season, loading, the
## pause menu and the end-of-run summary. Also owns the persistent Profile.

const SEED := 20261029

var sim: Sim
var world: WorldView
var cam: CameraRig
var hud: HUD
var layer: CanvasLayer
var settings := GameSettings.new()
var speed := 0
var started := false          # a company is running (not on the title screen)
var slot := 1                 # save slot of the running company
var _acc := 0.0
var _last_speed := 1
var _overlay: Control = null  # title / start screen / pause menu
var _settings_menu: SettingsMenu = null
var _tutorial: Tutorial = null
var _want_tutorial := false
var profile := Profile.load_or_new()


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	settings.load_or_detect()
	cam = CameraRig.new()
	add_child(cam)
	cam.clicked.connect(_on_world_clicked)
	layer = CanvasLayer.new()
	add_child(layer)
	_show_title()
	if settings.first_run:
		settings.save()


# ------------------------------------------------------------- sessions

## Replaces the running sim (and its world + HUD) with a new one.
func _set_session(new_sim: Sim) -> void:
	if world:
		world.queue_free()
	if hud:
		hud.queue_free()
	if _tutorial and is_instance_valid(_tutorial):
		_tutorial.queue_free()
	_tutorial = null
	sim = new_sim
	world = WorldView.new()
	add_child(world)
	world.setup(sim)
	hud = HUD.new()
	layer.add_child(hud)
	layer.move_child(hud, 0)
	hud.setup(sim, self)
	sim.event.connect(_on_sim_event)
	apply_settings()
	_acc = 0.0


func _set_overlay(c: Control) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = c
	if c:
		layer.add_child(c)


func _show_title() -> void:
	started = false
	speed = 0
	var backdrop := Sim.new()
	backdrop.setup(SEED, [])
	_set_session(backdrop)
	hud.visible = false
	cam.home()
	var t := TitleScreen.new()
	t.profile = profile
	t.new_game.connect(_on_new_game)
	t.daily_game.connect(_on_daily_game)
	t.hq_requested.connect(func(): _show_hq(_show_title))
	t.load_game.connect(_on_load_game)
	t.settings_requested.connect(open_settings)
	t.quit_requested.connect(_quit)
	_set_overlay(t)


func _show_hq(back: Callable) -> void:
	var h := HQScreen.new()
	h.setup(profile)
	h.closed.connect(back)
	_set_overlay(h)


## New season: pick a charter and heat, then (maybe) the starting vehicles.
func _on_new_game(p_slot: int) -> void:
	slot = p_slot
	var rs := RunSetup.new()
	rs.setup(profile)
	rs.chosen.connect(func(charter_id: String, heat: int):
		_begin_run(profile.make_run(charter_id, heat), randi()))
	rs.hq_requested.connect(func(): _show_hq(func(): _on_new_game(p_slot)))
	rs.back_requested.connect(_show_title)
	_set_overlay(rs)


## Today's daily run: same seed, charter and heat for everyone, no HQ upgrades.
func _on_daily_game(p_slot: int) -> void:
	slot = p_slot
	var dn := Season.daily_number()
	var r := profile.make_run(Season.daily_charter(dn), Season.DAILY_HEAT, true)
	r["daily_number"] = dn
	profile.mark_daily(dn)
	_begin_run(r, Season.daily_seed(dn))


func _begin_run(run_cfg: Dictionary, run_seed: int) -> void:
	var s := Sim.new()
	s.setup(run_seed, [], run_cfg)
	_set_session(s)
	hud.visible = true
	cam.home()
	var ch := Season.charter(run_cfg["charter"])
	if ch.has("fleet"):
		_on_fleet_chosen(ch["fleet"], false)
		return
	var picker := StartScreen.new()
	picker.cash = s.player().money
	picker.charter_name = ch["name"]
	picker.chosen.connect(_on_fleet_chosen)
	picker.back_requested.connect(_show_title)
	_set_overlay(picker)


func _on_fleet_chosen(vehicles: Array, tutorial: bool) -> void:
	_set_overlay(null)
	started = true
	_want_tutorial = tutorial
	submit_player({"type": "starter_fleet", "vehicles": vehicles})   # opens the first briefing
	save_game()


## The season is over (evicted or survived): bank the results, free the slot.
func _finish_run() -> void:
	speed = 0
	select_van(null)
	var result := sim.run_result
	var changes := profile.record_run(result)
	SaveGame.delete(slot)
	started = false
	var rs := RunSummary.new()
	rs.setup(result, changes, profile, sim.report)
	rs.again_requested.connect(func():
		if result.get("daily", false):
			_show_title()
		else:
			_on_new_game(slot))
	rs.title_requested.connect(_show_title)
	_set_overlay(rs)


func _on_load_game(p_slot: int) -> void:
	var loaded := SaveGame.load_slot(p_slot)
	if loaded == null:
		return
	slot = p_slot
	_set_overlay(null)
	_set_session(loaded)
	hud.visible = true
	cam.home()
	started = true
	speed = 0
	_last_speed = 1
	_show_phase_overlay()


func save_game() -> bool:
	if not started:
		return false
	return SaveGame.save(sim, slot)


func _on_sim_event(n: String, _d: Dictionary) -> void:
	if not started:
		return
	match n:
		"morning":
			save_game()
			_show_phase_overlay()
		"evening":
			_show_phase_overlay()
		"day_begun":
			_set_overlay(null)
			set_speed(_last_speed)
			if _want_tutorial:
				_want_tutorial = false
				_tutorial = Tutorial.new()
				layer.add_child(_tutorial)
				_tutorial.setup(sim, hud, self)
		"night":
			_set_overlay(null)
		"run_over":
			_finish_run()


## Shows the briefing or the evening report if the sim is waiting on one.
func _show_phase_overlay() -> void:
	select_van(null)
	if sim.phase == Sim.Phase.MORNING:
		speed = 0
		var b := Briefing.new()
		_set_overlay(b)
		b.setup(sim, self)
	elif sim.phase == Sim.Phase.EVENING:
		speed = 0
		var r := DayReport.new()
		_set_overlay(r)
		r.setup(sim, self)
	elif sim.phase == Sim.Phase.DAY:
		set_speed(_last_speed)
	elif sim.phase == Sim.Phase.OVER:
		_finish_run()


# ------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if not started:
		cam.rotate_by(delta * 2.5)   # slow orbit behind the title screen
	if started and sim.phase == Sim.Phase.NIGHT:
		# The night shift runs on its own: fast-forward to the next morning.
		var k := 0
		while sim.phase == Sim.Phase.NIGHT and k < 1500:
			sim.step()
			k += 1
	elif speed > 0 and sim.clock_running():
		_acc += delta * speed * Sim.TICK_RATE
		var n := 0
		while _acc >= 1.0 and n < 400 and sim.clock_running():
			sim.step()
			_acc -= 1.0
			n += 1
		if n >= 400 or not sim.clock_running():
			_acc = 0.0
	world.sync(_acc if speed > 0 else 1.0, delta, speed > 0)
	if hud.visible:
		hud.refresh(speed, cam.camera, world)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:
	save_game()
	settings.save()
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not started or _overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if world.selected_van != null:
					select_van(null)
				else:
					open_pause()
			KEY_SPACE:
				set_speed(_last_speed if speed == 0 else 0)
			KEY_1:
				set_speed(1)
			KEY_2:
				set_speed(2)
			KEY_3:
				set_speed(4)
			KEY_4:
				set_speed(8)


# ------------------------------------------------------------- menus

func open_pause() -> void:
	var resume_speed := speed if speed > 0 else _last_speed
	speed = 0
	var m := PauseMenu.new()
	m.slot = slot
	m.resume.connect(func():
		_set_overlay(null)
		set_speed(resume_speed))
	m.save_requested.connect(func(): m.show_saved(save_game()))
	m.settings_requested.connect(open_settings)
	m.title_requested.connect(func():
		save_game()
		_show_title())
	m.quit_requested.connect(_quit)
	_set_overlay(m)


func apply_settings() -> void:
	settings.apply_display(get_window())
	if world:
		world.apply_graphics(settings)
	if hud:
		hud.show_fps = settings.show_fps == 1


func open_settings() -> void:
	if _settings_menu != null:
		return
	_settings_menu = SettingsMenu.new()
	layer.add_child(_settings_menu)
	_settings_menu.setup(settings, self)
	_settings_menu.closed.connect(func(): _settings_menu = null)


# ------------------------------------------------------------- called by the UI

func set_speed(s: int) -> void:
	if not started:
		return
	if s > 0:
		_last_speed = s
	speed = s


func submit_player(cmd: Dictionary) -> void:
	cmd["company"] = Sim.PLAYER
	sim.submit(cmd)
	# Commands normally apply on the next tick; apply them right away while
	# the clock is stopped so buttons still respond.
	if started and (speed == 0 or not sim.clock_running()):
		sim.apply_commands_now()


func select_van(v: Van) -> void:
	world.selected_van = v
	hud.select(v)
	if v != null:
		cam.focus(world.van_render_pos(v))
		cam.follow = func(): return world.van_render_pos(v)
	else:
		cam.follow = Callable()


func camera_tool(key: String) -> void:
	match key:
		"plus":
			cam.zoom(0.8)
		"minus":
			cam.zoom(1.25)
		"rot_l":
			cam.rotate_by(-45.0)
		"rot_r":
			cam.rotate_by(45.0)
		"home":
			cam.home()
		"gear":
			if started:
				open_pause()
			else:
				open_settings()


func _on_world_clicked(pos: Vector2) -> void:
	if not started or _overlay != null:
		return
	select_van(world.pick_van(pos, cam.camera))
