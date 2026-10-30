extends SceneTree
## Headless season run: plays a whole 12-day season with the scripted player at a
## few heat levels, prints every lease bill, streaks and the final result, and
## checks that a season replays identically from the same seed.
func play(seed_value: int, charter: String, heat: int, verbose: bool) -> Sim:
	var sim := Sim.new()
	var run := {"id": seed_value, "charter": charter, "heat": heat, "daily": false, "hq": {}}
	if verbose:
		sim.event.connect(func(n, d):
			if n == "evening":
				var l: Dictionary = d.get("lease", {})
				print("   day %2d: %3d drops, %2d late, stars %d, streak %2d, interest $%d, cash $%d%s" % [d["day"], d["delivered"], d["late"], d["stars"], d["streak"], int(d["interest"]), int(sim.player().money),
					("  LEASE $%d %s" % [int(l["amount"]), "paid" if l["paid"] else ("FINAL NOTICE" if l["strike"] else "EVICTED")]) if not l.is_empty() else ""])
			elif n == "morning" and sim.twist != "":
				print("   day %2d twist: %s" % [sim.day(), Season.twist_name(sim.twist)])
			elif n == "run_over":
				print("   RUN OVER: %s on day %d, score %d, rep %d, best streak %d, leases %d" % ["WON" if d["won"] else "evicted", d["day"], d["score"], d["rep"], d["best_streak"], d["leases_paid"]]))
	sim.setup(seed_value, [], run)
	var fleet: Array = Season.charter(charter).get("fleet", [&"van", &"box"])
	sim.submit({"type": "starter_fleet", "company": 0, "vehicles": fleet})
	sim.apply_commands_now()
	AutoPlayer.run(sim, 13 * 1440 * 8)
	return sim

func _init() -> void:
	for cfg in [["courier", 0], ["budget", 2], ["premium", 4], ["haulers", 8]]:
		print("== %s, heat %d" % cfg)
		var s := play(4242, cfg[0], cfg[1], true)
		print("   phase OVER: ", s.phase == Sim.Phase.OVER)
	var a := play(99, "green", 3, false)
	var b := play(99, "green", 3, false)
	print("season deterministic: ", a.run_result.get("score", -1) == b.run_result.get("score", -2) and a.tick == b.tick)
	quit()
