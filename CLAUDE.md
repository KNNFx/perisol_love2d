# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

**Perisol** is a turn-based hex-territory strategy board game for 1–4 players, targeting **PC via Love2D (Lua)**. Milestones **M0 Sandbox**, **M1 Core Loop** and **M1.5 Buildings & Infrastructure** (see `plan.md`) are implemented: a hot-seat game of 20 rounds (Production → Resolution → Action) on a seeded random hex map, with shared Long Mạch production, Chi Phối territory (influence zone vs owned land, buy/retake tiles, HQ C1–C5, Subsidiary C1–C3), Basic buildings C1–C3 with multi-tile footprints (upgrade in place, demolish), strategic-resource and terrain effects, passive income, Expedition/Knight and Trade units, roads, player-to-player trade, Derived buildings D-01..D-05 with materials, Special buildings S-01..S-05 with auras, the Rebel, scoring and a results screen. Cards (M2), characters (M3), the industrial layer (coal, oil, rail, pipeline, durability) and polish/multiplayer (M4+) are not built yet. The designer ran playtest #1 and wrote **GDD 1.6** from it (2026-11-01). GDD 1.6 changes core rules: base resources on tiles, 6 free starting tiles, the tile price and adjacent expansion, Rebel plunder and the HQ block, N = 10 × players rounds, a River build lock, the S-04 redesign, and UI requirements. **The code still follows the older rules.** Applying them is milestone **M1.6** (`plan.md` P3.5), next, before M2; the mapping from current to new rules and the open questions are in `docs/Decisions.md` D-020.
### Commands (LÖVE 11.5 at `C:\Program Files\LOVE\`, not on PATH)
- Run: `run.bat` (= `love.exe .`) opens the menu. Dev flags: `--sandbox` (M0 map viewer), `--newgame` (straight into a game; with `--seed N --players 1-4`), `--results` (results screen of a simulated game), `--shot name.png` (screenshot into `%APPDATA%/LOVE/perisol`, then quit).
- Dev helpers for screenshots/UI checks: `--play N` (auto-play N random commands first), `--until PHASE` (auto-play until that phase), `--demo loss|upgrade|demolish|unit|suppress|trade|reply|derived|sub|special|specialpopup` (canned positions and UI states, `src/dev/demo.lua`), `--give gold=20,alloy=5` (add resources to every player at start; not recorded in `history`), `--drive N` (clicks the real UI for N turns via `src/dev/drive.lua`; real-time, so a full game takes minutes).
- Test: `test.bat` (= `lovec.exe . --test`; headless, exit code 1 on failure). The mini-runner is `tests/runner.lua` (`describe`/`it`/`expect.*`); specs are `tests/*_spec.lua`. There is no standalone Lua/busted on this machine.
- Simulate: `lovec.exe . --sim N` plays N random 2–4 player games headless (invariants checked after every turn) and prints stats; takes seconds. Add `--rich` to top up resources and materials after every turn, so the random games reach HQ C3+, Derived and trade (about 6 s per game). Use `lovec.exe` (console build) rather than `love.exe` for `--drive` and anything where you need to see errors, since `love.exe` swallows stdout.
- Game keys: Space roll · E end turn · Esc cancel/pause · F5/F9 quicksave/quickload · F1 debug · Z zones · wheel zoom · RMB-drag/WASD pan. Sandbox keys: R new seed · 1–4 players · Z zones · F1 debug.

### Code conventions
- `src/core/` is pure Lua and must **never call `love.*`** (keeps it testable headless and reusable for AI/multiplayer). `src/render/`, `src/scenes/`, `src/ui/`, `src/input/`, `src/save.lua` and `src/dev/` hold all LÖVE-specific code.
- **Every state change goes through `Game.check` / `Game.apply`** (`src/core/game.lua`; commands `placeHQ, roll, rebelStep, chooseLoss, trade, placeVote, buyTile, upgradeHQ, upgradeSub, build, upgrade, demolish, buyUnit, moveUnit, foundSub, suppress, garrison, disband, upgradeRoad, proposeTrade, buildDerived, redeemBond, buildSpecial, upgradeSpecial, fortressStrike, respond, endTurn`). UI, the simulator, future AI and multiplayer all use this one API, and `Game.legal` lists valid commands. Scenes only read `state` and send commands.
- Game state (`src/core/state.lua`) is plain data. The map is **not** saved: it is regenerated from `(seed, players)`. Save files carry a `version` (`C.SAVE_VERSION`); replay = seed + `state.history`.
- **Buildings are keyed by uid** (`state.buildings[uid]` + `state.occupied["q,r"]`, `src/core/structures.lua`) so they can span several tiles; never index `state.buildings` by tile. Strategic resources lost to demolish live in `state.lostStrategic`, so read them through `Structures.strategicAt`. Per-turn upkeep steps (demolish completion, passives, derived, units) register into `Upkeep` (`src/core/upkeep.lua`) and run before the dice. Questions to other players mid-turn use the generic `prompt` phase (`Game.openPrompt` + `respond`, registry `Game.prompts`).
- Auras of Special buildings are read from `src/core/aura.lua` (no dependency cycle with Rebel, Units, Territory, Production). Derived buildings are instances in `state.derived`; Special buildings are normal structures with ids `S-0x`.
- Randomness goes through `src/core/rng.lua` (deterministic, seeded) — not `math.random` / `love.math`. (Cosmetic UI randomness, such as the dice-roll animation, may use `love.math`.)
- Production modifiers register into `Production.modifiers` (`src/core/modifiers.lua`; stages Base → Character → Tech → Aura → Strategic → Road, floor at the end).
- UI text uses Be Vietnam Pro (`assets/fonts/`), which lacks arrow/geometric glyphs, so write words instead of symbols. Keys map to named actions in `src/input/actions.lua`.
- Balance and map-gen numbers live in `src/config/constants.lua`; static data keyed by doc IDs in `src/data/`.
- Hex grid: axial `(q, r)`, pointy-top, odd-r offset for the rectangular map; sprites are 32×32 with pitch 32×24. Decisions are logged in `docs/Decisions.md`.

All design docs are written in **Vietnamese**. Game terms (Sản Xuất Chung, Phiến Quân, Sắc Lệnh, Chi Phối, etc.; GDD 1.6 renamed "Long Mạch" to "Sản Xuất Chung", and the code and UI still say Long Mạch until M1.6) should be kept as-is in identifiers' comments and UI text, not translated loosely. English equivalents exist for some entities (e.g. terrain `Plains`, `Forest`; units `Expedition`, `Trade`) in `docs/Perisol_Data.md`.

## Design documents (source of truth)

| File | Contents |
|---|---|
| `docs/Perisol_GDD_v1.6_Full.md` | Master GDD **1.6** (post playtest #1), transcribed 1:1 from `docs/Perisol_GDD_v1.6.docx`. The source file was named "v1.3"; its content says 1.6. Keep the md identical to the docx and add no notes inside it. Covers core loop, map, base resources on tiles (§3.3), strategic resources, dice, characters, territory and tile prices (§7.2), Infantry occupation (§7.4, draft), combat (§7.5, draft), buildings, Port (§8.4, draft), infrastructure, cards summary, setup, scoring and round count (§11.3), UI requirements from playtest #1 (§12.4), roadmap (§13), playtest results (Appendix D) and proposed constants (Appendix E). GDD v1.2 is in git history only. |
| `docs/Perisol_Data.md` | Static data tables exported from `docs/Perisol Data.xlsx` (re-export the whole file when the xlsx changes): terrains (DH-xx), strategic resources (TN-xx), buildings with costs/footprints (B/D/S-xx), building×terrain placement matrix, infrastructure, units (U-xx), unit actions (A-xx), movement-cost table, durability rules, modifier order, **tunable constants**, unit FSM states, open design Q&A |
| `docs/Perisol_Buildings_v1.0.md` | Detailed per-building descriptions (Basic → Derived → Special) |
| `docs/Perisol_Cards_v1.2.md` | All 80 cards: 30 Tech (T-ENG/…, 5 schools × 6, 3 levels each), 30 Edicts (Tức Thì / Phản Ứng / Nội Tại), 20 Global Events (rounds 5/10/15/20) |

When implementing data, use the IDs from these docs (`DH-01`, `TN-05`, `B-01.2`, `D-03`, `S-04`, `U-01K`, `A-03`, `T-ENG-02`, `HT-03`) as stable keys so code can be traced back to the design.

**Docs disagree in places.**
- **Which doc wins (owner decision, D-020):** when GDD 1.6 and Data disagree, **GDD 1.6 wins**. Use Data for anything the GDD does not cover, for example:
  - the placement-matrix columns that GDD §9.4 omits (Tundra, Desert, Swamp);
  - the shape codes 3a..6f in the "Công trình" sheet, decoded in D-020;
  - unit tables and movement costs.
- **Always flag a conflict** to the user rather than silently picking one. The known conflicts are tabled at the end of `docs/Decisions.md`; one example is the S-04 / TN-12 effects, where Data is stale.
- **Not final:** rows marked "ĐỀ XUẤT" (proposed), "Dự kiến có thay đổi" or "đề xuất, cần test", and anything GDD 1.6 calls a draft (§7.4, §7.5, §8.4) or "Phase 2".
- **Godot leftover:** the Data unit-FSM section still says "Godot 4 / C#". The target engine is Love2D/Lua.
- **Code vs GDD 1.6:** where the implemented rules differ from GDD 1.6, the full list is in `docs/Decisions.md` D-020. Changing them is M1.6 work; ask before changing rules outside that plan.

## Core game architecture (cross-document summary)

*Items marked (1.6) are GDD 1.6 rules that the code does not have yet (M1.6).*
- **Turn structure:** a game has N rounds, where (1.6) N = 10 × players and can be set in multiples of 10; the code uses a fixed 20. A round is one turn per player. A turn is **Production → Resolution → Action**, then the dice pass to the next player. A Global Event is flipped every 5 rounds; its tier follows game progress.
- **Dice & Sản Xuất Chung (shared production, formerly "Long Mạch"):**
  - Two custom d6 with faces Science(1), Culture(2), Engineering(3), Faith(4), Gold(5), Hex(6).
  - Production is **shared**: on any player's roll, every player's matching buildings produce, by the per-level table × matching dice count.
  - (1.6) Tiles also hold **base resources** (Tài Nguyên Cơ Bản), 0–2 per kind, rolled at mapgen. They pay out on a matching face to the tile's harvester: the owner, or the only player whose influence zone covers an unowned tile.
  - The Hex face only benefits the active player.
  - A sum of 7 means no production and triggers the Rebel (Phiến Quân). (1.6) The Rebel cannot enter HQ tiles. It plunders every other player's building it steps on, passing included. A player harassed for more than 3 turns gets a Lệnh Đuổi Phiến Quân.
- **Resolution order:** Rebel (on 7) → Global Event → Edict cards → character skills.
- **Resources:** 5 core (Khoa Học, Văn Hóa, Kỹ Thuật, Tín Ngưỡng, Vàng), plus derived materials (Hợp Kim, Giấy, Thép, Lụa, Tín Phiếu) and industrial ones (Than, Dầu Mỏ).
- **Map:** hex grid, randomly generated each game. 7 of the 12 terrain types are drawn per game. The settlement and landmark counts each equal players + 1. Each tile may also carry a strategic resource whose *tile bonus* needs no ownership and whose *building bonus* does.
- **Territory has 3 tiers:** influence zone (radius around HQ/Subsidiary) → contested (votes below threshold) → owned (Lãnh thổ thực hữu, enough Chi Phối votes for that distance). Only owned tiles accept buildings.
  - (1.6) The 6 tiles around the HQ start owned.
  - Tiles can be bought for (1+d) VH + (2+d) V.
  - Tiles adjacent to owned land can be claimed outside the zone, at threshold +1.
  - Retake applies only to high-value tiles, and buildings follow their tile.
- **Buildings:** Basic (5 types × 3 levels; higher levels occupy multi-hex shapes) → Derived (formed when two qualifying basics are adjacent or road-connected; they produce materials) → Special (need materials and multi-tile footprints, and emit auras). HQ has 5 levels and Subsidiary has 3, both gating features.
- **Units:** no player-vs-player combat. Units pass through each other. Harm comes only via the Rebel, Edicts, or infrastructure sabotage. Movement uses per-terrain costs (∞ = impassable) with road bonuses. Infrastructure durability is **per tile**, and route durability = MIN over its tiles.
- **Modifier application order:** Base → Character → Tech → Building aura → Strategic resource → Road. Round down at the final step.
- **Characters:** 5 (Địa Sư, Thương Nhân, Pháp Sư, Tướng Quân, Học Sĩ). Each has 1 passive skill and 4 alternate win conditions, which are checked alongside end-of-game scoring.
- **Rules the GDD leaves open are decided in `docs/Decisions.md`.** D-006 covers Chi Phối thresholds and the Hex face, D-007 starting resources and setup, D-008 sum-of-7 and production, D-009 Rebel effects, D-010 C1 placement and scoring, D-011 the M1 architecture, and D-012 the differences between the full GDD PDF and M1, D-013 the M1 rules changed to follow the PDF (territory model, starting resources), and D-014..D-019 the M1.5 rules: D-014 scope, footprints, upgrade in place, demolish losing the TN, passives; D-015 units; D-016 roads, Trade unit, Market rule, player trade; D-017 HQ C3–C5, Subsidiary C2–C3, Knights; D-018 Derived buildings; D-019 Special buildings; and D-020 the GDD 1.6 / new Data sync (doc-precedence rule, renames, shape codes, the current → GDD 1.6 rule table for M1.6, conflicts and open questions for the designer). Each ends with its open items. Read these before changing any rule. Record new decisions there rather than editing the design docs.

Balance numbers live in `Perisol_Data.md` §8.1 ("HẰNG SỐ CÂN BẰNG"). Keep them as named constants in a single config module (e.g. `MAX_EXPEDITION_PER_PLAYER`, `SUPPRESS_THRESHOLD_EXPEDITION`) so playtesting can tune them without touching logic.

## Roadmap context

Milestones from GDD §13.1: Sandbox (M0) → Core Loop (M1) → Buildings & Infrastructure (M1.5) → Cards (M2) → Characters (M3) → Polish (M4) → Multiplayer (M5). The plan inserts **M1.6** (apply GDD 1.6 after playtest #1) before M2. M2–M3 are complete **as designs only**; M0, M1 and M1.5 (except the deferred industrial layer) are implemented. GDD 1.6 also drafts systems that are not scheduled yet: Infantry occupation, combat, Port, Lake/Sea, and a "Phase 2" list (Hảo Cảm, Sứ Giả, Settlement trade, Chuồng Ngựa, Chốt Phòng Thủ, Knights).

## Git Commit Guidelines
- Never append or include the "Co-authored-by: Claude" line in any git commit messages.
- Commit messages must strictly contain only the title and description of the changes made, without any AI authorship metadata.
