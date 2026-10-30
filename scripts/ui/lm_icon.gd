class_name LMIcon
extends Control
## Simple vector icons drawn in code, so the project needs no image assets.

@export var icon := "box"
@export var color := Color.BLACK
@export var thickness := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_icon(i: String, c: Color) -> void:
	icon = i
	color = c
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var u := s / 24.0     # icons designed on a 24 grid
	var w := maxf(1.5, thickness * u * 0.9)
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * u
	match icon:
		"box", "cube":
			var top := PackedVector2Array([P.call(12, 5), P.call(19, 8.5), P.call(12, 12), P.call(5, 8.5)])
			draw_colored_polygon(top, Color(color, 0.85))
			draw_colored_polygon(PackedVector2Array([P.call(5, 8.5), P.call(12, 12), P.call(12, 20), P.call(5, 16.5)]), color)
			draw_colored_polygon(PackedVector2Array([P.call(12, 12), P.call(19, 8.5), P.call(19, 16.5), P.call(12, 20)]), color.darkened(0.25))
		"truck":
			draw_rect(Rect2(P.call(3, 7), Vector2(11, 8) * u), color)
			draw_colored_polygon(PackedVector2Array([P.call(14, 9), P.call(18, 9), P.call(21, 12), P.call(21, 15), P.call(14, 15)]), color)
			draw_circle(P.call(7, 16.5), 2.2 * u, color)
			draw_circle(P.call(17, 16.5), 2.2 * u, color)
			draw_circle(P.call(7, 16.5), 0.9 * u, Color.WHITE)
			draw_circle(P.call(17, 16.5), 0.9 * u, Color.WHITE)
		"clock":
			draw_circle(P.call(12, 12), 8.5 * u, color)
			draw_line(P.call(12, 12), P.call(12, 7), Color.WHITE, w, true)
			draw_line(P.call(12, 12), P.call(15.5, 13.5), Color.WHITE, w, true)
		"chart":
			draw_rect(Rect2(P.call(4, 13), Vector2(4, 7) * u), color)
			draw_rect(Rect2(P.call(10, 8), Vector2(4, 12) * u), color)
			draw_rect(Rect2(P.call(16, 4), Vector2(4, 16) * u), color)
		"coins":
			draw_circle(P.call(12, 12), 8.5 * u, color)
			draw_string(ThemeDB.fallback_font, P.call(8.3, 16.8), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color.WHITE)
		"plus":
			draw_line(P.call(12, 6), P.call(12, 18), color, w, true)
			draw_line(P.call(6, 12), P.call(18, 12), color, w, true)
		"minus":
			draw_line(P.call(6, 12), P.call(18, 12), color, w, true)
		"rot_l", "rot_r":
			var c: Vector2 = P.call(12, 12)
			var r := 6.5 * u
			var a_start := deg_to_rad(-60.0)
			var a_end := deg_to_rad(200.0)
			draw_arc(c, r, a_start, a_end, 24, color, w, true)
			var cw := icon == "rot_r"
			var a := a_end if cw else a_start
			var travel := Vector2(-sin(a), cos(a)) * (1.0 if cw else -1.0)
			var nrm := Vector2(cos(a), sin(a))
			var tip := c + nrm * r
			var d := 3.4 * u
			draw_colored_polygon(PackedVector2Array([tip + travel * d, tip + nrm * d, tip - nrm * d]), color)
		"home":
			draw_polyline(PackedVector2Array([P.call(5, 11), P.call(12, 5), P.call(19, 11)]), color, w, true)
			draw_polyline(PackedVector2Array([P.call(7, 10), P.call(7, 19), P.call(17, 19), P.call(17, 10)]), color, w, true)
		"close":
			draw_line(P.call(7, 7), P.call(17, 17), color, w, true)
			draw_line(P.call(17, 7), P.call(7, 17), color, w, true)
		"check":
			draw_polyline(PackedVector2Array([P.call(6, 12.5), P.call(10.5, 17), P.call(18, 8)]), color, w * 1.1, true)
		"doc":
			draw_rect(Rect2(P.call(6, 4), Vector2(12, 16) * u), color)
			for k in 3:
				draw_line(P.call(9, 9 + k * 3.5), P.call(15, 9 + k * 3.5), Color.WHITE, w * 0.8, true)
		"sort":
			for k in 3:
				draw_line(P.call(5, 7 + k * 5), P.call(19 - k * 4, 7 + k * 5), color, w * 1.2, true)
		"load":
			draw_rect(Rect2(P.call(4, 13), Vector2(16, 7) * u), color)
			draw_line(P.call(12, 4), P.call(12, 11), color, w, true)
			draw_colored_polygon(PackedVector2Array([P.call(8.5, 8.5), P.call(15.5, 8.5), P.call(12, 12)]), color)
		"pause":
			draw_rect(Rect2(P.call(7, 6), Vector2(3.5, 12) * u), color)
			draw_rect(Rect2(P.call(13.5, 6), Vector2(3.5, 12) * u), color)
		"pin":
			draw_circle(P.call(12, 10), 6 * u, color)
			draw_colored_polygon(PackedVector2Array([P.call(7, 12.5), P.call(17, 12.5), P.call(12, 21)]), color)
			draw_circle(P.call(12, 10), 2.3 * u, Color.WHITE)
		"people":
			draw_circle(P.call(9, 8), 3.2 * u, color)
			draw_colored_polygon(PackedVector2Array([P.call(3, 19), P.call(4.5, 13), P.call(13.5, 13), P.call(15, 19)]), color)
			draw_circle(P.call(16.5, 9), 2.6 * u, Color(color, 0.6))
			draw_colored_polygon(PackedVector2Array([P.call(15.5, 18), P.call(16, 13.5), P.call(20, 13.5), P.call(21, 18)]), Color(color, 0.6))
		"map":
			draw_colored_polygon(PackedVector2Array([P.call(3, 6), P.call(9, 4), P.call(9, 18), P.call(3, 20)]), color)
			draw_colored_polygon(PackedVector2Array([P.call(9.6, 4), P.call(14.4, 6), P.call(14.4, 20), P.call(9.6, 18)]), Color(color, 0.6))
			draw_colored_polygon(PackedVector2Array([P.call(15, 6), P.call(21, 4), P.call(21, 18), P.call(15, 20)]), color)
		"bolt":
			draw_colored_polygon(PackedVector2Array([P.call(13, 3), P.call(6, 13.5), P.call(11, 13.5), P.call(10, 21), P.call(18, 10), P.call(13, 10), P.call(14.5, 3)]), color)
		"gear":
			var c: Vector2 = P.call(12, 12)
			for k in 8:
				var a := k * TAU / 8.0
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([c + d * 6.0 * u + n * 1.6 * u, c + d * 9.5 * u + n * 1.3 * u,
					c + d * 9.5 * u - n * 1.3 * u, c + d * 6.0 * u - n * 1.6 * u]), color)
			draw_circle(c, 6.6 * u, color)
			draw_circle(c, 2.6 * u, Palette.INK_2)
		"up":
			draw_colored_polygon(PackedVector2Array([P.call(12, 5), P.call(20, 16), P.call(4, 16)]), color)
		"down":
			draw_colored_polygon(PackedVector2Array([P.call(4, 8), P.call(20, 8), P.call(12, 19)]), color)
		"chevron":
			draw_polyline(PackedVector2Array([P.call(9, 6), P.call(15, 12), P.call(9, 18)]), color, w, true)
		_:
			draw_circle(P.call(12, 12), 6 * u, color)
