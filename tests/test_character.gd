extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _names(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		out.append(String(c.name))
	return out


func test_character_art_has_a_body_head_hair_nose_and_arms() -> void:
	var v := CharacterArt.build(Color.RED, Color.BLACK)
	for part in ["Body", "Head", "Hair", "Nose", "ArmL", "ArmR"]:
		T.truth(v.has_node(part), "has %s" % part)
	var shirt: StandardMaterial3D = v.get_node("Body").mesh.material
	T.eq(shirt.albedo_color, Color.RED, "shirt colour")
	T.truth(v.get_node("Nose").position.z < 0.0, "the nose points forward (-Z)")
	T.truth(v.get_node("Head").position.y > v.get_node("Body").position.y, "head above body")
	v.free()


func test_yaw_for_matches_godots_forward_axis() -> void:
	T.near(Player.yaw_for(Vector3(0, 0, -1)), 0.0, 0.001, "forward is -Z")
	T.near(Player.yaw_for(Vector3(1, 0, 0)), -PI / 2.0, 0.001, "right")
	T.near(Player.yaw_for(Vector3(-1, 0, 0)), PI / 2.0, 0.001, "left")


func test_players_get_distinct_shirt_colours() -> void:
	var seen := {}
	for i in 4:
		seen[Player.shirt_color(i)] = true
	T.eq(seen.size(), 4, "four players, four colours")


func test_player_has_a_character_and_a_you_marker() -> void:
	var p := Player.new()
	tree.root.add_child(p)
	T.truth(p.has_node("Visual/Head"), "character head")
	T.truth(p.has_node("Marker"), "marker")
	T.truth(p.get_node("Marker/Text").text.contains("YOU"), "marker says YOU")
	p.free()


func test_player_turns_to_face_where_they_walk() -> void:
	var p := Player.new()
	tree.root.add_child(p)
	p.global_position = Vector3(0, 0, 5)
	p.use_scripted = true
	p.scripted_move = Vector2(1, 0)
	for i in 60:
		p.step(DT)
	T.near(p.get_node("Visual").rotation.y, -PI / 2.0, 0.1, "faces right")
	p.scripted_move = Vector2(0, 1)
	for i in 60:
		p.step(DT)
	T.near(absf(p.get_node("Visual").rotation.y), PI, 0.1, "faces the camera")
	p.free()


func test_npcs_are_people_too_and_turn_when_they_walk() -> void:
	var b := Balance.new()
	var c := Chatter.new()
	c.b = b
	tree.root.add_child(c)
	var k := Climber.new()
	k.b = b
	tree.root.add_child(k)
	T.truth(c.has_node("Visual/Head") and k.has_node("Visual/Head"), "both have heads")
	k.global_position = Vector3(0, 0, 0)
	for i in 60:
		k._move_toward(Vector3(10, 0, 0))
	T.near(k.get_node("Visual").rotation.y, -PI / 2.0, 0.2, "the Climber faces where he walks")
	c.free()
	k.free()


func test_player_stays_inside_the_room() -> void:
	var p := Player.new()
	tree.root.add_child(p)
	p.bounds = Rect2(-5, -3, 10, 6)  # x from -5 to 5, z from -3 to 3
	p.global_position = Vector3(0, 0, 0)
	p.use_scripted = true
	p.scripted_move = Vector2(1, 0)
	for i in 600:
		p.step(DT)
	T.near(p.global_position.x, 5.0, 0.001, "stopped at the right wall")
	p.scripted_move = Vector2(0, -1)
	for i in 600:
		p.step(DT)
	T.near(p.global_position.z, -3.0, 0.001, "stopped at the back wall")
	p.scripted_move = Vector2(-1, 1)
	for i in 1200:
		p.step(DT)
	T.near(p.global_position.x, -5.0, 0.001, "stopped at the left wall")
	T.near(p.global_position.z, 3.0, 0.001, "stopped at the front edge")
	p.free()


func test_a_player_with_no_bounds_is_free_to_roam() -> void:
	var p := Player.new()
	tree.root.add_child(p)
	p.global_position = Vector3(0, 0, 20)
	p.use_scripted = true
	p.scripted_move = Vector2(1, 0)
	for i in 600:
		p.step(DT)
	T.truth(p.global_position.x > 20.0, "unbounded")
	p.free()
