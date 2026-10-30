class_name TitleScreen
extends Control
## Title screen over the slowly orbiting town: Continue, New season, Daily run,
## Head office, Load game, Settings, Quit. New/Daily/Load open a three-slot picker.
## A strip under the logo shows your reputation and what it unlocks next.

signal new_game(slot: int)
signal daily_game(slot: int)
signal hq_requested
signal load_game(slot: int)
signal settings_requested
signal quit_requested

var _card: PanelContainer
var _menu: VBoxContainer
var _slots_view: VBoxContainer
var _slots_title: Label
var _slots_list: VBoxContainer
var _mode := ""            # "new", "daily" or "load"
var profile: Profile
var _confirm := {}         # slot -> action awaiting a second click


func _ready() -> void:
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(Palette.INK, 0.85))
	g.set_color(1, Color(Palette.INK, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(0.75, 0.5)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_card = UIKit.paper(26)
	(_card.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom = 8
	_card.custom_minimum_size.x = 400
	var v := UIKit.vbox(10)
	_card.add_child(v)
	var top := UIKit.hbox(12)
	var logo := LMIcon.new()
	logo.icon = "box"
	logo.color = Palette.ORANGE
	logo.custom_minimum_size = Vector2(52, 52)
	top.add_child(logo)
	var tv := UIKit.vbox(-10)
	tv.add_child(UIKit.head("Last Mile", 58, Palette.TEXT))
	tv.add_child(UIKit.label("deliveries at the end of the line", 14, Palette.TEXT_SOFT, "head_semi"))
	top.add_child(tv)
	v.add_child(top)
	if profile == null:
		profile = Profile.load_or_new()
	v.add_child(_profile_strip())
	v.add_child(UIKit.rule())

	_menu = UIKit.vbox(8)
	v.add_child(_menu)
	_slots_view = UIKit.vbox(8)
	_slots_view.visible = false
	_slots_title = UIKit.head("", 20, Palette.TEXT)
	_slots_view.add_child(_slots_title)
	_slots_list = UIKit.vbox(8)
	_slots_view.add_child(_slots_list)
	var back := UIKit.button("Back", "paper", 16)
	back.pressed.connect(_show_menu)
	_slots_view.add_child(back)
	v.add_child(_slots_view)

	var foot := UIKit.label("prototype v0.8", 11, Palette.TEXT_SOFT, "mono")
	v.add_child(foot)
	add_child(_card)
	_card.rotation_degrees = -0.5
	_show_menu()


func _show_menu() -> void:
	_slots_view.visible = false
	_menu.visible = true
	for ch in _menu.get_children():
		ch.queue_free()
	var recent := SaveGame.most_recent_slot()
	if recent > 0:
		var m := SaveGame.meta(recent)
		var cont := UIKit.button("Continue", "go", 22)
		cont.custom_minimum_size.y = 50
		cont.pressed.connect(func(): load_game.emit(recent))
		_menu.add_child(cont)
		var sub := UIKit.label("Slot %d · %s · day %d · %s" % [recent, m.get("level_name", ""), m.get("day", 1), UIKit.money(m.get("money", 0.0))], 12, Palette.TEXT_SOFT, "mono")
		_menu.add_child(sub)
	var ng := UIKit.button("New season", "go" if recent < 0 else "paper", 20)
	ng.custom_minimum_size.y = 44
	ng.pressed.connect(func(): _show_slots("new"))
	_menu.add_child(ng)
	var dn := Season.daily_number()
	var played := profile.played_daily_today()
	var dl := UIKit.button("Daily run  ·  %s" % Season.charter(Season.daily_charter(dn))["name"], "green" if not played else "paper", 20)
	dl.custom_minimum_size.y = 44
	dl.tooltip_text = "Same town, charter and heat for everyone today. Come back tomorrow to keep your streak."
	dl.pressed.connect(func(): _show_slots("daily"))
	_menu.add_child(dl)
	var dsub := ""
	if played:
		dsub = "Played today · best %s · back tomorrow for day %d of your streak" % [str(profile.daily_best.get(dn, 0)), profile.daily_streak + 1]
	elif profile.daily_streak > 0 and profile.daily_last == dn - 1:
		dsub = "Keep it going: %d day streak!" % profile.daily_streak
	else:
		dsub = "New every day · heat %d · no HQ upgrades" % Season.DAILY_HEAT
	_menu.add_child(UIKit.label(dsub, 12, Palette.GREEN if not played else Palette.TEXT_SOFT, "mono"))
	var hq := UIKit.button("Head office  ·  %d rep" % profile.rep, "paper", 20)
	hq.custom_minimum_size.y = 44
	hq.pressed.connect(func(): hq_requested.emit())
	_menu.add_child(hq)
	var lg := UIKit.button("Load game", "paper", 20)
	lg.custom_minimum_size.y = 44
	lg.disabled = recent < 0
	lg.pressed.connect(func(): _show_slots("load"))
	_menu.add_child(lg)
	var st := UIKit.button("Settings", "paper", 20)
	st.custom_minimum_size.y = 44
	st.pressed.connect(func(): settings_requested.emit())
	_menu.add_child(st)
	var q := UIKit.button("Quit", "ink", 20)
	q.custom_minimum_size.y = 44
	q.pressed.connect(func(): quit_requested.emit())
	_menu.add_child(q)


func _show_slots(mode: String) -> void:
	_mode = mode
	_confirm.clear()
	_menu.visible = false
	_slots_view.visible = true
	_slots_title.text = {"new": "PICK A SLOT FOR YOUR NEW SEASON", "daily": "PICK A SLOT FOR TODAY'S DAILY RUN"}.get(mode, "LOAD A SAVED GAME")
	_rebuild_slots()


func _rebuild_slots() -> void:
	for ch in _slots_list.get_children():
		ch.queue_free()
	for s in range(1, SaveGame.SLOTS + 1):
		_slots_list.add_child(_slot_card(s))


func _slot_card(s: int) -> Control:
	var m := SaveGame.meta(s)
	var filled := not m.is_empty()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.paper_style(Palette.PAPER_2 if filled else Palette.PAPER, 12, 4))
	var h := UIKit.hbox(10)
	p.add_child(h)
	var tag := UIKit.head("%d" % s, 34, Palette.TEXT if filled else Palette.RULE)
	tag.custom_minimum_size.x = 26
	h.add_child(tag)
	var info := UIKit.vbox(-2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if filled:
		if m.get("season", false):
			var what := "Daily run" if m.get("daily", false) else "%s · heat %d" % [m.get("charter", ""), m.get("heat", 0)]
			info.add_child(UIKit.head(what, 17, Palette.TEXT))
			info.add_child(UIKit.mono("Day %d/%d · %s · %s" % [m.get("day", 1), Season.DAYS, m.get("clock", ""), UIKit.money(m.get("money", 0.0))], 12, Palette.TEXT))
		else:
			info.add_child(UIKit.head(String(m.get("level_name", "")), 17, Palette.TEXT))
			info.add_child(UIKit.mono("Day %d · %s · %s" % [m.get("day", 1), m.get("clock", ""), UIKit.money(m.get("money", 0.0))], 12, Palette.TEXT))
		info.add_child(UIKit.label("%d vehicles · saved %s" % [m.get("fleet", 0), _ago(int(m.get("saved_at", 0)))], 11, Palette.TEXT_SOFT))
	else:
		info.add_child(UIKit.head("Empty slot", 17, Palette.TEXT_SOFT))
	h.add_child(info)
	var actions := UIKit.vbox(4)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _mode == "new" or _mode == "daily":
		var b := UIKit.button("Start" if not filled else ("Sure?" if _confirm.get(s) == "new" else "Overwrite"), "go" if not filled or _confirm.get(s) == "new" else "paper", 15)
		b.custom_minimum_size.x = 104
		b.pressed.connect(func():
			if filled and _confirm.get(s) != "new":
				_confirm[s] = "new"
				_rebuild_slots()
			elif _mode == "daily":
				daily_game.emit(s)
			else:
				new_game.emit(s))
		actions.add_child(b)
	else:
		var b := UIKit.button("Load", "go", 15)
		b.custom_minimum_size.x = 104
		b.disabled = not filled
		b.pressed.connect(func(): load_game.emit(s))
		actions.add_child(b)
		if filled:
			var del := UIKit.button("Delete?" if _confirm.get(s) == "del" else "Delete", "ink" if _confirm.get(s) == "del" else "paper", 12)
			del.pressed.connect(func():
				if _confirm.get(s) == "del":
					SaveGame.delete(s)
					_confirm.erase(s)
					if SaveGame.most_recent_slot() < 0:
						_show_menu()
						return
				else:
					_confirm[s] = "del"
				_rebuild_slots())
			actions.add_child(del)
	h.add_child(actions)
	return p


func _profile_strip() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.flat(Palette.INK_2, 3, 10, 6))
	var v := UIKit.vbox(0)
	p.add_child(v)
	var h := UIKit.hbox(10)
	h.add_child(UIKit.head("%d rep" % profile.rep, 18, Palette.AMBER.lightened(0.2)))
	var rec := "first season ahead" if profile.runs == 0 else "%d runs · %d won · best %s · heat %d unlocked" % [profile.runs, profile.wins, str(profile.best_score), profile.max_heat]
	var rl := UIKit.label(rec, 12, Palette.TEXT_INV_SOFT, "mono")
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(rl)
	v.add_child(h)
	var hint := profile.next_unlock_hint()
	if hint != "":
		v.add_child(UIKit.label(hint, 12, Palette.PAPER, "head_semi"))
	return p


static func _ago(t: int) -> String:
	var d := int(Time.get_unix_time_from_system()) - t
	if d < 60:
		return "just now"
	if d < 3600:
		return "%d min ago" % (d / 60)
	if d < 86400:
		return "%d h ago" % (d / 3600)
	return "%d days ago" % (d / 86400)


func _process(_d: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	_card.size = _card.get_combined_minimum_size()
	_card.position = Vector2(maxf(40.0, vp.x * 0.08), floorf((vp.y - _card.size.y) * 0.5))
