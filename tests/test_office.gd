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
