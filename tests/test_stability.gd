extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _director(level: int) -> RunDirector:
	var d := RunDirector.new()
	d.start([] as Array[Player], 1, level)
	return d


func _run(d: RunDirector, seconds: float) -> void:
	for i in int(seconds / DT):
		d.tick(DT)


func _bug(ticket: WorkItem = null) -> WorkItem:
	var it := WorkItem.new()
	it.type = "bug"
	it.deadline = INF
	it.ticket = ticket
	return it


func _bugticket(stage := 0) -> WorkItem:
	var it := WorkItem.new()
	it.type = "bugticket"
	it.stage = stage
	it.deadline = 60.0
	return it


func _devtable(d: RunDirector, p: Player) -> Station:
	var st := Station.new()
	tree.root.add_child(st)
	st.setup("devtable", d.b.hold_devtable, Vector3(2, 1, 2), Color.WHITE)
	st.players = [p] as Array[Player]
	st.completed.connect(func(pl): d.on_station_completed("devtable", pl))
	d.register_station(st)
	return st


func _tick_all(d: RunDirector, seconds: float) -> void:
	for i in int(seconds / DT):
		d.tick(DT)
		for s in d.stations:
			s.tick(DT)


func test_drains_over_time() -> void:
	var b := Balance.new()
	T.near(Rules.stability_step(100.0, 10.0, 0, false, b), 90.0, 0.001, "drain 1/s")


func test_refill_only_without_bugs() -> void:
	var b := Balance.new()
	T.near(Rules.stability_step(50.0, 1.0, 0, true, b), 55.0, 0.001, "standing, no bugs: +6 -1")
	T.near(Rules.stability_step(50.0, 1.0, 1, true, b), 49.0, 0.001, "standing with a bug: drain only")
	T.near(Rules.stability_step(50.0, 1.0, 0, false, b), 49.0, 0.001, "not standing: drain only")


func test_clamps() -> void:
	var b := Balance.new()
	T.eq(Rules.stability_step(99.0, 5.0, 0, true, b), 100.0, "upper clamp")
	T.eq(Rules.stability_step(0.5, 5.0, 0, false, b), 0.0, "lower clamp")


func test_bugticket_full_path() -> void:
	var d := _director(2)
	var t := _bugticket()
	d.items = [t]
	d.on_station_completed("pc", null)
	T.eq(t.stage, 1, "waiting on the dev")
	T.eq(d.bugs_open(), 1, "a bug was filed")
	T.eq(d.satisfaction, d.b.start_satisfaction, "no score for filing")
	T.truth(d.item_for("pc") == null, "pc cannot reply yet")
	d.on_station_completed("devtable", null)
	T.eq(d.bugs_open(), 0, "bug fixed")
	T.eq(t.stage, 2, "ticket ready to reply")
	d.on_station_completed("pc", null)
	T.eq(d.satisfaction, d.b.start_satisfaction + d.b.sat_bug, "sat_bug once")
	T.eq(d.quests["tickets"], 1.0, "ticket counted")
	T.eq(d.items.size(), 0, "all done")
	d.free()


func test_bug_ticket_done_decays_share() -> void:
	var d := _director(2)
	var before := d.bugticket_share
	d.items = [_bugticket(2)]
	d.on_station_completed("pc", null)
	T.near(d.bugticket_share, before * d.b.bugticket_share_decay, 0.0001, "share decays")
	d.free()


func test_level1_has_no_stability_or_bugs() -> void:
	var d := _director(1)
	var st := _devtable(d, null)
	_run(d, 100.0)
	T.eq(d.stability, 100.0, "bar stays full")
	T.eq(d.bugs_open(), 0, "no bugs")
	T.eq(st.enabled, false, "dev table disabled")
	st.free()
	d.free()


func test_spontaneous_bugs_from_level_2() -> void:
	var d := _director(2)
	_run(d, 50.0)
	T.truth(d.bugs_open() >= 1, "a bug appeared on its own")
	d.free()


func test_outage_costs_satisfaction_and_floors_at_zero() -> void:
	var d := _director(2)
	d.stability = 0.0
	d.satisfaction = 3.0
	d._ticket_timer = 1.0e9
	_run(d, 1.0)
	T.near(d.satisfaction, 2.0, 0.1, "about -1 per second")
	_run(d, 5.0)
	T.truth(d.satisfaction >= 0.0, "never negative")
	T.eq(d.outcome, "fired", "outage got someone fired")
	d.free()


func test_outage_spawns_extra_tickets() -> void:
	var d := _director(2)
	d.stability = 0.0
	d.satisfaction = 100.0
	d._ticket_timer = 1.0e9
	d._bug_timer = 1.0e9
	_run(d, 21.0)
	T.truth(d.items.size() >= 1, "an extra ticket during the outage")
	d.free()


func test_fix_before_refill() -> void:
	var d := _director(2)
	d._ticket_timer = 1.0e9
	d._bug_timer = 1.0e9
	var p := Player.new()
	tree.root.add_child(p)
	var st := _devtable(d, p)
	p.global_position = st.global_position
	d.stability = 50.0
	d.items = [_bug(), _bug()]
	_tick_all(d, 8.3)
	T.eq(d.bugs_open(), 1, "first bug fixed")
	T.truth(d.stability < 50.0, "bar did not rise while a bug was open, got %s" % d.stability)
	_tick_all(d, 8.3)
	T.eq(d.bugs_open(), 0, "second bug fixed")
	var after_fix := d.stability
	_tick_all(d, 3.0)
	T.truth(d.stability > after_fix + 5.0, "bar rises once no bugs are open")
	st.free()
	p.free()
	d.free()


func test_fix_before_refill_with_bar_at_zero() -> void:
	var d := _director(2)
	d._ticket_timer = 1.0e9
	d._bug_timer = 1.0e9
	var p := Player.new()
	tree.root.add_child(p)
	var st := _devtable(d, p)
	p.global_position = st.global_position
	d.stability = 0.0
	d.satisfaction = 100.0
	d.items = [_bug()]
	_tick_all(d, 4.0)
	T.eq(d.stability, 0.0, "still 0 while the bug is open")
	T.eq(d.bugs_open(), 1, "bug still being fixed")
	_tick_all(d, 4.5)
	T.eq(d.bugs_open(), 0, "bug fixed during the outage")
	T.truth(d.satisfaction >= 0.0 and d.satisfaction < 100.0, "outage cost some satisfaction")
	st.free()
	p.free()
	d.free()
