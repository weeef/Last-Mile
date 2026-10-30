class_name LMTimeline
extends Control
## Five-step shipment tracker drawn like stamps on a delivery slip.

const ICONS := ["doc", "sort", "load", "truck", "check"]
const NAMES := ["Ordered", "Sorted", "Loaded", "Out", "Delivered"]

var stage := -1
var times: Array = ["", "", "", "", ""]
var late := false
var _icons: Array[LMIcon] = []
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(420, 78)
	for i in 5:
		var ic := LMIcon.new()
		ic.icon = ICONS[i]
		add_child(ic)
		_icons.append(ic)
	resized.connect(queue_redraw)


func set_state(p_stage: int, p_times: Array, p_late: bool) -> void:
	stage = p_stage
	times = p_times
	late = p_late
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta
	if stage >= 0 and stage < 4:
		queue_redraw()


func _draw() -> void:
	var f_head := UIKit.font("head")
	var f_mono := UIKit.font("mono")
	var pad := 34.0
	var step := (size.x - pad * 2.0) / 4.0
	var cy := 20.0
	var accent := Palette.RED if late else Palette.ORANGE
	for i in 4:
		var a := Vector2(pad + step * i + 16, cy)
		var b := Vector2(pad + step * (i + 1) - 16, cy)
		if stage > i:
			draw_line(a, b, Palette.INK, 3.0)
		else:
			var x := a.x
			while x < b.x:
				draw_line(Vector2(x, cy), Vector2(minf(x + 5, b.x), cy), Palette.RULE, 2.0)
				x += 9.0
	for i in 5:
		var c := Vector2(pad + step * i, cy)
		var done := stage >= i
		var current := stage == i
		var s := 15.0 if current else 13.0
		var r := Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0)
		if current and i < 4:
			var halo := 3.0 + 2.0 * (0.5 + 0.5 * sin(_pulse * 4.0))
			draw_rect(r.grow(halo), Color(accent, 0.35), false, 2.0)
		var fill := accent if current else (Palette.INK if done else Palette.PAPER_2)
		draw_rect(r, fill)
		draw_rect(r, Palette.INK, false, 2.0)
		var ic := _icons[i]
		var isz := 16.0
		ic.size = Vector2(isz, isz)
		ic.position = c - Vector2(isz, isz) * 0.5
		ic.set_icon(ICONS[i], Palette.PAPER if done else Palette.TEXT_SOFT)
		var nm: String = String(NAMES[i]).to_upper()
		var w := f_head.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(f_head, Vector2(c.x - w * 0.5, cy + 36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.TEXT if done else Palette.TEXT_SOFT)
		var t: String = times[i]
		if t != "":
			var tw := f_mono.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(f_mono, Vector2(c.x - tw * 0.5, cy + 53), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.TEXT_SOFT)
