class_name HelpScreen
extends ModalSheet
## The "?" page: a glossary of every mechanic with the real numbers.
## Open it from the HUD's ? button, F1, or the pause menu.

signal closed

var sim: Sim
var _topic := 0
var _list: VBoxContainer
var _title: Label
var _text: Label
var _topics: Array = []


func setup(p_sim: Sim) -> void:
	sim = p_sim
	_topics = topics(sim)
	var top := UIKit.hbox(12)
	var tv := UIKit.vbox(-6)
	tv.add_child(UIKit.label("HOW EVERYTHING WORKS", 13, Palette.TEXT_SOFT, "head"))
	tv.add_child(UIKit.head("Dispatcher's handbook", 34, Palette.TEXT))
	top.add_child(tv)
	top.add_child(UIKit.spacer())
	var x := UIKit.button("Close (Esc)", "ink", 15)
	x.pressed.connect(func(): closed.emit())
	top.add_child(x)
	body.add_child(top)
	var cols := UIKit.hbox(16)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	cols.add_child(sc)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIKit.flat(Palette.PAPER_2, 2, 18, 14))
	right.custom_minimum_size = Vector2(640, 560)
	var rv := UIKit.vbox(10)
	right.add_child(rv)
	_title = UIKit.head("", 26, Palette.TEXT)
	rv.add_child(_title)
	_text = UIKit.label("", 15, Palette.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 600
	rv.add_child(_text)
	cols.add_child(right)
	body.add_child(cols)
	_rebuild()


func _rebuild() -> void:
	ModalSheet.clear(_list)
	var last_cat := ""
	for i in _topics.size():
		var t: Dictionary = _topics[i]
		if t["cat"] != last_cat:
			last_cat = t["cat"]
			_list.add_child(UIKit.head(last_cat, 12, Palette.TEXT_SOFT))
		var b := UIKit.button(t["title"], "ink" if i == _topic else "paper", 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func():
			_topic = idx
			_rebuild())
		_list.add_child(b)
	var cur: Dictionary = _topics[_topic]
	_title.text = String(cur["title"]).to_upper()
	_text.text = cur["body"]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and (e.keycode == KEY_ESCAPE or e.keycode == KEY_F1):
		get_viewport().set_input_as_handled()
		closed.emit()


static func topics(s: Sim) -> Array:
	var w := Van.WAGE_PER_MIN * 60.0
	var van_fuel := Van.BASE_SPEED * Sim.TICKS_PER_HOUR * Van.FUEL_PER_UNIT
	var t: Array = []
	t.append({"cat": "Basics", "title": "Your day", "body":
		"07:00 morning briefing: weather, road works, any boss or twist, and you pick a contract.\n\nDuring the day: take jobs from vendors, let parcels sort and load, then SEND vehicles out. Walk-in customers also order on their own.\n\n21:00 evening report: what you earned and spent, stars, then pick an upgrade card (or shop, or a relic). Then choose what tomorrow will be. The night runs by itself."})
	t.append({"cat": "Basics", "title": "Sending vehicles", "body":
		"A vehicle at the depot loads parcels by itself (auto-load) and shows LOADED when it's full or nothing else fits. Press SEND in the fleet list or on its route sheet. SEND? sends it before it's full.\n\nAuto-send (RULES tab) sends loaded vehicles for you when they're full enough or have waited long enough, and immediately if any parcel aboard is due within 35 minutes.\n\nAuto-load turns itself off for a vehicle when you unload a parcel by hand, so your changes stick. Turn it back on from the route sheet."})
	t.append({"cat": "Basics", "title": "Route sheet", "body":
		"Click a vehicle at the depot to plan its trip. Each stop shows the predicted arrival: red = late, yellow = nobody home yet. Reorder with the arrows, add or remove parcels in the AT DEPOT tab.\n\nIt also shows what the trip costs per hour, which mods are active, and the route hand (combo multiplier). You can sell a parked, empty vehicle here for 40% of its price."})
	t.append({"cat": "Money", "title": "Where money goes", "body":
		"Wages: $%.0f/h per driver while working, $%.0f/h parked. Drivers are paid all night too, so an unused vehicle still costs about $%.0f a day.\n\nFuel: about $%.0f/h of driving for a van (box truck x1.7, sprinter x0.85). Fuel cards cut this.\n\nService $%d. Breakdown: tow $%d + repair $%d.\n\nHover your cash to see everything since the last report; the evening report lists it all, by category and by vehicle." % [w, w * 0.25, w * 0.25 * 24.0, van_fuel, int(Sim.SERVICE_COST), int(Sim.TOW_COST), int(Sim.REPAIR_COST)]})
	t.append({"cat": "Money", "title": "What drops pay", "body":
		"Walk-ins: $11 standard (150 min promise), $18 express (60 min). Signature +$4.\n\nVendor jobs: base $10 + $6 per stop + $0.32 per kg + distance, +$25 for heavy freight, x1.3 express, x1.8 rush, times the vendor's rate. The pay is split between the stops. Hover a job's price for its exact breakdown.\n\nA late drop pays 30%. On-time drops add your streak bonus, and clean runs add a combo bonus."})
	t.append({"cat": "Money", "title": "Rent and the season", "body":
		"A season is 12 days. Rent is due at 21:00 on days 3, 6, 9 and 12, and rises every week. It comes out of your cash.\n\nShort? You pay what you have and the rest plus a 20% late fee moves to next week (a final notice). Run out of final notices and you're evicted. Pay day 12's rent to win.\n\nEvening savings interest: $5 per $100 in the till, up to $25."})
	t.append({"cat": "Money", "title": "Business level", "body": Explain.levels(s.player()).replace("> ", "") + "\n\nLevel is based on lifetime earnings and never goes down."})
	t.append({"cat": "Vehicles", "title": "Condition and breakdowns", "body":
		"Condition drops about 2% per hour of driving (box trucks and Heavy Hands faster, Gearheads slower).\n\nBreakdown risk per hour of driving: 0.2% at 90%, 1.5% at 70%, 4% at 50%, 8% at 30%. Rain x1.5. Worn vehicles are also slower (x0.85 at 0%).\n\nA service ($%d, %d min) restores 100%%. A breakdown strands the vehicle: send a rescue for its parcels before the tow ($%d) hauls everything back to the depot, then a repair ($%d, %d min) gets it to 95%%. Gearbox Garage has 2 bays shared with Zoomer; the vehicle panel shows your place in line." % [int(Sim.SERVICE_COST), int(Sim.SERVICE_MIN), int(Sim.TOW_COST), int(Sim.REPAIR_COST), int(Sim.REPAIR_MIN)]})
	t.append({"cat": "Vehicles", "title": "Vehicle types", "body": "\n\n".join(VehicleTypes.ORDER.map(func(k): return Explain.vehicle_type(k)))})
	t.append({"cat": "Vehicles", "title": "Upgrade cards", "body":
		"Vehicle mods go on one vehicle (vans and sprinters have 2 slots, box trucks 3; a new mod on a full vehicle replaces the oldest). Company perks apply to everything.\n\nWhen you pick a card, the report shows exactly what changes, e.g. 'Fuel: $7.9/h -> $5.5/h'. Rarities: Common, Uncommon, Rare, Ultra rare, and Relics (only from boss clients).\n\nReroll costs $60, then $120... Skipping pays $40."})
	t.append({"cat": "Drivers", "title": "Mood", "body":
		"Mood (0-100) changes driving speed: x0.85 at 0, x1.00 at 50, x1.15 at 100.\n\nUp: parked (+6/h), in the shop (+3/h), on-time drops (+0.4).\nDown: driving (-2/h), late drops (-2), nobody home (-1), breakdowns (-8), stranded (-10/h).\n\nSunny drivers never drop below 50; the Comfy Cab mod stops mood dropping at all."})
	t.append({"cat": "Drivers", "title": "Knows area", "body":
		"Each driver learns the four districts. Familiarity makes drop-offs quicker: up to 35% at 100%.\n\nEvery drop in a district teaches +2% (Rookies +4%), so about 50 drops to know a district fully. Locals start at 100% in their home district."})
	var tr: Array = []
	for k in Traits.DATA.keys():
		tr.append("%s: %s." % [Traits.trait_name(k), Traits.trait_desc(k)])
	t.append({"cat": "Drivers", "title": "Traits", "body": "Every driver has two traits:\n\n" + "\n".join(tr)})
	t.append({"cat": "Customers", "title": "Walk-in share and reputation", "body":
		"Each walk-in order goes to you with a chance equal to your share in its district (10% to 75%). Every 10 minutes share moves toward whoever has the better reputation there.\n\nReputation rises with on-time drops (early ones count most) and falls with late drops and parcels that are already overdue. The DISTRICTS tab shows each district and whether you're rising or falling. Loyalty Cards add +6% to every walk-in chance for good."})
	t.append({"cat": "Customers", "title": "Delivery windows", "body":
		"'after 17:00': nobody is home before then. Arriving early wastes the trip and the parcel rides back to the depot (and breaks your streak).\n'due by 12:00': a tighter deadline, nothing more.\n'Sign': needs a signature, +$4, the drop takes 60% longer.\n'Heavy': needs a box truck or a Liftgate Kit."})
	t.append({"cat": "Customers", "title": "Zoomer Express", "body":
		"Your rival. They compete with you for walk-in customers through district reputation, and they share Gearbox Garage's 2 bays, so their vans can be ahead of yours in the queue.\n\nThey never take your vendor jobs. They buy vans when busy (up to 6) and sell them when broke."})
	t.append({"cat": "Conditions", "title": "Weather and traffic", "body":
		"Rush hour (07:30-09:00, 16:30-18:00): roads 22% slower.\nRain: roads 12% slower, breakdowns x1.5, 15% more walk-in orders.\nFog: roads 8% slower, drop-offs 15% slower.\nRoad works: 0-2 streets closed for the day, drawn on the map; routes go around.\n\nThe line under the clock shows what's in effect right now; hover it for numbers. Route sheet arrival times already include traffic."})
	t.append({"cat": "Conditions", "title": "Twists, bosses, day types", "body":
		"Each week a twist hits its middle day (Gridlock, Heatwave, Inspector, Zoomer Blitz, Viral Unboxing, Tight Promises). The briefing warns you the day before.\n\nRent days are boss days: a named client sets a rule for the whole day. Beat their contract for a relic.\n\nEach evening you choose tomorrow: Rush (busier, +25% pay), Market (cheaper vehicles, a shop tonight), Quiet (calm, repairs and morale), Mystery (an event and a free card) or Regular."})
	t.append({"cat": "Scoring", "title": "Streak", "body":
		"Every on-time drop in a row adds 2% to the pay of every drop, up to x1.5 at 25 (more with Hype Train). A late drop or nobody home breaks it, and it starts from 0 every morning."})
	t.append({"cat": "Scoring", "title": "Route hands (combos)", "body":
		"The parcels a vehicle leaves with are scored like a poker hand: Full Truck +0.3, Sweep (3+ stops in one district) +0.4, Neighbors +0.05 per extra stop on a street you already visit (up to +0.3), Big Haul (8+) +0.2, Mega Haul (12+) +0.4, Express Run +0.3, Mixed Bag +0.25, Signed & Sealed +0.2.\n\nIf the whole route comes back with zero late drops, its on-time pay is paid again x (multiplier - 1). One late drop busts it. The route sheet shows the hand while you load."})
	t.append({"cat": "Scoring", "title": "Hustle and powers", "body":
		"Every on-time drop earns 1 hustle (+2 at each streak tier), up to 10. Spend it:\n" + "\n".join(Abilities.ORDER.map(func(k): return "%s (%s, %d): %s" % [Abilities.DATA[k]["name"], Abilities.DATA[k]["key"], Abilities.DATA[k]["cost"], Abilities.DATA[k]["desc"]]))})
	t.append({"cat": "Scoring", "title": "Contracts and stars", "body":
		"Pick one contract each morning. Finish it by 21:00 for its cash and a better card draft (Steady: 4 cards; Ambitious: better odds; Heroic: Rare or better).\n\n" + Explain.stars()})
	t.append({"cat": "Controls", "title": "Keys", "body":
		"Pan: left-drag or WASD. Rotate: right-drag or Q/E. Zoom: wheel. Reset view: H.\nSpeed: Space pauses, 1-4 = 1x/2x/4x/8x. F: skip ahead until something needs you.\nPowers: Z X C V B. Help: F1. Menu: Esc.\n\nHover almost anything for an explanation."})
	return t
