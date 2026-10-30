class_name Van
extends Mover
## A delivery vehicle (van, box truck or sprinter) and its state machine.

enum State { IDLE, LOADING, EN_ROUTE, DELIVERING, RETURNING, BROKEN, TOWING, TO_SHOP, AT_SHOP }
const STATE_NAMES := ["Parked", "Loading", "En route", "Dropping off", "Returning",
	"Broken down", "Being towed", "To mechanic", "In the shop"]

const BASE_SPEED := 0.55        # world units per tick
const LOAD_MINUTES := 0.5       # per parcel
const STOP_MINUTES := 1.6       # per drop-off
const WAGE_PER_MIN := 0.40
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
	if p.heavy() and not spec()["heavy"]:
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
