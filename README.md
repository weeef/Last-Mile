# Last Mile — Prototype v0.4

A cozy-but-moody 3D logistics game about growing a tiny delivery outfit.
Open this folder in **Godot 4.7** and press **F5**.

![The town at dusk](docs/screenshots/town-dusk.png)

Design notes and the long-term plan live in [docs/DESIGN.md](docs/DESIGN.md).

## How a day goes

1. **Morning briefing (07:00).** See the weather (clear, rain, fog), road works and rush
   hours, then **pick one of three contracts** (Steady, Ambitious, Heroic). Finishing one
   by 21:00 pays cash and improves tonight's card draft.
2. **Take jobs** from the JOBS board. Pay depends on stops, weight and distance. Heavy
   freight needs a box truck (or a Liftgate Kit). **RUSH orders** pop up during the day:
   big pay, 20 minutes to accept, one-hour promise.
3. **Plan and load.** Click a vehicle at the depot to open its **route sheet**: reorder
   stops with the arrows and watch predicted arrival times. Red = late, yellow = nobody
   home yet (some customers are only in after 17:00, some only before noon, some need a
   signature). Load or unload parcels from the AT DEPOT tab. Then **SEND IT**.
4. **React.** Rush hour and rain slow everyone down. Road works close streets for the day.
   If a vehicle **breaks down**, send a **rescue** from the depot to grab its parcels
   before the tow truck hauls them back. Failed "nobody home" drops ride back and need
   another attempt.
5. **Evening (21:00).** Report card with up to 3 stars, then **draft one upgrade card**
   (reroll for cash, or skip for $40). The night shift runs on its own until morning.

## Upgrade cards (the roguelike part)

Four rarities: Common, Uncommon, Rare, **Ultra rare**.

- **Vehicle mods** go on one vehicle. Vans and sprinters have 2 slots, box trucks 3, so
  you build specialists. Examples: Eco Tune, Roof Rack, Reinforced Drivetrain,
  Hybrid Engine, Route GPS, Cargo Tetris, Liftgate Kit, Hypermiler, Comfy Cab, and the
  ultra rares **Turbo** (+45% speed) and **Golden Wrench** (never breaks down).
- **Company perks** apply to everything: Bulk Fuel Deal, Tow Club, Night Sort Crew,
  Friendly Mechanic, Loyalty Cards, Vendor Rep, Mechanic's Friend, and the ultra rare
  **Express Lane** (+30 min on every promise).

Lifetime earnings still raise your **business level** (bigger fleet cap, more vendors).
Auto-dispatch is in RULES for when you'd rather not plan every trip.

## Vehicles

| | Cost | Speed | Parcels | Max load | Notes |
|---|---|---|---|---|---|
| Delivery Van | $550 | 1.0 | 10 | 300 kg | all-rounder |
| Box Truck | $950 | 0.78 | 16 | 900 kg | liftgate (heavy freight), thirstier, wears faster |
| Sprinter Van | $700 | 1.2 | 8 | 180 kg | unlocks at Lv 2 |

## Vendors

Corner Pantry (start) · Sunrise Bakery · Oak & Iron (furniture, needs a box truck)
· Bloom & Co. · Byte Electronics · Pharma Plus. Better vendors pack faster and pay more.

## Title screen and saves

The game opens on a title screen: **Continue** (most recent save), **New game**,
**Load game**, **Settings**, **Quit**. There are **3 save slots**. The game autosaves
at the start of every in-game day, when you leave to the menu, and when you quit.
**Esc** in game opens the pause menu (resume, save, settings, main menu, quit).

Saves store the full game state (fleet, drivers, parcels in flight, jobs, garage
queue, RNG state), so loading is instant and continues exactly where you left off.
Files live in Godot's `user://` folder (`save_1.sav` … `save_3.sav`).

## Settings (pause menu, title screen, or the gear button)

Window mode, resolution, UI scale, VSync and FPS limit, plus a **Low / Medium / High**
graphics preset (3D render scale, anti-aliasing, shadows, fog, scenery detail).
On first launch the game reads the graphics card and picks a preset: integrated or
software GPUs start on Low. The game uses Godot's Compatibility renderer (OpenGL 3.3,
with an ANGLE/DirectX fallback on Windows), so it runs on older and low-end PCs too.
Settings are saved to `user://settings.cfg`.

## Controls

| Action | Input |
|---|---|
| Pan | Left-drag, or WASD / arrows |
| Rotate | Right-drag, or Q / E |
| Zoom | Mouse wheel, or + / − buttons |
| Reset view | H |
| Select a vehicle | Click it, or click its row in FLEET |
| Pause / resume | Space |
| Pause menu | Esc (when nothing is selected) |
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
    save_game.gd        3-slot save/load of the full game state
    cards.gd            Upgrade cards, rarities and the draft roll
    contracts.gd        Daily contracts
    parcel.gd, driver.gd, traits.gd, company.gd, rival_ai.gd
  view/                 3D town built from primitives (world_view.gd), camera, palette
  ui/                   Dispatcher's-desk UI: hud, title, pause, settings, start screen, tutorial, widgets
  settings/             Display + graphics settings and GPU-based preset detection
fonts/                  Barlow, Barlow Condensed, IBM Plex Mono (SIL Open Font License)
tools/
  autoplayer.gd         Scripted player used by the tests
  sim_test.gd           Headless 4-day run with a scripted player + determinism check
  save_test.gd          Save mid-game, load, run both forward and check they match
  screenshot.gd         Renders a PNG (modes: title, picker, settings, briefing, play, route, report, rain)
```

### Multiplayer-ready rules (keep these)

1. The sim only advances with `sim.step()`; it never reads frame time or physics.
2. All randomness comes from `sim.rng` (seeded).
3. Every player or AI action is a command sent with `sim.submit({...})`.

Run the sim test: `godot --headless --path . -s tools/sim_test.gd`

## Screenshots

| Morning briefing | Route sheet |
|---|---|
| ![](docs/screenshots/briefing.png) | ![](docs/screenshots/route-sheet.png) |
| **Evening report and card draft** | **A van on its route** |
| ![](docs/screenshots/day-report.png) | ![](docs/screenshots/selected-van.png) |
