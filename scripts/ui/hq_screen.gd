class_name HQScreen
extends ModalSheet
## Head office: spend reputation on permanent upgrades, check goals and records.

signal closed

var profile: Profile


func setup(p: Profile) -> void:
	profile = p
	_build()


func _build() -> void:
	ModalSheet.clear(body)
	var top := UIKit.hbox(12)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("BETWEEN SEASONS", 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("Head office", 36, Palette.TEXT))
	top.add_child(tv)
	top.add_child(UIKit.spacer())
	var rv := UIKit.vbox(-4)
	rv.add_child(UIKit.head("Reputation", 12, Palette.TEXT_SOFT))
	rv.add_child(UIKit.mono("%d" % profile.rep, 30, Palette.AMBER, true))
	top.add_child(rv)
	body.add_child(top)

	var cols := UIKit.hbox(18)
	var left := UIKit.vbox(6)
	left.custom_minimum_size.x = 520
	left.add_child(UIKit.head("Upgrades · kept forever", 20, Palette.TEXT))
	for id in Profile.UPGRADE_ORDER:
		left.add_child(_upgrade_row(id))
	cols.add_child(left)

	var right := UIKit.vbox(6)
	right.custom_minimum_size.x = 380
	right.add_child(UIKit.head("Goals · %d / %d" % [profile.goals.size(), Profile.GOALS.size()], 20, Palette.TEXT))
	var gl := UIKit.vbox(2)
	var shown := 0
	for g in Profile.GOALS:
		var done := profile.goals.has(g["id"])
		if done and shown >= 3:
			continue
		var h := UIKit.hbox(8)
		var mark := LMIcon.new()
		mark.icon = "check" if done else "pin"
		mark.color = Palette.GREEN if done else Palette.TEXT_SOFT
		mark.custom_minimum_size = Vector2(16, 16)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mark)
		var l := UIKit.label("%s: %s" % [g["name"], g["desc"]], 13, Palette.TEXT_SOFT if done else Palette.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UIKit.mono("+%d" % g["rep"], 13, Palette.GREEN if done else Palette.AMBER, true))
		gl.add_child(h)
		shown += 1
		if shown >= 9:
			break
	right.add_child(gl)
	right.add_child(UIKit.rule())
	right.add_child(UIKit.head("Records", 20, Palette.TEXT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 22)
	for item in [["Runs", str(profile.runs)], ["Seasons won", str(profile.wins)], ["Best score", str(profile.best_score)],
			["Best streak", str(profile.best_streak)], ["Best day", "%d drops" % profile.best_day], ["Daily streak", "%d days" % profile.daily_streak]]:
		var c := UIKit.vbox(-4)
		c.add_child(UIKit.head(item[0], 12, Palette.TEXT_SOFT))
		c.add_child(UIKit.mono(item[1], 17, Palette.TEXT, true))
		grid.add_child(c)
	right.add_child(grid)
	if not profile.history.is_empty():
		right.add_child(UIKit.head("Recent runs", 14, Palette.TEXT_SOFT))
		for i in mini(4, profile.history.size()):
			var r: Dictionary = profile.history[i]
			var line := "%s  %s · heat %d · day %d · %s" % ["WON " if r.get("won", false) else "OUT ", Season.charter(r.get("charter", "courier"))["name"], r.get("heat", 0), r.get("day", 1), str(r.get("score", 0))]
			right.add_child(UIKit.mono(line, 12, Palette.GREEN if r.get("won", false) else Palette.TEXT))
	cols.add_child(right)
	body.add_child(cols)

	var back := UIKit.button("Back", "ink", 17)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func(): closed.emit())
	body.add_child(back)


func _upgrade_row(id: String) -> Control:
	var u: Dictionary = Profile.UPGRADES[id]
	var lvl := profile.level(id)
	var max_lvl: int = u["cost"].size()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 12, 6))
	var h := UIKit.hbox(10)
	p.add_child(h)
	var v := UIKit.vbox(-2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.head(u["name"], 17, Palette.TEXT))
	v.add_child(UIKit.label(u["desc"], 12, Palette.TEXT_SOFT))
	h.add_child(v)
	var pips := UIKit.hbox(3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in max_lvl:
		var c := ColorRect.new()
		c.color = Palette.ORANGE if i < lvl else Palette.PAPER_3
		c.custom_minimum_size = Vector2(12, 12)
		pips.add_child(c)
	h.add_child(pips)
	var cost := profile.next_cost(id)
	var b := UIKit.button("Maxed" if cost < 0 else "Buy · %d" % cost, "go" if cost >= 0 and profile.rep >= cost else "paper", 14)
	b.custom_minimum_size.x = 104
	b.disabled = cost < 0 or profile.rep < cost
	b.pressed.connect(func():
		if profile.buy_upgrade(id):
			_build())
	h.add_child(b)
	return p
