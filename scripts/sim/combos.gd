class_name Combos
extends RefCounted
## Route "hands". The parcels a vehicle leaves with are scored like a poker hand:
## each combo adds to a route multiplier. If the whole route comes back with no
## late parcels (a clean run), the on-time pay from that route is paid again
## times (mult - 1) as a bonus. Bigger, tidier loads score more, but every extra
## stop is another chance to be late and bust the hand.
##
## Card fx keys (company perks, additive): combo_full, combo_sweep, combo_street,
## combo_all (every route), and the flag combo_double (3+ combos: bonus doubled).

const DATA := {
	"full": {"name": "Full Truck", "desc": "Every slot or the weight limit used.", "mult": 0.3},
	"sweep": {"name": "Sweep", "desc": "3+ stops, all in one district.", "mult": 0.4},
	"street": {"name": "Neighbors", "desc": "+0.05 for each extra stop on a street you already visit (up to +0.3).", "mult": 0.05},
	"haul": {"name": "Big Haul", "desc": "8+ stops.", "mult": 0.2},
	"mega": {"name": "Mega Haul", "desc": "12+ stops.", "mult": 0.4},
	"express": {"name": "Express Run", "desc": "2+ stops, every one express.", "mult": 0.3},
	"mixed": {"name": "Mixed Bag", "desc": "Express, standard, vendor and walk-in parcels together.", "mult": 0.25},
	"signed": {"name": "Signed & Sealed", "desc": "3+ parcels that need a signature.", "mult": 0.2},
}
const ORDER := ["full", "sweep", "street", "mega", "haul", "express", "mixed", "signed"]
const STREET_CAP := 0.3


## Scores a load. Returns {"mult": float, "hits": [{"id", "name", "add"}]}.
static func evaluate(city: City, cargo: Array, v: Van, c: Company) -> Dictionary:
	var hits: Array = []
	var n := cargo.size()
	if n == 0:
		return {"mult": 1.0, "hits": hits}
	var districts := {}
	var streets := {}
	var express := 0
	var vendor := 0
	var signed := 0
	for p in cargo:
		var h: Dictionary = city.houses[p.house]
		districts[p.district] = true
		streets[h["street"]] = int(streets.get(h["street"], 0)) + 1
		if p.kind == Parcel.Kind.EXPRESS:
			express += 1
		if p.vendor >= 0:
			vendor += 1
		if p.signature:
			signed += 1
	if n >= v.slots or v.load_kg() >= v.max_kg * 0.95:
		hits.append(_hit("full", DATA["full"]["mult"] + c.perk_add("combo_full")))
	if n >= 3 and districts.size() == 1:
		hits.append(_hit("sweep", DATA["sweep"]["mult"] + c.perk_add("combo_sweep")))
	var extra := 0
	for s in streets.keys():
		extra += int(streets[s]) - 1
	if extra > 0:
		var per: float = DATA["street"]["mult"] + c.perk_add("combo_street")
		hits.append(_hit("street", minf(per * extra, STREET_CAP + c.perk_add("combo_street") * 6.0), " x%d" % extra))
	if n >= 12:
		hits.append(_hit("mega", DATA["mega"]["mult"]))
	elif n >= 8:
		hits.append(_hit("haul", DATA["haul"]["mult"]))
	if n >= 2 and express == n:
		hits.append(_hit("express", DATA["express"]["mult"]))
	if express > 0 and express < n and vendor > 0 and vendor < n:
		hits.append(_hit("mixed", DATA["mixed"]["mult"]))
	if signed >= 3:
		hits.append(_hit("signed", DATA["signed"]["mult"]))
	var mult := 1.0
	for hit in hits:
		mult += hit["add"]
	var all_bonus := c.perk_add("combo_all")
	if all_bonus > 0.0:
		mult += all_bonus
	mult = 1.0 + (mult - 1.0) * c.perk("combo_scale")   # Double-Decker relic
	return {"mult": mult, "hits": hits}


static func _hit(id: String, add: float, suffix := "") -> Dictionary:
	return {"id": id, "name": DATA[id]["name"] + suffix, "add": add}


static func describe(result: Dictionary) -> String:
	var parts: Array = []
	for hit in result["hits"]:
		parts.append("%s +%.1f" % [hit["name"], hit["add"]])
	if parts.is_empty():
		return "No combo"
	return " · ".join(parts)
