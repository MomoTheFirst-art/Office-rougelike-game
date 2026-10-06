extends RefCounted
## Regression tests for the final whole-branch review findings.

var tree: SceneTree
const DT := 1.0 / 60.0


func _office(level: int) -> Node3D:
	RunDirector.carried_level = level
	var office: Node3D = load("res://main.tscn").instantiate()
	tree.root.add_child(office)
	return office


func _run(d: RunDirector, seconds: float) -> void:
	for i in int(seconds / DT):
		d.tick(DT)


# 1. A meeting must not leave the player slowed by the Chatter.
func test_meeting_start_ends_the_chatters_talk_and_restores_the_player() -> void:
	var office := _office(6)
	var d: RunDirector = office.director
	var chatter: Chatter = office.get_node("Chatter")
	var p: Player = office.player_list[0]
	chatter.target = p
	chatter.state = Chatter.State.TALK
	p.move_mult = d.b.chatter_move_mult
	p.work_rate = d.b.chatter_work_mult
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	_run(d, 1.0)
	T.truth(d.meeting != null, "meeting open")
	T.eq([p.move_mult, p.work_rate], [1.0, 1.0], "player is not slowed during the meeting")
	T.eq(chatter.state, Chatter.State.LEAVE, "the talk was cancelled")
	office.free()
	RunDirector.carried_level = 1


# 2. Nothing may change after the run has ended.
func test_steal_after_the_run_ends_changes_nothing() -> void:
	var d := RunDirector.new()
	d.start([] as Array[Player], 1, 6)
	d.quests["tickets"] = 5.0
	d.recent_solves.append({"quest": "tickets", "amount": 1.0})
	d.end_run("time")
	d.steal(3)
	T.eq(d.quests["tickets"], 5.0, "tickets untouched")
	T.eq(d.rival_bar, 0.0, "rival bar untouched")
	d.free()


func test_npcs_freeze_when_the_run_ends() -> void:
	var office := _office(6)
	var d: RunDirector = office.director
	T.truth(office.get_node("Climber").can_process(), "moving before the end")
	d.end_run("time")
	T.eq(office.get_node("Climber").can_process(), false, "Climber frozen after the end")
	T.eq(office.get_node("Chatter").can_process(), false, "Chatter frozen after the end")
	office.free()
	RunDirector.carried_level = 1


# 3. Locked features are never offered as buffs.
func _offers_stats(level: int, draws: int) -> Dictionary:
	var p := Player.new()
	var d := RunDirector.new()
	tree.root.add_child(d)
	tree.root.add_child(p)
	d.start([p] as Array[Player], 1, level)
	var stats := {}
	for s in draws:
		d.rng.seed = s
		d.buff_offers.clear()
		d._offer_buffs()
		for card: BuffDef in d.buff_offers[p]:
			stats[card.stat] = true
	d.free()
	p.free()
	return stats


func test_buff_offers_respect_the_ladder() -> void:
	T.truth(not _offers_stats(5, 200).has("shotgun_ammo"), "no shotgun buff before the shotgun exists")
	T.truth(_offers_stats(6, 200).has("shotgun_ammo"), "shotgun buff offered once it unlocks")


# 4. Spawn rates scale with career level and player count (spec section 4).
func _spawned(level: int, players: int, types: Array, seconds: float) -> int:
	var plist: Array[Player] = []
	for i in players:
		var pl := Player.new()
		tree.root.add_child(pl)  # a meeting starts at level 5+, and its pads need live nodes
		plist.append(pl)
	var d := RunDirector.new()
	tree.root.add_child(d)
	d.b = Balance.new()
	d.b.sat_expire = 0.0
	d.b.outage_sat_per_s = 0.0
	d.start(plist, 1, level)
	var n := [0]
	var cb := func(item): n[0] += 1 if types.has(item.type) else 0
	EventBus.item_spawned.connect(cb)
	_run(d, seconds)
	EventBus.item_spawned.disconnect(cb)
	d.free()
	for p in plist:
		p.free()
	return n[0]


func test_ticket_spawn_rate_scales_with_level_and_players() -> void:
	var base := _spawned(1, 1, ["ticket", "bugticket"], 200.0)
	T.truth(base >= 20 and base <= 30, "level 1, one player: about 25 tickets in 200 s, got %d" % base)
	var l6 := _spawned(6, 1, ["ticket", "bugticket"], 200.0)
	T.near(float(l6) / base, 2.0, 0.25, "level 6 is about 2x the tickets of level 1 (target grows 2x)")
	var two := _spawned(1, 2, ["ticket", "bugticket"], 200.0)
	T.near(float(two) / base, 2.0, 0.25, "two players get about 2x the tickets")


func test_lead_spawn_rate_scales_with_players() -> void:
	var one := _spawned(4, 1, ["lead"], 300.0)
	var two := _spawned(4, 2, ["lead"], 300.0)
	T.truth(one >= 5, "some leads at level 4, got %d" % one)
	T.near(float(two) / one, 2.0, 0.3, "two players get about 2x the leads")


# 5. Every player on a pad counts as a vote.
func _meeting_with(positions: Array, seed_value: int) -> Array:
	var plist: Array[Player] = []
	for i in positions.size():
		var p := Player.new()
		tree.root.add_child(p)
		plist.append(p)
	var d := RunDirector.new()
	tree.root.add_child(d)
	d.start(plist, seed_value, 5)
	d._ticket_timer = 1.0e9
	d.meeting_at = [0.5, 1.0e9, 1.0e9] as Array[float]
	_run(d, 1.0)
	for i in positions.size():
		plist[i].global_position = d.meeting.pads[positions[i]].global_position
	var ended := []
	var cb := func(_def, pad): ended.append(pad)
	EventBus.meeting_ended.connect(cb)
	_run(d, 3.0)
	EventBus.meeting_ended.disconnect(cb)
	var closed := d.meeting == null
	d.free()
	for p in plist:
		p.free()
	return [ended, closed]


func test_two_players_on_one_pad_both_lock_and_the_meeting_ends_early() -> void:
	var r := _meeting_with([1, 1], 3)
	T.eq(r[0], [1], "pad 1 chosen within 3 s, long before the countdown")
	T.eq(r[1], true, "meeting closed")


func test_majority_counts_every_player_on_a_pad() -> void:
	for seed_value in 12:
		var r := _meeting_with([0, 0, 1], seed_value)
		T.eq(r[0], [0], "two players beat one (seed %d)" % seed_value)
