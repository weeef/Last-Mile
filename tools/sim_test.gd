extends SceneTree
## Headless smoke test: plays 3 game days with a simple scripted player
## (takes the best job, starts ready vans, services worn ones) and checks determinism.

func play(sim: Sim, ticks: int, log_every: int) -> void:
	var p := sim.player()
	for i in ticks:
		if i % 40 == 0:
			# take one affordable job if few in flight
			if p.active_jobs().size() < 1 and p.backlog() < 12:
				var best: Job = null
				for j in p.offers():
					var heavy_ok := false
					for v in p.vans:
						if v.spec()["heavy"]: heavy_ok = true
					if j.needs_liftgate() and not heavy_ok: continue
					if best == null or j.pay > best.pay: best = j
				if best: sim.submit({"type": "accept_job", "company": 0, "job": best.id})
			for v in p.vans:
				if v.ready: sim.submit({"type": "start_route", "company": 0, "van": v.id})
			for v in p.vans:
				if v.state == Van.State.IDLE and v.condition < 0.45:
					sim.submit({"type": "service_van", "company": 0, "van": v.id})
			if p.money > 1300 and not p.vendors_unlocked.has(1):
				sim.submit({"type": "unlock_vendor", "company": 0, "vendor": 1})
			elif p.money > 800 and p.vans.size() < p.fleet_cap():
				sim.submit({"type": "buy_van", "company": 0, "vehicle": &"van"})
		if log_every > 0 and i % log_every == 0:
			print("Day %d %s  $%d  Lv%d rev %d  vans %d  backlog %d  ontime %.2f  share %.2f  jobs %d/%d  shop %d+%d | ZX $%d vans %d" % [sim.day(), sim.clock_now(), p.money, p.level, p.lifetime_revenue, p.vans.size(), p.backlog(), p.ontime_rate_total(), sim.total_share(), p.active_jobs().size(), p.offers().size(), sim.garage_working.size(), sim.garage_queue.size(), sim.rival().money, sim.rival().vans.size()])
		sim.step()

func _init() -> void:
	var sim := Sim.new()
	var breakdowns := [0]
	sim.notice.connect(func(t, k): if k == "bad" or t.begins_with("Level"): print("   >> ", t))
	sim.setup(12345, [&"van", &"box"])
	print("houses=", sim.city.houses.size(), " vendors=", sim.city.vendor_lots.size())
	play(sim, 3 * 1440 * 8, 2500)
	var a := Sim.new(); a.setup(7, [&"van", &"van"])
	var b := Sim.new(); b.setup(7, [&"van", &"van"])
	play(a, 6000, 0); play(b, 6000, 0)
	print("deterministic: ", a.player().money == b.player().money and a.next_parcel_id == b.next_parcel_id and a.next_job_id == b.next_job_id)
	quit()
