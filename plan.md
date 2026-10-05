# Perisol — Development Plan (priority order, top = do first)


## Context

**Current status (updated 2026-10-05):**
- **M0 complete (2026-10-04):** git repo, `conf.lua`/`main.lua`, hex math, seeded mapgen, camera/render sandbox, 29 headless tests (see the P1 checklist). Next: M1 (P2 checklist).
- *(Original scan 2026-10-04: no code, no tests and no git repo existed.)*
- Design docs are rich and mostly complete: GDD v1.2, Data tables, Buildings v1.0, and 80 cards in Cards v1.2.
- Art: one test sheet, `Image/HexaTiles_Test_V001.png`. It holds pixel-art hex tiles (forest, plains, desert, river/water, mountain, snow, settlements, roads) and is not yet sliced into individual sprites.
- Engine: **LÖVE 11.5** is installed at `C:\Program Files\LOVE\`. The `New folder/` directory at the project root is empty and can be deleted.
- Roadmap (GDD §12) is M0 Sandbox → M1 Core Loop → M1.5 Buildings & Infra → M2 Cards → M3 Characters → M4 Polish → M5 Multiplayer. M1.5–M3 are designed on paper only.

**Goal:** turn the design into a playable hot-seat prototype as fast as possible, then layer the systems on in the order of risk and dependency. The guiding rule is to **validate the fun of the core loop (Long Mạch dice + territory) before building the 80 cards**.

**Guiding principles**
1. **Pure game logic is separate from rendering.** `src/core/` has no `love.*` calls. That makes it testable headless with the LÖVE mini-runner (`test.bat`, D-003), and it makes M5 multiplayer possible later.
2. **Data-driven.** All static data lives in `src/data/*.lua`, keyed by doc IDs (`DH-01`, `B-01.2`, `U-01`, `T-ENG-02`…). All balance numbers go in `src/config/constants.lua` (Data §8.1).
3. **Seeded RNG everywhere** (own Park–Miller RNG `src/core/rng.lua`, D-004), so map generation and dice are reproducible for bugs and replays.
4. **Command pattern for player actions.** Every action is `{type, playerId, args}` and goes through `validate()` then `apply()`. This gives undo, logging, AI, and network sync later.

---

## P0 — Unblock: design decisions that must be answered before coding (≈1–2 days, design work)

These are gaps or contradictions found in the docs. Each needs a decision, and the decisions get written back into the docs or into a `docs/Decisions.md` log.

| # | Issue | Where | Needed by | Status |
|---|---|---|---|---|
| 1 | **Chi Phối vote thresholds are never given as numbers.** "Enough votes for that distance" has no table: how many votes at distance 1/2/3, how votes are earned, and how ties resolve. Only indirect hints exist (T-ENG-02: "distance 2 drops to 1", "3+ drops to 2"). | GDD §7 | M1 | ✅ Decided → D-006 |
| 2 | **Starting resources** per player are not defined. | GDD §11.1 step 8 | M1 | ✅ Decided → D-007 |
| 3 | **Map size is inconsistent.** "Radius 3 = 19 tiles" is wrong (radius 2 = 19, radius 3 = 37). The 16:8 vs 32:16 grid sizing is also unclear. Hex orientation (pointy vs flat) needs choosing; the art looks pointy-top. | GDD §3.1 | M0 | ✅ Decided → D-001, D-002 |
| 4 | **Hex face (6):** what exactly does the active player get (claim a tile? draw a card?), and what happens with double Hex? | GDD §3.4 | M1 | ✅ Decided → D-006 |
| 5 | **Sum of 7:** faces are 1–6, so 7 can be 1+6, 2+5 or 3+4. Is 7 checked on the face numbers? (Assume yes.) Do the matching faces still produce on 7? (GDD says no.) | GDD §5.2 | M1 | ✅ Decided → D-008 |
| 6 | **Building terrain conflicts** among GDD §8.1, Data "Công trình" and the Data "Đặt công trình" matrix. Examples: B-01 C1 on Forest/Coast (matrix ✅, building sheet ❌), Nhà Văn Hóa on Settlement. Decide which source wins; the recommendation is the matrix. | Data | M1.5 | 🟡 Partly → D-010 (C1 uses the matrix; C2/C3 at M1.5) |
| 7 | **Production per building level.** GDD has `level × base × matching dice`, but the Data sheet gives explicit per-level outputs (e.g. B-01.3: 3 KT on KT, 2 KT on KH). Recommendation: use the explicit Data table and drop the formula. | GDD §5.2 vs Data | M1 | ✅ Decided → D-008 |
| 8 | **Contested/claim flow:** what action places a Chi Phối token, and what does it cost? | GDD §5.4, §7 | M1 | ✅ Decided → D-006 |
| 9 | **Rebel effects:** "half of the most-held resource" — a tie-break rule is needed. The "Ô có tài nguyên ngoài chủ" row is ambiguous. | GDD §6.2 | M1 | ✅ Decided → D-009 |
| 10 | **Win condition timing:** does a character win end the game immediately or give bonus points? (GDD: "Thắng ngay / điểm thưởng lớn".) | GDD §11.2 | M3 | Open |
| 11 | Leftover references to "Godot 4 / C#" and to U-06 (`ENVOY_LIFETIME_ROUNDS`). U-05 Sứ Giả has a proposed cost. Hảo Cảm (favor) appears in the units sheet but not in the GDD. | Data §8–9 | M1.5 | Open |

**Recommendation:** start M0 in parallel with P0. M0 needs only decision #3. *(Update 2026-10-05: everything M1 needs is decided; #10 and #11 remain open for M1.5/M3.)*

---

## P1 — M0 Sandbox: project skeleton + hex map (≈1 week)

Goal: run `love .` and see a randomly generated hex map that you can pan, zoom and hover with the mouse.

1. **Repo setup**
   - Run `git init` and add a `.gitignore` (e.g. `*.love`, `build/`, `.DS_Store`).
   - Delete the empty `New folder/`.
   - Add `conf.lua` (window 1280×720, resizable, title "Perisol", `t.version = "11.5"`).
   - Add `main.lua` (thin bootstrap that only delegates to a scene manager).
   - Use VS Code + the Lua Language Server, with a `.luarc.json` declaring the `love` global, and a `run.bat` that launches `"C:\Program Files\LOVE\love.exe" .`.
2. **Folder layout**
   ```
   main.lua, conf.lua
   src/config/constants.lua      -- Data §8.1 tunables
   src/data/terrains.lua         -- DH-01..DH-12
   src/data/resources.lua        -- 5 core + materials + Than/Dầu
   src/data/strategic.lua        -- TN-01..TN-12
   src/core/hex.lua              -- axial coords, neighbors, distance, ring, spiral, line, pixel<->hex
   src/core/rng.lua              -- seeded RNG wrapper
   src/core/map.lua              -- Map model (tiles table keyed "q,r")
   src/core/mapgen.lua           -- generator
   src/scenes/                   -- scene manager + sandbox scene
   src/render/                   -- map renderer, camera
   lib/                          -- vendored libs (see below)
   assets/tiles/                 -- sliced sprites from HexaTiles_Test_V001.png
   tests/                        -- busted specs for src/core
   ```
3. **Libraries (vendored, MIT):** `hump` or `classic` for classes/gamestate/camera, `flux` for tweens, `inspect` for debugging, and `busted` for tests (run with a system Lua 5.1 or LuaJIT). Keep the list minimal.
4. **Hex math (`src/core/hex.lua`):** axial/cube coordinates following the Red Blob Games reference. Implement neighbors, distance, ring(radius), range(radius), pixel↔hex for pointy-top, and rounding. Unit-test this thoroughly, since everything depends on it.
5. **Map generation v1 (`src/core/mapgen.lua`):**
   - Draw 7 of the 12 terrains, making sure the required ones (mountain/river/settlement/landmark) are present.
   - Place settlements and landmarks so that each count is players + 1. Settlements are clusters of 2–10 tiles; landmarks use shapes 1/3/4.
   - Scatter strategic resources (TN-xx) according to rarity and allowed terrain. TN-12 appears on 1–2 tiles.
   - Validate that each player has a fair start zone (an HQ-eligible tile with 6 valid neighbors). Re-roll on failure.
   - Seed-based and deterministic.
6. **Rendering:** a camera (pan with drag or WASD, zoom with the wheel), a tile sprite per terrain (fall back to colored polygons until art is sliced), hover highlight, and a debug overlay showing coord, terrain ID and TN ID. Press F1 to toggle the debug overlay and R to regenerate with a new seed.
7. **Slice the art:** cut `HexaTiles_Test_V001.png` into per-terrain sprites, or define quads in `src/render/tileset.lua`.

**Done when** `love .` shows a valid random map, R regenerates it, and the hex tests pass.

### Progress checklist (P1 / M0) — updated 2026-10-04 — P1 complete
- [x] 1. Repo setup — git `main` (`5279bbd`), `.gitignore`, `.gitattributes`, `conf.lua`, `main.lua`, `.luarc.json`, `.vscode/extensions.json`, `run.bat`; removed `New folder/`
- [x] 2. Folder layout + static data (`src/config/constants.lua`, `src/data/{terrains,strategic,resources}.lua`)
- [x] 3. Libraries — decided: none for M0 (own camera/scene manager); tests via LÖVE (`lovec . --test`) instead of busted
- [x] 4. Hex math `src/core/hex.lua` + tests
- [x] 5. Map generation v1 `src/core/mapgen.lua` (+ `rng.lua`, `map.lua`) + tests
- [x] 6. Rendering: camera, hover, debug overlay (F1), regenerate (R)
- [x] 7. Slice art: quads in `src/render/tileset.lua`
- [x] P0 #3 decided: map 16×8 (1–2 players) / 32×16 (3–4 players), pointy-top, sprite 32×32, pitch 32×24 → record in `docs/Decisions.md`

---

## P2 — M1 Core Loop: playable hot-seat game without buildings beyond Basic C1 (≈2–3 weeks)

This is the most important milestone. It proves whether Long Mạch is fun.

1. **Game state model (`src/core/state.lua`):** players, resources, round/turn counter, current phase, map, rebel position and RNG. Make it serializable (save/load to a Lua table → `love.filesystem`).
2. **Turn FSM (`src/core/turn.lua`):** Setup → [Round 1..20: for each player: **Production → Resolution → Action → pass dice**] → End-game scoring. Events fire at rounds 5/10/15/20 (stub them in M1).
3. **Setup flow (GDD §11.1):** generate the map → roll for turn order → place HQs (validate: not Mountain/River/Swamp, all 6 neighbors valid, spacing rule) → give starting resources. Character pick is stubbed until M3.
4. **Dice & Long Mạch (`src/core/dice.lua`, `production.lua`):**
   - Roll 2d6 with custom faces. On a sum of 7: no production, trigger the Rebel.
   - Production is **shared across all players**. Every owned building matching a face produces: Data per-level output × matching dice (D-008). The Hex face benefits only the active player.
   - Apply modifiers through a single pipeline function `applyModifiers(base, ctx)` that follows the order **Base → Character → Tech → Aura → Strategic → Road → floor()**. Build it now, even though only Base and Strategic are used in M1, so later systems just register modifiers.
5. **Territory (`src/core/territory.lua`):** influence zone (radius 1 around HQ/Sub) → Chi Phối votes → contested → owned (thresholds 1/2/3 by distance, D-006). Add a recalculation function and rendering overlays (player color borders, hatched for contested).
6. **Action phase (commands):** trade resources with the bank (4:1, D-007), build a **Basic building at level 1** on owned tiles (terrain matrix), claim/vote Chi Phối, and end turn.
7. **Rebel / Phiến Quân (`src/core/rebel.lua`):** spawn rule, 1d6 steps, player-steered path (A-09: click step by step, no undo), 7-tile blockade, stop effects (halve the resource, steal), and Mountain locked for the first 10 rounds.
8. **Scoring (GDD §11.2):** 1 per owned tile, 3 per landmark, 2 per building C2+, 1 per 5 leftover resources. Show a results screen.
9. **UI (minimum viable):** a top bar with round, active player and phase; a resource panel per player; a dice roll button with animation; an action buttons panel; a building placement ghost showing valid/invalid tiles; tooltips; and a log panel listing every production event ("P2 got +2 KT from Trại Khai Thác via P1's roll"). The log matters because shared production must be legible.
10. **Tests:** production math, territory thresholds, rebel blockade, scoring, and a deterministic full-game simulation with random legal moves (catches crashes and infinite loops).

**Done when** 2–4 people can play 20 rounds hot-seat to a winner in about 30 minutes. **Then run playtest #1** and tune the constants.

### Progress checklist (P2 / M1) — added 2026-10-05
- [x] P0 decisions needed by M1 answered → `docs/Decisions.md` D-006..D-011
- [x] 1. Data + constants: `src/data/buildings.lua` (B-01..B-05 × 3 levels + placement matrix), `src/data/movement.lua`, M1 block in `constants.lua` + `data_spec`
- [x] 2. Core utils: `dice.lua`, `modifiers.lua` (Base→Character→Tech→Aura→Strategic→Road→floor), `serialize.lua` + specs
- [x] 3. Territory `territory.lua`: home 7 tiles, votes, thresholds 1/2/3 (TN-06 −1), contested → owned, locked tiles + spec
- [x] 4. Production `production.lua`: shared Long Mạch, × matching dice, Hex → votes, 7 → nothing, blockade, strategic bonuses + spec
- [x] 5. Rebel `rebel.lua`: spawn rule, 1d6 steered steps with U-03 costs, Mountain lock 10 rounds, 7-tile blockade, loss/steal + tie choice + spec
- [x] 6. Game `game.lua` (commands check/apply/legal/actor, phase FSM, setup, 20 rounds) + `scoring.lua` + versioned save/load + replay; `game_spec`, `sim_spec`, `--sim N`
- [ ] 7. UI foundation: Vietnamese font (Be Vietnam Pro, OFL), theme, widgets, input action map, menu + results scenes
- [ ] 8. Game scene: territory/building/HQ/rebel layers, placement ghost + reasons, HUD (top bar, player panels, dice + animation, actions, log), rebel steering, loss popup, F5/F9
- [ ] 9. Docs + acceptance: CLAUDE.md updated, 2-player hot-seat game to the score screen, `--sim 100` clean
- [ ] Playtest #1 → tune `constants.lua`

---

## P3 — M1.5 Buildings & Infrastructure (≈3 weeks)

Do this in order:
1. **Basic buildings C2/C3 with multi-hex footprints:** triangle (3), 2-adjacent, 4-rectangle, trapezoid/cluster (6), and L (3). Store each shape as a list of axial offsets × 6 rotations. Add placement preview with rotation (Q/E keys). Allow upgrading in place.
2. **Strategic resource bonuses:** tile bonuses (no ownership needed) and building bonuses (ownership needed), applied through the modifier pipeline. Warn the player when demolishing a building on a TN.
3. **HQ L1–5 and Subsidiary L1–3:** costs, gates (round 11+ / round 16+, needs a Market, and so on) and the influence radius increase.
4. **Units:** U-01 Expedition (buy, move with per-terrain cost, flood-fill reachable tiles, A* path preview), A-02 found a Subsidiary (consumes the unit), A-03 suppress the Rebel (1d6 vs threshold, pay 2 TN to guarantee), A-04 garrison, and A-06 disband. Add quotas and upkeep. Build the unit FSM from Data §9 (IDLE/MOVING/EXHAUSTED/…).
5. **Roads & trade:** U-02 auto-builds Dirt Road (Đường Đất) as it moves, road movement bonuses, the Stone Road upgrade, A-07 trade completion with a per-tile fee, and the Market's road requirement to reach HQ.
6. **Derived buildings D-01..D-05:** detect when two qualifying basics are adjacent or road-connected (BFS over the road graph). They produce materials (Hợp Kim, Giấy, Thép, Lụa, Tín Phiếu).
7. **Special buildings S-01..S-05:** large footprints, material costs and **auras** (radius-based modifier registration). Implement each S-ability (dice preview, rebel block, vote ×1.5, Long Mạch radius, cancel 7).
8. **Industrial layer (lowest in M1.5):** Coal Mine, Oil Well, Railway (+ U-02T train transform), Pipeline (U-04 auto transport), and per-tile **durability** with route = MIN(tile), damage sources, and repair (manual / auto from HQ). Consider deferring this to after M3 if time is short; it is the most complex and least core part.

---

## P4 — M2 Cards (≈3 weeks)

1. **Card engine:** data files `src/data/cards/tech.lua`, `edicts.lua`, `events.lua`, generated from `Perisol_Cards_v1.2.md` (30 + 30 + 20). Each card is `{id, name, cost, levels={...}, effect = function/handler key}`. Use an **effect registry** (`effects[cardId] = {onPlay, onTrigger, modifiers}`) plus an event bus (`onRoll`, `onBuild`, `onRebelStop`, `onEventFlip`…) so cards hook in without editing core code.
2. **Global Events:** 4 decks of 5, one flipped at rounds 5/10/15/20, resolved in the Resolution phase in order.
3. **Tech tree:** buy (3 KH + 3 KT), maximum 5 active, upgrade cost `ceil(prev × 1.8) + Gold`, effects registered as modifiers.
4. **Edicts:** buy (2 VH + 2 KT + 2 V), a hidden hand (opponents see only the count; hot-seat needs a "pass the screen" privacy cover). There are 3 timing types:
   - **Tức Thì:** played in the Action phase.
   - **Phản Ứng:** a reaction window. This needs an interrupt/priority prompt system, which is the hardest UI piece in M2.
   - **Nội Tại:** passive.
5. Implement the cards in batches by effect similarity. Write one test per card for its core effect.

## P5 — M3 Characters (≈1.5 weeks)

1. Character select at setup: draw 3, pick 1. Add faction colors.
2. Five passive skills, implemented as modifiers or event hooks (Địa Sư free claim every 3 rounds, Thương Nhân trade bonuses, Pháp Sư extra Edict draw, Tướng Quân rebel control, Học Sĩ tech discount).
3. **20 win conditions** (5 × 4): each is a predicate `check(state, player)` evaluated at end of turn and at game end. Some need stat tracking over time (e.g. "30 Gold for 3 consecutive rounds", "lost 20 resources to the rebel I steered"), so add a per-player **stats/history tracker** early in this milestone.
4. A UI panel showing each player's win-condition progress.

## P6 — M4 Polish (≈3+ weeks, ongoing)

- **Single-player AI** (GDD says 1–4 players). Start with a greedy heuristic AI driven by the command system. *Suggested to start a simple AI right after M1 for solo playtesting.*
- Art pipeline: the full tile set, buildings ×3 levels, HQ visual stages per 5 rounds, unit visuals per HQ stage, and Rebel tiers 1–5.
- Audio: upbeat music and SFX for dice, build and rebel.
- Tutorial / onboarding (target: "learnable in 1 game"), tooltips everywhere, and Vietnamese fonts with full diacritics (bundle a TTF that supports Vietnamese).
- Settings, save/load UI, game speed, and a fast-forward for the AI.
- Balance pass, with all numbers in `constants.lua`. Optionally add a headless batch simulator to collect win-rate stats per character.
- Packaging: a `.love` file + fused Windows `.exe` (build script).

## P7 — M5 Multiplayer (later)

- Use the command log + deterministic seeded RNG as the network protocol (lockstep), or an authoritative host using `lua-enet` (bundled with LÖVE).
- Hidden information (Edict hands) requires a host-authoritative model.
- Handle reconnects and resume from a state snapshot.

---

## Cross-cutting tasks (do continuously)

- **Decisions log:** `docs/Decisions.md`, listing every P0 answer and every doc conflict resolved.
- **Data sync:** consider a small script that regenerates `src/data/*.lua` from `Perisol Data.xlsx` (exported to CSV), so the designer can tune without touching code.
- **Debug tools:** a cheat console (give resources, set the dice, teleport the rebel, jump to round N). This is essential for testing round 15/20 events.
- Run tests on every change: `test.bat` (LÖVE mini-runner, D-003).

## Verification (per milestone)

- **M0:** `love .` → random valid map renders; R regenerates; `test.bat` passes the hex math tests. ✅ Done 2026-10-04.
- **M1:** play a full 20-round, 2-player hot-seat game to a score screen with no errors. The headless random-move simulation runs 100 seeded games without crashing.
- **M1.5–M3:** each new system has unit tests plus a debug scenario (cheat console) to exercise it, and a full game is replayed after each.
- **Playtest gate** after M1 and after M3: collect feedback and tune `constants.lua`.

## Immediate next steps (updated 2026-10-05)

1. P2 step 1: `src/data/buildings.lua`, `src/data/movement.lua`, the M1 block in `constants.lua`, and `data_spec`.
2. P2 step 2: `dice.lua`, `modifiers.lua`, `serialize.lua` and their specs.
3. P2 step 3: `territory.lua` and its spec (rules in D-006).
