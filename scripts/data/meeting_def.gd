class_name MeetingDef
extends Resource
## A meeting: one pad per label. effects[i] is what pad i does, as director effect keys:
## satisfaction (float), target_mult ({quest: float}), payout_mult (float),
## spawn_mult ({stream, mult, seconds}), rival_bar (float).

@export var title := ""
@export var labels := PackedStringArray()
@export var previews := PackedStringArray()
@export var effects: Array[Dictionary] = []
