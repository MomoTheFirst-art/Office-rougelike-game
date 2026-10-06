extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _director(players: Array[Player] = [] as Array[Player], level := 5) -> RunDirector:
	var d := RunDirector.new()
	tree.root.add_child(d)  # meetings add child nodes, which need a live tree
	d.start(players, 7, level)
	return d


func _player() -> Player:
	var p := Player.new()
	tree.root.add_child(p)
	return p


func _run(d: RunDirector, seconds: float) -> void:
	for i in int(seconds / DT):
		d.tick(DT)


## Start the first meeting right away and return once it is open.
func _open_meeting(d: RunDirector) -> void:
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	_run(d, 1.0)


func _draws(votes: Array[int], n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var seen := {}
	for i in n:
		seen[Rules.pick_meeting_pad(votes, rng)] = true
	return seen


func test_pick_majority_wins() -> void:
	var rng := RandomNumberGenerator.new()
	T.eq(Rules.pick_meeting_pad([2, 1, 0] as Array[int], rng), 0, "pad 0 has most")
	T.eq(Rules.pick_meeting_pad([0, 0, 2] as Array[int], rng), 2, "pad 2 has most")
	T.eq(Rules.pick_meeting_pad([1, 0, 0] as Array[int], rng), 0, "single player")


func test_pick_tie_is_random_among_tied_only() -> void:
	var seen := _draws([1, 1, 0] as Array[int], 300)
	T.eq(seen.keys().size(), 2, "both tied pads appear")
	T.truth(not seen.has(2), "the empty pad never wins a tie")


func test_pick_nobody_locked_is_random_among_all() -> void:
	var seen := _draws([0, 0, 0] as Array[int], 300)
	T.eq(seen.keys().size(), 3, "all pads appear")


func test_meeting_order_and_times() -> void:
	var d := _director()
	var titles: Array[String] = []
	for def in d.meeting_defs:
		titles.append(def.title)
	T.eq(titles, ["Client meeting", "Manager meeting", "CEO meeting"] as Array[String], "order")
	for i in 3:
		var base := d.b.meeting_times[i] * d.b.run_seconds
		T.truth(d.meeting_at[i] >= base and d.meeting_at[i] <= base + 10.0, "time %d" % i)
	T.truth(d.meeting_at[0] < d.meeting_at[1] and d.meeting_at[1] < d.meeting_at[2], "ascending")
	d.free()


func test_no_meetings_below_level_5() -> void:
	var d := _director([] as Array[Player], 4)
	T.eq(d.meeting_at.size(), 0, "none scheduled")
	var started := []
	var cb := func(_def): started.append(1)
	EventBus.meeting_started.connect(cb)
	var guard := 0
	while d.running and guard < 40000:
		d.tick(DT)
		guard += 1
	EventBus.meeting_started.disconnect(cb)
	T.eq(started.size(), 0, "no meeting_started")
	d.free()


func test_effects_apply() -> void:
	var d := _director()
	var base_target := d.quest_target("revenue")
	d.apply_effects({"satisfaction": 8.0, "target_mult": {"revenue": 1.2}, "payout_mult": 1.25})
	T.eq(d.satisfaction, d.b.start_satisfaction + 8.0, "satisfaction delta")
	T.near(d.quest_target("revenue"), base_target * 1.2, 0.001, "target multiplier")
	d.quests["tickets"] = 0.0
	var plain := Rules.bonus(d.ratios(), d.level, d.satisfaction, false, d.b)
	d.end_run("time")
	T.eq(d.result()["bonus"], roundi(plain * 1.25), "payout multiplier")
	d.free()


func test_spawn_boost_speeds_up_a_stream_then_expires() -> void:
	var d := _director()
	d.apply_effects({"spawn_mult": {"stream": "tickets", "mult": 2.0, "seconds": 10.0}})
	T.eq(d.boost("tickets"), 2.0, "boosted")
	T.eq(d.boost("pr"), 1.0, "other streams untouched")
	d._ticket_timer = 1.0e9
	_run(d, 10.5)
	T.eq(d.boost("tickets"), 1.0, "boost over")
	d.free()


func test_meeting_majority_applies_and_closes() -> void:
	var p := _player()
	var d := _director([p] as Array[Player])
	d._ticket_timer = 1.0e9
	var ended := []
	var cb := func(_def, pad): ended.append(pad)
	EventBus.meeting_ended.connect(cb)
	_open_meeting(d)
	T.truth(d.meeting != null, "meeting open")
	T.eq(d.meeting.pads.size(), 3, "three pads")
	p.global_position = d.meeting.pads[2].global_position
	_run(d, 3.0)
	EventBus.meeting_ended.disconnect(cb)
	T.eq(ended, [2], "pad 2 chosen by the only player")
	T.truth(d.meeting == null, "meeting closed")
	p.free()
	d.free()


func test_tie_picks_one_of_the_tied_pads() -> void:
	var a := _player()
	var b := _player()
	var d := _director([a, b] as Array[Player])
	d._ticket_timer = 1.0e9
	var ended := []
	var cb := func(_def, pad): ended.append(pad)
	EventBus.meeting_ended.connect(cb)
	_open_meeting(d)
	a.global_position = d.meeting.pads[0].global_position
	b.global_position = d.meeting.pads[1].global_position
	_run(d, 3.0)
	EventBus.meeting_ended.disconnect(cb)
	T.eq(ended.size(), 1, "closed once")
	T.truth(ended[0] == 0 or ended[0] == 1, "one of the tied pads, got %s" % ended[0])
	a.free()
	b.free()
	d.free()


func test_nobody_locked_still_picks_a_pad_when_time_runs_out() -> void:
	var d := _director()
	d._ticket_timer = 1.0e9
	var ended := []
	var cb := func(_def, pad): ended.append(pad)
	EventBus.meeting_ended.connect(cb)
	_open_meeting(d)
	_run(d, d.b.meeting_countdown + 1.0)
	EventBus.meeting_ended.disconnect(cb)
	T.eq(ended.size(), 1, "closed once")
	T.truth(ended[0] >= 0 and ended[0] < 3, "valid pad")
	d.free()


func test_deadlines_keep_running_in_meeting() -> void:
	var d := _director()
	d._ticket_timer = 1.0e9
	_open_meeting(d)
	var it := WorkItem.new()
	it.type = "ticket"
	it.deadline = 3.0
	d.items = [it]
	var before := d.satisfaction
	_run(d, 4.0)
	T.truth(d.meeting != null, "still in the meeting")
	T.eq(d.satisfaction, before + d.b.sat_expire, "the ticket expired during the meeting")
	d.free()


func test_stations_disabled_during_meeting() -> void:
	var d := _director()
	d._ticket_timer = 1.0e9
	var s := Station.new()
	s.kind = "pc"
	d.register_station(s)
	var it := WorkItem.new()
	it.deadline = 100.0
	d.items = [it]
	d.tick(DT)
	T.eq(s.enabled, true, "enabled with work")
	_open_meeting(d)
	d.tick(DT)
	T.eq(s.enabled, false, "disabled in a meeting")
	s.free()
	d.free()


func test_run_end_during_meeting_ends_once() -> void:
	var d := _director()
	d._ticket_timer = 1.0e9
	var ended := []
	var cb := func(_r): ended.append(1)
	var meeting_ended := []
	var cb2 := func(_def, _pad): meeting_ended.append(1)
	EventBus.run_ended.connect(cb)
	EventBus.meeting_ended.connect(cb2)
	_open_meeting(d)
	d.satisfaction = 1.0
	var it := WorkItem.new()
	it.deadline = 0.01
	d.items = [it]
	_run(d, 2.0)
	T.eq(ended.size(), 1, "run ended once")
	T.truth(d.meeting == null, "meeting torn down")
	var left := d.time_left
	_run(d, 20.0)
	T.eq(d.time_left, left, "frozen after the end")
	T.eq(meeting_ended.size(), 0, "no meeting_ended after the run is over")
	EventBus.run_ended.disconnect(cb)
	EventBus.meeting_ended.disconnect(cb2)
	d.free()
