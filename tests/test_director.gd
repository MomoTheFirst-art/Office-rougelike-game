extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _director() -> RunDirector:
	var d := RunDirector.new()
	d.start([] as Array[Player], 1)
	return d


func _run(d: RunDirector, seconds: float) -> void:
	for i in int(seconds / DT):
		d.tick(DT)


func _ticket(deadline: float) -> WorkItem:
	var it := WorkItem.new()
	it.type = "ticket"
	it.deadline = deadline
	return it


func test_unlocked_by_level() -> void:
	var b := Balance.new()
	T.truth(Rules.unlocked("tickets", 1, b), "tickets at 1")
	T.truth(not Rules.unlocked("pr", 2, b), "pr locked at 2")
	T.truth(Rules.unlocked("pr", 3, b), "pr at 3")
	T.truth(Rules.unlocked("npcs", 6, b), "npcs at 6")


func test_active_quests_grow_with_level() -> void:
	var d := RunDirector.new()
	d.b = Balance.new()
	var want := {
		1: ["tickets"], 2: ["tickets", "stability"], 3: ["tickets", "stability", "pr"],
		4: ["tickets", "stability", "pr", "revenue"], 6: ["tickets", "stability", "pr", "revenue"],
	}
	for lvl: int in want:
		d.level = lvl
		T.eq(Array(d.active_quests()), want[lvl], "active quests at level %d" % lvl)
	d.free()


func test_spawns_tickets_on_interval() -> void:
	var d := _director()
	_run(d, 1.0)
	T.eq(d.items.size(), 0, "none before the first spawn")
	_run(d, 1.1)
	T.eq(d.items.size(), 1, "first ticket after about 2 s")
	_run(d, 8.0)
	T.eq(d.items.size(), 2, "second ticket one interval later")
	d.free()


func test_item_for_picks_nearest_deadline() -> void:
	var d := _director()
	var late := _ticket(30.0)
	var soon := _ticket(10.0)
	d.items = [late, soon]
	T.truth(d.item_for("pc") == soon, "nearest deadline wins")
	T.truth(d.item_for("sales") == null, "no item accepts sales")
	d.free()


func test_expiry_costs_satisfaction() -> void:
	var d := _director()
	d.items = [_ticket(0.01)]
	d.tick(DT)
	T.eq(d.items.size(), 0, "expired item removed")
	T.eq(d.satisfaction, d.b.start_satisfaction + d.b.sat_expire, "satisfaction cost")
	d.free()


func test_fired_at_zero_ends_once() -> void:
	var d := _director()
	var ended := []
	var cb := func(_r): ended.append(1)
	EventBus.run_ended.connect(cb)
	d.satisfaction = 1.0
	d.items = [_ticket(0.01)]
	d.tick(DT)
	T.eq(ended.size(), 1, "run_ended once")
	T.eq(d.running, false, "not running")
	T.eq(d.outcome, "fired", "outcome")
	T.eq(d.satisfaction, 0.0, "floored at 0")
	var left := d.time_left
	d.items = [_ticket(0.01)]
	_run(d, 2.0)
	T.eq(ended.size(), 1, "still once")
	T.eq(d.time_left, left, "time frozen after the end")
	T.eq(d.items.size(), 1, "no spawns or expiries after the end")
	EventBus.run_ended.disconnect(cb)
	d.free()


func test_time_up_ends() -> void:
	var d := _director()
	d.time_left = 0.01
	d.tick(DT)
	T.eq(d.running, false, "not running")
	T.eq(d.outcome, "time", "outcome")
	d.free()


func test_satisfaction_never_negative() -> void:
	var d := _director()
	d.satisfaction = 1.0
	d.items = [_ticket(0.01)]
	d.tick(DT)
	T.truth(d.satisfaction >= 0.0, "not negative")
	d.free()


func test_station_completion_applies_reply_and_call() -> void:
	var d := _director()
	d.items = [_ticket(30.0)]
	d.on_station_completed("pc", null)
	T.eq(d.satisfaction, d.b.start_satisfaction + d.b.sat_reply, "reply")
	T.eq(d.quests["tickets"], 1.0, "quest")
	T.eq(d.items.size(), 0, "item done")
	d.items = [_ticket(30.0)]
	d.on_station_completed("phone", null)
	T.eq(d.quests["tickets"], 2.0, "quest again")
	T.eq(d.satisfaction, d.b.start_satisfaction + d.b.sat_reply + d.b.sat_call, "call")
	d.free()


func test_station_enabled_only_with_matching_item() -> void:
	var d := _director()
	var pc := Station.new()
	pc.kind = "pc"
	var sales := Station.new()
	sales.kind = "sales"
	d.register_station(pc)
	d.register_station(sales)
	d.items = [_ticket(30.0)]
	d.tick(DT)
	T.eq(pc.enabled, true, "pc enabled")
	T.eq(pc.stream, "tickets", "stream set")
	T.eq(sales.enabled, false, "sales disabled")
	pc.free()
	sales.free()
	d.free()


func test_level1_has_only_simple_tickets_and_active_quests() -> void:
	var d := _director()
	var types := {}
	var cb := func(item): types[item.type] = true
	EventBus.item_spawned.connect(cb)
	var guard := 0
	while d.running and guard < 40000:
		d.tick(DT)
		guard += 1
	EventBus.item_spawned.disconnect(cb)
	T.eq(types.keys(), ["ticket"], "only simple tickets at level 1")
	T.eq(d.active_quests(), ["tickets"] as Array[String], "active quests at level 1")
	d.free()
