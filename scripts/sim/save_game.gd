class_name SaveGame
extends RefCounted
## Saves and loads the whole simulation to one of three slots.
## The town layout is rebuilt from the seed; everything else (money, fleet,
## drivers, parcels in flight, jobs, garage queue, RNG state…) is stored as
## plain data with Godot's binary var format.

const SLOTS := 3
const VERSION := 1

const PARCEL_F := ["id", "company", "house", "district", "kind", "weight", "vendor", "job_id", "pay_amount",
	"created", "deadline", "stage", "stage_times", "van_code", "late"]
const DRIVER_F := ["name", "traits", "home_district", "mood", "familiarity", "delivered_today",
	"delivered_total", "late_total", "hired_day", "avatar_color"]
const MOVER_F := ["pos", "prev_pos", "heading", "path", "path_i", "odometer"]
const VAN_F := ["id", "number", "company", "code", "type", "slots", "max_kg", "state", "route_total", "node",
	"target_node", "timer", "wait", "ready", "condition", "breakdowns", "shop_reason", "shop_waiting", "shop_timer"]
const JOB_F := ["id", "vendor", "houses", "weights", "total_kg", "pay", "express", "promise", "expires", "state", "timer"]
const COMPANY_F := ["money", "level", "lifetime_revenue", "auto_dispatch", "dispatch_threshold", "max_wait",
	"auto_service", "delivered_today", "ontime_today", "delivered_total", "ontime_total", "ontime_yesterday",
	"money_start_of_day", "revenue_today"]


static func path(slot: int) -> String:
	return "user://save_%d.sav" % slot


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## Small summary for the title screen, or {} if the slot is empty/unreadable.
static func meta(slot: int) -> Dictionary:
	var d := _read(slot)
	return d.get("meta", {}) if not d.is_empty() else {}


static func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))


static func most_recent_slot() -> int:
	var best := -1
	var best_t := -1
	for s in range(1, SLOTS + 1):
		var m := meta(s)
		if not m.is_empty() and int(m.get("saved_at", 0)) > best_t:
			best_t = int(m["saved_at"])
			best = s
	return best


# ------------------------------------------------------------- save

static func save(sim: Sim, slot: int) -> bool:
	var p := sim.player()
	var d := {
		"version": VERSION,
		"meta": {
			"company": p.name, "level": p.level, "level_name": p.level_info()["name"],
			"day": sim.day(), "clock": sim.clock_now(), "money": p.money,
			"fleet": p.vans.size(), "saved_at": int(Time.get_unix_time_from_system()),
		},
		"seed": sim.seed_value,
		"rng_state": sim.rng.state,
		"tick": sim.tick,
		"next_parcel_id": sim.next_parcel_id,
		"next_van_id": sim.next_van_id,
		"next_job_id": sim.next_job_id,
		"share": Array(sim.share),
		"score": sim.score.duplicate(true),
		"last_day": sim.last_day,
		"commands": sim.commands.duplicate(true),
		"garage_working": sim.garage_working.map(func(v): return v.id),
		"garage_queue": sim.garage_queue.map(func(v): return v.id),
		"active": sim.active.map(func(x): return x.id),
		"recent": sim.recent.map(func(x): return x.id),
	}
	# Every parcel the sim still knows about, stored once and referenced by id.
	var parcels := {}
	for x in sim.active:
		parcels[x.id] = _pack(x, PARCEL_F)
	for x in sim.recent:
		parcels[x.id] = _pack(x, PARCEL_F)
	var comps := []
	for c in sim.companies:
		var cd := _pack(c, COMPANY_F)
		cd["sorting"] = c.sorting.map(func(x): return x.id)
		cd["waiting"] = c.waiting.map(func(x): return x.id)
		cd["vendors_unlocked"] = c.vendors_unlocked.keys()
		var vans := []
		for v in c.vans:
			var vd := _pack(v, VAN_F)
			vd.merge(_pack(v, MOVER_F))
			vd["driver"] = _pack(v.driver, DRIVER_F)
			vd["cargo"] = v.cargo.map(func(x): return x.id)
			for x in v.cargo:
				parcels[x.id] = _pack(x, PARCEL_F)
			vans.append(vd)
		cd["vans"] = vans
		var jobs := []
		for j in c.jobs:
			var jd := _pack(j, JOB_F)
			jd.merge(_pack(j, MOVER_F))
			jobs.append(jd)
		cd["jobs"] = jobs
		for x in c.sorting:
			parcels[x.id] = _pack(x, PARCEL_F)
		for x in c.waiting:
			parcels[x.id] = _pack(x, PARCEL_F)
		comps.append(cd)
	d["companies"] = comps
	d["parcels"] = parcels
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(d)
	f.close()
	return true


# ------------------------------------------------------------- load

static func load_slot(slot: int) -> Sim:
	var d := _read(slot)
	if d.is_empty() or int(d.get("version", 0)) != VERSION:
		return null
	var sim := Sim.new()
	sim.setup(int(d["seed"]), [])          # rebuilds the identical town
	sim.rng.state = d["rng_state"]
	sim.tick = d["tick"]
	sim.next_parcel_id = d["next_parcel_id"]
	sim.next_van_id = d["next_van_id"]
	sim.next_job_id = d["next_job_id"]
	sim.share.assign(d["share"])
	sim.score = d["score"]
	sim.last_day = d["last_day"]
	sim.commands.assign(d["commands"])

	var parcels := {}
	for id in d["parcels"].keys():
		var x := Parcel.new()
		_unpack(x, d["parcels"][id], PARCEL_F)
		parcels[int(id)] = x
	var pick := func(ids: Array) -> Array:
		var out := []
		for id in ids:
			if parcels.has(int(id)):
				out.append(parcels[int(id)])
		return out
	sim.active.assign(pick.call(d["active"]))
	sim.recent.assign(pick.call(d["recent"]))

	var vans_by_id := {}
	for i in sim.companies.size():
		var c := sim.companies[i]
		var cd: Dictionary = d["companies"][i]
		_unpack(c, cd, COMPANY_F)
		c.sorting.assign(pick.call(cd["sorting"]))
		c.waiting.assign(pick.call(cd["waiting"]))
		c.vendors_unlocked = {}
		for k in cd["vendors_unlocked"]:
			c.vendors_unlocked[int(k)] = true
		c.vans.clear()
		for vd in cd["vans"]:
			var v := Van.new()
			_unpack(v, vd, VAN_F)
			_unpack(v, vd, MOVER_F)
			v.driver = Driver.new()
			_unpack(v.driver, vd["driver"], DRIVER_F)
			v.cargo.assign(pick.call(vd["cargo"]))
			c.vans.append(v)
			vans_by_id[v.id] = v
		c.jobs.clear()
		for jd in cd["jobs"]:
			var j := Job.new()
			_unpack(j, jd, JOB_F)
			_unpack(j, jd, MOVER_F)
			c.jobs.append(j)
	sim.garage_working.clear()
	for id in d["garage_working"]:
		sim.garage_working.append(vans_by_id[int(id)])
	sim.garage_queue.clear()
	for id in d["garage_queue"]:
		sim.garage_queue.append(vans_by_id[int(id)])
	return sim


# ------------------------------------------------------------- helpers

static func _pack(o: Object, fields: Array) -> Dictionary:
	var d := {}
	for k in fields:
		var v = o.get(k)
		d[k] = v.duplicate() if (v is Array or v is Dictionary) else v
	return d


static func _unpack(o: Object, d: Dictionary, fields: Array) -> void:
	for k in fields:
		if not d.has(k):
			continue
		var cur = o.get(k)
		if cur is Array:
			(cur as Array).assign(d[k])
		else:
			o.set(k, d[k])


static func _read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var()
	f.close()
	return v if v is Dictionary else {}
