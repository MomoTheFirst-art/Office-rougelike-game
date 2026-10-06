extends SceneTree
## Writes the data/*.tres resources. Run: godot --headless --path . --script tools/make_data.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var err := ResourceSaver.save(Balance.new(), "res://data/balance.tres")
	print("balance.tres: ", error_string(err))
	quit(0 if err == OK else 1)
