class_name Palette
extends RefCounted
## One place for every color. World is muted dusk; UI is a dispatcher's desk:
## cream paper tickets, dark ink, a few stamp colors.

# ---------------------------------------------------------------- world
const GRASS := Color("5f7a52")
const GRASS_DARK := Color("4f6c47")
const LAWN := Color("6d8a5b")
const SIDEWALK := Color("b8ad97")
const ROAD := Color("41444f")
const ROAD_LINE := Color("d8c79f")
const SKY_DAY := Color("8b929c")
const SKY_DUSK := Color("b07f68")
const SKY_NIGHT := Color("1b1d29")
const TRUNK := Color("5e4636")
const TREE_GREENS: Array[Color] = [Color("4e6e45"), Color("5b7c4a"), Color("3f5c45"), Color("6b8350")]

const HOUSE_COLORS: Array[Color] = [
	Color("c08a7b"), Color("c9a96e"), Color("8fa58b"), Color("7d93a8"),
	Color("9c8aa8"), Color("b5876a"), Color("d1c3a4"), Color("7a9c98"),
]
const ROOF_COLORS: Array[Color] = [
	Color("6e4440"), Color("7a5a33"), Color("4d5f4a"), Color("3d4c5e"),
	Color("5a4a63"), Color("6b4532"), Color("6d6250"), Color("3e5653"),
]
const CAR_COLORS: Array[Color] = [Color("8c3b33"), Color("2f4b63"), Color("c9c1ad"), Color("3f4a3c"), Color("6f6a7d")]

# Companies
const PLAYER := Color("e0663a")
const RIVAL := Color("7d5fa8")

# Parcels / pins
const PARCEL := Color("c49a62")
const PARCEL_EXPRESS := Color("c8553d")
const PARCEL_HEAVY := Color("7a6a55")
const PIN := Color("e3b04b")
const PIN_EXPRESS := Color("d4573e")

# ---------------------------------------------------------------- UI
const INK := Color("211f27")
const INK_2 := Color("2d2a33")
const INK_3 := Color("3a3641")
const PAPER := Color("efe6d0")
const PAPER_2 := Color("e4d8bc")
const PAPER_3 := Color("d6c8a7")
const RULE := Color("c3b491")          # ruled lines on paper
const TEXT := Color("211f27")          # on paper
const TEXT_SOFT := Color("6e6656")     # on paper
const TEXT_INV := Color("efe6d0")      # on ink
const TEXT_INV_SOFT := Color("9c937f") # on ink

const ORANGE := Color("e0663a")
const RED := Color("b83a2b")
const GREEN := Color("4f7a46")
const BLUE := Color("2f5f86")
const AMBER := Color("c98a1e")
const PURPLE := Color("7d5fa8")
const SLATE := Color("5b6170")
