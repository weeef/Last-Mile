class_name Cards
extends RefCounted
## Upgrade cards drafted each evening. Vehicle mods go on one vehicle (limited
## slots, so you build specialists); company perks apply to the whole business.
##
## fx keys (multipliers unless noted):
##   speed, fuel, wear, break, stop, kg, slots (+add), slots_mult, express_pay,
##   heavy (flag), mood_lock (flag), gps (speed on 5+ stop routes)
##   company: fuel, tow (flag), sort, shop_cost, shop_time, job_pay, front_of_line (flag),
##   promise_add (+minutes), mood_now (+instant), share_now (+instant)
##   streaks + season: streak_guard (flag), second_wind (flag), streak_cap (+add), streak_floor (+add),
##   tip_jar (flag), lease (mult), interest_cap (+add)
##   route combos (see Combos): combo_full, combo_sweep, combo_street, combo_all (+add), combo_double (flag)
##   hustle: hustle_cap (+add), hustle_morning (+add), hustle_per_drop (+add)
##   relics (rarity RELIC, only from boss clients): mood_floor (+add), wage (mult), combo_scale (mult),
##   fleet_speed (mult), golden_ticket (flag), free_reroll (flag), first_stop_free (flag)

enum Rarity { COMMON, UNCOMMON, RARE, ULTRA, RELIC }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Ultra rare", "Relic"]
const RARITY_COLORS := [Color("8a8170"), Color("4f7a46"), Color("2f5f86"), Color("d17a22"), Color("8e3f9e")]
const SHOP_PRICES := [60.0, 110.0, 190.0, 320.0]
const RARITY_WEIGHTS := [60.0, 28.0, 10.0, 2.0]

const DATA := {
	# ---- vehicle mods
	&"eco_tune": {"name": "Eco Tune", "rarity": 0, "kind": "vehicle", "desc": "Fuel use −30%.", "fx": {"fuel": 0.7}},
	&"roof_rack": {"name": "Roof Rack", "rarity": 0, "kind": "vehicle", "desc": "+2 parcel slots.", "fx": {"slots": 2}},
	&"stiff_springs": {"name": "Heavy-Duty Springs", "rarity": 0, "kind": "vehicle", "desc": "Max load +30%.", "fx": {"kg": 1.3}},
	&"fresh_tires": {"name": "Fresh Tires", "rarity": 0, "kind": "vehicle", "desc": "Wears out 30% slower.", "fx": {"wear": 0.7}},
	&"quick_shelves": {"name": "Quick-Release Shelving", "rarity": 1, "kind": "vehicle", "desc": "Drop-offs 25% faster.", "fx": {"stop": 0.75}},
	&"reinforced": {"name": "Reinforced Drivetrain", "rarity": 1, "kind": "vehicle", "desc": "Breakdown chance −60%.", "fx": {"break": 0.4}},
	&"hybrid": {"name": "Hybrid Engine", "rarity": 1, "kind": "vehicle", "desc": "Fuel use −60%, speed −5%.", "fx": {"fuel": 0.4, "speed": 0.95}},
	&"route_gps": {"name": "Route GPS", "rarity": 1, "kind": "vehicle", "desc": "+12% speed on routes with 5+ stops.", "fx": {"gps": 1.12}},
	&"insulated": {"name": "Insulated Cargo", "rarity": 1, "kind": "vehicle", "desc": "Express parcels pay +30%.", "fx": {"express_pay": 1.3}},
	&"cargo_tetris": {"name": "Cargo Tetris", "rarity": 2, "kind": "vehicle", "desc": "+40% slots and max load.", "fx": {"slots_mult": 1.4, "kg": 1.4}},
	&"liftgate_kit": {"name": "Liftgate Kit", "rarity": 2, "kind": "vehicle", "desc": "Can haul heavy freight.", "fx": {"heavy": 1}},
	&"hypermiler": {"name": "Hypermiler", "rarity": 2, "kind": "vehicle", "desc": "No fuel cost and +5% speed.", "fx": {"fuel": 0.0, "speed": 1.05}},
	&"comfy_cab": {"name": "Comfy Cab", "rarity": 2, "kind": "vehicle", "desc": "Driver's mood never drops.", "fx": {"mood_lock": 1}},
	&"turbo": {"name": "Turbo", "rarity": 3, "kind": "vehicle", "desc": "+45% speed. Wears out 30% faster.", "fx": {"speed": 1.45, "wear": 1.3}},
	&"golden_wrench": {"name": "Golden Wrench", "rarity": 3, "kind": "vehicle", "desc": "Never breaks down.", "fx": {"break": 0.0}},
	# ---- company perks
	&"bulk_fuel": {"name": "Bulk Fuel Deal", "rarity": 0, "kind": "company", "desc": "All fuel −15%.", "fx": {"fuel": 0.85}},
	&"tow_club": {"name": "Tow Club", "rarity": 0, "kind": "company", "desc": "Tows are free and arrive twice as fast.", "fx": {"tow": 1}},
	&"pizza_friday": {"name": "Pizza Friday", "rarity": 0, "kind": "company", "desc": "Every driver +25 mood right now.", "fx": {"mood_now": 25.0}, "instant": true},
	&"night_crew": {"name": "Night Sort Crew", "rarity": 1, "kind": "company", "desc": "Sorting takes half as long.", "fx": {"sort": 0.5}},
	&"friendly_mech": {"name": "Friendly Mechanic", "rarity": 1, "kind": "company", "desc": "Repairs and services 40% cheaper and 30% quicker.", "fx": {"shop_cost": 0.6, "shop_time": 0.7}},
	&"loyalty": {"name": "Loyalty Cards", "rarity": 1, "kind": "company", "desc": "Walk-in share +6% in every district.", "fx": {"share_now": 0.06}, "instant": true},
	&"vendor_rep": {"name": "Vendor Rep", "rarity": 2, "kind": "company", "desc": "New jobs pay +15%.", "fx": {"job_pay": 1.15}},
	&"front_of_line": {"name": "Mechanic's Friend", "rarity": 2, "kind": "company", "desc": "Your vehicles skip to the front of the garage line.", "fx": {"front_of_line": 1}},
	&"express_lane": {"name": "Express Lane", "rarity": 3, "kind": "company", "desc": "Every delivery promise gets +30 min.", "fx": {"promise_add": 30.0}},
	# ---- streak and season perks
	&"tip_jar": {"name": "Tip Jar", "rarity": 0, "kind": "company", "desc": "On-time drops earn +$1 tip for every 5 in your streak.", "fx": {"tip_jar": 1}},
	&"piggy_bank": {"name": "Piggy Bank", "rarity": 0, "kind": "company", "desc": "Nightly savings interest can go $30 higher.", "fx": {"interest_cap": 30.0}, "season": true},
	&"doorbell_cam": {"name": "Doorbell Cam", "rarity": 1, "kind": "company", "desc": "\"Nobody home\" no longer breaks your streak.", "fx": {"streak_guard": 1}},
	&"second_wind": {"name": "Second Wind", "rarity": 1, "kind": "company", "desc": "A late parcel halves your streak instead of ending it.", "fx": {"second_wind": 1}},
	&"haggler": {"name": "Lease Haggler", "rarity": 1, "kind": "company", "desc": "Every lease payment is 15% cheaper.", "fx": {"lease": 0.85}, "season": true},
	&"hype_train": {"name": "Hype Train", "rarity": 2, "kind": "company", "desc": "Streak cap 25 to 40: up to x2.6 pay.", "fx": {"streak_cap": 15.0}},
	# ---- route combo "jokers" and hustle
	&"loading_boss": {"name": "Loading Bay Boss", "rarity": 0, "kind": "company", "desc": "Full Truck combos are worth +0.4 more.", "fx": {"combo_full": 0.4}},
	&"espresso": {"name": "Espresso Machine", "rarity": 0, "kind": "company", "desc": "+4 max hustle, and start every day with +3 hustle.", "fx": {"hustle_cap": 4.0, "hustle_morning": 3.0}},
	&"postcode_pride": {"name": "Postcode Pride", "rarity": 1, "kind": "company", "desc": "Sweep combos (one district) are worth +0.6 more.", "fx": {"combo_sweep": 0.6}},
	&"block_party": {"name": "Block Party", "rarity": 1, "kind": "company", "desc": "Neighbors combos are worth double.", "fx": {"combo_street": 0.1}},
	&"ace_courier": {"name": "Ace Courier", "rarity": 2, "kind": "company", "desc": "Every route gets +0.3 multiplier, even with no combo.", "fx": {"combo_all": 0.3}},
	&"double_down": {"name": "Double Down", "rarity": 3, "kind": "company", "desc": "Clean runs with 3+ combos pay their bonus twice.", "fx": {"combo_double": 1}},
	# ---- relics: boss rewards only, never in a normal draft
	&"landlords_cat": {"name": "The Landlord's Cat", "rarity": 4, "kind": "company", "desc": "Rent is 25% cheaper. He just likes you now.", "fx": {"lease": 0.75}, "season": true},
	&"union_contract": {"name": "Union Contract", "rarity": 4, "kind": "company", "desc": "Driver moods never drop below 60. Wages +40%.", "fx": {"mood_floor": 60.0, "wage": 1.4}},
	&"double_decker": {"name": "Double-Decker", "rarity": 4, "kind": "company", "desc": "Route combos count double. Your vehicles are 15% slower.", "fx": {"combo_scale": 2.0, "fleet_speed": 0.85}},
	&"golden_ticket": {"name": "Golden Ticket", "rarity": 4, "kind": "company", "desc": "Every 10th on-time drop pays +$40.", "fx": {"golden_ticket": 1}},
	&"hustle_engine": {"name": "Hustle Engine", "rarity": 4, "kind": "company", "desc": "+8 max hustle, and +1 extra hustle per on-time drop.", "fx": {"hustle_cap": 8.0, "hustle_per_drop": 1.0}},
	&"crystal_ball": {"name": "Crystal Ball", "rarity": 4, "kind": "company", "desc": "Card rerolls are always free.", "fx": {"free_reroll": 1}},
	&"pneumatic_tube": {"name": "Pneumatic Tube", "rarity": 4, "kind": "company", "desc": "The first drop of every route takes no time at all.", "fx": {"first_stop_free": 1}},
	&"golden_hour": {"name": "Golden Hour", "rarity": 3, "kind": "company", "desc": "Once past 10, your streak never drops below 10.", "fx": {"streak_floor": 10.0}},
}


## Relic choices for beating a boss client (ones you don't own yet).
static func roll_relics(rng: RandomNumberGenerator, count: int, owned: Array) -> Array:
	var pool: Array = []
	for id in DATA.keys():
		if DATA[id]["rarity"] == Rarity.RELIC and not owned.has(id):
			pool.append(id)
	pool.sort()
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


static func price(id: StringName) -> float:
	return SHOP_PRICES[mini(DATA[id]["rarity"], SHOP_PRICES.size() - 1)]


static func get_card(id: StringName) -> Dictionary:
	return DATA[id]


static func is_vehicle(id: StringName) -> bool:
	return DATA[id]["kind"] == "vehicle"


## Rolls `count` distinct cards. `boost` shifts odds toward rarer cards.
## Cards marked "season" (rent perks) only show up in season runs.
static func roll(rng: RandomNumberGenerator, count: int, boost: int, owned_perks: Array, has_vehicles: bool, min_rarity := 0, season := true) -> Array:
	var weights: Array = RARITY_WEIGHTS.duplicate()
	for b in boost:
		weights[0] *= 0.6
		weights[1] *= 1.2
		weights[2] *= 1.8
		weights[3] *= 2.0
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < 200:
		tries += 1
		var total := 0.0
		for r in range(min_rarity, 4):
			total += weights[r]
		var x := rng.randf() * total
		var rarity := min_rarity
		for r in range(min_rarity, 4):
			x -= weights[r]
			if x <= 0.0:
				rarity = r
				break
		var pool: Array = []
		for id in DATA.keys():
			var c: Dictionary = DATA[id]
			if c["rarity"] != rarity or out.has(id):
				continue
			if c["kind"] == "vehicle" and not has_vehicles:
				continue
			if c.get("season", false) and not season:
				continue
			if c["kind"] == "company" and not c.get("instant", false) and owned_perks.has(id):
				continue
			pool.append(id)
		if pool.is_empty():
			continue
		pool.sort()   # stable order -> deterministic pick
		out.append(pool[rng.randi_range(0, pool.size() - 1)])
	return out
