class_name Calls
extends RefCounted
## Phone calls during the day. One rings every couple of game hours; the clock
## stops until you pick an answer. Effects live in Sim._answer_call() so they
## stay deterministic. Text can use {van}, {driver}, {district}, {cond}.
##
## "needs": what must exist for the call to make sense ("van_on_road",
## "van_worn", "late_today", "vendor").
## Option "cost" is cash the answer needs up front.

const DATA := {
	"rush_drop": {"caller": "A shop owner", "title": "Same-hour delivery?",
		"text": "\"I need one parcel across town within 45 minutes. I'll pay $45 for it.\"",
		"options": [{"label": "Deal", "desc": "An express parcel worth $45 is ready to load now. Due in 45 min."},
			{"label": "Can't today", "desc": "Nothing happens."}]},
	"flat_tire": {"caller": "{driver}", "title": "Flat tire!", "needs": "van_on_road",
		"text": "\"Boss, {van} has a flat. I can change it myself, or we call roadside.\"",
		"options": [{"label": "Change it yourself", "desc": "{van} is stuck for 20 min."},
			{"label": "Call roadside", "desc": "$40. Back on the road in 5 min.", "cost": 40.0}]},
	"rattle": {"caller": "{driver}", "title": "A worrying rattle", "needs": "van_worn",
		"text": "\"{van} is making a noise. It's at {cond}% condition.\"",
		"options": [{"label": "Pull over and check", "desc": "{van} stops for 15 min and gains +15% condition."},
			{"label": "Keep driving", "desc": "Nothing happens now. Breakdown risk stays as it is."}]},
	"complaint": {"caller": "An angry customer", "title": "Complaint", "needs": "late_today",
		"text": "\"My parcel was late and I'm telling the whole of {district} about it!\"",
		"options": [{"label": "Refund them", "desc": "$30. Your reputation in {district} is spared.", "cost": 30.0},
			{"label": "Apologise", "desc": "Free, but walk-in share in {district} -4%."}]},
	"sick": {"caller": "{driver}", "title": "Calling in sick", "needs": "van_any",
		"text": "\"I feel terrible. Can I go home?\"",
		"options": [{"label": "Hire a temp", "desc": "$50 for a temp driver. {driver} rests: mood +20.", "cost": 50.0},
			{"label": "Ask them to stay", "desc": "Free, but {driver}'s mood -25."}]},
	"fuel_sale": {"caller": "Elm St. fuel station", "title": "Fuel sale",
		"text": "\"Half price for fleet customers, three hours only. Pay the sign-up fee and fill up.\"",
		"options": [{"label": "Sign up", "desc": "$35. Fuel costs half for the next 3 hours.", "cost": 35.0},
			{"label": "No thanks", "desc": "Nothing happens."}]},
	"bulk": {"caller": "A partner vendor", "title": "Bulk order", "needs": "vendor",
		"text": "\"We've got a big order going out. Want it at time and a half?\"",
		"options": [{"label": "Take it", "desc": "A job with 1.5x pay starts packing now. Express promise."},
			{"label": "Too busy", "desc": "Nothing happens."}]},
	"poach": {"caller": "{driver}", "title": "Zoomer is calling", "needs": "van_any",
		"text": "\"Zoomer offered me more money. I'd rather stay... if you can match it.\"",
		"options": [{"label": "Match the offer", "desc": "$70. {driver} stays happy: mood +15.", "cost": 70.0},
			{"label": "Wish them luck", "desc": "40% chance they leave: a new driver takes over {van} (knows no districts)."}]},
	"radio": {"caller": "Maple FM", "title": "Radio ad", "text": "\"We've got a 30-second slot before the traffic report.\"",
		"options": [{"label": "Buy the slot", "desc": "$60. Walk-in share +3% in every district.", "cost": 60.0},
			{"label": "Pass", "desc": "Nothing happens."}]},
	"thanks": {"caller": "A happy customer", "title": "A thank-you", "text": "\"Your driver saved my day. I'm sending a tip for the team!\"",
		"options": [{"label": "Thank them", "desc": "+$25 and every driver's mood +5."}]},
}
const ORDER := ["rush_drop", "flat_tire", "rattle", "complaint", "sick", "fuel_sale", "bulk", "poach", "radio", "thanks"]
const FIRST := 8.5 * 60.0          # no calls before 08:30
const LAST := 19.5 * 60.0          # or after 19:30
const GAP := [80.0, 160.0]         # minutes between calls


static func get_call(id: String) -> Dictionary:
	return DATA[id]


## Fills {van}, {driver}, {district}, {cond} from the call's context.
static func fill(text: String, ctx: Dictionary) -> String:
	for k in ctx.keys():
		text = text.replace("{%s}" % k, str(ctx[k]))
	return text


static func cost(id: String, option: int) -> float:
	return float(DATA[id]["options"][option].get("cost", 0.0))
