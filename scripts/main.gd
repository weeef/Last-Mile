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
var audio: GameAudio
var hints: Hints
var _help: HelpScreen = null
var _hint_speed := 0
var skipping := false         # fast-forward until something needs the player
var _skip_ready := 0
const SKIP_SPEED := 16
const SKIP_STOP_EVENTS := ["call", "rush_order", "breakdown", "job_arrived", "van_home", "streak_broken", "contract_done", "route_combo", "route_bust"]


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	settings.load_or_detect()
	audio = GameAudio.new()
	add_child(audio)
	cam = CameraRig.new()
	add_child(cam)
	cam.clicked.connect(_on_world_clicked)
	layer = CanvasLayer.new()
	add_child(layer)
	hints = Hints.new()
	hints.profile = profile
	layer.add_child(hints)
	hints.opened.connect(func():
		if speed > 0:
			_hint_speed = speed
			speed = 0)
	hints.dismissed.connect(func():
		if _hint_speed > 0 and started and _overlay == null:
			set_speed(_hint_speed)
		_hint_speed = 0)
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
	sim.parcel_delivered.connect(_on_delivered_sound)
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
	GameAudio.music("title")
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
	if skipping and n in SKIP_STOP_EVENTS:
		_stop_skip()
	_event_sound(n, _d)
	_event_hint(n, _d)
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
		"call":
			_show_call()
		"call_answered":
			if _overlay is CallPopup:
				_set_overlay(null)
		"run_over":
			_finish_run()


# ------------------------------------------------------------- audio

## Sound and music cues for sim events (the sim itself stays silent).
func _event_sound(n: String, d: Dictionary) -> void:
	match n:
		"morning":
			GameAudio.music("desk")
			if not sim.morning_event.is_empty():
				GameAudio.sfx("event")
		"day_begun":
			GameAudio.music("peak" if sim.today_type == "boss" or sim.is_peak_day() else "day")
		"evening":
			GameAudio.music("desk")
			var ultra := false
			for id in sim.draft:
				ultra = ultra or Cards.get_card(id)["rarity"] >= Cards.Rarity.ULTRA
			GameAudio.sfx("ultra" if ultra else "reveal")
			var lease: Dictionary = d.get("lease", {})
			if lease.get("paid", false):
				GameAudio.sfx("rent_paid")
			elif lease.get("strike", false):
				GameAudio.sfx("notice")
			elif d.get("contract_done", false):
				GameAudio.sfx("coin")
		"run_over":
			GameAudio.music("title")
			GameAudio.sfx("win" if d.get("won", false) else "evicted")
		"route_combo":
			GameAudio.sfx("jackpot" if d["mult"] >= 2.0 else "cash")
		"route_bust":
			GameAudio.sfx("bust", 1.0, -3.0)
		"streak_tier":
			GameAudio.sfx("streak", 1.0 + minf(d["streak"], 40) / 80.0)
		"streak_broken":
			GameAudio.sfx("streak_break")
		"breakdown":
			if d["van"].company == Sim.PLAYER:
				GameAudio.sfx("breakdown")
		"tow":
			if d["van"].company == Sim.PLAYER:
				GameAudio.sfx("tow", 1.0, -3.0)
		"not_home":
			if d["van"].company == Sim.PLAYER:
				GameAudio.sfx("doorbell", 1.0, -6.0)
		"rush_order":
			GameAudio.sfx("rush", 1.0, -3.0)
		"ability":
			GameAudio.sfx("power")
		"call":
			GameAudio.sfx("phone")
		"staff_hired":
			GameAudio.sfx("stamp")
		"van_departed":
			if d["van"].company == Sim.PLAYER:
				GameAudio.sfx("depart", randf_range(0.92, 1.08), -10.0)
		"contract_done", "level_up":
			GameAudio.sfx("level_up")
		"event_resolved":
			GameAudio.sfx("stamp")
		"card_applied":
			var rar: int = Cards.get_card(d["card"])["rarity"]
			GameAudio.sfx("relic" if rar == Cards.Rarity.RELIC else ("ultra" if rar == Cards.Rarity.ULTRA else "confirm"))
		"draft_rerolled":
			GameAudio.sfx("reveal")
		"shop_changed":
			GameAudio.sfx("coin")
		"plan_tomorrow":
			GameAudio.sfx("card")


## The delivery "ding" climbs a pentatonic scale as the streak grows (two octaves).
func _on_delivered_sound(p: Parcel, v: Van, _pay: float) -> void:
	if not started or v.company != Sim.PLAYER:
		return
	if p.late:
		GameAudio.sfx("late", 1.0, -4.0)
	else:
		var step := mini(maxi(sim.streak - 1, 0), 9)
		var semis: float = PENTATONIC[step % 5] + 12.0 * (step / 5)
		GameAudio.sfx("ding", 0.75 * pow(2.0, semis / 12.0), -7.0)


const PENTATONIC := [0.0, 2.0, 4.0, 7.0, 9.0]


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
	elif sim.phase == Sim.Phase.DAY and not sim.pending_call.is_empty():
		_show_call()
	elif sim.phase == Sim.Phase.DAY:
		set_speed(_last_speed)
	elif sim.phase == Sim.Phase.OVER:
		_finish_run()


# ------------------------------------------------------------- frame

func _process(delta: float) -> void:
	if not started:
		cam.rotate_by(delta * 2.5)   # slow orbit behind the title screen
	if skipping:
		var ready := _ready_count()
		if sim.phase != Sim.Phase.DAY:
			skipping = false      # the evening sheet already stopped the clock
		elif ready > _skip_ready:
			_stop_skip()
		else:
			_skip_ready = ready
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
	_update_ambience()
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
	if started and _help == null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		open_help()
		return
	if not started or _overlay != null or _help != null:
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
			KEY_F:
				skip_ahead()
			KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B:
				var key := OS.get_keycode_string(event.keycode)
				for id in Abilities.ORDER:
					if Abilities.DATA[id]["key"] == key:
						hud.use_power(id)


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
	m.help_requested.connect(open_help)
	m.title_requested.connect(func():
		save_game()
		_show_title())
	m.quit_requested.connect(_quit)
	_set_overlay(m)


## The handbook (? button, F1, pause menu). Pauses while open.
func open_help() -> void:
	if _help != null or sim == null:
		return
	var resume := speed
	speed = 0
	_help = HelpScreen.new()
	_help.setup(sim)
	layer.add_child(_help)
	_help.closed.connect(func():
		_help.queue_free()
		_help = null
		if resume > 0 and _overlay == null:
			set_speed(resume))


## The phone rings: a call sheet you must answer (the sim clock waits for it).
func _show_call() -> void:
	select_van(null)
	var c := CallPopup.new()
	c.setup(sim, self)
	_set_overlay(c)


## Town ambience follows the clock and weather; engines hum when the camera is close.
func _update_ambience() -> void:
	var h := sim.minute_of_day() / 60.0
	var night := h < 6.0 or h >= 20.5
	GameAudio.ambience(night, sim.weather == 1)
	var level := 0.0
	if started and speed > 0:
		var cp := cam.camera.global_position
		for v in sim.player().vans:
			if v.on_road() or v.state == Van.State.RESCUE:
				var d := cp.distance_to(world.van_render_pos(v))
				level = maxf(level, clampf(1.0 - (d - 10.0) / 45.0, 0.0, 1.0))
	GameAudio.engine(level)


## First-time tips for sim events.
func _event_hint(n: String, d: Dictionary) -> void:
	match n:
		"day_begun":
			if not _want_tutorial and _tutorial == null:
				hints.trigger("first_day")
			if sim.day() >= 2 and not sim.applicants.is_empty():
				hints.trigger("staff")
			if sim.today_type == "boss":
				hints.trigger("boss")
			elif sim.twist != "":
				hints.trigger("twist")
		"job_arrived":
			hints.trigger("job_arrived")
		"call":
			hints.trigger("call")
		"not_home":
			if d["van"].company == Sim.PLAYER:
				hints.trigger("not_home")
		"breakdown":
			if d["van"].company == Sim.PLAYER:
				hints.trigger("breakdown")
		"rush_order":
			hints.trigger("rush")
		"evening":
			hints.trigger({"shop": "shop", "relic": "relic"}.get(sim.evening_stage, "draft"))
		"plan_tomorrow":
			hints.trigger("plan")
		"route_combo", "route_bust":
			hints.trigger("combo")
		"streak_tier":
			hints.trigger("streak")
		"morning":
			if not sim.morning_event.is_empty():
				hints.trigger("event")
		"level_up":
			hints.trigger("level")
		"delivered":
			if d["parcel"].late and d["van"].company == Sim.PLAYER:
				hints.trigger("late")
			elif d["van"].company == Sim.PLAYER and sim.hustle >= sim.hustle_cap():
				hints.trigger("hustle")


func apply_settings() -> void:
	settings.apply_display(get_window())
	if world:
		world.apply_graphics(settings)
	if hud:
		hud.show_fps = settings.show_fps == 1
	if audio:
		audio.set_volumes(settings.master_volume / 10.0, settings.music_volume / 10.0, settings.sfx_volume / 10.0, settings.ambience_volume / 10.0)


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
	skipping = false
	if s > 0:
		_last_speed = s
	speed = s


## Mini Metro style: run the clock fast until a decision is waiting.
func skip_ahead() -> void:
	if not started or sim.phase != Sim.Phase.DAY:
		return
	if skipping:
		_stop_skip()
		return
	var resume := _last_speed
	_skip_ready = _ready_count()
	speed = SKIP_SPEED
	skipping = true
	_last_speed = resume


func _stop_skip() -> void:
	skipping = false
	speed = _last_speed


func _ready_count() -> int:
	var n := 0
	for v in sim.player().vans:
		if v.ready:
			n += 1
	return n


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
