local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
local M = ImGuizmo._math

local function near(a, b) return math.abs(a - b) < 1e-4 end

-- decompose/recompose round trip
local t0, r0, s0 = { 1, -2, 3 }, { 30, -20, 45 }, { 2, 0.5, 1.5 }
local m = {}
ImGuizmo.RecomposeMatrixFromComponents(t0, r0, s0, m)
local t, r, s = {}, {}, {}
ImGuizmo.DecomposeMatrixToComponents(m, t, r, s)
for i = 1, 3 do
    assert(near(t[i], t0[i]), "translation " .. i)
    assert(near(r[i], r0[i]), "rotation " .. i .. " " .. r[i])
    assert(near(s[i], s0[i]), "scale " .. i)
end

-- inverse * matrix ~= identity
local mat = M.matrix_t.new(m)
mat[4], mat[8], mat[12] = 0.1, 0.2, 0.3 -- non-affine too
local inv = M.matrix_t.new()
inv:Inverse(mat)
local id = inv * mat
for i = 1, 16 do
    local e = 0
    if i % 5 == 1 then e = 1 end
    assert(near(id[i], e), "identity " .. i .. " " .. id[i])
end

assert(ImGuizmo.OPERATION.UNIVERSAL == 14463, "UNIVERSAL")
print("OK")
