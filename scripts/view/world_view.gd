class_name WorldView
extends Node3D
## Builds the town from primitive meshes and mirrors the sim every frame.
## Nothing here changes the simulation; it only reads it.

const VAN_SCALE := 1.2

var sim: Sim
var sun: DirectionalLight3D
var env: Environment
var selected_van: Van = null

var _mats := {}
var _van_nodes := {}          # van id -> Node3D
var _van_render := {}         # van id -> {"pos", "dir"}
var _pins := {}               # house id -> Node3D
var _depot_boxes: Array = []
var _depot_slots: Array = []
var _garage_bays: Array[Transform3D] = []
var _garage_queue: Array[Transform3D] = []
var _job_nodes := {}          # job id -> Node3D (vendor courier)
var _vendor_nodes: Array = []
var _bracket: Node3D
var _window_mat: StandardMaterial3D
var _lamp_mat: StandardMaterial3D
var _shop_window_mat: StandardMaterial3D
var _font_sign: FontFile
var _font_mono: FontFile
var _time := 0.0
var _rng := RandomNumberGenerator.new()
# Graphics-detail hooks
var _forest: Array = []        # MultiMeshInstance3D of the woods around town
var _fences: MultiMeshInstance3D
var _cars: Array = []
var _crosswalks: MultiMeshInstance3D
var _shadow_dist := 180.0


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_rng.seed = sim.seed_value + 99
	_font_sign = load("res://fonts/BarlowCondensed-Bold.ttf")
	_font_mono = load("res://fonts/IBMPlexMono-Bold.ttf")
	_build_environment()
	_build_ground()
	_build_blocks()
	_build_road_markings()
	_build_lamps()
	for c in sim.companies:
		_build_depot(c)
	_build_garage()
	for i in sim.city.vendor_lots.size():
		_build_vendor(i)
	for c in sim.companies:
		for v in c.vans:
			_add_van_node(v)
	sim.van_added.connect(_add_van_node)
	sim.parcel_delivered.connect(_on_delivered)
	_bracket = _make_bracket()
	_bracket.visible = false
	add_child(_bracket)


# ------------------------------------------------------------- helpers

func mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mats[key] = m
	return m


func unshaded(c: Color) -> StandardMaterial3D:
	var key := "u_" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


func glow_mat(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func box(size: Vector3, pos: Vector3, m: Material, parent: Node3D = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func cyl(r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, parent: Node3D = null, seg := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func sign_label(text: String, size: int, col: Color, pos: Vector3, yaw_deg: float, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font_sign
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 0
	l.modulate = col
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw_deg, 0)
	l.double_sided = false
	(parent if parent else self).add_child(l)
	return l


func _multimesh(mesh: Mesh, tfs: Array[Transform3D], offset: Vector3) -> MultiMeshInstance3D:
	if tfs.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = tfs.size()
	for i in tfs.size():
		var t := tfs[i]
		mm.set_instance_transform(i, Transform3D(t.basis, t.origin + t.basis * offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


# ------------------------------------------------------------- environment

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.SKY_DAY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f98ad")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.06
	env.fog_enabled = true
	env.fog_light_color = Palette.SKY_DAY
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -52, 0)
	sun.light_color = Color("ffd7a8")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.75
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)


func _build_ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	g.mesh = pm
	g.material_override = mat(Palette.GRASS)
	g.position.y = -0.05
	add_child(g)
	var ext := City.GRID * City.BLOCK + City.ROAD_W
	box(Vector3(ext, 0.1, ext), Vector3.ZERO, mat(Palette.ROAD, 0.95), null, false)
	var trees: Array[Transform3D] = []
	var lim := City.HALF + City.ROAD_W
	for i in 260:
		var p := Vector3(_rng.randf_range(-lim - 55.0, lim + 55.0), 0, _rng.randf_range(-lim - 55.0, lim + 55.0))
		if absf(p.x) < lim + 3.0 and absf(p.z) < lim + 3.0:
			continue
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.9, 2.0))
		trees.append(Transform3D(b, p))
	_forest = _add_trees(trees)


func _build_blocks() -> void:
	var inner := City.BLOCK - City.ROAD_W
	var tree_tf: Array[Transform3D] = []
	for bx in City.GRID:
		for bz in City.GRID:
			var b := Vector2i(bx, bz)
			var c := City.block_origin(b) + Vector3(City.BLOCK * 0.5, 0, City.BLOCK * 0.5)
			box(Vector3(inner, 0.22, inner), c + Vector3(0, 0.11, 0), mat(Palette.SIDEWALK), null, false)
			if sim.city.depot_blocks.has(b):
				continue
			var park := sim.city.park_blocks.has(b)
			box(Vector3(inner - 0.9, 0.26, inner - 0.9), c + Vector3(0, 0.13, 0), mat(Palette.GRASS_DARK if park else Palette.LAWN), null, false)
			if park:
				box(Vector3(inner - 0.9, 0.02, 0.8), c + Vector3(0, 0.27, 0.6), mat(Palette.SIDEWALK.darkened(0.08)), null, false)
				box(Vector3(0.8, 0.02, 4.0), c + Vector3(-1.5, 0.27, -1.2), mat(Palette.SIDEWALK.darkened(0.08)), null, false)
				var pond := cyl(1.5, 1.6, 0.05, c + Vector3(2.2, 0.28, -2.3), mat(Color("4f6f7a"), 0.15), null, 14)
				pond.scale = Vector3(1.0, 1.0, 0.8)
				for k in 2:
					var bp := c + Vector3(-3.2 + k * 3.6, 0.27, 1.35)
					box(Vector3(1.0, 0.08, 0.32), bp + Vector3(0, 0.32, 0), mat(Color("7a5a3e")))
					box(Vector3(1.0, 0.3, 0.06), bp + Vector3(0, 0.5, -0.15), mat(Color("7a5a3e")))
				for k in 11:
					var p := c + Vector3(_rng.randf_range(-4.2, 4.2), 0.26, _rng.randf_range(-4.2, 4.2))
					if p.distance_to(Vector3(c.x + 2.2, p.y, c.z - 2.3)) < 2.2 or absf(p.z - c.z - 0.6) < 0.8 or absf(p.x - c.x + 1.5) < 0.7:
						continue
					tree_tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.4)), p))
			else:
				for k in 2:
					if _rng.randf() < 0.25:
						continue
					var p := c + Vector3(-2.5 + k * 5.0 + _rng.randf_range(-0.8, 0.8), 0.26, _rng.randf_range(-0.5, 0.5))
					tree_tf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.55, 0.95)), p))
	_add_trees(tree_tf)
	var posts: Array[Transform3D] = []
	for h in sim.city.houses:
		_build_house(h, posts)
	var post := BoxMesh.new()
	post.size = Vector3(0.07, 0.38, 0.07)
	post.material = mat(Color("d9cfb8"))
	_fences = _multimesh(post, posts, Vector3(0, 0.19, 0))


func _build_house(h: Dictionary, posts: Array[Transform3D]) -> void:
	var root := Node3D.new()
	root.position = h["pos"] + Vector3(0, 0.26, 0)
	root.rotation_degrees.y = h["yaw"]
	add_child(root)
	var face: float = h["face"]
	var ci: int = h["color"]
	var floors: int = h["floors"]
	var hgt := 1.45 if floors == 1 else 2.55
	var w := _rng.randf_range(2.1, 2.6)
	var d := _rng.randf_range(1.9, 2.2)
	var wall := mat(Palette.HOUSE_COLORS[ci])
	var roofm := mat(Palette.ROOF_COLORS[ci])
	box(Vector3(w, hgt, d), Vector3(0, hgt * 0.5, 0), wall, root)
	box(Vector3(w + 0.06, 0.18, d + 0.06), Vector3(0, 0.09, 0), mat(Color("6f675a")), root, false)
	if h["roof"] == 1:
		box(Vector3(w + 0.12, 0.16, d + 0.12), Vector3(0, hgt + 0.08, 0), roofm, root)
	else:
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(d + 0.4, _rng.randf_range(0.8, 1.15), w + 0.25)
		roof.mesh = pm
		roof.material_override = roofm
		roof.position = Vector3(0, hgt + pm.size.y * 0.5, 0)
		roof.rotation_degrees = Vector3(0, 90, 0)
		root.add_child(roof)
	if h["chimney"]:
		box(Vector3(0.32, 0.9, 0.32), Vector3(w * 0.28, hgt + 0.55, -face * d * 0.18), mat(Color("7b4a3d")), root)
	var fz := face * (d * 0.5 + 0.02)
	var door_x := -w * 0.2
	box(Vector3(0.48, 0.82, 0.06), Vector3(door_x, 0.6, fz), mat(Color("4a3a32")), root, false)
	box(Vector3(0.8, 0.06, 0.45), Vector3(door_x, 1.12, face * (d * 0.5 + 0.22)), roofm, root)
	box(Vector3(0.8, 0.12, 0.5), Vector3(door_x, 0.2, face * (d * 0.5 + 0.25)), mat(Color("8b8275")), root, false)
	var wm := _windows()
	box(Vector3(0.5, 0.42, 0.06), Vector3(w * 0.22, 0.85, fz), wm, root, false)
	box(Vector3(0.62, 0.07, 0.1), Vector3(w * 0.22, 0.6, fz), mat(Color("e8dcc4")), root, false)
	if floors == 2:
		box(Vector3(0.5, 0.42, 0.06), Vector3(-w * 0.2, 1.95, fz), wm, root, false)
		box(Vector3(0.5, 0.42, 0.06), Vector3(w * 0.22, 1.95, fz), wm, root, false)
	box(Vector3(0.06, 0.4, 0.45), Vector3(w * 0.5 + 0.02, 0.85, 0), wm, root, false)
	box(Vector3(0.45, 0.03, 1.3), Vector3(door_x, 0.01, face * (d * 0.5 + 0.9)), mat(Palette.SIDEWALK), root, false)
	box(Vector3(0.08, 0.55, 0.08), Vector3(w * 0.42, 0.27, face * (d * 0.5 + 1.35)), mat(Color("3e3a36")), root)
	box(Vector3(0.24, 0.2, 0.36), Vector3(w * 0.42, 0.62, face * (d * 0.5 + 1.35)), mat(Palette.ROOF_COLORS[(ci + 3) % 8]), root)
	if h["car"]:
		_make_car(root, Vector3(w * 0.5 + 0.75, 0, face * 0.2), Palette.CAR_COLORS[_rng.randi_range(0, Palette.CAR_COLORS.size() - 1)])
	if h["fence"]:
		var t := root.transform
		var z := face * (d * 0.5 + 1.75)
		var x := -1.35
		while x <= 1.35:
			if absf(x - door_x) > 0.4:
				posts.append(t * Transform3D(Basis(), Vector3(x, 0, z)))
			x += 0.22


func _make_car(parent: Node3D, pos: Vector3, col: Color) -> void:
	var car := Node3D.new()
	car.position = pos
	parent.add_child(car)
	_cars.append(car)
	box(Vector3(0.75, 0.32, 1.35), Vector3(0, 0.28, 0), mat(col, 0.5), car)
	box(Vector3(0.66, 0.26, 0.75), Vector3(0, 0.56, 0.05), mat(col.lightened(0.1), 0.5), car)
	box(Vector3(0.68, 0.18, 0.6), Vector3(0, 0.58, 0.05), mat(Color("2a3240"), 0.2), car, false)
	for wx in [-0.36, 0.36]:
		for wz in [-0.42, 0.42]:
			var w := cyl(0.13, 0.13, 0.1, Vector3(wx, 0.13, wz), mat(Color("1d1d22")), car)
			w.rotation_degrees.z = 90


func _windows() -> StandardMaterial3D:
	if _window_mat == null:
		_window_mat = StandardMaterial3D.new()
		_window_mat.albedo_color = Color("6b7487")
		_window_mat.roughness = 0.3
		_window_mat.emission_enabled = true
		_window_mat.emission = Color("ffbf6b")
		_window_mat.emission_energy_multiplier = 0.0
	return _window_mat


func _add_trees(tfs: Array[Transform3D]) -> Array:
	var out: Array = []
	if tfs.is_empty():
		return out
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.1
	trunk.bottom_radius = 0.16
	trunk.height = 0.9
	trunk.radial_segments = 6
	trunk.material = mat(Palette.TRUNK)
	out.append(_multimesh(trunk, tfs, Vector3(0, 0.45, 0)))
	var groups: Array = [[], [], [], []]
	for i in tfs.size():
		groups[i % 4].append(tfs[i])
	for gi in 4:
		var arr: Array[Transform3D] = []
		for t in groups[gi]:
			arr.append(t)
		if gi % 2 == 0:
			var canopy := SphereMesh.new()
			canopy.radius = 0.75
			canopy.height = 1.4
			canopy.radial_segments = 7
			canopy.rings = 4
			canopy.material = mat(Palette.TREE_GREENS[gi])
			out.append(_multimesh(canopy, arr, Vector3(0, 1.4, 0)))
		else:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.75
			cone.height = 1.9
			cone.radial_segments = 7
			cone.material = mat(Palette.TREE_GREENS[gi])
			out.append(_multimesh(cone, arr, Vector3(0, 1.6, 0)))
	return out


func _build_road_markings() -> void:
	var dash := BoxMesh.new()
	dash.size = Vector3(0.9, 0.02, 0.12)
	dash.material = mat(Palette.ROAD_LINE, 0.9)
	var tfs: Array[Transform3D] = []
	for j in City.GRID + 1:
		for i in City.GRID:
			for k in 4:
				tfs.append(Transform3D(Basis(), City.grid_pos(i, j) + Vector3(2.4 + k * 2.4, 0.06, 0)))
	var rot := Basis(Vector3.UP, PI * 0.5)
	for i in City.GRID + 1:
		for j in City.GRID:
			for k in 4:
				tfs.append(Transform3D(rot, City.grid_pos(i, j) + Vector3(0, 0.06, 2.4 + k * 2.4)))
	_multimesh(dash, tfs, Vector3.ZERO)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.22, 0.02, 1.6)
	stripe.material = mat(Palette.ROAD_LINE.darkened(0.05), 0.9)
	var cw: Array[Transform3D] = []
	for i in range(1, City.GRID):
		for j in range(1, City.GRID):
			if (i + j) % 2 != 0:
				continue
			var c := City.grid_pos(i, j)
			for s in 5:
				cw.append(Transform3D(Basis(), c + Vector3(-0.6 + s * 0.3, 0.06, -2.0)))
	_crosswalks = _multimesh(stripe, cw, Vector3.ZERO)


func _build_lamps() -> void:
	var poles: Array[Transform3D] = []
	for i in City.GRID + 1:
		for j in City.GRID + 1:
			if (i + j) % 2 == 1:
				continue
			var p := City.grid_pos(i, j) + Vector3(1.75, 0.22, 1.75)
			if absf(p.x) > City.HALF or absf(p.z) > City.HALF:
				continue
			poles.append(Transform3D(Basis(), p))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.07
	pole.height = 2.6
	pole.radial_segments = 6
	pole.material = mat(Color("2b2a2e"))
	_multimesh(pole, poles, Vector3(0, 1.3, 0))
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.32
	head.radial_segments = 8
	head.rings = 4
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color("f3e2b8")
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color("ffc979")
	_lamp_mat.emission_energy_multiplier = 0.2
	head.material = _lamp_mat
	_multimesh(head, poles, Vector3(0, 2.62, 0))


# ------------------------------------------------------------- depots, garage, vendors

func _block_local(b: Vector2i, side: int, x: float, z: float) -> Vector3:
	var o := City.block_origin(b)
	return o + Vector3(x, 0, z if side > 0 else City.BLOCK - z)


func _depot_local(c: Company, x: float, z: float) -> Vector3:
	var d: Dictionary = sim.city.depots[c.id]
	return _block_local(d["block"], d["side"], x, z)


func _build_depot(c: Company) -> void:
	var side: int = sim.city.depots[c.id]["side"]
	box(Vector3(8.8, 0.04, 5.2), _depot_local(c, 6.0, 8.0) + Vector3(0, 0.24, 0), mat(Color("575a63"), 0.95), null, false)
	var wh := _depot_local(c, 6.0, 3.4)
	box(Vector3(8.6, 3.0, 4.4), wh + Vector3(0, 1.72, 0), mat(Color("cfc6b4")))
	box(Vector3(8.9, 0.3, 4.7), wh + Vector3(0, 3.35, 0), mat(c.color.darkened(0.25)))
	box(Vector3(8.62, 0.6, 4.42), wh + Vector3(0, 0.52, 0), mat(Color("8d8577")))
	for k in 3:
		box(Vector3(0.6, 0.4, 0.6), wh + Vector3(-2.5 + k * 2.5, 3.7, 0), mat(Color("6c6a66")))
	for k in 3:
		var dp := wh + Vector3(-2.6 + k * 2.6, 1.15, side * 2.22)
		box(Vector3(1.6, 1.8, 0.06), dp, mat(Color("8e8f93")), null, false)
		for s in 6:
			box(Vector3(1.6, 0.03, 0.08), dp + Vector3(0, -0.8 + s * 0.32, 0), mat(Color("75767a")), null, false)
		box(Vector3(1.8, 0.14, 0.12), dp + Vector3(0, 1.0, 0), mat(c.color), null, false)
	box(Vector3(5.4, 0.62, 0.08), wh + Vector3(0, 2.55, side * 2.25), mat(Palette.INK), null, false)
	sign_label(c.name.to_upper(), 64, c.color.lightened(0.2), wh + Vector3(0, 2.55, side * 2.3), 0.0 if side > 0 else 180.0)
	var boxes: Array = []
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.34, 0.42)
	for i in 36:
		var col := i % 3
		var row := (i / 3) % 2
		var lvl := i / 6
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.position = _depot_local(c, 9.3 + col * 0.46, 6.2 + row * 0.46) + Vector3(_rng.randf_range(-0.04, 0.04), 0.43 + lvl * 0.35, 0)
		mi.rotation_degrees.y = _rng.randf_range(-6, 6)
		mi.material_override = mat(Palette.PARCEL)
		mi.visible = false
		add_child(mi)
		boxes.append(mi)
	_depot_boxes.append(boxes)
	var slots: Array = []
	var facing := Vector3(0, 0, 1.0 * side)
	for row in 2:
		for k in 6:
			var p := _depot_local(c, 2.0 + k * 1.25, 9.5 - row * 2.6) + Vector3(0, 0.26, 0)
			slots.append(Transform3D(Basis.looking_at(facing, Vector3.UP), p))
			box(Vector3(0.05, 0.02, 2.0), p + Vector3(0.62, 0.0, 0), unshaded(Color("c9c2b0")), null, false)
	_depot_slots.append(slots)


func _build_garage() -> void:
	var b: Vector2i = sim.city.garage["block"]
	var side: int = sim.city.garage["side"]
	box(Vector3(8.8, 0.04, 8.8), _block_local(b, side, 6.0, 6.0) + Vector3(0, 0.24, 0), mat(Color("4f4e52"), 0.95), null, false)
	for k in 4:
		var st := cyl(0.4, 0.4, 0.01, _block_local(b, side, _rng.randf_range(2.5, 9.5), _rng.randf_range(6.5, 9.5)) + Vector3(0, 0.27, 0), mat(Color("3a393c"), 0.4), null, 10)
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wh := _block_local(b, side, 6.0, 3.3)
	box(Vector3(7.6, 2.6, 4.2), wh + Vector3(0, 1.55, 0), mat(Color("7f8a86")))
	box(Vector3(7.9, 0.25, 4.5), wh + Vector3(0, 2.95, 0), mat(Color("3d4446")))
	for k in Sim.GARAGE_BAYS:
		var dp := wh + Vector3(-1.9 + k * 3.8, 1.2, side * 2.12)
		box(Vector3(2.6, 2.0, 0.06), dp, mat(Color("2c2f33")), null, false)
		box(Vector3(2.8, 0.1, 0.1), dp + Vector3(0, 1.05, 0), mat(Palette.AMBER), null, false)
		var bay_pos := wh + Vector3(-1.9 + k * 3.8, 0.26, side * 3.6)
		_garage_bays.append(Transform3D(Basis.looking_at(Vector3(0, 0, -side), Vector3.UP), bay_pos))
	box(Vector3(4.6, 0.6, 0.08), wh + Vector3(0, 2.45, side * 2.15), mat(Palette.AMBER.darkened(0.15)), null, false)
	sign_label("GEARBOX GARAGE", 60, Palette.INK, wh + Vector3(0, 2.45, side * 2.2), 0.0 if side > 0 else 180.0)
	for k in 3:
		for t in 3:
			var tire := cyl(0.32, 0.32, 0.2, _block_local(b, side, 1.6, 6.0 + k * 0.8) + Vector3(0, 0.36 + t * 0.21, 0), mat(Color("1f1f22")), null, 12)
			tire.rotation_degrees.y = t * 20
	var drum_cols := [Color("8c3b33"), Color("2f4b63"), Color("6b7a3c")]
	for k in 3:
		cyl(0.22, 0.22, 0.7, _block_local(b, side, 10.5, 5.6 + k * 0.5) + Vector3(0, 0.6, 0), mat(drum_cols[k], 0.6), null, 10)
	for k in 6:
		var qp := _block_local(b, side, 2.2 + k * 1.5, 9.8) + Vector3(0, 0.26, 0)
		_garage_queue.append(Transform3D(Basis.looking_at(Vector3(0, 0, -side), Vector3.UP), qp))


func _build_vendor(i: int) -> void:
	var lot: Dictionary = sim.city.vendor_lots[i]
	var vd := Vendors.get_vendor(i)
	var col: Color = vd["color"]
	var root := Node3D.new()
	root.position = lot["pos"] + Vector3(0, 0.26, 0)
	add_child(root)
	var face: float = lot["face"]
	var w := 2.9
	var d := 2.3
	box(Vector3(w, 1.9, d), Vector3(0, 0.95, 0), mat(col.lerp(Color("d8ccb4"), 0.55)), root)
	box(Vector3(w + 0.15, 0.25, d + 0.15), Vector3(0, 2.0, 0), mat(col.darkened(0.35)), root)
	var win := box(Vector3(1.6, 0.9, 0.06), Vector3(0.45, 0.85, face * (d * 0.5 + 0.02)), _shop_window(), root, false)
	box(Vector3(0.55, 1.1, 0.06), Vector3(-0.95, 0.6, face * (d * 0.5 + 0.02)), mat(Color("3d3330")), root, false)
	var stripes: Array = []
	for s in 8:
		var sc := col if s % 2 == 0 else Color("e9dfc8")
		var st := box(Vector3(w / 8.0, 0.05, 0.7), Vector3(-w * 0.5 + w / 16.0 + s * w / 8.0, 1.55, face * (d * 0.5 + 0.33)), mat(sc), root)
		st.rotation_degrees.x = -face * 22.0
		stripes.append(st)
	box(Vector3(w * 0.9, 0.42, 0.06), Vector3(0, 2.38, face * (d * 0.5 + 0.02)), mat(Palette.INK), root, false)
	sign_label(String(vd["name"]).to_upper(), 40, col.lightened(0.35), Vector3(0, 2.38, face * (d * 0.5 + 0.06)), 0.0 if face > 0 else 180.0, root)
	box(Vector3(0.4, 0.35, 0.4), Vector3(-1.5, 0.17, face * (d * 0.5 + 0.5)), mat(Palette.PARCEL), root)
	box(Vector3(0.35, 0.3, 0.35), Vector3(-1.45, 0.5, face * (d * 0.5 + 0.48)), mat(Palette.PARCEL.darkened(0.1)), root)
	var status := Label3D.new()
	status.font = _font_sign
	status.font_size = 54
	status.pixel_size = 0.016
	status.outline_size = 14
	status.outline_modulate = Palette.INK
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.no_depth_test = true
	status.position = Vector3(0, 3.4, 0)
	root.add_child(status)
	_vendor_nodes.append({"stripes": stripes, "window": win, "status": status, "color": col})


func _shop_window() -> StandardMaterial3D:
	if _shop_window_mat == null:
		_shop_window_mat = StandardMaterial3D.new()
		_shop_window_mat.albedo_color = Color("5d6676")
		_shop_window_mat.roughness = 0.2
		_shop_window_mat.emission_enabled = true
		_shop_window_mat.emission = Color("ffcf8a")
		_shop_window_mat.emission_energy_multiplier = 0.3
	return _shop_window_mat


# ------------------------------------------------------------- vehicles

func _vehicle_mesh(t: StringName, livery: Color, root: Node3D) -> void:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var cream := mat(Color("e7e0d0"))
	var glass := mat(Color("2b3442"), 0.15)
	var wheel_m := mat(Color("1f1f24"))
	var wheels: Array = []
	var front := -1.12
	var back := 0.96
	match t:
		&"box":
			box(Vector3(1.15, 1.45, 2.1), Vector3(0, 1.05, 0.42), cream, body)
			box(Vector3(1.17, 0.18, 2.12), Vector3(0, 0.45, 0.42), mat(livery), body)
			box(Vector3(1.05, 0.95, 0.85), Vector3(0, 0.72, -1.08), mat(livery), body)
			box(Vector3(0.9, 0.36, 0.05), Vector3(0, 0.95, -1.51), glass, body, false)
			box(Vector3(1.0, 0.12, 0.25), Vector3(0, 0.3, 1.55), mat(Color("3a3a3e")), body)
			wheels = [[-0.56, -1.0], [0.56, -1.0], [-0.56, 0.75], [0.56, 0.75], [-0.56, 1.15], [0.56, 1.15]]
			front = -1.52
			back = 1.48
		&"sprinter":
			box(Vector3(0.92, 1.2, 1.7), Vector3(0, 0.85, 0.2), cream, body)
			box(Vector3(0.94, 0.14, 1.72), Vector3(0, 0.62, 0.2), mat(livery), body)
			box(Vector3(0.9, 0.7, 0.55), Vector3(0, 0.6, -0.85), cream, body)
			box(Vector3(0.92, 0.12, 0.57), Vector3(0, 0.98, -0.85), mat(livery), body)
			box(Vector3(0.8, 0.3, 0.05), Vector3(0, 0.82, -1.13), glass, body, false)
			wheels = [[-0.47, -0.75], [0.47, -0.75], [-0.47, 0.7], [0.47, 0.7]]
			front = -1.13
			back = 1.06
		_:
			box(Vector3(1.0, 1.0, 1.45), Vector3(0, 0.75, 0.22), cream, body)
			box(Vector3(1.02, 0.2, 1.47), Vector3(0, 0.55, 0.22), mat(livery), body)
			box(Vector3(1.0, 0.72, 0.62), Vector3(0, 0.6, -0.8), mat(livery), body)
			box(Vector3(0.84, 0.3, 0.05), Vector3(0, 0.78, -1.1), glass, body, false)
			wheels = [[-0.5, -0.72], [0.5, -0.72], [-0.5, 0.62], [0.5, 0.62]]
	box(Vector3(0.18, 0.09, 0.04), Vector3(-0.3, 0.42, front - 0.01), unshaded(Color("f5e6b8")), body, false)
	box(Vector3(0.18, 0.09, 0.04), Vector3(0.3, 0.42, front - 0.01), unshaded(Color("f5e6b8")), body, false)
	for wpos in wheels:
		var w := cyl(0.21, 0.21, 0.16, Vector3(wpos[0], 0.21, wpos[1]), wheel_m, root, 10)
		w.rotation_degrees.z = 90
	var hz := Node3D.new()
	hz.name = "Hazard"
	hz.visible = false
	body.add_child(hz)
	var amber := glow_mat(Color("ff9a2e"), 3.0)
	box(Vector3(0.16, 0.1, 0.04), Vector3(-0.38, 0.5, back + 0.01), amber, hz, false)
	box(Vector3(0.16, 0.1, 0.04), Vector3(0.38, 0.5, back + 0.01), amber, hz, false)
	box(Vector3(0.16, 0.1, 0.04), Vector3(-0.42, 0.42, front - 0.02), amber, hz, false)
	box(Vector3(0.16, 0.1, 0.04), Vector3(0.42, 0.42, front - 0.02), amber, hz, false)
	var smoke := Node3D.new()
	smoke.name = "Smoke"
	smoke.visible = false
	root.add_child(smoke)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.55, 0.58, 0.6)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in 4:
		var s := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.25
		sph.height = 0.5
		sph.radial_segments = 6
		sph.rings = 3
		s.mesh = sph
		s.material_override = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.add_child(s)
	var tow := Node3D.new()
	tow.name = "Tow"
	tow.visible = false
	tow.position = Vector3(0, 0, front - 1.55)
	root.add_child(tow)
	box(Vector3(1.05, 0.85, 0.9), Vector3(0, 0.68, -0.55), mat(Color("d4a53c")), tow)
	box(Vector3(0.9, 0.3, 0.05), Vector3(0, 0.85, -1.01), glass, tow, false)
	box(Vector3(1.0, 0.2, 1.4), Vector3(0, 0.4, 0.55), mat(Color("3a3a3e")), tow)
	box(Vector3(0.7, 0.08, 0.15), Vector3(0, 1.15, -0.55), glow_mat(Color("ff9a2e"), 2.0), tow, false)
	var boom := box(Vector3(0.12, 0.12, 1.1), Vector3(0, 0.7, 1.15), mat(Color("2b2a2e")), tow)
	boom.rotation_degrees.x = 18
	for wpos in [[-0.5, -0.6], [0.5, -0.6], [-0.5, 0.7], [0.5, 0.7]]:
		var w := cyl(0.21, 0.21, 0.16, Vector3(wpos[0], 0.21, wpos[1]), wheel_m, tow, 10)
		w.rotation_degrees.z = 90
	var warn := Label3D.new()
	warn.name = "Warn"
	warn.text = "!"
	warn.font = _font_sign
	warn.font_size = 120
	warn.pixel_size = 0.01
	warn.outline_size = 28
	warn.modulate = Color("f2e6c8")
	warn.outline_modulate = Palette.RED
	warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	warn.no_depth_test = true
	warn.position = Vector3(0, 2.6, 0)
	warn.visible = false
	root.add_child(warn)


func _add_van_node(v: Van) -> void:
	var c := sim.companies[v.company]
	var root := Node3D.new()
	_vehicle_mesh(v.type, c.color, root)
	add_child(root)
	_van_nodes[v.id] = root
	_van_render[v.id] = {"pos": v.pos, "dir": Vector3(0, 0, 1)}


func van_render_pos(v: Van) -> Vector3:
	if _van_render.has(v.id):
		return _van_render[v.id]["pos"]
	return v.pos


# ------------------------------------------------------------- frame update

func sync(alpha: float, delta: float, playing: bool) -> void:
	_time += delta
	for c in sim.companies:
		var parked := 0
		for v in c.vans:
			var node: Node3D = _van_nodes[v.id]
			var body: Node3D = node.get_node("Body")
			var broken := v.state == Van.State.BROKEN
			var towing := v.state == Van.State.TOWING
			(body.get_node("Hazard") as Node3D).visible = (broken or towing) and fmod(_time, 0.8) < 0.45
			(node.get_node("Smoke") as Node3D).visible = broken
			(node.get_node("Tow") as Node3D).visible = towing
			var warn: Node3D = node.get_node("Warn")
			warn.visible = broken
			if broken:
				_animate_smoke(node.get_node("Smoke"), v.id)
				warn.position.y = 2.6 + sin(_time * 5.0) * 0.12
			var parked_t := Transform3D()
			var is_parked := false
			if v.state == Van.State.IDLE or v.state == Van.State.LOADING:
				var slots: Array = _depot_slots[c.id]
				parked_t = slots[parked % slots.size()]
				parked += 1
				is_parked = true
			elif v.state == Van.State.AT_SHOP:
				var bay := sim.garage_working.find(v)
				if bay >= 0:
					parked_t = _garage_bays[bay % _garage_bays.size()]
				else:
					var q := maxi(0, sim.garage_position(v))
					parked_t = _garage_queue[q % _garage_queue.size()]
				is_parked = true
			if is_parked:
				node.transform = Transform3D(parked_t.basis.scaled(Vector3.ONE * VAN_SCALE), parked_t.origin)
				_van_render[v.id] = {"pos": parked_t.origin, "dir": -parked_t.basis.z}
				body.position.y = 0.0
				continue
			var p := v.prev_pos.lerp(v.pos, alpha)
			var r: Dictionary = _van_render[v.id]
			var dir: Vector3 = r["dir"]
			if dir.dot(v.heading) > -0.99:
				dir = dir.slerp(v.heading, minf(1.0, delta * 10.0)).normalized()
			else:
				dir = v.heading
			var right := dir.cross(Vector3.UP).normalized()
			var rp := p + right * 0.68 + Vector3(0, 0.06, 0)
			r["pos"] = rp
			r["dir"] = dir
			node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP).scaled(Vector3.ONE * VAN_SCALE), rp)
			var moving := playing and v.state in [Van.State.EN_ROUTE, Van.State.RETURNING, Van.State.TO_SHOP, Van.State.TOWING]
			body.position.y = absf(sin(_time * 14.0 + v.id)) * 0.03 if moving else 0.0
	_sync_couriers(alpha)
	_sync_vendors()
	_sync_depots()
	_sync_pins()
	_sync_bracket()
	_sync_daylight()


func _animate_smoke(smoke: Node3D, seed_i: int) -> void:
	var k := 0
	for s in smoke.get_children():
		var t := fmod(_time * 0.6 + k * 0.25 + seed_i * 0.13, 1.0)
		(s as Node3D).position = Vector3(sin(k * 2.1) * 0.25 + t * 0.3, 1.2 + t * 1.6, -0.6 + cos(k * 1.7) * 0.2)
		(s as Node3D).scale = Vector3.ONE * (0.6 + t * 1.4)
		k += 1


func _sync_couriers(alpha: float) -> void:
	var p := sim.player()
	var live := {}
	for j in p.jobs:
		if j.state != Job.State.INBOUND:
			continue
		live[j.id] = true
		var node: Node3D = _job_nodes.get(j.id)
		if node == null:
			node = Node3D.new()
			_vehicle_mesh(&"sprinter", Vendors.get_vendor(j.vendor)["color"], node)
			add_child(node)
			_job_nodes[j.id] = node
		var pos := j.prev_pos.lerp(j.pos, alpha)
		var dir := j.heading
		var right := dir.cross(Vector3.UP).normalized()
		node.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), pos + right * 0.68 + Vector3(0, 0.06, 0))
	for id in _job_nodes.keys():
		if not live.has(id):
			_job_nodes[id].queue_free()
			_job_nodes.erase(id)


func _sync_vendors() -> void:
	var p := sim.player()
	for i in _vendor_nodes.size():
		var n: Dictionary = _vendor_nodes[i]
		var vd := Vendors.get_vendor(i)
		var open := p.vendors_unlocked.has(i)
		var col: Color = n["color"]
		var k := 0
		for st in n["stripes"]:
			(st as MeshInstance3D).material_override = mat((col if open else Color("6f6b66")) if k % 2 == 0 else Color("e9dfc8"))
			k += 1
		var lbl: Label3D = n["status"]
		var packing := 0.0
		for j in p.jobs:
			if j.vendor == i and j.state == Job.State.PACKING:
				packing = maxf(packing, j.timer)
		if not open:
			lbl.text = "CLOSED · LV %d" % vd["level"]
			lbl.modulate = Color("c8bfae")
			lbl.font_size = 40
		elif packing > 0.0:
			lbl.text = "PACKING %dm" % ceili(packing)
			lbl.modulate = Palette.AMBER.lightened(0.3)
			lbl.font_size = 54
		else:
			lbl.text = ""


func _sync_depots() -> void:
	for c in sim.companies:
		var boxes: Array = _depot_boxes[c.id]
		var items: Array = []
		items.append_array(c.waiting)
		items.append_array(c.sorting)
		for i in boxes.size():
			var mi: MeshInstance3D = boxes[i]
			if i < items.size():
				mi.visible = true
				var p: Parcel = items[i]
				var col := Palette.PARCEL
				if p.heavy():
					col = Palette.PARCEL_HEAVY
				elif p.kind == Parcel.Kind.EXPRESS:
					col = Palette.PARCEL_EXPRESS
				mi.material_override = mat(col)
			else:
				mi.visible = false


func _sync_pins() -> void:
	var want := {}
	for p in sim.active:
		if p.company != Sim.PLAYER:
			continue
		if not want.has(p.house):
			want[p.house] = p.kind == Parcel.Kind.EXPRESS
		elif p.kind == Parcel.Kind.EXPRESS:
			want[p.house] = true
	for hid in _pins.keys():
		if not want.has(hid):
			_pins[hid].queue_free()
			_pins.erase(hid)
	for hid in want.keys():
		var express: bool = want[hid]
		var pin: Node3D = _pins.get(hid)
		if pin == null or pin.get_meta("express") != express:
			if pin:
				pin.queue_free()
			pin = _make_pin(express)
			pin.set_meta("express", express)
			_pins[hid] = pin
		var h: Dictionary = sim.city.houses[hid]
		var base := 4.0 if h["floors"] == 1 else 5.1
		pin.position = h["pos"] + Vector3(0, base + sin(_time * 2.2 + hid) * 0.12, 0)
		pin.rotation.y = _time * 0.8 + hid


func _make_pin(express: bool) -> Node3D:
	# A little floating parcel with tape, instead of a generic map pin.
	var root := Node3D.new()
	var col := Palette.PIN_EXPRESS if express else Palette.PIN
	var tag := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.55, 0.7)
	tag.mesh = bm
	tag.material_override = mat(col, 0.6)
	tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tag)
	var tape := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.72, 0.57, 0.16)
	tape.mesh = tm
	tape.material_override = mat(Color("e9dfc8"))
	tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tape)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.02
	cm.height = 1.2
	stem.mesh = cm
	stem.position.y = -0.85
	stem.material_override = mat(Palette.INK)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stem)
	add_child(root)
	return root


func _make_bracket() -> Node3D:
	var root := Node3D.new()
	var m := unshaded(Palette.ORANGE)
	var hw := 0.95
	var hl := 1.75
	var arm := 0.45
	var th := 0.08
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector3(sx * hw, 0.08, sz * hl)
			box(Vector3(arm, th, th), corner + Vector3(-sx * arm * 0.5, 0, 0), m, root, false)
			box(Vector3(th, th, arm), corner + Vector3(0, 0, -sz * arm * 0.5), m, root, false)
	return root


func _sync_bracket() -> void:
	if selected_van == null or not _van_nodes.has(selected_van.id):
		_bracket.visible = false
		return
	var node: Node3D = _van_nodes[selected_van.id]
	_bracket.visible = true
	var pulse := 1.0 + sin(_time * 4.0) * 0.04
	_bracket.transform = Transform3D(node.transform.basis.orthonormalized().scaled(Vector3(VAN_SCALE * pulse, 1.0, VAN_SCALE * pulse)), node.transform.origin)


func _sync_daylight() -> void:
	var h := sim.minute_of_day() / 60.0
	var day_f := 0.0
	if h >= 7.0 and h < 17.5:
		day_f = 1.0
	elif h >= 17.5 and h < 20.5:
		day_f = 1.0 - (h - 17.5) / 3.0
	elif h >= 5.0 and h < 7.0:
		day_f = (h - 5.0) / 2.0
	var dusk := 0.0
	if h >= 15.5 and h < 20.5:
		dusk = 1.0 - absf(h - 18.0) / 2.5
	elif h >= 5.0 and h < 8.0:
		dusk = 1.0 - absf(h - 6.5) / 1.5
	dusk = clampf(dusk, 0.0, 1.0)
	var sky := Palette.SKY_NIGHT.lerp(Palette.SKY_DAY, day_f).lerp(Palette.SKY_DUSK, dusk * 0.6)
	env.background_color = sky
	env.fog_light_color = sky.darkened(0.15)
	sun.light_energy = lerpf(0.18, 0.85, day_f)
	sun.light_color = Color("8f9ccf").lerp(Color("ffe2bf"), day_f).lerp(Color("ff9f6a"), dusk * 0.7)
	env.ambient_light_color = Color("4a5578").lerp(Color("8f98ad"), day_f)
	env.ambient_light_energy = lerpf(0.4, 0.5, day_f)
	var night := 1.0 - day_f
	_window_mat.emission_energy_multiplier = night * 1.8
	_lamp_mat.emission_energy_multiplier = 0.2 + night * 3.0
	_shop_window_mat.emission_energy_multiplier = 0.3 + night * 1.5


# ------------------------------------------------------------- graphics settings

## Applies the world-level graphics options from GameSettings.
func apply_graphics(s: GameSettings) -> void:
	# Shadows: Off / Low / High
	sun.shadow_enabled = s.shadows > 0
	if s.shadows == 1:
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		_shadow_dist = 110.0
		sun.shadow_blur = 1.0
	elif s.shadows == 2:
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		_shadow_dist = 180.0
		sun.shadow_blur = 1.4
	sun.directional_shadow_max_distance = _shadow_dist
	env.fog_enabled = s.fog == 1
	# Detail: Low hides most of the woods, fences, parked cars and crosswalks;
	# Medium keeps half the woods; High shows everything.
	for mmi in _forest:
		if mmi:
			var mm := (mmi as MultiMeshInstance3D).multimesh
			mm.visible_instance_count = [int(mm.instance_count * 0.25), int(mm.instance_count * 0.6), -1][s.detail]
	if _fences:
		_fences.visible = s.detail >= 1
	if _crosswalks:
		_crosswalks.visible = s.detail >= 1
	for car in _cars:
		(car as Node3D).visible = s.detail >= 2
	# Cheap houses: skip shadow casting from small props on Low.
	var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if s.detail >= 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mmi in _forest:
		if mmi:
			(mmi as MultiMeshInstance3D).cast_shadow = cast


# ------------------------------------------------------------- picking & fx

func pick_van(screen_pos: Vector2, cam: Camera3D) -> Van:
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var best: Van = null
	var best_d := 1.8
	for c in sim.companies:
		for v in c.vans:
			var vp := van_render_pos(v) + Vector3(0, 0.8, 0)
			var t := (vp - from).dot(dir)
			var d := (from + dir * t).distance_to(vp)
			if d < best_d:
				best_d = d
				best = v
	return best


func _on_delivered(p: Parcel, v: Van, pay: float) -> void:
	if v.company != Sim.PLAYER:
		return
	var l := Label3D.new()
	l.font = _font_mono
	l.text = ("+$%d" % int(round(pay))) if not p.late else ("LATE +$%d" % int(round(pay)))
	l.font_size = 64
	l.pixel_size = 0.01
	l.outline_size = 16
	l.outline_modulate = Palette.INK
	l.modulate = Color("b9d98f") if not p.late else Color("f09a86")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.outline_render_priority = 9
	var start: Vector3 = sim.city.houses[p.house]["pos"] + Vector3(0, 2.8, 0)
	l.position = start
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", start + Vector3(0, 1.6, 0), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.tween_property(l, "outline_modulate:a", 0.0, 1.2).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
