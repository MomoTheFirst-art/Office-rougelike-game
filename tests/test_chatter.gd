extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _player(at: Vector3) -> Player:
	var p := Player.new()
	tree.root.add_child(p)
	p.global_position = at
	return p


func _chatter(at: Vector3, players: Array[Player]) -> Chatter:
	var c := Chatter.new()
	c.b = Balance.new()
	tree.root.add_child(c)
	c.global_position = at
	c.home = at
	c.players = players
	c.cooldown_left = 0.0
	return c


func _run(c: Chatter, seconds: float) -> void:
	for i in int(seconds / DT):
		c.tick(DT)


## Tick until the state equals `want` (or, with `leave` true, until it stops equaling it); returns seconds taken.
func _until(c: Chatter, want: Chatter.State, leave := false, max_seconds := 60.0) -> float:
	var n := 0
	while (c.state == want) == leave and n < int(max_seconds / DT):
		c.tick(DT)
		n += 1
	return n * DT


func test_picks_the_busiest_player_else_the_nearest() -> void:
	var near := _player(Vector3(3, 0, 0))
	var busy := _player(Vector3(-9, 0, 0))
	var c := _chatter(Vector3.ZERO, [near, busy] as Array[Player])
	T.truth(c.pick_target() == near, "nearest when nobody is busy")
	var st := Station.new()
	st.holder = busy
	c.stations = [st] as Array[Station]
	T.truth(c.pick_target() == busy, "busy player wins over a nearer idle one")
	c.players = [] as Array[Player]
	T.truth(c.pick_target() == null, "no players")
	for n in [near, busy, c, st]:
		n.free()


func test_approaches_then_talks_and_slows_the_target() -> void:
	var p := _player(Vector3(8, 0, 0))
	var c := _chatter(Vector3.ZERO, [p] as Array[Player])
	_run(c, 0.1)
	T.eq(c.state, Chatter.State.APPROACH, "approaching")
	_run(c, 6.0)
	T.eq(c.state, Chatter.State.TALK, "talking")
	T.eq(p.move_mult, c.b.chatter_move_mult, "movement slowed")
	T.eq(p.work_rate, c.b.chatter_work_mult, "work slowed")
	p.free()
	c.free()


func test_talk_ends_and_restores() -> void:
	var p := _player(Vector3(2, 0, 0))
	var c := _chatter(Vector3.ZERO, [p] as Array[Player])
	_until(c, Chatter.State.TALK)
	T.eq(c.state, Chatter.State.TALK, "talking")
	var talked := _until(c, Chatter.State.TALK, true)
	T.near(talked, c.b.chatter_talk, 0.1, "talks for chatter_talk seconds")
	T.eq(c.state, Chatter.State.LEAVE, "leaving")
	T.eq(p.move_mult, 1.0, "movement restored")
	T.eq(p.work_rate, 1.0, "work restored")
	p.free()
	c.free()


func test_stun_ends_talk_and_restores() -> void:
	var p := _player(Vector3(2, 0, 0))
	var c := _chatter(Vector3.ZERO, [p] as Array[Player])
	var stunned := []
	var cb := func(_n): stunned.append(1)
	EventBus.npc_stunned.connect(cb)
	_until(c, Chatter.State.TALK)
	c.stun(c.b.stun_chatter)
	T.eq(c.state, Chatter.State.STUNNED, "stunned")
	T.eq(p.move_mult, 1.0, "movement restored at once")
	T.eq(p.work_rate, 1.0, "work restored at once")
	T.eq(stunned.size(), 1, "npc_stunned emitted")
	var stunned_for := _until(c, Chatter.State.STUNNED, true)
	T.near(stunned_for, c.b.stun_chatter, 0.1, "stunned for stun_chatter seconds")
	T.eq(c.state, Chatter.State.LEAVE, "sent away after the stun")
	EventBus.npc_stunned.disconnect(cb)
	p.free()
	c.free()


func test_stun_while_stunned_refreshes_not_stacks() -> void:
	var c := _chatter(Vector3.ZERO, [] as Array[Player])
	c.stun(4.0)
	_run(c, 3.0)
	c.stun(4.0)
	_run(c, 3.9)
	T.eq(c.state, Chatter.State.STUNNED, "still stunned 3.9 s after the second stun")
	_run(c, 0.3)
	T.truth(c.state != Chatter.State.STUNNED, "over after 4 s, not 7")
	c.free()


func test_cooldown_before_returning_and_shrinks_with_level() -> void:
	var p := _player(Vector3(2, 0, 0))
	var c := _chatter(Vector3.ZERO, [p] as Array[Player])
	_until(c, Chatter.State.TALK)
	_until(c, Chatter.State.TALK, true)
	T.eq(c.state, Chatter.State.LEAVE, "leaving")
	T.near(c.cooldown_left, c.b.chatter_cooldown * Rules.timer_scale(c.level), 0.01, "cooldown set")
	_until(c, Chatter.State.LEAVE, true)
	T.eq(c.state, Chatter.State.WANDER, "home again")
	var away := _until(c, Chatter.State.WANDER, true)
	T.near(away, c.cooldown_seconds(), 0.5, "stays away for the cooldown")
	T.eq(c.state, Chatter.State.APPROACH, "then comes back")
	c.level = 5
	T.truth(c.cooldown_seconds() < c.b.chatter_cooldown, "higher level, shorter cooldown")
	p.free()
	c.free()


func test_a_freed_target_does_not_crash() -> void:
	var p := _player(Vector3(6, 0, 0))
	var c := _chatter(Vector3.ZERO, [p] as Array[Player])
	_run(c, 0.5)
	T.eq(c.state, Chatter.State.APPROACH, "approaching")
	p.free()
	_until(c, Chatter.State.APPROACH, true, 2.0)
	T.eq(c.state, Chatter.State.LEAVE, "gives up when the target is gone")
	c.free()
