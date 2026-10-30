class_name Briefing
extends ModalSheet
## Morning: weather, road works, rush hours, and pick one of three contracts.

const AVENUES := ["1st Ave", "2nd Ave", "3rd Ave", "4th Ave", "5th Ave", "6th Ave", "7th Ave"]

var sim: Sim
var main: Node


func setup(p_sim: Sim, p_main: Node) -> void:
	sim = p_sim
	main = p_main
	var top := UIKit.hbox(12)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("07:00 · MAPLE ST. DEPOT", 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("Morning briefing · day %d" % sim.day(), 34, Palette.TEXT))
	top.add_child(tv)
	body.add_child(top)

	# Conditions
	var cond := UIKit.hbox(10)
	cond.add_child(_info_box("Weather", Sim.WEATHER[sim.weather], _weather_note()))
	var works := "None today"
	if not sim.city.closures.is_empty():
		var lines: Array = []
		for c in sim.city.closures:
			lines.append(_closure_name(c))
		works = "\n".join(lines)
	cond.add_child(_info_box("Road works", "%d closed" % sim.city.closures.size() if not sim.city.closures.is_empty() else "Clear", works))
	cond.add_child(_info_box("Rush hour", "7:30-9:00", "and 16:30-18:00. Traffic crawls."))
	body.add_child(cond)
	body.add_child(UIKit.rule())
	body.add_child(UIKit.head("Pick today's contract", 22, Palette.TEXT))
	var sub := UIKit.label("Finish it by 21:00 for cash and a better pick of upgrade cards tonight.", 13, Palette.TEXT_SOFT)
	body.add_child(sub)
	var row := UIKit.hbox(12)
	for i in sim.contract_offers.size():
		row.add_child(_contract_ticket(i, sim.contract_offers[i]))
	body.add_child(row)
	var skip := UIKit.button("No contract today", "paper", 14)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(func(): main.submit_player({"type": "pick_contract", "index": -1}))
	body.add_child(skip)


func _weather_note() -> String:
	match sim.weather:
		1:
			return "Roads 12% slower, breakdowns more likely, more walk-in orders."
		2:
			return "Visibility is poor. Roads 8% slower."
	return "Good driving day."


func _closure_name(pair: Array) -> String:
	for k in sim.city.intersections.keys():
		if sim.city.intersections[k] == pair[0]:
			var ij: Vector2i = k
			return "%s, %s to %s" % [AVENUES[ij.x], City.STREET_NAMES[ij.y], City.STREET_NAMES[ij.y + 1]]
	return "a side street"


func _info_box(title: String, value: String, note: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 12, 8))
	p.custom_minimum_size = Vector2(210, 0)
	var v := UIKit.vbox(-2)
	p.add_child(v)
	v.add_child(UIKit.head(title, 12, Palette.TEXT_SOFT))
	v.add_child(UIKit.head(value, 20, Palette.TEXT))
	var n := UIKit.label(note, 12, Palette.TEXT_SOFT)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 186
	v.add_child(n)
	return p


func _contract_ticket(i: int, c: Dictionary) -> Control:
	var tier: Dictionary = Contracts.TIERS[c["tier"]]
	var col: Color = [Palette.GREEN, Palette.BLUE, Palette.ORANGE][c["tier"]]
	var p := PanelContainer.new()
	var st := UIKit.paper_style(Palette.PAPER, 14, 5)
	st.border_color = Palette.INK
	st.border_width_top = 8
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(212, 0)
	var v := UIKit.vbox(4)
	p.add_child(v)
	v.add_child(UIKit.stamp(tier["name"], col, 13))
	var d := UIKit.head(Contracts.describe(c), 19, Palette.TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(184, 70)
	v.add_child(d)
	v.add_child(UIKit.mono("+" + UIKit.money(c["reward"]), 18, Palette.GREEN, true))
	var b := UIKit.label("plus " + tier["bonus"], 12, Palette.TEXT_SOFT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 184
	v.add_child(b)
	var take := UIKit.button("Take it", "go", 16)
	take.pressed.connect(func(): main.submit_player({"type": "pick_contract", "index": i}))
	v.add_child(take)
	return p
