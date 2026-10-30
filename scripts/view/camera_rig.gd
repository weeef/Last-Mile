class_name CameraRig
extends Node3D
## Orbit camera. Left-drag or WASD to pan, right-drag or Q/E to rotate,
## scroll to zoom. Smoothly eases toward its targets.

signal clicked(screen_pos: Vector2)

const HOME_TARGET := Vector3(0, 0, 6)
const HOME_YAW := -35.0
const HOME_PITCH := -48.0
const HOME_DIST := 95.0

var camera: Camera3D
var target := HOME_TARGET
var yaw := HOME_YAW
var pitch := HOME_PITCH
var dist := HOME_DIST
var _t_target := HOME_TARGET
var _t_yaw := HOME_YAW
var _t_pitch := HOME_PITCH
var _t_dist := HOME_DIST

var _dragging_left := false
var _dragging_right := false
var _press_pos := Vector2.ZERO
var _moved := 0.0
var follow: Callable = Callable()   # returns a Vector3 to follow, or null


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.5
	camera.far = 500.0
	add_child(camera)
	_apply()


func zoom(f: float) -> void:
	_t_dist = clampf(_t_dist * f, 14.0, 130.0)


func rotate_by(deg: float) -> void:
	_t_yaw += deg


func home() -> void:
	_t_target = HOME_TARGET
	_t_yaw = HOME_YAW
	_t_pitch = HOME_PITCH
	_t_dist = HOME_DIST
	follow = Callable()


func focus(p: Vector3) -> void:
	_t_target = Vector3(p.x, 0, p.z)
	_t_dist = minf(_t_dist, 42.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(1.1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_left = mb.pressed
			if mb.pressed:
				_press_pos = mb.position
				_moved = 0.0
			elif _moved < 6.0:
				clicked.emit(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging_right = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging_left:
			_moved += mm.relative.length()
			if _moved >= 6.0:
				follow = Callable()
				_pan(-mm.relative * _t_dist * 0.0016)
		elif _dragging_right:
			_t_yaw -= mm.relative.x * 0.3
			_t_pitch = clampf(_t_pitch - mm.relative.y * 0.2, -80.0, -22.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				rotate_by(-45.0)
			KEY_E:
				rotate_by(45.0)
			KEY_H:
				home()


func _pan(d: Vector2) -> void:
	var yr := deg_to_rad(_t_yaw)
	var right := Vector3(cos(yr), 0, -sin(yr))
	var fwd := Vector3(-sin(yr), 0, -cos(yr))
	_t_target += right * d.x - fwd * d.y
	var lim := City.HALF + 10.0
	_t_target.x = clampf(_t_target.x, -lim, lim)
	_t_target.z = clampf(_t_target.z, -lim, lim)


func _process(delta: float) -> void:
	var key_pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key_pan.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key_pan.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key_pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key_pan.x += 1
	if key_pan != Vector2.ZERO:
		follow = Callable()
		_pan(key_pan * _t_dist * 0.9 * delta)
	if follow.is_valid():
		var p = follow.call()
		if p is Vector3:
			_t_target = Vector3(p.x, 0, p.z)
	var k := 1.0 - exp(-delta * 8.0)
	target = target.lerp(_t_target, k)
	yaw = lerpf(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	dist = lerpf(dist, _t_dist, k)
	_apply()


func _apply() -> void:
	if camera == null:
		return
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	camera.transform = Transform3D(b, target + b.z * dist)
