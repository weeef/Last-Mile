class_name RouteSheet
extends PanelContainer
## Plan a vehicle's trip before it leaves: reorder stops, see predicted
## arrival times (late / nobody home), load or unload parcels, then send it.

var sim: Sim
var main: Node
var van: Van
var tab := "stops"
var _sig := ""
var _code: Label
var _type: PanelContainer
var _load: Label
var _auto_btn: Button
var _tab_btns := {}
var _list: VBoxContainer
var _summary: Label
var _send: Button
var _service: Button
var _eta_labels := {}     # parcel id -> Label


func setup(p_sim: Sim, p_main: Node) -> void:
	sim = p_sim
	main = p_main
	add_theme_stylebox_override("panel", UIKit.paper_style(Palette.PAPER, 14))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UIKit.vbox(6)
	add_child(v)
	var head := UIKit.hbox(8)
	var hv := UIKit.vbox(-5)
	hv.add_child(UIKit.head("Route sheet", 12, Palette.ORANGE))
	_code = UIKit.head("", 28, Palette.TEXT)
	hv.add_child(_code)
	head.add_child(hv)
	_type = UIKit.stamp("", Palette.SLATE, 12)
	_type.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_type)
	head.add_child(UIKit.spacer())
	var close := UIKit.button("×", "paper", 18)
	close.custom_minimum_size = Vector2(32, 32)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): main.select_van(null))
	head.add_child(close)
	v.add_child(head)
	var info := UIKit.hbox(8)
	_load = UIKit.mono("", 13, Palette.TEXT, true)
	_load.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(_load)
	info.add_child(UIKit.spacer())
	_auto_btn = UIKit.button("Auto-load on", "paper", 13)
	_auto_btn.tooltip_text = "When on, this vehicle keeps loading parcels from the depot by itself."
	_auto_btn.pressed.connect(func():
		main.submit_player({"type": "set_auto_fill", "van": van.id, "value": not van.auto_fill}))
	info.add_child(_auto_btn)
	v.add_child(info)
	var tabs := UIKit.hbox(4)
	for t in [["stops", "Stops"], ["depot", "At depot"]]:
		var b := UIKit.button(t[1], "paper", 14)
		var key: String = t[0]
		b.pressed.connect(func():
			tab = key
			_sig = "")
		tabs.add_child(b)
		_tab_btns[key] = b
	v.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 236)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	v.add_child(sc)
	v.add_child(UIKit.rule())
	_summary = UIKit.label("", 13, Palette.TEXT, "bold")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.x = 330
	v.add_child(_summary)
	var actions := UIKit.hbox(8)
	_service = UIKit.button("Service $%d" % int(Sim.SERVICE_COST), "paper", 15)
	_service.tooltip_text = "Drive to Gearbox Garage for a tune-up (about %d min once a bay is free)." % int(Sim.SERVICE_MIN)
	_service.pressed.connect(func(): main.submit_player({"type": "service_van", "van": van.id}))
	actions.add_child(_service)
	var auto := UIKit.button("Auto order", "paper", 15)
	auto.tooltip_text = "Nearest stop first, evening-only customers last. Fast, not always best."
	auto.pressed.connect(func(): main.submit_player({"type": "auto_order", "van": van.id}))
	actions.add_child(auto)
	_send = UIKit.button("Send it", "go", 17)
	_send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_send.custom_minimum_size.y = 36
	_send.pressed.connect(func(): main.submit_player({"type": "start_route", "van": van.id}))
	actions.add_child(_send)
	v.add_child(actions)


func set_van(v: Van) -> void:
	van = v
	_sig = ""
	tab = "stops"


func send_button() -> Control:
	return _send


func _signature() -> String:
	var s := tab + "|"
	for p in van.cargo:
		s += str(p.id) + ","
	s += "|"
	if tab == "depot":
		for p in sim.player().waiting:
			s += str(p.id) + ","
	return s


func refresh() -> void:
	if van == null:
		return
	_code.text = van.code
	UIKit.set_stamp(_type, van.spec()["name"], Palette.SLATE)
	_load.text = "%d/%d parcels · %d/%dkg" % [van.cargo.size(), van.slots, int(van.load_kg()), int(van.max_kg)]
	_auto_btn.text = "AUTO-LOAD ON" if van.auto_fill else "AUTO-LOAD OFF"
	for k in _tab_btns.keys():
		var b: Button = _tab_btns[k]
		(b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Palette.ORANGE if k == tab else Palette.PAPER_2
	(_tab_btns["stops"] as Button).text = "STOPS %d" % van.cargo.size()
	(_tab_btns["depot"] as Button).text = "AT DEPOT %d" % sim.player().waiting.size()
	var sig := _signature()
	if sig != _sig:
		_sig = sig
		_rebuild()
	# Predicted arrivals for the current order.
	var est := sim.estimate_route(van, van.cargo, sim.player().depot_node, sim.minutes())
	var late := 0
	var early := 0
	for s in est["stops"]:
		var p: Parcel = s["parcel"]
		var l: Label = _eta_labels.get(p.id)
		if l == null:
			continue
		var status: String = s["status"]
		l.text = Sim.clock(s["arrive"]) + ("  LATE" if status == "late" else ("  NOT HOME" if status == "early" else ""))
		l.add_theme_color_override("font_color", Palette.RED if status == "late" else (Palette.AMBER if status == "early" else Palette.GREEN))
		if status == "late":
			late += 1
		elif status == "early":
			early += 1
	if van.cargo.is_empty():
		_summary.text = "Empty. Load parcels from the depot tab, or turn auto-load on."
		_summary.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	else:
		var bits := ["Back at %s" % Sim.clock(est["return"])]
		if late > 0:
			bits.append("%d late" % late)
		if early > 0:
			bits.append("%d nobody home yet" % early)
		if late == 0 and early == 0:
			bits.append("all on time")
		_summary.text = " · ".join(bits)
		_summary.add_theme_color_override("font_color", Palette.RED if late > 0 else (Palette.AMBER if early > 0 else Palette.GREEN))
	_send.disabled = van.cargo.is_empty() or van.state != Van.State.LOADING
	_service.visible = van.state == Van.State.IDLE
	_service.text = "Service %d%%" % int(van.condition * 100)
	_service.disabled = sim.player().money < Sim.SERVICE_COST


func _rebuild() -> void:
	ModalSheet.clear(_list)
	_eta_labels.clear()
	if tab == "stops":
		if van.cargo.is_empty():
			_list.add_child(UIKit.label("No parcels aboard yet.", 13, Palette.TEXT_SOFT))
		for i in van.cargo.size():
			_list.add_child(_stop_row(i, van.cargo[i]))
	else:
		var waiting := sim.player().waiting.duplicate()
		waiting.sort_custom(func(a: Parcel, b: Parcel): return a.deadline < b.deadline)
		if waiting.is_empty():
			_list.add_child(UIKit.label("Nothing waiting at the depot.", 13, Palette.TEXT_SOFT))
		for p in waiting:
			_list.add_child(_depot_row(p))


func _tags(p: Parcel) -> HBoxContainer:
	var t := UIKit.hbox(3)
	if p.kind == Parcel.Kind.EXPRESS:
		t.add_child(UIKit.stamp("Express", Palette.ORANGE, 10))
	var w := p.window_text()
	if w != "":
		t.add_child(UIKit.stamp(w, Palette.PURPLE, 10))
	if p.signature:
		t.add_child(UIKit.stamp("Sign", Palette.BLUE, 10))
	if p.heavy():
		t.add_child(UIKit.stamp("Heavy", Palette.RED, 10))
	if p.attempts > 0:
		t.add_child(UIKit.stamp("Retry", Palette.AMBER, 10))
	return t


func _stop_row(i: int, p: Parcel) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 6, 3))
	var h := UIKit.hbox(6)
	row.add_child(h)
	var n := PanelContainer.new()
	n.add_theme_stylebox_override("panel", UIKit.flat(Palette.INK, 2, 0, 0))
	n.custom_minimum_size = Vector2(24, 24)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nl := UIKit.head(str(i + 1), 14, Palette.PAPER)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_child(nl)
	h.add_child(n)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var addr := UIKit.label(sim.house(p.house)["address"], 13, Palette.TEXT, "bold")
	addr.clip_text = true
	v.add_child(addr)
	var line := UIKit.hbox(4)
	var eta := UIKit.mono("", 11, Palette.GREEN, true)
	line.add_child(eta)
	line.add_child(_tags(p))
	v.add_child(line)
	h.add_child(v)
	_eta_labels[p.id] = eta
	h.add_child(_icon_btn("up", "Earlier", i > 0, func(): _move(i, -1)))
	h.add_child(_icon_btn("down", "Later", i < van.cargo.size() - 1, func(): _move(i, 1)))
	h.add_child(_icon_btn("close", "Unload back to the depot", true, func():
		main.submit_player({"type": "unload_parcel", "van": van.id, "parcel": p.id})))
	return row


func _depot_row(p: Parcel) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 6, 3))
	var h := UIKit.hbox(6)
	row.add_child(h)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var addr := UIKit.label(sim.house(p.house)["address"], 13, Palette.TEXT, "bold")
	addr.clip_text = true
	v.add_child(addr)
	var line := UIKit.hbox(4)
	line.add_child(UIKit.mono("due %s · %.0fkg" % [Sim.clock(p.deadline), p.weight], 11, Palette.TEXT_SOFT))
	line.add_child(_tags(p))
	v.add_child(line)
	h.add_child(v)
	var fits := van.can_fit(p)
	var tip := "Load onto %s" % van.code
	if not fits:
		tip = "Needs a liftgate" if p.heavy() and not van.carries_heavy() else "Doesn't fit"
	h.add_child(_icon_btn("plus", tip, fits, func():
		main.submit_player({"type": "load_parcel", "van": van.id, "parcel": p.id})))
	return row


func _move(i: int, dir: int) -> void:
	var ids: Array = van.cargo.map(func(x): return x.id)
	var j := i + dir
	if j < 0 or j >= ids.size():
		return
	var tmp = ids[i]
	ids[i] = ids[j]
	ids[j] = tmp
	main.submit_player({"type": "set_order", "van": van.id, "order": ids})


func _icon_btn(icon: String, tip: String, enabled: bool, cb: Callable) -> Button:
	var b := UIKit.button("", "paper", 12)
	b.custom_minimum_size = Vector2(26, 26)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = tip
	b.disabled = not enabled
	var ic := LMIcon.new()
	ic.icon = icon
	ic.color = Palette.INK if enabled else Palette.RULE
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 5
	ic.offset_top = 4
	ic.offset_right = -5
	ic.offset_bottom = -6
	b.add_child(ic)
	b.pressed.connect(cb)
	return b
