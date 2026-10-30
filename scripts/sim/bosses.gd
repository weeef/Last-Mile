class_name Bosses
extends RefCounted
## Boss clients: every rent day a named client takes over the day. Their rule is
## in force all day whether you take their contract or not; beat their contract
## and you pick one of two relics (rule-breaking cards you only get this way).
## The week's boss is rolled on its first morning so the briefing can warn you.

const DATA := {
	"henderson": {"client": "Mrs. Henderson", "title": "The Estate Sale", "kind": "ontime", "base": 12.0,
		"rule": "Every parcel needs a signature today. Drops take longer."},
	"techcorp": {"client": "TechCorp", "title": "Launch Day", "kind": "express", "base": 5.0,
		"rule": "Half of your walk-in orders are express."},
	"mayor": {"client": "The Mayor", "title": "The Gala", "kind": "clean", "base": 8.0,
		"rule": "Late parcels pay nothing today."},
	"rossi": {"client": "Chef Rossi", "title": "Market Morning", "kind": "district", "base": 7.0,
		"rule": "Every promise is 20% shorter."},
	"streamqueen": {"client": "StreamQueen", "title": "Live Unboxing", "kind": "streak", "base": 8.0,
		"rule": "Late parcels cost a $15 fine. Chat is watching."},
	"bulkbarn": {"client": "Bulk Barn", "title": "Pallet Day", "kind": "revenue", "base": 260.0,
		"rule": "Walk-in parcels are three times heavier."},
}
const ORDER := ["henderson", "techcorp", "mayor", "rossi", "streamqueen", "bulkbarn"]


static func get_boss(id: String) -> Dictionary:
	return DATA[id]


## The boss contract for today, shaped like a normal contract (see Contracts).
static func make(rng: RandomNumberGenerator, id: String, day: int, fleet: int) -> Dictionary:
	var b: Dictionary = DATA[id]
	var scale := 1.25 * (0.8 + 0.2 * fleet) * (1.0 + 0.12 * (day - 1))
	var c := {"kind": b["kind"], "tier": 2, "target": 0, "district": -1, "boss": id}
	if b["kind"] == "revenue":
		c["target"] = int(round(b["base"] * scale / 10.0)) * 10
	else:
		c["target"] = maxi(1, int(round(b["base"] * scale)))
	if b["kind"] == "district":
		c["district"] = rng.randi_range(0, 3)
	c["reward"] = roundf(300.0 * (1.0 + 0.15 * (day - 1)))
	return c
