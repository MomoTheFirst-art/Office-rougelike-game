extends RefCounted

var tree: SceneTree
const DT := 1.0 / 60.0


func _pool() -> Array[BuffDef]:
	return (load("res://data/buffs/pool.tres") as BuffPool).buffs


func _rng(seed_value := 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _def(id: String, stream: String) -> BuffDef:
	var d := BuffDef.new()
	d.id = id
	d.stream = stream
	d.stat = "move_speed"
	d.op = "mul"
	d.value = 1.1
	return d


func test_pool_is_big_enough_and_well_formed() -> void:
	var pool := _pool()
	T.truth(pool.size() >= 10, "at least 10 buffs, got %d" % pool.size())
	var ids := {}
	for d in pool:
		ids[d.id] = true
		T.truth(d.op == "mul" or d.op == "add", "op of %s" % d.id)
		T.truth(d.stat != "" and d.title != "" and d.description != "", "fields of %s" % d.id)
	T.eq(ids.size(), pool.size(), "ids are unique")


func test_buff_weight() -> void:
	T.near(Rules.buff_weight(0.7), 3.8, 0.0001, "1 + 4 x 0.7")
	T.eq(Rules.buff_weight(0.0), 1.0, "no share")


func test_draw_offers_three_distinct() -> void:
	for seed_value in 50:
		var offers := Rules.draw_offers(_pool(), {"tickets": 0.5, "pr": 0.5}, _rng(seed_value))
		T.eq(offers.size(), 3, "three offers")
		var ids := {}
		for o in offers:
			ids[o.id] = true
		T.eq(ids.size(), 3, "distinct")


func test_top_stream_slot_is_guaranteed() -> void:
	for seed_value in 100:
		var offers := Rules.draw_offers(_pool(), {"tickets": 1.0}, _rng(seed_value))
		T.eq(offers[0].stream, "tickets", "first slot from the top stream")


func test_pool_without_the_top_stream_still_gives_three() -> void:
	var pool: Array[BuffDef] = [_def("a", "mobility"), _def("b", "mobility"), _def("c", "mobility"), _def("d", "mobility")]
	T.eq(Rules.draw_offers(pool, {"pr": 1.0}, _rng()).size(), 3, "three from a mobility-only pool")
	T.eq(Rules.draw_offers(pool, {}, _rng()).size(), 3, "three with no history")


func test_weights_favour_worked_streams() -> void:
	var rng := _rng(5)
	var pr := 0
	var business := 0
	for i in 300:
		for o in Rules.draw_offers(_pool(), {"pr": 0.8, "tickets": 0.2}, rng):
			if o.stream == "pr":
				pr += 1
			elif o.stream == "business":
				business += 1
	T.truth(pr > business * 2, "pr buffs far more common than business, %d vs %d" % [pr, business])


func test_add_stat_mul_and_add() -> void:
	var p := Player.new()
	p.add_stat("hold_tickets", "mul", 0.85)
	p.add_stat("hold_tickets", "mul", 0.85)
	T.near(p.stat_mult("hold_tickets"), 0.7225, 0.0001, "two 15% buffs stack")
	p.add_stat("shotgun_ammo", "add", 1.0)
	p.add_stat("shotgun_ammo", "add", 1.0)
	T.eq(p.stats["shotgun_ammo"], 2.0, "adds")
	p.free()


func test_action_shares() -> void:
	var p := Player.new()
	T.eq(p.action_shares(), {}, "no history")
	for i in 3:
		p.record_action("tickets")
	p.record_action("pr")
	T.eq(p.action_shares(), {"tickets": 0.75, "pr": 0.25}, "shares")
	p.free()


func _director_with_player() -> Array:
	var p := Player.new()
	tree.root.add_child(p)
	var d := RunDirector.new()
	tree.root.add_child(d)
	d.start([p] as Array[Player], 3, 5)
	d._ticket_timer = 1.0e9
	return [d, p]


func _run(d: RunDirector, seconds: float) -> void:
	for i in int(seconds / DT):
		d.tick(DT)


func _finish_a_meeting(d: RunDirector, p: Player) -> void:
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	_run(d, 1.0)
	p.global_position = d.meeting.pads[0].global_position
	_run(d, 3.0)


func test_meeting_end_offers_three_cards_and_choice_applies() -> void:
	var dp := _director_with_player()
	var d: RunDirector = dp[0]
	var p: Player = dp[1]
	_finish_a_meeting(d, p)
	T.truth(d.buff_offers.has(p), "player has offers")
	T.eq(d.buff_offers[p].size(), 3, "three cards")
	var card: BuffDef = d.buff_offers[p][1]
	d.choose_buff(p, 1)
	T.truth(not d.buff_offers.has(p), "offers cleared")
	T.truth(p.stats.has(card.stat), "stat applied: %s" % card.stat)
	d.choose_buff(p, 0)
	T.eq(p.stats.size(), 1, "a second pick does nothing")
	p.free()
	d.free()


func test_idle_player_gets_exactly_one_random_card() -> void:
	var dp := _director_with_player()
	var d: RunDirector = dp[0]
	var p: Player = dp[1]
	_finish_a_meeting(d, p)
	_run(d, d.b.buff_timeout + 1.0)
	T.truth(not d.buff_offers.has(p), "offers resolved")
	T.eq(p.stats.size(), 1, "exactly one buff applied")
	p.free()
	d.free()
