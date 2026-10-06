extends Node3D
## Builds the world in code (placeholder boxes) and wires the run together.

const FLOOR_SIZE := Vector3(24.0, 0.2, 16.0)
const OUTBOX_POS := Vector3(0, 0, -7)

var players_root: Node3D
var director: RunDirector
var player_list: Array[Player] = []
var b: Balance
var npcs: Array[Node3D] = []  # hidden and frozen during meetings
var camera: FollowCamera


func _ready() -> void:
	InputSetup.register()
	b = load("res://data/balance.tres") as Balance
	_build_floor()
	add_child(OfficeArt.room(FLOOR_SIZE))
	add_child(OfficeArt.decor())
	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	var p := Player.new()
	p.name = "Player1"
	p.index = 0
	p.bounds = Rect2(-11.4, -7.2, 22.8, 14.4)  # just inside the walls
	players_root.add_child(p)
	p.position = Vector3(0, 0, 3)
	player_list.append(p)
	_build_camera(p)
	director = RunDirector.new()
	director.b = b
	add_child(director)
	_build_stations()
	director.start(player_list, int(Time.get_ticks_usec()), RunDirector.carried_level)
	_show_stations()
	_build_npcs()
	EventBus.meeting_started.connect(_on_meeting_started)
	EventBus.meeting_ended.connect(_on_meeting_ended)
	EventBus.run_ended.connect(_on_run_ended)
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


func _build_npcs() -> void:
	if not Rules.unlocked("npcs", director.level, b):
		return
	var chatter := Chatter.new()
	chatter.name = "Chatter"
	chatter.b = b
	chatter.level = director.level
	chatter.players = player_list
	chatter.stations = director.stations
	add_child(chatter)
	chatter.position = Vector3(-10, 0, 6)
	chatter.home = chatter.position
	chatter.cooldown_left = chatter.cooldown_seconds() * 0.5
	npcs.append(chatter)
	_build_outbox()
	var climber := Climber.new()
	climber.name = "Climber"
	climber.b = b
	climber.level = director.level
	climber.director = director
	add_child(climber)
	climber.position = Vector3(10, 0, 7)
	climber.home = climber.position
	climber.board = OUTBOX_POS
	climber.cooldown_left = climber.interval() * 0.5
	var callout := Station.new()
	callout.name = "Callout"
	climber.add_child(callout)
	callout.setup("callout", b.hold_callout, Vector3(2.5, 0.1, 2.5), Color(1, 1, 0))
	callout.players = player_list
	callout.completed.connect(func(_pl: Player): climber.call_out())
	climber.callout = callout
	npcs.append(climber)
	var shelf := ShotgunShelf.new()
	shelf.name = "Shelf"
	shelf.b = b
	shelf.players = player_list
	add_child(shelf)
	shelf.position = Vector3(-11, 0, -6.5)
	npcs.append(shelf)
	for p in player_list:
		p.b = b
		p.npc_targets = [chatter, climber] as Array[Node3D]


## The board where finished work posts its credit; the Climber walks here to steal it.
func _build_outbox() -> void:
	var board := MeshInstance3D.new()
	board.name = "Outbox"
	var box := BoxMesh.new()
	box.size = Vector3(4, 2, 0.3)
	board.mesh = box
	add_child(board)
	board.position = OUTBOX_POS + Vector3(0, 1, -0.8)


func _set_npcs_active(on: bool) -> void:
	for n in npcs:
		n.visible = on
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Locked features stay hidden (the director also keeps them disabled).
func _show_stations() -> void:
	var needs := {"devtable": "stability", "sales": "leads", "studio": "pr"}
	for s in director.stations:
		s.visible = not needs.has(s.kind) or Rules.unlocked(needs[s.kind], director.level, b)


## The floor clears for a meeting: only the pads remain.
func _on_meeting_started(_def) -> void:
	camera.override_focus = Vector3.ZERO  # the pads are in the middle
	for s in director.stations:
		s.visible = false
	for n in npcs:
		if n.has_method("interrupt"):
			n.interrupt()
	_set_npcs_active(false)


## The run is over: freeze the NPCs where they stand (they stay visible behind the end screen).
func _on_run_ended(_result: Dictionary) -> void:
	for n in npcs:
		n.process_mode = Node.PROCESS_MODE_DISABLED


func _on_meeting_ended(_def, _pad: int) -> void:
	camera.override_focus = null
	_show_stations()
	_set_npcs_active(true)


func _add_station(kind: String, hold: float, pos: Vector3, color: Color) -> Station:
	var s := Station.new()
	s.name = kind.capitalize()
	add_child(s)
	s.setup(kind, hold, Vector3(2, 0.1, 2), color)  # flat pad: stand here
	s.position = pos
	var prop := OfficeArt.prop_for(kind)
	if prop != null:
		s.add_child(prop)
		prop.position = Vector3(0, 0, -1.5)
	s.label.position.y = 2.6
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
	box_mesh.material = StandardMaterial3D.new()
	box_mesh.material.albedo_color = Color(0.55, 0.5, 0.45)  # carpet
	box_mesh.material.roughness = 1.0
	mesh.mesh = box_mesh
	body.add_child(mesh)
	body.position.y = -FLOOR_SIZE.y / 2.0
	add_child(body)
	var env := WorldEnvironment.new()
	env.name = "Environment"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.15, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.8
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_camera(target: Player) -> void:
	camera = FollowCamera.new()
	camera.name = "Camera"
	camera.target = target
	add_child(camera)
	camera.snap()
