class_name OfficeArt
extends RefCounted
## The room, the decoration, and a desk-with-props for each work station. All flat-colour shapes.


static func _box(parent: Node3D, part_name: String, size: Vector3, pos: Vector3, color: Color, glow := 0.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh.material = mat
	m.mesh = mesh
	m.position = pos
	parent.add_child(m)
	return m


static func _cyl(parent: Node3D, part_name: String, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material = mat
	m.mesh = mesh
	m.position = pos
	parent.add_child(m)
	return m


static func room(floor_size: Vector3) -> Node3D:
	var r := Node3D.new()
	r.name = "Room"
	var wall := Color(0.9, 0.86, 0.78)
	var half_x := floor_size.x / 2.0
	var half_z := floor_size.z / 2.0
	_box(r, "BackWall", Vector3(floor_size.x + 0.8, 3.6, 0.4), Vector3(0, 1.8, -half_z - 0.2), wall)
	_box(r, "LeftWall", Vector3(0.4, 1.4, floor_size.z), Vector3(-half_x - 0.2, 0.7, 0), wall.darkened(0.08))
	_box(r, "RightWall", Vector3(0.4, 1.4, floor_size.z), Vector3(half_x + 0.2, 0.7, 0), wall.darkened(0.08))
	_box(r, "Baseboard", Vector3(floor_size.x, 0.25, 0.1), Vector3(0, 0.125, -half_z + 0.05), Color(0.35, 0.3, 0.28))
	_box(r, "Rug", Vector3(10, 0.03, 5), Vector3(0, 0.015, 0.5), Color(0.45, 0.52, 0.66))
	for i in 4:
		_box(r, "Window%d" % (i + 1), Vector3(2.6, 1.6, 0.06), Vector3(-9.0 + i * 6.0, 2.1, -half_z + 0.03), Color(0.65, 0.82, 0.95), 0.6)
	return r


static func decor() -> Node3D:
	var d := Node3D.new()
	d.name = "Decor"
	for spot in [Vector3(-11.2, 0, -7.0), Vector3(11.2, 0, -7.0), Vector3(-11.2, 0, 7.0)]:
		var plant := Node3D.new()
		plant.name = "Plant"
		d.add_child(plant)
		plant.position = spot
		_cyl(plant, "Pot", 0.4, 0.6, Vector3(0, 0.3, 0), Color(0.7, 0.4, 0.3))
		var leaves := MeshInstance3D.new()
		leaves.name = "Leaves"
		var ball := SphereMesh.new()
		ball.radius = 0.6
		ball.height = 1.2
		ball.material = StandardMaterial3D.new()
		ball.material.albedo_color = Color(0.25, 0.6, 0.3)
		leaves.mesh = ball
		leaves.position = Vector3(0, 1.1, 0)
		plant.add_child(leaves)
	var cooler := Node3D.new()
	cooler.name = "Cooler"
	d.add_child(cooler)
	cooler.position = Vector3(-11.2, 0, -3.5)
	_box(cooler, "Body", Vector3(0.7, 1.1, 0.7), Vector3(0, 0.55, 0), Color(0.85, 0.88, 0.92))
	_cyl(cooler, "Jug", 0.28, 0.6, Vector3(0, 1.4, 0), Color(0.5, 0.75, 0.95))
	var clock := Node3D.new()
	clock.name = "Clock"
	d.add_child(clock)
	clock.position = Vector3(0, 3.0, -7.9)
	_cyl(clock, "Face", 0.6, 0.1, Vector3.ZERO, Color(0.97, 0.97, 0.95)).rotation.x = PI / 2.0
	_box(clock, "HandHour", Vector3(0.06, 0.32, 0.04), Vector3(0, 0.12, 0.08), Color(0.1, 0.1, 0.1))
	_box(clock, "HandMinute", Vector3(0.04, 0.5, 0.04), Vector3(0.18, 0.0, 0.08), Color(0.1, 0.1, 0.1)).rotation.z = -1.1
	var poster := Node3D.new()
	poster.name = "Poster"
	d.add_child(poster)
	poster.position = Vector3(-4.5, 2.1, -7.9)
	_box(poster, "Frame", Vector3(1.6, 2.0, 0.08), Vector3.ZERO, Color(0.2, 0.2, 0.25))
	_box(poster, "Picture", Vector3(1.35, 1.75, 0.09), Vector3(0, 0, 0.01), Color(0.95, 0.65, 0.25))
	return d


## A desk (and what sits on it) for a work station, or null for kinds with no furniture.
static func prop_for(kind: String) -> Node3D:
	var p := Node3D.new()
	p.name = "Prop"
	var wood := Color(0.62, 0.46, 0.32)
	var dark := Color(0.15, 0.16, 0.2)
	match kind:
		"pc":
			_desk(p, 2.4, wood)
			_box(p, "Screen", Vector3(0.95, 0.6, 0.06), Vector3(0, 1.35, -0.3), Color(0.55, 0.8, 1.0), 0.8)
			_box(p, "Stand", Vector3(0.12, 0.3, 0.12), Vector3(0, 0.98, -0.3), dark)
			_box(p, "Keyboard", Vector3(0.7, 0.04, 0.25), Vector3(0, 0.88, 0.15), dark)
			_cyl(p, "Seat", 0.35, 0.1, Vector3(0, 0.5, -1.2), Color(0.3, 0.35, 0.5))
			_box(p, "ChairBack", Vector3(0.7, 0.7, 0.08), Vector3(0, 0.95, -1.55), Color(0.3, 0.35, 0.5))
		"phone":
			_desk(p, 1.8, wood)
			_box(p, "PhoneBase", Vector3(0.45, 0.12, 0.3), Vector3(0, 0.92, 0.1), Color(0.95, 0.75, 0.2))
			_box(p, "Handset", Vector3(0.6, 0.1, 0.14), Vector3(0, 1.04, 0.1), Color(0.85, 0.6, 0.1))
			_box(p, "Notepad", Vector3(0.4, 0.03, 0.5), Vector3(0.6, 0.87, 0.1), Color(0.97, 0.97, 0.9))
		"devtable":
			_desk(p, 3.4, wood)
			_box(p, "ScreenA", Vector3(0.95, 0.6, 0.06), Vector3(-0.7, 1.35, -0.3), Color(0.4, 0.95, 0.55), 0.8)
			_box(p, "ScreenB", Vector3(0.95, 0.6, 0.06), Vector3(0.7, 1.35, -0.3), Color(0.55, 0.8, 1.0), 0.8)
			_box(p, "Tower", Vector3(0.5, 1.0, 0.6), Vector3(1.9, 0.5, -0.2), dark)
			_box(p, "Led", Vector3(0.08, 0.08, 0.04), Vector3(1.9, 0.9, 0.12), Color(0.3, 1.0, 0.4), 1.5)
		"sales":
			_desk(p, 2.2, wood)
			_box(p, "Board", Vector3(1.8, 1.2, 0.06), Vector3(0, 1.9, -0.55), Color(0.97, 0.97, 0.95))
			_box(p, "BarA", Vector3(0.25, 0.4, 0.07), Vector3(-0.5, 1.7, -0.5), Color(0.9, 0.4, 0.3))
			_box(p, "BarB", Vector3(0.25, 0.7, 0.07), Vector3(0.0, 1.85, -0.5), Color(0.3, 0.75, 0.4))
			_box(p, "BarC", Vector3(0.25, 1.0, 0.07), Vector3(0.5, 2.0, -0.5), Color(0.3, 0.5, 0.9))
			_box(p, "Papers", Vector3(0.5, 0.06, 0.4), Vector3(-0.6, 0.9, 0.1), Color(0.97, 0.97, 0.9))
		"studio":
			_box(p, "Backdrop", Vector3(3.2, 2.4, 0.1), Vector3(0, 1.2, -0.6), Color(0.55, 0.35, 0.75))
			_cyl(p, "TripodPost", 0.06, 1.3, Vector3(-1.0, 0.65, 0.3), dark)
			_box(p, "Camera", Vector3(0.5, 0.35, 0.6), Vector3(-1.0, 1.45, 0.3), dark)
			_box(p, "LightStand", Vector3(0.08, 1.8, 0.08), Vector3(1.1, 0.9, 0.2), dark)
			_box(p, "LightPanel", Vector3(0.7, 0.5, 0.06), Vector3(1.1, 1.9, 0.2), Color(1.0, 0.97, 0.8), 1.2)
		_:
			p.free()
			return null
	return p


static func _desk(parent: Node3D, width: float, color: Color) -> void:
	_box(parent, "DeskTop", Vector3(width, 0.12, 1.1), Vector3(0, 0.8, 0), color)
	_box(parent, "LegL", Vector3(0.12, 0.8, 1.0), Vector3(-width / 2.0 + 0.1, 0.4, 0), color.darkened(0.2))
	_box(parent, "LegR", Vector3(0.12, 0.8, 1.0), Vector3(width / 2.0 - 0.1, 0.4, 0), color.darkened(0.2))
