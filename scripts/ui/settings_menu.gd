class_name SettingsMenu
extends Control
## Display + graphics settings sheet. Changes apply immediately and are saved.

signal closed

var settings: GameSettings
var main: Node
var _rows := {}          # key -> {"label": Label, "options": Array}
var _card: Control
var _gpu: Label


func setup(p_settings: GameSettings, p_main: Node) -> void:
	settings = p_settings
	main = p_main
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var card := UIKit.paper(22)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 7
	var v := UIKit.vbox(6)
	card.add_child(v)
	var top := UIKit.hbox(10)
	top.add_child(UIKit.head("Settings", 32, Palette.TEXT))
	top.add_child(UIKit.spacer())
	var x := UIKit.button("×", "paper", 18)
	x.custom_minimum_size = Vector2(34, 34)
	x.pressed.connect(close)
	top.add_child(x)
	v.add_child(top)

	v.add_child(UIKit.head("Display", 16, Palette.TEXT_SOFT))
	_row(v, "window_mode", "Window mode", GameSettings.WINDOW_MODES)
	var res_labels: Array = []
	for i in GameSettings.RESOLUTIONS.size():
		res_labels.append(settings.resolution_label(i))
	_row(v, "resolution", "Resolution", res_labels)
	_row(v, "ui_scale", "UI scale", GameSettings.UI_SCALES.map(func(s): return "%d%%" % int(s * 100)))
	_row(v, "vsync", "VSync", GameSettings.VSYNC)
	_row(v, "fps_limit", "FPS limit", GameSettings.FPS_LIMITS.map(func(f): return "Unlimited" if f == 0 else str(f)))
	v.add_child(UIKit.rule())
	v.add_child(UIKit.head("Graphics", 16, Palette.TEXT_SOFT))
	_row(v, "preset", "Quality preset", GameSettings.PRESETS, true)
	_row(v, "render_scale", "3D render scale", GameSettings.RENDER_SCALES.map(func(s): return "%d%%" % int(s * 100)))
	_row(v, "msaa", "Anti-aliasing", GameSettings.MSAA)
	_row(v, "shadows", "Shadows", GameSettings.SHADOWS)
	_row(v, "fog", "Distance fog", GameSettings.ONOFF)
	_row(v, "detail", "Scenery detail", GameSettings.DETAIL)
	_row(v, "show_fps", "Show FPS", GameSettings.ONOFF)
	v.add_child(UIKit.rule())
	_gpu = UIKit.label("", 12, Palette.TEXT_SOFT)
	_gpu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gpu.custom_minimum_size.x = 470
	v.add_child(_gpu)
	var actions := UIKit.hbox(8)
	var rec := UIKit.button("Use recommended", "paper", 15)
	rec.tooltip_text = "Pick the preset that suits this PC's graphics card"
	rec.pressed.connect(func():
		settings.apply_preset(GameSettings.recommended_preset())
		_changed())
	actions.add_child(rec)
	actions.add_child(UIKit.spacer())
	var done := UIKit.button("Done", "go", 16)
	done.custom_minimum_size = Vector2(110, 36)
	done.pressed.connect(close)
	actions.add_child(done)
	v.add_child(actions)
	add_child(card)
	_card = card
	_refresh()


func _row(parent: Control, key: String, title: String, options: Array, bold := false) -> void:
	var h := UIKit.hbox(8)
	var l := UIKit.label(title, 15, Palette.TEXT, "bold" if bold else "body")
	l.custom_minimum_size.x = 170
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	h.add_child(UIKit.spacer())
	var prev := UIKit.button("‹", "paper", 18)
	prev.custom_minimum_size = Vector2(32, 30)
	prev.pressed.connect(func(): _step(key, -1, options.size()))
	h.add_child(prev)
	var val := UIKit.head("", 17, Palette.TEXT)
	val.custom_minimum_size.x = 200
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(val)
	var next := UIKit.button("›", "paper", 18)
	next.custom_minimum_size = Vector2(32, 30)
	next.pressed.connect(func(): _step(key, 1, options.size()))
	h.add_child(next)
	parent.add_child(h)
	_rows[key] = {"label": val, "options": options}


func _step(key: String, dir: int, n: int) -> void:
	if key == "preset":
		# Cycle Low / Medium / High only; Custom is reached by tweaking options.
		var p := settings.preset
		p = (0 if p >= 3 else p) + dir
		settings.apply_preset(wrapi(p, 0, 3))
	else:
		settings.set(key, wrapi(int(settings.get(key)) + dir, 0, n))
		if key in ["render_scale", "msaa", "shadows", "fog", "detail"]:
			settings.refresh_preset()
	_changed()


func _changed() -> void:
	main.apply_settings()
	_refresh()


func _refresh() -> void:
	for key in _rows.keys():
		var r: Dictionary = _rows[key]
		var opts: Array = r["options"]
		(r["label"] as Label).text = String(opts[clampi(int(settings.get(key)), 0, opts.size() - 1)]).to_upper()
	var rec: String = GameSettings.PRESETS[GameSettings.recommended_preset()]
	_gpu.text = "Graphics card: %s  ·  recommended preset: %s. Lower resolution or render scale gives the biggest speed-up on older PCs." % [GameSettings.gpu_name(), rec]


func close() -> void:
	settings.save()
	closed.emit()
	queue_free()


func _process(_d: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((vp - _card.size) * 0.5).floor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
