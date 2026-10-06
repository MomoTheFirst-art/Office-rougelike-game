extends SceneTree
## Writes the data/*.tres resources. Run: godot --headless --path . --script tools/make_data.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/meetings")
	var ok := _save(Balance.new(), "res://data/balance.tres")
	for m in _meetings():
		ok = _save(m[1], "res://data/meetings/%s.tres" % m[0]) and ok
	quit(0 if ok else 1)


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	print(path, ": ", error_string(err))
	return err == OK


func _def(title: String, rows: Array) -> MeetingDef:
	var d := MeetingDef.new()
	d.title = title
	for r in rows:
		d.labels.append(r[0])
		d.previews.append(r[1])
		d.effects.append(r[2])
	return d


func _meetings() -> Array:
	var all := {"tickets": 1.2, "revenue": 1.2, "pr": 1.2}
	return [
		["client", _def("Client meeting", [
			["Quick deal", "more leads for a while", {"spawn_mult": {"stream": "business", "mult": 1.5, "seconds": 60.0}}],
			["Big promise", "revenue target +20%, payout +15%", {"target_mult": {"revenue": 1.2}, "payout_mult": 1.15}],
			["Apologise and listen", "satisfaction +8", {"satisfaction": 8.0}],
		])],
		["manager", _def("Manager meeting", [
			["Prioritise tickets", "satisfaction +5, more tickets", {"satisfaction": 5.0, "spawn_mult": {"stream": "tickets", "mult": 1.3, "seconds": 60.0}}],
			["Prioritise revenue", "more leads for a while", {"spawn_mult": {"stream": "business", "mult": 1.5, "seconds": 60.0}}],
			["Take the afternoon", "satisfaction +10, more tickets", {"satisfaction": 10.0, "spawn_mult": {"stream": "tickets", "mult": 1.3, "seconds": 45.0}}],
		])],
		["ceo", _def("CEO meeting", [
			["Stretch target", "all targets +20%, payout +25%", {"target_mult": all, "payout_mult": 1.25}],
			["Steady as she goes", "satisfaction +5", {"satisfaction": 5.0}],
			["Free pizza", "satisfaction +8, a few more tickets", {"satisfaction": 8.0, "spawn_mult": {"stream": "tickets", "mult": 1.2, "seconds": 30.0}}],
		])],
	]
