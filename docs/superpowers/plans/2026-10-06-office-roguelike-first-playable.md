# Office Roguelike First Playable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single-player, 3D, Overcooked-style office run (tickets, stability bar, leads, PR, meetings, buffs, two NPCs, toy shotgun) built so co-op can be added later.

**Architecture:** Nodes plus data plus pure functions. All rules numbers live in one `Balance` resource; formulas are static pure functions in `Rules`; one `RunDirector` node owns run state and is the only thing that mutates it (the "host authority" path). Stations, players and NPCs are nodes built in code (no hand-edited `.tscn` except `main.tscn`).

**Tech Stack:** Godot 4.7, GDScript, headless tests with plain asserts. No new addons.

**Spec:** `docs/superpowers/specs/2026-10-06-office-roguelike-first-playable-design.md`

## Global Constraints

- Godot 4.7, GDScript only. Typed signatures everywhere.
- Run headless with the `godot` binary on PATH: `godot --headless --path /home/user/Office-rougelike-game ...`.
- Tests: `godot --headless --path . --script tests/run.gd`; exit code 0 means all passed. No test framework.
- Every tunable number lives in `scripts/data/balance.gd` (defaults = the spec's placeholders, listed in Task 0). No magic numbers in logic.
- Only `RunDirector` (and code it calls) mutates run state, and only when `multiplayer.is_server()` (true offline). Players and NPCs never edit quests, satisfaction or stability directly.
- Spec rules to keep verbatim: meeting order client, manager, CEO at 25%, 50%, 75% of the run; pad lock-in 2 s; majority wins, ties random among tied, zero votes random among all; promotion needs end satisfaction >= 90 and rival bar < 100; fired keeps 25% of quest payout; run is 600 s.
- Placeholder art only: boxes and capsules.
- Before implementing each Godot system, invoke the `godot-prompter:*` skill named in the task and report the pattern chosen.

## Review Focus

1. A station with no matching open item: standing on it must do nothing and keep no progress. (Task 2)
2. Two players entering one station, or a player leaving mid-fill: only the first holds; leaving resets. (Task 2)
3. Meeting where nobody locks in, players tie, or there is one player: a pad is always chosen. (Task 6)
4. Run ending (fired or time) during a hold or meeting: ends once, no more spawns or score changes, results built once. (Task 3, Task 6)
5. Stability at 0 with bugs open and a player at the dev table: bugs are fixed first, outage drain continues, satisfaction never goes below 0. (Task 4)
6. Shotgun with no ammo, stunning an already-stunned NPC, or the Climber stealing with fewer than 3 solves recorded. (Tasks 9, 10)

---

## File Structure

```
main.tscn                      minimal scene: Node3D with scripts/office.gd
project.godot                  main scene, EventBus autoload
scripts/event_bus.gd           autoload; signals only
scripts/input_setup.gd         registers input actions in code
scripts/data/balance.gd        Balance resource: every tunable
scripts/data/meeting_def.gd    MeetingDef resource
scripts/data/buff_def.gd       BuffDef resource
tools/make_data.gd             writes data/*.tres (run once, output committed)
data/balance.tres, data/meetings/*.tres, data/buffs/*.tres
scripts/logic/rules.gd         Rules: pure static formulas
scripts/logic/work_item.gd     WorkItem: item types, stages, effects (pure)
scripts/player.gd              Player (CharacterBody3D)
scripts/station.gd             Station (Area3D) stand-to-fill
scripts/run_director.gd        RunDirector
scripts/office.gd              builds the world, wires everything
scripts/meeting.gd             Meeting flow and pads
scripts/ui/hud.gd              HUD, end screen, buff cards (CanvasLayer)
scripts/npc/chatter.gd, climber.gd, shotgun.gd
tests/run.gd, tests/t.gd, tests/test_*.gd
```

---

### Task 0: Foundation (project config, test runner, EventBus, Balance)

**Skills:** godot-prompter:godot-project-setup, godot-prompter:godot-testing

**Files:**
- Modify: `project.godot` (main scene `res://main.tscn`, autoload `EventBus="*res://scripts/event_bus.gd"`)
- Create: `main.tscn`, `scripts/event_bus.gd`, `scripts/input_setup.gd`, `scripts/data/balance.gd`, `tests/run.gd`, `tests/t.gd`, `tests/test_balance.gd`, `tools/make_data.gd`, `data/balance.tres`

**Interfaces:**
- Produces: `class_name Balance extends Resource` with `@export` fields below. `EventBus` signals: `item_spawned(item)`, `item_done(item, player)`, `item_expired(item)`, `satisfaction_changed(v: float)`, `stability_changed(v: float)`, `quest_changed(name: String, progress: float, target: float)`, `meeting_started(def)`, `meeting_ended(def, pad: int)`, `npc_stunned(npc)`, `run_ended(result: Dictionary)`. `InputSetup.register() -> void` adds actions `move_left/right/up/down` (A/D/W/S + arrows) and `fire` (Space). `T.eq(got, want, msg: String)`, `T.near(got: float, want: float, eps: float, msg: String)`, `T.truth(cond: bool, msg: String)`; failures are counted in `T.failed`.
- Test contract: each `tests/test_*.gd` extends `RefCounted` with `func test_*()` methods and a `var tree: SceneTree` set by the runner; the runner calls `_initialize()`-time (so autoloads exist), runs every test, prints each failure, and `quit(1)` if any failed.
- `Balance` defaults (spec values): `run_seconds 600`, `start_satisfaction 50`, `promo_threshold 90`, holds `pc 4, phone 8, sales 6, studio 10, devtable 8, pad 2, callout 2`, satisfaction `reply +1, call +3, bug +2, expire -4, outage -1/s`, stability `drain 1/s, refill 6/s, ok_level 30, ok_share 0.9`, deadlines `ticket 40, bugticket 60, lead 90, pr 60`, intervals `ticket 8, lead 30, pr 40, bug 45`, `bugticket_share 0.25`, `lead_values [500,1200,2500]`, `lead_hold_mult [1,1.25,1.5]`, `pr_points {pc:1, phone:2, studio:4}`, `ticket_base 40, revenue_base 2000, pr_base 6, pr_per_level 2`, `meeting_times [0.25,0.5,0.75]`, `meeting_countdown 15, meeting_warning 5, buff_timeout 8`, `payout_per_quest 100, fired_payout_share 0.25`, plus NPC and shotgun fields added in Tasks 8 to 10.

- [ ] **Step 1: Write `tests/run.gd`, `tests/t.gd` and `tests/test_balance.gd`**

`test_balance.gd`: `test_defaults_match_spec()` asserts `Balance.new().run_seconds == 600`, `hold_pc == 4.0`, `promo_threshold == 90.0`, `meeting_times == PackedFloat32Array([0.25, 0.5, 0.75])`.

- [ ] **Step 2: Run `godot --headless --path . --script tests/run.gd`; expect FAIL** (Balance missing).

- [ ] **Step 3: Implement `Balance`, `EventBus`, `InputSetup`, `main.tscn`, and the `project.godot` edits.** `tools/make_data.gd` (a `SceneTree` script) saves `Balance.new()` to `res://data/balance.tres` with `ResourceSaver`; run it once with `godot --headless --path . --script tools/make_data.gd`.

- [ ] **Step 4: Run the test command; expect PASS.** Also confirm autoloads exist inside the runner: add `test_event_bus_available()` asserting `tree.root.has_node("EventBus")`. If it fails, the runner must start tests from `_initialize()` instead of `_init()`.

- [ ] **Step 5: Commit** `git add -A && git commit -m "feat: project foundation, Balance, EventBus, test runner"`

---

### Task 1: Player and the Office floor (M1)

**Skills:** godot-prompter:player-controller, godot-prompter:input-handling, godot-prompter:camera-system, godot-prompter:3d-essentials

**Files:**
- Create: `scripts/player.gd`, `scripts/office.gd`, `tests/test_player.gd`
- Modify: `main.tscn` (attach `scripts/office.gd`)

**Interfaces:**
- Produces: `class_name Player extends CharacterBody3D` with `var stats: Dictionary = {}`, `var work_rate := 1.0`, `var move_mult := 1.0`, `var actions: Dictionary = {}` (stream to count), `var ammo := 0`, `var scripted_move := Vector2.ZERO`, `var use_scripted := false`, `const BASE_SPEED := 5.0`, `func record_action(stream: String) -> void`, `func stat_mult(key: String) -> float` (default 1.0). Movement happens in `_physics_process` only when `is_multiplayer_authority()`.
- Produces: `Office` (`Node3D`) builds in `_ready()`: a 24 x 16 m floor (static box), a fixed angled `Camera3D`, a `Players` container with one `Player` (capsule), a `RunDirector` (added in Task 3), the HUD (Task 3), and calls `InputSetup.register()`.

- [ ] **Step 1: Test** `test_player_moves_with_scripted_input()`: add a `Player` to `tree.root`, set `use_scripted = true`, `scripted_move = Vector2(1, 0)`, step 10 physics frames via `await tree.physics_frame`, assert `global_position.x > 0.5`. `test_move_mult_scales_speed()`: with `move_mult = 0.3` the distance after the same frames is about 0.3 of the base distance (`T.near`, eps 0.1).
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement `Player` (speed `BASE_SPEED * move_mult * stat_mult("move_speed")`) and `Office` floor and camera.**
- [ ] **Step 4: Run tests; expect PASS.** Also run `godot --headless --path . --quit-after 60` and expect no errors in output.
- [ ] **Step 5: Commit** `feat: player movement and office floor`

---

### Task 2: Station stand-to-fill (M1)

**Skills:** godot-prompter:physics-system, godot-prompter:component-system

**Files:**
- Create: `scripts/station.gd`, `tests/test_station.gd`
- Modify: `scripts/logic/rules.gd` (create; first function)

**Interfaces:**
- Produces: `Rules.hold_seconds(base: float, stats: Dictionary, key: String) -> float` returns `base * stats.get(key, 1.0)`.
- Produces: `class_name Station extends Area3D` with `signal completed(player: Player)`, `var kind: String`, `var base_hold: float`, `var stream := ""`, `var hold_mult := 1.0`, `var enabled := false`, `var holder: Player = null` (always tracked), `var progress := 0.0` (0 to 1, only advances while `enabled`), `func setup(kind: String, base_hold: float, size: Vector3, color: Color) -> void` (builds collision box and mesh). Seconds to fill = `Rules.hold_seconds(base_hold * hold_mult, holder.stats, "hold_" + stream) / holder.work_rate`.

- [ ] **Step 1: Tests.** `test_hold_seconds_applies_stat()` (`hold_seconds(4.0, {"hold_tickets": 0.5}, "hold_tickets") == 2.0`; missing key gives 4.0). Station tests place a `Player` inside the area (`player.global_position = station.global_position`) and step frames: `test_fills_and_completes()` (completed fires once after about 4 s of physics time, progress resets to 0); `test_disabled_station_keeps_no_progress()` (enabled false: stay 5 s, progress stays 0, no completed) [Review Focus 1]; `test_leaving_resets()` (stand 2 s, step away, progress is 0) [Review Focus 2]; `test_second_player_ignored()` (two players inside: `holder` is the first, and the second does not speed up the fill) [Review Focus 2]; `test_work_rate_slows()` (`work_rate = 0.5` roughly doubles the time).
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement** `Station._physics_process(delta)`: runs only if `multiplayer.is_server()`; `holder` is the earliest still-overlapping `Player` (keep it while it stays inside); if the holder changes or leaves, `progress = 0`.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: stand-to-fill Station`

---

### Task 3: WorkItem, RunDirector, tickets, satisfaction, HUD, end screen (M1)

**Skills:** godot-prompter:hud-system, godot-prompter:godot-ui, godot-prompter:event-bus

**Files:**
- Create: `scripts/logic/work_item.gd`, `scripts/run_director.gd`, `scripts/ui/hud.gd`, `tests/test_work_item.gd`, `tests/test_director.gd`
- Modify: `scripts/office.gd` (add director, HUD, stations `pc` x3 and `phone` x1 at fixed positions), `scripts/logic/rules.gd`

**Interfaces:**
- Produces: `class_name WorkItem extends RefCounted` with `var type: String` (`"ticket"`, `"bugticket"`, `"lead"`, `"pr"`, `"bug"`), `var stage := 0`, `var deadline: float`, `var size := 0` (lead size index), `var ticket: WorkItem` (for a bug), `func stream() -> String` (`tickets`, `bugs`, `business`, `pr`), `func accepts(station_kind: String) -> bool`, `func apply(station_kind: String, b: Balance) -> Dictionary` returning effects `{"done": bool, "satisfaction": float, "quest": {name: delta}, "spawn_bug": bool, "stage": int}` (pure; the director applies them).
- Rules for `accepts/apply` in this task: `ticket` accepts `pc` (reply, satisfaction `sat_reply`, quest tickets +1, done) and `phone` (call, `sat_call`, tickets +1, done). Later tasks add the other types.
- Produces: `class_name RunDirector extends Node` with `var b: Balance`, `var rng: RandomNumberGenerator`, `var level := 1`, `var players: Array[Player]`, `var time_left: float`, `var satisfaction: float`, `var stability := 100.0`, `var items: Array[WorkItem]`, `var quests := {"tickets": 0.0, "revenue": 0.0, "pr": 0.0, "stable_s": 0.0}`, `var running := false`, `func start(p: Array[Player], seed: int) -> void`, `func tick(dt: float) -> void` (called from `_physics_process`; tests call it directly), `func register_station(s: Station) -> void`, `func item_for(kind: String) -> WorkItem` (the accepting item with the nearest deadline, or null), `func on_station_completed(kind: String, player: Player) -> void`, `func end_run(reason: String) -> void` (`"fired"` or `"time"`; idempotent), `func result() -> Dictionary`.
- `tick`: decrement time, spawn tickets every `interval_ticket` (bug tickets with probability `bugticket_share`), expire items (satisfaction + `sat_expire`, `item_expired`), set each registered station's `enabled`, `stream`, `hold_mult`, clamp satisfaction to 0..100, end with `"fired"` at 0 or `"time"` at 0 seconds left. After `running == false`, `tick` does nothing.

- [ ] **Step 1: Tests.** `test_ticket_accepts_pc_and_phone()`, `test_reply_effects()` (`satisfaction == b.sat_reply`, quest tickets 1, done), `test_call_effects()`. Director (seeded, `players = []`, stations stubbed with `Station.new()`): `test_spawns_tickets_on_interval()`, `test_item_for_picks_nearest_deadline()`, `test_expiry_costs_satisfaction()` (`start_satisfaction + sat_expire`), `test_fired_at_zero_ends_once()` (set satisfaction to 1, expire an item, assert `run_ended` emitted once and `running == false`; further `tick` calls change nothing) [Review Focus 4], `test_time_up_ends()`, `test_satisfaction_never_negative()`.
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement** `WorkItem` (ticket type only), `RunDirector`, and `Hud` (time, satisfaction bar, open-item queue, end screen with result text, restart on Enter). `Office` wires each station's `completed` to `director.on_station_completed(station.kind, player)` and sets station markers via the director.
- [ ] **Step 4: Run tests; expect PASS.** Run `godot --headless --path . --quit-after 120` and expect no errors.
- [ ] **Step 5: Commit** `feat: M1 tickets by reply and call, satisfaction, end screen`

---

### Task 4: Dev table, stability bar, bugs (M2)

**Skills:** godot-prompter:state-machine (only to confirm a plain enum is enough here)

**Files:**
- Modify: `scripts/logic/work_item.gd`, `scripts/logic/rules.gd`, `scripts/run_director.gd`, `scripts/office.gd` (dev table station)
- Test: `tests/test_stability.gd`

**Interfaces:**
- Produces: `Rules.stability_step(value: float, dt: float, bugs_open: int, standing: bool, b: Balance) -> float`: `value - drain*dt` always; plus `refill*dt` only if `standing and bugs_open == 0`; clamped 0..100.
- `WorkItem`: `bugticket` stage 0 accepts `pc` (apply returns `spawn_bug: true`, stage 1, not done, no score); stage 1 accepts nothing; stage 2 accepts `pc` (done, `sat_bug`, tickets +1). `bug` accepts `devtable` (done; if `ticket` is set the director sets `ticket.stage = 2`).
- Director: finishing a bug ticket multiplies `bugticket_share` by `b.bugticket_share_decay` (Balance field, default `0.9`), so similar tickets get rarer for the rest of the run. `bugs_open() -> int`; spontaneous bugs every `interval_bug`; `stable_s` quest time accumulates while `stability > b.stability_ok_level`; dev table station `enabled` only while bugs are open; outage (`stability == 0`) applies `outage_sat_per_s * dt` and spawns an extra ticket every 20 s.

- [ ] **Step 1: Tests.** `test_drains_over_time()` (`stability_step(100, 10, 0, false, b) == 90`), `test_refill_only_without_bugs()` (standing with 1 bug: net drain; with 0 bugs: `+5` per second), `test_clamps()`, bug flow: `test_bugticket_full_path()` (pc, then dev table fixes the linked bug, then pc replies: done with `sat_bug` once), `test_bug_ticket_done_decays_share()` (`bugticket_share` becomes 0.9 x its old value), `test_outage_costs_satisfaction_and_floors_at_zero()` [Review Focus 5], `test_fix_before_refill()` (player at dev table with 2 bugs: after fixing one the bar still does not rise; after the second it does) [Review Focus 5].
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement.** Stability bar added to the HUD; dev table box station in the office.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M2 dev table, stability bar, bugs`

---

### Task 5: Leads, PR tasks, quests, payout, results (M3)

**Skills:** godot-prompter:hud-system

**Files:**
- Modify: `scripts/logic/rules.gd`, `scripts/logic/work_item.gd`, `scripts/run_director.gd`, `scripts/ui/hud.gd`, `scripts/office.gd` (sales PC and studio stations)
- Test: `tests/test_rules.gd`, `tests/test_items_more.gd`

**Interfaces:**
- Produces in `Rules`: `quest_ratio(progress: float, target: float) -> float` (`min(progress/target, 1.5)`; target <= 0 gives 0), `ticket_target(p: int, level: int, b: Balance) -> float`, `revenue_target(p, level, b)`, `pr_target(level: int, b: Balance) -> float`, `stability_ratio(stable_s: float, run_s: float, b: Balance) -> float` (share of run above the level, divided by `stability_ok_share`, capped at 1.5), `bonus(ratios: Array[float], level: int, end_satisfaction: float, fired: bool, b: Balance) -> int`, `promoted(end_satisfaction: float, rival_bar: float, b: Balance) -> bool`, `timer_scale(level: int) -> float` (`max(0.5, 0.92^(level-1))`).
- `WorkItem`: `lead` stage 0 accepts `sales`, stage 1 accepts `phone` (done: quest revenue `+b.lead_values[size]`); `pr` accepts `pc`, `phone`, `studio` (done: quest pr `+b.pr_points[kind]`). Lead holds use `hold_mult = b.lead_hold_mult[size]` (director sets it on the station).
- The director multiplies each new item's deadline by `Rules.timer_scale(level)` (test: at `level = 3` a ticket deadline is `deadline_ticket * 0.92^2`).
- `RunDirector.result()` returns `{"outcome", "ratios": Array[float], "bonus": int, "promoted": bool, "satisfaction": float}`.

- [ ] **Step 1: Tests with the spec's exact values.** `ticket_target(4, 2, b) == 192.0` (40 x 4 x 1.2), `revenue_target(1, 3, b) == 3000.0`, `pr_target(2, b) == 10.0`, `quest_ratio(300, 100) == 1.5`, `quest_ratio(5, 0) == 0.0`, `bonus([1,1,1,1], 1, 70, false, b) == 470`, `bonus([1,1,1,1], 1, 0, true, b) == 100` (25% of 400), `bonus([1,1,1,1], 2, 70, false, b) == 570` (500 + 70), `promoted(90, 99, b) == true`, `promoted(89, 0, b) == false`, `promoted(100, 100, b) == false`, `timer_scale(5)` near 0.72 and `timer_scale(30) == 0.5`. Items: `test_lead_two_stages_and_value()`, `test_pr_points_by_station()` (pc 1, phone 2, studio 4), `test_phone_serves_ticket_lead_and_pr_by_deadline()`.
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement** and add quest progress lines and the results screen (outcome, per-quest ratio, bonus, promotion yes or no) to the HUD.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M3 leads, PR, quests, payout`

---

### Task 6: Meetings and choice pads (M4)

**Skills:** godot-prompter:state-machine, godot-prompter:tween-animation

**Files:**
- Create: `scripts/data/meeting_def.gd`, `scripts/meeting.gd`; `data/meetings/client.tres`, `manager.tres`, `ceo.tres` (generated by `tools/make_data.gd`)
- Modify: `scripts/logic/rules.gd`, `scripts/run_director.gd`, `scripts/office.gd`, `scripts/ui/hud.gd`, `tools/make_data.gd`
- Test: `tests/test_meeting.gd`

**Interfaces:**
- Produces: `Rules.pick_meeting_pad(votes: Array[int], rng: RandomNumberGenerator) -> int` (`votes[i]` = players locked on pad i; highest wins; ties pick randomly among the tied; all zero picks randomly among all pads).
- Produces: `class_name MeetingDef extends Resource` with `@export var title: String`, `@export var labels: PackedStringArray`, `@export var effects: Array[Dictionary]` (keys: `satisfaction: float`, `target_mult: {quest: float}`, `spawn_mult: {stream: float, "seconds": float}`, `rival_bar: float`).
- Produces: `Meeting` (`Node3D`) with `func begin(def: MeetingDef, players: Array[Player], rng: RandomNumberGenerator) -> void`, signal `finished(pad: int)`; builds one pad `Station` per label (`kind "pad"`, hold `b.hold_pad`), tracks each player's locked pad (a player locks when their pad fills; leaving unlocks), ends when all players are locked or after `b.meeting_countdown`, then emits `finished(Rules.pick_meeting_pad(...))`.
- Director: `meeting_schedule` of three times from `meeting_times * run_seconds` plus a jitter of up to 10 s, in the order client, manager, CEO; 5 s warning, then it hides and disables work stations, keeps ticking deadlines, runs the `Meeting`, applies `effects[pad]` through `apply_effects(effects: Dictionary) -> void`, restores stations, and emits `meeting_started/ended`.

- [ ] **Step 1: Tests.** `pick_meeting_pad([2,1,0], rng) == 0`; `pick_meeting_pad([0,0,0], rng)` returns a valid index and over 300 seeded draws returns all three indices; `[1,1,0]` returns 0 or 1 only, and over 300 draws both appear [Review Focus 3]; one player on pad 2 gives 2. `test_meeting_order_and_times()` (types are client, manager, CEO; times inside the run). `test_effects_apply()` (satisfaction delta and target multiplier). `test_run_end_during_meeting_ends_once()` [Review Focus 4]. `test_deadlines_keep_running_in_meeting()`.
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement** the three definitions with the spec's example choices (client: quick deal or bigger promise; manager: prioritise tickets or revenue; CEO: higher revenue target for better payout or steady). Generate with `godot --headless --path . --script tools/make_data.gd`.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M4 meetings with choice pads`

---

### Task 7: Buffs and per-player stats (M5)

**Skills:** godot-prompter:resource-pattern, godot-prompter:hud-system

**Files:**
- Create: `scripts/data/buff_def.gd`, `data/buffs/*.tres` (generated), `tests/test_buffs.gd`
- Modify: `scripts/logic/rules.gd`, `scripts/player.gd`, `scripts/run_director.gd`, `scripts/ui/hud.gd`, `tools/make_data.gd`

**Interfaces:**
- Produces: `class_name BuffDef extends Resource` with `id: String`, `title: String`, `stream: String` (`tickets`, `bugs`, `business`, `pr`, `mobility`), `stat: String`, `op: String` (`"mul"` or `"add"`), `value: float`. Pool (at least 10): hold-time multipliers `0.85` for `hold_tickets`, `hold_bugs`, `hold_business`, `hold_pr`; `move_speed` mul `1.1`; `shotgun_ammo` add `1`; and a second copy of each of a few for variety.
- Produces: `Rules.buff_weight(share: float) -> float` (`1 + 4*share`; mobility buffs use weight 2 elsewhere), `Rules.draw_offers(pool: Array[BuffDef], shares: Dictionary, rng: RandomNumberGenerator) -> Array[BuffDef]` (three distinct buffs; one slot drawn only from the player's top stream if such buffs exist; other slots weighted).
- `Player.add_stat(stat: String, op: String, value: float) -> void` (mul multiplies the existing value starting at 1.0; add adds starting at 0.0). `Player.action_shares() -> Dictionary` (stream to share of recorded actions, empty when none).
- After each meeting: `HUD` shows three cards for the player; keys 1, 2, 3 pick; `buff_timeout` picks a random card; the pick calls `add_stat`.

- [ ] **Step 1: Tests.** `buff_weight(0.7)` near 3.8; `draw_offers` returns 3 distinct buffs; with shares `{"tickets": 1.0}` the first slot is a tickets buff in 100 seeded draws; with no shares and a pool lacking the top stream it still returns 3; `add_stat("hold_tickets", "mul", 0.85)` twice gives about 0.7225 via `stat_mult`; `add` for ammo; idle timeout picks exactly one card.
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement,** and make the director call `player.record_action(item.stream())` on each done item.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M5 buff cards and player stats`

---

### Task 8: Chatter NPC and navigation (M6)

**Skills:** godot-prompter:ai-navigation, godot-prompter:state-machine

**Files:**
- Create: `scripts/npc/chatter.gd`, `tests/test_chatter.gd`
- Modify: `scripts/data/balance.gd` (add `chatter_talk 5.0`, `chatter_cooldown 20.0`, `chatter_move_mult 0.3`, `chatter_work_mult 0.5`, `stun_chatter 4.0`), `scripts/office.gd` (bake a `NavigationRegion3D` from the floor at start)

**Interfaces:**
- Produces: `class_name Chatter extends CharacterBody3D` with `enum State { WANDER, APPROACH, TALK, LEAVE, STUNNED }`, `var state: State`, `func stun(seconds: float) -> void`, `func pick_target(players: Array[Player]) -> Player` (the player whose nearest station has a `holder`, else the nearest player), `func tick(delta: float) -> void` (tests call it directly). While in TALK: target `move_mult = chatter_move_mult`, `work_rate = chatter_work_mult`; restored on leaving or stun or free. Host-only logic. Cooldown shortens with `timer_scale(level)`.

- [ ] **Step 1: Tests.** `test_approaches_busy_player()`, `test_talk_slows_then_restores()` (move_mult 0.3 and work_rate 0.5 during talk; 1.0 after 5 s) , `test_stun_ends_talk_and_restores()`, `test_cooldown_before_return()`, `test_stun_while_stunned_does_not_stack()` [Review Focus 6].
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement** with a `NavigationAgent3D`. If baking produces no polygons headless, steer directly and add a `# ponytail:` comment naming the upgrade path.
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M6 Chatter NPC`

---

### Task 9: Climber, outbox board, call-out (M6)

**Skills:** godot-prompter:ai-navigation, godot-prompter:state-machine

**Files:**
- Create: `scripts/npc/climber.gd`, `tests/test_climber.gd`
- Modify: `scripts/data/balance.gd` (add `climber_interval 45.0`, `climber_steal_hold 4.0`, `climber_steal_bar 10.0`, `climber_creep 0.05`, `climber_steal_back 3`, `climber_away 30.0`, `stun_climber 5.0`), `scripts/run_director.gd` (`var rival_bar := 0.0`, `var recent_solves: Array`, `func steal(n: int) -> void`), `scripts/ui/hud.gd` (rival bar), `scripts/office.gd` (outbox board station, `callout` station that follows the Climber)

**Interfaces:**
- Produces: `class_name Climber extends CharacterBody3D` with `enum State { IDLE, TO_BOARD, STEALING, AWAY, STUNNED }`, `func stun(seconds: float) -> void`, `func call_out() -> void` (cancels a steal, goes AWAY for `climber_away`), `func tick(delta: float) -> void`. A completed steal calls `director.steal(b.climber_steal_back)`: removes the credit of the last `n` recorded solves (fewer if fewer exist, never negative) from `quests` and adds `climber_steal_bar` to `rival_bar` (clamped 100). `rival_bar` also rises by `climber_creep` per second in `tick`.
- Director records each done ticket as `{"quest": name, "amount": float}` in `recent_solves`.

- [ ] **Step 1: Tests.** `test_steal_removes_last_three_credits()`, `test_steal_with_fewer_than_three()` (never negative) [Review Focus 6], `test_steal_adds_bar_and_creep()`, `test_callout_cancels_steal()`, `test_stun_cancels_steal()`, `test_bar_100_blocks_promotion()` (end with satisfaction 95 and bar 100 gives `promoted == false`).
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M6 Climber, outbox board, call-out`

---

### Task 10: Toy shotgun (M6)

**Skills:** godot-prompter:physics-system, godot-prompter:input-handling

**Files:**
- Create: `scripts/npc/shotgun.gd`, `tests/test_shotgun.gd`
- Modify: `scripts/data/balance.gd` (add `shotgun_ammo 3`, `shotgun_cone_deg 12.0`, `shotgun_range 8.0`, `shotgun_cooldown 0.8`, `shotgun_respawn 20.0`), `scripts/player.gd`, `scripts/office.gd` (shelf pickup)

**Interfaces:**
- Produces: `class_name ShotgunShelf extends Area3D` (pickup: a player entering with `ammo == 0` gets `b.shotgun_ammo + stat_mult-style add of shotgun_ammo`; the shelf is empty until `shotgun_respawn` seconds after the ammo is used up). `Player.fire(targets: Array[Node3D]) -> bool`: returns false with no ammo or during cooldown; otherwise picks the nearest target inside the cone and range (auto-aim), calls its `stun(seconds)` (`stun_chatter` for a Chatter, `stun_climber` for a Climber), decrements ammo, returns true. Players are never targets. Firing is bound to the `fire` action.

- [ ] **Step 1: Tests.** `test_fire_stuns_chatter_and_climber_with_their_durations()`, `test_no_ammo_returns_false()` [Review Focus 6], `test_cooldown_blocks_second_shot()`, `test_out_of_cone_or_range_misses()`, `test_ammo_buff_adds_one()`, `test_shelf_respawns_after_delay()`, `test_stunning_stunned_npc_refreshes_not_stacks()`.
- [ ] **Step 2: Run tests; expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests; expect PASS.**
- [ ] **Step 5: Commit** `feat: M6 toy shotgun`

---

### Task 11: Seeded replay and playtest checklist

**Skills:** godot-prompter:godot-testing, godot-prompter:godot-debugging

**Files:**
- Create: `tests/test_replay.gd`, `docs/playtest-checklist.md`

- [ ] **Step 1: Test** `test_full_seeded_run_completes()`: build the `Office`, start a run with a fixed seed and one player with scripted movement visiting each station kind in turn, call `director.tick(1.0/60.0)` until the run ends, and assert: no errors, `run_ended` emitted once, all three meetings occurred in client, manager, CEO order, `bonus >= 0`, `satisfaction` within 0..100, and the same seed gives identical `result()` twice.
- [ ] **Step 2: Run all tests; fix failures.** `godot --headless --path . --script tests/run.gd` must exit 0.
- [ ] **Step 3: Write `docs/playtest-checklist.md`:** run on a machine with a display; verify the camera and readability, hold bars feel right, meeting pads and countdown, buff cards, Chatter slows you, Climber steal and call-out, shotgun feel, whether runs last about 10 minutes, and list every number that felt wrong (all in `balance.tres`).
- [ ] **Step 4: Commit** `test: seeded replay and playtest checklist`
