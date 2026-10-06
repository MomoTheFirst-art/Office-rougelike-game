class_name T
extends RefCounted
## Plain assert helpers. Failures are counted in T.failed and printed.

static var failed := 0


static func truth(cond: bool, msg: String = "") -> void:
	if not cond:
		failed += 1
		printerr("  FAIL: ", msg)


static func eq(got, want, msg: String = "") -> void:
	if got != want:
		failed += 1
		printerr("  FAIL: ", msg, " | got ", got, " want ", want)


static func near(got: float, want: float, eps: float, msg: String = "") -> void:
	if absf(got - want) > eps:
		failed += 1
		printerr("  FAIL: ", msg, " | got ", got, " want ", want, " +-", eps)
