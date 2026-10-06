class_name Player
extends CharacterBody3D
## One office worker. Only the authority peer reads input; step() is what tests drive.

const BASE_SPEED := 5.0

var stats: Dictionary = {}  # e.g. {"move_speed": 1.1, "hold_tickets": 0.85}
var work_rate := 1.0  # below 1 while the Chatter talks to us
var move_mult := 1.0
var actions: Dictionary = {}  # stream -> count of finished items
var ammo := 0
var facing := Vector3(0, 0, -1)  # last direction we moved in
var fire_cooldown := 0.0
var npc_targets: Array[Node3D] = []  # what the toy shotgun can hit
var b: Balance  # set by the Office; used when firing from input
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


## Toy shotgun. A miss still spends the shell. Returns false only if it could not fire at all.
func fire(targets: Array[Node3D], bal: Balance) -> bool:
	if ammo <= 0 or fire_cooldown > 0.0:
		return false
	ammo -= 1
	fire_cooldown = bal.shotgun_cooldown
	var best: Node3D = null
	var best_d := INF
	for t in targets:
		if not is_instance_valid(t) or t is Player:
			continue
		var to: Vector3 = t.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > bal.shotgun_range or rad_to_deg(facing.angle_to(to)) > bal.shotgun_cone_deg:
			continue
		if d < best_d:
			best = t
			best_d = d
	if best != null:
		best.stun(bal.stun_climber if best is Climber else bal.stun_chatter)
	return true


func step(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	var dir := intent_move()
	if dir != Vector2.ZERO:
		facing = Vector3(dir.x, 0.0, dir.y).normalized()
	if not use_scripted and b != null and Input.is_action_just_pressed("fire"):
		fire(npc_targets, b)
	velocity = Vector3(dir.x, 0.0, dir.y) * BASE_SPEED * move_mult * stat_mult("move_speed")
	move_and_slide()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		step(delta)
