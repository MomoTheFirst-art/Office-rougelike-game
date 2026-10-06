class_name Hud
extends CanvasLayer
## Time, satisfaction, open work, and the end screen. Reads the director each frame.

var director: RunDirector
var _status: Label
var _sat: ProgressBar
var _stab: ProgressBar
var _queue: Label
var _end: Label
var _banner: Label


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
	_stab = ProgressBar.new()
	_stab.custom_minimum_size = Vector2(260, 18)
	_stab.max_value = 100.0
	_stab.visible = Rules.unlocked("stability", d.level, d.b)
	box.add_child(_stab)
	_queue = Label.new()
	box.add_child(_queue)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 24)
	box.add_child(_banner)
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
	_status.text = "Level %d   Time %d s" % [director.level, ceili(director.time_left)]
	_sat.value = director.satisfaction
	_stab.value = director.stability
	if director.meeting != null:
		_banner.text = "%s: stand on a pad (%d s)" % [director.meeting.def.title, ceili(director.meeting.time_left)]
	elif director.next_meeting_in() <= director.b.meeting_warning:
		_banner.text = "Meeting in %d s" % ceili(director.next_meeting_in())
	else:
		_banner.text = ""
	var lines: PackedStringArray = []
	for it in director.items:
		lines.append("%s  %s" % [it.type, "fix at dev table" if is_inf(it.deadline) else "%d s" % ceili(it.deadline)])
	var quest_lines: PackedStringArray = []
	for q in director.active_quests():
		quest_lines.append("%s: %d / %d" % [q, int(director.quest_progress(q)), int(director.quest_target(q))])
	_queue.text = "Quests:\n" + "\n".join(quest_lines) + "\n\nOpen work:\n" + "\n".join(lines)


func _on_run_ended(r: Dictionary) -> void:
	var title := "YOU WERE FIRED" if r["outcome"] == "fired" else "WORKDAY OVER"
	var promo := "PROMOTED! Next run is level %d" % RunDirector.carried_level if r["promoted"] else "No promotion"
	_end.text = "%s\nSatisfaction: %d   Bonus: %d\n%s\n\nPress Enter to restart" % [
		title, int(r["satisfaction"]), r["bonus"], promo]
	_end.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _end != null and _end.visible and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
