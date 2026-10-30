class_name Tutorial
extends Control
## A short guided walkthrough: take a job, wait for the vendor, load up,
## start a route. Each step watches the game state and advances on its own.

var sim: Sim
var hud: HUD
var main: Node
var steps: Array = []
var index := -1
var _note: PanelContainer
var _step_label: Label
var _title: Label
var _body: Label
var _next: Button
var _target: Control = null
var _time := 0.0
var _flags := {}


func setup(p_sim: Sim, p_hud: HUD, p_main: Node) -> void:
	sim = p_sim
	hud = p_hud
	main = p_main
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sim.event.connect(func(n: String, _d: Dictionary): _flags[n] = true)
	_build_note()
	_define_steps()
	_go(0)


func _build_note() -> void:
	_note = PanelContainer.new()
	var s := UIKit.paper_style(Color("f6efd9"), 16, 6)
	_note.add_theme_stylebox_override("panel", s)
	_note.mouse_filter = Control.MOUSE_FILTER_STOP
	_note.custom_minimum_size = Vector2(340, 0)
	var v := UIKit.vbox(6)
	_note.add_child(v)
	var top := UIKit.hbox(8)
	_step_label = UIKit.mono("", 12, Palette.TEXT_SOFT, true)
	top.add_child(_step_label)
	top.add_child(UIKit.spacer())
	var skip := Button.new()
	skip.text = "skip tutorial"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", UIKit.font("head_semi"))
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	skip.add_theme_color_override("font_hover_color", Palette.RED)
	skip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip.pressed.connect(_finish)
	top.add_child(skip)
	v.add_child(top)
	_title = UIKit.head("", 24, Palette.TEXT)
	v.add_child(_title)
	_body = UIKit.label("", 14, Palette.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 308
	v.add_child(_body)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.spacer())
	_next = UIKit.button("Next", "go", 16)
	_next.pressed.connect(func(): _go(index + 1))
	row.add_child(_next)
	v.add_child(row)
	add_child(_note)
	# two strips of masking tape
	for k in 2:
		var tape := ColorRect.new()
		tape.color = Color("e8d9a8", 0.85)
		tape.size = Vector2(70, 20)
		tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tape.rotation_degrees = -12.0 if k == 0 else 10.0
		tape.name = "Tape%d" % k
		_note.add_child(tape)
		tape.top_level = true


func _any_van(f: Callable) -> bool:
	for v in sim.player().vans:
		if f.call(v):
			return true
	return false


func _define_steps() -> void:
	steps = [
		{
			"title": "Welcome to Maple St.",
			"body": "That orange-roofed building in the corner is your depot. You've got two vehicles, a little cash, and a whole town of doorsteps. Zoomer Express (purple) runs most deliveries here. Let's take some of that work.",
			"next": true,
		},
		{
			"title": "Take a job",
			"body": "Vendors post delivery orders on the JOBS board. More stops, heavier loads and longer drives pay more. Heavy freight needs a box truck. Hit TAKE on a job.",
			"enter": func(): hud.set_tab("jobs"),
			"target": func(): return hud.first_take_button() if hud.first_take_button() else hud.clipboard,
			"done": func(): return not sim.player().active_jobs().is_empty() or sim.player().backlog() > 3,
		},
		{
			"title": "The vendor is packing",
			"body": "Corner Pantry is boxing up your order. When it's ready, their little van drives it over to your depot. Waiting is boring: try 4x speed.",
			"target": func(): return hud.speed_box,
			"done": func(): return _flags.has("job_arrived") or _any_van(func(v): return not v.cargo.is_empty()),
		},
		{
			"title": "Loading up",
			"body": "The parcels get sorted, then your vehicles load whatever fits. Watch the FLEET list. A vehicle stamped READY is loaded and waiting for your word.",
			"enter": func(): hud.set_tab("fleet"),
			"target": func(): return hud.clipboard,
			"done": func(): return _any_van(func(v): return v.ready or v.on_road()),
		},
		{
			"title": "Plan it, then send it",
			"body": "Click the ready vehicle to open its ROUTE SHEET. Each stop shows when you'll get there: red is late, yellow means nobody's home yet. Shuffle stops with the arrows, then hit SEND IT.",
			"target": func():
				if hud.selected and hud.route_sheet.visible:
					return hud.route_sheet.send_button()
				var g = hud.fleet_go_button()
				return g if g else hud.clipboard,
			"done": func(): return _any_van(func(v): return v.on_road()),
		},
		{
			"title": "You're in business",
			"body": "Watch for RUSH orders on the board, road works and rush hour. If a vehicle breaks down, send a rescue before the tow takes the parcels back. At 21:00 you'll get a report card and pick an upgrade card. Stack mods on one truck to build a monster.",
			"next": true,
			"button": "Let's go",
		},
	]


func _go(i: int) -> void:
	if i >= steps.size():
		_finish()
		return
	index = i
	var s: Dictionary = steps[i]
	_step_label.text = "NOTE %d / %d" % [i + 1, steps.size()]
	_title.text = String(s["title"]).to_upper()
	_body.text = s["body"]
	_next.visible = s.get("next", false)
	_next.text = String(s.get("button", "Next")).to_upper()
	if s.has("enter"):
		(s["enter"] as Callable).call()
	_note.modulate.a = 0.0
	create_tween().tween_property(_note, "modulate:a", 1.0, 0.25)


func _finish() -> void:
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	if index < 0:
		return
	var s: Dictionary = steps[index]
	if s.has("done") and (s["done"] as Callable).call():
		_go(index + 1)
		return
	_target = null
	if s.has("target"):
		var t = (s["target"] as Callable).call()
		if t is Control and is_instance_valid(t) and (t as Control).is_visible_in_tree():
			_target = t
	_place_note()
	queue_redraw()


func _place_note() -> void:
	var vp := get_viewport_rect().size
	var ns := _note.get_combined_minimum_size()
	_note.size = ns
	var pos: Vector2
	if _target == null:
		pos = (vp - ns) * 0.5 + Vector2(0, -60)
	else:
		var r := _target.get_global_rect()
		pos = Vector2(r.position.x - ns.x - 60, r.get_center().y - ns.y * 0.5)
		if pos.x < 16:
			pos = Vector2(r.get_center().x - ns.x * 0.5, r.position.y - ns.y - 50)
		if pos.y < 16:
			pos = Vector2(r.get_center().x - ns.x * 0.5, r.end.y + 50)
	pos.x = clampf(pos.x, 16, vp.x - ns.x - 16)
	pos.y = clampf(pos.y, 16, vp.y - ns.y - 16)
	_note.position = pos
	_note.rotation_degrees = 0.8
	var t0 := _note.get_node("Tape0") as Control
	var t1 := _note.get_node("Tape1") as Control
	t0.position = pos + Vector2(-14, -8)
	t1.position = pos + Vector2(ns.x - 58, -12)


func _draw() -> void:
	if _target == null:
		return
	var r := _target.get_global_rect().grow(6.0)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	draw_rect(r.grow(2.0 + pulse * 3.0), Color(Palette.ORANGE, 0.35 + pulse * 0.3), false, 3.0)
	draw_rect(r, Palette.INK, false, 3.0)
	draw_rect(r.grow(-3.0), Palette.ORANGE, false, 2.0)
	# hand-drawn-ish arrow from the note to the target
	var nr := Rect2(_note.position, _note.size)
	var a := nr.get_center()
	var b := r.get_center()
	a = _edge_point(nr, b)
	b = _edge_point(r.grow(4.0), a)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var mid := (a + b) * 0.5 + n * minf(40.0, a.distance_to(b) * 0.15)
	var pts := PackedVector2Array()
	for k in 17:
		var t := k / 16.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, Palette.INK, 6.0, true)
	draw_polyline(pts, Palette.ORANGE, 3.0, true)
	var tip_dir := (pts[16] - pts[14]).normalized()
	var tn := Vector2(-tip_dir.y, tip_dir.x)
	var head := PackedVector2Array([b + tip_dir * 4.0, b - tip_dir * 16.0 + tn * 10.0, b - tip_dir * 16.0 - tn * 10.0])
	draw_colored_polygon(head, Palette.ORANGE)
	draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), Palette.INK, 2.0, true)


static func _edge_point(r: Rect2, toward: Vector2) -> Vector2:
	var c := r.get_center()
	var d := toward - c
	if d == Vector2.ZERO:
		return c
	var sx := (r.size.x * 0.5) / maxf(absf(d.x), 0.001)
	var sy := (r.size.y * 0.5) / maxf(absf(d.y), 0.001)
	return c + d * minf(sx, sy)
