class_name Meeting
extends Node3D
## The floor clears and one pad per choice appears. Stand on a pad to lock it in.
## Every player locks on their own, so several players can share a pad and each counts as a vote.
## Ends when every player is locked or the countdown runs out; the majority pad wins.

signal finished(pad: int)

var def: MeetingDef
var pads: Array[Station] = []  # markers only; this node does the locking
var time_left := 0.0
var _players: Array[Player] = []
var _rng: RandomNumberGenerator
var _hold_seconds := 2.0
var _held := {}  # Player -> {"pad": int, "t": float}
var _locked := {}  # Player -> pad index
var _done := false


func begin(d: MeetingDef, players: Array[Player], rng: RandomNumberGenerator, b: Balance) -> void:
	def = d
	_players = players
	_rng = rng
	_hold_seconds = b.hold_pad
	time_left = b.meeting_countdown
	var n := d.labels.size()
	for i in n:
		var s := Station.new()
		add_child(s)
		s.setup("pad", b.hold_pad, Vector3(3, 0.2, 3), Color.from_hsv(float(i) / n, 0.6, 0.9))
		s.position = Vector3((i - (n - 1) / 2.0) * 4.0, 0, 0)
		s.caption = "%s\n%s" % [d.labels[i], d.previews[i]]
		s.set_physics_process(false)
		s.refresh_label()
		pads.append(s)


func tick(dt: float) -> void:
	if _done:
		return
	for pl in _players:
		var pad := _pad_under(pl)
		if pad == -1:
			_held.erase(pl)
			_locked.erase(pl)
			continue
		if not _held.has(pl) or _held[pl]["pad"] != pad:
			_held[pl] = {"pad": pad, "t": 0.0}
			_locked.erase(pl)
		_held[pl]["t"] += dt
		if _held[pl]["t"] >= _hold_seconds:
			_locked[pl] = pad
	_show_votes()
	time_left -= dt
	if time_left <= 0.0 or (not _players.is_empty() and _locked.size() == _players.size()):
		_done = true
		finished.emit(Rules.pick_meeting_pad(_votes(), _rng))


func _pad_under(pl: Player) -> int:
	for i in pads.size():
		if pads[i].contains(pl):
			return i
	return -1


func _votes() -> Array[int]:
	var votes: Array[int] = []
	votes.resize(pads.size())
	votes.fill(0)
	for pl: Player in _locked:
		votes[_locked[pl]] += 1
	return votes


func _show_votes() -> void:
	var votes := _votes()
	for i in pads.size():
		var base := "%s\n%s" % [def.labels[i], def.previews[i]]
		pads[i].caption = base + ("\nLOCKED x%d" % votes[i] if votes[i] > 0 else "")
		pads[i].refresh_label()
