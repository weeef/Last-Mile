extends SceneTree
## Headless smoke test: plays 4 game days with a scripted player and checks determinism.
func _init() -> void:
	var sim := Sim.new()
	sim.notice.connect(func(t, k): if k in ["bad", "rush"] or t.begins_with("Level") or t.begins_with("Contract") or t.contains("installed") or t.begins_with("New perk"): print("   >> ", t))
	sim.event.connect(func(n, d): if n == "evening": print("   == evening day %d: %d delivered, %d late, stars %d, contract %s, draft %s" % [d["day"], d["delivered"], d["late"], d["stars"], d["contract_done"], sim.draft]))
	sim.event.connect(func(n, d): if n == "morning": print("   == morning: weather %s, closures %d, offers %s" % [Sim.WEATHER[sim.weather], sim.city.closures.size(), sim.contract_offers.map(func(c): return Contracts.describe(c))]))
	sim.setup(12345, [])
	sim.submit({"type": "starter_fleet", "company": 0, "vehicles": [&"van", &"box"]})
	sim.apply_commands_now()
	var p := sim.player()
	AutoPlayer.run(sim, 4 * 1440 * 8, func(i):
		if i % 4000 == 0:
			print("Day %d %s  $%d  Lv%d  vans %d  backlog %d  ontime %.2f  share %.2f  not-home %d | ZX $%d vans %d" % [sim.day(), sim.clock_now(), p.money, p.level, p.vans.size(), p.backlog(), p.ontime_rate_total(), sim.total_share(), p.counters.get("not_home", 0), sim.rival().money, sim.rival().vans.size()]))
	for v in p.vans:
		print("  %s mods=%s slots=%d kg=%d cond=%.2f" % [v.code, v.mods, v.slots, v.max_kg, v.condition])
	print("perks: ", p.perks)
	var a := Sim.new(); a.setup(7, [&"van", &"van"]); a.phase = Sim.Phase.DAY
	var b := Sim.new(); b.setup(7, [&"van", &"van"]); b.phase = Sim.Phase.DAY
	AutoPlayer.run(a, 9000); AutoPlayer.run(b, 9000)
	print("deterministic: ", a.player().money == b.player().money and a.next_parcel_id == b.next_parcel_id and a.next_job_id == b.next_job_id)
	quit()
