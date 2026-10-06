extends SceneTree
## Runs every tests/test_*.gd: each is a RefCounted with a `tree` var and test_* methods.
## Exit code 0 means all passed.


func _initialize() -> void:
	await process_frame  # the tree is not live inside _initialize
	var total := 0
	for f in DirAccess.get_files_at("res://tests"):
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			T.failed += 1
			printerr("FAIL " + f + " (does not load)")
			continue
		var inst = script.new()
		inst.tree = self
		for m in script.get_script_method_list():
			if not String(m.name).begins_with("test_"):
				continue
			total += 1
			var before := T.failed
			inst.call(m.name)
			print(("ok   " if T.failed == before else "FAIL ") + f + "::" + m.name)
	print("%d tests, %d failed" % [total, T.failed])
	quit(1 if T.failed > 0 else 0)
