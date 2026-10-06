#!/bin/sh
# Refresh the class cache, then run all tests headless. Exit code 0 means all passed.
cd "$(dirname "$0")/.." || exit 1
timeout 120 godot --headless --path . --import >/dev/null 2>&1
timeout 120 godot --headless --path . --script tests/run.gd
