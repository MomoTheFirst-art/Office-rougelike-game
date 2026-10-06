class_name Player
extends CharacterBody3D
## One office worker. Only the authority peer reads input; step() is what tests drive.

const BASE_SPEED := 5.0

var stats: Dictionary = {}  # e.g. {"move_speed": 1.1, "hold_tickets": 0.85}
var work_rate := 1.0  # below 1 while the Chatter talks to us
var move_mult := 1.0
var actions: Dictionary = {}  # stream -> count of finished items
var ammo := 0
var scripted_move := Vector2.ZERO
var use_scripted := false


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.position.y = capsule.height / 2.0
	add_child(mesh)


func stat_mult(key: String) -> float:
	return stats.get(key, 1.0)


func record_action(stream: String) -> void:
	actions[stream] = actions.get(stream, 0) + 1


## Stream -> share of this player's finished actions (empty when they have none).
func action_shares() -> Dictionary:
	var total := 0
	for n: int in actions.values():
		total += n
	var shares := {}
	for s: String in actions:
		shares[s] = float(actions[s]) / total
	return shares


## "mul" multiplies the stat (starting at 1.0); "add" adds to it (starting at 0.0).
func add_stat(stat: String, op: String, value: float) -> void:
	if op == "mul":
		stats[stat] = stats.get(stat, 1.0) * value
	else:
		stats[stat] = stats.get(stat, 0.0) + value


func intent_move() -> Vector2:
	if use_scripted:
		return scripted_move
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func step(_delta: float) -> void:
	var dir := intent_move()
	velocity = Vector3(dir.x, 0.0, dir.y) * BASE_SPEED * move_mult * stat_mult("move_speed")
	move_and_slide()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		step(delta)
