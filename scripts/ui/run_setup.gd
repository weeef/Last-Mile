class_name RunSetup
extends ModalSheet
## Before a season: pick a charter (starting company) and a heat level, and see
## the lease schedule you're signing up for. Locked charters can be bought here
## with reputation.

signal chosen(charter_id: String, heat: int)
signal hq_requested
signal back_requested

var profile: Profile
var _charter := "courier"
var _heat := 0


func setup(p: Profile) -> void:
	profile = p
	_heat = profile.max_heat
	var last: Array = profile.history
	if not last.is_empty() and profile.charters.has(last[0].get("charter", "")):
		_charter = last[0]["charter"]
	_build()


func _build() -> void:
	ModalSheet.clear(body)
	var top := UIKit.hbox(12)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("A NEW LEASE ON MAPLE ST.", 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("New season", 36, Palette.TEXT))
	top.add_child(tv)
	top.add_child(UIKit.spacer())
	var rep := UIKit.head("%d rep" % profile.rep, 22, Palette.AMBER)
	rep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(rep)
	body.add_child(top)
	var intro := UIKit.label("Survive %d days. Rent is due every third evening and climbs every week. Miss one and you get a final notice; miss again and you're out. Day %d is Holiday Peak." % [Season.DAYS, Season.DAYS], 14, Palette.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 900
	body.add_child(intro)

	body.add_child(UIKit.head("Charter", 20, Palette.TEXT))
	var row := UIKit.hbox(10)
	for id in Season.CHARTER_ORDER:
		row.add_child(_charter_card(id))
	body.add_child(row)
	body.add_child(UIKit.rule())

	var bottom := UIKit.hbox(18)
	bottom.add_child(_heat_box())
	bottom.add_child(_lease_box())
	body.add_child(bottom)

	var actions := UIKit.hbox(10)
	var back := UIKit.button("Back", "paper", 17)
	back.pressed.connect(func(): back_requested.emit())
	actions.add_child(back)
	var hq := UIKit.button("Head office", "paper", 17)
	hq.pressed.connect(func(): hq_requested.emit())
	actions.add_child(hq)
	actions.add_child(UIKit.spacer())
	var go := UIKit.button("Sign the lease", "go", 20)
	go.custom_minimum_size = Vector2(220, 46)
	go.disabled = not profile.charters.has(_charter)
	go.pressed.connect(func(): chosen.emit(_charter, _heat))
	actions.add_child(go)
	body.add_child(actions)


func _charter_card(id: String) -> Control:
	var ch := Season.charter(id)
	var owned := profile.charters.has(id)
	var sel := id == _charter
	var p := PanelContainer.new()
	var st := UIKit.paper_style(Palette.PAPER if sel else Palette.PAPER_2, 12, 6 if sel else 4)
	st.border_color = Palette.ORANGE if sel else (Palette.INK if owned else Palette.RULE)
	if sel:
		st.set_border_width_all(4)
		st.border_width_bottom = 7
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(176, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.head(ch["name"], 19, Palette.TEXT if owned else Palette.TEXT_SOFT))
	var d := UIKit.label(ch["desc"], 12, Palette.TEXT if owned else Palette.TEXT_SOFT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(152, 64)
	v.add_child(d)
	var k := UIKit.label(ch["perk"], 12, Palette.RED.lightened(0.1), "bold")
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	k.custom_minimum_size = Vector2(152, 30)
	v.add_child(k)
	v.add_child(UIKit.mono("%s start · %d wins" % [UIKit.money(ch["cash"]), int(profile.wins_by_charter.get(id, 0))], 11, Palette.TEXT_SOFT))
	if owned:
		var b := UIKit.button("Selected" if sel else "Pick", "ink" if sel else "paper", 14)
		b.disabled = sel
		b.pressed.connect(func():
			_charter = id
			_build())
		v.add_child(b)
	else:
		var b := UIKit.button("Unlock · %d rep" % ch["unlock"], "go", 14)
		b.disabled = profile.rep < ch["unlock"]
		b.pressed.connect(func():
			if profile.unlock_charter(id):
				_charter = id
				_build())
		v.add_child(b)
	return p


func _heat_box() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 14, 10))
	p.custom_minimum_size = Vector2(430, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	var h := UIKit.hbox(8)
	h.add_child(UIKit.head("Heat", 20, Palette.TEXT))
	h.add_child(UIKit.spacer())
	var minus := UIKit.button("-", "paper", 18)
	minus.custom_minimum_size = Vector2(36, 32)
	minus.disabled = _heat <= 0
	minus.pressed.connect(func():
		_heat -= 1
		_build())
	h.add_child(minus)
	var val := UIKit.mono("%d" % _heat, 24, Palette.RED if _heat > 0 else Palette.TEXT, true)
	val.custom_minimum_size.x = 30
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(val)
	var plus := UIKit.button("+", "paper", 18)
	plus.custom_minimum_size = Vector2(36, 32)
	plus.disabled = _heat >= profile.max_heat
	plus.pressed.connect(func():
		_heat += 1
		_build())
	h.add_child(plus)
	v.add_child(h)
	if _heat == 0:
		v.add_child(UIKit.label(Season.HEAT[0], 13, Palette.TEXT))
	for i in range(1, _heat + 1):
		v.add_child(UIKit.label("%d · %s" % [i, Season.HEAT[i]], 13, Palette.TEXT))
	var more := "Win at heat %d to unlock heat %d. Higher heat scores and earns more rep." % [profile.max_heat, profile.max_heat + 1] if profile.max_heat < Season.MAX_HEAT else "Every heat level unlocked."
	var m := UIKit.label(more, 12, Palette.TEXT_SOFT)
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.custom_minimum_size.x = 400
	v.add_child(m)
	return p


func _lease_box() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 14, 10))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.head("Your lease", 20, Palette.TEXT))
	var m: float = Season.charter(_charter).get("lease", 1.0) * (1.0 - 0.08 * profile.level("landlord")) \
		* Season.heat_lease_mult(_heat)
	for w in Season.LEASES.size():
		var r := UIKit.hbox(8)
		var l := UIKit.head("Day %d%s" % [(w + 1) * Season.WEEK_DAYS, "  ·  Holiday Peak" if w == Season.LEASES.size() - 1 else ""], 15, Palette.TEXT_SOFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		r.add_child(UIKit.mono(UIKit.money(roundf(Season.LEASES[w] * m)), 16, Palette.TEXT, true))
		v.add_child(r)
	var strikes := (0 if _heat >= 4 else 1) + profile.level("grace")
	v.add_child(UIKit.label("Final notices allowed: %d" % strikes, 13, Palette.RED if strikes == 0 else Palette.TEXT, "bold"))
	var bonus := []
	if profile.level("till") > 0:
		bonus.append("+%s cash" % UIKit.money(100.0 * profile.level("till")))
	for id in ["dice", "scout", "hype", "shark"]:
		if profile.level(id) > 0:
			bonus.append(Profile.UPGRADES[id]["name"])
	v.add_child(UIKit.label("HQ: " + (", ".join(bonus) if not bonus.is_empty() else "no upgrades yet"), 12, Palette.TEXT_SOFT))
	return p
