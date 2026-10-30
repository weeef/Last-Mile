class_name Abilities
extends RefCounted
## Dispatcher powers: what you DO during the day instead of watching. Every
## on-time drop earns 1 hustle (capped, so it's use-it-or-lose-it). Spend it on
## these. All of them are sim commands, so they replay deterministically.

const BASE_CAP := 10
const DATA := {
	"floor_it": {"name": "Floor It", "key": "Z", "cost": 2, "target": true,
		"desc": "The selected vehicle drives 60% faster for 40 min."},
	"rush_sort": {"name": "Rush the Line", "key": "X", "cost": 2,
		"desc": "Every parcel still being sorted is ready to load right now."},
	"call_ahead": {"name": "Call Ahead", "key": "C", "cost": 3,
		"desc": "Your next 5 drops find somebody home, whatever the time."},
	"green_wave": {"name": "Green Wave", "key": "V", "cost": 4,
		"desc": "60 min of green lights: your vehicles ignore rush hour, gridlock and weather, +10% speed."},
	"sweet_talk": {"name": "Sweet Talk", "key": "B", "cost": 5,
		"desc": "Phone every waiting customer: +40 min on every promise not yet late."},
}
const ORDER := ["floor_it", "rush_sort", "call_ahead", "green_wave", "sweet_talk"]
const FLOOR_IT_MIN := 40.0
const FLOOR_IT_MULT := 1.6
const GREEN_WAVE_MIN := 60.0
const CALL_AHEAD_DROPS := 5
const SWEET_TALK_MIN := 40.0
