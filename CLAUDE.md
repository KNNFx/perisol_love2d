# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

**Perisol** is a turn-based hex-territory strategy board game for 1–4 players, targeting **PC via Love2D (Lua)**. The repo is in early development: design documents live in `docs/`, and milestone **M0 Sandbox** (see `plan.md`) is implemented — a seeded random hex map you can pan/zoom/hover. Gameplay (M1+) is not built yet.

### Commands (LÖVE 11.5 at `C:\Program Files\LOVE\`, not on PATH)
- Run: `run.bat` (= `love.exe .`). Options: `--seed N`, `--players 1-4`, `--shot name.png` (screenshot into `%APPDATA%/LOVE/perisol`, then quit).
- Test: `test.bat` (= `lovec.exe . --test`; headless, exit code 1 on failure). The mini-runner is `tests/runner.lua` (`describe`/`it`/`expect.*`); specs are `tests/*_spec.lua`. There is no standalone Lua/busted on this machine.
- Sandbox keys: R new seed · 1–4 players · Z zones · F1 debug · wheel zoom · RMB-drag/WASD pan.

### Code conventions
- `src/core/` is pure Lua and must **never call `love.*`** (keeps it testable headless and reusable for AI/multiplayer). `src/render/` and `src/scenes/` hold all LÖVE-specific code.
- Randomness goes through `src/core/rng.lua` (deterministic, seeded) — not `math.random` / `love.math`.
- Balance and map-gen numbers live in `src/config/constants.lua`; static data keyed by doc IDs in `src/data/`.
- Hex grid: axial `(q, r)`, pointy-top, odd-r offset for the rectangular map; sprites are 32×32 with pitch 32×24. Decisions are logged in `docs/Decisions.md`.

All design docs are written in **Vietnamese**. Game terms (Long Mạch, Phiến Quân, Sắc Lệnh, Chi Phối, etc.) should be kept as-is in identifiers' comments and UI text, not translated loosely. English equivalents exist for some entities (e.g. terrain `Plains`, `Forest`; units `Expedition`, `Trade`) in `docs/Perisol_Data.md`.

## Design documents (source of truth)

| File | Contents |
|---|---|
| `docs/Perisol_GDD_v1.2_Full.md` | Master GDD: core loop, map, resources, dice, characters, territory, buildings, infrastructure, setup & scoring |
| `docs/Perisol_Data.md` | Static data tables exported from `Perisol Data.xlsx`: terrains (DH-xx), strategic resources (TN-xx), buildings with costs/footprints (B/D/S-xx), building×terrain placement matrix, infrastructure, units (U-xx), unit actions (A-xx), movement-cost table, durability rules, modifier order, **tunable constants**, unit FSM states, open design Q&A |
| `docs/Perisol_Buildings_v1.0.md` | Detailed per-building descriptions (Basic → Derived → Special) |
| `docs/Perisol_Cards_v1.2.md` | All 80 cards: 30 Tech (T-ENG/…, 5 schools × 6, 3 levels each), 30 Edicts (Tức Thì / Phản Ứng / Nội Tại), 20 Global Events (rounds 5/10/15/20) |

When implementing data, use the IDs from these docs (`DH-01`, `TN-05`, `B-01.2`, `D-03`, `S-04`, `U-01K`, `A-03`, `T-ENG-02`, `HT-03`) as stable keys so code can be traced back to the design.

**Docs disagree in places.** For example, valid terrains for Trại Khai Thác / Nhà Văn Hóa differ between the GDD §8.1, the Data "Công trình" sheet, and the "Đặt công trình" matrix. `Perisol_Data.md` is the newest and most detailed; prefer it for numbers and placement rules, and flag the conflict to the user rather than silently picking one. Rows marked "ĐỀ XUẤT" (proposed) or "Dự kiến có thay đổi" are not final. The Data doc mentions "Godot 4 / C#" in the unit FSM section; that is a leftover, and the target engine is Love2D/Lua.

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
- **Rules the GDD leaves open are decided in `docs/Decisions.md`.** D-006 covers Chi Phối thresholds and the Hex face, D-007 starting resources and setup, D-008 sum-of-7 and production, D-009 Rebel effects, D-010 C1 placement and scoring, and D-011 the M1 architecture. Read these before changing any rule. Record new decisions there rather than editing the design docs.

Balance numbers live in `Perisol_Data.md` §8.1 ("HẰNG SỐ CÂN BẰNG"). Keep them as named constants in a single config module (e.g. `MAX_EXPEDITION_PER_PLAYER`, `SUPPRESS_THRESHOLD_EXPEDITION`) so playtesting can tune them without touching logic.

## Roadmap context

Milestones from GDD §12: Sandbox (M0) → Core Loop (M1) → Buildings & Infrastructure (M1.5) → Cards (M2) → Characters (M3) → Polish (M4) → Multiplayer (M5). M1.5–M3 are complete **as designs only**; implementation starts from M0.

## Git Commit Guidelines
- Never append or include the "Co-authored-by: Claude" line in any git commit messages.
- Commit messages must strictly contain only the title and description of the changes made, without any AI authorship metadata.
