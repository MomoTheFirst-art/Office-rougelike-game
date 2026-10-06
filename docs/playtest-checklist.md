# Playtest checklist (first playable)

Run on a machine with a display and Godot 4.7. The container that built this had no display, so
the tests prove the logic but nobody has seen or felt the game yet.

Open the folder in Godot and press F5. Move with WASD or the arrow keys, fire with Space.
The level is kept in memory: a promotion moves you up on the next run, and closing the game
starts again at level 1. To try a later level without earning it, temporarily set
`static var carried_level := 6` in `scripts/run_director.gd`.

## Level 1: tickets
- [ ] Camera angle shows the whole floor; nothing is cut off.
- [ ] The player is easy to find and movement feels responsive (not floaty, not slow).
- [ ] Standing on a blue PC fills a bar over about 4 s; the station label shows the percent.
- [ ] A reply raises satisfaction by 1; a phone call (yellow) takes about 8 s and raises it by 3.
- [ ] Stepping off a station resets the bar.
- [ ] A station with no matching work does nothing when you stand on it.
- [ ] An unanswered ticket expires after about 40 s and drops satisfaction by 4.
- [ ] Reaching 0 shows "YOU WERE FIRED"; surviving 10 minutes shows "WORKDAY OVER" and a Bonus.
- [ ] Enter restarts the run.

## Level 2: stability and bugs
- [ ] The stability bar appears and drains about 1% per second.
- [ ] Standing at the red dev table refills it about 6% per second.
- [ ] Bug tickets need: file at a PC, fix at the dev table, then reply at a PC.
- [ ] While any bug is open the bar does not refill; standing there fixes bugs first.
- [ ] At 0% stability satisfaction drains and extra tickets appear.

## Level 3 and 4: PR and sales
- [ ] PR tasks can be done three ways: PC (fast), phone (medium), studio (slow, most points).
- [ ] The sales PC (green) then the phone closes a lead and adds revenue; bigger deals take longer.
- [ ] A missed PR task or lost lead costs no satisfaction.

## Level 5: meetings and buffs
- [ ] The banner warns "Meeting in N s" 5 s before; the order is client, manager, CEO.
- [ ] The floor clears; three labelled pads appear; standing on one for 2 s locks it.
- [ ] The meeting ends early when you are locked, or after the 15 s countdown.
- [ ] Work keeps piling up behind the meeting (deadlines keep running).
- [ ] Afterwards three buff cards appear; keys 1, 2, 3 pick one; doing nothing picks for you after 8 s.
- [ ] Buffs you pick make the matching work visibly faster.

## Level 6: the NPCs
- [ ] The Chatter (orange) walks up to you and slows you for about 5 s, then leaves for about 20 s.
- [ ] The Climber (magenta) walks to the outbox board and holds there about 4 s.
- [ ] A completed steal removes recent solves and raises the pink rival bar.
- [ ] Standing on the yellow patch under him for 2 s cancels the steal and sends him away.
- [ ] The toy shotgun on the shelf gives 3 shells; Space stuns whichever NPC you face, nearest first.
- [ ] The shelf is empty until about 20 s after the shells are used up.
- [ ] A full rival bar means no promotion even with high satisfaction.

## Numbers that felt wrong
Write them here. The numbers live in `data/balance.tres` (edit it in the Godot inspector; running
`tools/make_data.gd` overwrites it with the defaults), and the meeting and buff texts live in
`tools/make_data.gd`.

- 
