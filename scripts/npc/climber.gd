class_name Climber
extends CharacterBody3D
## The rival NPC. Every so often he walks to the outbox board and holds there to steal
## credit for the team's recent work. Call him out or stun him to cancel a steal.
## ponytail: steers straight at the board; the floor has no obstacles (see Chatter).

enum State { IDLE, TO_BOARD, STEALING, AWAY, STUNNED }

var b: Balance
var level := 1
var director: RunDirector
var home := Vector3.ZERO
var board := Vector3.ZERO
var state := State.IDLE
var cooldown_left := 0.0
var callout: Station  # the "call him out" spot; follows him as a child
var _timer := 0.0
var visual: Node3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	shape.shape = capsule
	shape.position.y = capsule.height / 2.0
	add_child(shape)
	visual = CharacterArt.build(Color(0.75, 0.15, 0.5), Color(0.1, 0.1, 0.1))
	add_child(visual)


func interval() -> float:
	return b.climber_interval * Rules.timer_scale(level)


## Standing on him for the hold time cancels the steal and sends him away.
func call_out() -> void:
	if state == State.TO_BOARD or state == State.STEALING:
		state = State.AWAY
		_timer = b.climber_away


## A stun freezes him and cancels a steal. Stunning a stunned NPC refreshes the time; it does not stack.
func stun(seconds: float) -> void:
	state = State.STUNNED
	_timer = seconds
	EventBus.npc_stunned.emit(self)


func tick(delta: float) -> void:
	match state:
		State.IDLE:
			if _flat_distance(home) > 0.5:
				_move_toward(home)
			cooldown_left -= delta
			if cooldown_left <= 0.0:
				state = State.TO_BOARD
		State.TO_BOARD:
			_move_toward(board)
			if _flat_distance(board) <= 1.0:
				state = State.STEALING
				_timer = b.climber_steal_hold
		State.STEALING:
			_timer -= delta
			if _timer <= 0.0:
				director.steal(b.climber_steal_back)
				_go_idle()
		State.AWAY:
			_move_toward(home)
			_timer -= delta
			if _timer <= 0.0:
				_go_idle()
		State.STUNNED:
			_timer -= delta
			if _timer <= 0.0:
				_go_idle()
	if callout != null:  # after the transitions, so it never lags a tick
		callout.enabled = state == State.TO_BOARD or state == State.STEALING


func _go_idle() -> void:
	state = State.IDLE
	cooldown_left = interval()


func _flat_distance(to: Vector3) -> float:
	return Vector2(global_position.x - to.x, global_position.z - to.z).length()


func _move_toward(to: Vector3) -> void:
	var dir := Vector3(to.x - global_position.x, 0.0, to.z - global_position.z).normalized()
	velocity = dir * b.climber_speed
	move_and_slide()
	if dir != Vector3.ZERO:
		visual.rotation.y = lerp_angle(visual.rotation.y, Player.yaw_for(dir), 0.25)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)
