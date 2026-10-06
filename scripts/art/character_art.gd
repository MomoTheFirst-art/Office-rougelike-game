class_name CharacterArt
extends RefCounted
## A chunky worker built from simple shapes. Faces -Z, like everything in Godot.


static func _part(root: Node3D, part_name: String, mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part_name
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material = mat
	m.mesh = mesh
	m.position = pos
	root.add_child(m)
	return m


static func build(shirt: Color, hair: Color, skin := Color(0.96, 0.78, 0.62)) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var body := CapsuleMesh.new()
	body.radius = 0.38
	body.height = 1.2
	_part(root, "Body", body, shirt, Vector3(0, 0.6, 0))
	var head := SphereMesh.new()
	head.radius = 0.3
	head.height = 0.6
	_part(root, "Head", head, skin, Vector3(0, 1.45, 0))
	var cap := SphereMesh.new()
	cap.radius = 0.33
	cap.height = 0.33
	cap.is_hemisphere = true
	_part(root, "Hair", cap, hair, Vector3(0, 1.5, 0.02))
	var nose := BoxMesh.new()
	nose.size = Vector3(0.1, 0.1, 0.14)
	_part(root, "Nose", nose, skin.darkened(0.15), Vector3(0, 1.43, -0.32))
	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.1
		arm.height = 0.6
		var a := _part(root, "ArmL" if side < 0.0 else "ArmR", arm, shirt.darkened(0.15), Vector3(side * 0.5, 0.85, 0))
		a.rotation.z = side * 0.15
	return root
