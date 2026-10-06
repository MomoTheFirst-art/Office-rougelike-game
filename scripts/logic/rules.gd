class_name Rules
extends RefCounted
## Pure static formulas. No state, no nodes: everything here is testable headlessly.


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
