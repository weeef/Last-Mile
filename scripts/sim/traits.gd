class_name Traits
extends RefCounted
## Driver traits. Each mixes an upside with a downside or a quirk.

const DATA := {
	&"lead_foot": {"name": "Lead Foot", "desc": "Drives 25% faster", "color": Color("b5483a")},
	&"chatty": {"name": "Chatty", "desc": "Stops take 50% longer, but every on-time drop earns a $3 tip", "color": Color("c98a1e")},
	&"organized": {"name": "Organized", "desc": "Drop-offs are 25% quicker", "color": Color("3f8577")},
	&"rookie": {"name": "Rookie", "desc": "A little slow, but learns routes twice as fast", "color": Color("2f5f86")},
	&"night_owl": {"name": "Night Owl", "desc": "Faster after 6pm, sluggish before 9am", "color": Color("6c5796")},
	&"local": {"name": "Local", "desc": "Knows their home district by heart", "color": Color("4f7a46")},
	&"sunny": {"name": "Sunny", "desc": "Mood never drops below 50", "color": Color("b8962a")},
	&"gearhead": {"name": "Gearhead", "desc": "Babies the engine. Half the wear, rarely breaks down", "color": Color("5b6170")},
	&"heavy_hands": {"name": "Heavy Hands", "desc": "Fast loader, rough on the vehicle", "color": Color("9a5a2e")},
}

const FIRST_NAMES := ["Rosa", "Theo", "Priya", "Marcus", "Juniper", "Dev", "Hana", "Ollie", "Bea", "Kofi",
	"Lena", "Sam", "Mateo", "Ivy", "Arjun", "Noor", "Felix", "Tess", "Quinn", "Yusuf", "Mabel", "Gus"]
const LAST_NAMES := ["Alvarez", "Okafor", "Lindqvist", "Park", "Moreau", "Nakamura", "Reyes", "Bello",
	"Hart", "Ng", "Kowalski", "Dube", "Fontaine", "Haddad", "Sato", "Brennan"]


static func trait_name(id: StringName) -> String:
	return DATA[id]["name"]


static func trait_color(id: StringName) -> Color:
	return DATA[id]["color"]


static func trait_desc(id: StringName) -> String:
	return DATA[id]["desc"]
