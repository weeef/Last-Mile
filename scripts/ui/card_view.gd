class_name CardView
extends Control
## One upgrade card: rarity-colored frame, kind label, name, effect text.
## Ultra rares get a foil stripe pattern. Hovering lifts the card.

signal picked(card_id: StringName)

var card_id: StringName
var _hover := 0.0
var _hovering := false
var _time := 0.0


func setup(id: StringName) -> void:
	card_id = id
	custom_minimum_size = Vector2(176, 236)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hovering = true)
	mouse_exited.connect(func(): _hovering = false)
	var c := Cards.get_card(id)
	var vehicle: bool = c["kind"] == "vehicle"
	var col: Color = Cards.RARITY_COLORS[c["rarity"]]
	var v := UIKit.vbox(4)
	v.position = Vector2(14, 14)
	v.size = Vector2(148, 208)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var kind := UIKit.head("Vehicle mod" if vehicle else "Company perk", 12, col.darkened(0.1))
	v.add_child(kind)
	var ic := LMIcon.new()
	ic.icon = "truck" if vehicle else ("bolt" if c["rarity"] >= 2 else "coins")
	ic.color = col
	ic.custom_minimum_size = Vector2(44, 44)
	v.add_child(ic)
	var nm := UIKit.head(c["name"], 22, Palette.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size.x = 148
	v.add_child(nm)
	var desc := UIKit.label(c["desc"], 14, Palette.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 148
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var r := UIKit.stamp(Cards.RARITY_NAMES[c["rarity"]], col, 12)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(r)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(card_id)


func _process(delta: float) -> void:
	_time += delta
	_hover = lerpf(_hover, 1.0 if _hovering else 0.0, minf(1.0, delta * 12.0))
	queue_redraw()


func _draw() -> void:
	var c := Cards.get_card(card_id)
	var col: Color = Cards.RARITY_COLORS[c["rarity"]]
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.PAPER.lerp(Color.WHITE, 0.25 * _hover))
	if c["rarity"] == Cards.Rarity.ULTRA:
		# foil: drifting diagonal gold stripes
		var x := -size.y + fmod(_time * 30.0, 28.0)
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x + size.y, size.y), Color(1.0, 0.72, 0.25, 0.16), 9.0)
			x += 28.0
	draw_rect(r, col, false, 4.0 + 2.0 * _hover)
	draw_rect(r.grow(-8), Color(col, 0.35), false, 1.5)
	draw_rect(Rect2(Vector2(0, size.y - 7), Vector2(size.x, 7)), col)
