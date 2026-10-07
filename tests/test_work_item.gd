extends RefCounted

var tree: SceneTree


func _ticket() -> WorkItem:
	var it := WorkItem.new()
	it.type = "ticket"
	it.deadline = 40.0
	return it


func test_ticket_accepts_pc_and_phone() -> void:
	var it := _ticket()
	T.truth(it.accepts("pc"), "pc")
	T.truth(it.accepts("phone"), "phone")
	T.truth(not it.accepts("sales"), "not sales")
	T.truth(not it.accepts("devtable"), "not devtable")


func test_reply_effects() -> void:
	var b := Balance.new()
	var fx := _ticket().apply("pc", b)
	T.eq(fx["done"], true, "done")
	T.eq(fx["satisfaction"], b.sat_reply, "reply satisfaction")
	T.eq(fx["quest"], {"tickets": 1.0}, "quest")


func test_call_effects() -> void:
	var b := Balance.new()
	var fx := _ticket().apply("phone", b)
	T.eq(fx["done"], true, "done")
	T.eq(fx["satisfaction"], b.sat_call, "call satisfaction")
	T.eq(fx["quest"], {"tickets": 1.0}, "quest")


func test_ticket_stream_is_tickets() -> void:
	T.eq(_ticket().stream(), "tickets", "stream")
