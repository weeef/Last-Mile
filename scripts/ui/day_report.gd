class_name DayReport
extends ModalSheet
## Evening: the day's report card, then draft one upgrade card.

var sim: Sim
var main: Node
var _picking: StringName = &""


func setup(p_sim: Sim, p_main: Node) -> void:
	sim = p_sim
	main = p_main
	sim.event.connect(_on_event)
	_build()


func _on_event(n: String, _d: Dictionary) -> void:
	if n == "draft_rerolled" and is_inside_tree():
		_picking = &""
		_build()


func _build() -> void:
	ModalSheet.clear(body)
	var r := sim.report
	var top := UIKit.hbox(14)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("END OF DAY", 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("Day %d report" % r.get("day", 1), 36, Palette.TEXT))
	top.add_child(tv)
	top.add_child(UIKit.spacer())
	var stars := StarRow.new()
	stars.stars = r.get("stars", 0)
	stars.custom_minimum_size = Vector2(150, 46)
	top.add_child(stars)
	body.add_child(top)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	var rate: float = r.get("rate", 0.0)
	for item in [["Delivered", str(r.get("delivered", 0))], ["On time", "%d%%" % int(rate * 100)],
			["Revenue", UIKit.money(r.get("revenue", 0.0))], ["Net today", UIKit.money(r.get("net", 0.0))],
			["Late", str(r.get("late", 0))], ["Nobody home", str(r.get("failed_attempts", 0))],
			["Breakdowns", str(r.get("breakdowns", 0))], ["Stars so far", str(sim.player().stars_total)]]:
		var v := UIKit.vbox(-4)
		v.add_child(UIKit.head(item[0], 12, Palette.TEXT_SOFT))
		v.add_child(UIKit.mono(item[1], 20, Palette.TEXT, true))
		grid.add_child(v)
	body.add_child(grid)

	var con: Dictionary = r.get("contract", {})
	var crow := PanelContainer.new()
	crow.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 12, 8))
	var ch := UIKit.hbox(10)
	crow.add_child(ch)
	if con.is_empty():
		ch.add_child(UIKit.label("No contract today.", 14, Palette.TEXT_SOFT))
	else:
		ch.add_child(UIKit.head("Contract", 14, Palette.TEXT_SOFT))
		var d := UIKit.label(Contracts.describe(con), 14, Palette.TEXT, "bold")
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch.add_child(d)
		if r.get("contract_done", false):
			ch.add_child(UIKit.mono("+" + UIKit.money(r.get("reward", 0.0)), 15, Palette.GREEN, true))
			ch.add_child(UIKit.stamp("Done", Palette.GREEN, 14))
		else:
			ch.add_child(UIKit.stamp("Missed", Palette.RED, 14))
	body.add_child(crow)
	if sim.season_on():
		body.add_child(_season_row(r))
	body.add_child(UIKit.rule())
	if _picking == &"":
		_build_draft()
	else:
		_build_vehicle_pick()


func _build_draft() -> void:
	var r := sim.report
	var hdr := UIKit.hbox(8)
	hdr.add_child(UIKit.head("Pick an upgrade", 22, Palette.TEXT))
	var why := ""
	if r.get("min_rarity", 0) >= 2:
		why = "Heroic contract: Rare or better guaranteed"
	elif r.get("boost", 0) > 0:
		why = "Ambitious contract: better odds"
	elif r.get("draft_count", 3) > 3:
		why = "Extra card for a good day"
	if why != "":
		var w := UIKit.label("· " + why, 13, Palette.TEXT_SOFT, "head_semi")
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hdr.add_child(w)
	body.add_child(hdr)
	var row := UIKit.hbox(14)
	for id in sim.draft:
		var cv := CardView.new()
		cv.setup(id)
		cv.picked.connect(_on_card)
		row.add_child(cv)
	body.add_child(row)
	var actions := UIKit.hbox(8)
	var cost := sim.reroll_cost()
	var reroll := UIKit.button("Reroll  %s" % (UIKit.money(cost) if cost > 0.0 else "free"), "paper", 15)
	reroll.disabled = sim.player().money < cost
	reroll.pressed.connect(func(): main.submit_player({"type": "reroll_draft"}))
	actions.add_child(reroll)
	actions.add_child(UIKit.spacer())
	var skip := UIKit.button("Skip, take $40", "ink", 15)
	skip.pressed.connect(func(): main.submit_player({"type": "skip_card"}))
	actions.add_child(skip)
	body.add_child(actions)


## Interest, streak and (on due evenings) the lease bill.
func _season_row(r: Dictionary) -> Control:
	var lease: Dictionary = r.get("lease", {})
	var p := PanelContainer.new()
	var col := Palette.PAPER_2
	if lease.get("strike", false):
		col = Color(Palette.RED, 0.18)
	elif lease.get("paid", false):
		col = Color(Palette.GREEN, 0.15)
	p.add_theme_stylebox_override("panel", UIKit.flat(col, 2, 12, 8))
	var h := UIKit.hbox(12)
	p.add_child(h)
	if lease.get("paid", false):
		h.add_child(UIKit.head("Lease paid", 15, Palette.GREEN))
		h.add_child(UIKit.mono("-" + UIKit.money(lease["amount"]), 15, Palette.TEXT, true))
		h.add_child(UIKit.stamp("Week %d done" % sim.run_stats["leases_paid"], Palette.GREEN, 13))
	elif lease.get("strike", false):
		h.add_child(UIKit.head("Final notice!", 15, Palette.RED))
		h.add_child(UIKit.label("Short on the lease. %s rolls into next week with a late fee." % UIKit.money(lease.get("debt", 0.0)), 13, Palette.TEXT, "bold"))
	else:
		var left := Season.due_day(sim.day()) - sim.day()
		h.add_child(UIKit.head("Next lease", 15, Palette.TEXT_SOFT))
		h.add_child(UIKit.mono("%s in %d day%s" % [UIKit.money(sim.lease_amount()), left, "" if left == 1 else "s"], 15, Palette.TEXT, true))
	h.add_child(UIKit.spacer())
	if r.get("interest", 0.0) > 0.0:
		h.add_child(UIKit.mono("interest +%s" % UIKit.money(r["interest"]), 13, Palette.GREEN, true))
	if r.get("streak", 0) > 0:
		h.add_child(UIKit.stamp("streak %d" % r["streak"], Palette.ORANGE, 13))
	return p


func _on_card(id: StringName) -> void:
	if Cards.is_vehicle(id):
		_picking = id
		_build()
	else:
		main.submit_player({"type": "pick_card", "index": sim.draft.find(id)})


func _build_vehicle_pick() -> void:
	var c := Cards.get_card(_picking)
	var hdr := UIKit.hbox(8)
	hdr.add_child(UIKit.head("Install %s on…" % c["name"], 22, Palette.TEXT))
	var d := UIKit.label("· " + c["desc"], 13, Palette.TEXT_SOFT, "head_semi")
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(d)
	body.add_child(hdr)
	var list := UIKit.vbox(6)
	for v in sim.player().vans:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 12, 6))
		var h := UIKit.hbox(10)
		row.add_child(h)
		var who := UIKit.vbox(-3)
		who.custom_minimum_size.x = 150
		who.add_child(UIKit.head(v.code, 18, Palette.TEXT))
		who.add_child(UIKit.label("%s · %s" % [v.spec()["name"], v.driver.name], 11, Palette.TEXT_SOFT))
		h.add_child(who)
		var mods := UIKit.hbox(4)
		mods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for m in v.mods:
			mods.add_child(UIKit.stamp(Cards.get_card(m)["name"], Cards.RARITY_COLORS[Cards.get_card(m)["rarity"]], 11))
		for k in v.mod_slots() - v.mods.size():
			mods.add_child(UIKit.stamp("empty slot", Palette.RULE, 11))
		h.add_child(mods)
		var full := v.mods.size() >= v.mod_slots()
		var b := UIKit.button("Replace %s" % Cards.get_card(v.mods[0])["name"] if full else "Install", "paper" if full else "go", 14)
		var vid := v.id
		b.pressed.connect(func(): main.submit_player({"type": "pick_card", "index": sim.draft.find(_picking), "van": vid}))
		h.add_child(b)
		list.add_child(row)
	body.add_child(list)
	var back := UIKit.button("Back to cards", "paper", 15)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func():
		_picking = &""
		_build())
	body.add_child(back)


class StarRow:
	extends Control
	var stars := 0

	func _draw() -> void:
		for i in 3:
			var c := Vector2(24 + i * 50, size.y * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var rad := 20.0 if k % 2 == 0 else 8.5
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			var on := i < stars
			draw_colored_polygon(pts, Palette.AMBER if on else Palette.PAPER_2)
			pts.append(pts[0])
			draw_polyline(pts, Palette.INK, 2.0, true)
