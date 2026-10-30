class_name Company
extends RefCounted
## A delivery company. The player and AI rivals are both companies and
## both act only through Sim.submit() commands.

var id := 0
var name := ""
var short := ""
var depot_name := ""
var color := Color.WHITE
var is_ai := false
var depot_node := 0
var money := 0.0
var vans: Array[Van] = []
var sorting: Array[Parcel] = []
var waiting: Array[Parcel] = []

# Progression
var level := 1
var lifetime_revenue := 0.0
var vendors_unlocked := {}        # vendor index -> true
var jobs: Array[Job] = []         # offered + taken jobs (player only)

# Rules
var auto_dispatch := false        # if false, vans wait as "Ready" until you start them
var dispatch_threshold := 0.75
var max_wait := 20.0
var auto_service := 0.0           # send idle vans to the mechanic below this condition (0 = off)

# Stats
var delivered_today := 0
var ontime_today := 0
var delivered_total := 0
var ontime_total := 0
var ontime_yesterday := -1.0
var money_start_of_day := 0.0
var revenue_today := 0.0

# Roguelike layer
var perks: Array[StringName] = []
var contract := {}               # today's chosen contract
var contract_done := false
var counters := {}               # today's tallies for contracts and the report
var stars_total := 0


func perk(key: String, default := 1.0) -> float:
	var m := default
	for id in perks:
		var f: Dictionary = Cards.DATA[id]["fx"]
		if f.has(key):
			if key == "promise_add":
				m += f[key]
			else:
				m *= f[key]
	return m


## Sum of an additive perk key (streak_cap, streak_floor, interest_cap).
func perk_add(key: String) -> float:
	var total := 0.0
	for id in perks:
		var f: Dictionary = Cards.DATA[id]["fx"]
		if f.has(key):
			total += f[key]
	return total


func has_perk_fx(key: String) -> bool:
	for id in perks:
		if Cards.DATA[id]["fx"].has(key):
			return true
	return false


func count(key: String, amount := 1.0) -> void:
	counters[key] = counters.get(key, 0) + amount


func level_info() -> Dictionary:
	return Vendors.LEVELS[level - 1]


func next_level_info() -> Dictionary:
	if level >= Vendors.LEVELS.size():
		return {}
	return Vendors.LEVELS[level]


func fleet_cap() -> int:
	return level_info()["fleet"]


func ontime_rate_today() -> float:
	if delivered_today == 0:
		return -1.0
	return float(ontime_today) / float(delivered_today)


func ontime_rate_total() -> float:
	if delivered_total == 0:
		return 1.0
	return float(ontime_total) / float(delivered_total)


func count_state(states: Array) -> int:
	var n := 0
	for v in vans:
		if v.state in states:
			n += 1
	return n


func vans_out() -> int:
	return count_state([Van.State.EN_ROUTE, Van.State.DELIVERING, Van.State.RETURNING])


func express_waiting() -> int:
	var n := 0
	for p in waiting:
		if p.kind == Parcel.Kind.EXPRESS:
			n += 1
	for p in sorting:
		if p.kind == Parcel.Kind.EXPRESS:
			n += 1
	return n


func backlog() -> int:
	return waiting.size() + sorting.size()


func offers() -> Array[Job]:
	var out: Array[Job] = []
	for j in jobs:
		if j.state == Job.State.OFFERED:
			out.append(j)
	return out


func active_jobs() -> Array[Job]:
	var out: Array[Job] = []
	for j in jobs:
		if j.state == Job.State.PACKING or j.state == Job.State.INBOUND:
			out.append(j)
	return out
