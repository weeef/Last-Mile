class_name PauseMenu
extends Control
## In-game menu (Esc): resume, save, settings, back to title, quit.

signal resume
signal save_requested
signal settings_requested
signal title_requested
signal quit_requested

var slot := 1
var _card: Control
var _saved: Label


func _ready() -> void:
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card := UIKit.paper(22)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 7
	card.custom_minimum_size.x = 320
	var v := UIKit.vbox(8)
	card.add_child(v)
	v.add_child(UIKit.head("Paused", 34, Palette.TEXT))
	v.add_child(UIKit.label("Save slot %d" % slot, 12, Palette.TEXT_SOFT, "mono"))
	v.add_child(UIKit.rule())
	for item in [["Resume", "go", resume], ["Save game", "paper", save_requested], ["Settings", "paper", settings_requested],
			["Save & main menu", "paper", title_requested], ["Save & quit", "ink", quit_requested]]:
		var b := UIKit.button(item[0], item[1], 19)
		b.custom_minimum_size.y = 42
		var sig: Signal = item[2]
		b.pressed.connect(func(): sig.emit())
		v.add_child(b)
	_saved = UIKit.label("", 13, Palette.GREEN, "bold")
	v.add_child(_saved)
	add_child(card)
	_card = card


func show_saved(ok: bool) -> void:
	_saved.text = ("Saved to slot %d." % slot) if ok else "Could not save."
	_saved.add_theme_color_override("font_color", Palette.GREEN if ok else Palette.RED)


func _process(_d: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((vp - _card.size) * 0.5).floor()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resume.emit()
