class_name Van
extends Mover
## A delivery vehicle (van, box truck or sprinter) and its state machine.

enum State { IDLE, LOADING, EN_ROUTE, DELIVERING, RETURNING, BROKEN, TOWING, TO_SHOP, AT_SHOP, RESCUE }
const STATE_NAMES := ["Parked", "Loading", "En route", "Dropping off", "Returning",
	"Broken down", "Being towed", "To mechanic", "In the shop", "Rescue run"]

const BASE_SPEED := 0.55        # world units per tick
const LOAD_MINUTES := 0.5       # per parcel
const STOP_MINUTES := 1.6       # per drop-off
const WAGE_PER_MIN := 0.55
const FUEL_PER_UNIT := 0.03
const WEAR_PER_UNIT := 0.00008

var id := 0
var number := 0
var company := 0
var code := ""
var type := &"van"
var driver: Driver
var slots := 10
var max_kg := 300.0
var state := State.IDLE
var cargo: Array[Parcel] = []   # cargo[0] is the next stop
var route_total := 0
var node := 0
var target_node := 0
var timer := 0.0
var wait := 0.0
var ready := false              # loaded and waiting for a start order

# Wear and repairs
var condition := 0.8            # 1 = brand new, 0 = falling apart
var breakdowns := 0
var shop_reason := ""           # "repair" or "service"
var shop_waiting := false
var shop_timer := 0.0

# Player control + roguelike mods
var mods: Array[StringName] = []    # installed vehicle cards
var manual_order := false            # route order set by the player
var auto_fill := true                # keep loading automatically at the depot
var returns: Array[Parcel] = []      # "nobody home" parcels riding back to the depot
var rescue_target := -1              # van id we're driving to rescue

# Route hand (see Combos) and dispatcher boosts
var route_mult := 1.0                # combo multiplier for the current route
var route_hits: Array = []           # combo names, for the UI
var route_base := 0.0                # on-time pay earned so far on this route
var route_clean := true              # no late parcels yet on this route
var boost_until := -1.0              # Floor It: faster until this minute


func mod_slots() -> int:
	return spec()["mod_slots"]


func fx(key: String, default := 1.0) -> float:
	var m := default
	for id in mods:
		var f: Dictionary = Cards.DATA[id]["fx"]
		if f.has(key):
			if key == "slots":
				m += f[key]
			else:
				m *= f[key]
	return m


func fx_has(key: String) -> bool:
	for id in mods:
		if Cards.DATA[id]["fx"].has(key):
			return true
	return false


func carries_heavy() -> bool:
	return spec()["heavy"] or fx_has("heavy")


## Recomputes capacity after installing mods.
func refresh_stats() -> void:
	slots = int(round((spec()["slots"] + fx("slots", 0.0)) * fx("slots_mult")))
	max_kg = spec()["kg"] * fx("kg")


func spec() -> Dictionary:
	return VehicleTypes.DATA[type]


func status_name() -> String:
	if state == State.LOADING and ready:
		return "Ready"
	if state == State.AT_SHOP and shop_waiting:
		return "Waiting for bay"
	return STATE_NAMES[state]


func next_parcel() -> Parcel:
	return cargo[0] if cargo.size() > 0 else null


func stops_left() -> int:
	return cargo.size()


func load_kg() -> float:
	var kg := 0.0
	for p in cargo:
		kg += p.weight
	return kg


func can_fit(p: Parcel) -> bool:
	if cargo.size() >= slots:
		return false
	if p.heavy() and not carries_heavy():
		return false
	return load_kg() + p.weight <= max_kg


func fill_ratio() -> float:
	return maxf(float(cargo.size()) / slots, load_kg() / max_kg)


func route_progress() -> float:
	if route_total == 0:
		return 0.0
	return float(route_total - cargo.size()) / float(route_total)


func on_road() -> bool:
	return state in [State.EN_ROUTE, State.DELIVERING, State.RETURNING, State.TO_SHOP]


func out_of_service() -> bool:
	return state in [State.BROKEN, State.TOWING, State.TO_SHOP, State.AT_SHOP]
