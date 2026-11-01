class_name Sim
extends RefCounted
## Deterministic, fixed-tick simulation. No nodes, no frame time, one seeded RNG.
## Every change from a player or an AI goes through submit() as a command, so the
## same seed + the same commands at the same ticks always replay identically.
##
## A day has phases: MORNING (briefing, clock stopped) -> DAY (07:00-21:00) ->
## EVENING (report + card draft, clock stopped) -> NIGHT (fast-forwarded) -> MORNING.
## In a season run (see Season) the lease is due every third evening, and the run
## ends in phase OVER when the player is evicted or survives day 12.

signal parcel_delivered(parcel: Parcel, van: Van, pay: float)
signal van_added(van: Van)
signal van_removed(van: Van)
signal notice(text: String, kind: String)
signal event(name: String, data: Dictionary)

enum Phase { MORNING, DAY, EVENING, NIGHT, OVER }
const WEATHER := ["Clear", "Rain", "Fog"]

const TICK_RATE := 10
const MIN_PER_TICK := 0.125
const DAY_START := 7.0 * 60.0
const DAY_END := 21.0 * 60.0
const PLAYER := 0
const RIVAL := 1

# Garage
const GARAGE_BAYS := 2
const TOW_WAIT := 25.0
const REPAIR_MIN := 110.0
const SERVICE_MIN := 35.0
const REPAIR_COST := 160.0
const SERVICE_COST := 60.0
const TOW_COST := 45.0
const BREAK_BASE := 0.00035     # per tick, scaled by (1 - condition)^2

# Job board
const OFFERS_PER_VENDOR := 2
const OFFER_LIFETIME := 150.0
const COURIER_SPEED := 0.6
const REROLL_COST := 60.0

var rng := RandomNumberGenerator.new()
var seed_value := 0
var city := City.new()
var tick := 0
var companies: Array[Company] = []
var active: Array[Parcel] = []
var recent: Array[Parcel] = []
var next_parcel_id := 1
var next_van_id := 1
var next_job_id := 1
var commands: Array[Dictionary] = []
var share: Array[float] = [0.2, 0.2, 0.2, 0.2]   # player's share of walk-in demand
var score: Array = []
var rival_ai: RivalAI
var last_day := 1
var garage_working: Array[Van] = []
var garage_queue: Array[Van] = []

# Daily rhythm + roguelike layer
var phase := Phase.MORNING
var weather := 0
var contract_offers: Array = []
var draft: Array = []            # card ids on offer this evening
var draft_rerolls := 0
var report := {}                 # evening summary for the UI

# Season run (empty run = classic endless mode)
var run := {}                    # see Season: charter, heat, daily, hq
var twist := ""                  # today's twist id ("" = none)
var week_twist := ""             # the twist waiting on this week's due day
var streak := 0                  # on-time deliveries in a row (player)
var lease_strikes := 0
var lease_debt := 0.0
var run_stats := {"best_streak": 0, "leases_paid": 0, "max_fleet": 0, "best_day": 0, "three_star_days": 0, "best_combo": 0.0, "combo_cash": 0.0, "bosses_beaten": 0}
var run_result := {}

# Dispatcher layer: hustle powers and morning events
var hustle := 0
var call_ahead_left := 0
var green_wave_until := -1.0
var demand_boost := 1.0          # today's walk-in demand multiplier from events
var morning_event := {}          # {"id", "done", "result"}

# Day plan, boss clients, shop
var today_type := "normal"       # Season.DAY_TYPES id
var tomorrow_type := ""
var day_options: Array = []      # tomorrow's choices while planning
var week_boss := ""              # Bosses id for this week's rent day
var evening_stage := ""          # "draft", "relic", "shop", "plan"
var shop: Array = []             # [{"id": StringName, "price": float, "sold": bool}]
var shop_rerolls := 0

# Staff and phone calls
var applicants: Array = []       # today's job applicants (see Staff)
var pending_call := {}           # {"id", "ctx", "van"}; the clock waits until it's answered
var next_call_at := 0.0
var fuel_sale_until := -1.0
const SHOP_REROLL := 25.0
const SHOP_TUNEUP_PER_VAN := 30.0
const SHOP_HUSTLE := 40.0


func setup(p_seed: int, start_fleet: Array, p_run := {}) -> void:
	seed_value = p_seed
	run = p_run.duplicate(true)
	rng.seed = p_seed
	city.build(rng)
	_make_company(PLAYER, "Last Mile Co.", "LMC", "Maple St. Depot", Palette.PLAYER, false)
	_make_company(RIVAL, "Zoomer Express", "ZX", "Zoomer Hub", Palette.RIVAL, true)
	var p := companies[PLAYER]
	p.money = 250.0
	p.money_start_of_day = p.money
	p.vendors_unlocked[0] = true
	for t in start_fleet:
		var v := _add_van(p, t)
		v.condition = rng.randf_range(0.68, 0.78)
	var r := companies[RIVAL]
	r.money = 1500.0
	r.level = 4
	r.auto_dispatch = true
	r.dispatch_threshold = 0.5
	r.max_wait = 12.0
	r.auto_service = 0.35
	for i in (5 if heat() >= 2 else 3):
		var v := _add_van(r, &"van")
		v.condition = rng.randf_range(0.75, 0.9)
	for d in 4:
		score.append([0.7, 0.8])
	rival_ai = RivalAI.new(self, RIVAL)
	if season_on():
		p.money = charter()["cash"] + 100.0 * hq("till")
		p.money_start_of_day = p.money
		for vi in charter().get("vendors", []):
			p.vendors_unlocked[vi] = true
		for d in 4:
			share[d] = clampf(share[d] + charter().get("share", 0.0), 0.1, 0.9)
		if not p.vans.is_empty():
			_apply_run_start(p)
	_refill_job_board(minutes())
	_begin_morning(true)


func _make_company(id: int, n: String, s: String, depot: String, col: Color, ai: bool) -> void:
	var c := Company.new()
	c.id = id
	c.name = n
	c.short = s
	c.depot_name = depot
	c.color = col
	c.is_ai = ai
	c.depot_node = city.depots[id]["node"]
	companies.append(c)


# ---------------------------------------------------------------- time

func minutes() -> float:
	return DAY_START + tick * MIN_PER_TICK


func day() -> int:
	return int(minutes() / 1440.0) + 1


func minute_of_day() -> float:
	return fmod(minutes(), 1440.0)


static func clock(m: float) -> String:
	var mm := int(fmod(m, 1440.0))
	return "%02d:%02d" % [mm / 60, mm % 60]


func clock_now() -> String:
	return clock(minutes())


func hour_curve(h: float) -> float:
	if h < 6.0:
		return 0.15
	if h < 8.0:
		return 0.7
	if h < 11.0:
		return 1.1
	if h < 14.0:
		return 1.3
	if h < 17.0:
		return 1.1
	if h < 20.0:
		return 0.9
	if h < 22.0:
		return 0.5
	return 0.2


func demand_per_hour() -> float:
	var w := 1.15 if weather == 1 else 1.0
	w *= demand_boost
	if twist == "viral":
		w *= 1.6
	if is_peak_day():
		w *= Season.PEAK_DEMAND
	return (14.0 + 6.0 * (day() - 1)) * hour_curve(minute_of_day() / 60.0) * w


func is_rush_hour() -> bool:
	var h := minute_of_day() / 60.0
	return (h >= 7.5 and h < 9.0) or (h >= 16.5 and h < 18.0)


func traffic_mult() -> float:
	var m := 0.78 if is_rush_hour() else 1.0
	if twist == "gridlock":
		m *= 0.75
	if weather == 1:
		m *= 0.88
	elif weather == 2:
		m *= 0.92
	return m


## True while the clock should run (day or the fast-forwarded night).
func clock_running() -> bool:
	return (phase == Phase.DAY or phase == Phase.NIGHT) and pending_call.is_empty()


# ---------------------------------------------------------------- commands

func submit(cmd: Dictionary) -> void:
	commands.append(cmd)


## Applies queued commands without advancing time (used while paused).
func apply_commands_now() -> void:
	_process_commands()


func _find_van(c: Company, van_id: int) -> Van:
	for v in c.vans:
		if v.id == van_id:
			return v
	return null


func _find_parcel(list: Array, id: int) -> Parcel:
	for p in list:
		if p.id == id:
			return p
	return null


func _process_commands() -> void:
	var now := minutes()
	var pending := commands.duplicate()
	commands.clear()
	for cmd in pending:
		var c: Company = companies[cmd["company"]]
		match cmd["type"]:
			"buy_van":
				var t: StringName = cmd.get("vehicle", &"van")
				var spec: Dictionary = VehicleTypes.DATA[t]
				var price := van_price(c, t)
				if c.money >= price and c.vans.size() < c.fleet_cap() and c.level >= spec["level"]:
					c.add_money(-price, "vehicles")
					var v := _add_van(c, t)
					v.condition = rng.randf_range(0.8, 0.95)
					if c.is_ai:
						notice.emit("Zoomer Express added %s to their fleet" % v.code, "rival")
					else:
						notice.emit("%s joins the team, driving %s" % [v.driver.name, v.code], "good")
						run_stats["max_fleet"] = maxi(run_stats["max_fleet"], c.vans.size())
					event.emit("van_bought", {"van": v})
			"starter_fleet":
				if c.vans.is_empty():
					for t in cmd["vehicles"]:
						var v := _add_van(c, t)
						v.condition = rng.randf_range(0.68, 0.78)
					if season_on():
						_apply_run_start(c)
					_begin_morning(true)
					event.emit("fleet_ready", {})
			"sell_van":
				var v := _find_van(c, cmd["van"])
				if v and v.state == Van.State.IDLE and v.cargo.is_empty() and c.vans.size() > 1:
					c.vans.erase(v)
					c.add_money(VehicleTypes.DATA[v.type]["cost"] * 0.4, "vehicles")
					van_removed.emit(v)
					if c.is_ai:
						notice.emit("Zoomer Express sold %s to cut costs" % v.code, "rival")
					else:
						notice.emit("Sold %s for $%d. Its wages and fuel stop now." % [v.code, int(VehicleTypes.DATA[v.type]["cost"] * 0.4)], "info")
			"start_route":
				var v := _find_van(c, cmd["van"])
				if v and v.state == Van.State.LOADING and not v.cargo.is_empty():
					_depart(c, v, now, c.depot_node)
			"set_order":
				var v := _find_van(c, cmd["van"])
				if v and v.state in [Van.State.IDLE, Van.State.LOADING]:
					var ordered: Array[Parcel] = []
					for id in cmd["order"]:
						var p := _find_parcel(v.cargo, id)
						if p and not ordered.has(p):
							ordered.append(p)
					for p in v.cargo:
						if not ordered.has(p):
							ordered.append(p)
					v.cargo = ordered
					v.manual_order = true
			"auto_order":
				var v := _find_van(c, cmd["van"])
				if v and v.state in [Van.State.IDLE, Van.State.LOADING]:
					v.cargo = _nearest_neighbor(v.cargo, c.depot_node)
					v.manual_order = false
			"load_parcel":
				var v := _find_van(c, cmd["van"])
				var p := _find_parcel(c.waiting, cmd["parcel"])
				if v and p and v.state in [Van.State.IDLE, Van.State.LOADING] and v.can_fit(p):
					c.waiting.erase(p)
					p.set_stage(Parcel.Stage.LOADED, now)
					p.van_code = v.code
					v.cargo.append(p)
					if v.state == Van.State.IDLE:
						v.state = Van.State.LOADING
						v.timer = Van.LOAD_MINUTES
			"unload_parcel":
				var v := _find_van(c, cmd["van"])
				if v and v.state in [Van.State.IDLE, Van.State.LOADING]:
					var p := _find_parcel(v.cargo, cmd["parcel"])
					if p:
						v.cargo.erase(p)
						p.set_stage(Parcel.Stage.SORTED, now)
						p.van_code = ""
						c.waiting.append(p)
						if v.auto_fill and c.id == PLAYER:
							notice.emit("Auto-load is off for %s so it keeps your changes" % v.code, "info")
						v.auto_fill = false
			"set_auto_fill":
				var v := _find_van(c, cmd["van"])
				if v:
					v.auto_fill = cmd["value"]
			"rescue":
				var v := _find_van(c, cmd["van"])
				var target := _find_van(c, cmd["target"])
				if v and target and target.state == Van.State.BROKEN and v.state in [Van.State.IDLE, Van.State.LOADING]:
					v.rescue_target = target.id
					var dest := city.astar.get_closest_point(target.pos)
					v.target_node = dest
					v.set_path(city.path(c.depot_node, dest))
					v.state = Van.State.RESCUE
					v.ready = false
					for p in v.cargo:
						p.set_stage(Parcel.Stage.OUT, now)
					v.route_total = v.cargo.size()
					notice.emit("%s is heading out to rescue %s's parcels" % [v.code, target.code], "info")
			"service_van":
				var v := _find_van(c, cmd["van"])
				if v and v.state == Van.State.IDLE:
					_send_to_shop(c, v)
			"accept_job":
				for j in c.jobs:
					if j.id == cmd["job"] and j.state == Job.State.OFFERED:
						j.state = Job.State.PACKING
						j.timer = Vendors.get_vendor(j.vendor)["prep"] * (0.5 if j.rush else 1.0)
						event.emit("job_taken", {"job": j})
			"unlock_vendor":
				var vi: int = cmd["vendor"]
				var vd := Vendors.get_vendor(vi)
				if not c.vendors_unlocked.has(vi) and c.level >= vd["level"] and c.money >= vd["unlock"]:
					c.add_money(-vd["unlock"], "unlocks")
					c.vendors_unlocked[vi] = true
					notice.emit("New partner: %s now posts jobs on your board" % vd["name"], "good")
					_refill_job_board(now)
			"pick_contract":
				if phase == Phase.MORNING and c.id == PLAYER:
					var i: int = cmd["index"]
					c.contract = contract_offers[i] if i >= 0 and i < contract_offers.size() else {}
					c.contract_done = false
					phase = Phase.DAY
					event.emit("day_begun", {})
			"pick_card":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage in ["draft", "relic"]:
					var i: int = cmd["index"]
					if i >= 0 and i < draft.size():
						_apply_card(c, draft[i], cmd.get("van", -1))
					_after_draft()
			"skip_card":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage in ["draft", "relic"]:
					c.add_money(100.0 if evening_stage == "relic" else 40.0, "cards")
					_after_draft()
			"shop_buy":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage == "shop":
					var i: int = cmd["index"]
					if i >= 0 and i < shop.size() and not shop[i]["sold"] and c.money >= shop[i]["price"]:
						var id: StringName = shop[i]["id"]
						if Cards.is_vehicle(id) and _find_van(c, cmd.get("van", -1)) == null:
							pass
						else:
							c.add_money(-shop[i]["price"], "cards")
							shop[i]["sold"] = true
							_apply_card(c, id, cmd.get("van", -1))
							event.emit("shop_changed", {"bought": id})
			"shop_service":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage == "shop":
					_shop_service(c, cmd["service"])
			"shop_reroll":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage == "shop":
					var cost := shop_reroll_cost()
					if c.money >= cost:
						c.add_money(-cost, "cards")
						shop_rerolls += 1
						_open_shop(c)
						event.emit("shop_changed", {})
			"shop_leave":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage == "shop":
					_after_draft()
			"pick_day":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage == "plan":
					var i: int = cmd["index"]
					if i >= 0 and i < day_options.size():
						tomorrow_type = day_options[i]
						_begin_night()
			"reroll_draft":
				if phase == Phase.EVENING and c.id == PLAYER and evening_stage == "draft":
					var cost := reroll_cost()
					if c.money >= cost:
						c.add_money(-cost, "cards")
						draft_rerolls += 1
						_roll_draft(c, report.get("draft_count", 3), report.get("boost", 0), report.get("min_rarity", 0))
						event.emit("draft_rerolled", {})
			"set_auto_dispatch":
				c.auto_dispatch = cmd["value"]
			"set_threshold":
				c.dispatch_threshold = clampf(cmd["value"], 0.25, 1.0)
			"set_max_wait":
				c.max_wait = clampf(cmd["value"], 5.0, 60.0)
			"set_auto_service":
				c.auto_service = clampf(cmd["value"], 0.0, 0.8)
			"hire_staff":
				var i: int = cmd["index"]
				if c.id == PLAYER and i >= 0 and i < applicants.size() and c.staff.size() < Staff.slots(c.level):
					var a: Dictionary = applicants[i]
					if c.money >= a["wage"]:
						c.add_money(-a["wage"], "staff")       # signing fee: the first day's wage
						c.staff.append(a)
						applicants.remove_at(i)
						notice.emit("%s joins as your %s: %s" % [a["name"], Staff.get_role(a["role"])["role"], Staff.get_role(a["role"])["desc"]], "good")
						event.emit("staff_hired", {"staff": a})
			"fire_staff":
				var i: int = cmd["index"]
				if c.id == PLAYER and i >= 0 and i < c.staff.size():
					var a: Dictionary = c.staff[i]
					c.staff.remove_at(i)
					notice.emit("%s (%s) has left. Their perk is gone and so is their wage." % [a["name"], Staff.get_role(a["role"])["role"]], "info")
					event.emit("staff_fired", {"staff": a})
			"answer_call":
				if c.id == PLAYER and not pending_call.is_empty():
					_answer_call(c, cmd["index"], now)
			"ability":
				if c.id == PLAYER and phase == Phase.DAY:
					_use_ability(c, cmd["ability"], cmd.get("van", -1), now)
			"pick_event":
				if c.id == PLAYER and phase == Phase.MORNING and not morning_event.is_empty() and not morning_event.get("done", false):
					_resolve_event(c, cmd["index"])


func _add_van(c: Company, t: StringName) -> Van:
	var v := Van.new()
	v.id = next_van_id
	next_van_id += 1
	v.company = c.id
	v.type = t
	v.refresh_stats()
	v.number = c.vans.size() + 1
	v.code = ("%s-%02d" % [v.spec()["short"], v.number]) if c.id == PLAYER else "ZX-%02d" % v.number
	v.driver = Driver.generate(rng, day())
	v.node = c.depot_node
	v.pos = city.node_pos(v.node)
	v.prev_pos = v.pos
	c.vans.append(v)
	van_added.emit(v)
	return v


# ---------------------------------------------------------------- season run

func season_on() -> bool:
	return not run.is_empty()


func heat() -> int:
	return int(run.get("heat", 0))


func hq(id: String) -> int:
	return int(run.get("hq", {}).get(id, 0))


func charter() -> Dictionary:
	return Season.charter(run.get("charter", "courier"))


func is_peak_day() -> bool:
	return season_on() and day() == Season.DAYS


func reroll_cost() -> float:
	if companies[PLAYER].has_perk_fx("free_reroll"):
		return 0.0
	if hq("dice") > 0 and draft_rerolls == 0:
		return 0.0
	return REROLL_COST * (draft_rerolls + 1 - mini(hq("dice"), 1))


## Lease due at the end of this week, including any carried debt.
func lease_amount() -> float:
	if not season_on():
		return 0.0
	var m: float = charter().get("lease", 1.0) * (1.0 - 0.08 * hq("landlord")) * companies[PLAYER].perk("lease") \
		* Season.heat_lease_mult(heat())
	return roundf(Season.LEASES[Season.week_of(day())] * m) + roundf(lease_debt)


## Missed leases you can survive. Heat 4 takes away the free one.
func strikes_allowed() -> int:
	return (0 if heat() >= 4 else 1) + hq("grace")


func promise_mult() -> float:
	var m: float = charter().get("promise", 1.0) if season_on() else 1.0
	if heat() >= 6:
		m *= 0.85
	if twist == "tight":
		m *= 0.7
	if boss_rule() == "rossi":
		m *= 0.8
	return m


## Today's boss client rule ("" unless it's a boss day).
func boss_rule() -> String:
	return week_boss if today_type == "boss" else ""


func van_price(c: Company, t: StringName) -> float:
	var cost: float = VehicleTypes.DATA[t]["cost"]
	if c.id == PLAYER and today_type == "market":
		cost *= 0.8
	return roundf(cost)


func shop_reroll_cost() -> float:
	return SHOP_REROLL * (shop_rerolls + 1)


func _open_shop(p: Company) -> void:
	shop = []
	for id in Cards.roll(rng, 4, 1, p.perks, not p.vans.is_empty(), 0, true):
		shop.append({"id": id, "price": Cards.price(id), "sold": false})


func _shop_service(c: Company, service: String) -> void:
	match service:
		"tuneup":
			var cost := SHOP_TUNEUP_PER_VAN * c.vans.size()
			if c.money < cost:
				return
			c.add_money(-cost, "services")
			for v in c.vans:
				v.condition = maxf(v.condition, 1.0 if v.state in [Van.State.IDLE, Van.State.LOADING] else v.condition)
			notice.emit("The whole fleet gets a tune-up", "good")
		"hustle":
			if c.money < SHOP_HUSTLE or hustle >= hustle_cap():
				return
			c.add_money(-SHOP_HUSTLE, "cards")
			hustle = hustle_cap()
			notice.emit("Hustle topped up", "good")
		_:
			return
	event.emit("shop_changed", {"service": service})


## After the card (or relic, or shop): plan tomorrow, unless tomorrow is rent day.
func _after_draft() -> void:
	if not season_on():
		_begin_night()
		return
	if (day() + 1) % Season.WEEK_DAYS == 0:
		tomorrow_type = "boss"
		_begin_night()
		return
	var pool: Array = Season.PLAN_POOL.duplicate()
	day_options = []
	while day_options.size() < 3 and not pool.is_empty():
		day_options.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	evening_stage = "plan"
	draft = []
	event.emit("plan_tomorrow", {})


func streak_cap() -> int:
	return Season.STREAK_CAP + int(companies[PLAYER].perk_add("streak_cap"))


func streak_mult() -> float:
	var step := Season.STREAK_STEP + 0.01 * hq("hype")
	return 1.0 + step * mini(streak, streak_cap())


## One-time bonuses for the chosen charter and HQ upgrades, once the fleet exists.
func _apply_run_start(p: Company) -> void:
	if run.get("applied", false):
		return
	run["applied"] = true
	var ch := charter()
	for v in p.vans:
		for m in ch.get("mods_each", []):
			v.mods.append(m)
		if ch.has("mood"):
			v.driver.mood = ch["mood"]
	for m in ch.get("mods_last", []):
		p.vans[p.vans.size() - 1].mods.append(m)
	for v in p.vans:
		v.refresh_stats()
	if hq("scout") > 0:
		var picks := Cards.roll(rng, 1, 0, p.perks, true, 1)
		if not picks.is_empty():
			var id: StringName = picks[0]
			var target := p.vans[0]
			for v in p.vans:
				if v.mods.size() < target.mods.size():
					target = v
			_apply_card(p, id, target.id)
	run_stats["max_fleet"] = p.vans.size()


## Picks today's twist. A week's twist is rolled on its first morning, so the
## briefing can warn about it two days ahead.
func _roll_twists() -> void:
	twist = ""
	if not season_on():
		week_twist = ""
		return
	var d := day()
	if (d - 1) % Season.WEEK_DAYS == 0:
		week_twist = Season.TWIST_ORDER[rng.randi_range(0, Season.TWIST_ORDER.size() - 1)]
		week_boss = Bosses.ORDER[rng.randi_range(0, Bosses.ORDER.size() - 1)]
	if d % Season.WEEK_DAYS == 2:
		twist = week_twist
	elif heat() >= 5 and d % Season.WEEK_DAYS == 0:
		var pool: Array = Season.TWIST_ORDER.filter(func(t): return t != week_twist)
		twist = pool[rng.randi_range(0, pool.size() - 1)]


## Counts an on-time drop. Returns the tip earned (Tip Jar).
func _bump_streak(c: Company) -> float:
	streak += 1
	run_stats["best_streak"] = maxi(run_stats["best_streak"], streak)
	c.counters["streak_peak"] = maxi(c.counters.get("streak_peak", 0), streak)
	if streak in Season.STREAK_TIERS and streak <= streak_cap():
		_gain_hustle(2)
		notice.emit("%s! %d on time in a row: deliveries pay x%.2f" % [Season.STREAK_NAMES[streak], streak, streak_mult()], "streak")
		event.emit("streak_tier", {"streak": streak})
	if c.has_perk_fx("tip_jar"):
		return float(mini(streak, streak_cap()) / 5)
	return 0.0


func _break_streak(c: Company, why: String) -> void:
	if streak <= 0:
		return
	var was := streak
	if why == "late" and c.has_perk_fx("second_wind"):
		streak = streak / 2
	else:
		streak = 0
	var floor_at := int(c.perk_add("streak_floor"))
	if floor_at > 0 and was >= floor_at:
		streak = maxi(streak, floor_at)
	if was >= 5 and streak < was:
		notice.emit("Streak %s at %d (%s)" % ["cut" if streak > 0 else "broken", was, "late parcel" if why == "late" else "nobody home"], "bad")
		event.emit("streak_broken", {"was": was, "now": streak})


## Bills the lease on a due evening. Returns the report entry.
func _settle_lease(p: Company) -> Dictionary:
	var amount := lease_amount()
	var out := {"due": true, "amount": amount, "paid": false, "strike": false, "evicted": false, "won": false}
	if p.money >= amount:
		p.add_money(-amount, "rent")
		lease_debt = 0.0
		run_stats["leases_paid"] += 1
		out["paid"] = true
		out["won"] = day() >= Season.DAYS
	elif day() < Season.DAYS and lease_strikes < strikes_allowed():
		# Final notice: pay what you can, the rest (plus a late fee) rolls into next week.
		var part := maxf(p.money, 0.0)
		p.add_money(-part, "rent")
		lease_strikes += 1
		lease_debt = (amount - part) * Season.LATE_FEE
		out["strike"] = true
		out["paid_part"] = part
		out["debt"] = lease_debt
	else:
		out["evicted"] = true
	return out


func _end_run(won: bool) -> void:
	phase = Phase.OVER
	draft = []
	var p := companies[PLAYER]
	run_result = run_stats.duplicate()
	run_result.merge({
		"id": run.get("id", 0), "charter": run.get("charter", "courier"), "heat": heat(),
		"daily": run.get("daily", false), "daily_number": run.get("daily_number", -1),
		"won": won, "day": day(), "revenue": p.lifetime_revenue, "stars": p.stars_total,
		"delivered": p.delivered_total, "ontime_rate": p.ontime_rate_total(), "fleet": p.vans.size(),
		"level_name": p.level_info()["name"], "ended_at": int(Time.get_unix_time_from_system()),
	})
	run_result["score"] = Season.score(run_result)
	run_result["rep"] = Season.rep_earned(run_result)
	event.emit("run_over", run_result)


# ---------------------------------------------------------------- day rhythm

func _begin_morning(first := false) -> void:
	phase = Phase.MORNING
	var p := companies[PLAYER]
	p.counters = {}
	p.contract = {}
	p.contract_done = false
	if first:
		weather = 0
		city.set_closures([])
	else:
		var r := rng.randf()
		weather = 0 if r < 0.55 else (1 if r < 0.85 else 2)
		# Close 0-2 north-south road segments for road works today.
		var pairs: Array = []
		var n := rng.randi_range(0, 2)
		var tries := 0
		while pairs.size() < n and tries < 20:
			tries += 1
			var i := rng.randi_range(1, City.GRID - 1)
			var j := rng.randi_range(0, City.GRID - 1)
			var a: int = city.intersections[Vector2i(i, j)]
			var b: int = city.intersections[Vector2i(i, j + 1)]
			var dup := false
			for q in pairs:
				if q[0] == a:
					dup = true
			if not dup:
				pairs.append([a, b])
		city.set_closures(pairs)
	var has_heavy := false
	for v in p.vans:
		if v.carries_heavy():
			has_heavy = true
	contract_offers = Contracts.roll(rng, day(), maxi(1, p.vans.size()), has_heavy)
	_roll_twists()
	streak = 0                    # a fresh streak to chase every day
	demand_boost = 1.0
	green_wave_until = -1.0
	_start_day_type(p)
	_roll_event()
	_roll_applicants(p)
	call_ahead_left = int(p.perk_add("call_ahead_morning"))
	next_call_at = floorf(minutes() / 1440.0) * 1440.0 + Calls.FIRST + rng.randf_range(0.0, 60.0) + (150.0 if day() == 1 else 0.0)
	pending_call = {}
	_gain_hustle(int(p.perk_add("hustle_morning")))
	event.emit("morning", {})


func _begin_evening() -> void:
	phase = Phase.EVENING
	var p := companies[PLAYER]
	var ontime: int = p.counters.get("ontime", 0)
	var late: int = p.counters.get("late", 0)
	var total := ontime + late
	var rate := (float(ontime) / total) if total > 0 else 0.0
	var done := Contracts.is_done(p.contract, p.counters)
	var stars := 0
	if total > 0 and rate >= 0.7:
		stars += 1
	if total > 0 and rate >= 0.9:
		stars += 1
	if done:
		stars += 1
	p.stars_total += stars
	if stars == 3:
		run_stats["three_star_days"] += 1
	run_stats["best_day"] = maxi(run_stats["best_day"], total)
	var tier: Dictionary = Contracts.TIERS[p.contract.get("tier", 0)] if done else {"draft_count": 3, "boost": 0, "min_rarity": 0}
	var reward: float = p.contract.get("reward", 0.0) if done else 0.0
	if done:
		p.add_money(reward, "contracts")
	# Savings interest: $5 for every $100 in the till, capped. Saving vs. spending.
	var interest := 0.0
	if season_on() and p.money > 0.0:
		interest = minf(floorf(p.money / 100.0) * 5.0, 25.0 + p.perk_add("interest_cap"))
		p.add_money(interest, "interest")
	var staff_pay := p.staff_wages()
	if staff_pay > 0.0:
		p.add_money(-staff_pay, "staff")
	var lease := {}
	if season_on() and day() % Season.WEEK_DAYS == 0:
		lease = _settle_lease(p)
	var count_mod := hq("shark") - (1 if heat() >= 3 else 0)
	report = {
		"day": day(), "delivered": total, "ontime": ontime, "late": late, "rate": rate,
		"revenue": p.revenue_today, "net": p.money - p.money_start_of_day,
		"contract": p.contract.duplicate(), "contract_done": done, "reward": reward, "stars": stars,
		"draft_count": maxi(2, tier["draft_count"] + (1 if stars == 3 else 0) + count_mod), "boost": tier["boost"], "min_rarity": tier["min_rarity"],
		"failed_attempts": p.counters.get("not_home", 0), "breakdowns": p.counters.get("breakdowns", 0),
		"interest": interest, "lease": lease, "twist": twist, "streak": streak,
	}
	# Money in and out since the last report, then start a fresh page.
	report["ledger"] = p.ledger.duplicate()
	report["net"] = p.ledger_total()
	var per_van: Array = []
	for v in p.vans:
		per_van.append({"code": v.code, "earned": v.earned_today, "cost": v.cost_today})
		v.earned_today = 0.0
		v.cost_today = 0.0
	report["vans"] = per_van
	p.ledger = {}
	draft_rerolls = 0
	city.set_closures([])
	if lease.get("evicted", false) or lease.get("won", false):
		report["run_end"] = "won" if lease.get("won", false) else "evicted"
		_end_run(lease.get("won", false))
		return
	report["today_type"] = today_type
	if season_on() and today_type == "boss" and done:
		run_stats["bosses_beaten"] = int(run_stats.get("bosses_beaten", 0)) + 1
		draft = Cards.roll_relics(rng, 2, p.perks)
		evening_stage = "relic" if not draft.is_empty() else "draft"
		if draft.is_empty():
			_roll_draft(p, report["draft_count"], report["boost"], report["min_rarity"])
	elif season_on() and today_type == "market":
		shop_rerolls = 0
		_open_shop(p)
		evening_stage = "shop"
		draft = []
	else:
		evening_stage = "draft"
		_roll_draft(p, report["draft_count"], report["boost"], report["min_rarity"])
	event.emit("evening", report)


func _roll_draft(p: Company, n: int, boost: int, min_rarity: int) -> void:
	draft = Cards.roll(rng, n, boost, p.perks, not p.vans.is_empty(), min_rarity, season_on())


func _begin_night() -> void:
	phase = Phase.NIGHT
	draft = []
	shop = []
	day_options = []
	evening_stage = ""
	twist = ""
	event.emit("night", {})


func _apply_card(c: Company, id: StringName, van_id: int) -> void:
	var card := Cards.get_card(id)
	if card["kind"] == "vehicle":
		var v := _find_van(c, van_id)
		if v == null:
			return
		if v.mods.size() >= v.mod_slots():
			v.mods.pop_front()
		v.mods.append(id)
		v.refresh_stats()
		notice.emit("%s installed on %s" % [card["name"], v.code], "good")
	else:
		var fx: Dictionary = card["fx"]
		if fx.has("mood_now"):
			for v in c.vans:
				v.driver.change_mood(fx["mood_now"])
		if fx.has("share_now"):
			for d in 4:
				share[d] = clampf(share[d] + fx["share_now"], 0.1, 0.9)
		if not card.get("instant", false):
			c.perks.append(id)
		notice.emit("New perk: %s" % card["name"], "good")
	event.emit("card_applied", {"card": id})


# ---------------------------------------------------------------- main step

func step() -> void:
	if not pending_call.is_empty():
		_process_commands()      # the phone is ringing: nothing moves until it's answered
		return
	tick += 1
	_process_commands()
	var now := minutes()
	_spawn_walk_ins(now)
	for c in companies:
		_update_sorting(c, now)
		for v in c.vans:
			_step_van(c, v, now)
		_pay_costs(c)
	_step_jobs(companies[PLAYER], now)
	_step_garage(now)
	if tick % 80 == 0:
		_update_reputation(now)
		_refill_job_board(now)
		_maybe_rush_order(now)
	if tick % 40 == 0:
		rival_ai.think()
	if phase == Phase.DAY and now >= next_call_at:
		_ring_call(now)
	_check_new_day()
	var m := minute_of_day()
	if phase == Phase.DAY and m >= DAY_END:
		_begin_evening()
	elif phase == Phase.NIGHT and m >= DAY_START and m < DAY_START + 1.0:
		_begin_morning()


# ---------------------------------------------------------------- demand

func _spawn_walk_ins(now: float) -> void:
	var expected := demand_per_hour() / 60.0 * MIN_PER_TICK
	while expected > 0.0:
		if rng.randf() < minf(expected, 1.0):
			_spawn_walk_in(now)
		expected -= 1.0


func _new_parcel(c: Company, house_id: int, now: float) -> Parcel:
	var p := Parcel.new()
	p.id = next_parcel_id
	next_parcel_id += 1
	p.company = c.id
	p.house = house_id
	p.district = city.houses[house_id]["district"]
	p.created = now
	p.set_stage(Parcel.Stage.PLACED, now)
	if c.id == PLAYER and boss_rule() == "henderson":
		p.signature = true
	active.append(p)
	c.sorting.append(p)
	return p


## Some customers are only home at certain times, some need a signature.
func _assign_window(c: Company, p: Parcel, now: float) -> void:
	var h := fmod(now, 1440.0) / 60.0
	var base := floorf(now / 1440.0) * 1440.0
	var r := rng.randf()
	if r < 0.09 and h < 15.0:
		p.window_start = base + 17.0 * 60.0
		p.deadline = maxf(p.deadline, p.window_start + 90.0)
	elif r < 0.17 and h < 9.5:
		p.window_end = base + 12.0 * 60.0
		p.deadline = minf(p.deadline, p.window_end)
	if rng.randf() < 0.1:
		p.signature = true
		p.pay_amount += 4.0
	p.deadline += c.perk("promise_add", 0.0)


func _spawn_walk_in(now: float) -> void:
	var hid := rng.randi_range(0, city.houses.size() - 1)
	var d: int = city.houses[hid]["district"]
	var odds := clampf(share[d] + companies[PLAYER].perk_add("share_bonus"), 0.0, 0.9) * (0.6 if twist == "blitz" else 1.0)
	var cid := PLAYER if rng.randf() < odds else RIVAL
	var c := companies[cid]
	var p := _new_parcel(c, hid, now)
	var express_odds := 0.35 if twist == "viral" else 0.2
	if cid == PLAYER and boss_rule() == "techcorp":
		express_odds = 0.5
	p.kind = Parcel.Kind.EXPRESS if rng.randf() < express_odds else Parcel.Kind.STANDARD
	p.weight = snappedf(rng.randf_range(0.5, 8.0), 0.1)
	if cid == PLAYER and boss_rule() == "bulkbarn":
		p.weight *= 3.0
	p.pay_amount = 18.0 if p.kind == Parcel.Kind.EXPRESS else 11.0
	var promise := 60.0 if p.kind == Parcel.Kind.EXPRESS else 150.0
	if cid == PLAYER:
		promise *= promise_mult()
		if season_on():
			p.pay_amount *= charter().get("walkin_pay", 1.0)
	p.deadline = now + promise
	_assign_window(c, p, now)


## Keeps each unlocked vendor's offers topped up and drops expired ones.
func _refill_job_board(now: float) -> void:
	var c := companies[PLAYER]
	var i := 0
	while i < c.jobs.size():
		var j := c.jobs[i]
		if (j.state == Job.State.OFFERED and now > j.expires) or j.state == Job.State.DONE:
			c.jobs.remove_at(i)
		else:
			i += 1
	for vi in Vendors.count():
		if not c.vendors_unlocked.has(vi):
			continue
		var n := 0
		for j in c.jobs:
			if j.vendor == vi and j.state == Job.State.OFFERED and not j.rush:
				n += 1
		while n < OFFERS_PER_VENDOR:
			c.jobs.append(_make_job(vi, now))
			n += 1


func _make_job(vi: int, now: float, rush := false) -> Job:
	var vd := Vendors.get_vendor(vi)
	var j := Job.new()
	j.id = next_job_id
	next_job_id += 1
	j.vendor = vi
	j.rush = rush
	var stops := rng.randi_range(3, 8) if vd["heavy"] < 1.0 else rng.randi_range(1, 4)
	if rush:
		stops = rng.randi_range(1, 3)
	var dist_sum := 0.0
	var depot := companies[PLAYER].depot_node
	for k in stops:
		var hid := rng.randi_range(0, city.houses.size() - 1)
		j.houses.append(hid)
		var kg: Array = vd["kg"]
		var w: float = rng.randf_range(kg[0], kg[1])
		if rng.randf() < vd["heavy"] and w < Vendors.HEAVY_KG:
			w = rng.randf_range(Vendors.HEAVY_KG, 110.0)
		w = snappedf(w, 0.5)
		j.weights.append(w)
		j.total_kg += w
		dist_sum += city.manhattan(depot, city.houses[hid]["curb"])
	j.express = rush or rng.randf() < vd["express"]
	j.promise = 60.0 if rush else (75.0 if j.express else 170.0)
	# Pay: a base fee, plus per stop, per kilogram and for distance from the depot.
	var avg_dist := dist_sum / stops
	var b := {"base": 10.0, "stops": stops * 6.0, "weight": j.total_kg * 0.32, "distance": avg_dist * 0.12 * stops,
		"liftgate": 25.0 if j.needs_liftgate() else 0.0, "express": 1.3 if j.express else 1.0, "rush": 1.8 if rush else 1.0,
		"vendor": float(vd["mult"]) * 0.85, "perk": companies[PLAYER].perk("job_pay")}
	var raw: float = b["base"] + b["stops"] + b["weight"] + b["distance"] + b["liftgate"]
	j.pay = roundf(raw * b["express"] * b["rush"] * b["vendor"] * b["perk"])
	b["prep"] = float(vd["prep"]) * (0.5 if rush else 1.0)
	j.breakdown = b
	j.expires = now + (20.0 if rush else OFFER_LIFETIME + rng.randf_range(0.0, 60.0))
	j.pos = city.node_pos(city.vendor_lots[vi]["curb"])
	j.prev_pos = j.pos
	return j


func _maybe_rush_order(now: float) -> void:
	if phase != Phase.DAY or minute_of_day() > DAY_END - 90.0:
		return
	var c := companies[PLAYER]
	if c.vans.is_empty() or rng.randf() > 0.06:
		return
	var open: Array = c.vendors_unlocked.keys()
	open.sort()
	var vi: int = open[rng.randi_range(0, open.size() - 1)]
	var j := _make_job(vi, now, true)
	c.jobs.append(j)
	notice.emit("RUSH ORDER from %s: %s, 20 min to accept!" % [Vendors.get_vendor(vi)["name"], "$%d" % int(j.pay)], "rush")
	event.emit("rush_order", {"job": j})


func _step_jobs(c: Company, now: float) -> void:
	for j in c.jobs:
		j.prev_pos = j.pos
		match j.state:
			Job.State.PACKING:
				j.timer -= MIN_PER_TICK
				if j.timer <= 0.0:
					j.state = Job.State.INBOUND
					var from: int = city.vendor_lots[j.vendor]["curb"]
					j.set_path(city.path(from, c.depot_node))
					j.prev_pos = j.pos
			Job.State.INBOUND:
				if j.drive(COURIER_SPEED):
					_job_arrived(c, j, now)


func _job_arrived(c: Company, j: Job, now: float) -> void:
	j.state = Job.State.DONE
	var per_stop := j.pay / j.stops()
	for k in j.stops():
		var p := _new_parcel(c, j.houses[k], now)
		p.vendor = j.vendor
		p.job_id = j.id
		p.weight = j.weights[k]
		p.kind = Parcel.Kind.EXPRESS if j.express else Parcel.Kind.STANDARD
		p.pay_amount = per_stop
		p.deadline = now + j.promise * promise_mult()
		if not j.rush:
			_assign_window(c, p, now)
		else:
			p.deadline += c.perk("promise_add", 0.0)
	var vd := Vendors.get_vendor(j.vendor)
	notice.emit("%s dropped off %d parcels at your depot" % [vd["name"], j.stops()], "info")
	event.emit("job_arrived", {"job": j})


func _update_sorting(c: Company, now: float) -> void:
	var sort_time := Parcel.SORT_MINUTES * c.perk("sort")
	var i := 0
	while i < c.sorting.size():
		var p := c.sorting[i]
		if now - p.stage_times[Parcel.Stage.PLACED] >= sort_time:
			p.set_stage(Parcel.Stage.SORTED, now)
			c.waiting.append(p)
			c.sorting.remove_at(i)
		else:
			i += 1


# ---------------------------------------------------------------- vans

func _pop_loadable(c: Company, v: Van) -> Parcel:
	var best := -1
	var now := minutes()
	for i in c.waiting.size():
		var p := c.waiting[i]
		if not v.can_fit(p) or p.window_start - now > 60.0:
			continue
		if best < 0:
			best = i
			continue
		var b := c.waiting[best]
		if v.carries_heavy() and p.heavy() != b.heavy():
			if p.heavy():
				best = i
		elif p.deadline < b.deadline:
			best = i
	if best < 0:
		return null
	var out := c.waiting[best]
	c.waiting.remove_at(best)
	return out


func _has_loadable(c: Company, v: Van) -> bool:
	var now := minutes()
	for p in c.waiting:
		if v.can_fit(p) and p.window_start - now <= 60.0:
			return true
	return false


func _mood(v: Van, delta: float) -> void:
	if delta < 0.0 and v.fx_has("mood_lock"):
		return
	if delta < 0.0 and twist == "heatwave" and v.company == PLAYER:
		delta *= 2.0
	if delta < 0.0 and v.company == PLAYER:
		delta *= companies[PLAYER].perk("mood_drain")
	v.driver.change_mood(delta)
	if delta < 0.0 and v.company == PLAYER:
		var floor_at := companies[PLAYER].perk_add("mood_floor")
		if floor_at > 0.0 and v.driver.mood < floor_at:
			v.driver.mood = floor_at


func _step_van(c: Company, v: Van, now: float) -> void:
	v.prev_pos = v.pos
	if now < v.hold_until and v.state in [Van.State.EN_ROUTE, Van.State.RETURNING, Van.State.RESCUE]:
		_mood(v, -0.004)        # stopped at the roadside
		return
	match v.state:
		Van.State.IDLE:
			_mood(v, 0.012)
			var fix := c.perk_add("depot_repair")
			if fix > 0.0:
				v.condition = minf(1.0, v.condition + fix / TICKS_PER_HOUR)
			v.ready = false
			if c.auto_service > 0.0 and v.condition < c.auto_service:
				_send_to_shop(c, v)
			elif v.auto_fill and _has_loadable(c, v):
				v.state = Van.State.LOADING
				v.timer = Van.LOAD_MINUTES * v.driver.load_mult() * c.perk("load")
		Van.State.LOADING:
			v.timer -= MIN_PER_TICK
			if v.timer <= 0.0 and v.auto_fill:
				var p := _pop_loadable(c, v)
				if p:
					p.set_stage(Parcel.Stage.LOADED, now)
					p.van_code = v.code
					v.cargo.append(p)
					v.timer = Van.LOAD_MINUTES * v.driver.load_mult() * c.perk("load")
					if v.cargo.size() == 1:
						event.emit("van_loaded", {"van": v})
			if not v.cargo.is_empty():
				v.wait += MIN_PER_TICK
			var can_more := v.auto_fill and _has_loadable(c, v)
			v.ready = not v.cargo.is_empty() and (not can_more or v.fill_ratio() >= 0.999)
			if c.auto_dispatch and not v.cargo.is_empty():
				var urgent := false
				for p in v.cargo:
					if p.deadline - now < 35.0:
						urgent = true
				if v.fill_ratio() >= c.dispatch_threshold or not can_more and v.wait >= 3.0 \
						or v.wait >= c.max_wait or urgent:
					_depart(c, v, now, c.depot_node)
			elif v.cargo.is_empty() and not can_more:
				v.state = Van.State.IDLE
		Van.State.EN_ROUTE:
			_mood(v, -0.004)
			var arrived := v.drive(_van_speed(v))
			if _wear_and_maybe_break(c, v, now):
				return
			if arrived:
				v.node = v.target_node
				v.state = Van.State.DELIVERING
				var p := v.cargo[0]
				v.timer = stop_minutes(v, p)
				if c.id == PLAYER and v.cargo.size() == v.route_total and c.has_perk_fx("first_stop_free"):
					v.timer = 0.05
		Van.State.DELIVERING:
			v.timer -= MIN_PER_TICK
			if v.timer <= 0.0:
				var p: Parcel = v.cargo.pop_front()
				var called := c.id == PLAYER and call_ahead_left > 0 and p.window_start > 0.0 and now < p.window_start
				if called:
					call_ahead_left -= 1
				if p.window_start > 0.0 and now < p.window_start and not called:
					_not_home(c, v, p)
				else:
					_deliver(c, v, p, now)
				_go_to_next(c, v)
		Van.State.RETURNING:
			_mood(v, -0.002)
			var arrived := v.drive(_van_speed(v))
			if _wear_and_maybe_break(c, v, now):
				return
			if arrived:
				v.node = c.depot_node
				v.state = Van.State.IDLE
				v.route_total = 0
				v.auto_fill = true
				for p in v.returns:
					p.set_stage(Parcel.Stage.SORTED, now)
					p.van_code = ""
					c.waiting.append(p)
				v.returns.clear()
				event.emit("van_home", {"van": v})
		Van.State.RESCUE:
			var arrived := v.drive(_van_speed(v))
			if _wear_and_maybe_break(c, v, now):
				return
			if arrived:
				v.node = v.target_node
				var target := _find_van(c, v.rescue_target)
				v.rescue_target = -1
				var taken := 0
				if target and target.state == Van.State.BROKEN:
					var keep: Array[Parcel] = []
					for p in target.cargo:
						if v.can_fit(p):
							p.van_code = v.code
							v.cargo.append(p)
							taken += 1
						else:
							keep.append(p)
					target.cargo = keep
				if taken > 0:
					notice.emit("%s picked up %d stranded parcels" % [v.code, taken], "good")
				_depart(c, v, now, v.node)
		Van.State.BROKEN:
			v.timer -= MIN_PER_TICK
			_mood(v, -0.02)
			if v.timer <= 0.0:
				_start_tow(c, v, now)
		Van.State.TOWING:
			if v.drive(Van.BASE_SPEED * 0.75):
				_arrive_shop(c, v, "repair")
		Van.State.TO_SHOP:
			if v.drive(_van_speed(v)):
				_arrive_shop(c, v, "service")
		Van.State.AT_SHOP:
			_mood(v, 0.006)


func _van_speed(v: Van) -> float:
	var cond_mult := 0.85 + 0.15 * v.condition   # worn vans are sluggish
	var gps := v.fx("gps") if v.route_total >= 5 else 1.0
	var boost := Abilities.FLOOR_IT_MULT if minutes() < v.boost_until else 1.0
	return Van.BASE_SPEED * v.spec()["speed"] * v.fx("speed") * gps * v.driver.speed_mult(minute_of_day()) \
		* cond_mult * traffic_for(v.company) * boost * companies[v.company].perk("fleet_speed")


## Traffic as one company sees it (Green Wave lifts it for the player).
func traffic_for(cid: int) -> float:
	if cid == PLAYER and green_wave_active():
		return 1.1
	return traffic_mult()


func green_wave_active() -> bool:
	return minutes() < green_wave_until


func hustle_cap() -> int:
	return Abilities.BASE_CAP + int(companies[PLAYER].perk_add("hustle_cap"))


## Dispatcher powers. Returns quietly if it can't be used.
func _use_ability(c: Company, id: String, van_id: int, now: float) -> void:
	if not Abilities.DATA.has(id):
		return
	var cost: int = Abilities.DATA[id]["cost"]
	if hustle < cost:
		return
	match id:
		"floor_it":
			var v := _find_van(c, van_id)
			if v == null or not (v.state in [Van.State.EN_ROUTE, Van.State.DELIVERING, Van.State.RETURNING, Van.State.RESCUE]):
				return
			v.boost_until = now + Abilities.FLOOR_IT_MIN
			notice.emit("%s floors it!" % v.code, "combo")
		"rush_sort":
			if c.sorting.is_empty():
				return
			var n := c.sorting.size()
			for p in c.sorting:
				p.set_stage(Parcel.Stage.SORTED, now)
				c.waiting.append(p)
			c.sorting.clear()
			notice.emit("Sort crew sprints: %d parcels ready to load" % n, "combo")
		"call_ahead":
			call_ahead_left += Abilities.CALL_AHEAD_DROPS
			notice.emit("Calling ahead: the next %d customers will be home" % call_ahead_left, "combo")
		"green_wave":
			green_wave_until = maxf(green_wave_until, now) + Abilities.GREEN_WAVE_MIN
			notice.emit("Green wave! Every light turns green for your vehicles", "combo")
		"sweet_talk":
			var n := 0
			var lists: Array = [c.sorting, c.waiting]
			for v in c.vans:
				lists.append(v.cargo)
			for list in lists:
				for p in list:
					if not p.late and p.deadline > now:
						p.deadline += Abilities.SWEET_TALK_MIN
						n += 1
			if n == 0:
				return
			notice.emit("You sweet-talked %d customers into waiting a bit longer" % n, "combo")
	hustle -= cost
	event.emit("ability", {"ability": id})


func _gain_hustle(amount: int) -> void:
	hustle = mini(hustle + amount, hustle_cap())


# ---------------------------------------------------------------- staff and calls

func _roll_applicants(p: Company) -> void:
	applicants = []
	var exclude: Array = p.staff.map(func(st): return st["role"])
	for k in Staff.APPLICANTS:
		var a := Staff.applicant(rng, exclude)
		exclude.append(a["role"])
		applicants.append(a)


func _call_van(states: Array, worn := false) -> Van:
	var pool: Array = []
	for v in companies[PLAYER].vans:
		if v.state in states and (not worn or v.condition < 0.6):
			pool.append(v)
	return pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


## The phone rings: pick a call that makes sense right now and stop the clock.
func _ring_call(now: float) -> void:
	var m := minute_of_day()
	next_call_at = now + rng.randf_range(Calls.GAP[0], Calls.GAP[1])
	var p := companies[PLAYER]
	if m < Calls.FIRST or m > Calls.LAST or p.vans.is_empty():
		return
	var road := [Van.State.EN_ROUTE, Van.State.RETURNING]
	var options: Array = []
	for cid in Calls.ORDER:
		var needs: String = Calls.get_call(cid).get("needs", "")
		var ok := true
		match needs:
			"van_on_road":
				ok = _call_van(road) != null
			"van_worn":
				ok = _call_van(road, true) != null
			"late_today":
				ok = p.counters.get("late", 0) > 0
		if ok:
			options.append(cid)
	var id: String = options[rng.randi_range(0, options.size() - 1)]
	var v: Van = null
	match Calls.get_call(id).get("needs", ""):
		"van_on_road":
			v = _call_van(road)
		"van_worn":
			v = _call_van(road, true)
		_:
			v = p.vans[rng.randi_range(0, p.vans.size() - 1)]
	var district := rng.randi_range(0, 3)
	pending_call = {"id": id, "van": v.id, "district": district, "ctx": {
		"van": v.code, "driver": v.driver.name, "district": City.DISTRICT_NAMES[district], "cond": int(v.condition * 100)}}
	event.emit("call", pending_call)


func _answer_call(c: Company, i: int, now: float) -> void:
	var id: String = pending_call["id"]
	var opts: Array = Calls.get_call(id)["options"]
	if i < 0 or i >= opts.size():
		return
	var cost := Calls.cost(id, i)
	if c.money < cost:
		return
	if cost > 0.0:
		c.add_money(-cost, "events")
	var v := _find_van(c, pending_call["van"])
	var d: int = pending_call["district"]
	var result := ""
	match id + ":" + str(i):
		"rush_drop:0":
			var p := _new_parcel(c, rng.randi_range(0, city.houses.size() - 1), now)
			c.sorting.erase(p)
			p.set_stage(Parcel.Stage.SORTED, now)
			c.waiting.append(p)
			p.kind = Parcel.Kind.EXPRESS
			p.weight = snappedf(rng.randf_range(1.0, 6.0), 0.1)
			p.pay_amount = 45.0
			p.deadline = now + 45.0
			result = "An express parcel for %s is waiting at the depot." % city.houses[p.house]["address"]
		"flat_tire:0", "flat_tire:1":
			if v:
				v.hold_until = now + (20.0 if i == 0 else 5.0)
			result = "%s is back on the road in %d min." % [v.code if v else "The van", 20 if i == 0 else 5]
		"rattle:0":
			if v:
				v.hold_until = now + 15.0
				v.condition = minf(1.0, v.condition + 0.15)
			result = "A loose heat shield, tightened. Condition +15%."
		"complaint:0":
			score[d][PLAYER] = clampf(score[d][PLAYER] + 0.05, 0.0, 1.0)
			result = "The customer calms down."
		"complaint:1":
			share[d] = clampf(share[d] - 0.04, 0.1, 0.9)
			result = "Word gets around %s. Walk-in share -4%%." % City.DISTRICT_NAMES[d]
		"sick:0":
			if v:
				v.driver.change_mood(20.0)
			result = "A temp covers the shift."
		"sick:1":
			if v:
				v.driver.change_mood(-25.0)
			result = "They stay, grumbling."
		"fuel_sale:0":
			fuel_sale_until = now + 180.0
			result = "Fuel is half price until %s." % clock(fuel_sale_until)
		"bulk:0":
			var open: Array = c.vendors_unlocked.keys()
			open.sort()
			var j := _make_job(open[rng.randi_range(0, open.size() - 1)], now)
			j.pay = roundf(j.pay * 1.5)
			j.express = true
			j.promise = 75.0
			j.state = Job.State.PACKING
			j.timer = Vendors.get_vendor(j.vendor)["prep"]
			c.jobs.append(j)
			result = "%s is packing a %d-stop order worth $%d." % [Vendors.get_vendor(j.vendor)["name"], j.stops(), int(j.pay)]
			event.emit("job_taken", {"job": j})
		"poach:0":
			if v:
				v.driver.change_mood(15.0)
			result = "They're staying."
		"poach:1":
			if v and rng.randf() < 0.4:
				var old := v.driver.name
				v.driver = Driver.generate(rng, day())
				result = "%s left for Zoomer. %s takes over %s." % [old, v.driver.name, v.code]
			else:
				result = "They decided to stay after all."
		"radio:0":
			for k in 4:
				share[k] = clampf(share[k] + 0.03, 0.1, 0.9)
			result = "The ad runs during the traffic report."
		"thanks:0":
			c.add_money(25.0, "tips")
			for van in c.vans:
				van.driver.change_mood(5.0)
			result = "The crew is chuffed."
		_:
			result = "Nothing happens."
	var answered := pending_call.duplicate(true)
	answered["choice"] = i
	answered["result"] = result
	pending_call = {}
	notice.emit(result, "info")
	event.emit("call_answered", answered)


## Morning dilemma from Events. Effects that roll dice use sim.rng.
func _start_day_type(p: Company) -> void:
	today_type = tomorrow_type if tomorrow_type != "" else "normal"
	tomorrow_type = ""
	if not season_on():
		today_type = "normal"
		return
	if day() % Season.WEEK_DAYS == 0:
		today_type = "boss"
	match today_type:
		"boss":
			contract_offers = [Bosses.make(rng, week_boss, day(), maxi(1, p.vans.size()))]
		"rush":
			demand_boost = 1.5
		"quiet":
			demand_boost = 0.6
			for v in p.vans:
				v.condition = minf(1.0, v.condition + 0.15)
				v.driver.change_mood(10.0)
		"mystery":
			var picks := Cards.roll(rng, 1, 0, p.perks, not p.vans.is_empty(), 0, true)
			if not picks.is_empty():
				var target := p.vans[0]
				for v in p.vans:
					if v.mods.size() < target.mods.size():
						target = v
				_apply_card(p, picks[0], target.id)


func _roll_event() -> void:
	morning_event = {}
	if not season_on() or day() < 2 or today_type == "boss":
		return
	if today_type != "mystery" and rng.randf() > 0.35:
		return
	var id: String = Events.ORDER[rng.randi_range(0, Events.ORDER.size() - 1)]
	morning_event = {"id": id, "done": false, "result": ""}


func _resolve_event(c: Company, i: int) -> void:
	var id: String = morning_event["id"]
	var opts: Array = Events.get_event(id)["options"]
	if i < 0 or i >= opts.size():
		return
	var cost := Events.cost(id, i, c.vans.size())
	if c.money < cost:
		return
	c.add_money(-cost, "events")
	var result := ""
	match id + ":" + str(i):
		"used_van:0":
			if c.vans.size() < c.fleet_cap():
				var v := _add_van(c, &"van")
				v.condition = 0.35
				run_stats["max_fleet"] = maxi(run_stats["max_fleet"], c.vans.size())
				result = "%s joins the team in a rattly van." % v.driver.name
			else:
				c.add_money(cost, "events")
				result = "No room in the fleet. Del shrugs and leaves."
		"raise:0":
			for v in c.vans:
				v.driver.change_mood(20.0)
			result = "The crew cheers."
		"raise:1":
			for v in c.vans:
				v.driver.change_mood(8.0)
			result = "Pizza helps. A little."
		"raise:2":
			for v in c.vans:
				v.driver.change_mood(-15.0)
			result = "Grumbling in the break room."
		"influencer:0":
			if rng.randf() < 0.5:
				for d in 4:
					share[d] = clampf(share[d] + 0.06, 0.1, 0.9)
				result = "The video blows up! Walk-in share +6%."
			else:
				for d in 4:
					share[d] = clampf(share[d] - 0.04, 0.1, 0.9)
				result = "The blooper reel is all anyone talks about. Share -4%."
		"card_trader:0", "card_trader:1":
			var picks := Cards.roll(rng, 1, 0, c.perks, true, 2 if i == 0 else 0, season_on())
			if picks.is_empty():
				c.add_money(cost, "events")
				result = "The binder is empty."
			else:
				var target := c.vans[0]
				for v in c.vans:
					if v.mods.size() < target.mods.size():
						target = v
				_apply_card(c, picks[0], target.id)
				result = "You got %s%s." % [Cards.get_card(picks[0])["name"], (" for " + target.code) if Cards.is_vehicle(picks[0]) else ""]
		"nephew:0":
			lease_debt -= roundf(Season.LEASES[Season.week_of(day())] * 0.15)
			result = "He's mostly harmless. Rent is cheaper this week."
		"open_day:0":
			for v in c.vans:
				if v.state in [Van.State.IDLE, Van.State.LOADING]:
					v.condition = maxf(v.condition, 0.9)
			result = "Everything purrs."
		"mall_sale:0":
			demand_boost = 1.3
			result = "Flyers everywhere. Expect a busy day."
		"zoomer_offer:0":
			var worst: Van = null
			for v in c.vans:
				if v.state == Van.State.IDLE and v.cargo.is_empty() and (worst == null or v.condition < worst.condition):
					worst = v
			if worst == null or c.vans.size() <= 1:
				result = "Nothing parked to sell."
			else:
				c.vans.erase(worst)
				c.add_money(VehicleTypes.DATA[worst.type]["cost"] * 0.9, "vehicles")
				van_removed.emit(worst)
				result = "Sold %s to Zoomer for %s." % [worst.code, "$%d" % int(VehicleTypes.DATA[worst.type]["cost"] * 0.9)]
		"gambler:0":
			if rng.randf() < 0.5:
				c.add_money(2.0 * cost, "events")
				result = "Heads! You win $100."
			else:
				result = "Tails. There goes $100."
		"coach:0":
			hustle = hustle_cap()
			result = "You feel unstoppable. Hustle full."
		"horseshoe:0":
			streak += 5
			run_stats["best_streak"] = maxi(run_stats["best_streak"], streak)
			result = "Your streak is now %d." % streak
		_:
			result = "Nothing happens."
	morning_event["done"] = true
	morning_event["choice"] = i
	morning_event["result"] = result
	event.emit("event_resolved", morning_event)


func _nearest_neighbor(list: Array, start: int) -> Array[Parcel]:
	var ordered: Array[Parcel] = []
	var remaining := list.duplicate()
	var at := start
	while not remaining.is_empty():
		var best := 0
		var best_d := INF
		for i in remaining.size():
			var d := city.manhattan(at, city.houses[remaining[i].house]["curb"])
			if remaining[i].kind == Parcel.Kind.EXPRESS:
				d *= 0.6
			if remaining[i].window_start > 0.0:
				d += 1000.0
			if d < best_d:
				best_d = d
				best = i
		var p: Parcel = remaining[best]
		remaining.remove_at(best)
		ordered.append(p)
		at = city.houses[p.house]["curb"]
	return ordered


func _depart(c: Company, v: Van, now: float, from_node: int) -> void:
	if not v.manual_order:
		v.cargo = _nearest_neighbor(v.cargo, from_node)
	v.manual_order = false
	v.node = from_node
	v.route_total = v.cargo.size()
	v.wait = 0.0
	v.ready = false
	for p in v.cargo:
		p.set_stage(Parcel.Stage.OUT, now)
	if c.id == PLAYER:
		var hand := Combos.evaluate(city, v.cargo, v, c)
		v.route_mult = hand["mult"]
		v.route_hits = hand["hits"].map(func(h): return h["name"])
		v.route_base = 0.0
		v.route_clean = true
		if v.route_mult > 1.0:
			notice.emit("%s heads out holding %s (x%.1f)" % [v.code, " + ".join(v.route_hits), v.route_mult], "combo")
	_go_to_next(c, v)
	event.emit("van_departed", {"van": v})


func _go_to_next(c: Company, v: Van) -> void:
	if v.cargo.is_empty() and c.id == PLAYER and v.route_total > 0:
		_cash_route(c, v)
	if v.cargo.is_empty():
		v.target_node = c.depot_node
		v.set_path(city.path(v.node, c.depot_node))
		v.state = Van.State.RETURNING
	else:
		v.target_node = city.houses[v.cargo[0].house]["curb"]
		v.set_path(city.path(v.node, v.target_node))
		v.state = Van.State.EN_ROUTE


## End of a route: a clean run pays its combo bonus, a late parcel busts it.
func _cash_route(c: Company, v: Van) -> void:
	if v.route_mult > 1.0 and v.route_base > 0.0:
		if v.route_clean:
			var bonus := v.route_base * (v.route_mult - 1.0)
			if v.route_hits.size() >= 3 and c.has_perk_fx("combo_double"):
				bonus *= 2.0
			bonus = roundf(bonus)
			c.add_money(bonus, "combos", v)
			c.revenue_today += bonus
			c.lifetime_revenue += bonus
			c.count("revenue", bonus)
			run_stats["best_combo"] = maxf(run_stats["best_combo"], v.route_mult)
			run_stats["combo_cash"] += bonus
			notice.emit("%s CLEAN RUN: $%d x%.1f = +$%d bonus" % [v.code, int(v.route_base), v.route_mult, int(bonus)], "combo")
			event.emit("route_combo", {"van": v, "bonus": bonus, "mult": v.route_mult, "hits": v.route_hits.duplicate()})
			_check_level(c)
		else:
			notice.emit("%s's x%.1f hand busted by a late parcel" % [v.code, v.route_mult], "bad")
			event.emit("route_bust", {"van": v})
	_reset_route(v)


func _reset_route(v: Van) -> void:
	v.route_mult = 1.0
	v.route_hits = []
	v.route_base = 0.0
	v.route_clean = true


func _not_home(c: Company, v: Van, p: Parcel) -> void:
	p.attempts += 1
	v.returns.append(p)
	_mood(v, -1.0)
	if c.id == PLAYER:
		c.count("not_home")
		notice.emit("Nobody home at %s (home %s). The parcel rides back to the depot for another try." % [city.houses[p.house]["address"], p.window_text()], "info")
		if not c.has_perk_fx("streak_guard"):
			_break_streak(c, "not_home")
	event.emit("not_home", {"parcel": p, "van": v})


func _deliver(c: Company, v: Van, p: Parcel, now: float) -> void:
	var already_flagged := p.late
	p.late = already_flagged or now > p.deadline
	p.set_stage(Parcel.Stage.DELIVERED, now)
	var base := p.pay()
	if p.kind == Parcel.Kind.EXPRESS:
		base *= v.fx("express_pay")
	if c.id == PLAYER and today_type == "rush":
		base *= 1.25
	var pay := base * ((0.3 + (c.perk_add("late_pay_add") if c.id == PLAYER else 0.0)) if p.late else 1.0)
	var booked := false
	if c.id == PLAYER:
		if p.late:
			v.route_clean = false
			_break_streak(c, "late")
			var fine := 0.0
			if boss_rule() == "mayor":
				pay = 0.0
			if twist == "inspector":
				fine = 10.0
			if boss_rule() == "streamqueen":
				fine = 15.0
			fine *= c.perk("fine")
			if fine > 0.0:
				pay = 0.0
				c.add_money(-fine, "fines", v)
				pay = -fine
			else:
				c.add_money(pay, "deliveries", v)
			booked = true
		else:
			v.route_base += pay
			_gain_hustle(1 + int(c.perk_add("hustle_per_drop")))
			var plain := pay
			var mult := streak_mult()
			var tip := _bump_streak(c)
			if v.driver.has(&"chatty"):
				tip += 3.0                     # customers love a chat
			if c.has_perk_fx("golden_ticket") and (c.ontime_total + 1) % 10 == 0:
				tip += 40.0
				notice.emit("Golden ticket! +$40", "streak")
			c.add_money(plain, "deliveries", v)
			if mult > 1.0:
				c.add_money(plain * (mult - 1.0), "streak", v)
			if tip > 0.0:
				c.add_money(tip, "tips", v)
			pay = plain * mult + tip
			booked = true
	if not booked:
		c.add_money(pay, "deliveries", v)
	p.paid = pay
	c.revenue_today += pay
	c.lifetime_revenue += pay
	c.delivered_today += 1
	c.delivered_total += 1
	if not p.late:
		c.ontime_today += 1
		c.ontime_total += 1
	if c.id == PLAYER:
		c.count("late" if p.late else "ontime")
		c.count("revenue", pay)
		if p.vendor >= 0:
			c.count("vendor")
		if p.kind == Parcel.Kind.EXPRESS and not p.late:
			c.count("express")
		if p.heavy():
			c.count("heavy")
		c.count("district_%d" % p.district)
		if not c.contract.is_empty() and not c.contract_done and Contracts.is_done(c.contract, c.counters):
			c.contract_done = true
			notice.emit("Contract complete: %s" % Contracts.describe(c.contract), "good")
			event.emit("contract_done", {})
	var d := v.driver
	d.delivered_today += 1
	d.delivered_total += 1
	d.learn(p.district, c.perk("learn"))
	if p.late:
		d.late_total += 1
		_mood(v, -2.0)
	else:
		_mood(v, 0.4)
	if not already_flagged:
		var result := 0.0
		if not p.late:
			var window := maxf(1.0, p.deadline - p.stage_times[Parcel.Stage.PLACED])
			result = 0.6 + 0.4 * clampf((p.deadline - now) / window, 0.0, 1.0)
		_bump_score(p.district, c.id, result, 0.0)
	active.erase(p)
	recent.push_front(p)
	if recent.size() > 60:
		recent.pop_back()
	parcel_delivered.emit(p, v, pay)
	event.emit("delivered", {"parcel": p, "van": v})
	_check_level(c)


func _check_level(c: Company) -> void:
	if c.is_ai:
		return
	var nxt := c.next_level_info()
	if nxt.is_empty() or c.lifetime_revenue < nxt["revenue"]:
		return
	c.level += 1
	notice.emit("Level up! You're now %s. Unlocked: %s" % [nxt["name"], ", ".join(Vendors.level_unlocks(c.level))], "good")
	event.emit("level_up", {"level": c.level})


# ---------------------------------------------------------------- route estimates

## Predicts arrival times for a stop order: [{parcel, arrive, status}], plus return time.
## status: "ok", "late", or "early" (nobody home yet).
func estimate_route(v: Van, order: Array, start_node: int, start_time: float) -> Dictionary:
	var spd: float = Van.BASE_SPEED * v.spec()["speed"] * v.fx("speed") * (v.fx("gps") if order.size() >= 5 else 1.0) \
		* v.driver.speed_mult(fmod(start_time, 1440.0)) * (0.85 + 0.15 * v.condition) * traffic_for(v.company) \
		* companies[v.company].perk("fleet_speed")
	var t := start_time
	var at := start_node
	var stops: Array = []
	for p in order:
		var curb: int = city.houses[p.house]["curb"]
		t += city.road_dist(at, curb) / spd * MIN_PER_TICK
		var status := "ok"
		if p.window_start > 0.0 and t < p.window_start:
			status = "early"
		elif t > p.deadline:
			status = "late"
		stops.append({"parcel": p, "arrive": t, "status": status})
		t += stop_minutes(v, p)
		at = curb
	var back: float = t + city.road_dist(at, companies[v.company].depot_node) / spd * MIN_PER_TICK
	return {"stops": stops, "return": back}


# ---------------------------------------------------------------- wear, breakdowns, garage

func _wear_and_maybe_break(c: Company, v: Van, now: float) -> bool:
	var dist := v.pos.distance_to(v.prev_pos)
	v.condition = maxf(0.0, v.condition - dist * Van.WEAR_PER_UNIT * v.spec()["wear"] * v.fx("wear") * v.driver.wear_mult())
	var worn := 1.0 - v.condition
	var p := BREAK_BASE * worn * worn * (0.4 if v.driver.has(&"gearhead") else 1.0) * v.fx("break") \
		* (1.5 if weather == 1 else 1.0)
	if c.id == PLAYER:
		if twist == "heatwave":
			p *= 1.6
		if heat() >= 7:
			p *= 1.5
	if rng.randf() < p:
		_break_down(c, v, now)
		return true
	return false


func _break_down(c: Company, v: Van, _now: float) -> void:
	v.state = Van.State.BROKEN
	v.timer = TOW_WAIT * (0.5 if c.has_perk_fx("tow") else 1.0)
	v.breakdowns += 1
	_mood(v, -8.0)
	if c.id == PLAYER:
		c.count("breakdowns")
	var where := "on the road"
	var closest := city.astar.get_closest_point(v.pos)
	for h in city.houses:
		if h["curb"] == closest:
			where = "near " + h["address"]
			break
	if c.is_ai:
		notice.emit("Zoomer's %s broke down. Their parcels are stuck." % v.code, "rival")
	else:
		var bill := TOW_COST * (0.0 if c.has_perk_fx("tow") else 1.0) + REPAIR_COST * c.perk("shop_cost")
		var why := "worn to %d%% condition" % int(v.condition * 100)
		if v.cargo.is_empty():
			notice.emit("%s broke down %s (%s). Tow + repair will cost about %s." % [v.code, where, why, "$%d" % int(bill)], "bad")
		else:
			notice.emit("%s broke down %s (%s) with %d parcels! Send a rescue before the tow takes them back. Tow + repair about %s." % [v.code, where, why, v.cargo.size(), "$%d" % int(bill)], "bad")
	event.emit("breakdown", {"van": v})


func _start_tow(c: Company, v: Van, now: float) -> void:
	if not c.has_perk_fx("tow"):
		c.add_money(-TOW_COST, "tows", v)
		if not c.is_ai:
			notice.emit("Tow truck hauls %s to Gearbox Garage: -$%d" % [v.code, int(TOW_COST)], "bad")
	if not c.is_ai and not v.cargo.is_empty():
		notice.emit("The tow brings %s's %d parcels back to the depot to be sent again" % [v.code, v.cargo.size()], "info")
	# The tow crew brings any parcels still aboard back to the depot.
	for p in v.cargo:
		p.set_stage(Parcel.Stage.SORTED, now)
		p.van_code = ""
		c.waiting.append(p)
	for p in v.returns:
		p.set_stage(Parcel.Stage.SORTED, now)
		p.van_code = ""
		c.waiting.append(p)
	v.cargo.clear()
	v.returns.clear()
	v.route_total = 0
	_reset_route(v)
	var closest := city.astar.get_closest_point(v.pos)
	var p := PackedVector3Array([v.pos])
	p.append_array(city.path(closest, city.garage["node"]))
	v.set_path(p)
	v.state = Van.State.TOWING
	event.emit("tow", {"van": v})


func _send_to_shop(c: Company, v: Van) -> void:
	v.set_path(city.path(c.depot_node, city.garage["node"]))
	v.state = Van.State.TO_SHOP
	v.ready = false


func _arrive_shop(c: Company, v: Van, reason: String) -> void:
	v.node = city.garage["node"]
	v.state = Van.State.AT_SHOP
	v.shop_reason = reason
	v.shop_waiting = true
	if c.has_perk_fx("front_of_line"):
		garage_queue.push_front(v)
	else:
		garage_queue.append(v)


func _step_garage(_now: float) -> void:
	while garage_working.size() < GARAGE_BAYS and not garage_queue.is_empty():
		var v: Van = garage_queue.pop_front()
		var c := companies[v.company]
		v.shop_waiting = false
		v.shop_timer = (REPAIR_MIN if v.shop_reason == "repair" else SERVICE_MIN) * c.perk("shop_time")
		garage_working.append(v)
	var i := 0
	while i < garage_working.size():
		var v := garage_working[i]
		v.shop_timer -= MIN_PER_TICK
		if v.shop_timer <= 0.0:
			garage_working.remove_at(i)
			var c := companies[v.company]
			var bill: float = (REPAIR_COST if v.shop_reason == "repair" else SERVICE_COST) * c.perk("shop_cost")
			c.add_money(-bill, "repairs" if v.shop_reason == "repair" else "services", v)
			v.condition = 0.95 if v.shop_reason == "repair" else 1.0
			v.set_path(city.path(city.garage["node"], c.depot_node))
			v.state = Van.State.RETURNING
			if not c.is_ai:
				notice.emit("%s %s: -$%d. Condition back to %d%%, heading to the depot" % [v.code, "repaired" if v.shop_reason == "repair" else "serviced", int(bill), int(v.condition * 100)], "good")
		else:
			i += 1


func garage_position(v: Van) -> int:
	return garage_queue.find(v)


# ---------------------------------------------------------------- numbers for the UI

const TICKS_PER_HOUR := 60.0 / MIN_PER_TICK


func fuel_mult(c: Company, v: Van) -> float:
	var sale := 0.5 if c.id == PLAYER and minutes() < fuel_sale_until else 1.0
	return v.spec()["fuel"] * v.fx("fuel") * c.perk("fuel") * sale


## Hourly running costs and wear for a vehicle, at normal traffic.
func running_costs(v: Van) -> Dictionary:
	var c := companies[v.company]
	var wage_drive := Van.WAGE_PER_MIN * 60.0 * c.perk("wage")
	var units: float = Van.BASE_SPEED * v.spec()["speed"] * v.fx("speed") * TICKS_PER_HOUR
	var fuel: float = units * Van.FUEL_PER_UNIT * fuel_mult(c, v)
	return {
		"wage_drive": wage_drive, "wage_parked": wage_drive * 0.25, "fuel": fuel,
		"drive": wage_drive + fuel, "wear": units * Van.WEAR_PER_UNIT * v.spec()["wear"] * v.fx("wear") * v.driver.wear_mult(),
	}


## Chance of breaking down during one hour of driving (0..1).
func breakdown_risk(v: Van, condition := -1.0) -> float:
	var worn := 1.0 - (v.condition if condition < 0.0 else condition)
	var p := BREAK_BASE * worn * worn * (0.4 if v.driver.has(&"gearhead") else 1.0) * v.fx("break") * (1.5 if weather == 1 else 1.0)
	if v.company == PLAYER:
		if twist == "heatwave":
			p *= 1.6
		if heat() >= 7:
			p *= 1.5
	return 1.0 - pow(1.0 - p, TICKS_PER_HOUR)


## Minutes a drop-off takes for this vehicle and parcel.
func stop_minutes(v: Van, p: Parcel) -> float:
	return Van.STOP_MINUTES * v.spec()["stop"] * v.fx("stop") * v.driver.stop_mult(p.district) \
		* (1.6 if p.signature else 1.0) * (1.15 if weather == 2 else 1.0)


## "Bay 1 of 2", or the queue position and who is ahead.
func garage_status(v: Van) -> String:
	if garage_working.has(v):
		return "in a bay, %d min left" % ceili(v.shop_timer)
	var i := garage_queue.find(v)
	if i < 0:
		return ""
	var ahead: Array = []
	for k in i:
		ahead.append(garage_queue[k].code)
	return "%s in line for %d bays%s" % [["1st", "2nd", "3rd", "4th", "5th"][mini(i, 4)], GARAGE_BAYS,
		(", behind " + ", ".join(ahead)) if not ahead.is_empty() else ""]


func _pay_costs(c: Company) -> void:
	for v in c.vans:
		var wage := Van.WAGE_PER_MIN * (0.25 if v.state in [Van.State.IDLE, Van.State.AT_SHOP] else 1.0) * c.perk("wage")
		c.add_money(-wage * MIN_PER_TICK, "wages", v)
		if v.state != Van.State.TOWING:
			var burn := v.pos.distance_to(v.prev_pos) * Van.FUEL_PER_UNIT * fuel_mult(c, v)
			if burn > 0.0:
				c.add_money(-burn, "fuel", v)


func _bump_score(district: int, cid: int, result: float, bonus: float) -> void:
	var s: float = score[district][cid]
	s = s * 0.92 + result * 0.08 + bonus
	score[district][cid] = clampf(s, 0.0, 1.0)


func _update_reputation(now: float) -> void:
	for p in active:
		if not p.late and now > p.deadline:
			p.late = true
			_bump_score(p.district, p.company, 0.0, 0.0)
	for d in 4:
		var diff: float = score[d][PLAYER] - score[d][RIVAL]
		share[d] = clampf(share[d] + diff * 0.025, 0.1, 0.75)


func _check_new_day() -> void:
	var dnow := day()
	if dnow == last_day:
		return
	last_day = dnow
	for c in companies:
		c.ontime_yesterday = c.ontime_rate_today()
		c.delivered_today = 0
		c.ontime_today = 0
		c.revenue_today = 0.0
		c.money_start_of_day = c.money
		for v in c.vans:
			v.driver.delivered_today = 0
	event.emit("day_started", {"day": dnow})


# ---------------------------------------------------------------- queries

func player() -> Company:
	return companies[PLAYER]


func rival() -> Company:
	return companies[RIVAL]


func total_share() -> float:
	var s := 0.0
	for d in 4:
		s += share[d]
	return s / 4.0


func eta_minutes(v: Van) -> float:
	var spd := _van_speed(v)
	if v.state == Van.State.TOWING:
		spd = Van.BASE_SPEED * 0.75
	if spd <= 0.0:
		return 0.0
	return v.remaining_distance() / spd * MIN_PER_TICK


func job_eta_minutes(j: Job) -> float:
	if j.state == Job.State.PACKING:
		return j.timer + j.remaining_distance() / COURIER_SPEED * MIN_PER_TICK
	return j.remaining_distance() / COURIER_SPEED * MIN_PER_TICK


func house(id: int) -> Dictionary:
	return city.houses[id]


## Best vehicle at the depot to send on a rescue (most free space).
func best_rescuer(c: Company) -> Van:
	var best: Van = null
	for v in c.vans:
		if v.state in [Van.State.IDLE, Van.State.LOADING]:
			if best == null or (v.slots - v.cargo.size()) > (best.slots - best.cargo.size()):
				best = v
	return best
