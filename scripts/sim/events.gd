class_name Events
extends RefCounted
## Morning dilemmas in a season run: a short story card with two or three
## choices, rolled each morning from day 2. Effects live in Sim._resolve_event()
## so they stay deterministic (they use sim.rng and go through commands).
##
## Option "cost" is cash the choice needs up front (the button greys out without it).

const DATA := {
	"used_van": {"title": "A deal on wheels", "text": "A man called Del is selling a 'barely used' van out of a car park. It rattles.",
		"options": [{"label": "Buy it", "desc": "A Delivery Van in rough shape (condition 35%).", "cost": 250.0},
			{"label": "Walk away", "desc": "Nothing happens."}]},
	"raise": {"title": "The crew wants a raise", "text": "Your drivers cornered you by the coffee machine.",
		"options": [{"label": "Pay a bonus", "desc": "$15 per driver. Everyone's mood +20.", "cost_per_van": 15.0},
			{"label": "Order pizza", "desc": "$30. Everyone's mood +8.", "cost": 30.0},
			{"label": "Say no", "desc": "Everyone's mood -15."}]},
	"influencer": {"title": "Going viral?", "text": "A delivery influencer wants to film your crew for a day.",
		"options": [{"label": "Roll the dice", "desc": "50%: walk-in share +6% everywhere. 50%: a blooper reel, -4%."},
			{"label": "No cameras", "desc": "Nothing happens."}]},
	"card_trader": {"title": "The card trader", "text": "A collector opens a binder of shiny upgrade cards.",
		"options": [{"label": "Buy a Rare", "desc": "$90 for a random Rare or better card, installed now.", "cost": 90.0},
			{"label": "Buy a Common", "desc": "$30 for a random card.", "cost": 30.0},
			{"label": "Just looking", "desc": "Nothing happens."}]},
	"nephew": {"title": "The landlord's nephew", "text": "The landlord asks if his nephew can 'help out' this week.",
		"options": [{"label": "Hire him", "desc": "Pay $40 now. This week's rent is 15% lower.", "cost": 40.0},
			{"label": "Politely refuse", "desc": "Nothing happens."}]},
	"open_day": {"title": "Garage open day", "text": "Gearbox Garage is doing half-price tune-ups this morning only.",
		"options": [{"label": "Tune up everything", "desc": "$25 per vehicle. Every parked vehicle back to 90%+ condition.", "cost_per_van": 25.0},
			{"label": "Not today", "desc": "Nothing happens."}]},
	"mall_sale": {"title": "Sale at the mall", "text": "A huge sale is pulling shoppers into town.",
		"options": [{"label": "Hand out flyers", "desc": "$60. Walk-in demand +30% today.", "cost": 60.0},
			{"label": "Let Zoomer have it", "desc": "Nothing happens."}]},
	"zoomer_offer": {"title": "An offer from Zoomer", "text": "Zoomer's regional manager wants one of your vehicles. They pay well.",
		"options": [{"label": "Sell the worst one", "desc": "Your most worn parked vehicle for 90% of its price."},
			{"label": "Not for sale", "desc": "Nothing happens."}]},
	"gambler": {"title": "Double or nothing", "text": "A regular at the cafe bets you can't guess the coin.",
		"options": [{"label": "Bet $100", "desc": "50%: +$100. 50%: -$100.", "cost": 100.0},
			{"label": "Walk away", "desc": "Nothing happens."}]},
	"coach": {"title": "Hustle seminar", "text": "A motivational speaker is in the break room. Loudly.",
		"options": [{"label": "Book the seminar", "desc": "$50. Hustle filled to the top.", "cost": 50.0},
			{"label": "Skip it", "desc": "Nothing happens."}]},
	"horseshoe": {"title": "A lucky horseshoe", "text": "A street vendor swears this horseshoe is lucky.",
		"options": [{"label": "Buy it", "desc": "$70. Your delivery streak jumps +5.", "cost": 70.0},
			{"label": "Superstition", "desc": "Nothing happens."}]},
}
const ORDER := ["used_van", "raise", "influencer", "card_trader", "nephew", "open_day", "mall_sale", "zoomer_offer", "gambler", "coach", "horseshoe"]


static func get_event(id: String) -> Dictionary:
	return DATA[id]


## Cash an option needs right now (0 if free).
static func cost(id: String, option: int, vans: int) -> float:
	var o: Dictionary = DATA[id]["options"][option]
	return float(o.get("cost", 0.0)) + float(o.get("cost_per_van", 0.0)) * vans
