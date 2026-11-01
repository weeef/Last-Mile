class_name Driver
extends RefCounted
## A worker with a name, traits, mood and route familiarity.

var name := ""
var traits: Array[StringName] = []
var home_district := 0
var mood := 80.0                 # 0..100
var familiarity: Array[float] = [0.0, 0.0, 0.0, 0.0]   # per district, 0..1
var delivered_today := 0
var delivered_total := 0
var late_total := 0
var hired_day := 1
var avatar_color := Color.WHITE


static func generate(rng: RandomNumberGenerator, day: int) -> Driver:
	var d := Driver.new()
	d.name = "%s %s" % [Traits.FIRST_NAMES[rng.randi_range(0, Traits.FIRST_NAMES.size() - 1)],
		Traits.LAST_NAMES[rng.randi_range(0, Traits.LAST_NAMES.size() - 1)]]
	var pool: Array = Traits.DATA.keys()
	var first: StringName = pool[rng.randi_range(0, pool.size() - 1)]
	var second: StringName = first
	while second == first:
		second = pool[rng.randi_range(0, pool.size() - 1)]
	d.traits = [first, second]
	d.home_district = rng.randi_range(0, 3)
	if d.has(&"local"):
		d.familiarity[d.home_district] = 1.0
	d.mood = rng.randf_range(65.0, 90.0)
	d.hired_day = day
	d.avatar_color = Color.from_hsv(rng.randf(), 0.45, 0.95)
	return d


func has(t: StringName) -> bool:
	return traits.has(t)


func initials() -> String:
	var parts := name.split(" ")
	var s := ""
	for p in parts:
		if p.length() > 0:
			s += p[0]
	return s


## Multiplier on driving speed.
func speed_mult(minute_of_day: float) -> float:
	var m := 1.0
	if has(&"lead_foot"):
		m *= 1.25
	if has(&"rookie"):
		m *= 0.9
	if has(&"night_owl"):
		var h := minute_of_day / 60.0
		if h >= 18.0 or h < 5.0:
			m *= 1.2
		elif h < 9.0:
			m *= 0.85
	m *= 0.85 + 0.3 * (mood / 100.0)   # happy drivers are quicker
	return m


## Multiplier on time spent at each drop-off.
func stop_mult(district: int) -> float:
	var m := 1.0
	if has(&"chatty"):
		m *= 1.5
	if has(&"organized"):
		m *= 0.75
	if has(&"rookie"):
		m *= 1.15
	m *= 1.0 - 0.35 * familiarity[district]   # knowing the area helps a lot
	return m


func wear_mult() -> float:
	if has(&"gearhead"):
		return 0.5
	if has(&"heavy_hands"):
		return 1.4
	return 1.0


func load_mult() -> float:
	return 0.6 if has(&"heavy_hands") else 1.0


func learn(district: int, mult := 1.0) -> void:
	var rate := (0.04 if has(&"rookie") else 0.02) * mult
	familiarity[district] = minf(1.0, familiarity[district] + rate)


func change_mood(delta: float) -> void:
	var floor_v := 50.0 if has(&"sunny") else 0.0
	mood = clampf(mood + delta, floor_v, 100.0)


func mood_word() -> String:
	if mood >= 80.0:
		return "Cheerful"
	if mood >= 60.0:
		return "Content"
	if mood >= 40.0:
		return "Tired"
	return "Grumpy"
