class_name Rules
extends RefCounted
## Pure static formulas. No state, no nodes: everything here is testable headlessly.


## Is a feature available at this career level?
static func unlocked(feature: String, level: int, b: Balance) -> bool:
	return level >= b.unlock_levels[feature]


## Seconds to fill a station: the base time scaled by the player's stat for that key.
static func hold_seconds(base: float, stats: Dictionary, key: String) -> float:
	return base * stats.get(key, 1.0)
