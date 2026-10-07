extends RefCounted

var tree: SceneTree


func test_targets_match_spec_examples() -> void:
	var b := Balance.new()
	T.near(Rules.ticket_target(4, 2, b), 192.0, 0.001, "40 x 4 x 1.2")
	T.near(Rules.revenue_target(1, 3, b), 3000.0, 0.001, "2000 x 1.5")
	T.near(Rules.pr_target(2, b), 10.0, 0.001, "6 + 2 x 2")


func test_quest_ratio() -> void:
	T.eq(Rules.quest_ratio(300.0, 100.0), 1.5, "capped at 150%")
	T.eq(Rules.quest_ratio(50.0, 100.0), 0.5, "half")
	T.eq(Rules.quest_ratio(5.0, 0.0), 0.0, "zero target gives 0")


func test_bonus_matches_spec_examples() -> void:
	var b := Balance.new()
	T.eq(Rules.bonus([1.0, 1.0, 1.0, 1.0], 1, 70.0, false, b), 470, "level 1, all quests")
	T.eq(Rules.bonus([1.0, 1.0, 1.0, 1.0], 1, 0.0, true, b), 100, "fired keeps 25%")
	T.eq(Rules.bonus([1.0, 1.0, 1.0, 1.0], 2, 70.0, false, b), 570, "level 2 pays 25% more")
	T.eq(Rules.bonus([1.0], 1, 70.0, false, b), 170, "level 1: tickets only")


func test_promoted() -> void:
	var b := Balance.new()
	T.truth(Rules.promoted(90.0, 99.0, b), "90 and rival below 100")
	T.truth(not Rules.promoted(89.0, 0.0, b), "89 is not enough")
	T.truth(not Rules.promoted(100.0, 100.0, b), "full rival bar blocks promotion")


func test_timer_scale() -> void:
	T.eq(Rules.timer_scale(1), 1.0, "level 1")
	T.near(Rules.timer_scale(5), 0.7164, 0.001, "level 5")
	T.eq(Rules.timer_scale(30), 0.5, "floor")
