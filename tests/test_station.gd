extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _station(kind := "pc", hold := 4.0) -> Station:
	var s := Station.new()
	tree.root.add_child(s)
	s.setup(kind, hold, Vector3(2, 1, 2), Color.WHITE)
	s.stream = "tickets"
	s.enabled = true
	return s


func _player(at: Vector3) -> Player:
	var p := Player.new()
	tree.root.add_child(p)
	p.global_position = at
	return p


func _run(s: Station, seconds: float) -> void:
	for i in int(seconds / DT):
		s.tick(DT)


func _count(s: Station) -> Array:
	var done := []
	s.completed.connect(func(_p): done.append(1))
	return done


func test_hold_seconds_applies_stat() -> void:
	T.eq(Rules.hold_seconds(4.0, {"hold_tickets": 0.5}, "hold_tickets"), 2.0, "scaled")
	T.eq(Rules.hold_seconds(4.0, {}, "hold_tickets"), 4.0, "missing key")


func test_fills_and_completes() -> void:
	var s := _station()
	var p := _player(Vector3.ZERO)
	s.players = [p]
	var done := _count(s)
	_run(s, 3.8)
	T.eq(done.size(), 0, "not done before 4 s")
	_run(s, 0.4)
	T.eq(done.size(), 1, "done once after 4 s")
	T.truth(s.progress < 0.2, "progress reset after completion")
	s.free()
	p.free()


func test_disabled_station_keeps_no_progress() -> void:
	var s := _station()
	s.enabled = false
	var p := _player(Vector3.ZERO)
	s.players = [p]
	var done := _count(s)
	_run(s, 5.0)
	T.eq(done.size(), 0, "no completion")
	T.eq(s.progress, 0.0, "no progress")
	T.truth(s.holder == p, "holder still tracked while disabled")
	s.free()
	p.free()


func test_leaving_resets() -> void:
	var s := _station()
	var p := _player(Vector3.ZERO)
	s.players = [p]
	_run(s, 2.0)
	T.truth(s.progress > 0.4, "half filled")
	p.global_position = Vector3(10, 0, 10)
	s.tick(DT)
	T.eq(s.progress, 0.0, "reset on leaving")
	T.truth(s.holder == null, "no holder")
	s.free()
	p.free()


func test_second_player_ignored() -> void:
	var s := _station()
	var a := _player(Vector3(0.2, 0, 0))
	var b := _player(Vector3(-0.2, 0, 0))
	s.players = [a, b]
	var done := _count(s)
	_run(s, 0.1)
	T.truth(s.holder == a, "first player holds")
	_run(s, 3.8)
	T.eq(done.size(), 0, "second player did not speed it up")
	_run(s, 0.3)
	T.eq(done.size(), 1, "done at about 4 s")
	s.free()
	a.free()
	b.free()


func test_work_rate_slows() -> void:
	var s := _station()
	var p := _player(Vector3.ZERO)
	p.work_rate = 0.5
	s.players = [p]
	var done := _count(s)
	_run(s, 7.5)
	T.eq(done.size(), 0, "not done at 7.5 s")
	_run(s, 0.8)
	T.eq(done.size(), 1, "done at about 8 s")
	s.free()
	p.free()


func test_stream_stat_speeds_up() -> void:
	var s := _station()
	var p := _player(Vector3.ZERO)
	p.stats["hold_tickets"] = 0.5
	s.players = [p]
	var done := _count(s)
	_run(s, 2.2)
	T.eq(done.size(), 1, "done at about 2 s")
	s.free()
	p.free()
