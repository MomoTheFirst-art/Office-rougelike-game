class_name Hud
extends CanvasLayer
## Time, satisfaction, open work, and the end screen. Reads the director each frame.

var director: RunDirector
var _status: Label
var _sat: ProgressBar
var _queue: Label
var _end: Label


func setup(d: RunDirector) -> void:
	director = d
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	add_child(box)
	_status = Label.new()
	box.add_child(_status)
	_sat = ProgressBar.new()
	_sat.custom_minimum_size = Vector2(260, 24)
	_sat.max_value = 100.0
	box.add_child(_sat)
	_queue = Label.new()
	box.add_child(_queue)
	_end = Label.new()
	_end.visible = false
	_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end.add_theme_font_size_override("font_size", 28)
	add_child(_end)
	_end.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	EventBus.run_ended.connect(_on_run_ended)


func _process(_delta: float) -> void:
	if director == null:
		return
	_status.text = "Level %d   Time %d s   Tickets solved: %d" % [
		director.level, ceili(director.time_left), int(director.quests["tickets"])]
	_sat.value = director.satisfaction
	var lines: PackedStringArray = []
	for it in director.items:
		lines.append("%s  %d s" % [it.type, ceili(it.deadline)])
	_queue.text = "Open work:\n" + "\n".join(lines)


func _on_run_ended(r: Dictionary) -> void:
	var title := "YOU WERE FIRED" if r["outcome"] == "fired" else "WORKDAY OVER"
	_end.text = "%s\nTickets solved: %d\nSatisfaction: %d\n\nPress Enter to restart" % [
		title, int(r["quests"]["tickets"]), int(r["satisfaction"])]
	_end.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _end != null and _end.visible and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
