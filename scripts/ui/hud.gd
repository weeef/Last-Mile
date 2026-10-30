class_name HUD
extends Control
## The dispatcher's desk: masthead, clock, cash, stats strip, vehicle work
## order, shipment slip, and the clipboard (jobs, fleet, buy, rules, districts).

const DETAIL_W := 360.0
const CLIP_W := 590.0
const CLIP_H := 330.0
const SPEEDS := [0, 1, 2, 4, 8]

var sim: Sim
var main: Node
var selected: Van = null
var show_fps := false
var _fps: Label

# masthead / top
var _level_name: Label
var _level_bar: LMBar
var _level_sub: Label
var _day: Label
var _clock: Label
var _speed_btns := {}
var speed_box: Control
var _clock_panel: Control
var _cash: Label
var _cash_delta: Label
var _rival_sub: Label
var _stats := {}
# tools + detail
var _tools: PanelContainer
var route_sheet: RouteSheet
var _contract_label: Label
var _contract_bar: LMBar
var _contract_val: Label
var _conditions: Label
var _season_panel: PanelContainer
var _lease_label: Label
var _lease_bar: LMBar
var _lease_val: Label
var _streak_box: PanelContainer
var _streak_val: Label
var _streak_sub: Label
var _streak_shown := -1
var _level_tip: Control
var _rival_tip: Control
var _cash_tip: Control
var _tip_frame := 0
var _hustle_bar: LMBar
var _hustle_val: Label
var _power_btns := {}
var _skip_btn: Button
var _detail: PanelContainer
var _d := {}
var _detail_van_id := -1
# tracking
var _timeline: LMTimeline
var _track := {}
# clipboard
var clipboard: Control
var _pages := {}
var _tab_btns := {}
var tab := "jobs"
var _fleet_list: VBoxContainer
var _fleet_rows := {}
var _jobs_list: VBoxContainer
var _jobs_sig := ""
var _job_rows: Array = []
var _vendor_rows: Array = []
var _buy_cards := {}
var _rules := {}
var _district_rows: Array = []
# overlay
var _tag: PanelContainer
var _tag_code: Label
var _tag_state: Label
var _toasts: VBoxContainer


func setup(p_sim: Sim, p_main: Node) -> void:
	sim = p_sim
	main = p_main
	theme = UIKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_masthead()
	_build_clock()
	_build_cash_and_rival()
	_build_stats()
	_build_tools()
	_build_detail()
	_build_tracking()
	_build_clipboard()
	_build_overlay()
	sim.notice.connect(_toast)
	sim.van_added.connect(_on_van_added)
	for v in sim.player().vans:
		_add_fleet_row(v)
	select(null)


func _place(c: Control, preset: int, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> void:
	add_child(c)
	c.set_anchors_preset(preset)
	var right := preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
	var bottom := preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT]
	if sz != Vector2.ZERO:
		c.custom_minimum_size = sz
	c.offset_left = -pos.x - sz.x if right else pos.x
	c.offset_right = -pos.x if right else pos.x + sz.x
	c.offset_top = -pos.y - sz.y if bottom else pos.y
	c.offset_bottom = -pos.y if bottom else pos.y + sz.y
	if right:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if bottom:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN


# ============================================================= top

func _build_masthead() -> void:
	var p := UIKit.ink(10)
	var h := UIKit.hbox(14)
	p.add_child(h)
	var logo := LMIcon.new()
	logo.icon = "box"
	logo.color = Palette.ORANGE
	logo.custom_minimum_size = Vector2(34, 34)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(logo)
	var tv := UIKit.vbox(-4)
	tv.add_child(UIKit.head("Last Mile", 28, Palette.PAPER))
	tv.add_child(UIKit.label("DISPATCH  ·  MAPLE ST.", 11, Palette.TEXT_INV_SOFT, "head_semi"))
	h.add_child(tv)
	var sep := ColorRect.new()
	sep.color = Palette.INK_3
	sep.custom_minimum_size = Vector2(2, 0)
	h.add_child(sep)
	var lv := UIKit.vbox(2)
	_level_name = UIKit.head("", 15, Palette.PAPER)
	lv.add_child(_level_name)
	_level_bar = LMBar.new()
	_level_bar.custom_minimum_size = Vector2(170, 8)
	_level_bar.color = Palette.ORANGE
	_level_bar.back = Palette.INK_3
	_level_bar.ticks = 10
	lv.add_child(_level_bar)
	lv.mouse_filter = Control.MOUSE_FILTER_STOP
	_level_tip = lv
	_level_sub = UIKit.mono("", 11, Palette.TEXT_INV_SOFT)
	lv.add_child(_level_sub)
	h.add_child(lv)
	_place(p, Control.PRESET_TOP_LEFT, Vector2(16, 12))


func _build_clock() -> void:
	var p := UIKit.ink(8)
	var h := UIKit.hbox(12)
	p.add_child(h)
	var cv := UIKit.vbox(-6)
	_day = UIKit.head("", 13, Palette.TEXT_INV_SOFT)
	_clock = UIKit.mono("", 28, Palette.PAPER, true)
	cv.add_child(_day)
	cv.add_child(_clock)
	h.add_child(cv)
	var keys := UIKit.hbox(4)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for s in SPEEDS:
		var b := UIKit.button("II" if s == 0 else "%dx" % s, "paper", 15)
		b.custom_minimum_size = Vector2(38, 32)
		b.pressed.connect(func(): main.set_speed(s))
		b.tooltip_text = "Pause (Space)" if s == 0 else "Speed %dx" % s
		keys.add_child(b)
		_speed_btns[s] = b
	h.add_child(keys)
	speed_box = keys
	add_child(p)
	_clock_panel = p


func _build_cash_and_rival() -> void:
	var h := UIKit.hbox(10)
	var r := PanelContainer.new()
	var rs := UIKit.ink_style(10)
	rs.border_color = Palette.PURPLE
	rs.border_width_left = 6
	r.add_theme_stylebox_override("panel", rs)
	var rv := UIKit.vbox(0)
	rv.add_child(UIKit.head("Zoomer Express", 16, Palette.PURPLE.lightened(0.35)))
	_rival_sub = UIKit.label("", 12, Palette.TEXT_INV_SOFT)
	rv.add_child(_rival_sub)
	r.add_child(rv)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	_rival_tip = r
	r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(r)
	var c := UIKit.paper(10)
	var cv := UIKit.vbox(-2)
	cv.add_child(UIKit.head("Cash on hand", 13, Palette.TEXT_SOFT))
	_cash = UIKit.mono("", 28, Palette.TEXT, true)
	cv.add_child(_cash)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	_cash_tip = c
	_cash_delta = UIKit.mono("", 12, Palette.GREEN)
	cv.add_child(_cash_delta)
	c.add_child(cv)
	c.custom_minimum_size.x = 170
	h.add_child(c)
	_place(h, Control.PRESET_TOP_RIGHT, Vector2(16, 12))


func _build_stats() -> void:
	var p := UIKit.paper(10)
	var h := UIKit.hbox(14)
	p.add_child(h)
	var defs := [["ontime", "On time today"], ["done", "Delivered"], ["share", "Walk-in share"], ["fleet", "Fleet"]]
	var first := true
	for d in defs:
		if not first:
			var sep := ColorRect.new()
			sep.color = Palette.RULE
			sep.custom_minimum_size = Vector2(2, 0)
			h.add_child(sep)
		first = false
		var v := UIKit.vbox(-2)
		v.custom_minimum_size.x = 108
		v.add_child(UIKit.head(d[1], 12, Palette.TEXT_SOFT))
		var val := UIKit.mono("", 21, Palette.TEXT, true)
		v.add_child(val)
		var sub := UIKit.label("", 11, Palette.TEXT_SOFT)
		v.add_child(sub)
		h.add_child(v)
		_stats[d[0]] = {"value": val, "sub": sub, "box": v}
		v.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(p, Control.PRESET_TOP_LEFT, Vector2(16, 92))
	var hint := UIKit.label("drag: pan   ·   right-drag / Q E: rotate   ·   wheel: zoom   ·   click a vehicle   ·   space: pause", 12, Color(Palette.PAPER, 0.75), "head_semi")
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	hint.add_theme_constant_override("shadow_offset_y", 1)
	_place(hint, Control.PRESET_TOP_LEFT, Vector2(20, 262))
	var cp := UIKit.paper(8)
	var ch := UIKit.hbox(10)
	cp.add_child(ch)
	ch.add_child(UIKit.head("Today's contract", 13, Palette.TEXT_SOFT))
	_contract_label = UIKit.label("", 14, Palette.TEXT, "bold")
	ch.add_child(_contract_label)
	UIKit.tip(cp, "Today's contract, picked at the morning briefing. Finish it by 21:00 for its cash reward, a better card draft tonight and a star.\n" + Explain.stars())
	_contract_bar = LMBar.new()
	_contract_bar.custom_minimum_size = Vector2(90, 8)
	_contract_bar.color = Palette.GREEN
	_contract_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.add_child(_contract_bar)
	_contract_val = UIKit.mono("", 13, Palette.TEXT, true)
	ch.add_child(_contract_val)
	_place(cp, Control.PRESET_TOP_LEFT, Vector2(16, 176))
	_build_season()
	_build_powers()
	var cond := UIKit.label("", 13, Palette.PAPER, "head")
	cond.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	cond.add_theme_constant_override("shadow_offset_y", 1)
	_conditions = cond
	cond.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(cond)


## Lease meter (cash vs. what's due) and the delivery streak badge.
func _build_season() -> void:
	var row := UIKit.hbox(8)
	_season_panel = UIKit.paper(8)
	var h := UIKit.hbox(10)
	_season_panel.add_child(h)
	_lease_label = UIKit.head("", 13, Palette.TEXT_SOFT)
	h.add_child(_lease_label)
	_lease_bar = LMBar.new()
	_lease_bar.custom_minimum_size = Vector2(120, 10)
	_lease_bar.bar_height = 10.0
	_lease_bar.ticks = 4
	_lease_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_lease_bar)
	_lease_val = UIKit.mono("", 13, Palette.TEXT, true)
	h.add_child(_lease_val)
	_season_panel.tooltip_text = "Rent is billed at 21:00 on the due day. Keep enough cash in the till."
	row.add_child(_season_panel)
	_streak_box = PanelContainer.new()
	_streak_box.add_theme_stylebox_override("panel", UIKit.ink_style(8))
	_streak_box.tooltip_text = "On-time deliveries in a row. Each one adds to the pay of every drop. A late parcel or nobody home breaks it."
	var sh := UIKit.hbox(8)
	_streak_box.add_child(sh)
	_streak_val = UIKit.mono("", 18, Palette.PAPER, true)
	sh.add_child(_streak_val)
	_streak_sub = UIKit.head("", 12, Palette.TEXT_INV_SOFT)
	_streak_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_streak_sub)
	row.add_child(_streak_box)
	_place(row, Control.PRESET_TOP_LEFT, Vector2(16, 216))


func _refresh_season() -> void:
	var p := sim.player()
	_season_panel.visible = sim.season_on()
	if sim.season_on():
		var due := Season.due_day(sim.day())
		var left := due - sim.day()
		var amount := sim.lease_amount()
		_lease_label.text = "LEASE %s" % ("TONIGHT" if left == 0 else "DAY %d" % due)
		_lease_label.add_theme_color_override("font_color", Palette.RED if left == 0 else Palette.TEXT_SOFT)
		_lease_bar.value = p.money / amount if amount > 0.0 else 1.0
		_lease_bar.color = Palette.GREEN if p.money >= amount else (Palette.RED if left == 0 else Palette.AMBER)
		_lease_val.text = "%s / %s" % [UIKit.money(p.money), UIKit.money(amount)]
	var s := sim.streak
	if s != _streak_shown:
		var grew := s > _streak_shown and _streak_shown >= 0
		_streak_shown = s
		_streak_val.text = "x%.2f" % sim.streak_mult()
		var tier := Season.streak_tier_name(s)
		_streak_sub.text = ("%d IN A ROW%s" % [s, "  ·  " + tier.to_upper() if tier != "" else ""]) if s > 0 else "NO STREAK"
		var col := Palette.TEXT_INV_SOFT
		if s >= 20:
			col = Palette.RED.lightened(0.25)
		elif s >= 10:
			col = Palette.ORANGE
		elif s >= 5:
			col = Palette.AMBER.lightened(0.2)
		elif s > 0:
			col = Palette.PAPER
		_streak_val.add_theme_color_override("font_color", col)
		var st := _streak_box.get_theme_stylebox("panel") as StyleBoxFlat
		st.border_color = col if s >= 5 else Palette.INK
		if grew and is_inside_tree():
			_streak_box.pivot_offset = _streak_box.size * 0.5
			var tw := create_tween()
			tw.tween_property(_streak_box, "scale", Vector2(1.12, 1.12), 0.06)
			tw.tween_property(_streak_box, "scale", Vector2.ONE, 0.14)


## Dispatcher powers (spend hustle) and the skip-ahead button.
func _build_powers() -> void:
	var p := UIKit.ink(8)
	var v := UIKit.vbox(5)
	p.add_child(v)
	var hh := UIKit.hbox(6)
	hh.add_child(UIKit.head("Hustle", 14, Palette.AMBER.lightened(0.2)))
	hh.add_child(UIKit.spacer())
	_hustle_val = UIKit.mono("", 13, Palette.PAPER, true)
	hh.add_child(_hustle_val)
	v.add_child(hh)
	_hustle_bar = LMBar.new()
	_hustle_bar.custom_minimum_size = Vector2(176, 10)
	_hustle_bar.bar_height = 10.0
	_hustle_bar.color = Palette.AMBER
	_hustle_bar.back = Palette.INK_3
	_hustle_bar.ticks = Abilities.BASE_CAP
	v.add_child(_hustle_bar)
	var tip := UIKit.label("+1 per on-time drop", 11, Palette.TEXT_INV_SOFT, "head_semi")
	v.add_child(tip)
	for id in Abilities.ORDER:
		var a: Dictionary = Abilities.DATA[id]
		var b := UIKit.button("%s  %s · %d" % [a["key"], a["name"], a["cost"]], "paper", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(176, 30)
		b.tooltip_text = a["desc"] + ("\nSelect a vehicle on the road first." if a.get("target", false) else "")
		var key: String = id
		b.pressed.connect(func(): use_power(key))
		v.add_child(b)
		_power_btns[id] = b
	_skip_btn = UIKit.button("F  Skip ahead >>", "go", 14)
	_skip_btn.custom_minimum_size = Vector2(176, 32)
	_skip_btn.tooltip_text = "Run the clock fast until something needs you: a vehicle is ready, a rush order, a breakdown, a delivery from a vendor."
	_skip_btn.pressed.connect(func(): main.skip_ahead())
	v.add_child(_skip_btn)
	_place(p, Control.PRESET_TOP_LEFT, Vector2(16, 292))


## Hover text for the always-visible widgets (refreshed a few times a second).
func _refresh_tips() -> void:
	var p := sim.player()
	UIKit.tip(_cash_tip, Explain.cash(p))
	UIKit.tip(_level_tip, Explain.levels(p))
	UIKit.tip(_rival_tip, Explain.zoomer(sim))
	UIKit.tip(_stats["ontime"]["box"], "Share of today's drops delivered before their deadline. Late drops pay 30%%, break your streak and hurt reputation.\n" + Explain.stars())
	UIKit.tip(_stats["done"]["box"], "Parcels delivered today and what they paid (including streak and tips).")
	UIKit.tip(_stats["share"]["box"], Explain.walkins(sim))
	UIKit.tip(_stats["fleet"]["box"], "Vehicles out on the road / in your fleet. Fleet cap %d at this business level. Every vehicle costs wages even when parked." % p.fleet_cap())
	UIKit.tip(_conditions, Explain.conditions(sim))
	if sim.season_on():
		UIKit.tip(_season_panel, Explain.lease(sim))
	UIKit.tip(_streak_box, Explain.streak(sim))
	UIKit.tip(_hustle_bar.get_parent(), Explain.hustle(sim))


## Fires a dispatcher power (button or hotkey).
func use_power(id: String) -> void:
	var cmd := {"type": "ability", "ability": id}
	if Abilities.DATA[id].get("target", false):
		if selected == null:
			_toast("Select a vehicle on the road first", "info")
			return
		cmd["van"] = selected.id
	main.submit_player(cmd)


func _refresh_powers() -> void:
	var cap := sim.hustle_cap()
	_hustle_bar.ticks = cap
	_hustle_bar.value = float(sim.hustle) / cap
	_hustle_val.text = "%d / %d" % [sim.hustle, cap]
	var day := sim.phase == Sim.Phase.DAY
	for id in _power_btns.keys():
		var b: Button = _power_btns[id]
		var a: Dictionary = Abilities.DATA[id]
		var ok: bool = day and sim.hustle >= a["cost"]
		if a.get("target", false):
			ok = ok and selected != null and selected.state in [Van.State.EN_ROUTE, Van.State.DELIVERING, Van.State.RETURNING, Van.State.RESCUE]
		b.disabled = not ok
	var extra := ""
	if sim.green_wave_active():
		extra = "  ·  GREEN WAVE"
	if sim.call_ahead_left > 0:
		extra += "  ·  CALL AHEAD %d" % sim.call_ahead_left
	_hustle_val.text += extra
	_skip_btn.text = "F  Skipping... (F to stop)" if main.skipping else "F  Skip ahead >>"


# ============================================================= tools

func _build_tools() -> void:
	_tools = UIKit.ink(4)
	var v := UIKit.vbox(2)
	_tools.add_child(v)
	var defs := [["plus", "Zoom in"], ["minus", "Zoom out"], ["rot_l", "Rotate left (Q)"], ["rot_r", "Rotate right (E)"], ["home", "Reset view (H)"], ["gear", "Settings (Esc)"]]
	for d in defs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = d[1]
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", UIKit.flat(Palette.INK_3, 2))
		b.add_theme_stylebox_override("pressed", UIKit.flat(Palette.INK, 2))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var ic := LMIcon.new()
		ic.icon = d[0]
		ic.color = Palette.PAPER
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 9
		ic.offset_top = 9
		ic.offset_right = -9
		ic.offset_bottom = -9
		b.add_child(ic)
		var key: String = d[0]
		b.pressed.connect(func(): main.camera_tool(key))
		v.add_child(b)
	var help := Button.new()
	help.text = "?"
	help.custom_minimum_size = Vector2(38, 38)
	help.focus_mode = Control.FOCUS_NONE
	help.add_theme_font_override("font", UIKit.font("head"))
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Palette.PAPER)
	help.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	help.add_theme_stylebox_override("hover", UIKit.flat(Palette.INK_3, 2))
	help.add_theme_stylebox_override("pressed", UIKit.flat(Palette.INK, 2))
	help.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	help.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	help.tooltip_text = "Handbook: how everything works (F1)"
	help.pressed.connect(func(): main.open_help())
	v.add_child(help)
	_place(_tools, Control.PRESET_TOP_RIGHT, Vector2(16, 104), Vector2(46, 0))


# ============================================================= vehicle work order

func _build_detail() -> void:
	_detail = UIKit.paper(14)
	var v := UIKit.vbox(7)
	_detail.add_child(v)

	var head := UIKit.hbox(10)
	var hv := UIKit.vbox(-4)
	_d["company"] = UIKit.head("", 12, Palette.ORANGE)
	_d["code"] = UIKit.head("", 30, Palette.TEXT)
	hv.add_child(_d["company"])
	hv.add_child(_d["code"])
	head.add_child(hv)
	_d["type"] = UIKit.stamp("", Palette.SLATE, 13)
	_d["type"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_d["type"])
	head.add_child(UIKit.spacer())
	var close := UIKit.button("×", "paper", 18)
	close.custom_minimum_size = Vector2(32, 32)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func(): main.select_van(null))
	head.add_child(close)
	v.add_child(head)

	var drv := UIKit.hbox(8)
	_d["avatar_box"] = drv
	_d["driver"] = UIKit.label("", 14, Palette.TEXT, "bold")
	_d["driver"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_d["driver_sub"] = UIKit.label("", 12, Palette.TEXT_SOFT)
	_d["driver_sub"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drv.add_child(_d["driver"])
	drv.add_child(_d["driver_sub"])
	v.add_child(drv)

	var srow := UIKit.hbox(8)
	_d["status"] = UIKit.stamp("", Palette.BLUE, 14)
	_d["status"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(_d["status"])
	_d["dest"] = UIKit.label("", 13, Palette.TEXT_SOFT)
	_d["dest"].clip_text = true
	_d["dest"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(_d["dest"])
	v.add_child(srow)
	var prow := UIKit.hbox(8)
	_d["bar"] = LMBar.new()
	_d["bar"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(_d["bar"])
	_d["left"] = UIKit.mono("", 12, Palette.TEXT_SOFT)
	prow.add_child(_d["left"])
	v.add_child(prow)
	v.add_child(UIKit.rule())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["Condition", "Mood", "Load", "Next stop", "ETA", "Knows area", "Running cost", "Since report"]:
		var kl := UIKit.head(key, 14, Palette.TEXT_SOFT)
		_d[key + "_head"] = kl
		grid.add_child(kl)
		if key == "Condition" or key == "Mood":
			var mh := UIKit.hbox(8)
			mh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mh.alignment = BoxContainer.ALIGNMENT_END
			var mb := LMBar.new()
			mb.custom_minimum_size = Vector2(100, 8)
			mb.ticks = 4
			mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			mh.add_child(mb)
			var ml := UIKit.mono("", 13, Palette.TEXT, true)
			ml.custom_minimum_size.x = 74
			ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			mh.add_child(ml)
			grid.add_child(mh)
			_d[key + "_bar"] = mb
			_d[key] = ml
		else:
			var val := UIKit.mono("", 13, Palette.TEXT, true)
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			val.clip_text = true
			grid.add_child(val)
			_d[key] = val
	v.add_child(grid)
	v.add_child(UIKit.rule())
	_d["traits"] = UIKit.vbox(4)
	v.add_child(_d["traits"])
	_d["mods"] = UIKit.hbox(4)
	v.add_child(_d["mods"])

	var actions := UIKit.hbox(8)
	_d["start"] = UIKit.button("Send", "go", 16)
	_d["start"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d["start"].custom_minimum_size.y = 36
	_d["start"].pressed.connect(func():
		if selected:
			main.submit_player({"type": "start_route", "van": selected.id}))
	actions.add_child(_d["start"])
	_d["service"] = UIKit.button("Service  $%d" % int(Sim.SERVICE_COST), "paper", 16)
	_d["service"].custom_minimum_size.y = 36
	_d["service"].tooltip_text = "Drive to Gearbox Garage for a tune-up. Takes about %d min once a bay is free." % int(Sim.SERVICE_MIN)
	_d["service"].pressed.connect(func():
		if selected:
			main.submit_player({"type": "service_van", "van": selected.id}))
	actions.add_child(_d["service"])
	_d["actions"] = actions
	v.add_child(actions)
	_d["rescue"] = UIKit.button("Send rescue", "go", 16)
	_d["rescue"].custom_minimum_size.y = 36
	_d["rescue"].tooltip_text = "Send a vehicle from the depot to collect the stranded parcels before the tow truck takes them back."
	_d["rescue"].pressed.connect(func():
		var r := sim.best_rescuer(sim.player())
		if selected and r:
			main.submit_player({"type": "rescue", "van": r.id, "target": selected.id}))
	v.add_child(_d["rescue"])
	_place(_detail, Control.PRESET_TOP_RIGHT, Vector2(16, 104), Vector2(DETAIL_W, 0))
	route_sheet = RouteSheet.new()
	route_sheet.setup(sim, main)
	route_sheet.visible = false
	_place(route_sheet, Control.PRESET_TOP_RIGHT, Vector2(16, 104), Vector2(DETAIL_W + 20, 0))


func detail_start_button() -> Control:
	return _d["start"]


func _planning(v: Van) -> bool:
	return v != null and v.company == Sim.PLAYER and v.state in [Van.State.IDLE, Van.State.LOADING]


func select(v: Van) -> void:
	selected = v
	_detail.visible = v != null and not _planning(v)
	route_sheet.visible = _planning(v)
	if _planning(v):
		route_sheet.set_van(v)
	_tools.offset_right = -(16.0 + (DETAIL_W + 30.0 if v != null else 0.0))
	_tools.offset_left = _tools.offset_right - 46.0
	_detail_van_id = -1
	for id in _fleet_rows.keys():
		var row: Dictionary = _fleet_rows[id]
		var st := (row["panel"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		st.bg_color = Palette.PAPER_3 if (v != null and v.id == id) else Color(0, 0, 0, 0)


func _state_color(v: Van) -> Color:
	if v.state == Van.State.LOADING and v.ready:
		return Palette.ORANGE
	match v.state:
		Van.State.LOADING:
			return Palette.BLUE
		Van.State.EN_ROUTE:
			return Palette.GREEN
		Van.State.DELIVERING:
			return Palette.AMBER
		Van.State.RETURNING:
			return Palette.SLATE
		Van.State.BROKEN, Van.State.TOWING:
			return Palette.RED
		Van.State.TO_SHOP, Van.State.AT_SHOP:
			return Palette.AMBER
	return Palette.TEXT_SOFT


func _cond_color(c: float) -> Color:
	if c >= 0.6:
		return Palette.GREEN
	if c >= 0.35:
		return Palette.AMBER
	return Palette.RED


func _refresh_detail() -> void:
	var v := selected
	if v == null:
		return
	var c := sim.companies[v.company]
	var d := v.driver
	var mine := v.company == Sim.PLAYER
	if _detail_van_id != v.id:
		_detail_van_id = v.id
		_d["company"].text = c.name.to_upper()
		_d["company"].add_theme_color_override("font_color", c.color.darkened(0.1))
		_d["code"].text = v.code
		UIKit.set_stamp(_d["type"], v.spec()["name"], Palette.SLATE)
		var ab: HBoxContainer = _d["avatar_box"]
		if ab.get_child_count() > 2:
			ab.get_child(0).queue_free()
		var av := UIKit.avatar(d.initials(), d.avatar_color, 28)
		ab.add_child(av)
		ab.move_child(av, 0)
		var tv: VBoxContainer = _d["traits"]
		for ch in tv.get_children():
			ch.queue_free()
		for t in d.traits:
			var tr := UIKit.hbox(8)
			UIKit.tip(tr, Explain.trait_tip(d, t))
			tr.mouse_filter = Control.MOUSE_FILTER_STOP
			var st := UIKit.stamp(Traits.trait_name(t), Traits.trait_color(t).darkened(0.1), 12)
			st.custom_minimum_size.x = 92
			tr.add_child(st)
			var desc := UIKit.label(Traits.trait_desc(t) + (" (%s)" % City.DISTRICT_NAMES[d.home_district] if t == &"local" else ""), 12, Palette.TEXT_SOFT)
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tr.add_child(desc)
			tv.add_child(tr)
		_d["actions"].visible = false   # starting/servicing lives on the route sheet now
		var mh: HBoxContainer = _d["mods"]
		for ch in mh.get_children():
			ch.queue_free()
		if not v.mods.is_empty() or mine:
			mh.add_child(UIKit.head("Mods %d/%d" % [v.mods.size(), v.mod_slots()], 13, Palette.TEXT_SOFT))
			for m in v.mods:
				var cd := Cards.get_card(m)
				mh.add_child(UIKit.tip(UIKit.stamp(cd["name"], Cards.RARITY_COLORS[cd["rarity"]], 11), "%s: %s" % [cd["name"], cd["desc"]]))
			UIKit.tip(mh, "Upgrade cards installed on this vehicle. A %s has %d slots; a new mod on a full vehicle replaces the oldest." % [v.spec()["name"], v.mod_slots()])
	_d["driver"].text = d.name
	_d["driver_sub"].text = "· %d drops today · hired day %d" % [d.delivered_today, d.hired_day]
	var col := _state_color(v)
	UIKit.set_stamp(_d["status"], v.status_name(), col)
	var np := v.next_parcel()
	var dest := ""
	match v.state:
		Van.State.EN_ROUTE, Van.State.DELIVERING:
			if np:
				dest = "to " + sim.house(np.house)["address"]
		Van.State.RETURNING:
			dest = "back to " + c.depot_name
		Van.State.LOADING:
			dest = "loaded, press SEND" if v.ready else "loading at " + c.depot_name
		Van.State.BROKEN:
			dest = "tow truck in %d min" % ceili(v.timer)
		Van.State.TOWING:
			dest = "on the hook to Gearbox Garage"
		Van.State.TO_SHOP:
			dest = "driving to Gearbox Garage"
		Van.State.AT_SHOP:
			dest = ("%s · " % ("repair" if v.shop_reason == "repair" else "service")) + sim.garage_status(v)
		_:
			dest = "parked at " + c.depot_name
	_d["dest"].text = dest
	var bar: LMBar = _d["bar"]
	bar.color = col
	if v.state == Van.State.LOADING:
		bar.value = v.fill_ratio()
		_d["left"].text = "%d%% full" % int(v.fill_ratio() * 100)
	elif v.state == Van.State.AT_SHOP and not v.shop_waiting:
		var total := Sim.REPAIR_MIN if v.shop_reason == "repair" else Sim.SERVICE_MIN
		bar.value = 1.0 - v.shop_timer / total
		_d["left"].text = "in the bay"
	else:
		bar.value = v.route_progress()
		_d["left"].text = ("%d left" % v.stops_left()) if v.route_total > 0 else "—"
	var cb: LMBar = _d["Condition_bar"]
	cb.value = v.condition
	cb.color = _cond_color(v.condition)
	_d["Condition"].text = "%d%% · %.1f%%/h" % [int(v.condition * 100), sim.breakdown_risk(v) * 100.0]
	var mb: LMBar = _d["Mood_bar"]
	mb.value = d.mood / 100.0
	mb.color = Palette.GREEN if d.mood >= 60 else (Palette.AMBER if d.mood >= 40 else Palette.RED)
	_d["Mood"].text = "%d · x%.2f" % [int(d.mood), 0.85 + 0.3 * d.mood / 100.0]
	_d["Load"].text = "%d/%d · %d/%dkg" % [v.cargo.size(), v.slots, int(v.load_kg()), int(v.max_kg)]
	_d["Next stop"].text = sim.house(np.house)["address"] if np else "—"
	_d["ETA"].text = ("%d min" % ceili(sim.eta_minutes(v))) if v.state in [Van.State.EN_ROUTE, Van.State.RETURNING, Van.State.TOWING, Van.State.TO_SHOP] else "—"
	var dist := np.district if np else d.home_district
	_d["Knows area"].text = "%s %d%% · drops -%d%%" % [City.DISTRICT_NAMES[dist], int(d.familiarity[dist] * 100), int(35.0 * d.familiarity[dist])]
	var rc := sim.running_costs(v)
	_d["Running cost"].text = "$%d/h road · $%d/h parked" % [int(round(rc["drive"])), int(round(rc["wage_parked"]))]
	_d["Since report"].text = "+%s  -%s" % [UIKit.money(v.earned_today), UIKit.money(v.cost_today)]
	# Hover explanations for every row (cheap to refresh each frame).
	var cond_tip := Explain.condition(sim, v)
	UIKit.tip(_d["Condition_head"], cond_tip)
	UIKit.tip(_d["Condition"].get_parent(), cond_tip)
	UIKit.tip(_d["Mood_head"], Explain.mood(v))
	UIKit.tip(_d["Mood"].get_parent(), Explain.mood(v))
	UIKit.tip(_d["Load_head"], "Parcels aboard / slots, and weight / max load. Whichever fills first limits the load. Full loads score the Full Truck combo.")
	UIKit.tip(_d["Knows area_head"], Explain.area(v, dist))
	UIKit.tip(_d["Knows area"], Explain.area(v, dist))
	UIKit.tip(_d["Running cost_head"], Explain.costs(sim, v))
	UIKit.tip(_d["Running cost"], Explain.costs(sim, v))
	UIKit.tip(_d["Since report_head"], "What this vehicle earned (drops, streak, tips, clean runs) and cost (wages, fuel, tows, repairs) since the last evening report.")
	UIKit.tip(_d["status"], Explain.status(v))
	UIKit.tip(_d["ETA_head"], "Minutes until it reaches its next destination at current traffic.")
	var rescue: Button = _d["rescue"]
	rescue.visible = mine and v.state == Van.State.BROKEN and not v.cargo.is_empty()
	if rescue.visible:
		var r := sim.best_rescuer(sim.player())
		rescue.disabled = r == null
		rescue.text = ("SEND RESCUE (%s)" % r.code) if r else "NO VEHICLE AT THE DEPOT"
	if mine:
		var start: Button = _d["start"]
		start.disabled = not (v.state == Van.State.LOADING and not v.cargo.is_empty())
		start.text = "SEND" if v.state != Van.State.LOADING or v.ready or v.cargo.is_empty() else "SEND NOW (%d%%)" % int(v.fill_ratio() * 100)
		(_d["service"] as Button).disabled = v.state != Van.State.IDLE or c.money < Sim.SERVICE_COST


# ============================================================= shipment slip

func _build_tracking() -> void:
	var card := UIKit.paper(12)
	var h := UIKit.hbox(14)
	card.add_child(h)
	var left := UIKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UIKit.hbox(8)
	title.add_child(UIKit.head("Shipment slip", 18, Palette.TEXT))
	title.add_child(UIKit.spacer())
	_track["who"] = UIKit.label("", 12, Palette.TEXT_SOFT)
	_track["who"].size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(_track["who"])
	left.add_child(title)
	_timeline = LMTimeline.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_timeline)
	h.add_child(left)
	var sep := ColorRect.new()
	sep.color = Palette.RULE
	sep.custom_minimum_size = Vector2(2, 0)
	h.add_child(sep)
	var info := UIKit.vbox(0)
	info.custom_minimum_size = Vector2(230, 0)
	_track["code"] = UIKit.mono("", 15, Palette.TEXT, true)
	_track["from"] = UIKit.head("", 13, Palette.TEXT_SOFT)
	_track["to"] = UIKit.label("", 13, Palette.TEXT)
	_track["status"] = UIKit.head("", 15, Palette.BLUE)
	_track["due"] = UIKit.mono("", 12, Palette.TEXT_SOFT)
	for k in ["code", "from", "to", "status", "due"]:
		info.add_child(_track[k])
	h.add_child(info)
	_place(card, Control.PRESET_BOTTOM_LEFT, Vector2(16, 16), Vector2(780, 0))


func _tracked_parcel() -> Parcel:
	if selected != null and selected.company == Sim.PLAYER and selected.next_parcel() != null:
		return selected.next_parcel()
	var p := sim.player()
	var best: Parcel = null
	for x in p.waiting:
		if best == null or x.deadline < best.deadline:
			best = x
	if best == null and not p.sorting.is_empty():
		best = p.sorting[0]
	if best == null:
		for c in p.vans:
			if c.next_parcel():
				return c.next_parcel()
		for x in sim.recent:
			if x.company == Sim.PLAYER:
				return x
	return best


func _refresh_tracking() -> void:
	var p := _tracked_parcel()
	if p == null:
		_timeline.set_state(-1, ["", "", "", "", ""], false)
		_track["code"].text = "NO PARCELS YET"
		_track["from"].text = ""
		_track["to"].text = "Take a job from the board →"
		_track["status"].text = ""
		_track["due"].text = ""
		_track["who"].text = ""
		return
	var times := []
	for t in p.stage_times:
		times.append(Sim.clock(t) if t >= 0.0 else "")
	var now := sim.minutes()
	if p.stage < Parcel.Stage.DELIVERED:
		times[4] = "due " + Sim.clock(p.deadline)
	var late := p.late or (p.stage < Parcel.Stage.DELIVERED and now > p.deadline)
	_timeline.set_state(p.stage, times, late)
	_track["code"].text = "%s  %.1fkg" % [p.code(), p.weight]
	_track["from"].text = p.source_name().to_upper() + ("  ·  EXPRESS" if p.kind == Parcel.Kind.EXPRESS else "")
	_track["to"].text = "to " + sim.house(p.house)["address"]
	var status: String = Parcel.STAGE_NAMES[p.stage]
	if p.stage == Parcel.Stage.DELIVERED:
		status = "Delivered late" if p.late else "Delivered on time"
	_track["status"].text = status.to_upper()
	_track["status"].add_theme_color_override("font_color", Palette.RED if late else (Palette.GREEN if p.stage == Parcel.Stage.DELIVERED else Palette.BLUE))
	if p.stage < Parcel.Stage.DELIVERED:
		var left := p.deadline - now
		_track["due"].text = ("%d min left · pays %s" % [int(left), UIKit.money(p.pay())]) if left >= 0 else ("%d min overdue" % int(-left))
	else:
		_track["due"].text = "dropped at " + Sim.clock(p.stage_times[4])
	_track["who"].text = ("on " + p.van_code) if p.van_code != "" else "at the depot"


# ============================================================= clipboard

func _build_clipboard() -> void:
	var root := UIKit.vbox(0)
	clipboard = root
	var head := PanelContainer.new()
	var hs := UIKit.ink_style(6)
	hs.border_width_bottom = 2
	hs.corner_radius_bottom_left = 0
	hs.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", hs)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	var hh := UIKit.hbox(4)
	head.add_child(hh)
	for t in [["jobs", "Jobs"], ["fleet", "Fleet"], ["buy", "Buy"], ["rules", "Rules"], ["map", "Districts"]]:
		var b := Button.new()
		b.text = String(t[1]).to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UIKit.font("head"))
		b.add_theme_font_size_override("font_size", 16)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var key: String = t[0]
		b.pressed.connect(func(): set_tab(key))
		hh.add_child(b)
		_tab_btns[key] = b
	hh.add_child(UIKit.spacer())
	root.add_child(head)

	var body := PanelContainer.new()
	var bs := UIKit.paper_style(Palette.PAPER, 10)
	bs.border_width_top = 0
	bs.corner_radius_top_left = 0
	bs.corner_radius_top_right = 0
	body.add_theme_stylebox_override("panel", bs)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(stack)

	_pages["jobs"] = _page_jobs()
	_pages["fleet"] = _page_fleet()
	_pages["buy"] = _page_buy()
	_pages["rules"] = _page_rules()
	_pages["map"] = _page_map()
	for k in _pages.keys():
		var pg: Control = _pages[k]
		stack.add_child(pg)
		pg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_place(root, Control.PRESET_BOTTOM_RIGHT, Vector2(16, 16), Vector2(CLIP_W, CLIP_H))
	set_tab("jobs")


func set_tab(t: String) -> void:
	tab = t
	for k in _pages.keys():
		(_pages[k] as Control).visible = k == t
	for k in _tab_btns.keys():
		var b: Button = _tab_btns[k]
		var active: bool = k == t
		var s := UIKit.flat(Palette.PAPER if active else Color(0, 0, 0, 0), 2, 12, 2)
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", UIKit.flat(Palette.PAPER if active else Palette.INK_3, 2, 12, 2))
		b.add_theme_stylebox_override("pressed", s)
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(st, Palette.INK if active else Palette.TEXT_INV_SOFT)
	if t == "jobs":
		_jobs_sig = ""


func _scroll(inner: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return sc


# ------------------------------------------------------------- jobs page

func _page_jobs() -> Control:
	_jobs_list = UIKit.vbox(6)
	return _scroll(_jobs_list)


func _jobs_signature() -> String:
	var p := sim.player()
	var s := ""
	for j in p.jobs:
		s += "%d:%d," % [j.id, j.state]
	s += "|%d|" % p.level
	for k in p.vendors_unlocked.keys():
		s += str(k)
	return s


func _rebuild_jobs() -> void:
	for ch in _jobs_list.get_children():
		_jobs_list.remove_child(ch)
		ch.queue_free()
	_job_rows.clear()
	_vendor_rows.clear()
	var p := sim.player()
	var active := p.active_jobs()
	if not active.is_empty():
		_jobs_list.add_child(UIKit.head("On the way to your depot", 14, Palette.TEXT_SOFT))
		for j in active:
			_jobs_list.add_child(_job_row(j))
	_jobs_list.add_child(UIKit.head("Open jobs", 14, Palette.TEXT_SOFT))
	var offers := p.offers()
	offers.sort_custom(func(a: Job, b: Job): return a.pay > b.pay if a.rush == b.rush else a.rush)
	for j in offers:
		_jobs_list.add_child(_job_row(j))
	if offers.is_empty():
		_jobs_list.add_child(UIKit.label("No open jobs right now. New ones get posted every few minutes.", 13, Palette.TEXT_SOFT))
	_jobs_list.add_child(UIKit.rule())
	_jobs_list.add_child(UIKit.head("Vendors", 14, Palette.TEXT_SOFT))
	for vi in Vendors.count():
		_jobs_list.add_child(_vendor_row(vi))


func _job_row(j: Job) -> Control:
	var vd := Vendors.get_vendor(j.vendor)
	var panel := PanelContainer.new()
	var s := UIKit.flat(Palette.PAPER_2, 2, 10, 6)
	s.border_color = vd["color"]
	s.border_width_left = 6
	panel.add_theme_stylebox_override("panel", s)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := UIKit.hbox(10)
	panel.add_child(h)
	var who := UIKit.vbox(-3)
	who.custom_minimum_size.x = 118
	who.add_child(UIKit.head(vd["name"], 16, Palette.TEXT))
	who.add_child(UIKit.label(vd["kind"], 11, Palette.TEXT_SOFT))
	h.add_child(who)
	var mid := UIKit.vbox(-1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var load_row := UIKit.hbox(6)
	load_row.add_child(UIKit.mono("%d stops · %dkg" % [j.stops(), int(j.total_kg)], 13, Palette.TEXT, true))
	if j.needs_liftgate():
		load_row.add_child(UIKit.stamp("Heavy", Palette.RED, 11))
	if j.rush:
		load_row.add_child(UIKit.stamp("Rush", Palette.RED, 11))
	elif j.express:
		load_row.add_child(UIKit.stamp("Express", Palette.ORANGE, 11))
	mid.add_child(load_row)
	var sub := UIKit.label("", 11, Palette.TEXT_SOFT)
	mid.add_child(sub)
	h.add_child(mid)
	var pay := UIKit.mono(UIKit.money(j.pay), 20, Palette.GREEN.darkened(0.1), true)
	pay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pay)
	UIKit.tip(pay, Explain.job(sim, j))
	UIKit.tip(mid, Explain.job_timing(sim, j) + ("\nHeavy: needs a box truck or a vehicle with a Liftgate Kit." if j.needs_liftgate() else "") + ("\nRush: accept within 20 min; it's packed twice as fast and due 1 hour after drop-off." if j.rush else ""))
	var right: Control
	if j.state == Job.State.OFFERED:
		var b := UIKit.button("Take", "go", 15)
		UIKit.tip(b, "Accept this job. The vendor starts packing, then drives the parcels to your depot.")
		b.custom_minimum_size = Vector2(64, 30)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var jid := j.id
		b.pressed.connect(func(): main.submit_player({"type": "accept_job", "job": jid}))
		right = b
	else:
		var st := UIKit.stamp("", Palette.AMBER, 12)
		st.custom_minimum_size = Vector2(92, 0)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right = st
	h.add_child(right)
	_job_rows.append({"job": j, "sub": sub, "right": right})
	return panel


func first_take_button() -> Control:
	for r in _job_rows:
		var j: Job = r["job"]
		if j.state == Job.State.OFFERED and r["right"] is Button and not (r["right"] as Button).disabled:
			return r["right"]
	return null


func _vendor_row(vi: int) -> Control:
	var vd := Vendors.get_vendor(vi)
	var h := UIKit.hbox(10)
	var sw := ColorRect.new()
	sw.color = vd["color"]
	sw.custom_minimum_size = Vector2(10, 26)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	var who := UIKit.vbox(-3)
	who.custom_minimum_size.x = 140
	who.add_child(UIKit.head(vd["name"], 15, Palette.TEXT))
	who.add_child(UIKit.label(vd["kind"], 11, Palette.TEXT_SOFT))
	h.add_child(who)
	var info := UIKit.label("packs in %dm · pay ×%.2f%s" % [int(vd["prep"]), vd["mult"], "  · heavy freight" if vd["heavy"] >= 1.0 else ""], 12, Palette.TEXT_SOFT)
	UIKit.tip(info, "%s posts jobs on your board once they're a partner. They pack an order in %d min, pay x%.2f the normal rate, %d%% of their orders are express%s." % [vd["name"], int(vd["prep"]), vd["mult"], int(vd["express"] * 100), ", and most items are heavy (needs a liftgate)" if vd["heavy"] >= 1.0 else ""])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(info)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(130, 30)
	h.add_child(slot)
	var b := UIKit.button("Unlock %s" % UIKit.money(vd["unlock"]), "ink", 14)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(func(): main.submit_player({"type": "unlock_vendor", "vendor": vi}))
	slot.add_child(b)
	var st := UIKit.stamp("", Palette.GREEN, 12)
	st.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	st.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	st.grow_vertical = Control.GROW_DIRECTION_BOTH
	slot.add_child(st)
	_vendor_rows.append({"vi": vi, "btn": b, "stamp": st})
	return h


func _refresh_jobs() -> void:
	var sig := _jobs_signature()
	if sig != _jobs_sig:
		_jobs_sig = sig
		_rebuild_jobs()
	var p := sim.player()
	var now := sim.minutes()
	var has_box := false
	for v in p.vans:
		if v.spec()["heavy"]:
			has_box = true
	for r in _job_rows:
		var j: Job = r["job"]
		var vd := Vendors.get_vendor(j.vendor)
		if j.state == Job.State.OFFERED:
			if j.rush:
				r["sub"].text = "RUSH: take within %dm · deliver within %s of reaching your depot" % [maxi(0, int(j.expires - now)), _dur(j.promise * sim.promise_mult())]
			else:
				r["sub"].text = "deliver within %s of reaching your depot · offer ends in %dm" % [_dur(j.promise * sim.promise_mult()), maxi(0, int(j.expires - now))]
			var b: Button = r["right"]
			b.disabled = j.needs_liftgate() and not has_box
			b.tooltip_text = "Needs a box truck (liftgate)" if b.disabled else "%s packs it in %d min, then drops it at your depot." % [vd["name"], int(vd["prep"])]
		else:
			r["sub"].text = "arrives in ~%d min" % ceili(sim.job_eta_minutes(j))
			UIKit.set_stamp(r["right"], ("Packing %dm" % ceili(j.timer)) if j.state == Job.State.PACKING else "On the way", Palette.AMBER if j.state == Job.State.PACKING else Palette.BLUE)
	for r in _vendor_rows:
		var vi: int = r["vi"]
		var vd := Vendors.get_vendor(vi)
		var b: Button = r["btn"]
		var st: PanelContainer = r["stamp"]
		if p.vendors_unlocked.has(vi):
			b.visible = false
			st.visible = true
			UIKit.set_stamp(st, "Partner", Palette.GREEN)
		elif p.level < vd["level"]:
			b.visible = false
			st.visible = true
			UIKit.set_stamp(st, "Needs Lv %d" % vd["level"], Palette.SLATE)
		else:
			b.visible = true
			st.visible = false
			b.disabled = p.money < vd["unlock"]


static func _dur(m: float) -> String:
	var h := int(m) / 60
	var mm := int(m) % 60
	return ("%dh%02d" % [h, mm]) if h > 0 else ("%dm" % mm)


# ------------------------------------------------------------- fleet page

func _page_fleet() -> Control:
	var v := UIKit.vbox(6)
	var top := UIKit.hbox(8)
	top.add_child(UIKit.label("LOADED = waiting for you to SEND it. SEND? = send it before it's full.", 12, Palette.TEXT_SOFT))
	top.add_child(UIKit.spacer())
	var all := UIKit.button("Send all loaded", "go", 14)
	UIKit.tip(all, "Send every vehicle that's loaded and waiting at the depot.")
	all.pressed.connect(func():
		for van in sim.player().vans:
			if van.ready:
				main.submit_player({"type": "start_route", "van": van.id}))
	top.add_child(all)
	v.add_child(top)
	_fleet_list = UIKit.vbox(2)
	var sc := _scroll(_fleet_list)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	return v


func _on_van_added(v: Van) -> void:
	if v.company == Sim.PLAYER:
		_add_fleet_row(v)


func _add_fleet_row(v: Van) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.flat(Color(0, 0, 0, 0), 2, 6, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			main.select_van(v))
	var h := UIKit.hbox(9)
	panel.add_child(h)
	h.add_child(UIKit.avatar(v.driver.initials(), v.driver.avatar_color, 30))
	var idv := UIKit.vbox(-3)
	idv.custom_minimum_size.x = 112
	idv.add_child(UIKit.head(v.code, 17, Palette.TEXT))
	idv.add_child(UIKit.label(v.driver.name, 11, Palette.TEXT_SOFT))
	h.add_child(idv)
	var act := UIKit.label("", 13, Palette.TEXT)
	act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.clip_text = true
	h.add_child(act)
	var st := UIKit.stamp("", Palette.BLUE, 12)
	st.custom_minimum_size.x = 100
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(st)
	var cv := UIKit.vbox(1)
	cv.custom_minimum_size.x = 56
	cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cb := LMBar.new()
	cb.custom_minimum_size = Vector2(56, 6)
	cb.bar_height = 6
	cv.add_child(cb)
	var cl := UIKit.mono("", 10, Palette.TEXT_SOFT)
	cv.add_child(cl)
	h.add_child(cv)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(58, 30)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var go := UIKit.button("Send", "go", 14)
	go.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.tip(go, "Send this vehicle out on its route now.")
	go.pressed.connect(func(): main.submit_player({"type": "start_route", "van": v.id}))
	slot.add_child(go)
	h.add_child(slot)
	_fleet_list.add_child(panel)
	_fleet_rows[v.id] = {"van": v, "panel": panel, "act": act, "stamp": st, "bar": cb, "cond": cl, "go": go, "cv": cv}


func fleet_go_button() -> Control:
	for id in _fleet_rows.keys():
		var r: Dictionary = _fleet_rows[id]
		if (r["go"] as Button).visible and (r["van"] as Van).ready:
			return r["go"]
	for id in _fleet_rows.keys():
		var r: Dictionary = _fleet_rows[id]
		if (r["go"] as Button).visible:
			return r["go"]
	return null


func _refresh_fleet() -> void:
	for id in _fleet_rows.keys():
		var r: Dictionary = _fleet_rows[id]
		var v: Van = r["van"]
		var np := v.next_parcel()
		var act := ""
		match v.state:
			Van.State.IDLE:
				act = "Parked. Nothing it can carry yet." if sim.player().backlog() > 0 else "Parked, waiting for parcels"
			Van.State.LOADING:
				act = "%d parcels · %d%% full" % [v.cargo.size(), int(v.fill_ratio() * 100)]
			Van.State.EN_ROUTE:
				act = "Driving to " + sim.house(np.house)["address"]
			Van.State.DELIVERING:
				act = "At the door, " + sim.house(np.house)["address"]
			Van.State.RETURNING:
				act = "Heading back"
			Van.State.BROKEN:
				act = "Broke down. Tow in %dm" % ceili(v.timer)
			Van.State.TOWING:
				act = "Being towed to the garage"
			Van.State.TO_SHOP:
				act = "Driving to the garage"
			Van.State.AT_SHOP:
				act = sim.garage_status(v).capitalize()
		r["act"].text = act + "  ·  +%s -%s" % [UIKit.money(v.earned_today), UIKit.money(v.cost_today)]
		UIKit.tip(r["panel"], "%s · %s\n%s\n\n%s\n\nClick to open its route sheet." % [v.code, v.spec()["name"], Explain.status(v), Explain.costs(sim, v)])
		UIKit.tip(r["cv"], Explain.condition(sim, v))
		UIKit.set_stamp(r["stamp"], v.status_name(), _state_color(v))
		var cb: LMBar = r["bar"]
		cb.value = v.condition
		cb.color = _cond_color(v.condition)
		r["cond"].text = "cond %d%%" % int(v.condition * 100)
		var go: Button = r["go"]
		go.visible = v.state == Van.State.LOADING and not v.cargo.is_empty()
		go.text = "SEND" if v.ready else "SEND?"
		UIKit.tip(go, "Loaded and waiting: send it now." if v.ready else "Still loading (%d%% full). Send it now anyway?" % int(v.fill_ratio() * 100))
	var p := sim.player()
	var ready := 0
	for v in p.vans:
		if v.ready:
			ready += 1
	(_tab_btns["fleet"] as Button).text = "FLEET %d/%d" % [p.vans.size(), p.fleet_cap()] + (("  •%d" % ready) if ready > 0 else "")
	(_tab_btns["jobs"] as Button).text = "JOBS %d" % p.offers().size()


# ------------------------------------------------------------- buy page

func _page_buy() -> Control:
	var v := UIKit.vbox(8)
	var note := UIKit.label("", 12, Palette.TEXT_SOFT)
	v.add_child(note)
	_buy_cards["note"] = note
	var h := UIKit.hbox(8)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for t in VehicleTypes.ORDER:
		h.add_child(_buy_card(t))
	v.add_child(h)
	return v


func _buy_card(t: StringName) -> Control:
	var spec: Dictionary = VehicleTypes.DATA[t]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.paper_style(Palette.PAPER_2, 10, 4))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(3)
	p.add_child(v)
	v.add_child(UIKit.head(spec["name"], 19, Palette.TEXT))
	v.add_child(UIKit.mono(UIKit.money(spec["cost"]), 18, Palette.TEXT, true))
	UIKit.tip(p, Explain.vehicle_type(t))
	for row in [["Speed", spec["speed"] / 1.25], ["Space", spec["slots"] / 16.0], ["Max load", spec["kg"] / 900.0], ["Tough", 1.0 / spec["wear"] / 1.25]]:
		var rh := UIKit.hbox(6)
		var l := UIKit.head(row[0], 12, Palette.TEXT_SOFT)
		l.custom_minimum_size.x = 58
		rh.add_child(l)
		var b := LMBar.new()
		b.value = row[1]
		b.ticks = 5
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(b)
		v.add_child(rh)
	v.add_child(UIKit.mono("%d slots · %dkg%s" % [spec["slots"], int(spec["kg"]), " · liftgate" if spec["heavy"] else ""], 11, Palette.TEXT_SOFT))
	var desc := UIKit.label(spec["desc"], 12, Palette.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)
	var b := UIKit.button("Buy", "go", 15)
	b.pressed.connect(func(): main.submit_player({"type": "buy_van", "vehicle": t}))
	v.add_child(b)
	_buy_cards[t] = b
	return p


func _refresh_buy() -> void:
	var p := sim.player()
	(_buy_cards["note"] as Label).text = "Fleet %d of %d at %s. Level up to raise the cap." % [p.vans.size(), p.fleet_cap(), p.level_info()["name"]]
	for t in VehicleTypes.ORDER:
		var spec: Dictionary = VehicleTypes.DATA[t]
		var b: Button = _buy_cards[t]
		if p.level < spec["level"]:
			b.disabled = true
			b.text = "UNLOCKS AT LV %d" % spec["level"]
		elif p.vans.size() >= p.fleet_cap():
			b.disabled = true
			b.text = "FLEET FULL"
		elif p.money < sim.van_price(p, t):
			b.disabled = true
			b.text = "NEED %s" % UIKit.money(sim.van_price(p, t))
		else:
			b.disabled = false
			b.text = "BUY %s" % UIKit.money(sim.van_price(p, t)) if sim.van_price(p, t) < spec["cost"] else "BUY"


# ------------------------------------------------------------- rules page

func _page_rules() -> Control:
	var v := UIKit.vbox(5)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.head("Auto-send", 18, Palette.TEXT))
	row.add_child(UIKit.spacer())
	var tog := UIKit.button("Off", "paper", 15)
	tog.custom_minimum_size.x = 70
	tog.pressed.connect(func(): main.submit_player({"type": "set_auto_dispatch", "value": not sim.player().auto_dispatch}))
	row.add_child(tog)
	_rules["auto"] = tog
	UIKit.tip(tog, "Turn automatic sending on or off for every vehicle. Auto-load (filling vehicles at the depot) is set per vehicle on its route sheet.")
	v.add_child(row)
	var d1 := UIKit.label("When on, loaded vehicles leave by themselves using the rules below. They also leave at once if any parcel aboard is due within 35 min. When off, you press SEND.", 12, Palette.TEXT_SOFT)
	d1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d1)
	_rules["thr_l"] = UIKit.label("", 13, Palette.TEXT, "bold")
	v.add_child(_rules["thr_l"])
	_rules["thr"] = UIKit.slider(25, 100, 5)
	_rules["thr"].value_changed.connect(func(x): main.submit_player({"type": "set_threshold", "value": x / 100.0}))
	v.add_child(_rules["thr"])
	_rules["wait_l"] = UIKit.label("", 13, Palette.TEXT, "bold")
	v.add_child(_rules["wait_l"])
	_rules["wait"] = UIKit.slider(5, 60, 5)
	_rules["wait"].value_changed.connect(func(x): main.submit_player({"type": "set_max_wait", "value": x}))
	v.add_child(_rules["wait"])
	v.add_child(UIKit.rule())
	_rules["svc_l"] = UIKit.label("", 13, Palette.TEXT, "bold")
	v.add_child(_rules["svc_l"])
	_rules["svc"] = UIKit.slider(0, 70, 5)
	_rules["svc"].value_changed.connect(func(x): main.submit_player({"type": "set_auto_service", "value": x / 100.0}))
	v.add_child(_rules["svc"])
	var d2 := UIKit.label("Parked vehicles below this condition drive to Gearbox Garage for a $%d service (%d min, back to 100%%). A breakdown costs a tow ($%d), a repair ($%d), about %d min off the road, and late parcels. Breakdown risk per hour of driving: 0.2%% at 90%% condition, 1.5%% at 70%%, 4%% at 50%%, 8%% at 30%%." % [int(Sim.SERVICE_COST), int(Sim.SERVICE_MIN), int(Sim.TOW_COST), int(Sim.REPAIR_COST), int(Sim.TOW_WAIT + Sim.REPAIR_MIN)], 12, Palette.TEXT_SOFT)
	d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d2)
	return _scroll(v)


func _refresh_rules() -> void:
	var p := sim.player()
	var tog: Button = _rules["auto"]
	tog.text = "ON" if p.auto_dispatch else "OFF"
	var col := Color("8fb07a") if p.auto_dispatch else Palette.PAPER_2
	(tog.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = col
	(tog.get_theme_stylebox("hover") as StyleBoxFlat).bg_color = col.lightened(0.1)
	_rules["thr"].set_value_no_signal(p.dispatch_threshold * 100.0)
	_rules["wait"].set_value_no_signal(p.max_wait)
	_rules["svc"].set_value_no_signal(p.auto_service * 100.0)
	_rules["thr_l"].text = "Leave when %d%% full" % int(p.dispatch_threshold * 100)
	_rules["wait_l"].text = "…or after waiting %d min (express leaves early)" % int(p.max_wait)
	_rules["svc_l"].text = ("Auto-service below %d%% condition" % int(p.auto_service * 100)) if p.auto_service > 0 else "Auto-service: off"


# ------------------------------------------------------------- districts page

func _page_map() -> Control:
	var v := UIKit.vbox(8)
	var l := UIKit.label("Each walk-in order goes to you with a chance equal to your share in its district. Every 10 minutes share drifts toward whoever has the better reputation there: on-time drops (early ones most) raise yours, late or overdue parcels lower it. Hover a district for details.", 12, Palette.TEXT_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	for d in 4:
		var row := UIKit.vbox(2)
		var top := UIKit.hbox(8)
		top.add_child(UIKit.head(City.DISTRICT_NAMES[d], 16, Palette.TEXT))
		top.add_child(UIKit.spacer())
		var sh := UIKit.mono("", 12, Palette.TEXT_SOFT)
		top.add_child(sh)
		row.add_child(top)
		var bar := LMBar.new()
		bar.split = true
		bar.bar_height = 12.0
		bar.color = Palette.ORANGE
		bar.right_color = Palette.PURPLE
		bar.ticks = 10
		bar.custom_minimum_size.y = 14
		row.add_child(bar)
		v.add_child(row)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_district_rows.append({"share": sh, "bar": bar, "row": row})
	return v


func _refresh_map() -> void:
	for d in 4:
		var r: Dictionary = _district_rows[d]
		var s := sim.share[d]
		(r["bar"] as LMBar).value = s
		var gap: float = sim.score[d][0] - sim.score[d][1]
		var trend := "rising" if gap > 0.01 else ("falling" if gap < -0.01 else "steady")
		r["share"].text = "you %d%% (%s) · rep %d vs %d" % [int(round(s * 100)), trend, int(sim.score[d][0] * 100), int(sim.score[d][1] * 100)]
		UIKit.tip(r["row"], Explain.share(sim, d))


# ============================================================= overlay

func _build_overlay() -> void:
	_tag = PanelContainer.new()
	var ts := UIKit.ink_style(6)
	ts.content_margin_top = 2
	ts.content_margin_bottom = 2
	ts.border_width_bottom = 3
	_tag.add_theme_stylebox_override("panel", ts)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(6)
	_tag.add_child(h)
	_tag_code = UIKit.head("", 16, Palette.PAPER)
	_tag_state = UIKit.head("", 13, Palette.ORANGE)
	_tag_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_tag_code)
	h.add_child(_tag_state)
	add_child(_tag)
	_tag.visible = false

	_toasts = UIKit.vbox(6)
	add_child(_toasts)
	_fps = UIKit.mono("", 12, Palette.PAPER, true)
	_fps.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_fps.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_fps)


func _toast(text: String, kind: String) -> void:
	var colors := {"info": Palette.BLUE, "good": Palette.GREEN, "rival": Palette.PURPLE, "bad": Palette.RED, "rush": Palette.ORANGE, "streak": Palette.AMBER, "combo": Palette.BLUE.lightened(0.15)}
	var c: Color = colors.get(kind, Palette.BLUE)
	var p := PanelContainer.new()
	var st := UIKit.paper_style(Palette.PAPER, 10, 4)
	st.border_width_left = 8
	st.content_margin_left = 12
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(8)
	var dot := ColorRect.new()
	dot.color = c
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(UIKit.label(text, 14, Palette.TEXT, "bold"))
	p.add_child(h)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(p)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.5 if kind != "bad" else 7.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _refresh_tag(cam: Camera3D, world: WorldView) -> void:
	if selected == null:
		_tag.visible = false
		return
	var wp := world.van_render_pos(selected) + Vector3(0, 2.9, 0)
	if cam.is_position_behind(wp):
		_tag.visible = false
		return
	_tag.visible = true
	_tag_code.text = selected.code
	_tag_state.text = selected.status_name().to_upper() + ("  x%.1f" % selected.route_mult if selected.route_mult > 1.0 and selected.on_road() else "")
	_tag_state.add_theme_color_override("font_color", _state_color(selected).lightened(0.3))
	_tag.position = cam.unproject_position(wp) - Vector2(_tag.size.x * 0.5, _tag.size.y)


# ============================================================= per frame

func refresh(speed: int, cam: Camera3D, world: WorldView) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	_clock_panel.size = _clock_panel.get_combined_minimum_size()
	_clock_panel.position = Vector2(floorf((vp.x - _clock_panel.size.x) * 0.5), 12)
	_fps.visible = show_fps
	if show_fps:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
		_fps.position = Vector2(20, 282)
	_toasts.size = _toasts.get_combined_minimum_size()
	_toasts.position = Vector2(floorf((vp.x - _toasts.size.x) * 0.5), 104)
	var p := sim.player()
	var r := sim.rival()
	var li := p.level_info()
	var nxt := p.next_level_info()
	_level_name.text = "LV %d · %s" % [p.level, String(li["name"]).to_upper()]
	if nxt.is_empty():
		_level_bar.value = 1.0
		_level_sub.text = "top of the town · %s earned" % UIKit.money(p.lifetime_revenue)
	else:
		_level_bar.value = (p.lifetime_revenue - li["revenue"]) / (nxt["revenue"] - li["revenue"])
		_level_sub.text = "%s / %s earned" % [UIKit.money(p.lifetime_revenue), UIKit.money(nxt["revenue"])]
	var day_txt := "DAY %d/%d" % [sim.day(), Season.DAYS] if sim.season_on() else "DAY %d" % sim.day()
	if sim.season_on() and sim.today_type != "normal":
		day_txt += " · " + String(Season.DAY_TYPES[sim.today_type]["name"]).to_upper()
	_day.text = "%s · %s%s" % [day_txt, String(Sim.WEATHER[sim.weather]).to_upper(), "  ·  PAUSED" if speed == 0 else ""]
	var conds: Array = []
	if sim.is_peak_day():
		conds.append("HOLIDAY PEAK: DOUBLE DEMAND")
	if sim.twist != "":
		conds.append(Season.twist_name(sim.twist).to_upper())
	if sim.boss_rule() != "":
		conds.append("BOSS: " + String(Bosses.get_boss(sim.boss_rule())["client"]).to_upper())
	if sim.is_rush_hour():
		conds.append("RUSH HOUR: traffic slow")
	if not sim.city.closures.is_empty():
		conds.append("%d ROAD%s CLOSED" % [sim.city.closures.size(), "S" if sim.city.closures.size() > 1 else ""])
	if sim.weather == 1:
		conds.append("RAIN: slower roads, more breakdowns")
	elif sim.weather == 2:
		conds.append("FOG: slower roads")
	_conditions.text = "   ·   ".join(conds)
	_conditions.position = Vector2(floorf((vp.x - _conditions.size.x) * 0.5), 64 + 12)
	if not p.contract.is_empty():
		_contract_label.text = Contracts.describe(p.contract)
		var prog := Contracts.progress(p.contract, p.counters)
		_contract_bar.value = prog / float(p.contract["target"])
		_contract_val.text = ("DONE  +%s" % UIKit.money(p.contract["reward"])) if p.contract_done else "%d / %d" % [int(prog), p.contract["target"]]
		_contract_val.add_theme_color_override("font_color", Palette.GREEN if p.contract_done else Palette.TEXT)
	else:
		_contract_label.text = "none today"
		_contract_bar.value = 0.0
		_contract_val.text = ""
	if selected:
		var planning := _planning(selected)
		if planning != route_sheet.visible:
			select(selected)
		if planning:
			route_sheet.refresh()
	_clock.text = sim.clock_now()
	for s in _speed_btns.keys():
		var b: Button = _speed_btns[s]
		var on: bool = s == speed
		(b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Palette.ORANGE if on else Palette.PAPER_2
	_cash.text = UIKit.money(p.money)
	_cash.add_theme_color_override("font_color", Palette.RED if p.money < 0 else Palette.TEXT)
	var dm := p.ledger_total()
	_cash_delta.text = "%s%s since report" % ["+" if dm >= 0 else "", UIKit.money(dm)]
	_cash_delta.add_theme_color_override("font_color", Palette.GREEN if dm >= 0 else Palette.RED)
	_rival_sub.text = "%d vans · %d%% of walk-ins · %d waiting" % [r.vans.size(), int(round((1.0 - sim.total_share()) * 100)), r.backlog()]

	var rate := p.ontime_rate_today()
	_stats["ontime"]["value"].text = "—" if rate < 0 else "%d%%" % int(rate * 100)
	_stats["ontime"]["sub"].text = ("yesterday %d%%" % int(p.ontime_yesterday * 100)) if p.ontime_yesterday >= 0 else "no history yet"
	_stats["done"]["value"].text = str(p.delivered_today)
	_stats["done"]["sub"].text = "%s today" % UIKit.money(p.revenue_today)
	_stats["share"]["value"].text = "%d%%" % int(round(sim.total_share() * 100))
	_stats["share"]["sub"].text = "zoomer %d%%" % int(round((1.0 - sim.total_share()) * 100))
	_stats["fleet"]["value"].text = "%d/%d" % [p.vans_out(), p.vans.size()]
	var shop := p.count_state([Van.State.BROKEN, Van.State.TOWING, Van.State.TO_SHOP, Van.State.AT_SHOP])
	var ready := 0
	for v in p.vans:
		if v.ready:
			ready += 1
	_stats["fleet"]["sub"].text = "%d ready · %d in shop" % [ready, shop]

	# The route sheet needs the whole right column; it has its own depot tab.
	clipboard.visible = not route_sheet.visible
	_refresh_season()
	_refresh_powers()
	_tip_frame += 1
	if _tip_frame % 15 == 0:
		_refresh_tips()
	_refresh_detail()
	_refresh_tracking()
	_refresh_fleet()
	match tab:
		"jobs":
			_refresh_jobs()
		"buy":
			_refresh_buy()
		"rules":
			_refresh_rules()
		"map":
			_refresh_map()
	_refresh_tag(cam, world)
