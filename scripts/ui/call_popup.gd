class_name CallPopup
extends ModalSheet
## An incoming phone call. The clock is stopped until you pick an answer;
## every answer says what it costs and what it does.

var sim: Sim
var main: Node


func setup(p_sim: Sim, p_main: Node) -> void:
	sim = p_sim
	main = p_main
	var call: Dictionary = sim.pending_call
	var data := Calls.get_call(call["id"])
	var ctx: Dictionary = call["ctx"]
	(card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Palette.ORANGE
	var top := UIKit.hbox(12)
	var icon := LMIcon.new()
	icon.icon = "bolt"
	icon.color = Palette.ORANGE
	icon.custom_minimum_size = Vector2(40, 40)
	top.add_child(icon)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("INCOMING CALL · %s · %s" % [sim.clock_now(), Calls.fill(data["caller"], ctx).to_upper()], 13, Palette.ORANGE, "head"))
	tv.add_child(UIKit.head(data["title"], 32, Palette.TEXT))
	top.add_child(tv)
	body.add_child(top)
	var t := UIKit.label(Calls.fill(data["text"], ctx), 16, Palette.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 620
	body.add_child(t)
	body.add_child(UIKit.label("The clock is stopped until you answer.", 12, Palette.TEXT_SOFT, "head_semi"))
	var row := UIKit.hbox(12)
	var opts: Array = data["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var cost := Calls.cost(call["id"], i)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.paper_style(Palette.PAPER_2, 12, 4))
		p.custom_minimum_size.x = 300 if opts.size() > 1 else 400
		var v := UIKit.vbox(6)
		p.add_child(v)
		var b := UIKit.button(o["label"] + ("  -%s" % UIKit.money(cost) if cost > 0.0 else ""), "go" if i == 0 else "paper", 17)
		b.custom_minimum_size.y = 40
		b.disabled = sim.player().money < cost
		var idx := i
		b.pressed.connect(func(): main.submit_player({"type": "answer_call", "index": idx}))
		v.add_child(b)
		var d := UIKit.label(Calls.fill(o["desc"], ctx) + ("\n(not enough cash)" if b.disabled else ""), 13, Palette.TEXT_SOFT)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = p.custom_minimum_size.x - 24
		v.add_child(d)
		row.add_child(p)
	body.add_child(row)
	card.rotation_degrees = 0.6
