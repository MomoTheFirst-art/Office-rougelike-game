class_name RunDirector
extends Node
## Owns the run: timer, satisfaction, work items, quests. The only thing that mutates run state.

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
var _ticket_timer := 0.0


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
	_ticket_timer = b.interval_ticket * 0.25
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
	_ticket_timer -= dt
	if _ticket_timer <= 0.0:
		_ticket_timer += b.interval_ticket
		_spawn("ticket", b.deadline_ticket)
	for it in items.duplicate():
		it.deadline -= dt
		if it.deadline <= 0.0:
			items.erase(it)
			satisfaction += b.sat_expire
			EventBus.item_expired.emit(it)
	for s in stations:
		var it := item_for(s.kind)
		s.enabled = it != null
		if it != null:
			s.stream = it.stream()
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
	if fx["done"]:
		items.erase(it)
		if player != null:
			player.record_action(it.stream())
		EventBus.item_done.emit(it, player)


func end_run(reason: String) -> void:
	if not running:
		return
	running = false
	outcome = reason
	EventBus.run_ended.emit(result())


func result() -> Dictionary:
	return {"outcome": outcome, "satisfaction": satisfaction, "quests": quests.duplicate()}


func _spawn(type: String, deadline: float) -> void:
	var it := WorkItem.new()
	it.type = type
	it.deadline = deadline
	items.append(it)
	EventBus.item_spawned.emit(it)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		tick(delta)
