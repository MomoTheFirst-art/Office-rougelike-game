class_name WorkItem
extends RefCounted
## One piece of work. Pure data plus rules for which station can advance it.
## apply() returns the effects; the director applies them.
##
## ticket     reply at pc / call at phone
## bugticket  stage 0: file the bug at pc; stage 1: waiting on the dev; stage 2: reply at pc
## bug        fixed at the dev table; finishing it releases its ticket to stage 2

var type := "ticket"  # also "bugticket", "bug" (later: "lead", "pr")
var stage := 0
var deadline := 0.0  # seconds left before it expires (INF for bugs)
var size := 0  # lead size index
var ticket: WorkItem = null  # for a bug: the ticket waiting on it


func stream() -> String:
	return "bugs" if type == "bug" else "tickets"


func accepts(station_kind: String) -> bool:
	match type:
		"ticket":
			return station_kind == "pc" or station_kind == "phone"
		"bugticket":
			return station_kind == "pc" and (stage == 0 or stage == 2)
		"bug":
			return station_kind == "devtable"
	return false


func apply(station_kind: String, b: Balance) -> Dictionary:
	var fx := {"done": true, "satisfaction": 0.0, "quest": {}, "spawn_bug": false, "stage": stage}
	match type:
		"ticket":
			fx["satisfaction"] = b.sat_reply if station_kind == "pc" else b.sat_call
			fx["quest"] = {"tickets": 1.0}
		"bugticket":
			if stage == 0:
				fx["done"] = false
				fx["spawn_bug"] = true
				fx["stage"] = 1
			else:
				fx["satisfaction"] = b.sat_bug
				fx["quest"] = {"tickets": 1.0}
	return fx
