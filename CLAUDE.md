# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

**Perisol** is a turn-based hex-territory strategy board game for 1–4 players, targeting **PC via Love2D (Lua)**. Milestones **M0 Sandbox**, **M1 Core Loop** and **M1.5 Buildings & Infrastructure** (see `plan.md`) are implemented: a hot-seat game of 20 rounds (Production → Resolution → Action) on a seeded random hex map, with shared Long Mạch production, Chi Phối territory (influence zone vs owned land, buy/retake tiles, HQ C1–C5, Subsidiary C1–C3), Basic buildings C1–C3 with multi-tile footprints (upgrade in place, demolish), strategic-resource and terrain effects, passive income, Expedition/Knight and Trade units, roads, player-to-player trade, Derived buildings D-01..D-05 with materials, Special buildings S-01..S-05 with auras, the Rebel, scoring and a results screen. Cards (M2), characters (M3), the industrial layer (coal, oil, rail, pipeline, durability) and polish/multiplayer (M4+) are not built yet. M1 and M1.5 still need human playtests (see the `plan.md` P2 checklist and P3 phase I) to tune `constants.lua`; the rules the docs leave open are in `docs/Decisions.md` D-014..D-021.
### Commands

`make` is the single entry point for people, agents and CI (`make help` lists the targets). Override the tools with `make LOVE=/path/to/love LUA=luajit`; the defaults are `love` and `luajit`. Core and specs run under plain `luajit`; only the `it.love` cases need LÖVE.
- `make check`: the pre-commit gate. Runs `layer`, `test`, the golden hash, a 10-game smoke sim and `cover`. It must be green before every commit.
- `make layer`: greps the single-writer rules: no `love.*` in `src/core`; `player.res` written only by `wallet.lua`; the Rebel position only by `rebel.lua`; `state.roads` only by `roads.lua`; `state.units` added or removed only by `units.lua`.
- `make test`: all specs under `luajit` (`tools/test.lua` fails if a `tests/*_spec.lua` is missing from `SPECS`). `make test-love`: the same specs inside LÖVE (`love . --test`).
- `make hash`: checks the final-state hashes of the golden seeds against `tests/fixtures/golden_hashes.lua`. `make hash-write` regenerates them, only for an intentional rule or bot change.
- `make sim N=100 [BASE=1]`: random games, invariants checked after every turn. `make sim-rich N=10` tops up resources so HQ C3+, Derived and trade appear.
- `make sweep N=30 BASE=5000 [RICH=1]`: sweeps a seed range and writes `build/repro/<seed>.lua` on failure; `make repro F=build/repro/5006.lua` replays one.
- `make cover`: counts how often the fixed batch reaches each command and event kind. It fails on an uncovered kind that is not listed in `tools/cover_gaps.lua`, and on a listed kind that is now covered.
- `make run ARGS="--newgame --seed 5"` launches the game. `make shot NAME=a.png ARGS="--newgame"` saves a screenshot and quits.
- Windows: `run.bat` and `test.bat` are one-line shims for the same flags. LÖVE is at `C:\Program Files\LOVE\`, not on PATH, so set `make LOVE=` to that path there.
- Scene dev flags (pass through `ARGS=`): `--sandbox` (M0 map viewer), `--newgame` (straight into a game; with `--seed N --players 1-4`), `--results` (results screen of a simulated game), `--shot name.png` (screenshot into `%APPDATA%/LOVE/perisol`, then quit), `--size 1024x576` (window size for layout checks).
- Dev helpers for screenshots/UI checks: `--play N` (auto-play N random commands first), `--until PHASE` (auto-play until that phase), `--demo loss|upgrade|demolish|unit|suppress|trade|reply|derived|sub|special|specialpopup` (canned positions and UI states, `src/dev/demo.lua`), `--give gold=20,alloy=5` (add resources to every player at start; not recorded in `history`), `--drive N` (clicks the real UI for N turns via `src/dev/drive.lua`; real-time, so a full game takes minutes). Use `lovec.exe` (console build) for `--drive`, since `love.exe` swallows stdout.
- Game keys: Space roll · E end turn · Esc cancel/pause · F5/F9 quicksave/quickload · F1 debug · Z zones · wheel zoom · RMB-drag/WASD pan. Sandbox keys: R new seed · 1–4 players · Z zones · F1 debug.

### Code conventions
- `src/core/` is pure Lua and must **never call `love.*`** (keeps it testable headless and reusable for AI/multiplayer). `src/render/`, `src/scenes/`, `src/ui/`, `src/input/`, `src/save.lua` and `src/dev/` hold all LÖVE-specific code.
- **Every state change goes through `Game.check` / `Game.apply`** (`src/core/game.lua`; commands `placeHQ, roll, rebelStep, chooseLoss, trade, placeVote, buyTile, upgradeHQ, upgradeSub, build, upgrade, demolish, buyUnit, moveUnit, foundSub, suppress, garrison, disband, upgradeRoad, proposeTrade, buildDerived, redeemBond, buildSpecial, upgradeSpecial, fortressStrike, respond, endTurn`). UI, the simulator, future AI and multiplayer all use this one API, and `Game.legal` lists valid commands. Scenes only read `state` and send commands. `Game.price(state, pid, kind, a, b)` is the one price source for core and UI; `Game.afford` and `Game.affordBuild` wrap it.
- Game state (`src/core/state.lua`) is plain data. The map is **not** saved: it is regenerated from `(seed, players)`. Save files carry a `version` (`C.SAVE_VERSION`); replay = seed + `state.history`. `State.new` declares every field (`false` = not set yet), so adding one means bumping `C.SAVE_VERSION`, adding a step to `MIGRATIONS` (`src/core/game.lua`) and a save fixture in `tests/fixtures/saves`. `Game.load` rejects malformed or invalid saves (`Invariants.shape`, then `Invariants.check`).
- **Buildings are keyed by uid** (`state.buildings[uid]` + `state.occupied["q,r"]`, `src/core/structures.lua`) so they can span several tiles; never index `state.buildings` by tile. Strategic resources lost to demolish live in `state.lostStrategic`, so read them through `Structures.strategicAt`. Turn-start upkeep runs the steps in `Upkeep.steps` (`src/core/upkeep.lua`) in declared order: demolish → passives (includes Derived cleanup and counting) → units (D-021). `Upkeep.register` appends a step. Questions to other players mid-turn use the generic `prompt` phase (`Game.openPrompt` + `respond`, registry `Game.prompts`).
- **Single writers:** `Wallet` (`src/core/wallet.lua`) is the only module that writes `player.res`; the few direct writes (initial setup, migration, `rich` top-up) carry a `-- wallet:ok` marker. `Rebel.moveTo`, `Roads.build/upgrade/damage*` and `Units.spawn/remove` are the only writers of the Rebel position, `state.roads` and `state.units`. `make layer` checks these.
- **Keys and ids:** tile keys `"q,r"` are built and parsed only in `src/core/hex.lua` (`Hex.key`, `Hex.keyQR`, `Hex.unkey`); `State.key` and `State.unkey` are aliases. Khu Chợ lookups go through `Structures.marketsOf` (predicate `Structures.isMarket`). Strategic ids are named constants in `src/data/strategic.lua` (`Strategic.HARBOR` = `TN-10`), and core has no `"TN-xx"` literal. Level thresholds are named in `src/config/constants.lua` (e.g. `C.HQ_KNIGHT_LEVEL`, `C.SEVEN_CANCEL_FAITH`).
- Auras of Special buildings are read from `src/core/aura.lua` (no dependency cycle with Rebel, Units, Territory, Production). Derived buildings are instances in `state.derived`; Special buildings are normal structures with ids `S-0x`.
- Randomness goes through `src/core/rng.lua` (deterministic, seeded) — not `math.random` / `love.math`. (Cosmetic UI randomness, such as the dice-roll animation, may use `love.math`.)
- Production modifiers register into `Production.modifiers` (`src/core/modifiers.lua`; stages Base → Character → Tech → Aura → Strategic → Road, floor at the end).
- UI text uses Be Vietnam Pro (`assets/fonts/`), which lacks arrow/geometric glyphs, so write words instead of symbols. Keys map to named actions in `src/input/actions.lua`.
- Balance and map-gen numbers live in `src/config/constants.lua`; static data keyed by doc IDs in `src/data/`.
- Hex grid: axial `(q, r)`, pointy-top, odd-r offset for the rectangular map; sprites are 32×32 with pitch 32×24. Decisions are logged in `docs/Decisions.md`.

All design docs are written in **Vietnamese**. Game terms (Long Mạch, Phiến Quân, Sắc Lệnh, Chi Phối, etc.) should be kept as-is in identifiers' comments and UI text, not translated loosely. English equivalents exist for some entities (e.g. terrain `Plains`, `Forest`; units `Expedition`, `Trade`) in `docs/Perisol_Data.md`.

### Contracts and tests
- **Adding a contract** (a shape guard or a single-writer rule) needs all three answers from `docs/Architecture_Hardening_Plan.md` §1: which named content needs it (a card, a character, a D-019 stub); which test goes red without it; and whether the same thing has been repeated three times or caused a bug. If not, write it directly and extract it later.
- **Test principle (project owner):** tests check inputs, results and side effects. They do not check how something is implemented: internal structure, internal names, module load order, or source text. Structural rules belong to `make layer`. Do not write tests to raise coverage or to reach a count.
- **Before commit:** `make check` must be green. If a rule or event order changes on purpose, run `make hash-write` and commit the new fixture with the change; for a refactor, the golden hash must stay the same.
- **New spec file:** add its name to `SPECS` in `tests/runner.lua`; `make test` fails until you do.

## Design documents (source of truth)

| File | Contents |
|---|---|
| `docs/Perisol_GDD_v1.2_Full.md` | Master GDD, transcribed 1:1 from `Perisol_GDD_v1.2.pdf` (keep it identical to the PDF, do not add notes inside it): core loop, map, resources, dice, characters, territory, buildings, infrastructure, cards summary, setup & scoring, roadmap (§13.1) |
| `docs/Perisol_Data.md` | Static data tables exported from `Perisol Data.xlsx`: terrains (DH-xx), strategic resources (TN-xx), buildings with costs/footprints (B/D/S-xx), building×terrain placement matrix, infrastructure, units (U-xx), unit actions (A-xx), movement-cost table, durability rules, modifier order, **tunable constants**, unit FSM states, open design Q&A |
| `docs/Perisol_Buildings_v1.0.md` | Detailed per-building descriptions (Basic → Derived → Special) |
| `docs/Perisol_Cards_v1.2.md` | All 80 cards: 30 Tech (T-ENG/…, 5 schools × 6, 3 levels each), 30 Edicts (Tức Thì / Phản Ứng / Nội Tại), 20 Global Events (rounds 5/10/15/20) |

When implementing data, use the IDs from these docs (`DH-01`, `TN-05`, `B-01.2`, `D-03`, `S-04`, `U-01K`, `A-03`, `T-ENG-02`, `HT-03`) as stable keys so code can be traced back to the design.

**Docs disagree in places.** For example, valid terrains for Trại Khai Thác / Nhà Văn Hóa differ between the GDD §8.1, the Data "Công trình" sheet, and the "Đặt công trình" matrix. `Perisol_Data.md` is the newest and most detailed; prefer it for numbers and placement rules, and flag the conflict to the user rather than silently picking one. Rows marked "ĐỀ XUẤT" (proposed) or "Dự kiến có thay đổi" are not final. The Data doc (unit FSM section) and the GDD cover page mention "Godot 4 / C#"; that is a leftover, and the target engine is Love2D/Lua. Where the full GDD differs from the implemented M1 rules (influence zone vs owned land, retake cost, cluster control, Rebel movement/spawn, starting resources, trading), the open items are listed in `docs/Decisions.md` D-012 — ask before changing those rules.

## Core game architecture (cross-document summary)

- **Turn structure:** Game = 20 rounds; round = each player's turn; turn = **Production → Resolution → Action**, then the dice pass to the next player. A Global Event is flipped at rounds 5/10/15/20.
- **Dice & Long Mạch:** 2 custom d6 with faces Science(1), Culture(2), Engineering(3), Faith(4), Gold(5), Hex(6). Production is **shared**: every player's matching buildings produce on any player's roll (`output = building level × base output × matching dice count`). The Hex face only benefits the active player. A sum of 7 means no production and triggers the Rebel (Phiến Quân).
- **Resolution order:** Rebel (on 7) → Global Event → Edict cards → character skills.
- **Resources:** 5 core (Khoa Học, Văn Hóa, Kỹ Thuật, Tín Ngưỡng, Vàng), plus derived materials (Hợp Kim, Giấy, Thép, Lụa, Tín Phiếu) and industrial ones (Than, Dầu Mỏ).
- **Map:** hex grid, randomly generated each game. 7 of the 12 terrain types are drawn per game. The settlement and landmark counts each equal players + 1. Each tile may also carry a strategic resource whose *tile bonus* needs no ownership and whose *building bonus* does.
- **Territory has 3 tiers:** influence zone (radius around HQ/Subsidiary) → contested (votes below threshold) → owned (Lãnh thổ thực hữu, enough Chi Phối votes for that distance). Only owned tiles accept buildings.
- **Buildings:** Basic (5 types × 3 levels; higher levels occupy multi-hex shapes) → Derived (formed when two qualifying basics are adjacent or road-connected; they produce materials) → Special (need materials and multi-tile footprints, and emit auras). HQ has 5 levels and Subsidiary has 3, both gating features.
- **Units:** no player-vs-player combat. Units pass through each other. Harm comes only via the Rebel, Edicts, or infrastructure sabotage. Movement uses per-terrain costs (∞ = impassable) with road bonuses. Infrastructure durability is **per tile**, and route durability = MIN over its tiles.
- **Modifier application order:** Base → Character → Tech → Building aura → Strategic resource → Road. Round down at the final step.
- **Characters:** 5 (Địa Sư, Thương Nhân, Pháp Sư, Tướng Quân, Học Sĩ). Each has 1 passive skill and 4 alternate win conditions, which are checked alongside end-of-game scoring.
- **Rules the GDD leaves open are decided in `docs/Decisions.md`.** D-006 covers Chi Phối thresholds and the Hex face, D-007 starting resources and setup, D-008 sum-of-7 and production, D-009 Rebel effects, D-010 C1 placement and scoring, D-011 the M1 architecture, and D-012 the differences between the full GDD PDF and M1, D-013 the M1 rules changed to follow the PDF (territory model, starting resources), and D-014..D-019 the M1.5 rules: D-014 scope, footprints, upgrade in place, demolish losing the TN, passives; D-015 units; D-016 roads, Trade unit, Market rule, player trade; D-017 HQ C3–C5, Subsidiary C2–C3, Knights; D-018 Derived buildings; D-019 Special buildings; D-020 keep the tile after a TN-06 loss; D-021 explicit turn-start order (demolish → passives → units). Open items are listed at the end of D-014..D-019. Read these before changing any rule. Record new decisions there rather than editing the design docs.

Balance numbers live in `Perisol_Data.md` §8.1 ("HẰNG SỐ CÂN BẰNG"). Keep them as named constants in a single config module (e.g. `MAX_EXPEDITION_PER_PLAYER`, `SUPPRESS_THRESHOLD_EXPEDITION`) so playtesting can tune them without touching logic.

## Roadmap context

Milestones from GDD §13.1: Sandbox (M0) → Core Loop (M1) → Buildings & Infrastructure (M1.5) → Cards (M2) → Characters (M3) → Polish (M4) → Multiplayer (M5). M2–M3 are complete **as designs only**; M0, M1 and M1.5 (except the deferred industrial layer) are implemented.

## Git Commit Guidelines
- Never append or include the "Co-authored-by: Claude" line in any git commit messages.
- Commit messages must strictly contain only the title and description of the changes made, without any AI authorship metadata.
