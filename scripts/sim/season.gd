class_name Season
extends RefCounted
## The roguelike run. A season is 12 days split into four 3-day weeks. The depot
## lease is due on the last evening of every week; miss it and you get a final
## notice (debt + late fee), miss it again and you're evicted. Each due day has a
## telegraphed twist, and day 12 is Holiday Peak: double demand on top of the twist.
##
## A run is configured by a plain dictionary (saved with the game):
##   {"id": int, "charter": String, "heat": int, "daily": bool, "hq": {upgrade: level}}
## An empty dictionary means classic endless mode (no lease, no run end).

const DAYS := 12
const WEEK_DAYS := 3
const LEASES := [350.0, 800.0, 1500.0, 2400.0]   # due on day 3, 6, 9, 12
const LATE_FEE := 1.2                              # carried debt grows 20%
const PEAK_DEMAND := 2.0

# ---------------------------------------------------------------- streaks
const STREAK_STEP := 0.04          # pay bonus per on-time delivery in a row
const STREAK_CAP := 25             # x2.0 at 25
const STREAK_TIERS := [5, 10, 15, 20, 25, 30, 40]
const STREAK_NAMES := {5: "Warming up", 10: "On a roll", 15: "Hot hands", 20: "On fire", 25: "Unstoppable", 30: "Legendary", 40: "Mythical"}

# ---------------------------------------------------------------- twists
const TWISTS := {
	"gridlock": {"name": "Gridlock", "desc": "A burst water main snarls the grid. Roads 25% slower all day."},
	"heatwave": {"name": "Heatwave", "desc": "Drivers wilt and engines overheat. Moods drain twice as fast, breakdowns x1.6."},
	"inspector": {"name": "Inspector Visit", "desc": "The council is watching. Late parcels pay nothing and cost a $10 fine."},
	"blitz": {"name": "Zoomer Blitz", "desc": "Zoomer slashes prices. You get 40% fewer walk-in orders."},
	"viral": {"name": "Viral Unboxing", "desc": "A video goes viral. Demand x1.6 and more of it is express."},
	"tight": {"name": "Tight Promises", "desc": "Customers want it now. Every new promise is 30% shorter."},
}
const TWIST_ORDER := ["gridlock", "heatwave", "inspector", "blitz", "viral", "tight"]

# ---------------------------------------------------------------- charters
## Starting companies. "fleet" fixes the starting vehicles (otherwise you pick two).
const CHARTERS := {
	"courier": {"name": "Corner Courier", "unlock": 0, "cash": 250.0,
		"desc": "The classic start. Pick any two vehicles and $250 in the till.",
		"perk": "No strings attached."},
	"green": {"name": "Green Courier", "unlock": 20, "cash": 150.0, "mods_each": [&"eco_tune"], "share": 0.05,
		"desc": "Every starting vehicle has an Eco Tune. Locals love you: +5% walk-in share.",
		"perk": "Only $150 to start."},
	"budget": {"name": "Budget Freight", "unlock": 25, "cash": 700.0, "lease": 1.25, "mood": 50.0,
		"desc": "Cheap and cheerful. $700 to start.",
		"perk": "Leases +25%, and your drivers start grumpy."},
	"premium": {"name": "Premium Express", "unlock": 35, "cash": 250.0, "fleet": [&"sprinter", &"van"], "walkin_pay": 1.35, "promise": 0.8,
		"desc": "White-glove service. Start with a Sprinter. Walk-ins pay +35%.",
		"perk": "Every promise is 20% tighter."},
	"haulers": {"name": "Heavy Haulers", "unlock": 40, "cash": 200.0, "fleet": [&"box", &"van"], "mods_last": [&"liftgate_kit"], "vendors": [2], "share": -0.05,
		"desc": "Box truck, a van with a liftgate, and Oak & Iron already on your board.",
		"perk": "Fewer walk-ins: -5% share."},
}
const CHARTER_ORDER := ["courier", "green", "budget", "premium", "haulers"]

# ---------------------------------------------------------------- heat
## Difficulty ladder. Winning at heat N unlocks heat N+1. Effects stack.
const HEAT := [
	"Standard season.",
	"Leases +15%.",
	"Zoomer starts with 2 extra vans.",
	"One fewer card in every draft.",
	"No final notice: miss a lease and you're out.",
	"Twists also hit the middle day of every week.",
	"Every promise is 15% tighter.",
	"Breakdowns +50%.",
	"Leases +25% more. Good luck.",
]
const MAX_HEAT := 8
const DAILY_HEAT := 2


static func week_of(day: int) -> int:
	return clampi((day - 1) / WEEK_DAYS, 0, LEASES.size() - 1)


static func due_day(day: int) -> int:
	return (week_of(day) + 1) * WEEK_DAYS


static func charter(id: String) -> Dictionary:
	return CHARTERS.get(id, CHARTERS["courier"])


static func twist_name(id: String) -> String:
	return TWISTS[id]["name"] if TWISTS.has(id) else ""


static func streak_tier_name(streak: int) -> String:
	var out := ""
	for t in STREAK_TIERS:
		if streak >= t:
			out = STREAK_NAMES[t]
	return out


## Daily run: the same seed and charter for everyone on a given date.
static func daily_number() -> int:
	var d := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": d["month"], "day": d["day"]}) / 86400)


static func daily_seed(day_number: int) -> int:
	return 7919 * day_number + 104729


static func daily_charter(day_number: int) -> String:
	return CHARTER_ORDER[day_number % CHARTER_ORDER.size()]


## Final run score and the HQ reputation it earns.
static func score(r: Dictionary) -> int:
	var s := float(r.get("revenue", 0.0))
	s += 40.0 * r.get("stars", 0) + 15.0 * r.get("best_streak", 0) + 250.0 * r.get("leases_paid", 0) + 200.0 * r.get("best_combo", 0.0)
	if r.get("won", false):
		s += 1000.0
	return int(round(s * (1.0 + 0.15 * r.get("heat", 0))))


static func rep_earned(r: Dictionary) -> int:
	var rep: float = float(r.get("stars", 0)) + 4.0 * r.get("leases_paid", 0) + int(r.get("best_streak", 0) / 5)
	if r.get("won", false):
		rep += 15.0
	if r.get("daily", false):
		rep += 5.0
	return int(round(rep * (1.0 + 0.2 * r.get("heat", 0))))
