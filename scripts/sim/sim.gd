class_name Sim
extends RefCounted
## Deterministic, fixed-tick simulation. No nodes, no frame time, one seeded RNG.
## Every change from a player or an AI goes through submit() as a command, so the
## same seed + the same commands at the same ticks always replay identically.
##
## A day has phases: MORNING (briefing, clock stopped) -> DAY (07:00-21:00) ->
## EVENING (report + card draft, clock stopped) -> NIGHT (fast-forwarded) -> MORNING.

signal parcel_delivered(parcel: Parcel, van: Van, pay: float)
signal van_added(van: Van)
signal van_removed(van: Van)
signal notice(text: String, kind: String)
signal event(name: String, data: Dictionary)

enum Phase { MORNING, DAY, EVENING, NIGHT }
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


func setup(p_seed: int, start_fleet: Array) -> void:
	seed_value = p_seed
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
	for i in 3:
		var v := _add_van(r, &"van")
		v.condition = rng.randf_range(0.75, 0.9)
	for d in 4:
		score.append([0.7, 0.8])
	rival_ai = RivalAI.new(self, RIVAL)
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
	return (14.0 + 6.0 * (day() - 1)) * hour_curve(minute_of_day() / 60.0) * w


func is_rush_hour() -> bool:
	var h := minute_of_day() / 60.0
	return (h >= 7.5 and h < 9.0) or (h >= 16.5 and h < 18.0)


func traffic_mult() -> float:
	var m := 0.78 if is_rush_hour() else 1.0
	if weather == 1:
		m *= 0.88
	elif weather == 2:
		m *= 0.92
	return m


## True while the clock should run (day or the fast-forwarded night).
func clock_running() -> bool:
	return phase == Phase.DAY or phase == Phase.NIGHT


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
				if c.money >= spec["cost"] and c.vans.size() < c.fleet_cap() and c.level >= spec["level"]:
					c.money -= spec["cost"]
					var v := _add_van(c, t)
					v.condition = rng.randf_range(0.8, 0.95)
					if c.is_ai:
						notice.emit("Zoomer Express added %s to their fleet" % v.code, "rival")
					else:
						notice.emit("%s joins the team, driving %s" % [v.driver.name, v.code], "good")
					event.emit("van_bought", {"van": v})
			"starter_fleet":
				if c.vans.is_empty():
					for t in cmd["vehicles"]:
						var v := _add_van(c, t)
						v.condition = rng.randf_range(0.68, 0.78)
					_begin_morning(true)
					event.emit("fleet_ready", {})
			"sell_van":
				var v := _find_van(c, cmd["van"])
				if v and v.state == Van.State.IDLE and v.cargo.is_empty() and c.vans.size() > 1:
					c.vans.erase(v)
					c.money += VehicleTypes.DATA[v.type]["cost"] * 0.4
					van_removed.emit(v)
					if c.is_ai:
						notice.emit("Zoomer Express sold %s to cut costs" % v.code, "rival")
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
					c.money -= vd["unlock"]
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
				if phase == Phase.EVENING and c.id == PLAYER:
					var i: int = cmd["index"]
					if i >= 0 and i < draft.size():
						_apply_card(c, draft[i], cmd.get("van", -1))
					_begin_night()
			"skip_card":
				if phase == Phase.EVENING and c.id == PLAYER:
					c.money += 40.0
					_begin_night()
			"reroll_draft":
				if phase == Phase.EVENING and c.id == PLAYER:
					var cost := REROLL_COST * (draft_rerolls + 1)
					if c.money >= cost:
						c.money -= cost
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
	var tier: Dictionary = Contracts.TIERS[p.contract.get("tier", 0)] if done else {"draft_count": 3, "boost": 0, "min_rarity": 0}
	var reward: float = p.contract.get("reward", 0.0) if done else 0.0
	if done:
		p.money += reward
	report = {
		"day": day(), "delivered": total, "ontime": ontime, "late": late, "rate": rate,
		"revenue": p.revenue_today, "net": p.money - p.money_start_of_day,
		"contract": p.contract.duplicate(), "contract_done": done, "reward": reward, "stars": stars,
		"draft_count": tier["draft_count"] + (1 if stars == 3 else 0), "boost": tier["boost"], "min_rarity": tier["min_rarity"],
		"failed_attempts": p.counters.get("not_home", 0), "breakdowns": p.counters.get("breakdowns", 0),
	}
	draft_rerolls = 0
	_roll_draft(p, report["draft_count"], report["boost"], report["min_rarity"])
	city.set_closures([])
	event.emit("evening", report)


func _roll_draft(p: Company, n: int, boost: int, min_rarity: int) -> void:
	draft = Cards.roll(rng, n, boost, p.perks, not p.vans.is_empty(), min_rarity)


func _begin_night() -> void:
	phase = Phase.NIGHT
	draft = []
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
	var cid := PLAYER if rng.randf() < share[d] else RIVAL
	var c := companies[cid]
	var p := _new_parcel(c, hid, now)
	p.kind = Parcel.Kind.EXPRESS if rng.randf() < 0.2 else Parcel.Kind.STANDARD
	p.weight = snappedf(rng.randf_range(0.5, 8.0), 0.1)
	p.pay_amount = 18.0 if p.kind == Parcel.Kind.EXPRESS else 11.0
	p.deadline = now + (75.0 if p.kind == Parcel.Kind.EXPRESS else 180.0)
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
	j.promise = 60.0 if rush else (90.0 if j.express else 200.0)
	# Pay: a base fee, plus per stop, per kilogram and for distance from the depot.
	var avg_dist := dist_sum / stops
	var raw := 10.0 + stops * 6.0 + j.total_kg * 0.32 + avg_dist * 0.12 * stops
	if j.needs_liftgate():
		raw += 25.0
	if j.express:
		raw *= 1.3
	if rush:
		raw *= 1.8
	j.pay = roundf(raw * vd["mult"] * 0.85 * companies[PLAYER].perk("job_pay"))
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
		p.deadline = now + j.promise
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
	v.driver.change_mood(delta)


func _step_van(c: Company, v: Van, now: float) -> void:
	v.prev_pos = v.pos
	match v.state:
		Van.State.IDLE:
			_mood(v, 0.012)
			v.ready = false
			if c.auto_service > 0.0 and v.condition < c.auto_service:
				_send_to_shop(c, v)
			elif v.auto_fill and _has_loadable(c, v):
				v.state = Van.State.LOADING
				v.timer = Van.LOAD_MINUTES * v.driver.load_mult()
		Van.State.LOADING:
			v.timer -= MIN_PER_TICK
			if v.timer <= 0.0 and v.auto_fill:
				var p := _pop_loadable(c, v)
				if p:
					p.set_stage(Parcel.Stage.LOADED, now)
					p.van_code = v.code
					v.cargo.append(p)
					v.timer = Van.LOAD_MINUTES * v.driver.load_mult()
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
				v.timer = Van.STOP_MINUTES * v.spec()["stop"] * v.fx("stop") * v.driver.stop_mult(p.district) * (1.6 if p.signature else 1.0)
		Van.State.DELIVERING:
			v.timer -= MIN_PER_TICK
			if v.timer <= 0.0:
				var p: Parcel = v.cargo.pop_front()
				if p.window_start > 0.0 and now < p.window_start:
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
	return Van.BASE_SPEED * v.spec()["speed"] * v.fx("speed") * gps * v.driver.speed_mult(minute_of_day()) \
		* cond_mult * traffic_mult()


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
	_go_to_next(c, v)
	event.emit("van_departed", {"van": v})


func _go_to_next(c: Company, v: Van) -> void:
	if v.cargo.is_empty():
		v.target_node = c.depot_node
		v.set_path(city.path(v.node, c.depot_node))
		v.state = Van.State.RETURNING
	else:
		v.target_node = city.houses[v.cargo[0].house]["curb"]
		v.set_path(city.path(v.node, v.target_node))
		v.state = Van.State.EN_ROUTE


func _not_home(c: Company, v: Van, p: Parcel) -> void:
	p.attempts += 1
	v.returns.append(p)
	_mood(v, -1.0)
	if c.id == PLAYER:
		c.count("not_home")
	event.emit("not_home", {"parcel": p, "van": v})


func _deliver(c: Company, v: Van, p: Parcel, now: float) -> void:
	var already_flagged := p.late
	p.late = already_flagged or now > p.deadline
	p.set_stage(Parcel.Stage.DELIVERED, now)
	var base := p.pay()
	if p.kind == Parcel.Kind.EXPRESS:
		base *= v.fx("express_pay")
	var pay := base * (0.3 if p.late else 1.0)
	c.money += pay
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
	d.learn(p.district)
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
		var bonus := 0.01 if (d.has(&"chatty") and not p.late) else 0.0
		_bump_score(p.district, c.id, result, bonus)
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
	notice.emit("Level up! You're now %s. Fleet cap %d." % [nxt["name"], nxt["fleet"]], "good")
	event.emit("level_up", {"level": c.level})


# ---------------------------------------------------------------- route estimates

## Predicts arrival times for a stop order: [{parcel, arrive, status}], plus return time.
## status: "ok", "late", or "early" (nobody home yet).
func estimate_route(v: Van, order: Array, start_node: int, start_time: float) -> Dictionary:
	var spd: float = Van.BASE_SPEED * v.spec()["speed"] * v.fx("speed") * (v.fx("gps") if order.size() >= 5 else 1.0) \
		* v.driver.speed_mult(fmod(start_time, 1440.0)) * (0.85 + 0.15 * v.condition) * traffic_mult()
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
		t += Van.STOP_MINUTES * v.spec()["stop"] * v.fx("stop") * v.driver.stop_mult(p.district) * (1.6 if p.signature else 1.0)
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
		if v.cargo.is_empty():
			notice.emit("%s broke down %s. Tow truck on the way." % [v.code, where], "bad")
		else:
			notice.emit("%s broke down %s with %d parcels! Send a rescue or wait for the tow." % [v.code, where, v.cargo.size()], "bad")
	event.emit("breakdown", {"van": v})


func _start_tow(c: Company, v: Van, now: float) -> void:
	if not c.has_perk_fx("tow"):
		c.money -= TOW_COST
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
	var closest := city.astar.get_closest_point(v.pos)
	var p := PackedVector3Array([v.pos])
	p.append_array(city.path(closest, city.garage["node"]))
	v.set_path(p)
	v.state = Van.State.TOWING


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
			c.money -= (REPAIR_COST if v.shop_reason == "repair" else SERVICE_COST) * c.perk("shop_cost")
			v.condition = 0.95 if v.shop_reason == "repair" else 1.0
			v.set_path(city.path(city.garage["node"], c.depot_node))
			v.state = Van.State.RETURNING
			if not c.is_ai:
				notice.emit("%s is fixed up and heading back to the depot" % v.code, "good")
		else:
			i += 1


func garage_position(v: Van) -> int:
	return garage_queue.find(v)


func _pay_costs(c: Company) -> void:
	for v in c.vans:
		var wage := Van.WAGE_PER_MIN * (0.25 if v.state in [Van.State.IDLE, Van.State.AT_SHOP] else 1.0)
		c.money -= wage * MIN_PER_TICK
		if v.state != Van.State.TOWING:
			c.money -= v.pos.distance_to(v.prev_pos) * Van.FUEL_PER_UNIT * v.spec()["fuel"] * v.fx("fuel") * c.perk("fuel")


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
