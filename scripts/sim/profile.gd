class_name Profile
extends RefCounted
## Everything that survives between runs: reputation (the meta currency), HQ
## upgrades, unlocked charters and heat, goals, records, daily-run streak and a
## short run history. Stored in user://profile.dat, separate from the save slots.

const PATH := "user://profile.dat"
const VERSION := 1
const HISTORY := 12

## Permanent HQ upgrades bought with reputation. cost[i] buys level i + 1.
const UPGRADES := {
	"till": {"name": "Bigger Till", "desc": "+$100 starting cash per level.", "cost": [10, 20, 35]},
	"landlord": {"name": "Friendly Landlord", "desc": "Leases 8% cheaper per level.", "cost": [15, 30]},
	"dice": {"name": "Lucky Dice", "desc": "Your first reroll every evening is free.", "cost": [20]},
	"scout": {"name": "Talent Scout", "desc": "Start every run with a free Uncommon-or-better card.", "cost": [25]},
	"hype": {"name": "Hype Crew", "desc": "Streaks build faster: +5% pay per step instead of +4%.", "cost": [30]},
	"grace": {"name": "Second Chances", "desc": "One extra final notice before eviction.", "cost": [30]},
	"shark": {"name": "Card Shark", "desc": "One more card in every evening draft.", "cost": [45]},
}
const UPGRADE_ORDER := ["till", "landlord", "dice", "scout", "hype", "grace", "shark"]

## One-off goals. Each pays reputation the first time.
const GOALS := [
	{"id": "lease1", "name": "Rent day", "desc": "Pay your first lease.", "rep": 5},
	{"id": "stars3", "name": "Gold star", "desc": "Finish a day with 3 stars.", "rep": 5},
	{"id": "streak10", "name": "On a roll", "desc": "Reach a 10 delivery streak.", "rep": 5},
	{"id": "day40", "name": "Busy bee", "desc": "Deliver 40 parcels in one day.", "rep": 6},
	{"id": "fleet4", "name": "Fleet manager", "desc": "Run 4 vehicles at once.", "rep": 6},
	{"id": "week3", "name": "Two thirds there", "desc": "Pay the day 9 lease.", "rep": 8},
	{"id": "streak25", "name": "Unstoppable", "desc": "Reach a 25 delivery streak.", "rep": 10},
	{"id": "daily", "name": "Daily driver", "desc": "Finish a daily run.", "rep": 5},
	{"id": "win", "name": "Season survivor", "desc": "Survive a whole season.", "rep": 15},
	{"id": "day80", "name": "Parcel storm", "desc": "Deliver 80 parcels in one day.", "rep": 12},
	{"id": "fleet7", "name": "Small empire", "desc": "Run 7 vehicles at once.", "rep": 12},
	{"id": "heat3", "name": "Feeling the heat", "desc": "Win a season at heat 3 or higher.", "rep": 20},
	{"id": "charters3", "name": "Franchise", "desc": "Win with 3 different charters.", "rep": 25},
	{"id": "heat6", "name": "Furnace", "desc": "Win a season at heat 6 or higher.", "rep": 30},
	{"id": "heat8", "name": "Last Mile legend", "desc": "Win a season at heat 8.", "rep": 50},
]

var rep := 0
var rep_lifetime := 0
var upgrades := {}                 # id -> level
var charters := {"courier": true}  # unlocked charter ids
var max_heat := 0                  # highest heat you may pick
var goals := {}                    # goal id -> true
var wins_by_charter := {}          # charter id -> wins
var runs := 0
var wins := 0
var best_score := 0
var best_streak := 0
var best_day := 0
var daily_streak := 0
var daily_last := -1               # day number of the last daily run started
var daily_best := {}               # day number -> best score
var history: Array = []            # newest first: run result dictionaries


static func load_or_new() -> Profile:
	var p := Profile.new()
	if not FileAccess.file_exists(PATH):
		return p
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return p
	var d = f.get_var()
	f.close()
	if not d is Dictionary:
		return p
	for k in ["rep", "rep_lifetime", "max_heat", "runs", "wins", "best_score", "best_streak", "best_day", "daily_streak", "daily_last"]:
		if d.has(k):
			p.set(k, int(d[k]))
	for k in ["upgrades", "charters", "goals", "wins_by_charter", "daily_best"]:
		if d.has(k) and d[k] is Dictionary:
			p.set(k, d[k])
	if d.has("history") and d["history"] is Array:
		p.history = d["history"]
	p.charters["courier"] = true
	return p


func save() -> bool:
	var d := {"version": VERSION}
	for k in ["rep", "rep_lifetime", "max_heat", "runs", "wins", "best_score", "best_streak", "best_day", "daily_streak",
			"daily_last", "upgrades", "charters", "goals", "wins_by_charter", "daily_best", "history"]:
		d[k] = get(k)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	f.close()
	return true


# ------------------------------------------------------------- HQ

func level(id: String) -> int:
	return int(upgrades.get(id, 0))


func next_cost(id: String) -> int:
	var costs: Array = UPGRADES[id]["cost"]
	var l := level(id)
	return costs[l] if l < costs.size() else -1


func buy_upgrade(id: String) -> bool:
	var c := next_cost(id)
	if c < 0 or rep < c:
		return false
	rep -= c
	upgrades[id] = level(id) + 1
	save()
	return true


func unlock_charter(id: String) -> bool:
	var c: int = Season.charter(id)["unlock"]
	if charters.has(id) or rep < c:
		return false
	rep -= c
	charters[id] = true
	save()
	return true


## The run config for a new season (or today's daily run).
func make_run(charter_id: String, heat: int, daily := false) -> Dictionary:
	return {
		"id": int(Time.get_unix_time_from_system()) * 1000 + randi() % 1000,
		"charter": charter_id,
		"heat": heat,
		"daily": daily,
		"hq": {} if daily else upgrades.duplicate(),   # daily runs are a level playing field
	}


## Call when a daily run starts: keeps the "days in a row" streak.
func mark_daily(day_number: int) -> void:
	if daily_last == day_number:
		return
	daily_streak = daily_streak + 1 if daily_last == day_number - 1 else 1
	daily_last = day_number
	save()


func played_daily_today() -> bool:
	return daily_last == Season.daily_number()


# ------------------------------------------------------------- results

## Records a finished run once. Returns what changed, for the summary screen.
func record_run(r: Dictionary) -> Dictionary:
	for h in history:
		if h.get("id", -1) == r.get("id", -2):
			return {"duplicate": true, "rep": 0, "goals": [], "heat_unlocked": -1, "new_best": false}
	var out := {"rep": 0, "goals": [], "heat_unlocked": -1, "new_best": false}
	var gained := Season.rep_earned(r)
	runs += 1
	if r.get("won", false):
		wins += 1
		var ch: String = r.get("charter", "courier")
		wins_by_charter[ch] = int(wins_by_charter.get(ch, 0)) + 1
		var h: int = r.get("heat", 0)
		if not r.get("daily", false) and h >= max_heat and max_heat < Season.MAX_HEAT:
			max_heat = h + 1
			out["heat_unlocked"] = max_heat
	var sc: int = r.get("score", 0)
	if sc > best_score:
		best_score = sc
		out["new_best"] = true
	best_streak = maxi(best_streak, r.get("best_streak", 0))
	best_day = maxi(best_day, r.get("best_day", 0))
	if r.get("daily", false):
		var dn: int = r.get("daily_number", -1)
		if sc > int(daily_best.get(dn, 0)):
			daily_best[dn] = sc
	for g in GOALS:
		if not goals.has(g["id"]) and _goal_met(g["id"], r):
			goals[g["id"]] = true
			gained += int(g["rep"])
			out["goals"].append(g)
	rep += gained
	rep_lifetime += gained
	out["rep"] = gained
	history.push_front(r)
	while history.size() > HISTORY:
		history.pop_back()
	save()
	return out


func _goal_met(id: String, r: Dictionary) -> bool:
	var won: bool = r.get("won", false)
	match id:
		"lease1":
			return r.get("leases_paid", 0) >= 1
		"stars3":
			return r.get("three_star_days", 0) >= 1
		"streak10":
			return r.get("best_streak", 0) >= 10
		"streak25":
			return r.get("best_streak", 0) >= 25
		"day40":
			return r.get("best_day", 0) >= 40
		"day80":
			return r.get("best_day", 0) >= 80
		"fleet4":
			return r.get("max_fleet", 0) >= 4
		"fleet7":
			return r.get("max_fleet", 0) >= 7
		"week3":
			return r.get("leases_paid", 0) >= 3
		"daily":
			return r.get("daily", false)
		"win":
			return won
		"heat3":
			return won and r.get("heat", 0) >= 3
		"heat6":
			return won and r.get("heat", 0) >= 6
		"heat8":
			return won and r.get("heat", 0) >= 8
		"charters3":
			return wins_by_charter.size() >= 3
	return false


## The next few goals you haven't done yet (shown as a teaser).
func open_goals(n := 3) -> Array:
	var out: Array = []
	for g in GOALS:
		if not goals.has(g["id"]):
			out.append(g)
			if out.size() >= n:
				break
	return out


## The cheapest thing you can't afford yet, so the title can say "12 rep to go".
func next_unlock_hint() -> String:
	var best := ""
	var best_cost := 1 << 30
	for id in Season.CHARTER_ORDER:
		var c: int = Season.charter(id)["unlock"]
		if not charters.has(id) and c > rep and c < best_cost:
			best_cost = c
			best = "the %s charter" % Season.charter(id)["name"]
	for id in UPGRADE_ORDER:
		var c := next_cost(id)
		if c > rep and c < best_cost:
			best_cost = c
			best = UPGRADES[id]["name"]
	if best == "":
		return ""
	return "%d rep to %s" % [best_cost - rep, best]
