# Office Roguelike: First Playable Design

Engine: Godot 4.7, 3D. Language: GDScript. Status: draft for review.

## 1. Intent

A co-op, Overcooked-style 3D game. You play office workers in the operations sector, juggling customer tickets, a stability bar, and new business under time pressure, with scheduled meetings and two troublesome NPCs. Tone: light, absurd office comedy with real time pressure (assumed; not yet confirmed).

Players: 1 now; local co-op and online co-op later. Runs are short roguelike runs (one compressed workday, about 10 minutes).

Success for the first playable: one player can play a full run, the juggling is fun, and the code is structured so co-op can be added without a rewrite.

## 2. Scope

In (first playable, built in six playable steps M1 to M6):
- Walk around a 3D office; stand-to-fill interaction at stations.
- Tickets with three solving paths, the dev table and stability bar, bugs.
- Leads (new business) and PR tasks (three ways each).
- Four quests, the satisfaction bar, end-of-run results.
- Three meetings with choice pads, then per-player buff cards.
- The Chatter NPC, the Climber (rival) NPC with outbox board, the toy shotgun.

Out (later specs): shop and persistent Bonus currency, promotion levels beyond data hooks, local co-op (stage 2), online co-op, saving, final art and audio.

## 3. Core interaction

One reusable `Station` (`Area3D`). A player stands inside, a bar fills, leaving resets that step's bar, completion emits `completed(player)`. Seconds to fill = base seconds x the player's stat multiplier for that kind. The same component serves PC desks, phone, dev table, sales PC, studio, outbox board, meeting pads, and the "call out the rival" spot. A station works the open item nearest its deadline; there are no menus.

## 4. Work streams

All numbers are placeholders held in data files.

| Stream | Steps | Done | Expires |
|---|---|---|---|
| Ticket, simple | Reply at PC (4 s) or call at phone (about 8 s) | Satisfaction +1 (reply) or +3 (call); ticket quest +1 | Satisfaction -4 |
| Ticket, bug | File bug at PC (4 s); fix at dev table (about 8 s); reply at PC (4 s) | Satisfaction +2; ticket quest +1; fewer tickets of that type for the rest of the run | Satisfaction -4 |
| Lead | Proposal at sales PC (about 6 s); call at phone (about 8 s) | Revenue + deal size (small, medium, large; bigger = longer holds) | Lead lost |
| PR task | One of: post online at PC (about 4 s, 1 pt); respond to press at phone (about 8 s, 2 pts); broadcast interview at studio (about 10 s, 4 pts) | PR points | Missed |

Most tickets accept reply or call. Some "bug tickets" accept only the bug path. Reply is fast with a small satisfaction gain; call is slow with a large one; the bug path is slowest but reduces repeat tickets.

Work items spawn on timers from `RunDirector`; rates scale with career level and player count. Each has a deadline. Open items show as markers above their station and in a HUD queue.

### Stability and the dev table

- The stability bar (0 to 100) always drains (about 1% per second).
- Standing at the dev table raises it (about +6% per second), but only when no bug is open.
- While any bug is open, standing at the dev table works the oldest bug (about 8 s each, sped up by coding buffs). The bar rises only once no bugs are open.
- Bugs come from bug tickets and also spawn at a low rate that grows with level.
- At 0% there is an outage: satisfaction -1 per second and extra tickets spawn until the bar is above 0.

### Satisfaction

0 to 100, starts at 50. Reaching 0 means fired (run ends; keep 25% of quest payout). At run end, 90 or more earns a promotion (threshold is tunable; 100 would be too hard).

## 5. Quests and currency maths

`P` = players, `L` = career level (1 at start).

| Item | Formula |
|---|---|
| Ticket quest target | `40 * P * (1 + 0.2 * (L - 1))` |
| Revenue target | `2000 * P * (1 + 0.25 * (L - 1))` |
| Stability target | bar above 30% for 90% of the run |
| PR target | `6 + 2 * L` PR points |
| Quest ratio | `r = min(progress / target, 1.5)` |
| Run payout (Bonus) | sum over the four quests of `100 * r * (1 + 0.25 * (L - 1))`, plus end satisfaction (0 to 100) |
| Fired | 25% of the quest payout |
| Promotion | needs end satisfaction of 90 or more and the rival's bar below 100; then `L + 1`; task timers x `0.92^(L - 1)`, floor x 0.5 |
| Shop cost (later) | rank `n` costs `200 * 1.6^(n - 1)`; +6% per rank, 5 ranks max |

Bonus is computed and displayed at run end in this spec; spending it (the shop) is a later spec.

## 6. Meetings

Order: client, manager, CEO, at roughly 25%, 50%, and 75% of the run with small random jitter. A banner and siren warn 5 s before.

During a meeting the floor clears (stations, NPCs, furniture hidden and disabled); only the choice pads remain, each with a label and consequence preview. Work item deadlines keep running behind the scenes (assumption, adjustable). A countdown of about 15 s runs; the meeting ends early if every player has locked in. A player stands on a pad for 2 s to lock in; stepping off unlocks.

Resolution: majority pad wins; tied pads are chosen between at random; if nobody locked in, a random pad is chosen. A choice is always made.

Pad effects are data: satisfaction delta, quest target or progress changes, a stream's spawn rate for a while, or the rival's bar. Examples: the client demands a quick deal or promises a bigger one; the manager asks to prioritise tickets or revenue; the CEO raises the revenue target for a better payout.

## 7. Buff offers

After each meeting every player gets three cards on screen and picks one (idle: a random card after about 8 s). Buffs last for the run and stack. Examples: tickets faster, bug fixing ("coding") faster, PR faster, move speed, shotgun ammo.

Draw weight for a buff of work type `s`: `1 + 4 * (the player's share of actions in s)`. Mobility buffs have fixed weight 2. One of the three slots is guaranteed from the player's top work type. Each player has a `stats` dictionary (for example `hold_ticket`, `hold_bug`, `hold_pr`, `move_speed`) read by stations and the player script.

## 8. NPCs and the toy shotgun

All NPC logic runs on the host with a plain enum and `match`, walking on a baked `NavigationRegion3D`.

**The Chatter.** States: wander, approach, talk, leave, stunned. Targets the busiest player (one standing on a station). While he talks (about 5 s) the target's movement is 30% and station bars fill at 50%. After leaving he returns after about 20 s (shorter with level). A stun ends the talk immediately.

**The Climber (rival).** The office has an outbox board where completed work posts credit. About every 45 s (shorter with level) he walks to it and holds about 4 s to steal credit. A completed steal removes the credit of about the last 3 solves from quest progress and adds about 10 to his bar; his bar also creeps up slowly. If his bar reaches 100 before the run ends, no promotion. Counters: call him out (stand on him 2 s) cancels the steal and sends him away for 30 s; a shotgun stun freezes him about 5 s and cancels a steal. His bar is shown on the HUD.

**Toy shotgun.** One on a shelf; walk into it to pick up; 3 shots; short-range cone (about 12 degrees, up to about 8 m) with auto-aim to an NPC in the cone; cooldown about 0.8 s. Stuns the Chatter about 4 s and the Climber about 5 s. NPCs only, no friendly fire. Respawns on the shelf about 20 s after use. Later in co-op, firing is an RPC to the host, which validates the hit.

## 9. Architecture

Approach: nodes plus data plus a few pure functions, with one host-authority path for all state changes.

- `Office` (`Node3D`) is the main scene: floor, instanced stations, NPCs, `Players` container, `RunDirector`, HUD (`CanvasLayer`).
- `Player` is a `CharacterBody3D` moving in `_physics_process`; only the authority peer reads input. A single player is the host of Godot's default offline peer, so one code path covers solo and later co-op.
- `RunDirector` (a node in the scene, not a global) owns the run timer, quests, satisfaction, spawning, and the meeting schedule.
- Only the host mutates state. In co-op, clients send intents as RPCs and Godot's built-in multiplayer (`MultiplayerSpawner`, `MultiplayerSynchronizer`) replicates. Nothing is networked in this spec, but the code keeps to this rule.
- Data in `Resource` files: ticket types, buffs, quests, meetings. Formulas live as pure static functions in one script.
- A small `EventBus` autoload carries signals (`ticket_solved`, `meeting_started`, and similar); signals go up, method calls go down.
- Rejected: global game-state autoload (hard to replicate and test); an extra behaviour-tree addon (overkill for two NPCs).

## 10. Testing

- Plain GDScript test file run with `godot --headless --script`, plain asserts, no framework: payout, buff weights, majority and tie-break, quest ratio, stability drain and refill, hold times with stats.
- One seeded replay: load the office, run a fixed seed with scripted inputs for a few simulated minutes, check no errors and expected outcomes.
- Manual playtest checklist on a machine with a display (this container has none).

## 11. Build order

| Step | Adds |
|---|---|
| M1 | Walk around, tickets by reply and call, satisfaction bar, run timer, end screen |
| M2 | Dev table, stability bar, bugs, bug-ticket path |
| M3 | Leads, PR tasks (three ways), four quests, results screen |
| M4 | Three meetings with choice pads and resolution |
| M5 | Buff cards and player stats |
| M6 | The Chatter, the Climber and outbox board, the toy shotgun |

Each step is playable and ends with tests and a commit.

## 12. Assumptions to confirm

- Tone is comedic (not yet confirmed).
- Work deadlines keep running during meetings.
- Promotion threshold is 90 satisfaction, not exactly 100.
- The Stability quest target and all timings and numbers are placeholders.
- The Chatter's slow-down values and the shotgun's numbers are placeholders.
