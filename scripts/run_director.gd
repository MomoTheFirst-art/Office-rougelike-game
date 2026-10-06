class_name RunDirector
extends Node
## Owns the run: timer, satisfaction, stability, work items, quests.
## The only thing that mutates run state.

static var carried_level := 1  # in memory only; saving is out of scope

var b: Balance
var rng := RandomNumberGenerator.new()
var level := 1
var players: Array[Player] = []
var time_left := 0.0
var satisfaction := 0.0
var stability := 100.0
var items: Array[WorkItem] = []
var quests := {"tickets": 0.0, "revenue": 0.0, "pr": 0.0, "stable_s": 0.0}
var running := false
var outcome := ""
var stations: Array[Station] = []
var bugticket_share := 0.0
var rival_bar := 0.0  # set by the Climber (Task 9)
var _ticket_timer := 0.0
var _bug_timer := 0.0
var _lead_timer := 0.0
var _pr_timer := 0.0
var _outage_timer := 0.0
var meeting_defs: Array[MeetingDef] = []
var meeting_at: Array[float] = []  # elapsed seconds at which each meeting starts
var meeting: Meeting = null
var target_mults := {}  # quest -> multiplier from meeting choices
var payout_mult := 1.0
var _boosts: Array = []  # {stream, mult, left} spawn boosts from meeting choices
var _meeting_next := 0
var buff_pool: BuffPool
var buff_offers := {}  # Player -> Array[BuffDef] waiting for a pick
var _buff_left := 0.0


func start(p: Array[Player], seed_value: int, run_level := 1) -> void:
	if b == null:
		b = load("res://data/balance.tres") as Balance
		if b == null:
			b = Balance.new()
	players = p
	level = run_level
	rng.seed = seed_value
	time_left = b.run_seconds
	satisfaction = b.start_satisfaction
	stability = 100.0
	bugticket_share = b.bugticket_share
	_ticket_timer = b.interval_ticket * 0.25
	_bug_timer = _bug_interval()
	_lead_timer = b.interval_lead * 0.25
	_pr_timer = b.interval_pr * 0.25
	_outage_timer = 0.0
	target_mults = {}
	payout_mult = 1.0
	_boosts.clear()
	_meeting_next = 0
	meeting = null
	buff_offers.clear()
	meeting_defs.clear()
	meeting_at.clear()
	if Rules.unlocked("meetings", level, b):
		for n in ["client", "manager", "ceo"]:
			meeting_defs.append(load("res://data/meetings/%s.tres" % n) as MeetingDef)
		buff_pool = load("res://data/buffs/pool.tres") as BuffPool
		for t in b.meeting_times:
			meeting_at.append(t * b.run_seconds + rng.randf_range(0.0, 10.0))
	running = true


func register_station(s: Station) -> void:
	stations.append(s)


func active_quests() -> Array[String]:
	var q: Array[String] = ["tickets"]
	if Rules.unlocked("stability", level, b):
		q.append("stability")
	if Rules.unlocked("pr", level, b):
		q.append("pr")
	if Rules.unlocked("leads", level, b):
		q.append("revenue")
	return q


func bugs_open() -> int:
	var n := 0
	for it in items:
		if it.type == "bug":
			n += 1
	return n


func item_for(kind: String) -> WorkItem:
	var best: WorkItem = null
	for it in items:
		if it.accepts(kind) and (best == null or it.deadline < best.deadline):
			best = it
	return best


func tick(dt: float) -> void:
	if not running:
		return
	time_left -= dt
	_tick_boosts(dt)
	_tick_buff_timeout(dt)
	_spawn_work(dt)
	for it in items.duplicate():
		it.deadline -= dt
		if it.deadline <= 0.0:
			items.erase(it)
			satisfaction += it.expire_cost(b)
			EventBus.item_expired.emit(it)
	if Rules.unlocked("stability", level, b):
		_tick_stability(dt)
	_tick_meeting(dt)
	for s in stations:
		var it := item_for(s.kind)
		s.enabled = it != null and meeting == null
		if it != null:
			s.stream = it.stream()
			s.hold_mult = it.hold_mult(b)
	satisfaction = clampf(satisfaction, 0.0, 100.0)
	if satisfaction <= 0.0:
		end_run("fired")
	elif time_left <= 0.0:
		end_run("time")


func on_station_completed(kind: String, player: Player) -> void:
	if not running:
		return
	var it := item_for(kind)
	if it == null:
		return
	var fx := it.apply(kind, b)
	satisfaction = clampf(satisfaction + fx["satisfaction"], 0.0, 100.0)
	for q: String in fx["quest"]:
		quests[q] += fx["quest"][q]
	it.stage = fx["stage"]
	if fx["spawn_bug"]:
		var bug := _new_item("bug", INF)
		bug.ticket = it
	if fx["done"]:
		items.erase(it)
		if it.type == "bug" and it.ticket != null:
			it.ticket.stage = 2
		if it.type == "bugticket":
			bugticket_share *= b.bugticket_share_decay
		if player != null:
			player.record_action(it.stream())
		EventBus.item_done.emit(it, player)


func end_run(reason: String) -> void:
	if not running:
		return
	running = false
	outcome = reason
	if meeting != null:
		meeting.queue_free()
		meeting = null
	var r := result()
	if r["promoted"]:
		carried_level = level + 1
	EventBus.run_ended.emit(r)


func quest_target(q: String) -> float:
	var p := maxi(players.size(), 1)
	var t := 0.0
	match q:
		"tickets":
			t = Rules.ticket_target(p, level, b)
		"stability":
			t = b.run_seconds * b.stability_ok_share  # seconds above the ok level
		"pr":
			t = Rules.pr_target(level, b)
		"revenue":
			t = Rules.revenue_target(p, level, b)
	return t * target_mults.get(q, 1.0)


## Meeting choices: each key is optional.
func apply_effects(fx: Dictionary) -> void:
	satisfaction = clampf(satisfaction + fx.get("satisfaction", 0.0), 0.0, 100.0)
	for q: String in fx.get("target_mult", {}):
		target_mults[q] = target_mults.get(q, 1.0) * fx["target_mult"][q]
	payout_mult *= fx.get("payout_mult", 1.0)
	if fx.has("spawn_mult"):
		var sm: Dictionary = fx["spawn_mult"]
		_boosts.append({"stream": sm["stream"], "mult": sm["mult"], "left": sm["seconds"]})
	rival_bar = clampf(rival_bar + fx.get("rival_bar", 0.0), 0.0, 100.0)


## Spawn-rate multiplier for a stream from active meeting boosts.
func boost(stream: String) -> float:
	var m := 1.0
	for bo in _boosts:
		if bo["stream"] == stream:
			m *= bo["mult"]
	return m


## Seconds until the next meeting starts, or INF if none is left.
func next_meeting_in() -> float:
	if _meeting_next >= meeting_at.size():
		return INF
	return meeting_at[_meeting_next] - (b.run_seconds - time_left)


func quest_progress(q: String) -> float:
	return quests["stable_s"] if q == "stability" else quests[q]


func ratios() -> Array[float]:
	var r: Array[float] = []
	for q in active_quests():
		r.append(Rules.quest_ratio(quest_progress(q), quest_target(q)))
	return r


func result() -> Dictionary:
	var r := ratios()
	var fired := outcome == "fired"
	return {
		"outcome": outcome,
		"satisfaction": satisfaction,
		"quests": quests.duplicate(),
		"ratios": r,
		"bonus": roundi(Rules.bonus(r, level, satisfaction, fired, b) * payout_mult),
		"promoted": not fired and Rules.promoted(satisfaction, rival_bar, b),
	}


func _bug_interval() -> float:
	return b.interval_bug / (1.0 + b.bug_rate_per_level * maxi(level - 2, 0))


func _spawn_work(dt: float) -> void:
	_ticket_timer -= dt * boost("tickets")
	if _ticket_timer <= 0.0:
		_ticket_timer += b.interval_ticket
		_spawn_ticket()
	if Rules.unlocked("stability", level, b):
		_bug_timer -= dt * boost("bugs")
		if _bug_timer <= 0.0:
			_bug_timer += _bug_interval()
			_new_item("bug", INF)
	if Rules.unlocked("leads", level, b):
		_lead_timer -= dt * boost("business")
		if _lead_timer <= 0.0:
			_lead_timer += b.interval_lead
			_new_item("lead", b.deadline_lead).size = rng.randi_range(0, 2)
	if Rules.unlocked("pr", level, b):
		_pr_timer -= dt * boost("pr")
		if _pr_timer <= 0.0:
			_pr_timer += b.interval_pr
			_new_item("pr", b.deadline_pr)


func _spawn_ticket() -> void:
	if Rules.unlocked("bugtickets", level, b) and rng.randf() < bugticket_share:
		_new_item("bugticket", b.deadline_bugticket)
	else:
		_new_item("ticket", b.deadline_ticket)


func _tick_stability(dt: float) -> void:
	var standing := false
	for s in stations:
		if meeting == null and s.kind == "devtable" and s.holder != null:
			standing = true
	stability = Rules.stability_step(stability, dt, bugs_open(), standing, b)
	if stability > b.stability_ok_level:
		quests["stable_s"] += dt
	if stability <= 0.0:
		satisfaction += b.outage_sat_per_s * dt
		_outage_timer += dt
		if _outage_timer >= b.outage_ticket_every:
			_outage_timer -= b.outage_ticket_every
			_spawn_ticket()
	else:
		_outage_timer = 0.0


## Each player picks one of three cards; the card stays until picked or the timeout picks for them.
func _offer_buffs() -> void:
	for p in players:
		buff_offers[p] = Rules.draw_offers(buff_pool.buffs, p.action_shares(), rng)
	_buff_left = b.buff_timeout


func choose_buff(player: Player, index: int) -> void:
	if not buff_offers.has(player):
		return
	var card: BuffDef = buff_offers[player][index]
	player.add_stat(card.stat, card.op, card.value)
	buff_offers.erase(player)


func _tick_buff_timeout(dt: float) -> void:
	if buff_offers.is_empty():
		return
	_buff_left -= dt
	if _buff_left <= 0.0:
		for p: Player in buff_offers.keys():
			choose_buff(p, rng.randi_range(0, buff_offers[p].size() - 1))


func _tick_boosts(dt: float) -> void:
	for bo in _boosts:
		bo["left"] -= dt
	_boosts = _boosts.filter(func(bo): return bo["left"] > 0.0)


func _tick_meeting(dt: float) -> void:
	if meeting != null:
		meeting.tick(dt)
	elif _meeting_next < meeting_at.size() and next_meeting_in() <= 0.0:
		var def := meeting_defs[_meeting_next]
		_meeting_next += 1
		meeting = Meeting.new()
		add_child(meeting)
		meeting.begin(def, players, rng, b)
		meeting.finished.connect(_on_meeting_finished.bind(def))
		EventBus.meeting_started.emit(def)


func _on_meeting_finished(pad: int, def: MeetingDef) -> void:
	apply_effects(def.effects[pad])
	meeting.queue_free()
	meeting = null
	_offer_buffs()
	EventBus.meeting_ended.emit(def, pad)


func _new_item(type: String, deadline: float) -> WorkItem:
	var it := WorkItem.new()
	it.type = type
	it.deadline = deadline * Rules.timer_scale(level)
	items.append(it)
	EventBus.item_spawned.emit(it)
	return it


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)
