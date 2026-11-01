class_name Staff
extends RefCounted
## Depot staff you can hire. Each role gives a company-wide perk (the same fx
## keys as cards, see Cards) for a daily wage paid every evening. A few new
## applicants turn up every morning; how many staff you can keep depends on
## your business level.

const DATA := {
	"mechanic": {"role": "Mechanic", "wage": 70.0, "icon": "gear",
		"desc": "Services and repairs 30% cheaper and 40% quicker. Parked vehicles regain 2% condition an hour.",
		"fx": {"shop_cost": 0.7, "shop_time": 0.6, "depot_repair": 0.02}},
	"sorter": {"role": "Sort Lead", "wage": 55.0, "icon": "sort",
		"desc": "Parcels sort in half the time and load 30% faster.",
		"fx": {"sort": 0.5, "load": 0.7}},
	"dispatcher": {"role": "Dispatcher", "wage": 65.0, "icon": "clock",
		"desc": "+4 max hustle, and every day starts with 4 hustle.",
		"fx": {"hustle_cap": 4.0, "hustle_morning": 4.0}},
	"accountant": {"role": "Accountant", "wage": 60.0, "icon": "coins",
		"desc": "Fuel 10% cheaper, and nightly savings interest can go $25 higher.",
		"fx": {"fuel": 0.9, "interest_cap": 25.0}},
	"marketer": {"role": "Marketer", "wage": 80.0, "icon": "chart",
		"desc": "+5% chance that every walk-in order picks you.",
		"fx": {"share_bonus": 0.05}},
	"coach": {"role": "Driving Coach", "wage": 55.0, "icon": "people",
		"desc": "Drivers learn districts twice as fast, and their mood drops 30% slower.",
		"fx": {"learn": 2.0, "mood_drain": 0.7}},
	"rep": {"role": "Customer Rep", "wage": 60.0, "icon": "doc",
		"desc": "Calls ahead for your first 3 drops each day (somebody's home), and every promise gets +10 min.",
		"fx": {"call_ahead_morning": 3.0, "promise_add": 10.0}},
	"lawyer": {"role": "Lawyer", "wage": 90.0, "icon": "check",
		"desc": "Late drops pay 50% instead of 30%, and fines are halved.",
		"fx": {"late_pay_add": 0.2, "fine": 0.5}},
}
const ORDER := ["mechanic", "sorter", "dispatcher", "accountant", "marketer", "coach", "rep", "lawyer"]
const SLOTS := [1, 2, 3, 4]            # staff you can keep at business level 1..4
const APPLICANTS := 3


static func get_role(id: String) -> Dictionary:
	return DATA[id]


static func slots(level: int) -> int:
	return SLOTS[clampi(level - 1, 0, SLOTS.size() - 1)]


## A fresh applicant: {"role", "name", "wage"}; the wage varies a little.
static func applicant(rng: RandomNumberGenerator, exclude: Array) -> Dictionary:
	var pool: Array = ORDER.filter(func(r): return not exclude.has(r))
	if pool.is_empty():
		pool = ORDER.duplicate()
	var role: String = pool[rng.randi_range(0, pool.size() - 1)]
	var name := "%s %s" % [Traits.FIRST_NAMES[rng.randi_range(0, Traits.FIRST_NAMES.size() - 1)],
		Traits.LAST_NAMES[rng.randi_range(0, Traits.LAST_NAMES.size() - 1)]]
	var wage := roundf(float(DATA[role]["wage"]) * rng.randf_range(0.85, 1.2) / 5.0) * 5.0
	return {"role": role, "name": name, "wage": wage}
