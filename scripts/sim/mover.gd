class_name Mover
extends RefCounted
## Anything that drives along the road graph: vans, vendor couriers.

var pos := Vector3.ZERO
var prev_pos := Vector3.ZERO
var heading := Vector3.FORWARD
var path := PackedVector3Array()
var path_i := 0
var odometer := 0.0


func set_path(p: PackedVector3Array) -> void:
	path = p
	path_i = 1
	if p.size() > 0:
		pos = p[0]


func remaining_distance() -> float:
	if path_i >= path.size():
		return 0.0
	var d := pos.distance_to(path[path_i])
	for i in range(path_i + 1, path.size()):
		d += path[i - 1].distance_to(path[i])
	return d


## Moves along the path. Returns true on arrival.
func drive(step: float) -> bool:
	while step > 0.0 and path_i < path.size():
		var target := path[path_i]
		var to := target - pos
		var dist := to.length()
		if dist > 0.001:
			heading = to / dist
		if dist <= step:
			pos = target
			step -= dist
			odometer += dist
			path_i += 1
		else:
			pos += heading * step
			odometer += step
			step = 0.0
	return path_i >= path.size()
