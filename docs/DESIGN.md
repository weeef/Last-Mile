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
