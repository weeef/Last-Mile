extends Node3D
## Entry point. Owns the simulation clock and wires the sim, the 3D view,
## the camera, the HUD, the start screen and the tutorial together.

const SEED := 20261029

var sim: Sim
var world: WorldView
var cam: CameraRig
var hud: HUD
var layer: CanvasLayer
var speed := 0
var started := false
var _acc := 0.0
var _last_speed := 1


func _ready() -> void:
	sim = Sim.new()
	sim.setup(SEED, [])

	world = WorldView.new()
	add_child(world)
	world.setup(sim)

	cam = CameraRig.new()
	add_child(cam)
	cam.clicked.connect(_on_world_clicked)

	layer = CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	hud.setup(sim, self)

	var picker := StartScreen.new()
	layer.add_child(picker)
	picker.chosen.connect(_on_fleet_chosen.bind(picker))


func _on_fleet_chosen(vehicles: Array, tutorial: bool, picker: Control) -> void:
	picker.queue_free()
	submit_player({"type": "starter_fleet", "vehicles": vehicles})
	started = true
	set_speed(1)
	if tutorial:
		var t := Tutorial.new()
		layer.add_child(t)
		t.setup(sim, hud, self)


func _process(delta: float) -> void:
	if speed > 0:
		_acc += delta * speed * Sim.TICK_RATE
		var n := 0
		while _acc >= 1.0 and n < 400:
			sim.step()
			_acc -= 1.0
			n += 1
		if n >= 400:
			_acc = 0.0
	world.sync(_acc if speed > 0 else 1.0, delta, speed > 0)
	hud.refresh(speed, cam.camera, world)


func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
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
			KEY_ESCAPE:
				select_van(null)


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
	# Commands are applied on the next tick; nudge one through if paused so
	# buttons still respond while the clock is stopped.
	if speed == 0 and started:
		sim.step()


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


func _on_world_clicked(pos: Vector2) -> void:
	if not started:
		return
	select_van(world.pick_van(pos, cam.camera))
