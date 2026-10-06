class_name BuffDef
extends Resource
## A buff card. stat is a Player.stats key; op "mul" multiplies (start 1.0), "add" adds (start 0.0).

@export var id := ""
@export var title := ""
@export var description := ""
@export var stream := ""  # tickets, bugs, business, pr, or mobility
@export var stat := ""
@export var op := "mul"
@export var value := 1.0
