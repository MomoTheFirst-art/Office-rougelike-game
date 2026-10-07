extends Node
## Autoload. Signals only; peers talk through here, parents call children directly.

signal item_spawned(item)
signal item_done(item, player)
signal item_expired(item)
signal satisfaction_changed(value: float)
signal stability_changed(value: float)
signal quest_changed(quest: String, progress: float, target: float)
signal meeting_started(def)
signal meeting_ended(def, pad: int)
signal npc_stunned(npc)
signal run_ended(result: Dictionary)
