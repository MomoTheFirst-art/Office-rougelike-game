extends Node3D
## Builds the world in code (placeholder boxes) and wires the run together.

const FLOOR_SIZE := Vector3(24.0, 0.2, 16.0)

var players_root: Node3D


func _ready() -> void:
	InputSetup.register()
	_build_floor()
	_build_camera()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	var p := Player.new()
	p.name = "Player1"
	players_root.add_child(p)
	p.position = Vector3(0, 0, 3)


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = FLOOR_SIZE
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = FLOOR_SIZE
	mesh.mesh = box_mesh
	body.add_child(mesh)
	body.position.y = -FLOOR_SIZE.y / 2.0
	add_child(body)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	add_child(light)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	add_child(cam)
	cam.position = Vector3(0, 16, 12)
	cam.look_at(Vector3.ZERO)
