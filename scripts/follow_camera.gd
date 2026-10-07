class_name FollowCamera
extends Camera3D
## Smooth top-down follow camera. Tune offset, fov and the focus limits here.
## override_focus pins the view (a meeting looks at the middle of the room).

@export var offset := Vector3(0, 9.0, 7.0)
@export var follow_speed := 6.0
@export var focus_min := Vector3(-6.0, 0.0, -3.5)  # the focus point is kept inside this box
@export var focus_max := Vector3(6.0, 0.0, 4.0)

var target: Node3D
var override_focus: Variant = null  # Vector3 or null


func _init() -> void:
	fov = 60.0


## Where the camera should sit for a focus point: offset from it, with the focus kept inside the room.
static func goal(focus: Vector3, off: Vector3, lo: Vector3, hi: Vector3) -> Vector3:
	return focus.clamp(lo, hi) + off


func _focus() -> Vector3:
	if override_focus != null:
		return override_focus
	if is_instance_valid(target):
		return target.global_position
	return Vector3.ZERO


## Jump straight to the goal (use once at the start of a run).
func snap() -> void:
	global_position = goal(_focus(), offset, focus_min, focus_max)
	look_at(_focus().clamp(focus_min, focus_max))


func tick(delta: float) -> void:
	var want := goal(_focus(), offset, focus_min, focus_max)
	global_position = global_position.lerp(want, 1.0 - exp(-follow_speed * delta))
	look_at(_focus().clamp(focus_min, focus_max))


func _process(delta: float) -> void:
	tick(delta)
