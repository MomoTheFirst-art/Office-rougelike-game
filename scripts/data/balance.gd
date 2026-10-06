class_name Balance
extends Resource
## Every tunable number. Defaults are the spec's placeholders.

@export_group("Run")
@export var run_seconds := 600.0
@export var start_satisfaction := 50.0
@export var promo_threshold := 90.0
@export var unlock_levels := {
	"tickets": 1, "stability": 2, "bugtickets": 2, "pr": 3, "leads": 4, "meetings": 5, "npcs": 6,
}

@export_group("Station hold seconds")
@export var hold_pc := 4.0
@export var hold_phone := 8.0
@export var hold_sales := 6.0
@export var hold_studio := 10.0
@export var hold_devtable := 8.0
@export var hold_pad := 2.0
@export var hold_callout := 2.0

@export_group("Satisfaction")
@export var sat_reply := 1.0
@export var sat_call := 3.0
@export var sat_bug := 2.0
@export var sat_expire := -4.0
@export var outage_sat_per_s := -1.0

@export_group("Stability")
@export var stability_drain := 1.0
@export var stability_refill := 6.0
@export var stability_ok_level := 30.0
@export var stability_ok_share := 0.9
@export var bugticket_share_decay := 0.9
@export var bug_rate_per_level := 0.25  # spontaneous bugs get this much more frequent per level above 2
@export var outage_ticket_every := 20.0  # seconds between extra tickets while stability is 0

@export_group("Work items")
@export var deadline_ticket := 40.0
@export var deadline_bugticket := 60.0
@export var deadline_lead := 90.0
@export var deadline_pr := 60.0
@export var interval_ticket := 8.0
@export var interval_lead := 30.0
@export var interval_pr := 40.0
@export var interval_bug := 45.0
@export var bugticket_share := 0.25
@export var lead_values := PackedInt32Array([500, 1200, 2500])
@export var lead_hold_mult := PackedFloat32Array([1.0, 1.25, 1.5])
@export var pr_points := {"pc": 1, "phone": 2, "studio": 4}

@export_group("Quests and payout")
@export var ticket_base := 40.0
@export var revenue_base := 2000.0
@export var pr_base := 6.0
@export var pr_per_level := 2.0
@export var ticket_level_growth := 0.2
@export var revenue_level_growth := 0.25
@export var payout_level_growth := 0.25
@export var payout_per_quest := 100.0
@export var fired_payout_share := 0.25

@export_group("Meetings and buffs")
@export var meeting_times := PackedFloat32Array([0.25, 0.5, 0.75])
@export var meeting_countdown := 15.0
@export var meeting_warning := 5.0
@export var buff_timeout := 8.0
