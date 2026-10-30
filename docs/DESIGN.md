# Last Mile — Core Design Brainstorm

*Working draft. A logistics game built to stay fun for 400+ hours.*

---

## 1. The one-sentence pitch

You start with one van and one neighborhood, and grow it into a delivery network that spans a continent. Each layer you master becomes a single building block in the next, bigger layer.

## 2. What makes a game last 400 hours

The games people sink 400+ hours into (Factorio, OpenTTD, Satisfactory, Transport Fever, RimWorld, Mini Metro in short bursts) have the same traits:

1. **No solved state.** The problem keeps shifting: demand grows, moves, and changes type, so a network that worked yesterday has a bottleneck today.
2. **Many valid answers with real tradeoffs.** Cheap, fast and green can't all be maxed at once, so there's always a better version to build.
3. **Scale changes the shape of the problem**, not just the numbers. Routing 10 vans is a different puzzle from balancing 40 sort centers.
4. **Automation buys attention.** Every system you automate frees you to work on the next one. That loop is where the hours come from.
5. **Watching it run is the reward.** A busy, readable network is satisfying to look at.
6. **Self-set goals.** Once the game stops telling you what to do, you still want to "fix that one ugly interchange."

Every system below should serve at least one of these.

---

## 3. The core loop (minute to minute)

```
Packages appear  ->  Flow through your network  ->  Delivered (or late)
      ^                                                    |
      |                                                    v
City grows where  <-  Reputation and money  <-  Score: on-time %, cost/pkg
service is good
```

1. **Demand spawns.** Addresses generate packages, each with a size, a type and a **promise** (2-hour, same-day, next-day, scheduled window).
2. **The player builds flow.** Depots, sort hubs, vehicles, routes and dispatch rules.
3. **The simulation runs.** Vehicles drive real roads, traffic exists, packages queue visibly at bottlenecks.
4. **Results feed back.** On-time deliveries earn money and reputation. Reputation unlocks contracts, and good service makes neighborhoods grow denser, which creates *more and harder* demand.

**The key feedback loop: success creates its own next problem.** A well-served district turns into apartments, then a downtown, and your old van routes collapse under the load. That loop alone carries a lot of hours.

---

## 4. The five core systems

### 4.1 The network (what you build)

| Tier | Building | Role |
|---|---|---|
| Doorstep | Lockers, pickup points, mailrooms | Batch many deliveries into one stop |
| Last mile | Delivery station / micro-hub | Vans, cargo bikes, walkers start here |
| Middle mile | Sort center | Splits inbound freight by destination |
| Line haul | Regional hub, rail yard, airport | Moves bulk between cities |

Buildings have **capacity, throughput, and footprint**. Sorters have lanes, docks have bays, parking lots fill up. Bottlenecks are *physical and visible*: trucks idling at a full dock, packages piling on a conveyor.

### 4.2 Vehicles

Each vehicle class is a different tool, not just "bigger number":

- **Walker / cargo bike:** tiny capacity, ignores traffic, perfect for dense downtown.
- **Van:** the workhorse.
- **Box truck:** big, slow to park, bad in narrow old streets.
- **Semi:** line haul only; needs docks.
- **EV variants:** cheap to run but need charging time and chargers (adds a scheduling layer).
- **Late game:** drones (weight limit, weather-sensitive), autonomous pods, freight rail, cargo planes, ferries.

Vehicles have **shifts and drivers** (optional depth: driver hours, fatigue, skill/familiarity with a route).

### 4.3 Routing and dispatch (the deep system)

This is the system that gives a puzzle-game skill ceiling.

- **Early:** you draw routes by hand and assign vans to zones.
- **Mid:** you set **dispatch rules**, a simple visual rule editor:
  - "If van is 80% full OR it's 9:30, depart."
  - "Priority packages go to Bike Route A first."
  - "If Sort Center 2 is over 90%, divert to Sort Center 3."
- **Late:** full **programmable logistics**: signals, conditions, counters (Factorio-circuits level for players who want it). These are optional but powerful, and the game should never *require* them for normal progress.

Good design rule: **an auto-router always exists** and works "okay." Player-designed rules beat it, so there's always a reason to tinker but never a wall.

### 4.4 Package types (variety that changes the puzzle)

Each type unlocks as a new contract and changes how you have to build:

| Type | New constraint |
|---|---|
| Standard parcels | The baseline |
| Oversized / furniture | Needs 2-person crews, box trucks, appointment windows |
| Fragile | Penalized by multi-hop sorting; rewards direct routes |
| Cold chain (groceries, pharma) | Spoils over time; needs refrigerated vehicles and fast lanes |
| Hazmat | Restricted roads and vehicles |
| **Returns** | Packages flow *backwards*. Reverse logistics is a great mid-game twist |
| B2B freight | Big, scheduled, predictable; dock-to-dock |
| Medical / urgent | Small, very tight deadline, high pay |

### 4.5 The living city

- The city is simulated at a coarse level: zones grow, densify, get new road layouts.
- **Your service quality shapes growth.** Neighborhoods with fast reliable delivery attract shops and residents.
- Cities have **personality**: a hilly port city with ferries and bridges, a strict grid city, a medieval tangle of one-way streets, sprawling suburbs with long distances.
- **Time of day and seasons matter:** rush hour traffic, weekend demand, rain slows bikes, snow closes hills.

---

## 5. The progression spine (how 400 hours is structured)

### Layer 1 — Neighborhood (hours 0–10)
One depot, a few vans, hand-drawn routes. Teaches: promises, capacity, routes.

### Layer 2 — City (hours 10–60)
Multiple delivery stations, a sort center, mixed vehicle types, dispatch rules, lockers. The city grows in reaction to you.

### Layer 3 — Region (hours 60–150)
Connect several cities with line haul. **Zoom out:** each city now runs on the rules and templates you built, and you manage it as a node with stats. You drop back in to fix problems.

### Layer 4 — Nation / Continent (hours 150–400+)
Rail, air, ports, cross-border customs, multiple competing priorities. Markets and contracts at a big scale.

**The "zoom out" idea is the heart of it.** Once you've designed a delivery station you're proud of, you save it as a **template** and stamp it into new districts. Once a city runs itself, it becomes one dot on the regional map. You never lose the micro game, but you're never forced to micromanage what you already solved.

### Peak Season — the recurring "boss fight"
Every in-game year ends with **holiday peak**: demand spikes 3–5x for a few weeks. It's a stress test of everything you built. Players prepare all year (temp drivers, overflow hubs, rental trucks). Surviving peak with a high on-time rate is the big yearly payoff and a natural "one more year" hook.

### Disruptions (keep the network from going stale)
Road construction, bridge closures, storms, a major shipper signing on overnight, a competitor opening nearby, a sort center fire. These should be **readable and fair**: warned ahead when possible, never pure punishment.

---

## 6. Replayability layers (hours 400+)

- **New maps:** handcrafted cities plus procedurally generated ones with seeds.
- **Scenarios:** "Fix this broken network in 30 days," "Deliver to an island city with only ferries," "Zero-emissions city."
- **Optimization challenges with leaderboards:** cost per package, on-time %, CO₂ per package, fewest vehicles. Like Zachtronics histograms: show where your solution sits vs. everyone else.
- **Daily/weekly seeded puzzle** for a quick session.
- **Company traits on a new run:** "Green Courier" (cheap EVs, emissions bonus), "Budget Freight" (cheap labor, low reputation cap), "Premium" (high-paying tight windows).
- **Sandbox mode** with every unlock and no money.
- **Modding:** Godot's text-based scenes and resources make it easy to support custom vehicles, cities and package types. Mods are how sim games reach thousands of hours.

---

## 7. The scoring triangle

Every decision trades off three numbers:

```
          SPEED
         (on-time %)
          /    \
         /      \
      COST ---- GREEN
   (per package) (CO2 per package)
```

Contracts and city policies weight these differently (downtown might cap emissions; a pharma client only cares about speed). This gives "there's always a better build" without needing endless new content.

---

## 8. Making it readable and satisfying

- **Packages are visible.** Little colored boxes on conveyors, in van windows, piling at docks. You should *see* a bottleneck before a stat tells you.
- **Flow overlays:** a heatmap of late packages, congestion, vehicle utilization.
- **Time controls:** pause, 1x, 2x, 4x, plus "skip to next problem."
- **A satisfying delivery "click":** a tiny sound and pop on each drop-off. At scale, it becomes a pleasing hum.
- **Clean, stylized art:** low-poly or flat 2D top-down. Readability beats realism.

---

## 9. Pitfalls to avoid

| Pitfall | Fix |
|---|---|
| Micromanagement burnout | Templates, auto-router, zoom-out abstraction |
| Progress that's only bigger numbers | Each tier must change the *kind* of problem |
| Simulation lag at scale | Simulate individual packages only where the camera is; aggregate into flows elsewhere |
| Punishing randomness | Telegraph disruptions; let players prepare |
| Overwhelming early game | Unlock systems one at a time; first hour uses only vans, houses and one depot |
| A dominant strategy | Contracts and city types that reward different builds |

---

## 10. First prototype (test the fun before building the empire)

**Goal:** prove that the core loop is fun for 30 minutes in a tiny slice.

1. A small grid of roads with ~40 houses (2D top-down in Godot).
2. One depot. Packages spawn at the depot addressed to random houses, each with a deadline.
3. Player buys vans and draws a route (a sequence of stops) for each.
4. Vans drive the roads (`AStar2D` on the road graph), drop off, and return.
5. HUD: money, on-time %, packages waiting.
6. Demand slowly ramps up until the player is forced to rethink routes.

**The question the prototype answers:** *Is it satisfying to spot a bottleneck and fix it?* If yes, everything else is layers on top. If no, change the core before building more.

**Second prototype step:** add a second depot and a sort center so packages travel two hops. That tests whether the network-building feels good.

### Technical notes (Godot 4)
- Keep the **simulation separate from rendering**: a fixed-tick sim (e.g. 10 ticks/sec) in plain GDScript classes, with nodes that just draw the current state. That makes fast-forward, save/load, and scaling much easier.
- Define vehicles, package types and buildings as **custom `Resource` files** (`.tres`) so content is data, not code. Easy to tune and mod.
- Use a **deterministic RNG with seeds** from the start (needed for daily puzzles and leaderboards).
- Road network as a **graph** (intersections = nodes, roads = edges), not just tiles. Routing and traffic both get simpler.

---

## 11. Open questions to decide

- **2D or 3D?** 2D top-down is much faster to build and easier to read. Recommendation: 2D for now.
- **Real-time or turn/day-based?** Real-time with pause fits the "watch it run" pillar.
- **Tone:** cozy and colorful, or grounded and realistic? (Cozy widens the audience; the systems can still be deep.)
- **Competitors:** AI rival companies, or purely you vs. the city?
- **Workers:** are drivers just a cost, or characters with names and traits (RimWorld-style attachment)?

---

## 12. The run and the reasons to come back (v0.5)

The 400-hour sandbox above is the long game. What it lacked was a **session shape**:
a reason to start, stakes in the middle, a clear end, and a reason to start again.
v0.5 adds a roguelike run on top of the existing day loop, borrowing the pressure
curve of "rent" roguelikes and the meta layer of modern deckbuilders.

### The three loops

| Loop | Length | Question it asks | Reward |
|---|---|---|---|
| **Drop** | seconds | Can I keep the streak alive? | Streak multiplier, hotter pay pops |
| **Day** | ~10 min | Which contract, which routes, buy or save? | Stars, contract cash, a card |
| **Season** | 12 days | Can I make rent through Holiday Peak? | Score, reputation, unlocks |
| **Profile** | forever | What do I unlock or beat next? | Charters, heat, HQ upgrades, goals |

### Design rules we followed

1. **Spending vs. saving is the core management tension.** Rent is paid from the till,
   so every van, vendor and reroll is a bet. Interest on savings makes holding cash a
   real choice instead of a wasted one.
2. **Telegraph every threat.** Twists are rolled at the start of each week and shown in
   every briefing until they hit. Losing should feel like a planning mistake, never a
   coin flip.
3. **Forgive once.** The first missed rent is a final notice with a late fee, not
   instant death. New players learn the rule; heat 4 removes the safety net for experts.
4. **A run must end.** Win at day 12 or get evicted. Endings create the summary screen,
   the summary creates the "one more run" moment.
5. **Make the micro loop juicy.** The streak is the slot-machine hum underneath the
   spreadsheet: every on-time drop pays a bit more, tier names pop, the pay numbers grow
   and change color. Breaking it hurts, and cards exist to protect it.
6. **Always show the next carrot.** The title strip, the run summary and head office
   all name the next affordable unlock and the next three goals.
7. **Variety comes from starting conditions, not just content volume.** Charters change
   the opening (fleet, cash, share, rent) and heat changes the rules, so the same town
   plays differently.
8. **Daily run for the habit.** One seeded season per day, no upgrades, a personal best
   and a days-in-a-row streak. Short-session players get a reason to open the game
   every day.

### Tuning knobs (all in `scripts/sim/season.gd` and `profile.gd`)

- `LEASES`: the rent curve. If most first runs die on day 6, lower week 2.
- `STREAK_STEP` / `STREAK_CAP`: how loud the micro loop is.
- `HEAT`: the difficulty ladder.
- `Profile.UPGRADES` / `GOALS` / charter `unlock` costs: the pace of meta progression.
  Target: first unlock after the first or second run, something new every 1–2 runs after.

### Next ideas

- Run modifiers chosen at the start ("Sponsor deals": +risk, +reward).
- A short **boss contract** on peak day with its own reward card.
- Leaderboard upload for the daily seed (the sim is already deterministic).
- Driver legacy: a driver who survives a season can be "retained" into the next run.

---

## 13. Lessons from the greats, and what we took (v0.6)

The problem with v0.5: between the morning and evening sheets you mostly watched vans.
The best roguelikes and logistics games keep your hands busy with **small, frequent,
legible decisions** that compound into big swings. What each one does right, and the
piece of it we copied:

| Game | What it does right | What Last Mile took |
|---|---|---|
| **Balatro** (5M+ sold, GOTY 2024) | Familiar "hands" scored as visible chips × mult; jokers that bend the rules; numbers that explode | **Route hands**: every load scores combos (Sweep, Full Truck, Neighbors…) into a multiplier shown live while you load, paid out with a jackpot pop. **Combo jokers** bend it (Double Down, Postcode Pride) |
| **Slay the Spire** | Branching risk; "?" event rooms with short stories and hard choices | **Morning dilemmas**: a story card with 2–3 choices most mornings, some of them gambles |
| **Luck be a Landlord** | Rent that keeps climbing turns every choice into a budget | Already in v0.5: the climbing lease |
| **Hades** | Active abilities on cooldowns; run-to-run progression with story | **Dispatcher powers** paid with hustle; head office meta (v0.5) |
| **Vampire Survivors** | A constant drip of tiny power-ups; escalating spectacle | Hustle from every drop, streak tiers, pay pops that grow and heat up with the streak |
| **Overcooked / Diner Dash** | Use-it-or-lose-it pressure; many small jobs at once | Hustle is capped at 10, so hoarding wastes it |
| **Into the Breach / FTL** | Threats telegraphed before they hit; perfect information | Weekly twists announced days ahead; route sheet predicts late / not-home and warns "a late stop will bust this hand" |
| **Mini Metro / Mini Motorways** | Tiny rule set, weekly upgrade pick, pressure until collapse, short sessions | Evening card draft, rent pressure, and **Skip ahead**: fast-forward that stops the moment a decision is waiting |
| **Factorio / OpenTTD** | Optimisation you can see; "one more fix" | Route sheet as a puzzle: reorder, swap parcels, chase the bigger hand |
| **The Binding of Isaac** (10M+ sold) | Huge item pool with wild synergies | Cards now combine across four systems: vehicle mods, streak, rent, combos |

### Rules this added to our design

1. **Every 10–20 seconds the player should have something to decide.** Skip ahead takes
   away the empty stretches; hustle powers fill the middle of a route.
2. **Show the math.** The route hand, streak multiplier and rent meter are always on
   screen, so players can plan around them.
3. **Push your luck, with a fair warning.** A bigger hand is worth more and is easier
   to bust. The game tells you before you press Send.
4. **Stack multipliers from different systems** (streak × route hand × cards) so good
   runs feel explosive, while rent keeps rising to match.

### What to watch in playtests

- If routes are almost always clean, raise the risk (more windows, tighter promises)
  or lower combo values in `combos.gd`.
- If hustle piles up unused, the powers are too weak or too expensive (`abilities.gd`).
- If players never pick the risky dilemma options, make the upside bigger.
