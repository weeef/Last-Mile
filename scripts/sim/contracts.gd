class_name Contracts
extends RefCounted
## Daily contracts offered at the morning briefing. Pick one; finish it by
## 21:00 for cash and a better card draft that evening.

const TIERS := [
	{"name": "Steady", "reward": 90.0, "bonus": "4 cards to pick from", "draft_count": 4, "boost": 0, "min_rarity": 0},
	{"name": "Ambitious", "reward": 170.0, "bonus": "better card odds", "draft_count": 3, "boost": 2, "min_rarity": 0},
	{"name": "Heroic", "reward": 280.0, "bonus": "a guaranteed Rare or better", "draft_count": 3, "boost": 1, "min_rarity": 2},
]


## Builds three offers (one per tier) scaled to the day and the fleet.
static func roll(rng: RandomNumberGenerator, day: int, fleet: int, has_heavy: bool) -> Array:
	var kinds := ["ontime", "express", "vendor", "revenue", "district", "clean", "streak"]
	if has_heavy:
		kinds.append("heavy")
	var out: Array = []
	var used := {}
	for tier in 3:
		var k: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var guard := 0
		while used.has(k) and guard < 20:
			k = kinds[rng.randi_range(0, kinds.size() - 1)]
			guard += 1
		used[k] = true
		var scale := (1.0 + 0.35 * tier) * (0.8 + 0.2 * fleet) * (1.0 + 0.12 * (day - 1))
		var c := {"kind": k, "tier": tier, "target": 0, "district": -1}
		match k:
			"ontime":
				c["target"] = int(round(10.0 * scale))
			"express":
				c["target"] = int(round(3.0 * scale))
			"vendor":
				c["target"] = int(round(8.0 * scale))
			"revenue":
				c["target"] = int(round(220.0 * scale / 10.0)) * 10
			"district":
				c["target"] = int(round(5.0 * scale))
				c["district"] = rng.randi_range(0, 3)
			"clean":
				c["target"] = int(round(6.0 * scale))
			"streak":
				c["target"] = int(round(6.0 * scale))
			"heavy":
				c["target"] = maxi(1, int(round(2.0 * scale)))
		c["reward"] = roundf(TIERS[tier]["reward"] * (1.0 + 0.1 * (day - 1)))
		out.append(c)
	return out


static func describe(c: Dictionary) -> String:
	var t: int = c["target"]
	match c["kind"]:
		"ontime":
			return "Deliver %d parcels on time" % t
		"express":
			return "Deliver %d express parcels on time" % t
		"vendor":
			return "Deliver %d vendor parcels" % t
		"revenue":
			return "Earn $%d from deliveries" % t
		"district":
			return "Deliver %d parcels in %s" % [t, City.DISTRICT_NAMES[c["district"]]]
		"clean":
			return "Deliver %d parcels with zero late ones" % t
		"streak":
			return "Hit a streak of %d on-time drops" % t
		"heavy":
			return "Deliver %d heavy items" % t
	return "?"


## Current progress value for the contract given today's counters.
static func progress(c: Dictionary, counters: Dictionary) -> float:
	match c["kind"]:
		"ontime":
			return counters.get("ontime", 0)
		"express":
			return counters.get("express", 0)
		"vendor":
			return counters.get("vendor", 0)
		"revenue":
			return counters.get("revenue", 0.0)
		"district":
			return counters.get("district_%d" % c["district"], 0)
		"clean":
			return counters.get("ontime", 0) if counters.get("late", 0) == 0 else 0
		"heavy":
			return counters.get("heavy", 0)
		"streak":
			return counters.get("streak_peak", 0)
	return 0


static func is_done(c: Dictionary, counters: Dictionary) -> bool:
	if c.is_empty():
		return false
	return progress(c, counters) >= c["target"]
