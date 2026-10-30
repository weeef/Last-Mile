class_name VehicleTypes
extends RefCounted
## Vehicle classes. Each one is a different tool, not just a bigger number.

const DATA := {
	&"van": {
		"name": "Delivery Van", "short": "VAN", "cost": 1100.0, "level": 1,
		"speed": 1.0, "slots": 10, "kg": 300.0, "stop": 1.0, "wear": 1.0, "fuel": 1.0, "heavy": false, "mod_slots": 2,
		"desc": "The all-rounder. Decent speed, decent space.",
	},
	&"box": {
		"name": "Box Truck", "short": "BOX", "cost": 1800.0, "level": 1,
		"speed": 0.78, "slots": 16, "kg": 900.0, "stop": 1.25, "wear": 1.3, "fuel": 1.7, "heavy": true, "mod_slots": 3,
		"desc": "Slow and thirsty, but has a liftgate. The only thing that can haul furniture.",
	},
	&"sprinter": {
		"name": "Sprinter Van", "short": "SPR", "cost": 1400.0, "level": 2,
		"speed": 1.2, "slots": 8, "kg": 180.0, "stop": 0.85, "wear": 0.8, "fuel": 0.85, "heavy": false, "mod_slots": 2,
		"desc": "Quick and nimble. Great for express, light loads only.",
	},
}

const ORDER := [&"van", &"box", &"sprinter"]
const START_CHOICES := [&"van", &"box"]


static func get_data(t: StringName) -> Dictionary:
	return DATA[t]
