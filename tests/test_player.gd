extends RefCounted

var tree: SceneTree


func _spawn(z: float) -> Player:
	var p := Player.new()
	tree.root.add_child(p)
	p.global_position = Vector3(0, 0, z)
	p.use_scripted = true
	return p


func test_player_moves_with_scripted_input() -> void:
	var p := _spawn(-5.0)
	p.scripted_move = Vector2(1, 0)
	for i in 10:
		p.step(1.0 / 60.0)
	T.truth(p.global_position.x > 0.5, "moved right, x=%s" % p.global_position.x)
	p.free()


func test_move_mult_scales_speed() -> void:
	var fast := _spawn(-5.0)
	var slow := _spawn(5.0)
	slow.move_mult = 0.3
	fast.scripted_move = Vector2(1, 0)
	slow.scripted_move = Vector2(1, 0)
	for i in 10:
		fast.step(1.0 / 60.0)
		slow.step(1.0 / 60.0)
	T.near(slow.global_position.x / fast.global_position.x, 0.3, 0.1, "slow is 0.3 of fast")
	fast.free()
	slow.free()


func test_stat_mult_defaults_to_one_and_scales_speed() -> void:
	var p := _spawn(-5.0)
	T.eq(p.stat_mult("hold_tickets"), 1.0, "missing stat is 1.0")
	p.stats["move_speed"] = 2.0
	p.scripted_move = Vector2(1, 0)
	for i in 10:
		p.step(1.0 / 60.0)
	T.truth(p.global_position.x > 1.2, "double speed, x=%s" % p.global_position.x)
	p.free()


func test_record_action_counts_by_stream() -> void:
	var p := Player.new()
	p.record_action("tickets")
	p.record_action("tickets")
	p.record_action("pr")
	T.eq(p.actions, {"tickets": 2, "pr": 1}, "actions")
	p.free()
