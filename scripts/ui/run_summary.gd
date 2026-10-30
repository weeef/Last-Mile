class_name RunSummary
extends ModalSheet
## End of a season: survived or evicted. Shows the score, the reputation it
## banked, goals completed, what's unlocked now, and what to chase next.

signal again_requested
signal title_requested


func setup(r: Dictionary, changes: Dictionary, profile: Profile, last_report: Dictionary) -> void:
	var won: bool = r.get("won", false)
	var top := UIKit.hbox(14)
	var tv := UIKit.vbox(-6)
	var sub := "%s · heat %d%s" % [Season.charter(r.get("charter", "courier"))["name"], r.get("heat", 0), " · daily run" if r.get("daily", false) else ""]
	tv.add_child(UIKit.label(sub.to_upper(), 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("Season survived!" if won else "Evicted on day %d" % r.get("day", 1), 42, Palette.GREEN if won else Palette.RED))
	top.add_child(tv)
	top.add_child(UIKit.spacer())
	var sv := UIKit.vbox(-4)
	sv.add_child(UIKit.head("Score", 13, Palette.TEXT_SOFT))
	sv.add_child(UIKit.mono(str(r.get("score", 0)), 34, Palette.TEXT, true))
	if changes.get("new_best", false):
		sv.add_child(UIKit.stamp("New best", Palette.ORANGE, 13))
	top.add_child(sv)
	body.add_child(top)

	var lease: Dictionary = last_report.get("lease", {})
	var line := ""
	if won:
		line = "You paid every lease and made it through Holiday Peak. Zoomer Express is nervous."
	elif not lease.is_empty():
		line ="The landlord wanted %s. You couldn't cover it, and the locks were changed overnight." % UIKit.money(lease.get("amount", 0.0))
	var ll := UIKit.label(line, 14, Palette.TEXT)
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll.custom_minimum_size.x = 820
	body.add_child(ll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 2)
	for item in [["Leases paid", "%d / %d" % [r.get("leases_paid", 0), Season.LEASES.size()]], ["Revenue", UIKit.money(r.get("revenue", 0.0))],
			["Delivered", str(r.get("delivered", 0))], ["On time", "%d%%" % int(r.get("ontime_rate", 0.0) * 100)],
			["Best streak", str(r.get("best_streak", 0))], ["Best day", "%d drops" % r.get("best_day", 0)],
			["Stars", str(r.get("stars", 0))], ["Fleet", "%d vehicles" % r.get("fleet", 0)]]:
		var v := UIKit.vbox(-4)
		v.add_child(UIKit.head(item[0], 12, Palette.TEXT_SOFT))
		v.add_child(UIKit.mono(item[1], 20, Palette.TEXT, true))
		grid.add_child(v)
	body.add_child(grid)
	body.add_child(UIKit.rule())

	# Reputation banked
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UIKit.flat(Palette.INK_2, 3, 14, 10))
	var rv := UIKit.vbox(4)
	rp.add_child(rv)
	var rh := UIKit.hbox(10)
	rh.add_child(UIKit.head("+%d rep banked" % changes.get("rep", 0), 26, Palette.AMBER.lightened(0.2)))
	rh.add_child(UIKit.spacer())
	var bal := UIKit.mono("%d rep total" % profile.rep, 15, Palette.PAPER, true)
	bal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(bal)
	rv.add_child(rh)
	for g in changes.get("goals", []):
		rv.add_child(UIKit.label("Goal: %s (+%d)" % [g["name"], g["rep"]], 14, Palette.GREEN.lightened(0.4), "bold"))
	if changes.get("heat_unlocked", -1) > 0:
		rv.add_child(UIKit.label("Heat %d unlocked: %s" % [changes["heat_unlocked"], Season.HEAT[changes["heat_unlocked"]]], 14, Palette.ORANGE.lightened(0.2), "bold"))
	var hint := profile.next_unlock_hint()
	if hint != "":
		rv.add_child(UIKit.label("Next: " + hint, 13, Palette.TEXT_INV_SOFT, "head_semi"))
	body.add_child(rp)

	var goals := profile.open_goals(3)
	if not goals.is_empty():
		var gh := UIKit.hbox(8)
		gh.add_child(UIKit.head("Up next", 14, Palette.TEXT_SOFT))
		for g in goals:
			gh.add_child(UIKit.stamp("%s +%d" % [g["desc"], g["rep"]], Palette.BLUE, 12))
		body.add_child(gh)
	if r.get("daily", false):
		body.add_child(UIKit.label("Daily streak: %d day%s. A new daily run opens tomorrow." % [profile.daily_streak, "" if profile.daily_streak == 1 else "s"], 13, Palette.GREEN, "bold"))

	var actions := UIKit.hbox(10)
	var menu := UIKit.button("Main menu", "paper", 17)
	menu.pressed.connect(func(): title_requested.emit())
	actions.add_child(menu)
	actions.add_child(UIKit.spacer())
	if not r.get("daily", false):
		var again := UIKit.button("Next season", "go", 20)
		again.custom_minimum_size = Vector2(220, 46)
		again.pressed.connect(func(): again_requested.emit())
		actions.add_child(again)
	body.add_child(actions)
