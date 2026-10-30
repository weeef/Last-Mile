class_name Parcel
extends RefCounted
## One package moving through a company's network.

enum Kind { STANDARD, EXPRESS }
enum Stage { PLACED, SORTED, LOADED, OUT, DELIVERED }

const STAGE_NAMES := ["Order placed", "Sorted", "Loaded", "Out for delivery", "Delivered"]
const SORT_MINUTES := 6.0

var id := 0
var company := 0
var house := 0
var district := 0
var kind := Kind.STANDARD
var weight := 3.0
var vendor := -1          # -1 = walk-in customer from the open market
var job_id := 0
var pay_amount := 12.0
var created := 0.0
var deadline := 0.0
var stage := Stage.PLACED
var stage_times: Array[float] = [-1.0, -1.0, -1.0, -1.0, -1.0]
var van_code := ""
var late := false
# Delivery windows: arriving before window_start means nobody's home.
var window_start := -1.0
var window_end := -1.0
var signature := false
var attempts := 0


func set_stage(s: Stage, minute: float) -> void:
	stage = s
	stage_times[s] = minute


func code() -> String:
	return "#%04d" % id


func pay() -> float:
	return pay_amount


func heavy() -> bool:
	return weight >= Vendors.HEAVY_KG


func window_text() -> String:
	if window_start > 0.0:
		return "after " + Sim.clock(window_start)
	if window_end > 0.0:
		return "before " + Sim.clock(window_end)
	return ""


func kind_name() -> String:
	return "Express" if kind == Kind.EXPRESS else "Standard"


func source_name() -> String:
	return "Walk-in" if vendor < 0 else Vendors.get_vendor(vendor)["name"]
