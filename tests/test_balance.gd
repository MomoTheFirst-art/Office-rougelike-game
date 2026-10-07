extends RefCounted

var tree: SceneTree


func test_defaults_match_spec() -> void:
	var b := Balance.new()
	T.eq(b.run_seconds, 600.0, "run_seconds")
	T.eq(b.hold_pc, 4.0, "hold_pc")
	T.eq(b.promo_threshold, 90.0, "promo_threshold")
	T.eq(b.meeting_times, PackedFloat32Array([0.25, 0.5, 0.75]), "meeting_times")


func test_unlock_levels() -> void:
	var b := Balance.new()
	T.eq(b.unlock_levels["tickets"], 1, "tickets")
	T.eq(b.unlock_levels["stability"], 2, "stability")
	T.eq(b.unlock_levels["pr"], 3, "pr")
	T.eq(b.unlock_levels["npcs"], 6, "npcs")


func test_event_bus_available() -> void:
	T.truth(tree.root.has_node("EventBus"), "EventBus autoload present")
