extends SceneTree
## Saves mid-game, loads into a fresh sim, runs both forward and checks they match.
func fingerprint(s: Sim) -> String:
	var p := s.player()
	var parts := [s.tick, s.streak, s.lease_strikes, s.twist, s.week_twist, s.next_parcel_id, s.next_job_id, snappedf(p.money, 0.001), snappedf(s.rival().money, 0.001), p.delivered_total, s.active.size(), s.garage_queue.size(), s.garage_working.size()]
	for v in p.vans:
		parts.append("%s:%d:%.4f:%.3f" % [v.code, v.state, v.condition, v.pos.x])
	return str(parts)

func drive(sim: Sim, n: int) -> void:
	AutoPlayer.run(sim, n)

func _init() -> void:
	var a := Sim.new()
	a.setup(20261029, [&"van", &"box"], {"id": 1, "charter": "green", "heat": 5, "daily": false, "hq": {"scout": 1, "dice": 1}})
	a.phase = Sim.Phase.DAY
	drive(a, 12000)
	var ok := SaveGame.save(a, 3)
	print("saved: ", ok, " meta: ", SaveGame.meta(3))
	var b := SaveGame.load_slot(3)
	print("loaded fingerprint matches: ", fingerprint(a) == fingerprint(b))
	drive(a, 9000)
	drive(b, 9000)
	print("after 9000 more ticks: ", fingerprint(a) == fingerprint(b))
	if fingerprint(a) != fingerprint(b):
		print(fingerprint(a)); print(fingerprint(b))
	SaveGame.delete(3)
	print("deleted: ", not SaveGame.exists(3))
	quit()
