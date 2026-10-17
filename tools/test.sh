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
# every operation x snap x bounds (random mouse input drags over the gizmo)
for op in TRANSLATE ROTATE SCALE UNIVERSAL; do for snap in false true; do for bounds in false true; do
    ex=$(mktemp --suffix=.luau)
    cat tests/example_prelude.luau examples/roblox/main.client.luau | sed \
        -e "s/^local Operation, Mode = OP.TRANSLATE/local Operation, Mode = OP.$op/" \
        -e "s/^local UseSnap, ShowGrid = false/local UseSnap, ShowGrid = $snap/" \
        -e "s/^local BoundSizing, BoundSizingSnap = false, false/local BoundSizing, BoundSizingSnap = $bounds, $bounds/" > "$ex"
    out=$(python3 tools/core/tools/test/run.py --module ImGuizmo=ImGuizmo.lua --main "$ex" --frames 30 --roblox 2>&1)
    rm -f "$ex"
    if echo "$out" | grep -q "^OK"; then echo "PASS example $op snap=$snap bounds=$bounds"; else echo "FAIL example $op snap=$snap bounds=$bounds"; echo "$out" | tail -20; fail=1; fi
done; done; done
exit $fail
