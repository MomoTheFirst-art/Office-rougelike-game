class_name Station
extends Node3D
## Stand-to-fill spot. A player stands inside, the bar fills, leaving resets it.
## Presence is an XZ box test against the registered players (no physics timing).

signal completed(player: Player)

var kind := ""
var base_hold := 4.0
var stream := ""  # which stat family speeds this up, e.g. "tickets" -> hold_tickets
var hold_mult := 1.0
var enabled := false  # the director enables a station only when it has work for it
var holder: Player = null  # tracked even while disabled
var progress := 0.0  # 0..1, advances only while enabled
var players: Array[Player] = []
var half := Vector2(1.0, 1.0)
var label: Label3D


func setup(station_kind: String, hold: float, size: Vector3, color: Color) -> void:
	kind = station_kind
	base_hold = hold
	half = Vector2(size.x, size.z) / 2.0
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = StandardMaterial3D.new()
	box.material.albedo_color = color
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	add_child(mesh)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.012
	label.position.y = size.y + 0.8
	add_child(label)


func contains(p: Player) -> bool:
	var d := p.global_position - global_position
	return absf(d.x) <= half.x and absf(d.z) <= half.y


func tick(delta: float) -> void:
	if holder != null and not contains(holder):
		holder = null
		progress = 0.0
	if holder == null:
		for p in players:
			if contains(p):
				holder = p
				break
	if holder == null or not enabled:
		progress = 0.0
		_update_label()
		return
	var seconds := Rules.hold_seconds(base_hold * hold_mult, holder.stats, "hold_" + stream)
	progress += delta / (seconds / holder.work_rate)
	if progress >= 1.0:
		progress = 0.0
		completed.emit(holder)
	_update_label()


func _update_label() -> void:
	if label == null:
		return
	label.text = kind + (" *" if enabled else "")
	if holder != null and progress > 0.0:
		label.text += "  %d%%" % int(progress * 100.0)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)
