class_name WorkItem
extends RefCounted
## One piece of work. Pure data plus rules for which station can advance it.
## apply() returns the effects; the director applies them.

var type := "ticket"  # "ticket" (later: "bugticket", "lead", "pr", "bug")
var stage := 0
var deadline := 0.0  # seconds left before it expires
var size := 0  # lead size index
var ticket: WorkItem = null  # for a bug: the ticket waiting on it


func stream() -> String:
	return "tickets"


func accepts(station_kind: String) -> bool:
	return station_kind == "pc" or station_kind == "phone"


func apply(station_kind: String, b: Balance) -> Dictionary:
	var sat := b.sat_reply if station_kind == "pc" else b.sat_call
	return {"done": true, "satisfaction": sat, "quest": {"tickets": 1.0}, "spawn_bug": false, "stage": stage}
