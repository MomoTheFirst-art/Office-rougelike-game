class_name Rules
extends RefCounted
## Pure static formulas. No state, no nodes: everything here is testable headlessly.


const RATIO_CAP := 1.5  # overachieving counts up to 150%
const TIMER_DECAY := 0.92  # task timers shrink 8% per level above 1
const TIMER_FLOOR := 0.5


static func ticket_target(players: int, level: int, b: Balance) -> float:
	return b.ticket_base * players * (1.0 + b.ticket_level_growth * (level - 1))


static func revenue_target(players: int, level: int, b: Balance) -> float:
	return b.revenue_base * players * (1.0 + b.revenue_level_growth * (level - 1))


static func pr_target(level: int, b: Balance) -> float:
	return b.pr_base + b.pr_per_level * level


static func quest_ratio(progress: float, target: float) -> float:
	if target <= 0.0:
		return 0.0
	return minf(progress / target, RATIO_CAP)


## Run payout: per active quest, scaled by level; fired keeps a share; plus end satisfaction.
static func bonus(ratios: Array[float], level: int, end_satisfaction: float, fired: bool, b: Balance) -> int:
	var quest := 0.0
	for r in ratios:
		quest += b.payout_per_quest * r
	quest *= 1.0 + b.payout_level_growth * (level - 1)
	if fired:
		quest *= b.fired_payout_share
	return roundi(quest + end_satisfaction)


static func promoted(end_satisfaction: float, rival_bar: float, b: Balance) -> bool:
	return end_satisfaction >= b.promo_threshold and rival_bar < 100.0


const MOBILITY_WEIGHT := 2.0


## Draw weight for a buff of a work type the player did `share` of their actions in.
static func buff_weight(share: float) -> float:
	return 1.0 + 4.0 * share


static func _weighted_pick(cands: Array, shares: Dictionary, rng: RandomNumberGenerator) -> BuffDef:
	var weights: Array[float] = []
	var total := 0.0
	for d: BuffDef in cands:
		var w := MOBILITY_WEIGHT if d.stream == "mobility" else buff_weight(shares.get(d.stream, 0.0))
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in cands.size():
		roll -= weights[i]
		if roll <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]


## Three distinct cards: one drawn from the player's top work type (if the pool has any), the rest weighted.
static func draw_offers(pool: Array[BuffDef], shares: Dictionary, rng: RandomNumberGenerator) -> Array[BuffDef]:
	var offers: Array[BuffDef] = []
	var remaining := pool.duplicate()
	var top := ""
	var best := 0.0
	for s: String in shares:
		if shares[s] > best:
			best = shares[s]
			top = s
	if top != "":
		var cands := remaining.filter(func(d: BuffDef): return d.stream == top)
		if not cands.is_empty():
			var pick := _weighted_pick(cands, shares, rng)
			offers.append(pick)
			remaining.erase(pick)
	while offers.size() < 3 and not remaining.is_empty():
		var pick := _weighted_pick(remaining, shares, rng)
		offers.append(pick)
		remaining.erase(pick)
	return offers


## Majority pad wins; tied pads are chosen between at random; nobody locked means all are tied.
static func pick_meeting_pad(votes: Array[int], rng: RandomNumberGenerator) -> int:
	var top: int = votes.max()
	var tied: Array[int] = []
	for i in votes.size():
		if votes[i] == top:
			tied.append(i)
	return tied[rng.randi_range(0, tied.size() - 1)]


static func timer_scale(level: int) -> float:
	return maxf(TIMER_FLOOR, pow(TIMER_DECAY, level - 1))


## Is a feature available at this career level?
static func unlocked(feature: String, level: int, b: Balance) -> bool:
	return level >= b.unlock_levels[feature]


## The stability bar: always drains; refills only while someone stands at the dev table and no bug is open.
static func stability_step(value: float, dt: float, bugs_open: int, standing: bool, b: Balance) -> float:
	var v := value - b.stability_drain * dt
	if standing and bugs_open == 0:
		v += b.stability_refill * dt
	return clampf(v, 0.0, 100.0)


## Seconds to fill a station: the base time scaled by the player's stat for that key.
static func hold_seconds(base: float, stats: Dictionary, key: String) -> float:
	return base * stats.get(key, 1.0)
