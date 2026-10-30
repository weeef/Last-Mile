class_name AutoPlayer
extends RefCounted
## A simple scripted player used by the headless tests.

static func act(sim: Sim, i: int) -> void:
	var p := sim.player()
	if sim.phase == Sim.Phase.MORNING:
		if not sim.morning_event.is_empty() and not sim.morning_event.get("done", false):
			var id: String = sim.morning_event["id"]
			var pick: int = 0 if p.money >= Events.cost(id, 0, p.vans.size()) + 400.0 else Events.get_event(id)["options"].size() - 1
			sim.submit({"type": "pick_event", "company": 0, "index": pick})
		sim.submit({"type": "pick_contract", "company": 0, "index": 1})
		sim.apply_commands_now()
		return
	if sim.phase == Sim.Phase.EVENING and sim.evening_stage == "plan":
		sim.submit({"type": "pick_day", "company": 0, "index": i % sim.day_options.size()})
		sim.apply_commands_now()
		return
	if sim.phase == Sim.Phase.EVENING and sim.evening_stage == "shop":
		# buy the first company perk we can afford while keeping rent money, then leave
		for k in sim.shop.size():
			var item: Dictionary = sim.shop[k]
			if not item["sold"] and not Cards.is_vehicle(item["id"]) and p.money - item["price"] > sim.lease_amount():
				sim.submit({"type": "shop_buy", "company": 0, "index": k})
				break
		sim.submit({"type": "shop_leave", "company": 0})
		sim.apply_commands_now()
		return
	if sim.phase == Sim.Phase.EVENING:
		var vid: int = p.vans[0].id if not p.vans.is_empty() else -1
		# install vehicle cards on the van with the fewest mods
		for v in p.vans:
			if v.mods.size() < p.vans[0].mods.size():
				vid = v.id
		sim.submit({"type": "pick_card", "company": 0, "index": 0, "van": vid})
		sim.apply_commands_now()
		return
	if i % 40 != 0:
		return
	if p.active_jobs().size() < 1 and p.backlog() < 10:
		for j in p.offers():
			if j.needs_liftgate():
				var ok := false
				for v in p.vans:
					if v.carries_heavy(): ok = true
				if not ok: continue
			sim.submit({"type": "accept_job", "company": 0, "job": j.id})
			break
	for v in p.vans:
		if v.state == Van.State.BROKEN and not v.cargo.is_empty():
			var r := sim.best_rescuer(p)
			if r: sim.submit({"type": "rescue", "company": 0, "van": r.id, "target": v.id})
		if v.ready:
			sim.submit({"type": "start_route", "company": 0, "van": v.id})
		if v.state == Van.State.IDLE and v.condition < 0.45:
			sim.submit({"type": "service_van", "company": 0, "van": v.id})
	# Spend hustle: keep promises alive, then call ahead, then speed up a van.
	if sim.hustle >= 5 and p.waiting.size() > 6:
		sim.submit({"type": "ability", "company": 0, "ability": "sweet_talk"})
	elif sim.hustle >= 3 and sim.call_ahead_left == 0:
		sim.submit({"type": "ability", "company": 0, "ability": "call_ahead"})
	elif sim.hustle >= sim.hustle_cap() - 1:
		for v in p.vans:
			if v.state == Van.State.EN_ROUTE:
				sim.submit({"type": "ability", "company": 0, "ability": "floor_it", "van": v.id})
				break
	if p.money > 1300 and not p.vendors_unlocked.has(1):
		sim.submit({"type": "unlock_vendor", "company": 0, "vendor": 1})
	elif p.money > 1100.0 + sim.lease_amount() + 200.0 and p.vans.size() < p.fleet_cap():
		sim.submit({"type": "buy_van", "company": 0, "vehicle": &"van"})


## Runs n clock ticks (phases that stop the clock are resolved by act()).
static func run(sim: Sim, n: int, on_tick := Callable()) -> void:
	var done := 0
	var guard := 0
	while done < n and guard < n * 3 and sim.phase != Sim.Phase.OVER:
		guard += 1
		act(sim, done)
		if sim.clock_running():
			sim.step()
			done += 1
			if on_tick.is_valid():
				on_tick.call(done)
