#!/usr/bin/env bash
# Runs every tests/t_*.luau against the core (tools/core submodule) in the Roblox mock.
cd "$(dirname "$0")/.."
fail=0
for t in tests/t_*.luau; do
    out=$(python3 tools/core/tools/test/run.py --module ImGuizmo=ImGuizmo.lua --main "$t" --quiet --roblox 2>&1)
    if echo "$out" | grep -q "^OK"; then echo "PASS $t"; else echo "FAIL $t"; echo "$out" | tail -20; fail=1; fi
done
ex=$(mktemp --suffix=.luau)
cat tests/example_prelude.luau examples/roblox/main.client.luau > "$ex"
out=$(python3 tools/core/tools/test/run.py --module ImGuizmo=ImGuizmo.lua --main "$ex" --frames 30 --roblox 2>&1)
rm -f "$ex"
if echo "$out" | grep -q "^OK"; then echo "PASS example"; else echo "FAIL example"; echo "$out" | tail -20; fail=1; fi
exit $fail
