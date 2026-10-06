extends RefCounted

var tree: SceneTree


func _meshes(n: Node) -> int:
	var count := 0
	for c in n.get_children():
		if c is MeshInstance3D:
			count += 1
		count += _meshes(c)
	return count


func test_room_has_back_and_side_walls_but_an_open_front() -> void:
	var room := OfficeArt.room(Vector3(24, 0.2, 16))
	for part in ["BackWall", "LeftWall", "RightWall", "Rug"]:
		T.truth(room.has_node(part), "has %s" % part)
	T.truth(not room.has_node("FrontWall"), "front is open so the camera can see in")
	T.truth(room.get_node("LeftWall").mesh.size.y < room.get_node("BackWall").mesh.size.y, "side walls are lower than the back wall")
	room.free()


func test_every_work_station_gets_a_prop_made_of_several_shapes() -> void:
	for kind in ["pc", "phone", "devtable", "sales", "studio"]:
		var prop := OfficeArt.prop_for(kind)
		T.truth(prop != null, "prop for %s" % kind)
		if prop != null:
			T.truth(_meshes(prop) >= 3, "%s prop is more than a box, got %d shapes" % [kind, _meshes(prop)])
			prop.free()
	T.truth(OfficeArt.prop_for("pad") == null, "no prop for meeting pads")
	T.truth(OfficeArt.prop_for("callout") == null, "no prop for the call-out spot")


func test_office_is_dressed() -> void:
	RunDirector.carried_level = 1
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	T.truth(office.has_node("Room"), "room")
	T.truth(office.has_node("Decor"), "plants, cooler and clock")
	T.truth(office.get_node("Decor").get_child_count() >= 4, "some decoration")
	for n in ["Pc", "Phone", "Devtable", "Sales", "Studio"]:
		T.truth(office.get_node(n).has_node("Prop"), "%s has its prop" % n)
	var pad: Station = office.get_node("Pc")
	T.truth(pad.get_child(0).mesh.size.y <= 0.15, "the stand-here spot is a flat pad")
	T.truth(pad.label.position.y > 2.0, "label floats above the prop")
	T.truth(pad.label.font_size >= 48 and pad.label.outline_size > 0 and pad.label.no_depth_test, "label is big, outlined and never hidden")
	var env: WorldEnvironment = office.get_node("Environment")
	T.truth(env.environment.ambient_light_energy > 0.0, "ambient light so shadows are not black")
	T.truth(office.get_node("Sun").shadow_enabled, "sun casts shadows")
	var p: Player = office.player_list[0]
	T.truth(p.bounds.has_area(), "player is kept inside the walls")
	T.truth(p.bounds.has_point(Vector2(p.global_position.x, p.global_position.z)), "and starts inside")
	office.free()


func test_camera_follows_the_player_and_looks_at_the_middle_during_meetings() -> void:
	RunDirector.carried_level = 5
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	var cam: FollowCamera = office.get_node("Camera")
	T.truth(cam.target == office.player_list[0], "follows the player")
	var d: RunDirector = office.director
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	for i in 60:
		d.tick(1.0 / 60.0)
	T.truth(d.meeting != null, "meeting open")
	T.eq(cam.override_focus, Vector3.ZERO, "camera shows the pads in the middle")
	for i in int(16.0 * 60.0):
		d.tick(1.0 / 60.0)
	T.truth(cam.override_focus == null, "camera is back on the player")
	office.free()
	RunDirector.carried_level = 1
