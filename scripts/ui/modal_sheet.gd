class_name ModalSheet
extends Control
## Base for full-screen sheets: dims the desk and keeps a paper card centered.

var card: PanelContainer
var body: VBoxContainer


func _init() -> void:
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	card = UIKit.paper(22)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 8
	body = UIKit.vbox(10)
	card.add_child(body)
	add_child(card)


func _process(_d: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	card.size = card.get_combined_minimum_size()
	card.position = ((vp - card.size) * 0.5).floor()


static func clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()
