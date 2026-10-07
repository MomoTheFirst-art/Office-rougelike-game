extends RefCounted
## End-to-end: whole seeded runs driven tick by tick (no display, no physics frames).

var tree: SceneTree
const DT := 1.0 / 60.0
const STATION_TOUR := ["pc", "phone", "devtable", "sales", "studio", "pc"]


## Build the Office at a level with a seed. Expiry and outage costs are off so the run always reaches the end.
func _office(level: int, seed_value: int) -> Node3D:
	RunDirector.carried_level = level
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	var d: RunDirector = office.director
	d.b = d.b.duplicate()  # do not touch the cached shared resource
	d.b.sat_expire = 0.0
	d.b.outage_sat_per_s = 0.0
	d.start(office.player_list, seed_value, level)
	return office


func _tick_world(office: Node3D) -> void:
	var d: RunDirector = office.director
	d.tick(DT)
	for s in d.stations:
		s.tick(DT)
	if d.meeting == null:
		for npc in office.npcs:
			npc.tick(DT)
			if npc is Climber:
				npc.callout.tick(DT)


## One player who tours every station kind every few seconds and stands on pad 0 in meetings.
func _play(office: Node3D, seed_value: int) -> Dictionary:
	var d: RunDirector = office.director
	var p: Player = office.player_list[0]
	var titles: Array[String] = []
	var ended := []
	var cb := func(def): titles.append(def.title)
	var cb2 := func(_r): ended.append(1)
	EventBus.meeting_started.connect(cb)
	EventBus.run_ended.connect(cb2)
	var n := 0
	while d.running and n < 40000:
		if d.meeting != null:
			p.global_position = d.meeting.pads[0].global_position
		elif n % 360 == 0:
			var kind: String = STATION_TOUR[(n / 360) % STATION_TOUR.size()]
			for s in d.stations:
				if s.kind == kind and s.visible:
					p.global_position = s.global_position
		_tick_world(office)
		n += 1
	EventBus.meeting_started.disconnect(cb)
	EventBus.run_ended.disconnect(cb2)
	return {"result": d.result(), "titles": titles, "ended": ended.size(), "ticks": n}


func test_full_seeded_run_completes_and_repeats_exactly() -> void:
	var office := _office(6, 12345)
	var first := _play(office, 12345)
	office.free()
	T.eq(first["ended"], 1, "run_ended exactly once")
	T.eq(first["result"]["outcome"], "time", "reached the end of the workday")
	T.eq(first["titles"], ["Client meeting", "Manager meeting", "CEO meeting"] as Array[String], "meetings in order")
	T.truth(first["result"]["bonus"] >= 0, "bonus is not negative")
	var sat: float = first["result"]["satisfaction"]
	T.truth(sat >= 0.0 and sat <= 100.0, "satisfaction in range")
	T.truth(first["result"]["quests"]["tickets"] > 0.0, "the scripted player solved some tickets")
	var again_office := _office(6, 12345)
	var again := _play(again_office, 12345)
	again_office.free()
	T.eq(again["result"], first["result"], "same seed, same result")
	RunDirector.carried_level = 1


func _allowed_types(level: int) -> Dictionary:
	var t := {"ticket": true}
	if level >= 2:
		t["bugticket"] = true
		t["bug"] = true
	if level >= 3:
		t["pr"] = true
	if level >= 4:
		t["lead"] = true
	return t


func test_each_level_runs_and_hides_locked_features() -> void:
	var locked_kind_level := {"devtable": 2, "studio": 3, "sales": 4}
	for level in range(1, 7):
		var office := _office(level, 99)
		var d: RunDirector = office.director
		var seen := {}
		var meetings := []
		var cb := func(item): seen[item.type] = true
		var cb2 := func(_def): meetings.append(1)
		EventBus.item_spawned.connect(cb)
		EventBus.meeting_started.connect(cb2)
		var locked_enabled := false
		var n := 0
		while d.running and n < 40000:
			d.tick(DT)
			for s in d.stations:
				if locked_kind_level.has(s.kind) and level < locked_kind_level[s.kind] and s.enabled:
					locked_enabled = true
			n += 1
		EventBus.item_spawned.disconnect(cb)
		EventBus.meeting_started.disconnect(cb2)
		var allowed := _allowed_types(level)
		for type: String in seen:
			T.truth(allowed.has(type), "level %d must not spawn %s" % [level, type])
		T.eq(locked_enabled, false, "level %d: no locked station was ever enabled" % level)
		T.eq(meetings.size(), 3 if level >= 5 else 0, "level %d meeting count" % level)
		T.eq(office.has_node("Chatter"), level >= 6, "level %d Chatter node" % level)
		T.eq(office.has_node("Climber"), level >= 6, "level %d Climber node" % level)
		T.eq(office.has_node("Shelf"), level >= 6, "level %d shelf node" % level)
		if level < 6:
			T.eq(d.rival_bar, 0.0, "level %d: no rival bar" % level)
		T.eq(d.outcome, "time", "level %d reached the end" % level)
		office.free()
	RunDirector.carried_level = 1
