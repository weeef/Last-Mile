class_name GameSettings
extends RefCounted
## Display + graphics settings. Saved to user://settings.cfg.
## On first launch a preset is picked from the detected GPU so the game
## starts playable on anything from an old laptop to a gaming rig.

const PATH := "user://settings.cfg"

const WINDOW_MODES := ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"]
const RESOLUTIONS := [Vector2i(0, 0), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]   # (0,0) = native
const UI_SCALES := [0.85, 1.0, 1.15, 1.3, 1.5]
const VSYNC := ["Off", "On", "Adaptive"]
const FPS_LIMITS := [30, 60, 120, 144, 0]   # 0 = unlimited
const PRESETS := ["Low", "Medium", "High", "Custom"]
const RENDER_SCALES := [0.5, 0.6, 0.75, 0.85, 1.0]
const MSAA := ["Off", "2x", "4x"]
const SHADOWS := ["Off", "Low", "High"]
const DETAIL := ["Low", "Medium", "High"]
const ONOFF := ["Off", "On"]

# Display
var window_mode := 1
var resolution := 0
var ui_scale := 1
var vsync := 1
var fps_limit := 1
# Graphics
var preset := 1
var render_scale := 4
var msaa := 1
var shadows := 1
var fog := 1
var detail := 1
var show_fps := 0
var first_run := true


static func preset_values(p: int) -> Dictionary:
	match p:
		0:  # Low: integrated graphics, old laptops
			return {"render_scale": 2, "msaa": 0, "shadows": 0, "fog": 0, "detail": 0}
		2:  # High
			return {"render_scale": 4, "msaa": 2, "shadows": 2, "fog": 1, "detail": 2}
		_:  # Medium
			return {"render_scale": 4, "msaa": 1, "shadows": 1, "fog": 1, "detail": 1}


func apply_preset(p: int) -> void:
	preset = p
	if p >= 3:
		return
	var v := preset_values(p)
	for k in v.keys():
		set(k, v[k])


## Marks the preset as Custom if the individual options no longer match it.
func refresh_preset() -> void:
	for p in 3:
		var v := preset_values(p)
		var same := true
		for k in v.keys():
			if get(k) != v[k]:
				same = false
		if same:
			preset = p
			return
	preset = 3


static func gpu_name() -> String:
	var n := RenderingServer.get_video_adapter_name()
	return n if n != "" else "Unknown GPU"


## Guess a sensible starting preset from the graphics adapter.
static func recommended_preset() -> int:
	var name := RenderingServer.get_video_adapter_name().to_lower()
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	var t := RenderingServer.get_video_adapter_type()
	if t == RenderingDevice.DEVICE_TYPE_CPU or name.contains("llvmpipe") or name.contains("swiftshader") \
			or name.contains("microsoft basic") or name.contains("software"):
		return 0
	if t == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return 0
	var igpu_words := ["intel", "uhd", "iris", "hd graphics", "vega 8", "vega 6", "radeon(tm) graphics",
		"radeon graphics", "adreno", "mali", "apple m1"]
	for w in igpu_words:
		if name.contains(w) or (w == "intel" and vendor.contains("intel")):
			return 1 if (name.contains("arc") or name.contains("iris xe") or name.contains("780m") or name.contains("680m")) else 0
	if t == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU or name.contains("rtx") or name.contains("rx 6") \
			or name.contains("rx 7") or name.contains("rx 9") or name.contains("gtx 16") or name.contains("arc a"):
		return 2
	return 1


func load_or_detect() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		apply_preset(recommended_preset())
		first_run = true
		return
	first_run = false
	for k in _keys():
		set(k, cf.get_value("settings", k, get(k)))


func save() -> void:
	var cf := ConfigFile.new()
	for k in _keys():
		cf.set_value("settings", k, get(k))
	cf.save(PATH)


func _keys() -> Array:
	return ["window_mode", "resolution", "ui_scale", "vsync", "fps_limit", "preset", "render_scale",
		"msaa", "shadows", "fog", "detail", "show_fps"]


func resolution_label(i: int) -> String:
	var r: Vector2i = RESOLUTIONS[i]
	if r == Vector2i.ZERO:
		var s := DisplayServer.screen_get_size()
		return "Native (%d×%d)" % [s.x, s.y]
	return "%d×%d" % [r.x, r.y]


## Applies window/display settings and the viewport-level graphics settings.
## World-level settings (shadows, fog, detail) are applied by WorldView.
func apply_display(win: Window) -> void:
	var headless := DisplayServer.get_name() == "headless"
	if not headless:
		var target_res: Vector2i = RESOLUTIONS[resolution]
		var screen := DisplayServer.screen_get_size()
		match window_mode:
			0:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				var size := screen if target_res == Vector2i.ZERO else target_res
				size = Vector2i(mini(size.x, screen.x), mini(size.y, screen.y))
				if size == screen:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
				else:
					DisplayServer.window_set_size(size)
					DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - size) / 2)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		var vs := [DisplayServer.VSYNC_DISABLED, DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE]
		DisplayServer.window_set_vsync_mode(vs[vsync])
	Engine.max_fps = FPS_LIMITS[fps_limit]
	win.content_scale_factor = UI_SCALES[ui_scale]
	win.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][msaa]
	# 3D render resolution. In fullscreen, a lower chosen resolution renders the
	# 3D scene at that size and upscales it, while the UI stays sharp.
	var scale: float = RENDER_SCALES[render_scale]
	if window_mode != 0 and RESOLUTIONS[resolution] != Vector2i.ZERO and not headless:
		var screen_h := float(DisplayServer.screen_get_size().y)
		scale *= clampf(RESOLUTIONS[resolution].y / screen_h, 0.25, 1.0)
	win.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	win.scaling_3d_scale = scale
