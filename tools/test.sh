#!/bin/sh
# Refresh the class cache, then run all tests headless.
# Exit code 0 only if every test passed and Godot printed no ERROR lines.
cd "$(dirname "$0")/.." || exit 1
timeout 120 godot --headless --path . --import >/dev/null 2>&1
out=$(mktemp)
timeout 120 godot --headless --path . --script tests/run.gd >"$out" 2>&1
code=$?
cat "$out"
if grep -qE "^(SCRIPT )?ERROR" "$out"; then
	echo "FAIL: Godot reported errors"
	code=1
fi
rm -f "$out"
exit $code
