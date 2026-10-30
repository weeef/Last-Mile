class_name City
extends RefCounted
## The road network, houses and districts. Pure data, no nodes.
## Roads form a grid. Each horizontal street segment has two curb stops,
## and houses line both sides of those streets.

const GRID := 6              # blocks per side
const BLOCK := 12.0          # distance between intersections
const ROAD_W := 2.6
const HALF := GRID * BLOCK * 0.5

const STREET_NAMES := ["Maple St", "Birch St", "Cedar St", "Elm St", "Oak St", "Pine St", "Willow St"]
const DISTRICT_NAMES := ["Old Town", "Riverside", "Maple Heights", "Harbor"]

var astar := AStar3D.new()
var node_count := 0
var intersections := {}          # Vector2i -> node id
var houses: Array[Dictionary] = []
var park_blocks := {}            # Vector2i -> true
var depot_blocks := {}           # Vector2i -> company id
# Per company: { "node": int, "block": Vector2i, "side": int } side = +1 if the road is south of the block
var depots: Array[Dictionary] = []
var garage := {}                 # { "block": Vector2i, "node": int, "side": 1 }
var vendor_lots: Array[Dictionary] = []   # one per vendor, same shape as a house
var curb_lookup := {}
var _dist_cache := {}
var closures: Array = []        # [a, b] node pairs closed today            # "i,j,k" -> node id (horizontal segment curbs)


func build(rng: RandomNumberGenerator) -> void:
	# Two depots in opposite corners.
	depots = [
		{"block": Vector2i(0, 0), "side": 1},
		{"block": Vector2i(GRID - 1, GRID - 1), "side": -1},
	]
	depot_blocks[Vector2i(0, 0)] = 0
	depot_blocks[Vector2i(GRID - 1, GRID - 1)] = 1
	# The town mechanic takes a whole block near the middle.
	garage = {"block": Vector2i(3, 2), "side": 1}
	depot_blocks[Vector2i(3, 2)] = -1

	# A few park blocks with trees instead of houses.
	var tries := 0
	while park_blocks.size() < 3 and tries < 50:
		tries += 1
		var b := Vector2i(rng.randi_range(0, GRID - 1), rng.randi_range(0, GRID - 1))
		if depot_blocks.has(b):
			continue
		park_blocks[b] = true

	# Intersections.
	for i in GRID + 1:
		for j in GRID + 1:
			intersections[Vector2i(i, j)] = _add_node(grid_pos(i, j))

	# Horizontal segments (west-east) with two curb stops each.
	for j in GRID + 1:
		for i in GRID:
			var a: int = intersections[Vector2i(i, j)]
			var b: int = intersections[Vector2i(i + 1, j)]
			var prev := a
			for k in 2:
				var t := (k + 1) / 3.0
				var p := grid_pos(i, j).lerp(grid_pos(i + 1, j), t)
				var c := _add_node(p)
				curb_lookup["%d,%d,%d" % [i, j, k]] = c
				astar.connect_points(prev, c)
				prev = c
			astar.connect_points(prev, b)

	# Vertical segments (north-south).
	for i in GRID + 1:
		for j in GRID:
			astar.connect_points(intersections[Vector2i(i, j)], intersections[Vector2i(i, j + 1)])

	# Depot access nodes.
	for d in depots:
		var blk: Vector2i = d["block"]
		var road_j: int = blk.y + (1 if d["side"] > 0 else 0)
		var k := 1 if d["side"] > 0 else 0
		d["node"] = curb_lookup["%d,%d,%d" % [blk.x, road_j, k]]

	var gb: Vector2i = garage["block"]
	garage["node"] = curb_lookup["%d,%d,%d" % [gb.x, gb.y + 1, 1]]

	# Houses: two per row, north and south row of every block.
	for bx in GRID:
		for bz in GRID:
			var blk := Vector2i(bx, bz)
			if depot_blocks.has(blk) or park_blocks.has(blk):
				continue
			for row in 2:  # 0 = north row (faces road j=bz), 1 = south row (faces road j=bz+1)
				var road_j := bz + row
				for k in 2:
					var curb: int = curb_lookup["%d,%d,%d" % [bx, road_j, k]]
					var curb_pos := astar.get_point_position(curb)
					var face := -1.0 if row == 0 else 1.0  # direction from house toward its road (z)
					var setback := ROAD_W * 0.5 + 2.4
					var hp := curb_pos + Vector3(0, 0, -face * setback)
					var number := 100 * (bx + 1) + k * 20 + (1 if row == 1 else 2) * 2
					houses.append({
						"id": houses.size(),
						"pos": hp,
						"curb": curb,
						"face": face,
						"district": district_of(blk),
						"address": "%d %s" % [number, STREET_NAMES[road_j]],
						"street": STREET_NAMES[road_j],
						"color": rng.randi_range(0, Palette.HOUSE_COLORS.size() - 1),
						"floors": 2 if rng.randf() < 0.3 else 1,
						"block": blk,
						"yaw": rng.randf_range(-4.0, 4.0),
						"chimney": rng.randf() < 0.45,
						"fence": rng.randf() < 0.35,
						"car": rng.randf() < 0.3,
						"roof": 1 if rng.randf() < 0.18 else 0,
					})
	# Turn a few lots into vendor storefronts, spread around town.
	var targets := [Vector2i(1, 1), Vector2i(4, 1), Vector2i(1, 4), Vector2i(2, 3), Vector2i(4, 4), Vector2i(2, 0)]
	for t in targets:
		var best := -1
		var best_d := 1e9
		for i in houses.size():
			var b: Vector2i = houses[i]["block"]
			var d: int = (b - t).length_squared()
			if d < best_d:
				best_d = d
				best = i
		var lot: Dictionary = houses[best]
		houses.remove_at(best)
		vendor_lots.append(lot)
	for i in houses.size():
		houses[i]["id"] = i


func _add_node(p: Vector3) -> int:
	var id := node_count
	astar.add_point(id, p)
	node_count += 1
	return id


static func grid_pos(i: int, j: int) -> Vector3:
	return Vector3(i * BLOCK - HALF, 0.0, j * BLOCK - HALF)


static func block_origin(b: Vector2i) -> Vector3:
	return grid_pos(b.x, b.y)


static func district_of(b: Vector2i) -> int:
	return (1 if b.x >= GRID / 2 else 0) + (2 if b.y >= GRID / 2 else 0)


func node_pos(id: int) -> Vector3:
	return astar.get_point_position(id)


func path(from_id: int, to_id: int) -> PackedVector3Array:
	if from_id == to_id:
		return PackedVector3Array([astar.get_point_position(from_id)])
	return astar.get_point_path(from_id, to_id)


static func path_length(p: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, p.size()):
		total += p[i - 1].distance_to(p[i])
	return total


## Driving distance along roads (cached; cleared when roads close/open).
func road_dist(a: int, b: int) -> float:
	if a == b:
		return 0.0
	var key := a * 100000 + b
	if not _dist_cache.has(key):
		_dist_cache[key] = path_length(path(a, b))
	return _dist_cache[key]


func set_closures(pairs: Array) -> void:
	for c in closures:
		astar.connect_points(c[0], c[1])
	closures = pairs.duplicate()
	for c in closures:
		astar.disconnect_points(c[0], c[1])
	_dist_cache.clear()


func manhattan(a: int, b: int) -> float:
	var pa := astar.get_point_position(a)
	var pb := astar.get_point_position(b)
	return absf(pa.x - pb.x) + absf(pa.z - pb.z)
