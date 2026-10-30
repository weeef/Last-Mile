class_name Traits
extends RefCounted
## Driver traits. Each mixes an upside with a downside or a quirk.

const DATA := {
	&"lead_foot": {"name": "Lead Foot", "desc": "Drives 25% faster", "color": Color("b5483a")},
	&"chatty": {"name": "Chatty", "desc": "Stops take 50% longer, but every on-time drop earns a $3 tip", "color": Color("c98a1e")},
	&"organized": {"name": "Organized", "desc": "Drop-offs are 25% quicker", "color": Color("3f8577")},
	&"rookie": {"name": "Rookie", "desc": "10% slower driving, 15% slower drops, but learns districts twice as fast", "color": Color("2f5f86")},
	&"night_owl": {"name": "Night Owl", "desc": "20% faster after 18:00, 15% slower before 09:00", "color": Color("6c5796")},
	&"local": {"name": "Local", "desc": "Starts knowing their home district 100% (drops there 35% quicker)", "color": Color("4f7a46")},
	&"sunny": {"name": "Sunny", "desc": "Mood never drops below 50", "color": Color("b8962a")},
	&"gearhead": {"name": "Gearhead", "desc": "Half the wear and 60% fewer breakdowns", "color": Color("5b6170")},
	&"heavy_hands": {"name": "Heavy Hands", "desc": "Loads 40% faster, but wears the vehicle 40% faster", "color": Color("9a5a2e")},
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
