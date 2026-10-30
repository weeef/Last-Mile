# Last Mile — Prototype v0.2

A cozy-but-moody 3D logistics game about growing a tiny delivery outfit.
Open this folder in **Godot 4.7** and press **F5**.

![The town at dusk](docs/screenshots/town-dusk.png)

Design notes and the long-term plan live in [docs/DESIGN.md](docs/DESIGN.md).

## How a game goes

1. **Pick your first two vehicles**: delivery vans, box trucks, or one of each.
2. **Take jobs** from the JOBS board. Vendors post orders; pay depends on the
   number of stops, total weight, and how far they are from your depot.
   Heavy freight (furniture) needs a box truck.
3. The vendor **packs** the order, then their courier drives it to your depot.
4. Parcels are sorted and **loaded**. A vehicle stamped **READY** waits for you:
   press **GO** (or **Start route**). Turn on **Auto-dispatch** under RULES later.
5. Get paid on delivery. Late drops pay 30% and hurt your reputation.
6. Lifetime earnings raise your **business level** → bigger fleet cap, more vendors.
7. Vehicles **wear out**. Worn ones can **break down**: tow ($45), then they queue
   at **Gearbox Garage** (2 bays, shared with Zoomer Express) for a repair ($160, ~2h).
   A service at the garage is $60 and ~35 min. RULES has an auto-service setting.

The tutorial (offered on the start screen) walks through steps 2–4.

## Vehicles

| | Cost | Speed | Parcels | Max load | Notes |
|---|---|---|---|---|---|
| Delivery Van | $550 | 1.0 | 10 | 300 kg | all-rounder |
| Box Truck | $950 | 0.78 | 16 | 900 kg | liftgate (heavy freight), thirstier, wears faster |
| Sprinter Van | $700 | 1.2 | 8 | 180 kg | unlocks at Lv 2 |

## Vendors

Corner Pantry (start) · Sunrise Bakery · Oak & Iron (furniture, needs a box truck)
· Bloom & Co. · Byte Electronics · Pharma Plus. Better vendors pack faster and pay more.

## Controls

| Action | Input |
|---|---|
| Pan | Left-drag, or WASD / arrows |
| Rotate | Right-drag, or Q / E |
| Zoom | Mouse wheel, or + / − buttons |
| Reset view | H |
| Select a vehicle | Click it, or click its row in FLEET |
| Pause / resume | Space |
| Speed 1x / 2x / 4x / 8x | 1 / 2 / 3 / 4 |

## Code layout

```
scripts/
  main.gd               Clock, start screen, tutorial, wiring
  sim/                  Pure, deterministic simulation (no nodes)
    sim.gd              Step loop, commands, jobs, wear/breakdowns, garage, reputation
    city.gd             Road graph, houses, vendor lots, garage block
    mover.gd            Shared path-following for vehicles and couriers
    van.gd              Vehicle state machine
    vehicle_types.gd    Van / Box Truck / Sprinter stats
    vendors.gd          Vendor list + business levels
    job.gd              A vendor delivery order
    parcel.gd, driver.gd, traits.gd, company.gd, rival_ai.gd
  view/                 3D town built from primitives (world_view.gd), camera, palette
  ui/                   Dispatcher's-desk UI: hud.gd, start_screen.gd, tutorial.gd, widgets
fonts/                  Barlow, Barlow Condensed, IBM Plex Mono (SIL Open Font License)
tools/
  sim_test.gd           Headless 3-day run with a scripted player + determinism check
  screenshot.gd         Renders a PNG (modes: picker, tutorial, play, wide)
```

### Multiplayer-ready rules (keep these)

1. The sim only advances with `sim.step()`; it never reads frame time or physics.
2. All randomness comes from `sim.rng` (seeded).
3. Every player or AI action is a command sent with `sim.submit({...})`.

Run the sim test: `godot --headless --path . -s tools/sim_test.gd`

## Screenshots

| Start screen | A van on its route |
|---|---|
| ![](docs/screenshots/start-screen.png) | ![](docs/screenshots/selected-van.png) |
