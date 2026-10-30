class_name LMRule
extends Control
## A horizontal rule; dashed like a perforated ticket edge.

var color := Palette.RULE
var dashed := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 6
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var y := size.y * 0.5
	if not dashed:
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.5)
		return
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, y), Vector2(minf(x + 6.0, size.x), y), color, 1.5)
		x += 10.0
