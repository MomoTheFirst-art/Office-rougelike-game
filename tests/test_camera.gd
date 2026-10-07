extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0
const LO := Vector3(-6, 0, -3.5)
const HI := Vector3(6, 0, 4)
const OFF := Vector3(0, 9, 7)


func _cam() -> FollowCamera:
	var c := FollowCamera.new()
	tree.root.add_child(c)
	return c


func _run(c: FollowCamera, seconds: float) -> void:
	for i in int(seconds / DT):
		c.tick(DT)


func test_goal_is_the_focus_plus_offset_clamped_to_the_room() -> void:
	T.eq(FollowCamera.goal(Vector3(2, 0, 1), OFF, LO, HI), Vector3(2, 9, 8), "inside the room")
	T.eq(FollowCamera.goal(Vector3(100, 0, 100), OFF, LO, HI), HI + OFF, "far corner is clamped")
	T.eq(FollowCamera.goal(Vector3(-100, 0, -100), OFF, LO, HI), LO + OFF, "other corner is clamped")


func test_it_glides_to_its_target() -> void:
	var player := Node3D.new()
	tree.root.add_child(player)
	player.global_position = Vector3(3, 0, 1)
	var c := _cam()
	c.target = player
	c.global_position = Vector3(-20, 30, 20)
	_run(c, 3.0)
	var want := FollowCamera.goal(Vector3(3, 0, 1), c.offset, c.focus_min, c.focus_max)
	T.truth(c.global_position.distance_to(want) < 0.05, "arrived, off by %s" % c.global_position.distance_to(want))
	player.free()
	c.free()


func test_snap_jumps_straight_to_the_goal() -> void:
	var player := Node3D.new()
	tree.root.add_child(player)
	player.global_position = Vector3(-2, 0, 0)
	var c := _cam()
	c.target = player
	c.snap()
	T.eq(c.global_position, FollowCamera.goal(Vector3(-2, 0, 0), c.offset, c.focus_min, c.focus_max), "snapped")
	player.free()
	c.free()


func test_override_focus_wins_over_the_target_until_cleared() -> void:
	var player := Node3D.new()
	tree.root.add_child(player)
	player.global_position = Vector3(5, 0, 3)
	var c := _cam()
	c.target = player
	c.override_focus = Vector3.ZERO
	_run(c, 3.0)
	T.truth(c.global_position.distance_to(c.offset) < 0.05, "looking at the middle of the room")
	c.override_focus = null
	_run(c, 3.0)
	T.truth(c.global_position.x > 4.0, "back on the player")
	player.free()
	c.free()


func test_it_looks_at_the_focus() -> void:
	var player := Node3D.new()
	tree.root.add_child(player)
	player.global_position = Vector3(2, 0, 0)
	var c := _cam()
	c.target = player
	c.snap()
	c.tick(DT)
	var to_focus := (Vector3(2, 0, 0) - c.global_position).normalized()
	var forward := -c.global_transform.basis.z
	T.truth(forward.dot(to_focus) > 0.999, "pointing at the player")
	player.free()
	c.free()
