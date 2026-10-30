class_name Vendors
extends RefCounted
## Shops around town that post delivery jobs. Better vendors pack faster and pay more.

const LIST := [
	{"name": "Corner Pantry", "kind": "Groceries", "unlock": 0.0, "level": 1, "prep": 30.0,
		"kg": [4.0, 14.0], "heavy": 0.0, "mult": 1.0, "express": 0.0, "color": Color("7d9b62")},
	{"name": "Sunrise Bakery", "kind": "Bread & cakes", "unlock": 400.0, "level": 1, "prep": 18.0,
		"kg": [1.0, 5.0], "heavy": 0.0, "mult": 1.15, "express": 0.5, "color": Color("d39a4f")},
	{"name": "Oak & Iron", "kind": "Furniture", "unlock": 900.0, "level": 2, "prep": 40.0,
		"kg": [45.0, 120.0], "heavy": 1.0, "mult": 1.0, "express": 0.0, "color": Color("9a6b4f")},
	{"name": "Bloom & Co.", "kind": "Flowers", "unlock": 1200.0, "level": 2, "prep": 12.0,
		"kg": [1.0, 4.0], "heavy": 0.0, "mult": 1.35, "express": 0.8, "color": Color("c2718f")},
	{"name": "Byte Electronics", "kind": "Gadgets", "unlock": 2500.0, "level": 3, "prep": 10.0,
		"kg": [2.0, 25.0], "heavy": 0.15, "mult": 1.5, "express": 0.3, "color": Color("5f86b8")},
	{"name": "Pharma Plus", "kind": "Pharmacy", "unlock": 4000.0, "level": 4, "prep": 5.0,
		"kg": [0.5, 3.0], "heavy": 0.0, "mult": 1.7, "express": 1.0, "color": Color("4f9e92")},
]

const HEAVY_KG := 40.0   # anything heavier needs a liftgate (box truck)

const LEVELS := [
	{"name": "Corner Courier", "revenue": 0.0, "fleet": 3},
	{"name": "Neighborhood Service", "revenue": 2500.0, "fleet": 5},
	{"name": "Town Logistics", "revenue": 8000.0, "fleet": 8},
	{"name": "City Express", "revenue": 20000.0, "fleet": 12},
]


static func count() -> int:
	return LIST.size()


static func get_vendor(i: int) -> Dictionary:
	return LIST[i]
