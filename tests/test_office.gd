extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func test_locked_stations_are_hidden_by_level() -> void:
	# level -> [devtable, sales, studio] visible
	var want := {1: [false, false, false], 2: [true, false, false], 3: [true, false, true], 4: [true, true, true]}
	for lvl: int in want:
		RunDirector.carried_level = lvl
		var office: Node3D = load("res://main.tscn").instantiate()
		tree.root.add_child(office)
		var got := [
			office.get_node("Devtable").visible, office.get_node("Sales").visible, office.get_node("Studio").visible]
		T.eq(got, want[lvl], "devtable/sales/studio visible at level %d" % lvl)
		office.free()
	RunDirector.carried_level = 1


func test_floor_clears_during_a_meeting_and_returns() -> void:
	RunDirector.carried_level = 5
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	var d: RunDirector = office.director
	var pc: Station = office.get_node("Pc")
	var dev: Station = office.get_node("Devtable")
	T.eq([pc.visible, dev.visible], [true, true], "visible before")
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	for i in int(1.0 / DT):
		d.tick(DT)
	T.truth(d.meeting != null, "meeting open")
	T.eq([pc.visible, dev.visible], [false, false], "floor cleared")
	for i in int(16.0 / DT):
		d.tick(DT)
	T.truth(d.meeting == null, "meeting over")
	T.eq([pc.visible, dev.visible], [true, true], "floor back")
	office.free()
	RunDirector.carried_level = 1


func test_chatter_exists_only_from_level_6_and_leaves_during_meetings() -> void:
	RunDirector.carried_level = 5
	var l5: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(l5)
	T.truth(not l5.has_node("Chatter") and not l5.has_node("Shelf"), "no Chatter or shelf at level 5")
	T.eq(l5.player_list[0].npc_targets.size(), 0, "nothing to shoot at level 5")
	l5.free()
	RunDirector.carried_level = 6
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	T.truth(office.has_node("Chatter"), "Chatter at level 6")
	T.truth(office.has_node("Climber") and office.has_node("Outbox") and office.has_node("Shelf"), "Climber, outbox and shelf at level 6")
	T.eq(office.player_list[0].npc_targets.size(), 2, "the shotgun can hit both NPCs")
	T.truth(office.player_list[0].b != null, "player knows the balance for firing")
	var chatter: Chatter = office.get_node("Chatter")
	var climber: Climber = office.get_node("Climber")
	var d: RunDirector = office.director
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	for i in int(1.0 / DT):
		d.tick(DT)
	T.truth(d.meeting != null, "meeting open")
	T.eq([chatter.visible, chatter.can_process()], [false, false], "Chatter gone during the meeting")
	T.eq([climber.visible, climber.can_process(), climber.callout.can_process()], [false, false, false], "Climber and his call-out spot gone")
	for i in int(16.0 / DT):
		d.tick(DT)
	T.eq([chatter.visible, chatter.can_process()], [true, true], "Chatter back")
	T.eq([climber.visible, climber.can_process(), climber.callout.can_process()], [true, true, true], "Climber back")
	office.free()
	RunDirector.carried_level = 1


func test_standing_at_a_pc_solves_a_ticket_through_the_office_wiring() -> void:
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	var d: RunDirector = office.director
	d.start(office.player_list, 1)
	var pc: Station = office.get_node("Pc")
	office.player_list[0].global_position = pc.global_position
	for i in int(20.0 / DT):
		d.tick(DT)
		for s in d.stations:
			s.tick(DT)
	T.truth(d.quests["tickets"] >= 1.0, "a ticket was solved, got %s" % d.quests["tickets"])
	T.truth(d.satisfaction > 0.0, "still employed")
	office.free()
