extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _director(level := 6) -> RunDirector:
	var d := RunDirector.new()
	d.start([] as Array[Player], 1, level)
	d._ticket_timer = 1.0e9
	d._bug_timer = 1.0e9
	d._lead_timer = 1.0e9
	d._pr_timer = 1.0e9
	return d


func _solve_tickets(d: RunDirector, n: int) -> void:
	for i in n:
		var it := WorkItem.new()
		it.deadline = 30.0
		d.items = [it]
		d.on_station_completed("pc", null)


func _climber(d: RunDirector) -> Climber:
	var c := Climber.new()
	c.b = d.b
	c.director = d
	tree.root.add_child(c)
	c.global_position = Vector3(10, 0, 0)
	c.home = Vector3(10, 0, 0)
	c.board = Vector3.ZERO
	c.cooldown_left = 0.0
	return c


func _until(c: Climber, want: Climber.State, leave := false, max_seconds := 60.0) -> float:
	var n := 0
	while (c.state == want) == leave and n < int(max_seconds / DT):
		c.tick(DT)
		n += 1
	return n * DT


func test_steal_removes_last_three_credits() -> void:
	var d := _director()
	_solve_tickets(d, 4)
	d.steal(3)
	T.eq(d.quests["tickets"], 1.0, "three of four credits gone")
	T.eq(d.rival_bar, d.b.climber_steal_bar, "bar +10")
	T.eq(d.recent_solves.size(), 1, "stolen solves are gone from the list")
	d.free()


func test_steal_with_fewer_than_three_never_goes_negative() -> void:
	var d := _director()
	_solve_tickets(d, 1)
	d.steal(3)
	T.eq(d.quests["tickets"], 0.0, "floored at zero")
	d.steal(3)
	T.eq(d.quests["tickets"], 0.0, "nothing left to steal")
	T.eq(d.rival_bar, 2.0 * d.b.climber_steal_bar, "bar still rises")
	d.free()


func test_bar_creeps_and_caps() -> void:
	var d := _director()
	for i in int(100.0 / DT):
		d.tick(DT)
	T.near(d.rival_bar, d.b.climber_creep * 100.0, 0.1, "creeps 0.05 per second")
	d.rival_bar = 99.0
	d.steal(3)
	T.eq(d.rival_bar, 100.0, "capped at 100")
	d.free()


func test_no_rival_below_level_6() -> void:
	var d := _director(5)
	for i in int(50.0 / DT):
		d.tick(DT)
	T.eq(d.rival_bar, 0.0, "no rival yet")
	d.free()


func test_full_bar_blocks_promotion() -> void:
	var d := _director(1)
	d.satisfaction = 95.0
	d.rival_bar = 100.0
	d.end_run("time")
	T.eq(d.result()["promoted"], false, "rival got there first")
	d.free()


func test_walks_to_the_board_and_steals_after_the_hold() -> void:
	var d := _director()
	_solve_tickets(d, 3)
	var c := _climber(d)
	_until(c, Climber.State.IDLE, true)
	T.eq(c.state, Climber.State.TO_BOARD, "heading for the board")
	_until(c, Climber.State.TO_BOARD, true)
	T.eq(c.state, Climber.State.STEALING, "at the board")
	T.eq(d.quests["tickets"], 3.0, "nothing stolen yet")
	var held := _until(c, Climber.State.STEALING, true)
	T.near(held, d.b.climber_steal_hold, 0.1, "holds for the steal time")
	T.eq(d.quests["tickets"], 0.0, "credit stolen")
	T.eq(c.state, Climber.State.IDLE, "heads home")
	T.near(c.cooldown_left, c.interval(), 0.01, "cooldown restarts")
	c.free()
	d.free()


func test_call_out_cancels_the_steal_and_sends_him_away() -> void:
	var d := _director()
	_solve_tickets(d, 3)
	var c := _climber(d)
	_until(c, Climber.State.STEALING, false)
	c.call_out()
	T.eq(c.state, Climber.State.AWAY, "away")
	var away := _until(c, Climber.State.AWAY, true)
	T.near(away, d.b.climber_away, 0.1, "away for climber_away seconds")
	T.eq(d.quests["tickets"], 3.0, "nothing was stolen")
	T.eq(d.rival_bar, 0.0, "bar untouched")
	c.free()
	d.free()


func test_call_out_does_nothing_when_idle() -> void:
	var d := _director()
	var c := _climber(d)
	c.cooldown_left = 100.0
	c.call_out()
	T.eq(c.state, Climber.State.IDLE, "still idle")
	c.free()
	d.free()


func test_stun_cancels_the_steal_and_refreshes_not_stacks() -> void:
	var d := _director()
	_solve_tickets(d, 3)
	var c := _climber(d)
	_until(c, Climber.State.STEALING, false)
	c.stun(d.b.stun_climber)
	T.eq(c.state, Climber.State.STUNNED, "stunned")
	for i in int(3.0 / DT):
		c.tick(DT)
	c.stun(d.b.stun_climber)
	var stunned := _until(c, Climber.State.STUNNED, true)
	T.near(stunned, d.b.stun_climber, 0.1, "second stun refreshed to full, did not add")
	T.eq(d.quests["tickets"], 3.0, "nothing stolen")
	T.eq(c.state, Climber.State.IDLE, "idle afterwards")
	c.free()
	d.free()


func test_callout_station_is_enabled_only_while_he_is_after_the_board() -> void:
	var d := _director()
	var c := _climber(d)
	var st := Station.new()
	tree.root.add_child(st)
	c.callout = st
	c.cooldown_left = 5.0
	c.tick(DT)
	T.eq(st.enabled, false, "idle: nothing to call out")
	c.cooldown_left = 0.0
	c.tick(DT)
	T.eq(st.enabled, true, "on his way")
	_until(c, Climber.State.TO_BOARD, true)
	c.tick(DT)
	T.eq(st.enabled, true, "stealing")
	c.call_out()
	c.tick(DT)
	T.eq(st.enabled, false, "away")
	st.free()
	c.free()
	d.free()
