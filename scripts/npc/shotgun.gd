class_name ShotgunShelf
extends Node3D
## The one toy shotgun. Walk into it with no shells to pick it up; it is back on the shelf
## shotgun_respawn seconds after the shells are used up.

var b: Balance
var players: Array[Player] = []
var available := true
var _holder: Player = null
var _respawn_left := -1.0  # below 0: not counting down yet
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 0.2, 0.3)
	box.material = StandardMaterial3D.new()
	box.material.albedo_color = Color(0.45, 0.3, 0.15)
	_mesh.mesh = box
	_mesh.position.y = 1.0
	add_child(_mesh)


func tick(delta: float) -> void:
	if available:
		for p in players:
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if p.ammo == 0 and d <= b.shotgun_pickup_radius:
				p.ammo = b.shotgun_ammo + int(p.stats.get("shotgun_ammo", 0.0))
				available = false
				_holder = p
				_respawn_left = -1.0
				break
	elif _respawn_left < 0.0:
		if not is_instance_valid(_holder) or _holder.ammo == 0:
			_respawn_left = b.shotgun_respawn
	else:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			available = true
			_holder = null
			_respawn_left = -1.0
	if _mesh != null:
		_mesh.visible = available


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)
