extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


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
