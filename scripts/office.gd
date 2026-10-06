extends Node3D
## Builds the world in code (placeholder boxes) and wires the run together.

const FLOOR_SIZE := Vector3(24.0, 0.2, 16.0)

var players_root: Node3D
var director: RunDirector
var player_list: Array[Player] = []
var b: Balance


func _ready() -> void:
	InputSetup.register()
	b = load("res://data/balance.tres") as Balance
	_build_floor()
	_build_camera()
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	var p := Player.new()
	p.name = "Player1"
	players_root.add_child(p)
	p.position = Vector3(0, 0, 3)
	player_list.append(p)
	director = RunDirector.new()
	director.b = b
	add_child(director)
	_build_stations()
	director.start(player_list, int(Time.get_ticks_usec()), RunDirector.carried_level)
	_apply_ladder()
	var hud := Hud.new()
	add_child(hud)
	hud.setup(director)


func _build_stations() -> void:
	for x in [-8.0, -5.0, -2.0]:
		_add_station("pc", b.hold_pc, Vector3(x, 0, -5), Color(0.3, 0.5, 0.9))
	_add_station("phone", b.hold_phone, Vector3(4, 0, -5), Color(0.9, 0.7, 0.2))
	_add_station("devtable", b.hold_devtable, Vector3(9, 0, -2), Color(0.8, 0.25, 0.25))
	_add_station("sales", b.hold_sales, Vector3(-9, 0, 2), Color(0.3, 0.8, 0.4))
	_add_station("studio", b.hold_studio, Vector3(9, 0, 4), Color(0.7, 0.4, 0.8))


## Locked features are hidden (the director also keeps them disabled).
func _apply_ladder() -> void:
	var needs := {"devtable": "stability", "sales": "leads", "studio": "pr"}
	for s in director.stations:
		if needs.has(s.kind):
			s.visible = Rules.unlocked(needs[s.kind], director.level, b)


func _add_station(kind: String, hold: float, pos: Vector3, color: Color) -> Station:
	var s := Station.new()
	s.name = kind.capitalize()
	add_child(s)
	s.setup(kind, hold, Vector3(2, 1, 2), color)
	s.position = pos
	s.players = player_list
	s.completed.connect(func(pl: Player): director.on_station_completed(kind, pl))
	director.register_station(s)
	return s


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
