extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _item(type: String, deadline := 30.0, stage := 0, size := 0) -> WorkItem:
	var it := WorkItem.new()
	it.type = type
	it.deadline = deadline
	it.stage = stage
	it.size = size
	return it


func _director(level: int) -> RunDirector:
	var d := RunDirector.new()
	d.start([] as Array[Player], 1, level)
	return d


func _types_seen(level: int) -> Dictionary:
	var d := _director(level)
	var types := {}
	var cb := func(item): types[item.type] = true
	EventBus.item_spawned.connect(cb)
	var guard := 0
	while d.running and guard < 40000:
		d.tick(DT)
		guard += 1
	EventBus.item_spawned.disconnect(cb)
	d.free()
	return types


func test_lead_two_stages_and_value() -> void:
	var b := Balance.new()
	var lead := _item("lead", 90.0, 0, 1)
	T.truth(lead.accepts("sales") and not lead.accepts("phone"), "stage 0 is the sales PC")
	var fx := lead.apply("sales", b)
	T.eq(fx["done"], false, "proposal is not the end")
	T.eq(fx["stage"], 1, "moves to stage 1")
	lead.stage = 1
	T.truth(lead.accepts("phone") and not lead.accepts("sales"), "stage 1 is the phone")
	fx = lead.apply("phone", b)
	T.eq(fx["done"], true, "closed")
	T.eq(fx["quest"], {"revenue": 1200.0}, "medium deal pays 1200")
	T.eq(lead.stream(), "business", "stream")


func test_pr_points_by_station() -> void:
	var b := Balance.new()
	var pr := _item("pr")
	T.eq(pr.apply("pc", b)["quest"], {"pr": 1.0}, "post online")
	T.eq(pr.apply("phone", b)["quest"], {"pr": 2.0}, "press response")
	T.eq(pr.apply("studio", b)["quest"], {"pr": 4.0}, "broadcast interview")
	T.truth(pr.accepts("studio") and not pr.accepts("sales"), "accepts")
	T.eq(pr.stream(), "pr", "stream")


func test_expiry_cost_only_for_tickets() -> void:
	var b := Balance.new()
	T.eq(_item("ticket").expire_cost(b), b.sat_expire, "ticket")
	T.eq(_item("bugticket").expire_cost(b), b.sat_expire, "bug ticket")
	T.eq(_item("pr").expire_cost(b), 0.0, "pr is just missed")
	T.eq(_item("lead").expire_cost(b), 0.0, "lead is just lost")


func test_phone_serves_ticket_lead_and_pr_by_deadline() -> void:
	var d := _director(4)
	var ticket := _item("ticket", 30.0)
	var lead := _item("lead", 10.0, 1)
	var pr := _item("pr", 20.0)
	d.items = [ticket, lead, pr]
	T.truth(d.item_for("phone") == lead, "lead first")
	d.items.erase(lead)
	T.truth(d.item_for("phone") == pr, "then pr")
	d.items.erase(pr)
	T.truth(d.item_for("phone") == ticket, "then ticket")
	d.free()


func test_lead_hold_mult_set_on_station() -> void:
	var d := _director(4)
	var s := Station.new()
	s.kind = "sales"
	d.register_station(s)
	d._ticket_timer = 1.0e9
	d.items = [_item("lead", 90.0, 0, 2)]
	d.tick(DT)
	T.eq(s.hold_mult, 1.5, "large deal holds 1.5x")
	s.free()
	d.free()


func test_pr_and_leads_gated_by_level() -> void:
	var l2 := _types_seen(2)
	T.truth(not l2.has("pr") and not l2.has("lead"), "level 2 has neither")
	var l3 := _types_seen(3)
	T.truth(l3.has("pr") and not l3.has("lead"), "level 3 has pr only")
	var l4 := _types_seen(4)
	T.truth(l4.has("pr") and l4.has("lead"), "level 4 has both")


func test_missed_pr_costs_no_satisfaction() -> void:
	var d := _director(3)
	d._ticket_timer = 1.0e9
	d._bug_timer = 1.0e9
	d.items = [_item("pr", 0.01)]
	d.tick(DT)
	T.eq(d.items.size(), 0, "expired")
	T.eq(d.satisfaction, d.b.start_satisfaction, "no cost")
	d.free()


func test_deadlines_scale_with_level() -> void:
	var d := _director(3)
	var guard := 0
	while d.items.is_empty() and guard < 600:
		d.tick(DT)
		guard += 1
	T.near(d.items[0].deadline, d.b.deadline_ticket * pow(0.92, 2), 0.3, "ticket deadline at level 3")
	d.free()


func test_result_ratios_only_active_quests() -> void:
	var d := _director(1)
	d.end_run("time")
	T.eq(d.result()["ratios"].size(), 1, "level 1: tickets only")
	var d2 := _director(2)
	d2.end_run("time")
	T.eq(d2.result()["ratios"].size(), 2, "level 2: tickets and stability")
	d.free()
	d2.free()


func test_result_bonus_and_promotion() -> void:
	var d := _director(1)
	d.quests["tickets"] = 40.0
	d.satisfaction = 70.0
	d.end_run("time")
	T.eq(d.result()["bonus"], 170, "100 for tickets + 70 satisfaction")
	T.eq(d.result()["promoted"], false, "70 is below 90")
	var p := _director(1)
	p.quests["tickets"] = 40.0
	p.satisfaction = 95.0
	RunDirector.carried_level = 1
	p.end_run("time")
	T.eq(p.result()["promoted"], true, "95 is promoted")
	T.eq(RunDirector.carried_level, 2, "next run is level 2")
	RunDirector.carried_level = 1
	d.free()
	p.free()


func test_fired_never_promotes() -> void:
	var d := _director(1)
	d.satisfaction = 95.0
	d.end_run("fired")
	T.eq(d.result()["promoted"], false, "fired")
	d.free()
