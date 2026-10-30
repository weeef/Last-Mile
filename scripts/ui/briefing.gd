class_name Briefing
extends ModalSheet
## Morning: weather, road works, rush hours, and pick one of three contracts.

const AVENUES := ["1st Ave", "2nd Ave", "3rd Ave", "4th Ave", "5th Ave", "6th Ave", "7th Ave"]

var sim: Sim
var main: Node


func setup(p_sim: Sim, p_main: Node) -> void:
	sim = p_sim
	main = p_main
	sim.event.connect(func(n: String, _d: Dictionary):
		if n == "event_resolved" and is_inside_tree():
			_build())
	_build()


func _build() -> void:
	ModalSheet.clear(body)
	var top := UIKit.hbox(12)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("07:00 · MAPLE ST. DEPOT", 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("Morning briefing · day %d%s" % [sim.day(), " of %d" % Season.DAYS if sim.season_on() else ""], 34, Palette.TEXT))
	top.add_child(tv)
	if sim.streak > 0:
		top.add_child(UIKit.spacer())
		var sk := UIKit.stamp("Streak %d · x%.2f pay" % [sim.streak, sim.streak_mult()], Palette.ORANGE, 15)
		sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(sk)
	body.add_child(top)
	if sim.season_on():
		body.add_child(_season_strip())
	var pending := not sim.morning_event.is_empty() and not sim.morning_event.get("done", false)
	if not sim.morning_event.is_empty():
		body.add_child(_event_box())

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
	var sub := UIKit.label("Finish it by 21:00 for cash and a better pick of upgrade cards tonight." if not pending else "Deal with this morning's situation first.", 13, Palette.TEXT_SOFT if not pending else Palette.RED)
	body.add_child(sub)
	var row := UIKit.hbox(12)
	for i in sim.contract_offers.size():
		row.add_child(_contract_ticket(i, sim.contract_offers[i], pending))
	body.add_child(row)
	var skip := UIKit.button("No contract today", "paper", 14)
	skip.disabled = pending
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(func(): main.submit_player({"type": "pick_contract", "index": -1}))
	body.add_child(skip)


## Lease countdown, this week's twist and the peak warning.
func _season_strip() -> Control:
	var d := sim.day()
	var due := Season.due_day(d)
	var left := due - d
	var p := PanelContainer.new()
	var st := UIKit.paper_style(Palette.PAPER_2, 12, 4)
	st.border_width_left = 8
	st.border_color = Palette.RED if left == 0 else Palette.INK
	p.add_theme_stylebox_override("panel", st)
	var h := UIKit.hbox(18)
	p.add_child(h)
	var lv := UIKit.vbox(-2)
	lv.add_child(UIKit.head("Week %d of %d · lease" % [Season.week_of(d) + 1, Season.LEASES.size()], 12, Palette.TEXT_SOFT))
	var when := "DUE TONIGHT" if left == 0 else ("due tomorrow" if left == 1 else "due day %d" % due)
	lv.add_child(UIKit.head("%s %s" % [UIKit.money(sim.lease_amount()), when], 22, Palette.RED if left == 0 else Palette.TEXT))
	var have := sim.player().money
	var short := sim.lease_amount() - have
	var note := "You have it covered (%s in the till)." % UIKit.money(have) if short <= 0.0 else "%s short. Make it before 21:00 on day %d." % [UIKit.money(short), due]
	if sim.lease_debt > 0.0:
		note += " Includes %s carried debt." % UIKit.money(sim.lease_debt)
	lv.add_child(UIKit.label(note, 12, Palette.GREEN if short <= 0.0 else Palette.TEXT_SOFT))
	h.add_child(lv)
	var sep := ColorRect.new()
	sep.color = Palette.RULE
	sep.custom_minimum_size = Vector2(2, 0)
	h.add_child(sep)
	var tw := UIKit.vbox(-2)
	tw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tid := sim.twist if sim.twist != "" else sim.week_twist
	var today := sim.twist != ""
	var title := "Twist today" if today else "Twist on day %d" % due
	if sim.is_peak_day():
		title = "HOLIDAY PEAK · demand x%.0f" % Season.PEAK_DEMAND
	tw.add_child(UIKit.head(title, 12, Palette.RED if today or sim.is_peak_day() else Palette.TEXT_SOFT))
	if tid != "":
		tw.add_child(UIKit.head(Season.twist_name(tid), 22, Palette.ORANGE if today else Palette.TEXT))
		var td := UIKit.label(Season.TWISTS[tid]["desc"], 12, Palette.TEXT_SOFT)
		td.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		td.custom_minimum_size.x = 340
		tw.add_child(td)
	h.add_child(tw)
	var sv := UIKit.vbox(-2)
	sv.add_child(UIKit.head("Final notices", 12, Palette.TEXT_SOFT))
	var left_strikes := sim.strikes_allowed() - sim.lease_strikes
	sv.add_child(UIKit.head("%d left" % left_strikes, 22, Palette.RED if left_strikes <= 0 else Palette.TEXT))
	sv.add_child(UIKit.label("heat %d" % sim.heat(), 12, Palette.TEXT_SOFT))
	h.add_child(sv)
	return p


## Today's dilemma (Events): a story and two or three choices.
func _event_box() -> Control:
	var ev: Dictionary = sim.morning_event
	var data := Events.get_event(ev["id"])
	var done: bool = ev.get("done", false)
	var p := PanelContainer.new()
	var st := UIKit.paper_style(Palette.PAPER, 12, 5)
	st.border_color = Palette.PURPLE
	st.border_width_left = 8
	p.add_theme_stylebox_override("panel", st)
	var v := UIKit.vbox(6)
	p.add_child(v)
	var h := UIKit.hbox(10)
	h.add_child(UIKit.stamp("This morning", Palette.PURPLE, 12))
	h.add_child(UIKit.head(data["title"], 20, Palette.TEXT))
	v.add_child(h)
	var t := UIKit.label(data["text"], 14, Palette.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 640
	v.add_child(t)
	if done:
		v.add_child(UIKit.label(ev.get("result", ""), 14, Palette.GREEN, "bold"))
		return p
	var row := UIKit.hbox(10)
	var opts: Array = data["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var cost := Events.cost(ev["id"], i, sim.player().vans.size())
		var ov := UIKit.vbox(2)
		ov.custom_minimum_size.x = 210
		var b := UIKit.button(o["label"] + ("  %s" % UIKit.money(cost) if cost > 0.0 else ""), "go" if i == 0 else "paper", 15)
		b.disabled = sim.player().money < cost
		var idx := i
		b.pressed.connect(func(): main.submit_player({"type": "pick_event", "index": idx}))
		ov.add_child(b)
		var d := UIKit.label(o["desc"], 12, Palette.TEXT_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 210
		ov.add_child(d)
		row.add_child(ov)
	v.add_child(row)
	return p


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


func _contract_ticket(i: int, c: Dictionary, locked := false) -> Control:
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
	take.disabled = locked
	take.pressed.connect(func(): main.submit_player({"type": "pick_contract", "index": i}))
	v.add_child(take)
	return p
