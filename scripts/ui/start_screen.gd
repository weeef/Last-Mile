class_name StartScreen
extends Control
## "Pick your first two vehicles" screen shown before the clock starts.

signal chosen(vehicles: Array, tutorial: bool)
signal back_requested

var picks: Array = []
var cash := 250.0
var charter_name := "Corner Courier"
var _slots: Array[Label] = []
var _start: Button
var _skip: Button
var _card: Control


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var card := UIKit.paper(26)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 8
	var v := UIKit.vbox(10)
	card.add_child(v)
	var top := UIKit.hbox(12)
	var logo := LMIcon.new()
	logo.icon = "box"
	logo.color = Palette.ORANGE
	logo.custom_minimum_size = Vector2(46, 46)
	top.add_child(logo)
	var tv := UIKit.vbox(-8)
	tv.add_child(UIKit.head("Last Mile", 46, Palette.TEXT))
	tv.add_child(UIKit.label("A small delivery outfit at the end of the line.", 14, Palette.TEXT_SOFT))
	top.add_child(tv)
	v.add_child(top)
	v.add_child(UIKit.rule())
	v.add_child(UIKit.head("Pick your first two vehicles", 24, Palette.TEXT))
	var intro := UIKit.label("%s. You've leased a small depot on Maple St. and have %s in the till. The landlord wants rent every third evening, and Holiday Peak hits on day 12. Zoomer Express runs most of the deliveries in town. You start with two second-hand vehicles; more can be bought as the business grows." % [charter_name, UIKit.money(cash)], 14, Palette.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 760
	v.add_child(intro)

	var opts := UIKit.hbox(14)
	for t in VehicleTypes.START_CHOICES:
		opts.add_child(_option(t))
	v.add_child(opts)

	var slot_row := UIKit.hbox(10)
	slot_row.add_child(UIKit.head("Your fleet", 16, Palette.TEXT_SOFT))
	for i in 2:
		var p := PanelContainer.new()
		var s := UIKit.flat(Palette.PAPER_2, 2, 12, 4)
		s.border_color = Palette.INK
		s.set_border_width_all(2)
		p.add_theme_stylebox_override("panel", s)
		p.custom_minimum_size = Vector2(200, 0)
		var l := UIKit.head("", 16, Palette.TEXT)
		p.add_child(l)
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.tooltip_text = "Click to remove"
		var idx := i
		p.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and idx < picks.size():
				picks.remove_at(idx)
				_refresh())
		slot_row.add_child(p)
		_slots.append(l)
	v.add_child(slot_row)

	var actions := UIKit.hbox(10)
	var back := UIKit.button("Back", "paper", 17)
	back.pressed.connect(func(): back_requested.emit())
	actions.add_child(back)
	actions.add_child(UIKit.spacer())
	_skip = UIKit.button("Start, skip tutorial", "paper", 17)
	_skip.pressed.connect(func(): chosen.emit(picks.duplicate(), false))
	actions.add_child(_skip)
	_start = UIKit.button("Start with tutorial", "go", 17)
	_start.custom_minimum_size.y = 40
	_start.pressed.connect(func(): chosen.emit(picks.duplicate(), true))
	actions.add_child(_start)
	v.add_child(actions)

	add_child(card)
	card.rotation_degrees = -0.6   # a slightly askew sheet on the desk
	_card = card
	_refresh()


func _process(_d: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	_card.size = _card.get_combined_minimum_size()
	_card.position = ((vp - _card.size) * 0.5).floor()


func _option(t: StringName) -> Control:
	var spec: Dictionary = VehicleTypes.DATA[t]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.paper_style(Palette.PAPER_2, 14, 4))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.head(spec["name"], 24, Palette.TEXT))
	for row in [["Speed", spec["speed"] / 1.25], ["Space", spec["slots"] / 16.0], ["Max load", spec["kg"] / 900.0], ["Toughness", 1.0 / spec["wear"] / 1.25]]:
		var rh := UIKit.hbox(8)
		var l := UIKit.head(row[0], 13, Palette.TEXT_SOFT)
		l.custom_minimum_size.x = 76
		rh.add_child(l)
		var b := LMBar.new()
		b.value = row[1]
		b.ticks = 5
		b.custom_minimum_size = Vector2(200, 10)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(b)
		v.add_child(rh)
	v.add_child(UIKit.mono("%d parcels · %dkg%s" % [spec["slots"], int(spec["kg"]), " · liftgate" if spec["heavy"] else ""], 12, Palette.TEXT_SOFT))
	var d := UIKit.label(spec["desc"], 13, Palette.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.y = 36
	v.add_child(d)
	var add := UIKit.button("Add  " + spec["short"], "ink", 15)
	add.pressed.connect(func():
		if picks.size() < 2:
			picks.append(t)
			_refresh())
	v.add_child(add)
	return p


func _refresh() -> void:
	for i in 2:
		if i < picks.size():
			_slots[i].text = "%d · %s  ×" % [i + 1, VehicleTypes.DATA[picks[i]]["name"].to_upper()]
			_slots[i].add_theme_color_override("font_color", Palette.TEXT)
		else:
			_slots[i].text = "%d · (empty)" % (i + 1)
			_slots[i].add_theme_color_override("font_color", Palette.TEXT_SOFT)
	_start.disabled = picks.size() < 2
	_skip.disabled = picks.size() < 2
