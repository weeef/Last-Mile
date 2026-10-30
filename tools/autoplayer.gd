class_name AutoPlayer
extends RefCounted
## A simple scripted player used by the headless tests.

static func act(sim: Sim, i: int) -> void:
	var p := sim.player()
	if sim.phase == Sim.Phase.MORNING:
		sim.submit({"type": "pick_contract", "company": 0, "index": 1})
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
	if p.money > 1300 and not p.vendors_unlocked.has(1):
		sim.submit({"type": "unlock_vendor", "company": 0, "vendor": 1})
	elif p.money > 900 and p.vans.size() < p.fleet_cap():
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
