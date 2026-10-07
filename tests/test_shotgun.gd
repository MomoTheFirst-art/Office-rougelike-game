extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _player(ammo := 3) -> Player:
	var p := Player.new()
	tree.root.add_child(p)
	p.use_scripted = true
	p.ammo = ammo
	return p  # faces -Z by default


func _chatter(at: Vector3) -> Chatter:
	var c := Chatter.new()
	c.b = Balance.new()
	tree.root.add_child(c)
	c.global_position = at
	c.home = at
	c.cooldown_left = 1000.0
	return c


func _climber(at: Vector3) -> Climber:
	var c := Climber.new()
	c.b = Balance.new()
	c.director = RunDirector.new()
	tree.root.add_child(c)
	c.global_position = at
	c.home = at
	c.cooldown_left = 1000.0
	return c


func _run_player(p: Player, seconds: float) -> void:
	for i in int(seconds / DT):
		p.step(DT)


func test_fire_stuns_each_npc_for_its_own_duration() -> void:
	var b := Balance.new()
	var p := _player()
	var chatter := _chatter(Vector3(0, 0, -5))
	T.eq(p.fire([chatter] as Array[Node3D], b), true, "fired")
	T.eq(chatter.state, Chatter.State.STUNNED, "Chatter stunned")
	for i in int((b.stun_chatter - 0.1) / DT):
		chatter.tick(DT)
	T.eq(chatter.state, Chatter.State.STUNNED, "still stunned just before stun_chatter")
	for i in int(0.3 / DT):
		chatter.tick(DT)
	T.truth(chatter.state != Chatter.State.STUNNED, "Chatter stun is 4 s")
	var climber := _climber(Vector3(0, 0, -5))
	p.ammo = 3
	_run_player(p, 1.0)
	p.fire([climber] as Array[Node3D], b)
	T.eq(climber.state, Climber.State.STUNNED, "Climber stunned")
	for i in int((b.stun_climber - 0.1) / DT):
		climber.tick(DT)
	T.eq(climber.state, Climber.State.STUNNED, "still stunned just before stun_climber")
	p.free()
	chatter.free()
	climber.director.free()
	climber.free()


func test_only_the_nearest_target_in_the_cone_is_hit() -> void:
	var b := Balance.new()
	var p := _player()
	var near := _chatter(Vector3(0, 0, -3))
	var far := _chatter(Vector3(0, 0, -6))
	p.fire([far, near] as Array[Node3D], b)
	T.eq(near.state, Chatter.State.STUNNED, "nearest hit")
	T.truth(far.state != Chatter.State.STUNNED, "farther one untouched")
	p.free()
	near.free()
	far.free()


func test_no_ammo_returns_false_and_stuns_nothing() -> void:
	var b := Balance.new()
	var p := _player(0)
	var c := _chatter(Vector3(0, 0, -4))
	T.eq(p.fire([c] as Array[Node3D], b), false, "no ammo")
	T.truth(c.state != Chatter.State.STUNNED, "nothing stunned")
	p.free()
	c.free()


func test_cooldown_blocks_a_second_shot() -> void:
	var b := Balance.new()
	var p := _player()
	T.eq(p.fire([] as Array[Node3D], b), true, "first shot")
	T.eq(p.fire([] as Array[Node3D], b), false, "blocked by the cooldown")
	T.eq(p.ammo, 2, "only one shell spent")
	_run_player(p, b.shotgun_cooldown + 0.1)
	T.eq(p.fire([] as Array[Node3D], b), true, "ready again")
	p.free()


func test_out_of_cone_or_range_misses_but_spends_the_shell() -> void:
	var b := Balance.new()
	var p := _player()
	var side := _chatter(Vector3(6, 0, 0))
	T.eq(p.fire([side] as Array[Node3D], b), true, "fired")
	T.truth(side.state != Chatter.State.STUNNED, "off to the side: missed")
	T.eq(p.ammo, 2, "shell spent")
	_run_player(p, 1.0)
	var far := _chatter(Vector3(0, 0, -(b.shotgun_range + 1.0)))
	p.fire([far] as Array[Node3D], b)
	T.truth(far.state != Chatter.State.STUNNED, "out of range: missed")
	p.free()
	side.free()
	far.free()


func test_players_are_never_targets() -> void:
	var b := Balance.new()
	var p := _player()
	var other := _player()
	other.global_position = Vector3(0, 0, -3)
	p.fire([other] as Array[Node3D], b)
	T.eq(other.move_mult, 1.0, "nothing happens to a player")
	p.free()
	other.free()


func test_facing_follows_movement() -> void:
	var b := Balance.new()
	var p := _player()
	p.scripted_move = Vector2(1, 0)
	_run_player(p, 0.1)
	p.scripted_move = Vector2.ZERO
	var c := _chatter(p.global_position + Vector3(4, 0, 0))
	p.fire([c] as Array[Node3D], b)
	T.eq(c.state, Chatter.State.STUNNED, "hit what it faced")
	p.free()
	c.free()


func _shelf(p: Player, b: Balance) -> ShotgunShelf:
	var s := ShotgunShelf.new()
	s.b = b
	tree.root.add_child(s)
	s.global_position = Vector3(20, 0, 20)
	s.players = [p] as Array[Player]
	p.global_position = s.global_position
	return s


func test_shelf_gives_ammo_plus_the_buff_and_respawns_after_use() -> void:
	var b := Balance.new()
	var p := _player(0)
	p.stats["shotgun_ammo"] = 1.0
	var s := _shelf(p, b)
	s.tick(DT)
	T.eq(p.ammo, b.shotgun_ammo + 1, "3 shells plus the extra-shell buff")
	T.eq(s.available, false, "shelf empty")
	var q := _player(0)
	q.global_position = s.global_position
	s.players = [p, q] as Array[Player]
	for i in int(5.0 / DT):
		s.tick(DT)
	T.eq(q.ammo, 0, "nothing left for the second player")
	p.ammo = 0  # used up
	p.global_position = Vector3(0, 0, 0)  # walk away so nobody grabs it the moment it returns
	q.global_position = Vector3(0, 0, 0)
	for i in int((b.shotgun_respawn - 1.0) / DT):
		s.tick(DT)
	T.eq(s.available, false, "not back yet")
	for i in int(2.0 / DT):
		s.tick(DT)
	T.eq(s.available, true, "respawned about 20 s after being used up")
	p.global_position = s.global_position
	s.tick(DT)
	T.eq(p.ammo, b.shotgun_ammo + 1, "picked up again")
	p.free()
	q.free()
	s.free()


func test_a_player_who_still_has_shells_does_not_pick_up_again() -> void:
	var b := Balance.new()
	var p := _player(2)
	var s := _shelf(p, b)
	s.tick(DT)
	T.eq(p.ammo, 2, "unchanged")
	T.eq(s.available, true, "shelf still stocked")
	p.free()
	s.free()
