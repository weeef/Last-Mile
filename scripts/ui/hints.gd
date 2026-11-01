class_name Hints
extends Control
## First-time tips: the first time a mechanic shows up, a short note explains
## it. Each one appears once per profile (Profile.hints_seen); "No more tips"
## turns them all off. The game pauses while a tip is open.

signal opened
signal dismissed

const DATA := {
	"first_day": {"title": "Every vehicle costs money", "body": "Drivers earn $33/h while working and $8/h parked, all night too, and driving burns fuel. Hover your cash to see where money went; the evening report breaks it all down. Hover anything else for an explanation, or press F1 for the handbook."},
	"job_arrived": {"title": "Parcels at the depot", "body": "New parcels take 6 minutes to sort, then vehicles with auto-load fill up with the most urgent ones first. A vehicle stamped LOADED is waiting for you to SEND it (or turn on Auto-send in RULES)."},
	"late": {"title": "A late drop", "body": "Late parcels pay only 30%, break your streak, bust that vehicle's route hand and lower your reputation in the district (fewer walk-in customers). The route sheet shows predicted lateness in red before you send."},
	"not_home": {"title": "Nobody home", "body": "Some customers are only home after a time (the purple tag). Arriving earlier wastes the trip: the parcel rides back to the depot for another try and your streak breaks. Put those stops last, or use Call Ahead (C)."},
	"breakdown": {"title": "Breakdown!", "body": "Worn vehicles break down more (1.5% per driving hour at 70% condition, 8% at 30%). The tow truck arrives in 25 min and takes the parcels back to the depot. Send a rescue from the vehicle panel to save them. Tow $45 + repair $160. A $60 service would have prevented most of this."},
	"rush": {"title": "Rush order", "body": "Rush jobs pay x1.8 but must be taken within 20 minutes, are packed twice as fast, and are due 1 hour after reaching your depot. Keep a vehicle free if you want them."},
	"draft": {"title": "Pick an upgrade", "body": "Each card shows exactly what it changes under it. Vehicle mods go on one vehicle; company perks help everything. Reroll for a new hand, or skip for $40."},
	"shop": {"title": "Market night", "body": "Buy as many cards as your cash allows, tune up the fleet or refill hustle. Keep an eye on next rent, shown at the bottom."},
	"relic": {"title": "Relics", "body": "Beating a boss client earns a relic: a rule-breaking card you can't get any other way. Some have a downside, so read them."},
	"plan": {"title": "Plan tomorrow", "body": "Choose what kind of day tomorrow will be. Rush days are busier and pay 25% more; Market days end in a shop; Quiet days rest the fleet; Mystery brings an event and a free card. Rent day is always a boss day."},
	"combo": {"title": "Route hands", "body": "A load is scored like a poker hand (see the route sheet): full trucks, one-district sweeps, neighbours on the same street... If the whole route comes back with no late drops, it pays a bonus. One late drop busts it."},
	"streak": {"title": "Streak", "body": "On-time drops in a row raise the pay of every drop: +2% each, up to x1.5 at 25. Late drops and nobody-home break it. It resets every morning."},
	"event": {"title": "Morning events", "body": "Some mornings bring a situation with choices. Each choice says what it costs and does. You must answer it before picking a contract."},
	"boss": {"title": "Boss client", "body": "Rent day! A boss client's rule is in force all day, whether or not you take their contract. Beat their contract for cash and a relic. Rent is taken at 21:00."},
	"twist": {"title": "Twist", "body": "A twist changes today's rules (see the line under the clock; hover it for numbers). The briefing warns about them a day ahead."},
	"level": {"title": "Level up", "body": "Lifetime earnings raised your business level: a bigger fleet cap and new partners or vehicles. Hover the level bar (top left) to see every level and what it unlocks."},
	"call": {"title": "The phone's ringing", "body": "Calls come in a few times a day: customers, drivers, vendors. The clock stops until you answer. Each answer says what it costs and what happens, so read before you click."},
	"staff": {"title": "Hiring staff", "body": "Applicants turn up every morning in the STAFF tab. Each role (mechanic, accountant, marketer...) gives a perk for a daily wage. Your business level decides how many you can keep: 1 at level 1, up to 4."},
	"hustle": {"title": "Hustle is full", "body": "You earn 1 hustle per on-time drop, but it caps at 10. Spend it on the powers on the left (keys Z X C V B) instead of wasting it."},
}

var profile: Profile
var _queue: Array = []
var _card: PanelContainer
var _title: Label
var _body: Label


func _ready() -> void:
	theme = UIKit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = UIKit.paper(16)
	var st := _card.get_theme_stylebox("panel") as StyleBoxFlat
	st.border_color = Palette.BLUE
	st.border_width_left = 8
	st.border_width_bottom = 6
	_card.custom_minimum_size.x = 460
	var v := UIKit.vbox(8)
	_card.add_child(v)
	var h := UIKit.hbox(8)
	h.add_child(UIKit.stamp("Tip", Palette.BLUE, 12))
	_title = UIKit.head("", 20, Palette.TEXT)
	h.add_child(_title)
	v.add_child(h)
	_body = UIKit.label("", 14, Palette.TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 430
	v.add_child(_body)
	var actions := UIKit.hbox(8)
	var off := UIKit.button("No more tips", "paper", 13)
	off.pressed.connect(func():
		profile.hints_seen["_off"] = true
		profile.save()
		_queue.clear()
		_close())
	actions.add_child(off)
	actions.add_child(UIKit.spacer())
	var ok := UIKit.button("Got it", "go", 15)
	ok.pressed.connect(_close)
	actions.add_child(ok)
	v.add_child(actions)
	add_child(_card)
	_card.visible = false


func showing() -> bool:
	return _card.visible


## Queues tip `id` if this profile hasn't seen it.
func trigger(id: String) -> void:
	if profile == null or profile.hints_seen.get("_off", false) or profile.hints_seen.has(id) or _queue.has(id):
		return
	profile.hints_seen[id] = true
	profile.save()
	_queue.append(id)
	if not _card.visible:
		_next()


func _next() -> void:
	if _queue.is_empty():
		return
	var d: Dictionary = DATA[_queue.pop_front()]
	_title.text = String(d["title"]).to_upper()
	_body.text = d["body"]
	_card.visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().move_child(self, -1)
	opened.emit()


func _close() -> void:
	_card.visible = false
	if _queue.is_empty():
		dismissed.emit()
	else:
		_next()


func _process(_d: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		position = Vector2.ZERO
		size = vp
	if _card.visible:
		if get_index() != get_parent().get_child_count() - 1:
			get_parent().move_child(self, -1)    # stay above sheets opened after us
		_card.size = _card.get_combined_minimum_size()
		_card.position = Vector2(floorf((vp.x - _card.size.x) * 0.5), 150.0)
