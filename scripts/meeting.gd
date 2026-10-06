class_name Meeting
extends Node3D
## The floor clears and one pad per choice appears. Stand on a pad to lock it in.
## Ends when every player is locked or the countdown runs out; the majority pad wins.

signal finished(pad: int)

var def: MeetingDef
var pads: Array[Station] = []
var time_left := 0.0
var _players: Array[Player] = []
var _rng: RandomNumberGenerator
var _locked := {}  # Player -> pad index
var _done := false


func begin(d: MeetingDef, players: Array[Player], rng: RandomNumberGenerator, b: Balance) -> void:
	def = d
	_players = players
	_rng = rng
	time_left = b.meeting_countdown
	var n := d.labels.size()
	for i in n:
		var s := Station.new()
		add_child(s)
		s.setup("pad", b.hold_pad, Vector3(3, 0.2, 3), Color.from_hsv(float(i) / n, 0.6, 0.9))
		s.position = Vector3((i - (n - 1) / 2.0) * 4.0, 0, 0)
		s.caption = "%s\n%s" % [d.labels[i], d.previews[i]]
		s.players = players
		s.enabled = true
		s.set_physics_process(false)  # this node ticks the pads
		s.completed.connect(func(pl: Player): _locked[pl] = i)
		pads.append(s)


func tick(dt: float) -> void:
	if _done:
		return
	for s in pads:
		s.tick(dt)
	for pl: Player in _locked.keys():
		if not pads[_locked[pl]].contains(pl):
			_locked.erase(pl)
	time_left -= dt
	if time_left <= 0.0 or (not _players.is_empty() and _locked.size() == _players.size()):
		_done = true
		var votes: Array[int] = []
		votes.resize(pads.size())
		votes.fill(0)
		for pl: Player in _locked:
			votes[_locked[pl]] += 1
		finished.emit(Rules.pick_meeting_pad(votes, _rng))
