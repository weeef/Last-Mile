class_name RivalAI
extends RefCounted
## A simple rival brain. It plays by the same rules as the player:
## it can only act by submitting commands to the simulation.

var sim: Sim
var company_id := 1
var max_vans := 6


func _init(s: Sim, cid: int) -> void:
	sim = s
	company_id = cid


func think() -> void:
	var c: Company = sim.companies[company_id]
	var capacity := c.vans.size() * 8
	# Zoomer Express expands aggressively when its backlog grows.
	# ...and sells idle vans when money runs dry.
	if c.money < 0.0 and c.vans.size() > 2:
		for v in c.vans:
			if v.state == Van.State.IDLE and v.cargo.is_empty():
				sim.submit({"type": "sell_van", "company": company_id, "van": v.id})
				return
	if c.backlog() > capacity * 0.6 and c.money >= VehicleTypes.DATA[&"van"]["cost"] + 150.0 and c.vans.size() < max_vans:
		sim.submit({"type": "buy_van", "company": company_id, "vehicle": &"van"})
