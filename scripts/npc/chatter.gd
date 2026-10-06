class_name Chatter
extends CharacterBody3D
## The annoying NPC: walks up to the busiest player and talks, slowing them down.
## ponytail: steers straight at its target; the office floor has no obstacles, so no navmesh.
## Add a NavigationAgent3D here when furniture gets colliders.

enum State { WANDER, APPROACH, TALK, LEAVE, STUNNED }

var b: Balance
var level := 1
var players: Array[Player] = []
var stations: Array[Station] = []
var home := Vector3.ZERO
var state := State.WANDER
var cooldown_left := 0.0
var target: Player = null
var _timer := 0.0  # talk or stun seconds left
var visual: Node3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	visual = CharacterArt.build(Color(0.95, 0.6, 0.15), Color(0.85, 0.85, 0.85))
	add_child(visual)


func cooldown_seconds() -> float:
	return b.chatter_cooldown * Rules.timer_scale(level)


## The busiest player (standing on a station), else the nearest one; null if there is nobody.
func pick_target() -> Player:
	var best: Player = null
	var best_busy := false
	var best_d := INF
	for i in players.size():
		var p = players[i]
		if not is_instance_valid(p):
			continue
		var busy := false
		for s in stations:
			if s.holder == p:
				busy = true
		var d := global_position.distance_to(p.global_position)
		if (busy and not best_busy) or (busy == best_busy and d < best_d):
			best = p
			best_busy = busy
			best_d = d
	return best


## A meeting starts: drop any talk or approach and head home, so nobody stays slowed.
func interrupt() -> void:
	if state == State.TALK or state == State.APPROACH:
		_release()
		_begin_leave()


## A stun ends any talk at once. Stunning a stunned NPC refreshes the time; it does not stack.
func stun(seconds: float) -> void:
	_release()
	target = null
	state = State.STUNNED
	_timer = seconds
	EventBus.npc_stunned.emit(self)


func tick(delta: float) -> void:
	match state:
		State.WANDER:
			cooldown_left -= delta
			if cooldown_left <= 0.0:
				target = pick_target()
				if target != null:
					state = State.APPROACH
		State.APPROACH:
			if not is_instance_valid(target):
				_begin_leave()
				return
			_move_toward(target.global_position)
			if _flat_distance(target.global_position) <= b.chatter_reach:
				state = State.TALK
				_timer = b.chatter_talk
				target.move_mult = b.chatter_move_mult
				target.work_rate = b.chatter_work_mult
		State.TALK:
			if not is_instance_valid(target):
				_begin_leave()
				return
			if _flat_distance(target.global_position) > b.chatter_reach:
				_move_toward(target.global_position)
			_timer -= delta
			if _timer <= 0.0:
				_release()
				_begin_leave()
		State.LEAVE:
			_move_toward(home)
			if _flat_distance(home) <= 0.5:
				state = State.WANDER
		State.STUNNED:
			_timer -= delta
			if _timer <= 0.0:
				_begin_leave()


func _begin_leave() -> void:
	target = null
	state = State.LEAVE
	cooldown_left = cooldown_seconds()


func _release() -> void:
	if state == State.TALK and is_instance_valid(target):
		target.move_mult = 1.0
		target.work_rate = 1.0


func _flat_distance(to: Vector3) -> float:
	return Vector2(global_position.x - to.x, global_position.z - to.z).length()


func _move_toward(to: Vector3) -> void:
	var dir := Vector3(to.x - global_position.x, 0.0, to.z - global_position.z).normalized()
	velocity = dir * b.chatter_speed
	move_and_slide()
	if dir != Vector3.ZERO:
		visual.rotation.y = lerp_angle(visual.rotation.y, Player.yaw_for(dir), 0.25)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)
