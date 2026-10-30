class_name LMBar
extends Control
## Gauge bar with an ink outline and tick marks. If `split`, draws two colors.

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var color := Palette.INK:
	set(v):
		color = v
		queue_redraw()
var back := Palette.PAPER_3
var right_color := Palette.PURPLE
var split := false
var ticks := 0
var bar_height := 8.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < bar_height:
		custom_minimum_size.y = bar_height


func _draw() -> void:
	var h := bar_height
	var y := floorf((size.y - h) * 0.5)
	var r := Rect2(0, y, size.x, h)
	draw_rect(r, right_color if split else back)
	if value > 0.0:
		draw_rect(Rect2(0, y, size.x * value, h), color)
	for k in range(1, ticks):
		var x := size.x * k / float(ticks)
		draw_line(Vector2(x, y), Vector2(x, y + h * 0.4), Color(Palette.INK, 0.35), 1.0)
	draw_rect(r, Palette.INK, false, 1.5)
