class_name Job
extends Mover
## A delivery order posted by a vendor. Once taken, the vendor packs it,
## then their courier drives the parcels to your depot.

enum State { OFFERED, PACKING, INBOUND, DONE }

var id := 0
var vendor := 0
var houses: Array[int] = []
var weights: Array[float] = []
var total_kg := 0.0
var pay := 0.0
var express := false
var promise := 180.0       # minutes from arrival at the depot
var expires := 0.0         # when an offer disappears from the board
var state := State.OFFERED
var timer := 0.0
var rush := false          # short-notice order: big pay, accept fast


func stops() -> int:
	return houses.size()


func needs_liftgate() -> bool:
	for w in weights:
		if w >= Vendors.HEAVY_KG:
			return true
	return false
