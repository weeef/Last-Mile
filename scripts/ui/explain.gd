class_name Explain
extends RefCounted
## Every player-facing explanation in one place: tooltips, card previews and
## the help page all read the real numbers from the sim, so they can't drift.


static func pct(x: float) -> String:
	return "%d%%" % int(round(x * 100.0))


static func mult(x: float) -> String:
	return "x%.2f" % x


static func per_hour(x: float) -> String:
	return "$%.1f/h" % x


# ------------------------------------------------------------- vehicles

static func condition(sim: Sim, v: Van) -> String:
	var rc := sim.running_costs(v)
	var c := sim.companies[v.company]
	return ("Condition %s: how worn this vehicle is.\n" % pct(v.condition)
		+ "Breakdown risk now: %.1f%% per hour of driving (at 50%%: %.1f%%, at 30%%: %.1f%%).\n" % [sim.breakdown_risk(v) * 100.0, sim.breakdown_risk(v, 0.5) * 100.0, sim.breakdown_risk(v, 0.3) * 100.0]
		+ "Worn vehicles are slower: speed %s right now.\n" % mult(0.85 + 0.15 * v.condition)
		+ "Wears about %.1f%% per hour of driving.\n" % (rc["wear"] * 100.0)
		+ "Service: $%d, %d min, back to 100%%.\n" % [int(Sim.SERVICE_COST * c.perk("shop_cost")), int(Sim.SERVICE_MIN * c.perk("shop_time"))]
		+ "Breakdown: tow $%d + repair $%d, about %d min off the road, and its parcels go back to the depot." % [int(Sim.TOW_COST * (0.0 if c.has_perk_fx("tow") else 1.0)), int(Sim.REPAIR_COST * c.perk("shop_cost")), int(Sim.TOW_WAIT + Sim.REPAIR_MIN * c.perk("shop_time"))])


static func mood(v: Van) -> String:
	var d := v.driver
	var s := ("Mood %d/100 (%s): driving speed %s.\n" % [int(d.mood), d.mood_word(), mult(0.85 + 0.3 * d.mood / 100.0)]
		+ "Mood 0 = x0.85, 50 = x1.00, 100 = x1.15.\n"
		+ "Goes up: parked (+6/h), in the shop (+3/h), on-time drop (+0.4).\n"
		+ "Goes down: driving (-2/h), late drop (-2), nobody home (-1), breakdown (-8), stranded (-10/h).")
	if d.has(&"sunny"):
		s += "\nSunny: never drops below 50."
	if v.fx_has("mood_lock"):
		s += "\nComfy Cab: never drops at all."
	return s


static func area(v: Van, district: int) -> String:
	var f: float = v.driver.familiarity[district]
	return ("Knows %s %s: drop-offs there are %s quicker (up to 35%% at 100%%).\n" % [City.DISTRICT_NAMES[district], pct(f), pct(0.35 * f)]
		+ "Every drop in a district teaches +%d%%%s." % [4 if v.driver.has(&"rookie") else 2, " (Rookie: twice as fast)" if v.driver.has(&"rookie") else ""])


static func trait_tip(d: Driver, t: StringName) -> String:
	var s := "%s: %s." % [Traits.trait_name(t), Traits.trait_desc(t)]
	if t == &"local":
		s += " Home district: %s." % City.DISTRICT_NAMES[d.home_district]
	return s


static func costs(sim: Sim, v: Van) -> String:
	var rc := sim.running_costs(v)
	var c := sim.companies[v.company]
	var s := ("Driving: %s wages + %s fuel = %s.\n" % [per_hour(rc["wage_drive"]), per_hour(rc["fuel"]), per_hour(rc["drive"])]
		+ "Parked (or in the shop): %s wages. Drivers are paid all night too.\n" % per_hour(rc["wage_parked"])
		+ "Since the last report: earned %s, cost %s." % [UIKit.money(v.earned_today), UIKit.money(v.cost_today)])
	var fuel_bits: Array = []
	if v.spec()["fuel"] != 1.0:
		fuel_bits.append("%s burns %s fuel" % [v.spec()["name"], mult(v.spec()["fuel"])])
	for m in v.mods:
		if Cards.DATA[m]["fx"].has("fuel"):
			fuel_bits.append("%s %s" % [Cards.DATA[m]["name"], mult(Cards.DATA[m]["fx"]["fuel"])])
	for k in c.perks:
		if Cards.DATA[k]["fx"].has("fuel"):
			fuel_bits.append("%s %s" % [Cards.DATA[k]["name"], mult(Cards.DATA[k]["fx"]["fuel"])])
	if not fuel_bits.is_empty():
		s += "\nFuel: " + ", ".join(fuel_bits) + "."
	return s


static func vehicle_type(t: StringName) -> String:
	var d: Dictionary = VehicleTypes.DATA[t]
	return ("%s: %d parcels, %dkg max load%s.\n" % [d["name"], d["slots"], int(d["kg"]), ", liftgate for heavy freight" if d["heavy"] else ""]
		+ "Speed %s, drop-off time %s, wear %s, fuel %s.\n" % [mult(d["speed"]), mult(d["stop"]), mult(d["wear"]), mult(d["fuel"])]
		+ "Driving costs about %s wages + %s fuel. Upgrade slots: %d." % [per_hour(Van.WAGE_PER_MIN * 60.0), per_hour(Van.BASE_SPEED * d["speed"] * Sim.TICKS_PER_HOUR * Van.FUEL_PER_UNIT * d["fuel"]), d["mod_slots"]])


static func status(v: Van) -> String:
	match v.state:
		Van.State.IDLE:
			return "Parked at the depot. Costs parked wages until it has something to carry."
		Van.State.LOADING:
			return "Loaded: waiting for you to press SEND (or for auto-send)." if v.ready else "Loading parcels at the depot (%d sec of game time each)." % int(Van.LOAD_MINUTES * 60 * v.driver.load_mult())
		Van.State.EN_ROUTE:
			return "Driving to the next stop."
		Van.State.DELIVERING:
			return "Dropping off a parcel."
		Van.State.RETURNING:
			return "Driving back to the depot."
		Van.State.BROKEN:
			return "Broken down. Send a rescue for its parcels before the tow truck arrives (%d min)." % ceili(v.timer)
		Van.State.TOWING:
			return "Being towed to Gearbox Garage."
		Van.State.TO_SHOP:
			return "Driving to Gearbox Garage for a service."
		Van.State.AT_SHOP:
			return "At Gearbox Garage. The garage has 2 bays shared with Zoomer Express."
		Van.State.RESCUE:
			return "Rescue run: collecting a broken-down vehicle's parcels."
	return ""


# ------------------------------------------------------------- company

static func cash(p: Company) -> String:
	if p.ledger.is_empty():
		return "Cash on hand. Nothing earned or spent since the last report yet."
	var lines: Array = ["Since the last evening report:"]
	for k in Company.LEDGER_ORDER:
		if p.ledger.has(k) and absf(p.ledger[k]) >= 0.5:
			lines.append("  %s  %s%s" % [Company.LEDGER_LABELS[k], "+" if p.ledger[k] > 0 else "", UIKit.money(p.ledger[k])])
	lines.append("Net: %s%s" % ["+" if p.ledger_total() >= 0 else "", UIKit.money(p.ledger_total())])
	return "\n".join(lines)


static func levels(p: Company) -> String:
	var lines: Array = ["Business level rises with lifetime earnings:"]
	for i in Vendors.LEVELS.size():
		var l: Dictionary = Vendors.LEVELS[i]
		var mark := ">" if i + 1 == p.level else " "
		lines.append("%s Lv %d %s (%s): %s" % [mark, i + 1, l["name"], UIKit.money(l["revenue"]), ", ".join(Vendors.level_unlocks(i + 1))])
	return "\n".join(lines)


static func stars() -> String:
	return "Stars each evening: 1 for 70%+ on time, 1 for 90%+ on time, 1 for finishing today's contract. 3 stars = an extra card to pick from."


static func share(sim: Sim, d: int) -> String:
	var bonus := sim.player().perk_add("share_bonus")
	return ("Walk-in share in %s: %s of customers there pick you%s.\n" % [City.DISTRICT_NAMES[d], pct(sim.share[d]), " (+%s Loyalty Cards)" % pct(bonus) if bonus > 0 else ""]
		+ "Reputation: you %d vs Zoomer %d. Every 10 minutes your share moves toward whoever is more reliable there (range 10%%-75%%).\n" % [int(sim.score[d][0] * 100), int(sim.score[d][1] * 100)]
		+ "On-time drops raise reputation (early ones most); late drops and overdue parcels lower it.")


static func walkins(sim: Sim) -> String:
	return ("Walk-ins are customers who order without a vendor: $11 standard (%d min promise), $18 express (%d min).\n" % [150, 60]
		+ "About %d orders an hour across town right now; your share decides how many are yours.\n" % int(sim.demand_per_hour())
		+ "Win share with fast, reliable drops. See the DISTRICTS tab.")


static func zoomer(sim: Sim) -> String:
	var r := sim.rival()
	return ("Zoomer Express, your rival. They have %d vans and send them when half full.\n" % r.vans.size()
		+ "What they do to you: they compete for walk-in customers (district reputation decides who gets them), and they share Gearbox Garage's 2 bays, so their vans can be ahead of yours in the queue.\n"
		+ "They never take your vendor jobs. They buy vans when busy and sell them when broke.")


static func lease(sim: Sim) -> String:
	var due := Season.due_day(sim.day())
	return ("Rent of %s is taken from your cash at 21:00 on day %d.\n" % [UIKit.money(sim.lease_amount()), due]
		+ "Short of it? You pay what you have, and the rest plus a 20%% late fee rolls into next week (final notices left: %d). With none left, you're evicted and the season ends." % (sim.strikes_allowed() - sim.lease_strikes))


static func streak(sim: Sim) -> String:
	return ("On-time drops in a row today: %d. Each one adds %d%% to the pay of every drop, up to %s at %d.\n" % [sim.streak, int(round((Season.STREAK_STEP + 0.01 * sim.hq("hype")) * 100)), mult(1.0 + (Season.STREAK_STEP + 0.01 * sim.hq("hype")) * sim.streak_cap()), sim.streak_cap()]
		+ "A late drop or nobody home breaks it. It starts again from 0 every morning.")


static func hustle(sim: Sim) -> String:
	return "Hustle: %d of %d. Every on-time drop earns 1 (+2 when your streak reaches a new tier). It's capped, so spend it on the powers below before it's wasted." % [sim.hustle, sim.hustle_cap()]


static func conditions(sim: Sim) -> String:
	var lines: Array = []
	if sim.is_rush_hour():
		lines.append("Rush hour (07:30-09:00, 16:30-18:00): roads 22% slower.")
	if sim.weather == 1:
		lines.append("Rain: roads 12% slower, breakdowns x1.5, 15% more walk-in orders.")
	elif sim.weather == 2:
		lines.append("Fog: roads 8% slower, drop-offs 15% slower (hard to find addresses).")
	if not sim.city.closures.is_empty():
		lines.append("Road works: %d street(s) closed today; routes go around them (drawn on the map)." % sim.city.closures.size())
	if sim.twist != "":
		lines.append("%s: %s" % [Season.twist_name(sim.twist), Season.TWISTS[sim.twist]["desc"]])
	if sim.boss_rule() != "":
		var b := Bosses.get_boss(sim.boss_rule())
		lines.append("Boss %s: %s" % [b["client"], b["rule"]])
	if sim.is_peak_day():
		lines.append("Holiday Peak: walk-in demand x%.0f." % Season.PEAK_DEMAND)
	if sim.green_wave_active():
		lines.append("Green Wave: your vehicles ignore traffic and drive 10% faster.")
	return "\n".join(lines) if not lines.is_empty() else "Normal traffic."


# ------------------------------------------------------------- jobs

static func job(sim: Sim, j: Job) -> String:
	var b := j.breakdown
	if b.is_empty():
		return "Pays %s, split evenly between its %d stops." % [UIKit.money(j.pay), j.stops()]
	var lines: Array = ["How %s is worked out:" % UIKit.money(j.pay),
		"  Base fee $10 + %d stops x $6 = %s" % [j.stops(), UIKit.money(b["base"] + b["stops"])],
		"  Weight %dkg x $0.32 = %s" % [int(j.total_kg), UIKit.money(b["weight"])],
		"  Distance from your depot = %s" % UIKit.money(b["distance"])]
	if b["liftgate"] > 0.0:
		lines.append("  Heavy freight = +$25 (needs a liftgate)")
	if b["express"] > 1.0:
		lines.append("  Express x1.3")
	if b["rush"] > 1.0:
		lines.append("  Rush order x1.8")
	lines.append("  %s rate x%.2f%s" % [Vendors.get_vendor(j.vendor)["name"], b["vendor"], " (Vendor Rep x%.2f)" % b["perk"] if b["perk"] != 1.0 else ""])
	lines.append("Each stop pays %s. A late stop pays 30%%." % UIKit.money(j.pay / j.stops()))
	lines.append("")
	lines.append(job_timing(sim, j))
	return "\n".join(lines)


static func job_timing(sim: Sim, j: Job) -> String:
	var prep: float = j.breakdown.get("prep", Vendors.get_vendor(j.vendor)["prep"])
	var drive := sim.city.road_dist(sim.city.vendor_lots[j.vendor]["curb"], sim.player().depot_node) / Sim.COURIER_SPEED * Sim.MIN_PER_TICK
	return ("Timeline: the vendor packs it (~%d min), their courier drives it to your depot (~%d min), then you have %s to deliver every stop. The clock starts when it reaches your depot." % [int(prep), int(drive), _dur(j.promise * sim.promise_mult())])


static func _dur(m: float) -> String:
	var h := int(m) / 60
	var mm := int(m) % 60
	return ("%dh%02d" % [h, mm]) if h > 0 else "%d min" % mm


# ------------------------------------------------------------- card previews

## Before -> after lines for installing card `id` (on vehicle `v` if it's a mod).
static func card_preview(sim: Sim, id: StringName, v: Van) -> Array:
	var card := Cards.get_card(id)
	if card["kind"] == "vehicle":
		if v == null:
			return []
		var before := _van_stats(sim, v)
		var saved: Array[StringName] = v.mods.duplicate()
		if v.mods.size() >= v.mod_slots():
			v.mods.pop_front()
		v.mods.append(id)
		v.refresh_stats()
		var after := _van_stats(sim, v)
		v.mods = saved
		v.refresh_stats()
		var out := _diff(before, after)
		if saved.size() >= v.mod_slots():
			out.append("Replaces %s" % Cards.get_card(saved[0])["name"])
		return out
	var p := sim.player()
	var before_c := _company_stats(sim)
	p.perks.append(id)
	var after_c := _company_stats(sim)
	p.perks.pop_back()
	var out_c := _diff(before_c, after_c)
	if card["fx"].has("mood_now"):
		out_c.append("Every driver's mood +%d now" % int(card["fx"]["mood_now"]))
	return out_c


static func _van_stats(sim: Sim, v: Van) -> Dictionary:
	var rc := sim.running_costs(v)
	return {
		"Speed": "x%.2f" % (v.spec()["speed"] * v.fx("speed")),
		"Parcels": str(v.slots),
		"Max load": "%dkg" % int(v.max_kg),
		"Drop-off time": "x%.2f" % (v.spec()["stop"] * v.fx("stop")),
		"Fuel": per_hour(rc["fuel"]),
		"Wear": "%.1f%%/h" % (rc["wear"] * 100.0),
		"Breakdown risk": "%.2f%%/h" % (sim.breakdown_risk(v) * 100.0),
		"Express pay": "x%.2f" % v.fx("express_pay"),
		"Heavy freight": "yes" if v.carries_heavy() else "no",
		"Mood": "never drops" if v.fx_has("mood_lock") else "normal",
		"5+ stop routes": "x%.2f speed" % v.fx("gps"),
	}


static func _company_stats(sim: Sim) -> Dictionary:
	var p := sim.player()
	var fuel := 0.0
	for v in p.vans:
		fuel += sim.running_costs(v)["fuel"]
	var s := {
		"Fleet fuel": per_hour(fuel),
		"Tow": "$%d, %d min wait" % [int(0.0 if p.has_perk_fx("tow") else Sim.TOW_COST), int(Sim.TOW_WAIT * (0.5 if p.has_perk_fx("tow") else 1.0))],
		"Sorting": "%.0f min" % (Parcel.SORT_MINUTES * p.perk("sort")),
		"Repair": "$%d, %d min" % [int(Sim.REPAIR_COST * p.perk("shop_cost")), int(Sim.REPAIR_MIN * p.perk("shop_time"))],
		"Service": "$%d, %d min" % [int(Sim.SERVICE_COST * p.perk("shop_cost")), int(Sim.SERVICE_MIN * p.perk("shop_time"))],
		"Garage queue": "front of the line" if p.has_perk_fx("front_of_line") else "first come first served",
		"New job pay": "x%.2f" % p.perk("job_pay"),
		"Promises": "+%d min" % int(p.perk("promise_add", 0.0)),
		"Walk-in chance bonus": "+%s" % pct(p.perk_add("share_bonus")),
		"Driver wages": per_hour(Van.WAGE_PER_MIN * 60.0 * p.perk("wage")),
		"Streak cap": "%d (x%.2f)" % [sim.streak_cap(), 1.0 + (Season.STREAK_STEP + 0.01 * sim.hq("hype")) * sim.streak_cap()],
		"Max hustle": str(sim.hustle_cap()),
		"Full Truck combo": "+%.2f" % (Combos.DATA["full"]["mult"] + p.perk_add("combo_full")),
		"Sweep combo": "+%.2f" % (Combos.DATA["sweep"]["mult"] + p.perk_add("combo_sweep")),
		"Neighbors combo": "+%.2f per stop" % (Combos.DATA["street"]["mult"] + p.perk_add("combo_street")),
		"Every route": "+%.2f" % p.perk_add("combo_all"),
		"Combos count": "x%.1f" % p.perk("combo_scale"),
		"Vehicle speed": "x%.2f" % p.perk("fleet_speed"),
	}
	if sim.season_on():
		s["Rent this week"] = UIKit.money(sim.lease_amount())
		s["Interest cap"] = "$%d" % int(25.0 + p.perk_add("interest_cap"))
	return s


static func _diff(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k in a.keys():
		if str(a[k]) != str(b[k]):
			out.append("%s: %s -> %s" % [k, a[k], b[k]])
	return out
